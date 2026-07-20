import { createHash } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import { isValidIdentifier } from "./authz.js";

export type MigrationManifest = {
  id: string;
  sourcePath: string;
  destinationPath: string;
  schemaVersion: number;
  ownerResolution: "mapped" | "quarantine";
  checksum: string;
};

export interface LegacyFixtureDocument {
  readonly path: string;
  readonly data: Readonly<Record<string, unknown>>;
}

export interface MigrationFixture {
  readonly migrationId: string;
  readonly migrationTimestamp: string;
  readonly schemaVersion: number;
  readonly ownership: Readonly<Record<string, string>>;
  readonly documents: readonly LegacyFixtureDocument[];
}

export interface MigrationWrite {
  readonly manifest: MigrationManifest;
  readonly data: Readonly<Record<string, unknown>>;
}

export interface MigrationPlan {
  readonly migrationId: string;
  readonly schemaVersion: number;
  readonly sourceCount: number;
  readonly mappedCount: number;
  readonly quarantinedCount: number;
  readonly planChecksum: string;
  readonly writes: readonly MigrationWrite[];
}

type LegacyRecordKind = "student" | "plan";

interface ParsedLegacyPath {
  readonly kind: LegacyRecordKind;
  readonly legacyID: string;
  readonly userOwnerPath: string | null;
}

interface OwnerResolution {
  readonly districtID: string | null;
  readonly reason: "unresolved-tenant-ownership" | "tenant-ownership-conflict";
}

export function parseMigrationFixture(value: unknown): MigrationFixture {
  const root = requirePlainRecord(value, "fixture");
  rejectUnexpectedKeys(
    root,
    new Set([
      "migrationId",
      "migrationTimestamp",
      "schemaVersion",
      "ownership",
      "documents",
    ]),
    "fixture",
  );
  const migrationId = requireOpaqueIdentifier(
    root.migrationId,
    "fixture.migrationId",
  );
  const migrationTimestamp = requireTimestampString(
    root.migrationTimestamp,
    "fixture.migrationTimestamp",
  );
  const schemaVersion = requirePositiveInteger(
    root.schemaVersion,
    "fixture.schemaVersion",
  );
  const ownershipValue = requirePlainRecord(
    root.ownership,
    "fixture.ownership",
  );
  const ownership: Record<string, string> = {};
  for (const [ownerPath, districtValue] of Object.entries(ownershipValue)) {
    requireDocumentPath(ownerPath, "fixture.ownership key");
    ownership[ownerPath] = requireOpaqueIdentifier(
      districtValue,
      `fixture.ownership.${ownerPath}`,
    );
  }

  if (!Array.isArray(root.documents) || root.documents.length === 0) {
    throw new TypeError("fixture.documents must be a non-empty array.");
  }
  const seenPaths = new Set<string>();
  const documents = root.documents.map((candidate, index) => {
    const document = requirePlainRecord(
      candidate,
      `fixture.documents[${index}]`,
    );
    rejectUnexpectedKeys(
      document,
      new Set(["path", "data"]),
      `fixture.documents[${index}]`,
    );
    const path = requireDocumentPath(
      document.path,
      `fixture.documents[${index}].path`,
    );
    if (seenPaths.has(path)) {
      throw new TypeError(`Duplicate legacy document path: ${path}.`);
    }
    seenPaths.add(path);
    const data = requirePlainRecord(
      document.data,
      `fixture.documents[${index}].data`,
    );
    requireJSONValue(data, `fixture.documents[${index}].data`);
    return { path, data };
  });

  return {
    migrationId,
    migrationTimestamp,
    schemaVersion,
    ownership,
    documents,
  };
}

export function buildMigrationPlan(
  fixture: MigrationFixture,
): MigrationPlan {
  const writes = fixture.documents
    .map((document) => buildMigrationWrite(fixture, document))
    .sort((left, right) =>
      left.manifest.sourcePath.localeCompare(right.manifest.sourcePath),
    );
  const mappedCount = writes.filter(
    (write) => write.manifest.ownerResolution === "mapped",
  ).length;
  const quarantinedCount = writes.length - mappedCount;
  const planChecksum = checksumValue(
    writes.map((write) => ({
      ...write.manifest,
      data: write.data,
    })),
  );

  return {
    migrationId: fixture.migrationId,
    schemaVersion: fixture.schemaVersion,
    sourceCount: fixture.documents.length,
    mappedCount,
    quarantinedCount,
    planChecksum,
    writes,
  };
}

export function checksumValue(value: unknown): string {
  return createHash("sha256")
    .update(canonicalJSONString(value))
    .digest("hex");
}

export function canonicalJSONString(value: unknown): string {
  return JSON.stringify(canonicalize(value));
}

function buildMigrationWrite(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
): MigrationWrite {
  const checksum = checksumValue(document.data);
  const parsedPath = parseLegacyPath(document.path);
  const legacyID =
    parsedPath?.legacyID ?? document.path.split("/").at(-1) ?? "unknown";
  const owner = resolveOwner(fixture, document, parsedPath);
  const destinationPath =
    parsedPath !== null && owner.districtID !== null
      ? canonicalDestinationPath(
          owner.districtID,
          parsedPath.kind,
          parsedPath.legacyID,
        )
      : `migrationQuarantine/${stableID(document.path)}`;
  const ownerResolution =
    parsedPath !== null && owner.districtID !== null
      ? ("mapped" as const)
      : ("quarantine" as const);
  const manifest: MigrationManifest = {
    id: stableID(
      `${fixture.migrationId}:${document.path}:${destinationPath}:${checksum}`,
    ),
    sourcePath: document.path,
    destinationPath,
    schemaVersion: fixture.schemaVersion,
    ownerResolution,
    checksum,
  };
  const fallbackActor = `migration:${fixture.migrationId}`;
  const createdAt = canonicalTimestamp(
    document.data.createdAt,
    fixture.migrationTimestamp,
  );
  const createdBy = isValidIdentifier(document.data.createdBy)
    ? document.data.createdBy
    : fallbackActor;
  const updatedAt = canonicalTimestamp(document.data.updatedAt, createdAt);
  const updatedBy = isValidIdentifier(document.data.updatedBy)
    ? document.data.updatedBy
    : createdBy;

  if (ownerResolution === "quarantine") {
    return {
      manifest,
      data: {
        schemaVersion: fixture.schemaVersion,
        recordVersion: 1,
        createdAt,
        createdBy,
        updatedAt,
        updatedBy,
        migrationId: fixture.migrationId,
        legacyPath: document.path,
        legacyId: legacyID,
        checksum,
        reason:
          parsedPath === null
            ? "unsupported-legacy-path"
            : owner.reason,
        sourceData: document.data,
      },
    };
  }

  const recordVersion =
    typeof document.data.recordVersion === "number" &&
    Number.isSafeInteger(document.data.recordVersion) &&
    document.data.recordVersion > 0
      ? document.data.recordVersion
      : 1;
  return {
    manifest,
    data: {
      ...document.data,
      schemaVersion: fixture.schemaVersion,
      recordVersion,
      createdAt,
      createdBy,
      updatedAt,
      updatedBy,
      districtId: owner.districtID,
      migrationId: fixture.migrationId,
      legacyPath: document.path,
      legacyId: legacyID,
      checksum,
    },
  };
}

function parseLegacyPath(path: string): ParsedLegacyPath | null {
  const segments = path.split("/");
  if (
    segments.length === 4 &&
    segments[0] === "users" &&
    segments[2] === "students"
  ) {
    return {
      kind: "student",
      legacyID: segments[3] ?? "",
      userOwnerPath: `users/${segments[1] ?? ""}`,
    };
  }
  if (
    segments.length === 4 &&
    segments[0] === "users" &&
    segments[2] === "tmiPlans"
  ) {
    return {
      kind: "plan",
      legacyID: segments[3] ?? "",
      userOwnerPath: `users/${segments[1] ?? ""}`,
    };
  }
  if (segments.length === 2 && segments[0] === "students") {
    return {
      kind: "student",
      legacyID: segments[1] ?? "",
      userOwnerPath: null,
    };
  }
  if (segments.length === 2 && segments[0] === "plans") {
    return {
      kind: "plan",
      legacyID: segments[1] ?? "",
      userOwnerPath: null,
    };
  }
  return null;
}

function resolveOwner(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
  parsedPath: ParsedLegacyPath | null,
): OwnerResolution {
  if (parsedPath === null) {
    return { districtID: null, reason: "unresolved-tenant-ownership" };
  }
  const mappedDistrict =
    fixture.ownership[document.path] ??
    (parsedPath.userOwnerPath === null
      ? undefined
      : fixture.ownership[parsedPath.userOwnerPath]);
  if (mappedDistrict === undefined) {
    return { districtID: null, reason: "unresolved-tenant-ownership" };
  }
  const embeddedDistrict = document.data.districtId;
  if (
    embeddedDistrict !== undefined &&
    embeddedDistrict !== null &&
    embeddedDistrict !== mappedDistrict
  ) {
    return { districtID: null, reason: "tenant-ownership-conflict" };
  }
  return { districtID: mappedDistrict, reason: "unresolved-tenant-ownership" };
}

function canonicalDestinationPath(
  districtID: string,
  kind: LegacyRecordKind,
  legacyID: string,
): string {
  const collection = kind === "student" ? "students" : "plans";
  return `districts/${districtID}/${collection}/${legacyID}`;
}

function stableID(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 40);
}

function requirePlainRecord(
  value: unknown,
  fieldName: string,
): Record<string, unknown> {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value) ||
    Object.getPrototypeOf(value) !== Object.prototype
  ) {
    throw new TypeError(`${fieldName} must be a plain object.`);
  }
  return value as Record<string, unknown>;
}

function rejectUnexpectedKeys(
  value: Record<string, unknown>,
  allowedKeys: ReadonlySet<string>,
  fieldName: string,
): void {
  const unexpected = Object.keys(value).find((key) => !allowedKeys.has(key));
  if (unexpected !== undefined) {
    throw new TypeError(`${fieldName} contains unexpected key ${unexpected}.`);
  }
}

function requireOpaqueIdentifier(value: unknown, fieldName: string): string {
  if (!isValidIdentifier(value)) {
    throw new TypeError(`${fieldName} must be a safe opaque identifier.`);
  }
  return value;
}

function requirePositiveInteger(value: unknown, fieldName: string): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 1
  ) {
    throw new TypeError(`${fieldName} must be a positive integer.`);
  }
  return value;
}

function requireTimestampString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be an ISO-8601 timestamp.`);
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new TypeError(`${fieldName} must be an ISO-8601 timestamp.`);
  }
  return date.toISOString();
}

function canonicalTimestamp(
  value: unknown,
  fallback: string | Timestamp,
): Timestamp {
  if (value instanceof Timestamp) {
    return value;
  }
  if (typeof value === "string") {
    const date = new Date(value);
    if (Number.isFinite(date.getTime())) {
      return Timestamp.fromDate(date);
    }
  }
  return typeof fallback === "string"
    ? Timestamp.fromDate(new Date(fallback))
    : fallback;
}

function requireDocumentPath(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be a document path.`);
  }
  const segments = value.split("/");
  if (
    segments.length < 2 ||
    segments.length % 2 !== 0 ||
    !segments.every(isValidIdentifier)
  ) {
    throw new TypeError(`${fieldName} must be a valid document path.`);
  }
  return value;
}

function requireJSONValue(value: unknown, fieldName: string): void {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      requireJSONValue(item, `${fieldName}[${index}]`),
    );
    return;
  }
  if (
    typeof value === "object" &&
    value !== null &&
    Object.getPrototypeOf(value) === Object.prototype
  ) {
    Object.entries(value).forEach(([key, nestedValue]) =>
      requireJSONValue(nestedValue, `${fieldName}.${key}`),
    );
    return;
  }
  throw new TypeError(`${fieldName} contains a non-JSON value.`);
}

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }
  if (typeof value === "object" && value !== null) {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, nestedValue]) => [key, canonicalize(nestedValue)]),
    );
  }
  return value;
}
