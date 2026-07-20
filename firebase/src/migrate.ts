import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import {
  buildMigrationPlan,
  canonicalJSONString,
  parseMigrationFixture,
  type MigrationPlan,
  type MigrationWrite,
} from "./migrationManifest.js";

export interface MigrationStore {
  read(path: string): Promise<Readonly<Record<string, unknown>> | null>;
  createIfAbsent(
    path: string,
    data: Readonly<Record<string, unknown>>,
  ): Promise<"created" | "exists">;
}

export interface MigrationApplyResult {
  readonly plannedWrites: number;
  readonly writesApplied: number;
  readonly alreadyApplied: number;
}

export class MigrationConflictError extends Error {
  constructor(path: string) {
    super(
      `Migration destination ${path} already exists with different data. ` +
        "The forward migration stopped without overwriting it.",
    );
    this.name = "MigrationConflictError";
  }
}

export class ForwardOnlyMigrationError extends Error {
  constructor() {
    super(
      "Canonical migrations are forward-only. Correct data with a new " +
        "versioned migration instead of deleting or rolling back history.",
    );
    this.name = "ForwardOnlyMigrationError";
  }
}

export class MemoryMigrationStore implements MigrationStore {
  readonly #documents = new Map<string, Readonly<Record<string, unknown>>>();

  get count(): number {
    return this.#documents.size;
  }

  async read(
    path: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    const value = this.#documents.get(path);
    return value === undefined ? null : cloneRecord(value);
  }

  async createIfAbsent(
    path: string,
    data: Readonly<Record<string, unknown>>,
  ): Promise<"created" | "exists"> {
    if (this.#documents.has(path)) {
      return "exists";
    }
    this.#documents.set(path, cloneRecord(data));
    return "created";
  }

  async replaceForTesting(
    path: string,
    data: Readonly<Record<string, unknown>>,
  ): Promise<void> {
    this.#documents.set(path, cloneRecord(data));
  }

  async deleteForTesting(path: string): Promise<void> {
    this.#documents.delete(path);
  }
}

export class FirestoreMigrationStore implements MigrationStore {
  constructor(private readonly firestore: Firestore) {}

  async read(
    path: string,
  ): Promise<Readonly<Record<string, unknown>> | null> {
    const snapshot = await this.firestore.doc(path).get();
    return snapshot.exists ? (snapshot.data() ?? {}) : null;
  }

  async createIfAbsent(
    path: string,
    data: Readonly<Record<string, unknown>>,
  ): Promise<"created" | "exists"> {
    try {
      await this.firestore.doc(path).create(data);
      return "created";
    } catch (error) {
      if (isAlreadyExistsError(error)) {
        return "exists";
      }
      throw error;
    }
  }
}

export async function applyMigrationPlan(
  plan: MigrationPlan,
  store: MigrationStore,
): Promise<MigrationApplyResult> {
  const pending: MigrationWrite[] = [];
  let alreadyApplied = 0;

  for (const write of plan.writes) {
    const existing = await store.read(write.manifest.destinationPath);
    if (existing === null) {
      pending.push(write);
    } else if (recordsEqual(existing, write.data)) {
      alreadyApplied += 1;
    } else {
      throw new MigrationConflictError(write.manifest.destinationPath);
    }
  }

  let writesApplied = 0;
  for (const write of pending) {
    const result = await store.createIfAbsent(
      write.manifest.destinationPath,
      write.data,
    );
    if (result === "created") {
      writesApplied += 1;
      continue;
    }

    const racedDocument = await store.read(write.manifest.destinationPath);
    if (racedDocument !== null && recordsEqual(racedDocument, write.data)) {
      alreadyApplied += 1;
      continue;
    }
    throw new MigrationConflictError(write.manifest.destinationPath);
  }

  return {
    plannedWrites: plan.writes.length,
    writesApplied,
    alreadyApplied,
  };
}

export function rollbackMigration(): never {
  throw new ForwardOnlyMigrationError();
}

function recordsEqual(
  left: Readonly<Record<string, unknown>>,
  right: Readonly<Record<string, unknown>>,
): boolean {
  return canonicalJSONString(left) === canonicalJSONString(right);
}

function cloneRecord(
  value: Readonly<Record<string, unknown>>,
): Readonly<Record<string, unknown>> {
  return JSON.parse(canonicalJSONString(value)) as Record<string, unknown>;
}

function isAlreadyExistsError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }
  const code = (error as { code?: unknown }).code;
  return code === 6 || code === "6" || code === "already-exists";
}

interface MigrationCLIArguments {
  readonly project: string;
  readonly fixturePath: string;
  readonly dryRun: boolean;
  readonly apply: boolean;
  readonly confirmedProject: string | null;
}

function parseCLIArguments(arguments_: readonly string[]): MigrationCLIArguments {
  const readValue = (flag: string): string | null => {
    const index = arguments_.indexOf(flag);
    const value = index < 0 ? undefined : arguments_[index + 1];
    return value === undefined || value.startsWith("--") ? null : value;
  };
  const project = readValue("--project");
  const fixturePath = readValue("--fixture");
  if (project === null || fixturePath === null) {
    throw new TypeError("--project and --fixture are required.");
  }
  return {
    project,
    fixturePath,
    dryRun: arguments_.includes("--dry-run"),
    apply: arguments_.includes("--apply"),
    confirmedProject: readValue("--confirm-project"),
  };
}

function resolveInputPath(path: string): string {
  const initialDirectory = process.env.INIT_CWD;
  const candidates = [
    resolve(process.cwd(), path),
    ...(initialDirectory === undefined ? [] : [resolve(initialDirectory, path)]),
    resolve(process.cwd(), "..", path),
  ];
  const match = candidates.find(existsSync);
  if (match === undefined) {
    throw new TypeError(`Fixture not found: ${path}.`);
  }
  return match;
}

async function runCLI(): Promise<void> {
  const arguments_ = parseCLIArguments(process.argv.slice(2));
  const fixture = parseMigrationFixture(
    JSON.parse(
      readFileSync(resolveInputPath(arguments_.fixturePath), "utf8"),
    ) as unknown,
  );
  const plan = buildMigrationPlan(fixture);
  if (arguments_.dryRun) {
    process.stdout.write(`${JSON.stringify({ mode: "dry-run", ...plan }, null, 2)}\n`);
    return;
  }
  if (
    !arguments_.apply ||
    arguments_.confirmedProject !== arguments_.project
  ) {
    throw new TypeError(
      "Applying a migration requires --apply and an exact " +
        "--confirm-project value.",
    );
  }
  if (getApps().length === 0) {
    initializeApp({ projectId: arguments_.project });
  }
  const result = await applyMigrationPlan(
    plan,
    new FirestoreMigrationStore(getFirestore()),
  );
  process.stdout.write(
    `${JSON.stringify({ mode: "apply", project: arguments_.project, ...result }, null, 2)}\n`,
  );
}

const isMainModule =
  process.argv[1] !== undefined &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (isMainModule) {
  runCLI().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}
