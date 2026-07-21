import { createHash } from "node:crypto";
import type {
  DocumentData,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";

export const capabilityValues = [
  "student.read.detail",
  "student.write.detail",
  "student.restricted.read",
  "student.restricted.write",
  "plan.approve",
  "staff.manage",
  "report.export",
  "audit.read",
] as const;

export type Capability = (typeof capabilityValues)[number];

export const staffRoleValues = [
  "teacher",
  "counselor",
  "socialWorker",
  "schoolAdministrator",
  "districtAdministrator",
] as const;

export type StaffRole = (typeof staffRoleValues)[number];

export interface TrustedCallableIdentity {
  readonly userID: string;
  readonly districtID: string;
  readonly membershipVersion: number;
}

export interface TrustedMembership {
  readonly userID: string;
  readonly districtID: string;
  readonly schoolIDs: ReadonlySet<string>;
  readonly role: StaffRole;
  readonly capabilities: ReadonlySet<Capability>;
  readonly assignedStudentIDs: ReadonlySet<string>;
  readonly version: number;
}

export interface PrivilegedBaseRequest {
  readonly districtID: string;
  readonly expectedRecordVersion: number;
  readonly idempotencyKey: string;
  readonly reasonCode: string;
}

export interface PrivilegedOperationResult {
  readonly operationID: string;
  readonly recordVersion: number;
  readonly replayed: boolean;
}

export interface PrivilegedMutationContext<T extends PrivilegedBaseRequest> {
  readonly data: T;
  readonly identity: TrustedCallableIdentity;
  readonly membership: TrustedMembership;
  readonly transaction: Transaction;
}

interface PrivilegedOperationSpec<T extends PrivilegedBaseRequest> {
  readonly action: string;
  readonly targetPath: (data: T) => string;
  readonly requiredCapability: Capability | null;
  readonly auditDetails: (data: T) => Readonly<Record<string, unknown>>;
  readonly mutate: (
    context: PrivilegedMutationContext<T>,
  ) => Promise<{ readonly recordVersion: number }>;
}

const allowedCapabilities = new Set<string>(capabilityValues);
const allowedStaffRoles = new Set<string>(staffRoleValues);
const utf8Encoder = new TextEncoder();

export function isValidIdentifier(value: unknown): value is string {
  if (typeof value !== "string") {
    return false;
  }

  return (
    value.length > 0 &&
    value === value.trim() &&
    utf8Encoder.encode(value).byteLength <= 1_500 &&
    !value.includes("/") &&
    value !== "." &&
    value !== ".." &&
    !/\p{Cc}/u.test(value)
  );
}

export function requireIdentifier(value: unknown, fieldName: string): string {
  if (!isValidIdentifier(value)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a safe opaque identifier.`,
    );
  }
  return value;
}

export function requireString(
  value: unknown,
  fieldName: string,
  maximumUTF8Bytes = 500,
): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value !== value.trim() ||
    utf8Encoder.encode(value).byteLength > maximumUTF8Bytes ||
    /\p{Cc}/u.test(value)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is missing or malformed.`,
    );
  }
  return value;
}

export function requireInteger(
  value: unknown,
  fieldName: string,
  minimum: number,
  maximum = Number.MAX_SAFE_INTEGER,
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be an integer between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

export function requireBoolean(value: unknown, fieldName: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a boolean.`,
    );
  }
  return value;
}

export function requireRecord(
  value: unknown,
  fieldName = "data",
): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be an object.`,
    );
  }
  return value as Record<string, unknown>;
}

export function rejectUnexpectedFields(
  value: Record<string, unknown>,
  allowedFields: ReadonlySet<string>,
): void {
  const unexpectedField = Object.keys(value).find(
    (field) => !allowedFields.has(field),
  );
  if (unexpectedField !== undefined) {
    throw new HttpsError(
      "invalid-argument",
      `Unexpected field: ${unexpectedField}.`,
    );
  }
}

export function requireIdentifierArray(
  value: unknown,
  fieldName: string,
  options: { readonly allowEmpty: boolean; readonly maximumCount?: number },
): string[] {
  const maximumCount = options.maximumCount ?? 500;
  if (
    !Array.isArray(value) ||
    (!options.allowEmpty && value.length === 0) ||
    value.length > maximumCount
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} has an invalid item count.`,
    );
  }

  const identifiers = value.map((item) => requireIdentifier(item, fieldName));
  if (new Set(identifiers).size !== identifiers.length) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must not contain duplicates.`,
    );
  }
  return identifiers;
}

export function requireEnum<T extends string>(
  value: unknown,
  fieldName: string,
  allowedValues: readonly T[],
): T {
  if (typeof value !== "string" || !allowedValues.includes(value as T)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is not an allowed value.`,
    );
  }
  return value as T;
}

export function parseBaseRequest(
  value: Record<string, unknown>,
): PrivilegedBaseRequest {
  return {
    districtID: requireIdentifier(value.districtID, "districtID"),
    expectedRecordVersion: requireInteger(
      value.expectedRecordVersion,
      "expectedRecordVersion",
      0,
    ),
    idempotencyKey: requireIdentifier(
      value.idempotencyKey,
      "idempotencyKey",
    ),
    reasonCode: requireString(value.reasonCode, "reasonCode", 100),
  };
}

export function parseTrustedCallableIdentity(
  request: Pick<CallableRequest<unknown>, "app" | "auth">,
): TrustedCallableIdentity {
  if (request.auth === undefined) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.app === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "A verified App Check token is required.",
    );
  }

  const userID = request.auth.uid;
  const districtID = request.auth.token.tmiDistrictID;
  const accessClass = request.auth.token.tmiAccessClass;
  const membershipVersion = request.auth.token.tmiMembershipVersion;

  if (
    !isValidIdentifier(userID) ||
    !isValidIdentifier(districtID) ||
    accessClass !== "staff" ||
    typeof membershipVersion !== "number" ||
    !Number.isSafeInteger(membershipVersion) ||
    membershipVersion < 1
  ) {
    throw new HttpsError(
      "permission-denied",
      "The trusted authorization claims are missing or malformed.",
    );
  }

  return { userID, districtID, membershipVersion };
}

export function assertDistrict(
  identity: TrustedCallableIdentity,
  districtID: string,
): void {
  if (identity.districtID !== districtID) {
    throw new HttpsError(
      "permission-denied",
      "The operation is outside the authenticated district.",
    );
  }
}

const parseMembership = (
  data: DocumentData,
  identity: TrustedCallableIdentity,
): TrustedMembership => {
  const schoolIDs = parseTrustedIdentifierArray(data.schoolIDs);
  const assignedStudentIDs = parseTrustedIdentifierArray(
    data.assignedStudentIDs,
  );
  const capabilities = parseTrustedCapabilities(data.capabilities);
  const role = data.role;
  const version = data.version;

  if (
    data.isActive !== true ||
    schoolIDs === null ||
    assignedStudentIDs === null ||
    capabilities === null ||
    typeof role !== "string" ||
    !allowedStaffRoles.has(role) ||
    typeof version !== "number" ||
    !Number.isSafeInteger(version) ||
    version < 1 ||
    version !== identity.membershipVersion ||
    (data.districtID !== undefined && data.districtID !== identity.districtID)
  ) {
    throw new HttpsError(
      "permission-denied",
      "The trusted membership is inactive, stale, or malformed.",
    );
  }

  return {
    userID: identity.userID,
    districtID: identity.districtID,
    schoolIDs: new Set(schoolIDs),
    role: role as StaffRole,
    capabilities: new Set(capabilities),
    assignedStudentIDs: new Set(assignedStudentIDs),
    version,
  };
};

const parseTrustedIdentifierArray = (value: unknown): string[] | null => {
  if (!Array.isArray(value) || value.length > 5_000) {
    return null;
  }
  const identifiers = value.filter(isValidIdentifier);
  if (
    identifiers.length !== value.length ||
    new Set(identifiers).size !== identifiers.length
  ) {
    return null;
  }
  return identifiers;
};

const parseTrustedCapabilities = (value: unknown): Capability[] | null => {
  if (!Array.isArray(value)) {
    return null;
  }
  const capabilities = value.filter(
    (item): item is Capability =>
      typeof item === "string" && allowedCapabilities.has(item),
  );
  if (
    capabilities.length !== value.length ||
    new Set(capabilities).size !== capabilities.length
  ) {
    return null;
  }
  return capabilities;
};

export async function requireTrustedMembership(
  firestore: Firestore,
  transaction: Transaction,
  identity: TrustedCallableIdentity,
): Promise<TrustedMembership> {
  const reference = firestore.doc(
    `districts/${identity.districtID}/members/${identity.userID}`,
  );
  const snapshot = await transaction.get(reference);
  if (!snapshot.exists) {
    throw new HttpsError(
      "permission-denied",
      "An active trusted membership is required.",
    );
  }
  return parseMembership(snapshot.data() ?? {}, identity);
}

export function requireCapability(
  membership: TrustedMembership,
  capability: Capability,
): void {
  if (!membership.capabilities.has(capability)) {
    throw new HttpsError(
      "permission-denied",
      `The ${capability} capability is required.`,
    );
  }
}

export function assertRecordVersion(
  actual: unknown,
  expected: number,
): void {
  if (
    typeof actual !== "number" ||
    !Number.isSafeInteger(actual) ||
    actual < 0
  ) {
    throw new HttpsError(
      "data-loss",
      "The stored record version is malformed.",
    );
  }
  if (actual !== expected) {
    throw new HttpsError(
      "aborted",
      "The record changed. Refresh and retry with its current version.",
      {
        kind: "record-version-conflict",
        expectedRecordVersion: expected,
        actualRecordVersion: actual,
      },
    );
  }
}

export function canReadStudentDetail(
  membership: TrustedMembership,
  studentID: string,
  schoolID: string,
): boolean {
  if (!isValidIdentifier(studentID) || !isValidIdentifier(schoolID)) {
    return false;
  }

  switch (membership.role) {
    case "teacher":
    case "counselor":
    case "socialWorker":
      return (
        membership.schoolIDs.has(schoolID) &&
        membership.assignedStudentIDs.has(studentID)
      );
    case "schoolAdministrator":
      return (
        membership.schoolIDs.has(schoolID) &&
        membership.capabilities.has("student.read.detail")
      );
    case "districtAdministrator":
      return membership.capabilities.has("student.read.detail");
  }
}

export function canManageSchool(
  membership: TrustedMembership,
  schoolID: string,
): boolean {
  if (!membership.capabilities.has("staff.manage")) {
    return false;
  }
  if (membership.role === "districtAdministrator") {
    return true;
  }
  return (
    membership.role === "schoolAdministrator" &&
    membership.schoolIDs.has(schoolID)
  );
}

export async function executePrivilegedOperation<
  T extends PrivilegedBaseRequest,
>(
  firestore: Firestore,
  request: CallableRequest<T>,
  data: T,
  spec: PrivilegedOperationSpec<T>,
): Promise<PrivilegedOperationResult> {
  const identity = parseTrustedCallableIdentity(request);
  assertDistrict(identity, data.districtID);
  const requestHash = hashCanonicalJSON(data);
  const targetPath = spec.targetPath(data);
  const auditReference = firestore.doc(
    `districts/${data.districtID}/auditEvents/${data.idempotencyKey}`,
  );

  return firestore.runTransaction(async (transaction) => {
    const priorAudit = await transaction.get(auditReference);
    if (priorAudit.exists) {
      const prior = priorAudit.data() ?? {};
      const isExactReplay =
        prior.action === spec.action &&
        prior.actorUserID === identity.userID &&
        prior.requestHash === requestHash;
      if (isExactReplay) {
        const priorResult = requireRecord(prior.result, "audit result");
        const recordVersion = priorResult.recordVersion;
        if (
          typeof recordVersion !== "number" ||
          !Number.isSafeInteger(recordVersion) ||
          recordVersion < 0
        ) {
          throw new HttpsError(
            "data-loss",
            "The prior operation result is malformed.",
          );
        }
        return {
          operationID: data.idempotencyKey,
          recordVersion,
          replayed: true,
        };
      }
    }

    const membership = await requireTrustedMembership(
      firestore,
      transaction,
      identity,
    );
    if (spec.requiredCapability !== null) {
      requireCapability(membership, spec.requiredCapability);
    }

    if (priorAudit.exists) {
      throw new HttpsError(
        "already-exists",
        "The idempotency key was already used for a different operation.",
        { kind: "idempotency-key-reused" },
      );
    }

    const mutationResult = await spec.mutate({
      data,
      identity,
      membership,
      transaction,
    });
    const auditDetails = spec.auditDetails(data);
    transaction.create(auditReference, {
      schemaVersion: 1,
      recordVersion: 1,
      action: spec.action,
      actorUserID: identity.userID,
      districtID: data.districtID,
      targetPath,
      reasonCode: data.reasonCode,
      requestHash,
      details: auditDetails,
      result: { recordVersion: mutationResult.recordVersion },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      operationID: data.idempotencyKey,
      recordVersion: mutationResult.recordVersion,
      replayed: false,
    };
  });
}

function hashCanonicalJSON(value: unknown): string {
  return createHash("sha256")
    .update(JSON.stringify(canonicalize(value)))
    .digest("hex");
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
