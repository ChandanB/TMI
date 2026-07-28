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
  readonly predecessorData?: Readonly<Record<string, unknown>>;
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

type LegacyRecordKind = "student" | "plan" | "member";
type SourceRecordShape = "legacy" | "canonical";
type QuarantineReason =
  | "unsupported-legacy-path"
  | "unresolved-tenant-ownership"
  | "tenant-ownership-conflict"
  | "unresolved-school-ownership"
  | "malformed-student-record"
  | "duplicate-canonical-destination";

interface ParsedLegacyPath {
  readonly kind: LegacyRecordKind;
  readonly legacyID: string;
  readonly userOwnerPath: string | null;
  readonly sourceShape: SourceRecordShape;
  readonly canonicalDistrictID: string | null;
}

interface OwnerResolution {
  readonly districtID: string | null;
  readonly reason: "unresolved-tenant-ownership" | "tenant-ownership-conflict";
}

interface MigrationPredecessor {
  readonly migrationId: string;
  readonly migrationTimestamp: string;
  readonly schemaVersion: number;
}

const migrationPredecessors: Readonly<
  Record<string, MigrationPredecessor>
> = {
  "release1-roster-v1": {
    migrationId: "gate0-canonical-v1",
    migrationTimestamp: "2026-07-20T12:00:00.000Z",
    schemaVersion: 1,
  },
};

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
  const candidates = fixture.documents.map((document) => ({
    document,
    write: buildMigrationWrite(fixture, document),
  }));
  const mappedByDestination = new Map<
    string,
    typeof candidates
  >();
  for (const candidate of candidates) {
    if (candidate.write.manifest.ownerResolution !== "mapped") {
      continue;
    }
    const destination = candidate.write.manifest.destinationPath;
    const group = mappedByDestination.get(destination) ?? [];
    group.push(candidate);
    mappedByDestination.set(destination, group);
  }

  const duplicateSources = new Map<string, string>();
  for (const [destination, group] of mappedByDestination) {
    if (group.length < 2) {
      continue;
    }
    const canonical = group.filter(
      (candidate) =>
        candidate.write.manifest.sourcePath === destination,
    );
    if (canonical.length === 1) {
      for (const candidate of group) {
        if (candidate !== canonical[0]) {
          duplicateSources.set(candidate.document.path, destination);
        }
      }
      continue;
    }

    // Conflicting legacy copies have no trustworthy implicit winner. Keep
    // every source available for manual resolution instead of selecting a
    // tenant record from lexical order or fixture order.
    for (const candidate of group) {
      duplicateSources.set(candidate.document.path, destination);
    }
  }

  const writes = candidates
    .map(({ document, write }) => {
      const canonicalDestination = duplicateSources.get(document.path);
      const resolvedWrite = canonicalDestination === undefined
        ? write
        : buildQuarantineWrite(
            fixture,
            document,
            parseLegacyPath(document.path),
            "duplicate-canonical-destination",
            canonicalDestination,
          );
      const parsedPath = parseLegacyPath(document.path);
      const predecessor = migrationPredecessors[fixture.migrationId];
      if (
        predecessor === undefined ||
        parsedPath?.sourceShape === "canonical"
      ) {
        return resolvedWrite;
      }
      const predecessorFixture: MigrationFixture = {
        ...fixture,
        migrationId: predecessor.migrationId,
        migrationTimestamp: predecessor.migrationTimestamp,
        schemaVersion: predecessor.schemaVersion,
      };
      return {
        ...resolvedWrite,
        predecessorData: buildMigrationWrite(
          predecessorFixture,
          document,
        ).data,
      };
    })
    .sort((left, right) =>
      left.manifest.sourcePath.localeCompare(right.manifest.sourcePath),
    );
  assertUniqueDestinations(writes);
  const mappedCount = writes.filter(
    (write) => write.manifest.ownerResolution === "mapped",
  ).length;
  const quarantinedCount = writes.length - mappedCount;
  const planChecksum = checksumValue(
    writes.map((write) => ({
      ...write.manifest,
      data: write.data,
      ...(write.predecessorData === undefined
        ? {}
        : { predecessorData: write.predecessorData }),
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
  const parsedPath = parseLegacyPath(document.path);
  const owner = resolveOwner(fixture, document, parsedPath);
  if (parsedPath === null) {
    return buildQuarantineWrite(
      fixture,
      document,
      null,
      "unsupported-legacy-path",
    );
  }
  if (owner.districtID === null) {
    return buildQuarantineWrite(
      fixture,
      document,
      parsedPath,
      owner.reason,
    );
  }
  const districtID = owner.districtID;

  if (parsedPath.kind === "member") {
    const memberData = canonicalMemberData(document, districtID);
    if (memberData === null) {
      return buildQuarantineWrite(
        fixture,
        document,
        parsedPath,
        "malformed-student-record",
      );
    }
    const memberSchoolIDs = memberData.schoolIDs as readonly string[];
    if (
      !memberSchoolIDs.every((schoolID) =>
        hasTrustedSchoolOwnership(fixture, districtID, schoolID),
      )
    ) {
      return buildQuarantineWrite(
        fixture,
        document,
        parsedPath,
        "unresolved-school-ownership",
      );
    }
    const destinationPath = canonicalDestinationPath(
      districtID,
      parsedPath.kind,
      parsedPath.legacyID,
    );
    return {
      manifest: buildManifest(
        fixture,
        document,
        destinationPath,
        "mapped",
      ),
      data: memberData,
    };
  }

  if (parsedPath.kind === "student") {
    if (
      !isValidIdentifier(document.data.schoolId) ||
      !hasTrustedSchoolOwnership(
        fixture,
        districtID,
        document.data.schoolId,
      )
    ) {
      return buildQuarantineWrite(
        fixture,
        document,
        parsedPath,
        "unresolved-school-ownership",
      );
    }
    const studentData = canonicalStudentData(
      fixture,
      document,
      parsedPath,
      districtID,
    );
    if (studentData === null) {
      return buildQuarantineWrite(
        fixture,
        document,
        parsedPath,
        "malformed-student-record",
      );
    }
    const destinationPath = canonicalDestinationPath(
      districtID,
      parsedPath.kind,
      parsedPath.legacyID,
    );
    return {
      manifest: buildManifest(
        fixture,
        document,
        destinationPath,
        "mapped",
      ),
      data: studentData,
    };
  }

  const metadata = canonicalMetadata(fixture, document);
  const destinationPath = canonicalDestinationPath(
    districtID,
    parsedPath.kind,
    parsedPath.legacyID,
  );
  return {
    manifest: buildManifest(
      fixture,
      document,
      destinationPath,
      "mapped",
    ),
    data: {
      ...document.data,
      schemaVersion: fixture.schemaVersion,
      recordVersion: metadata.recordVersion,
      createdAt: metadata.createdAt,
      createdBy: metadata.createdBy,
      updatedAt: metadata.updatedAt,
      updatedBy: metadata.updatedBy,
      districtId: districtID,
      migrationId: fixture.migrationId,
      legacyPath: document.path,
      legacyId: parsedPath.legacyID,
      checksum: checksumValue(document.data),
    },
  };
}

function hasTrustedSchoolOwnership(
  fixture: MigrationFixture,
  districtID: string,
  schoolID: string,
): boolean {
  const schoolPath = `districts/${districtID}/schools/${schoolID}`;
  return fixture.ownership[schoolPath] === districtID;
}

function canonicalMemberData(
  document: LegacyFixtureDocument,
  districtID: string,
): Readonly<Record<string, unknown>> | null {
  if (
    document.data.districtID !== districtID ||
    !Array.isArray(document.data.schoolIDs) ||
    !document.data.schoolIDs.every(isValidIdentifier) ||
    !Array.isArray(document.data.assignedStudentIDs) ||
    !document.data.assignedStudentIDs.every(isValidIdentifier)
  ) {
    return null;
  }
  const metadata = existingCanonicalMetadata(document);
  if (metadata === null) {
    return null;
  }
  return {
    ...document.data,
    schoolIDs: [...new Set(document.data.schoolIDs)].sort(
      (left, right) =>
        (left as string).localeCompare(right as string),
    ),
    assignedStudentIDs: [
      ...new Set(document.data.assignedStudentIDs),
    ].sort((left, right) =>
      (left as string).localeCompare(right as string),
    ),
    schemaVersion: metadata.schemaVersion,
    recordVersion: metadata.recordVersion,
    createdAt: metadata.createdAt,
    createdBy: metadata.createdBy,
    updatedAt: metadata.updatedAt,
    updatedBy: metadata.updatedBy,
  };
}

function canonicalStudentData(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
  parsedPath: ParsedLegacyPath,
  districtID: string,
): Readonly<Record<string, unknown>> | null {
  const isCanonical = parsedPath.sourceShape === "canonical";
  const displayName = normalizeRequiredStudentText(
    isCanonical
      ? document.data.displayName
      : (document.data.displayName ?? document.data.name),
  );
  const grade = normalizeRequiredStudentText(document.data.grade);
  const schoolID = document.data.schoolId;
  if (
    displayName === null ||
    grade === null ||
    !isValidIdentifier(schoolID)
  ) {
    return null;
  }

  const studentIdentifier = normalizeOptionalStudentText(
    isCanonical
      ? document.data.studentIdentifier
      : (document.data.studentIdentifier ?? document.data.studentID),
  );
  const pronouns = normalizeOptionalStudentText(document.data.pronouns);
  if (studentIdentifier === null || pronouns === null) {
    return null;
  }

  const dateOfBirth = optionalCanonicalTimestamp(
    document.data.dateOfBirth,
  );
  if (dateOfBirth === null) {
    return null;
  }

  const assignedMemberIDs = canonicalAssignedMemberIDs(
    document.data,
    isCanonical,
  );
  if (assignedMemberIDs === null) {
    return null;
  }

  const isArchived =
    document.data.isArchived === undefined && !isCanonical
      ? false
      : document.data.isArchived;
  if (typeof isArchived !== "boolean") {
    return null;
  }

  const metadata = isCanonical
    ? existingCanonicalMetadata(document)
    : canonicalMetadata(fixture, document);
  if (metadata === null) {
    return null;
  }

  const canonical: Record<string, unknown> = {
    districtId: districtID,
    schoolId: schoolID,
    displayName,
    normalizedDisplayName: normalizeSearchText(displayName),
    grade,
    ...(studentIdentifier === undefined
      ? {}
      : {
          studentIdentifier,
          normalizedStudentIdentifier:
            normalizeSearchText(studentIdentifier),
        }),
    ...(dateOfBirth === undefined ? {} : { dateOfBirth }),
    ...(pronouns === undefined ? {} : { pronouns }),
    assignedMemberIDs,
    isArchived,
    schemaVersion: metadata.schemaVersion,
    recordVersion: metadata.recordVersion,
    createdAt: metadata.createdAt,
    createdBy: metadata.createdBy,
    updatedAt: metadata.updatedAt,
    updatedBy: metadata.updatedBy,
  };
  if (isCanonical) {
    return canonical;
  }

  return {
    ...canonical,
    migrationId: fixture.migrationId,
    legacyPath: document.path,
    legacyId: parsedPath.legacyID,
    checksum: checksumValue(document.data),
  };
}

function canonicalAssignedMemberIDs(
  data: Readonly<Record<string, unknown>>,
  requiresCanonicalArray: boolean,
): readonly string[] | null {
  const identifiers = new Set<string>();
  if (data.assignedMemberIDs !== undefined) {
    if (
      !Array.isArray(data.assignedMemberIDs) ||
      !data.assignedMemberIDs.every(isValidIdentifier)
    ) {
      return null;
    }
    data.assignedMemberIDs.forEach((identifier) => {
      identifiers.add(identifier as string);
    });
  } else if (requiresCanonicalArray) {
    return null;
  }

  if (!requiresCanonicalArray) {
    for (const field of ["assignedCounselorId", "primaryTeacherId"] as const) {
      const value = data[field];
      if (value === undefined || value === null) {
        continue;
      }
      if (!isValidIdentifier(value)) {
        return null;
      }
      identifiers.add(value);
    }
  }
  return [...identifiers].sort((left, right) => left.localeCompare(right));
}

function normalizeRequiredStudentText(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim().split(/\s+/u).join(" ");
  return normalized.length === 0 ? null : normalized;
}

function normalizeOptionalStudentText(
  value: unknown,
): string | undefined | null {
  if (value === undefined || value === null) {
    return undefined;
  }
  return normalizeRequiredStudentText(value);
}

function normalizeSearchText(value: string): string {
  return value
    .trim()
    .split(/\s+/u)
    .join(" ")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase();
}

interface CanonicalMetadata {
  readonly schemaVersion: number;
  readonly recordVersion: number;
  readonly createdAt: Timestamp;
  readonly createdBy: string;
  readonly updatedAt: Timestamp;
  readonly updatedBy: string;
}

function canonicalMetadata(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
): CanonicalMetadata {
  const fallbackActor = `migration:${fixture.migrationId}`;
  const createdAt = canonicalTimestamp(
    document.data.createdAt,
    fixture.migrationTimestamp,
  );
  const createdBy = isValidIdentifier(document.data.createdBy)
    ? document.data.createdBy
    : fallbackActor;
  return {
    schemaVersion: fixture.schemaVersion,
    recordVersion: positiveIntegerOrDefault(document.data.recordVersion, 1),
    createdAt,
    createdBy,
    updatedAt: canonicalTimestamp(document.data.updatedAt, createdAt),
    updatedBy: isValidIdentifier(document.data.updatedBy)
      ? document.data.updatedBy
      : createdBy,
  };
}

function existingCanonicalMetadata(
  document: LegacyFixtureDocument,
): CanonicalMetadata | null {
  const schemaVersion = document.data.schemaVersion;
  const recordVersion = document.data.recordVersion;
  const createdAt = optionalCanonicalTimestamp(document.data.createdAt);
  const updatedAt = optionalCanonicalTimestamp(document.data.updatedAt);
  if (
    typeof schemaVersion !== "number" ||
    !Number.isSafeInteger(schemaVersion) ||
    schemaVersion < 1 ||
    typeof recordVersion !== "number" ||
    !Number.isSafeInteger(recordVersion) ||
    recordVersion < 1 ||
    !(createdAt instanceof Timestamp) ||
    !(updatedAt instanceof Timestamp) ||
    !isValidIdentifier(document.data.createdBy) ||
    !isValidIdentifier(document.data.updatedBy)
  ) {
    return null;
  }
  return {
    schemaVersion,
    recordVersion,
    createdAt,
    createdBy: document.data.createdBy,
    updatedAt,
    updatedBy: document.data.updatedBy,
  };
}

function positiveIntegerOrDefault(value: unknown, fallback: number): number {
  return typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value > 0
    ? value
    : fallback;
}

function buildQuarantineWrite(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
  parsedPath: ParsedLegacyPath | null,
  reason: QuarantineReason,
  canonicalDestinationPath?: string,
): MigrationWrite {
  const destinationPath = `migrationQuarantine/${stableID(document.path)}`;
  const metadata = canonicalMetadata(fixture, document);
  const legacyID =
    parsedPath?.legacyID ?? document.path.split("/").at(-1) ?? "unknown";
  const checksum = checksumValue(document.data);
  return {
    manifest: buildManifest(
      fixture,
      document,
      destinationPath,
      "quarantine",
    ),
    data: {
      schemaVersion: fixture.schemaVersion,
      recordVersion: 1,
      createdAt: metadata.createdAt,
      createdBy: metadata.createdBy,
      updatedAt: metadata.updatedAt,
      updatedBy: metadata.updatedBy,
      migrationId: fixture.migrationId,
      legacyPath: document.path,
      legacyId: legacyID,
      checksum,
      reason,
      ...(canonicalDestinationPath === undefined
        ? {}
        : { canonicalDestinationPath }),
      sourceData: document.data,
    },
  };
}

function buildManifest(
  fixture: MigrationFixture,
  document: LegacyFixtureDocument,
  destinationPath: string,
  ownerResolution: MigrationManifest["ownerResolution"],
): MigrationManifest {
  const checksum = checksumValue(document.data);
  return {
    id: stableID(
      `${fixture.migrationId}:${document.path}:${destinationPath}:${checksum}`,
    ),
    sourcePath: document.path,
    destinationPath,
    schemaVersion: fixture.schemaVersion,
    ownerResolution,
    checksum,
  };
}

function assertUniqueDestinations(writes: readonly MigrationWrite[]): void {
  const seen = new Set<string>();
  for (const write of writes) {
    if (seen.has(write.manifest.destinationPath)) {
      throw new TypeError(
        `Duplicate migration destination: ${write.manifest.destinationPath}.`,
      );
    }
    seen.add(write.manifest.destinationPath);
  }
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
      sourceShape: "legacy",
      canonicalDistrictID: null,
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
      sourceShape: "legacy",
      canonicalDistrictID: null,
    };
  }
  if (segments.length === 2 && segments[0] === "students") {
    return {
      kind: "student",
      legacyID: segments[1] ?? "",
      userOwnerPath: null,
      sourceShape: "legacy",
      canonicalDistrictID: null,
    };
  }
  if (segments.length === 2 && segments[0] === "plans") {
    return {
      kind: "plan",
      legacyID: segments[1] ?? "",
      userOwnerPath: null,
      sourceShape: "legacy",
      canonicalDistrictID: null,
    };
  }
  if (
    segments.length === 4 &&
    segments[0] === "districts" &&
    segments[2] === "students"
  ) {
    return {
      kind: "student",
      legacyID: segments[3] ?? "",
      userOwnerPath: null,
      sourceShape: "canonical",
      canonicalDistrictID: segments[1] ?? "",
    };
  }
  if (
    segments.length === 4 &&
    segments[0] === "districts" &&
    segments[2] === "members"
  ) {
    return {
      kind: "member",
      legacyID: segments[3] ?? "",
      userOwnerPath: null,
      sourceShape: "canonical",
      canonicalDistrictID: segments[1] ?? "",
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
    parsedPath.canonicalDistrictID ??
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
  const collection =
    kind === "student"
      ? "students"
      : kind === "plan"
        ? "plans"
        : "members";
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
  const timestamp = optionalCanonicalTimestamp(value);
  if (timestamp instanceof Timestamp) {
    return timestamp;
  }
  return typeof fallback === "string"
    ? Timestamp.fromDate(new Date(fallback))
    : fallback;
}

function optionalCanonicalTimestamp(
  value: unknown,
): Timestamp | undefined | null {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (value instanceof Timestamp) {
    return value;
  }
  const date =
    typeof value === "number" && Number.isFinite(value)
      ? new Date(value * 1_000)
      : typeof value === "string"
        ? new Date(value)
        : null;
  if (date === null || !Number.isFinite(date.getTime())) {
    return null;
  }
  return Timestamp.fromDate(date);
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
