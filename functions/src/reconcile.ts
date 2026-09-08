import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  buildMigrationPlan,
  canonicalJSONString,
  parseMigrationFixture,
  type MigrationPlan,
  type MigrationWrite,
} from "./migrationManifest.js";
import {
  applyMigrationPlan,
  FirestoreMigrationStore,
  MemoryMigrationStore,
  type MigrationStore,
} from "./migrate.js";

export interface ReconciliationReport {
  readonly expectedCount: number;
  readonly foundCount: number;
  readonly mismatches: readonly string[];
  readonly isConsistent: boolean;
}

export async function reconcileMigrationPlan(
  plan: MigrationPlan,
  store: MigrationStore,
): Promise<ReconciliationReport> {
  const mismatches: string[] = [];
  let foundCount = 0;
  const destinationPaths = new Set<string>();

  for (const write of plan.writes) {
    if (destinationPaths.has(write.manifest.destinationPath)) {
      mismatches.push(
        `duplicate destination: ${write.manifest.destinationPath}`,
      );
      continue;
    }
    destinationPaths.add(write.manifest.destinationPath);
    const actual = await store.read(write.manifest.destinationPath);
    if (actual === null) {
      mismatches.push(`missing destination: ${write.manifest.destinationPath}`);
      continue;
    }
    foundCount += 1;
    reconcileRequiredFields(plan, write, actual, mismatches);
    reconcileStableID(write, mismatches);
    reconcileTenantOwnership(write, actual, mismatches);
    if (canonicalJSONString(actual) !== canonicalJSONString(write.data)) {
      mismatches.push(
        `decoded equality mismatch: ${write.manifest.destinationPath}`,
      );
    }
  }

  await reconcilePlanReferences(plan, store, mismatches);
  await reconcileStudentAssignments(plan, store, mismatches);
  mismatches.sort((left, right) => left.localeCompare(right));
  return {
    expectedCount: plan.writes.length,
    foundCount,
    mismatches,
    isConsistent: mismatches.length === 0,
  };
}

function reconcileRequiredFields(
  plan: MigrationPlan,
  write: MigrationWrite,
  actual: Readonly<Record<string, unknown>>,
  mismatches: string[],
): void {
  const legacyID = write.manifest.sourcePath.split("/").at(-1);
  const verifiesCanonicalSource =
    write.manifest.sourcePath === write.manifest.destinationPath;
  const expectedFields: Readonly<Record<string, unknown>> = {
    ...(verifiesCanonicalSource
      ? {}
      : {
          migrationId: plan.migrationId,
          legacyPath: write.manifest.sourcePath,
          legacyId: legacyID,
          checksum: write.manifest.checksum,
        }),
    schemaVersion: write.manifest.schemaVersion,
    createdAt: write.data.createdAt,
    createdBy: write.data.createdBy,
    updatedAt: write.data.updatedAt,
    updatedBy: write.data.updatedBy,
  };
  for (const [field, expected] of Object.entries(expectedFields)) {
    if (canonicalJSONString(actual[field]) !== canonicalJSONString(expected)) {
      mismatches.push(
        `required field mismatch (${field}): ${write.manifest.destinationPath}`,
      );
    }
  }
  if (
    typeof actual.recordVersion !== "number" ||
    !Number.isSafeInteger(actual.recordVersion) ||
    actual.recordVersion < 1
  ) {
    mismatches.push(
      `required field mismatch (recordVersion): ${write.manifest.destinationPath}`,
    );
  }
}

function reconcileStableID(
  write: MigrationWrite,
  mismatches: string[],
): void {
  if (write.manifest.ownerResolution !== "mapped") {
    return;
  }
  if (write.manifest.destinationPath.startsWith("catalogs/careers/items/")) {
    return;
  }
  const legacyID = write.manifest.sourcePath.split("/").at(-1);
  const destinationID = write.manifest.destinationPath.split("/").at(-1);
  if (legacyID !== destinationID) {
    mismatches.push(
      `stable ID mismatch: ${write.manifest.destinationPath}`,
    );
  }
}

function reconcileTenantOwnership(
  write: MigrationWrite,
  actual: Readonly<Record<string, unknown>>,
  mismatches: string[],
): void {
  if (write.manifest.ownerResolution === "quarantine") {
    if (!write.manifest.destinationPath.startsWith("migrationQuarantine/")) {
      mismatches.push(
        `quarantine path mismatch: ${write.manifest.destinationPath}`,
      );
    }
    return;
  }
  if (write.manifest.destinationPath.startsWith("catalogs/careers/items/")) {
    const segments = write.manifest.destinationPath.split("/");
    if (segments.length !== 4 || actual.id !== segments[3] || actual.isApproved !== true) {
      mismatches.push(`catalog identity mismatch: ${write.manifest.destinationPath}`);
    }
    return;
  }
  if (/^districts\/[^/]+\/students\/[^/]+\/careers\/[^/]+$/u.test(write.manifest.destinationPath)) {
    const segments = write.manifest.destinationPath.split("/");
    if (
      actual.districtID !== segments[1] ||
      actual.studentID !== segments[3] ||
      actual.careerID !== segments[5] ||
      actual.isSaved !== true ||
      actual.isDismissed !== false
    ) {
      mismatches.push(`career relationship mismatch: ${write.manifest.destinationPath}`);
    }
    return;
  }
  const segments = write.manifest.destinationPath.split("/");
  const districtID = segments[1];
  const collection = segments[2];
  const actualDistrictID =
    collection === "members" ? actual.districtID : actual.districtId;
  if (
    segments.length !== 4 ||
    segments[0] !== "districts" ||
    (collection !== "students" &&
      collection !== "plans" &&
      collection !== "members") ||
    actualDistrictID !== districtID
  ) {
    mismatches.push(
      `tenant ownership mismatch: ${write.manifest.destinationPath}`,
    );
  }
}

async function reconcilePlanReferences(
  plan: MigrationPlan,
  store: MigrationStore,
  mismatches: string[],
): Promise<void> {
  for (const write of plan.writes) {
    const segments = write.manifest.destinationPath.split("/");
    if (
      write.manifest.ownerResolution !== "mapped" ||
      segments[2] !== "plans"
    ) {
      continue;
    }
    const studentIDs = write.data.studentIDs;
    if (!Array.isArray(studentIDs) || studentIDs.length === 0) {
      mismatches.push(
        `required plan reference mismatch: ${write.manifest.destinationPath}`,
      );
      continue;
    }
    const districtID = segments[1] ?? "";
    for (const studentID of studentIDs) {
      if (typeof studentID !== "string") {
        mismatches.push(
          `malformed student reference: ${write.manifest.destinationPath}`,
        );
        continue;
      }
      const studentPath = `districts/${districtID}/students/${studentID}`;
      if ((await store.read(studentPath)) === null) {
        mismatches.push(
          `broken student reference (${studentID}): ${write.manifest.destinationPath}`,
        );
      }
    }
  }
}

async function reconcileStudentAssignments(
  plan: MigrationPlan,
  store: MigrationStore,
  mismatches: string[],
): Promise<void> {
  for (const write of plan.writes) {
    const segments = write.manifest.destinationPath.split("/");
    if (
      write.manifest.ownerResolution !== "mapped" ||
      segments.length !== 4 ||
      segments[2] !== "students"
    ) {
      continue;
    }
    const districtID = segments[1] ?? "";
    const studentID = segments[3] ?? "";
    const assignedMemberIDs = write.data.assignedMemberIDs;
    if (
      !Array.isArray(assignedMemberIDs) ||
      !assignedMemberIDs.every((value) => typeof value === "string")
    ) {
      mismatches.push(
        `malformed assigned members: ${write.manifest.destinationPath}`,
      );
      continue;
    }
    for (const memberID of assignedMemberIDs) {
      const memberPath = `districts/${districtID}/members/${memberID}`;
      const member = await store.read(memberPath);
      if (member === null) {
        mismatches.push(
          `missing assigned member (${memberID}): ${write.manifest.destinationPath}`,
        );
        continue;
      }
      const assignedStudentIDs = member.assignedStudentIDs;
      if (
        !Array.isArray(assignedStudentIDs) ||
        !assignedStudentIDs.includes(studentID)
      ) {
        mismatches.push(
          `missing student back-reference (${studentID}): ${memberPath}`,
        );
      }
    }
  }

  for (const write of plan.writes) {
    const segments = write.manifest.destinationPath.split("/");
    if (
      write.manifest.ownerResolution !== "mapped" ||
      segments.length !== 4 ||
      segments[2] !== "members"
    ) {
      continue;
    }
    const districtID = segments[1] ?? "";
    const memberID = segments[3] ?? "";
    const assignedStudentIDs = write.data.assignedStudentIDs;
    if (
      !Array.isArray(assignedStudentIDs) ||
      !assignedStudentIDs.every((value) => typeof value === "string")
    ) {
      mismatches.push(
        `malformed assigned students: ${write.manifest.destinationPath}`,
      );
      continue;
    }
    for (const studentID of assignedStudentIDs) {
      const studentPath =
        `districts/${districtID}/students/${studentID}`;
      const student = await store.read(studentPath);
      if (student === null) {
        mismatches.push(
          `missing assigned student (${studentID}): ${write.manifest.destinationPath}`,
        );
        continue;
      }
      const assignedMemberIDs = student.assignedMemberIDs;
      if (
        !Array.isArray(assignedMemberIDs) ||
        !assignedMemberIDs.includes(memberID)
      ) {
        mismatches.push(
          `missing member back-reference (${memberID}): ${studentPath}`,
        );
      }
    }
  }
}

interface ReconcileCLIArguments {
  readonly project: string;
  readonly fixturePath: string;
  readonly againstFirestore: boolean;
  readonly confirmedProject: string | null;
}

function parseCLIArguments(arguments_: readonly string[]): ReconcileCLIArguments {
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
    againstFirestore: arguments_.includes("--against-firestore"),
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
  let store: MigrationStore;
  let mode: "fixture" | "firestore";

  if (arguments_.againstFirestore) {
    if (arguments_.confirmedProject !== arguments_.project) {
      throw new TypeError(
        "Firestore reconciliation requires an exact --confirm-project value.",
      );
    }
    if (getApps().length === 0) {
      initializeApp({ projectId: arguments_.project });
    }
    store = new FirestoreMigrationStore(getFirestore());
    mode = "firestore";
  } else {
    const memoryStore = new MemoryMigrationStore();
    for (const write of plan.writes) {
      if (write.manifest.sourcePath === write.manifest.destinationPath) {
        await memoryStore.replaceForTesting(
          write.manifest.destinationPath,
          write.data,
        );
      }
    }
    await applyMigrationPlan(plan, memoryStore);
    store = memoryStore;
    mode = "fixture";
  }

  const report = await reconcileMigrationPlan(plan, store);
  process.stdout.write(
    `${JSON.stringify({ mode, project: arguments_.project, ...report }, null, 2)}\n`,
  );
  if (!report.isConsistent) {
    process.exitCode = 2;
  }
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
