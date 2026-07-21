import { createHash } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {
  assertRecordVersion,
  canManageSchool,
  canReadStudentDetail,
  capabilityValues,
  executePrivilegedOperation,
  parseBaseRequest,
  rejectUnexpectedFields,
  requireBoolean,
  requireEnum,
  requireIdentifier,
  requireIdentifierArray,
  requireInteger,
  requireRecord,
  requireString,
  staffRoleValues,
  type Capability,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
  type StaffRole,
  type TrustedMembership,
} from "./authz.js";
import {
  createProductionDeletePersonalAccountDataHandler,
} from "./accountDeletion.js";
import {
  createProductionProvisionStaffMembershipHandler,
  type ProvisionStaffMembershipRequest,
} from "./invitations.js";

export type { DeletePersonalAccountDataRequest } from "./accountDeletion.js";
export type { ProvisionStaffMembershipRequest } from "./invitations.js";

if (getApps().length === 0) {
  const projectID =
    process.env.GCLOUD_PROJECT ??
    (process.env.FIRESTORE_EMULATOR_HOST === undefined
      ? undefined
      : "demo-tmi");
  if (projectID === undefined) {
    initializeApp();
  } else {
    initializeApp({ projectId: projectID });
  }
}

const callableOptions = {
  enforceAppCheck: true,
  region: "us-central1",
} as const;

const baseFields = [
  "districtID",
  "expectedRecordVersion",
  "idempotencyKey",
  "reasonCode",
] as const;

const maximumStudentAssignments = 200;

const allowedPlanStatuses = [
  "draft",
  "submitted",
  "changesRequested",
  "approved",
  "active",
  "completed",
  "archived",
] as const;

type PlanStatus = (typeof allowedPlanStatuses)[number];

const allowedPlanTransitions: Readonly<Record<PlanStatus, readonly PlanStatus[]>> = {
  draft: ["submitted"],
  submitted: ["changesRequested", "approved"],
  changesRequested: ["submitted"],
  approved: ["active"],
  active: ["completed"],
  completed: ["archived"],
  archived: [],
};

export interface MutateMembershipRequest extends PrivilegedBaseRequest {
  readonly targetUserID: string;
  readonly role: StaffRole;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly assignedStudentIDs: readonly string[];
  readonly isActive: boolean;
}

export interface GrantStudentDetailAccessRequest
  extends PrivilegedBaseRequest {
  readonly targetUserID: string;
  readonly studentID: string;
}

export interface CreateStudentRequest extends PrivilegedBaseRequest {
  readonly schoolID: string;
  readonly displayName: string;
  readonly grade: string;
  readonly studentIdentifier?: string;
  readonly dateOfBirth?: string;
  readonly pronouns?: string;
  readonly assignedMemberIDs: readonly string[];
}

export interface UpdateStudentRequest extends CreateStudentRequest {
  readonly studentID: string;
}

export interface ArchiveStudentRequest extends PrivilegedBaseRequest {
  readonly studentID: string;
}

export interface StudentMutationMembership {
  readonly districtID: string;
  readonly schoolIDs: readonly string[];
  readonly role: StaffRole;
  readonly capabilities: readonly Capability[];
  readonly assignedStudentIDs: readonly string[];
  readonly isActive: boolean;
  readonly version: number;
}

export interface StudentMutationResult extends PrivilegedOperationResult {
  readonly studentID: string;
  readonly membership: StudentMutationMembership;
}

export interface TransitionPlanRequest extends PrivilegedBaseRequest {
  readonly planID: string;
  readonly nextStatus: PlanStatus;
}

export interface IssueStudentModeSessionRequest
  extends PrivilegedBaseRequest {
  readonly studentID: string;
  readonly assignmentIDs: readonly string[];
  readonly durationMinutes: number;
}

const exportTypeValues = [
  "professionalPlan",
  "interventionSummary",
  "progressReport",
  "meetingSummary",
  "districtAggregate",
] as const;

type ExportType = (typeof exportTypeValues)[number];

export interface RequestSensitiveExportRequest extends PrivilegedBaseRequest {
  readonly exportType: ExportType;
  readonly schoolID: string | null;
  readonly studentIDs: readonly string[];
}

const privilegedAuditEventValues = [
  "studentDetailDrilldown",
  "restrictedRecordRead",
  "studentModeEntry",
  "studentModeLock",
  "studentModeResume",
  "studentModeExit",
  "officialRecordAIUse",
] as const;

type PrivilegedAuditEvent = (typeof privilegedAuditEventValues)[number];

export interface RecordPrivilegedAuditEventRequest
  extends PrivilegedBaseRequest {
  readonly eventType: PrivilegedAuditEvent;
  readonly targetPath: string;
}

const withBaseFields = (...fields: readonly string[]): ReadonlySet<string> =>
  new Set([...baseFields, ...fields]);

const parseCapabilityArray = (value: unknown): Capability[] => {
  if (!Array.isArray(value) || value.length > capabilityValues.length) {
    throw new HttpsError(
      "invalid-argument",
      "capabilities has an invalid item count.",
    );
  }
  const parsed = value.map((item) =>
    requireEnum(item, "capabilities", capabilityValues),
  );
  if (new Set(parsed).size !== parsed.length) {
    throw new HttpsError(
      "invalid-argument",
      "capabilities must not contain duplicates.",
    );
  }
  return parsed;
};

const parseMutateMembershipRequest = (
  value: unknown,
): MutateMembershipRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields(
      "targetUserID",
      "role",
      "schoolIDs",
      "capabilities",
      "assignedStudentIDs",
      "isActive",
    ),
  );
  return {
    ...parseBaseRequest(data),
    targetUserID: requireIdentifier(data.targetUserID, "targetUserID"),
    role: requireEnum(data.role, "role", staffRoleValues),
    schoolIDs: requireIdentifierArray(data.schoolIDs, "schoolIDs", {
      allowEmpty: true,
      maximumCount: 100,
    }),
    capabilities: parseCapabilityArray(data.capabilities),
    assignedStudentIDs: requireIdentifierArray(
      data.assignedStudentIDs,
      "assignedStudentIDs",
      { allowEmpty: true, maximumCount: 5_000 },
    ),
    isActive: requireBoolean(data.isActive, "isActive"),
  };
};

const parseGrantStudentDetailAccessRequest = (
  value: unknown,
): GrantStudentDetailAccessRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("targetUserID", "studentID"),
  );
  return {
    ...parseBaseRequest(data),
    targetUserID: requireIdentifier(data.targetUserID, "targetUserID"),
    studentID: requireIdentifier(data.studentID, "studentID"),
  };
};

const parseOptionalStudentText = (
  value: unknown,
  fieldName: string,
  maximumCharacters: number,
  maximumUTF8Bytes: number,
  collapseWhitespace: boolean,
): string | undefined => {
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is missing or malformed.`,
    );
  }
  const normalized = collapseWhitespace
    ? value.trim().split(/\s+/u).join(" ")
    : value.trim();
  if (normalized.length === 0) {
    return undefined;
  }
  if (
    [...normalized].length > maximumCharacters ||
    Buffer.byteLength(normalized, "utf8") > maximumUTF8Bytes ||
    /\p{Cc}/u.test(normalized)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is missing or malformed.`,
    );
  }
  return normalized;
};

const parseRequiredStudentText = (
  value: unknown,
  fieldName: string,
  maximumCharacters: number,
  maximumUTF8Bytes: number,
): string => {
  const parsed = parseOptionalStudentText(
    value,
    fieldName,
    maximumCharacters,
    maximumUTF8Bytes,
    true,
  );
  if (parsed === undefined) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is missing or malformed.`,
    );
  }
  return parsed;
};

const parseOptionalDateOfBirth = (value: unknown): string | undefined => {
  if (value === undefined) {
    return undefined;
  }
  if (
    typeof value !== "string" ||
    value.length > 40 ||
    !/^\d{4}-\d{2}-\d{2}(?:T.*)?$/u.test(value)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "dateOfBirth must be a valid ISO 8601 date.",
    );
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime()) || parsed.getTime() > Date.now()) {
    throw new HttpsError(
      "invalid-argument",
      "dateOfBirth must be a valid non-future ISO 8601 date.",
    );
  }
  return parsed.toISOString();
};

const parseStudentDraftFields = (
  data: Record<string, unknown>,
): Omit<CreateStudentRequest, keyof PrivilegedBaseRequest> => {
  const studentIdentifier = parseOptionalStudentText(
    data.studentIdentifier,
    "studentIdentifier",
    128,
    512,
    false,
  );
  const pronouns = parseOptionalStudentText(
    data.pronouns,
    "pronouns",
    80,
    320,
    true,
  );
  const dateOfBirth = parseOptionalDateOfBirth(data.dateOfBirth);
  return {
    schoolID: requireIdentifier(data.schoolID, "schoolID"),
    displayName: parseRequiredStudentText(
      data.displayName,
      "displayName",
      120,
      512,
    ),
    grade: parseRequiredStudentText(data.grade, "grade", 32, 128),
    ...(studentIdentifier === undefined ? {} : { studentIdentifier }),
    ...(dateOfBirth === undefined ? {} : { dateOfBirth }),
    ...(pronouns === undefined ? {} : { pronouns }),
    assignedMemberIDs: requireIdentifierArray(
      data.assignedMemberIDs,
      "assignedMemberIDs",
      { allowEmpty: true, maximumCount: maximumStudentAssignments },
    ).sort(),
  };
};

const studentDraftFieldNames = [
  "schoolID",
  "displayName",
  "grade",
  "studentIdentifier",
  "dateOfBirth",
  "pronouns",
  "assignedMemberIDs",
] as const;

const parseCreateStudentRequest = (value: unknown): CreateStudentRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, withBaseFields(...studentDraftFieldNames));
  return { ...parseBaseRequest(data), ...parseStudentDraftFields(data) };
};

const parseUpdateStudentRequest = (value: unknown): UpdateStudentRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("studentID", ...studentDraftFieldNames),
  );
  return {
    ...parseBaseRequest(data),
    studentID: requireIdentifier(data.studentID, "studentID"),
    ...parseStudentDraftFields(data),
  };
};

const parseArchiveStudentRequest = (value: unknown): ArchiveStudentRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, withBaseFields("studentID"));
  return {
    ...parseBaseRequest(data),
    studentID: requireIdentifier(data.studentID, "studentID"),
  };
};

const parseTransitionPlanRequest = (value: unknown): TransitionPlanRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, withBaseFields("planID", "nextStatus"));
  return {
    ...parseBaseRequest(data),
    planID: requireIdentifier(data.planID, "planID"),
    nextStatus: requireEnum(
      data.nextStatus,
      "nextStatus",
      allowedPlanStatuses,
    ),
  };
};

const parseIssueStudentModeSessionRequest = (
  value: unknown,
): IssueStudentModeSessionRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("studentID", "assignmentIDs", "durationMinutes"),
  );
  return {
    ...parseBaseRequest(data),
    studentID: requireIdentifier(data.studentID, "studentID"),
    assignmentIDs: requireIdentifierArray(
      data.assignmentIDs,
      "assignmentIDs",
      { allowEmpty: false, maximumCount: 100 },
    ),
    durationMinutes: requireInteger(
      data.durationMinutes,
      "durationMinutes",
      1,
      60,
    ),
  };
};

const parseRequestSensitiveExportRequest = (
  value: unknown,
): RequestSensitiveExportRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("exportType", "schoolID", "studentIDs"),
  );
  const schoolID =
    data.schoolID === null || data.schoolID === undefined
      ? null
      : requireIdentifier(data.schoolID, "schoolID");
  return {
    ...parseBaseRequest(data),
    exportType: requireEnum(data.exportType, "exportType", exportTypeValues),
    schoolID,
    studentIDs: requireIdentifierArray(data.studentIDs, "studentIDs", {
      allowEmpty: true,
      maximumCount: 50,
    }),
  };
};

const parseRecordPrivilegedAuditEventRequest = (
  value: unknown,
): RecordPrivilegedAuditEventRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("eventType", "targetPath"),
  );
  const base = parseBaseRequest(data);
  const targetPath = requireDistrictDocumentPath(
    data.targetPath,
    base.districtID,
  );
  return {
    ...base,
    eventType: requireEnum(
      data.eventType,
      "eventType",
      privilegedAuditEventValues,
    ),
    targetPath,
  };
};

const requireDistrictDocumentPath = (
  value: unknown,
  districtID: string,
): string => {
  const path = requireString(value, "targetPath", 1_500);
  const segments = path.split("/");
  if (
    segments.length < 4 ||
    segments.length % 2 !== 0 ||
    segments[0] !== "districts" ||
    segments[1] !== districtID ||
    !segments.every((segment) => {
      try {
        requireIdentifier(segment, "targetPath");
        return true;
      } catch {
        return false;
      }
    })
  ) {
    throw new HttpsError(
      "invalid-argument",
      "targetPath must be a document in the authenticated district.",
    );
  }
  return path;
};

const requireExistingData = (
  snapshot: DocumentSnapshot,
  resourceName: string,
): DocumentData => {
  if (!snapshot.exists) {
    throw new HttpsError("not-found", `${resourceName} was not found.`);
  }
  return snapshot.data() ?? {};
};

const requireSchoolID = (data: DocumentData, resourceName: string): string => {
  try {
    return requireIdentifier(data.schoolId, `${resourceName}.schoolId`);
  } catch {
    throw new HttpsError(
      "data-loss",
      `${resourceName} does not have a valid school boundary.`,
    );
  }
};

const requireStoredIdentifierArray = (
  value: unknown,
  fieldName: string,
): string[] => {
  try {
    return requireIdentifierArray(value, fieldName, {
      allowEmpty: true,
      maximumCount: 5_000,
    });
  } catch {
    throw new HttpsError("data-loss", `${fieldName} is malformed.`);
  }
};

const requireTargetVersion = (
  snapshot: DocumentSnapshot,
  expectedRecordVersion: number,
  resourceName: string,
): DocumentData | null => {
  if (!snapshot.exists) {
    if (expectedRecordVersion !== 0) {
      throw new HttpsError("not-found", `${resourceName} was not found.`);
    }
    return null;
  }
  const data = snapshot.data() ?? {};
  assertRecordVersion(data.recordVersion ?? data.version, expectedRecordVersion);
  return data;
};

const requireStaffMutationScope = (
  caller: TrustedMembership,
  targetUserID: string,
  targetRole: StaffRole,
  targetSchoolIDs: readonly string[],
): void => {
  if (caller.userID === targetUserID) {
    throw new HttpsError(
      "failed-precondition",
      "Staff authorization cannot be changed by the same account.",
    );
  }
  if (caller.role === "districtAdministrator") {
    return;
  }
  if (
    caller.role !== "schoolAdministrator" ||
    targetRole === "districtAdministrator" ||
    targetSchoolIDs.length === 0 ||
    !targetSchoolIDs.every((schoolID) => caller.schoolIDs.has(schoolID))
  ) {
    throw new HttpsError(
      "permission-denied",
      "The target membership is outside the administrator's school scope.",
    );
  }
};

const refreshTrustedClaims = async (
  targetUserID: string,
  districtID: string,
  membershipVersion: number,
): Promise<void> => {
  const auth = getAuth();
  const user = await auth.getUser(targetUserID);
  await auth.setCustomUserClaims(targetUserID, {
    ...(user.customClaims ?? {}),
    tmiDistrictID: districtID,
    tmiAccessClass: "staff",
    tmiMembershipVersion: membershipVersion,
  });
};

const mutateMembershipHandler = async (
  request: CallableRequest<MutateMembershipRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseMutateMembershipRequest(request.data);
  const firestore = getFirestore();
  const result = await executePrivilegedOperation(
    firestore,
    request,
    data,
    {
      action: "membership.mutate",
      targetPath: (input) =>
        `districts/${input.districtID}/members/${input.targetUserID}`,
      requiredCapability: "staff.manage",
      auditDetails: (input) => ({
        targetUserID: input.targetUserID,
        nextRole: input.role,
        nextActiveState: input.isActive,
      }),
      mutate: async ({ transaction, membership, identity }) => {
        if (data.expectedRecordVersion === 0) {
          throw new HttpsError(
            "invalid-argument",
            "Membership onboarding is a separate trusted operation.",
          );
        }
        requireStaffMutationScope(
          membership,
          data.targetUserID,
          data.role,
          data.schoolIDs,
        );
        const reference = firestore.doc(
          `districts/${data.districtID}/members/${data.targetUserID}`,
        );
        const snapshot = await transaction.get(reference);
        const existing = requireTargetVersion(
          snapshot,
          data.expectedRecordVersion,
          "Membership",
        );
        if (existing === null) {
          throw new HttpsError("not-found", "Membership was not found.");
        }
        const existingRole = requireEnum(
          existing.role,
          "membership.role",
          staffRoleValues,
        );
        const existingSchoolIDs = requireStoredIdentifierArray(
          existing.schoolIDs,
          "membership.schoolIDs",
        );
        const existingAssignedStudentIDs = requireStoredIdentifierArray(
          existing.assignedStudentIDs,
          "membership.assignedStudentIDs",
        ).sort();
        const requestedAssignedStudentIDs = [...data.assignedStudentIDs].sort();
        if (
          existingAssignedStudentIDs.length !==
            requestedAssignedStudentIDs.length ||
          existingAssignedStudentIDs.some(
            (studentID, index) =>
              studentID !== requestedAssignedStudentIDs[index],
          )
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Student assignments must be changed through a trusted student mutation.",
          );
        }
        requireStaffMutationScope(
          membership,
          data.targetUserID,
          existingRole,
          existingSchoolIDs,
        );
        const nextVersion = data.expectedRecordVersion + 1;
        transaction.set(reference, {
          schemaVersion: 1,
          recordVersion: nextVersion,
          version: nextVersion,
          districtID: data.districtID,
          schoolIDs: [...data.schoolIDs],
          role: data.role,
          capabilities: [...data.capabilities],
          assignedStudentIDs: existingAssignedStudentIDs,
          isActive: data.isActive,
          createdAt: existing.createdAt ?? FieldValue.serverTimestamp(),
          createdBy: existing.createdBy ?? identity.userID,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: identity.userID,
        });
        return { recordVersion: nextVersion };
      },
    },
  );
  await refreshTrustedClaims(
    data.targetUserID,
    data.districtID,
    result.recordVersion,
  );
  return result;
};

export const createGrantStudentDetailAccessHandler = (
  dependencies: StudentMutationDependencies,
) => async (
  request: CallableRequest<GrantStudentDetailAccessRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseGrantStudentDetailAccessRequest(request.data);
  const result = await executePrivilegedOperation(
    dependencies.firestore,
    request,
    data,
    {
      action: "student.detailAccess.grant",
      targetPath: (input) =>
        `districts/${input.districtID}/members/${input.targetUserID}`,
      requiredCapability: "staff.manage",
      auditDetails: (input) => ({
        targetUserID: input.targetUserID,
        studentID: input.studentID,
      }),
      mutate: async ({ transaction, membership, identity }) => {
        if (membership.userID === data.targetUserID) {
          throw new HttpsError(
            "failed-precondition",
            "An administrator cannot grant their own detail access.",
          );
        }
        const studentReference = dependencies.firestore.doc(
          `districts/${data.districtID}/students/${data.studentID}`,
        );
        const targetReference = dependencies.firestore.doc(
          `districts/${data.districtID}/members/${data.targetUserID}`,
        );
        const [studentSnapshot, targetSnapshot] = await Promise.all([
          transaction.get(studentReference),
          transaction.get(targetReference),
        ]);
        const student = requireCanonicalStudent(
          studentSnapshot,
          data.districtID,
        );
        const schoolID = requireSchoolID(student, "Student");
        if (!canManageSchool(membership, schoolID)) {
          throw new HttpsError(
            "permission-denied",
            "The student is outside the administrator's school scope.",
          );
        }
        const target = requireTargetVersion(
          targetSnapshot,
          data.expectedRecordVersion,
          "Membership",
        );
        if (target === null) {
          throw new HttpsError("not-found", "Membership was not found.");
        }
        const targetMembership = parseAssignmentMembership(
          targetSnapshot,
          data.districtID,
          schoolID,
          true,
        );
        const memberAssignments = new Set(
          targetMembership.assignedStudentIDs,
        );
        const studentAssignments = new Set(
          requireStoredIdentifierArray(
            student.assignedMemberIDs,
            "student.assignedMemberIDs",
          ),
        );
        if (
          studentAssignments.size >= maximumStudentAssignments &&
          !studentAssignments.has(data.targetUserID)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The student has reached the maximum staff assignment count.",
          );
        }
        if (
          memberAssignments.has(data.studentID) &&
          studentAssignments.has(data.targetUserID)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The target member already has student detail access.",
          );
        }
        const studentRecordVersion = student.recordVersion;
        if (
          typeof studentRecordVersion !== "number" ||
          !Number.isSafeInteger(studentRecordVersion) ||
          studentRecordVersion < 1
        ) {
          throw new HttpsError(
            "data-loss",
            "The student record version is malformed.",
          );
        }
        memberAssignments.add(data.studentID);
        studentAssignments.add(data.targetUserID);
        const nextVersion = data.expectedRecordVersion + 1;
        transaction.update(targetReference, {
          assignedStudentIDs: [...memberAssignments].sort(),
          recordVersion: nextVersion,
          version: nextVersion,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: identity.userID,
        });
        transaction.update(studentReference, {
          assignedMemberIDs: [...studentAssignments].sort(),
          recordVersion: studentRecordVersion + 1,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: identity.userID,
        });
        return { recordVersion: nextVersion };
      },
    },
  );
  await dependencies.refreshTrustedClaimsForUser(
    data.targetUserID,
    data.districtID,
  );
  return result;
};

const grantStudentDetailAccessHandler = async (
  request: CallableRequest<GrantStudentDetailAccessRequest>,
): Promise<PrivilegedOperationResult> =>
  createGrantStudentDetailAccessHandler({
    firestore: getFirestore(),
    refreshTrustedClaimsForUser: refreshCurrentTrustedClaimsForUser,
  })(request);

interface StudentMutationDependencies {
  readonly firestore: Firestore;
  readonly refreshTrustedClaimsForUser: (
    userID: string,
    districtID: string,
  ) => Promise<void>;
}

interface AssignmentMembershipRecord {
  readonly reference: DocumentReference;
  readonly assignedStudentIDs: Set<string>;
  readonly version: number;
}

const normalizeSearchText = (value: string): string =>
  value
    .trim()
    .split(/\s+/u)
    .join(" ")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase();

const studentIDForCreate = (data: CreateStudentRequest): string =>
  `student_${createHash("sha256")
    .update(`${data.districtID}:${data.idempotencyKey}`)
    .digest("hex")
    .slice(0, 32)}`;

const studentClaimRefreshPath = (
  districtID: string,
  operationID: string,
): string =>
  `districts/${districtID}/studentClaimRefreshes/${operationID}`;

const areEqualIdentifierSets = (
  left: ReadonlySet<string>,
  right: ReadonlySet<string>,
): boolean =>
  left.size === right.size && [...left].every((value) => right.has(value));

const requireCanonicalStudent = (
  snapshot: DocumentSnapshot,
  districtID: string,
): DocumentData => {
  const data = requireExistingData(snapshot, "Student");
  if (data.districtId !== districtID) {
    throw new HttpsError(
      "data-loss",
      "The student does not have a valid district boundary.",
    );
  }
  requireSchoolID(data, "Student");
  requireStoredIdentifierArray(
    data.assignedMemberIDs,
    "student.assignedMemberIDs",
  );
  if (typeof data.isArchived !== "boolean") {
    throw new HttpsError(
      "data-loss",
      "The student archive state is malformed.",
    );
  }
  return data;
};

const canCreateStudentInSchool = (
  membership: TrustedMembership,
  schoolID: string,
): boolean => {
  switch (membership.role) {
    case "teacher":
    case "counselor":
      return membership.schoolIDs.has(schoolID);
    case "socialWorker":
      return false;
    case "schoolAdministrator":
      return (
        membership.schoolIDs.has(schoolID) &&
        membership.capabilities.has("student.write.detail")
      );
    case "districtAdministrator":
      return membership.capabilities.has("student.write.detail");
  }
};

const canWriteCanonicalStudent = (
  membership: TrustedMembership,
  studentID: string,
  schoolID: string,
  assignedMemberIDs: ReadonlySet<string>,
): boolean => {
  switch (membership.role) {
    case "teacher":
    case "counselor":
      return (
        membership.schoolIDs.has(schoolID) &&
        membership.assignedStudentIDs.has(studentID) &&
        assignedMemberIDs.has(membership.userID)
      );
    case "socialWorker":
      return false;
    case "schoolAdministrator":
      return (
        membership.schoolIDs.has(schoolID) &&
        membership.capabilities.has("student.write.detail")
      );
    case "districtAdministrator":
      return membership.capabilities.has("student.write.detail");
  }
};

const requireCreateAssignmentScope = (
  membership: TrustedMembership,
  schoolID: string,
  assignedMemberIDs: ReadonlySet<string>,
): void => {
  if (
    (membership.role === "teacher" || membership.role === "counselor") &&
    (!assignedMemberIDs.has(membership.userID) ||
      assignedMemberIDs.size !== 1)
  ) {
    throw new HttpsError(
      "permission-denied",
      "Ordinary roster creators must assign themselves and cannot expand assignment scope.",
    );
  }
  const containsAnotherMember = [...assignedMemberIDs].some(
    (memberID) => memberID !== membership.userID,
  );
  if (containsAnotherMember && !canManageSchool(membership, schoolID)) {
    throw new HttpsError(
      "permission-denied",
      "Assigning another staff member requires staff management scope.",
    );
  }
};

const assertNoStudentDuplicate = async (
  transaction: Transaction,
  firestore: Firestore,
  data: CreateStudentRequest,
  excludingStudentID?: string,
): Promise<void> => {
  const collection = firestore.collection(
    `districts/${data.districtID}/students`,
  );
  const normalizedDisplayName = normalizeSearchText(data.displayName);
  const normalizedGrade = normalizeSearchText(data.grade);
  const nameQuery = collection
    .where("schoolId", "==", data.schoolID)
    .where("normalizedDisplayName", "==", normalizedDisplayName);
  const identifierQuery =
    data.studentIdentifier === undefined
      ? null
      : collection
          .where("schoolId", "==", data.schoolID)
          .where(
            "normalizedStudentIdentifier",
            "==",
            normalizeSearchText(data.studentIdentifier),
          );
  const nameMatches = await transaction.get(nameQuery);
  const identifierMatches =
    identifierQuery === null
      ? null
      : await transaction.get(identifierQuery);
  const candidateIDs = new Set<string>();
  for (const snapshot of nameMatches.docs) {
    if (snapshot.id === excludingStudentID) {
      continue;
    }
    const grade = snapshot.get("grade");
    if (
      typeof grade === "string" &&
      normalizeSearchText(grade) === normalizedGrade
    ) {
      candidateIDs.add(snapshot.id);
    }
  }
  for (const snapshot of identifierMatches?.docs ?? []) {
    if (snapshot.id !== excludingStudentID) {
      candidateIDs.add(snapshot.id);
    }
  }
  if (candidateIDs.size > 0) {
    throw new HttpsError(
      "already-exists",
      "A matching student already exists in this school, including archived records.",
      {
        kind: "student-duplicate",
        candidateIDs: [...candidateIDs].sort(),
      },
    );
  }
};

const assertStudentRecordVersion = (
  actualRecordVersion: unknown,
  expectedRecordVersion: number,
): void => {
  if (
    typeof actualRecordVersion !== "number" ||
    !Number.isSafeInteger(actualRecordVersion) ||
    actualRecordVersion < 1
  ) {
    throw new HttpsError(
      "data-loss",
      "The student record version is malformed.",
    );
  }
  if (actualRecordVersion !== expectedRecordVersion) {
    throw new HttpsError(
      "aborted",
      "The student changed. Refresh and retry with its current version.",
      {
        kind: "record-version-conflict",
        expectedRecordVersion,
        actualRecordVersion,
      },
    );
  }
};

const parseAssignmentMembership = (
  snapshot: DocumentSnapshot,
  districtID: string,
  schoolID: string,
  requiresActiveSchoolScope: boolean,
): AssignmentMembershipRecord => {
  const data = requireExistingData(snapshot, "Assigned membership");
  const schoolIDs = requireStoredIdentifierArray(
    data.schoolIDs,
    "membership.schoolIDs",
  );
  const assignedStudentIDs = requireStoredIdentifierArray(
    data.assignedStudentIDs,
    "membership.assignedStudentIDs",
  );
  const version = data.version;
  const recordVersion = data.recordVersion ?? version;
  if (
    data.districtID !== undefined &&
    data.districtID !== districtID
  ) {
    throw new HttpsError(
      "data-loss",
      "An assigned membership crosses the student district boundary.",
    );
  }
  if (
    typeof version !== "number" ||
    !Number.isSafeInteger(version) ||
    version < 1 ||
    recordVersion !== version
  ) {
    throw new HttpsError(
      "data-loss",
      "An assigned membership version is malformed.",
    );
  }
  if (
    requiresActiveSchoolScope &&
    (data.isActive !== true || !schoolIDs.includes(schoolID))
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Every assigned staff member must have an active membership in the student's school.",
    );
  }
  return {
    reference: snapshot.ref,
    assignedStudentIDs: new Set(assignedStudentIDs),
    version,
  };
};

const applyStudentAssignmentChanges = async (
  transaction: Transaction,
  firestore: Firestore,
  parameters: {
    readonly districtID: string;
    readonly schoolID: string;
    readonly studentID: string;
    readonly operationID: string;
    readonly actorUserID: string;
    readonly previousMemberIDs: ReadonlySet<string>;
    readonly nextMemberIDs: ReadonlySet<string>;
    readonly validateAllNextMemberScopes?: boolean;
  },
): Promise<void> => {
  const affectedUserIDs = [...new Set([
    ...parameters.previousMemberIDs,
    ...parameters.nextMemberIDs,
  ])]
    .filter(
      (userID) =>
        parameters.previousMemberIDs.has(userID) !==
        parameters.nextMemberIDs.has(userID),
    )
    .sort();
  const memberIDsToRead = [...new Set([
    ...affectedUserIDs,
    ...(parameters.validateAllNextMemberScopes === true
      ? parameters.nextMemberIDs
      : []),
  ])].sort();
  if (memberIDsToRead.length === 0) {
    return;
  }
  const references = memberIDsToRead.map((userID) =>
    firestore.doc(`districts/${parameters.districtID}/members/${userID}`),
  );
  const snapshots = await Promise.all(
    references.map(async (reference) => transaction.get(reference)),
  );
  const memberships = new Map(
    snapshots.map((snapshot, index) => {
      const userID = memberIDsToRead[index] ?? "";
      return [
        userID,
        parseAssignmentMembership(
          snapshot,
          parameters.districtID,
          parameters.schoolID,
          parameters.nextMemberIDs.has(userID),
        ),
      ] as const;
    }),
  );
  for (const userID of affectedUserIDs) {
    const membership = memberships.get(userID);
    if (membership === undefined) {
      throw new HttpsError("data-loss", "An assignment member is missing.");
    }
    const nextAssignments = new Set(membership.assignedStudentIDs);
    if (parameters.nextMemberIDs.has(userID)) {
      nextAssignments.add(parameters.studentID);
    } else {
      nextAssignments.delete(parameters.studentID);
    }
    const nextVersion = membership.version + 1;
    transaction.update(membership.reference, {
      assignedStudentIDs: [...nextAssignments].sort(),
      version: nextVersion,
      recordVersion: nextVersion,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: parameters.actorUserID,
    });
  }
  if (affectedUserIDs.length > 0) {
    transaction.create(
      firestore.doc(
        studentClaimRefreshPath(parameters.districtID, parameters.operationID),
      ),
      {
        schemaVersion: 1,
        districtID: parameters.districtID,
        affectedUserIDs,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: parameters.actorUserID,
      },
    );
  }
};

export const createStudentClaimRefreshHandler = (
  dependencies: StudentMutationDependencies,
) => async (input: {
  readonly districtID: string;
  readonly operationID: string;
}): Promise<void> => {
  const districtID = requireIdentifier(input.districtID, "districtID");
  const operationID = requireIdentifier(input.operationID, "operationID");
  const reference = dependencies.firestore.doc(
    studentClaimRefreshPath(districtID, operationID),
  );
  const snapshot = await reference.get();
  if (!snapshot.exists || snapshot.get("completedAt") !== undefined) {
    return;
  }
  if (snapshot.get("districtID") !== districtID) {
    throw new HttpsError(
      "data-loss",
      "The claim refresh task crosses its district boundary.",
    );
  }
  const affectedUserIDs = requireStoredIdentifierArray(
    snapshot.get("affectedUserIDs"),
    "claimRefresh.affectedUserIDs",
  );
  const rawCompletedUserIDs = snapshot.get("completedUserIDs");
  const completedUserIDs = new Set(
    rawCompletedUserIDs === undefined
      ? []
      : requireStoredIdentifierArray(
          rawCompletedUserIDs,
          "claimRefresh.completedUserIDs",
        ),
  );
  if (
    [...completedUserIDs].some(
      (userID) => !affectedUserIDs.includes(userID),
    )
  ) {
    throw new HttpsError(
      "data-loss",
      "The claim refresh task completion state is malformed.",
    );
  }

  let firstError: unknown;
  for (const userID of affectedUserIDs) {
    if (completedUserIDs.has(userID)) {
      continue;
    }
    try {
      await dependencies.refreshTrustedClaimsForUser(userID, districtID);
      await reference.update({
        completedUserIDs: FieldValue.arrayUnion(userID),
        lastAttemptAt: FieldValue.serverTimestamp(),
      });
      completedUserIDs.add(userID);
    } catch (error) {
      firstError ??= error;
    }
  }
  if (firstError !== undefined) {
    throw firstError;
  }
  await reference.update({
    completedAt: FieldValue.serverTimestamp(),
    completedUserIDs: [...affectedUserIDs].sort(),
  });
};

const refreshStudentAssignmentClaims = async (
  dependencies: StudentMutationDependencies,
  districtID: string,
  operationID: string,
): Promise<void> =>
  createStudentClaimRefreshHandler(dependencies)({ districtID, operationID });

const studentDocumentFields = (
  data: CreateStudentRequest,
): Readonly<Record<string, unknown>> => ({
  districtId: data.districtID,
  schoolId: data.schoolID,
  displayName: data.displayName,
  normalizedDisplayName: normalizeSearchText(data.displayName),
  grade: data.grade,
  ...(data.studentIdentifier === undefined
    ? {}
    : {
        studentIdentifier: data.studentIdentifier,
        normalizedStudentIdentifier: normalizeSearchText(
          data.studentIdentifier,
        ),
      }),
  ...(data.dateOfBirth === undefined
    ? {}
    : { dateOfBirth: Timestamp.fromDate(new Date(data.dateOfBirth)) }),
  ...(data.pronouns === undefined ? {} : { pronouns: data.pronouns }),
  assignedMemberIDs: [...data.assignedMemberIDs].sort(),
});

const readStudentMutationMembership = async (
  firestore: Firestore,
  districtID: string,
  userID: string,
): Promise<StudentMutationMembership> => {
  const snapshot = await firestore
    .doc(`districts/${districtID}/members/${userID}`)
    .get();
  const data = requireExistingData(snapshot, "Caller membership");
  let schoolIDs: string[];
  let assignedStudentIDs: string[];
  let role: StaffRole;
  let capabilities: Capability[];
  try {
    schoolIDs = requireStoredIdentifierArray(
      data.schoolIDs,
      "membership.schoolIDs",
    );
    assignedStudentIDs = requireStoredIdentifierArray(
      data.assignedStudentIDs,
      "membership.assignedStudentIDs",
    );
    role = requireEnum(data.role, "membership.role", staffRoleValues);
    capabilities = parseCapabilityArray(data.capabilities);
  } catch {
    throw new HttpsError(
      "data-loss",
      "The caller membership authority is malformed after mutation.",
    );
  }
  const version = data.version;
  if (
    data.districtID !== districtID ||
    data.isActive !== true ||
    typeof version !== "number" ||
    !Number.isSafeInteger(version) ||
    version < 1 ||
    (data.recordVersion !== undefined && data.recordVersion !== version)
  ) {
    throw new HttpsError(
      "data-loss",
      "The caller membership authority is malformed after mutation.",
    );
  }
  return {
    districtID,
    schoolIDs: schoolIDs.sort(),
    role,
    capabilities: capabilities.sort(),
    assignedStudentIDs: assignedStudentIDs.sort(),
    isActive: true,
    version,
  };
};

export const createStudentMutationHandlers = (
  dependencies: StudentMutationDependencies,
) => ({
  createStudent: async (
    request: CallableRequest<CreateStudentRequest>,
  ): Promise<StudentMutationResult> => {
    const data = parseCreateStudentRequest(request.data);
    if (data.expectedRecordVersion !== 0) {
      throw new HttpsError(
        "invalid-argument",
        "A new student must expect record version zero.",
      );
    }
    const studentID = studentIDForCreate(data);
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "student.create",
        targetPath: () =>
          `districts/${data.districtID}/students/${studentID}`,
        requiredCapability: null,
        auditDetails: () => ({
          studentID,
          schoolID: data.schoolID,
          assignmentCount: data.assignedMemberIDs.length,
        }),
        mutate: async ({ transaction, membership, identity }) => {
          if (!canCreateStudentInSchool(membership, data.schoolID)) {
            throw new HttpsError(
              "permission-denied",
              "The member cannot create students in this school.",
            );
          }
          const assignedMemberIDs = new Set(data.assignedMemberIDs);
          requireCreateAssignmentScope(
            membership,
            data.schoolID,
            assignedMemberIDs,
          );
          const reference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${studentID}`,
          );
          const snapshot = await transaction.get(reference);
          if (snapshot.exists) {
            throw new HttpsError(
              "already-exists",
              "The student operation target already exists.",
            );
          }
          await assertNoStudentDuplicate(
            transaction,
            dependencies.firestore,
            data,
          );
          await applyStudentAssignmentChanges(
            transaction,
            dependencies.firestore,
            {
              districtID: data.districtID,
              schoolID: data.schoolID,
              studentID,
              operationID: data.idempotencyKey,
              actorUserID: identity.userID,
              previousMemberIDs: new Set(),
              nextMemberIDs: assignedMemberIDs,
            },
          );
          transaction.create(reference, {
            ...studentDocumentFields(data),
            isArchived: false,
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: FieldValue.serverTimestamp(),
            createdBy: identity.userID,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: identity.userID,
          });
          return { recordVersion: 1 };
        },
      },
    );
    await refreshStudentAssignmentClaims(
      dependencies,
      data.districtID,
      data.idempotencyKey,
    );
    const membership = await readStudentMutationMembership(
      dependencies.firestore,
      data.districtID,
      request.auth?.uid ?? "",
    );
    return { ...result, studentID, membership };
  },

  updateStudent: async (
    request: CallableRequest<UpdateStudentRequest>,
  ): Promise<StudentMutationResult> => {
    const data = parseUpdateStudentRequest(request.data);
    if (data.expectedRecordVersion < 1) {
      throw new HttpsError(
        "invalid-argument",
        "An updated student must expect an existing record version.",
      );
    }
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "student.update",
        targetPath: () =>
          `districts/${data.districtID}/students/${data.studentID}`,
        requiredCapability: null,
        auditDetails: () => ({
          studentID: data.studentID,
          schoolID: data.schoolID,
          assignmentCount: data.assignedMemberIDs.length,
        }),
        mutate: async ({ transaction, membership, identity }) => {
          const reference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          );
          const snapshot = await transaction.get(reference);
          const existing = requireCanonicalStudent(
            snapshot,
            data.districtID,
          );
          assertStudentRecordVersion(
            existing.recordVersion,
            data.expectedRecordVersion,
          );
          if (existing.isArchived === true) {
            throw new HttpsError(
              "failed-precondition",
              "Archived students cannot be edited.",
            );
          }
          const existingSchoolID = requireSchoolID(existing, "Student");
          const previousMemberIDs = new Set(
            requireStoredIdentifierArray(
              existing.assignedMemberIDs,
              "student.assignedMemberIDs",
            ),
          );
          if (previousMemberIDs.size > maximumStudentAssignments) {
            throw new HttpsError(
              "failed-precondition",
              "The legacy student exceeds the maximum staff assignment count and must be reconciled before editing.",
            );
          }
          if (
            !canWriteCanonicalStudent(
              membership,
              data.studentID,
              existingSchoolID,
              previousMemberIDs,
            )
          ) {
            throw new HttpsError(
              "permission-denied",
              "The member cannot edit this student.",
            );
          }
          const nextMemberIDs = new Set(data.assignedMemberIDs);
          const changesSchool = data.schoolID !== existingSchoolID;
          const changesAssignments = !areEqualIdentifierSets(
            previousMemberIDs,
            nextMemberIDs,
          );
          if (
            (changesSchool || changesAssignments) &&
            (!canManageSchool(membership, existingSchoolID) ||
              !canManageSchool(membership, data.schoolID))
          ) {
            throw new HttpsError(
              "permission-denied",
              "Changing school or assignment scope requires staff management scope.",
            );
          }
          await assertNoStudentDuplicate(
            transaction,
            dependencies.firestore,
            data,
            data.studentID,
          );
          await applyStudentAssignmentChanges(
            transaction,
            dependencies.firestore,
            {
              districtID: data.districtID,
              schoolID: data.schoolID,
              studentID: data.studentID,
              operationID: data.idempotencyKey,
              actorUserID: identity.userID,
              previousMemberIDs,
              nextMemberIDs,
              validateAllNextMemberScopes: changesSchool,
            },
          );
          const nextVersion = data.expectedRecordVersion + 1;
          transaction.set(reference, {
            ...studentDocumentFields(data),
            isArchived: false,
            schemaVersion: 1,
            recordVersion: nextVersion,
            createdAt: existing.createdAt ?? FieldValue.serverTimestamp(),
            createdBy: existing.createdBy ?? identity.userID,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: identity.userID,
          });
          return { recordVersion: nextVersion };
        },
      },
    );
    await refreshStudentAssignmentClaims(
      dependencies,
      data.districtID,
      data.idempotencyKey,
    );
    const membership = await readStudentMutationMembership(
      dependencies.firestore,
      data.districtID,
      request.auth?.uid ?? "",
    );
    return { ...result, studentID: data.studentID, membership };
  },

  archiveStudent: async (
    request: CallableRequest<ArchiveStudentRequest>,
  ): Promise<StudentMutationResult> => {
    const data = parseArchiveStudentRequest(request.data);
    if (data.expectedRecordVersion < 1) {
      throw new HttpsError(
        "invalid-argument",
        "An archived student must expect an existing record version.",
      );
    }
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "student.archive",
        targetPath: () =>
          `districts/${data.districtID}/students/${data.studentID}`,
        requiredCapability: null,
        auditDetails: () => ({ studentID: data.studentID }),
        mutate: async ({ transaction, membership, identity }) => {
          const reference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          );
          const snapshot = await transaction.get(reference);
          const existing = requireCanonicalStudent(
            snapshot,
            data.districtID,
          );
          assertStudentRecordVersion(
            existing.recordVersion,
            data.expectedRecordVersion,
          );
          const schoolID = requireSchoolID(existing, "Student");
          const assignedMemberIDs = new Set(
            requireStoredIdentifierArray(
              existing.assignedMemberIDs,
              "student.assignedMemberIDs",
            ),
          );
          if (
            !canWriteCanonicalStudent(
              membership,
              data.studentID,
              schoolID,
              assignedMemberIDs,
            )
          ) {
            throw new HttpsError(
              "permission-denied",
              "The member cannot archive this student.",
            );
          }
          if (existing.isArchived === true) {
            throw new HttpsError(
              "failed-precondition",
              "The student is already archived.",
            );
          }
          const nextVersion = data.expectedRecordVersion + 1;
          transaction.update(reference, {
            isArchived: true,
            recordVersion: nextVersion,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: identity.userID,
          });
          return { recordVersion: nextVersion };
        },
      },
    );
    const membership = await readStudentMutationMembership(
      dependencies.firestore,
      data.districtID,
      request.auth?.uid ?? "",
    );
    return { ...result, studentID: data.studentID, membership };
  },
});

const refreshCurrentTrustedClaimsForUser = async (
  userID: string,
  districtID: string,
): Promise<void> => {
  const membership = await getFirestore()
    .doc(`districts/${districtID}/members/${userID}`)
    .get();
  const version = membership.get("version");
  if (
    !membership.exists ||
    typeof version !== "number" ||
    !Number.isSafeInteger(version) ||
    version < 1
  ) {
    throw new HttpsError(
      "data-loss",
      "The affected membership version is missing after assignment.",
    );
  }
  await refreshTrustedClaims(userID, districtID, version);
};

const productionStudentMutationHandlers = createStudentMutationHandlers({
  firestore: getFirestore(),
  refreshTrustedClaimsForUser: refreshCurrentTrustedClaimsForUser,
});
const productionStudentClaimRefreshHandler =
  createStudentClaimRefreshHandler({
    firestore: getFirestore(),
    refreshTrustedClaimsForUser: refreshCurrentTrustedClaimsForUser,
  });

const transitionPlanHandler = async (
  request: CallableRequest<TransitionPlanRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseTransitionPlanRequest(request.data);
  const firestore = getFirestore();
  return executePrivilegedOperation(firestore, request, data, {
    action: "plan.transition",
    targetPath: (input) =>
      `districts/${input.districtID}/plans/${input.planID}`,
    requiredCapability: "plan.approve",
    auditDetails: (input) => ({
      planID: input.planID,
      nextStatus: input.nextStatus,
    }),
    mutate: async ({ transaction, membership, identity }) => {
      const reference = firestore.doc(
        `districts/${data.districtID}/plans/${data.planID}`,
      );
      const snapshot = await transaction.get(reference);
      const plan = requireExistingData(snapshot, "Plan");
      assertRecordVersion(plan.recordVersion, data.expectedRecordVersion);
      const currentStatus = requireEnum(
        plan.status,
        "plan.status",
        allowedPlanStatuses,
      );
      if (!allowedPlanTransitions[currentStatus].includes(data.nextStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `The plan cannot transition from ${currentStatus} to ${data.nextStatus}.`,
        );
      }
      const schoolID = requireSchoolID(plan, "Plan");
      const studentIDs = requireStoredIdentifierArray(
        plan.studentIDs,
        "plan.studentIDs",
      );
      const isInScope =
        membership.role === "districtAdministrator" ||
        (membership.role === "schoolAdministrator"
          ? membership.schoolIDs.has(schoolID)
          : membership.schoolIDs.has(schoolID) &&
            studentIDs.length > 0 &&
            studentIDs.every((studentID) =>
              membership.assignedStudentIDs.has(studentID),
            ));
      if (!isInScope) {
        throw new HttpsError(
          "permission-denied",
          "The plan is outside the member's assigned scope.",
        );
      }
      const nextVersion = data.expectedRecordVersion + 1;
      transaction.update(reference, {
        status: data.nextStatus,
        recordVersion: nextVersion,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: identity.userID,
      });
      return { recordVersion: nextVersion };
    },
  });
};

const issueStudentModeSessionHandler = async (
  request: CallableRequest<IssueStudentModeSessionRequest>,
): Promise<
  PrivilegedOperationResult & {
    readonly customToken: string;
    readonly expiresAt: string;
  }
> => {
  const data = parseIssueStudentModeSessionRequest(request.data);
  const firestore = getFirestore();
  const sessionPath = `districts/${data.districtID}/studentModeSessions/${data.idempotencyKey}`;
  const result = await executePrivilegedOperation(
    firestore,
    request,
    data,
    {
      action: "studentMode.session.issue",
      targetPath: () => sessionPath,
      requiredCapability: null,
      auditDetails: (input) => ({
        studentID: input.studentID,
        assignmentIDs: [...input.assignmentIDs],
        durationMinutes: input.durationMinutes,
      }),
      mutate: async ({ transaction, membership, identity }) => {
        const studentReference = firestore.doc(
          `districts/${data.districtID}/students/${data.studentID}`,
        );
        const sessionReference = firestore.doc(sessionPath);
        const [studentSnapshot, sessionSnapshot] = await Promise.all([
          transaction.get(studentReference),
          transaction.get(sessionReference),
        ]);
        const student = requireExistingData(studentSnapshot, "Student");
        assertRecordVersion(
          student.recordVersion,
          data.expectedRecordVersion,
        );
        const schoolID = requireSchoolID(student, "Student");
        if (!canReadStudentDetail(membership, data.studentID, schoolID)) {
          throw new HttpsError(
            "permission-denied",
            "Student Mode can only be issued for an authorized student.",
          );
        }
        if (sessionSnapshot.exists) {
          throw new HttpsError(
            "already-exists",
            "The Student Mode session already exists.",
          );
        }
        const issuedAt = Timestamp.now();
        const expiresAt = Timestamp.fromMillis(
          issuedAt.toMillis() + data.durationMinutes * 60_000,
        );
        transaction.create(sessionReference, {
          schemaVersion: 1,
          recordVersion: 1,
          districtID: data.districtID,
          schoolId: schoolID,
          studentID: data.studentID,
          assignmentIDs: [...data.assignmentIDs],
          educatorUserID: identity.userID,
          status: "active",
          issuedAt,
          expiresAt,
          lastActivityAt: issuedAt,
        });
        return { recordVersion: 1 };
      },
    },
  );
  const session = await firestore.doc(sessionPath).get();
  const expiresAt = session.get("expiresAt");
  if (!(expiresAt instanceof Timestamp)) {
    throw new HttpsError(
      "data-loss",
      "The Student Mode session expiry is missing.",
    );
  }
  const tokenPayload = {
    tmiDistrictID: data.districtID,
    tmiAccessClass: "studentMode",
    tmiMembershipVersion: 1,
    tmiStudentID: data.studentID,
    tmiSessionID: data.idempotencyKey,
  };
  if (Buffer.byteLength(JSON.stringify(tokenPayload), "utf8") > 900) {
    throw new HttpsError(
      "invalid-argument",
      "The Student Mode identifiers are too large for a secure token.",
    );
  }
  const sessionUserID = `studentMode_${createHash("sha256")
    .update(`${data.districtID}:${data.idempotencyKey}`)
    .digest("hex")}`;
  const customToken = await getAuth().createCustomToken(
    sessionUserID,
    tokenPayload,
  );
  return { ...result, customToken, expiresAt: expiresAt.toDate().toISOString() };
};

const deletePersonalAccountDataHandler =
  createProductionDeletePersonalAccountDataHandler();
const provisionStaffMembershipHandler =
  createProductionProvisionStaffMembershipHandler();

const requestSensitiveExportHandler = async (
  request: CallableRequest<RequestSensitiveExportRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseRequestSensitiveExportRequest(request.data);
  const firestore = getFirestore();
  const taskPath = `districts/${data.districtID}/tasks/${data.idempotencyKey}`;
  return executePrivilegedOperation(firestore, request, data, {
    action: "report.export.request",
    targetPath: () => taskPath,
    requiredCapability: "report.export",
    auditDetails: (input) => ({
      exportType: input.exportType,
      schoolID: input.schoolID,
      studentIDs: [...input.studentIDs],
    }),
    mutate: async ({ transaction, membership, identity }) => {
      if (data.expectedRecordVersion !== 0) {
        throw new HttpsError(
          "invalid-argument",
          "A new export request must expect record version zero.",
        );
      }
      if (
        data.schoolID !== null &&
        membership.role !== "districtAdministrator" &&
        !membership.schoolIDs.has(data.schoolID)
      ) {
        throw new HttpsError(
          "permission-denied",
          "The export school is outside the member's scope.",
        );
      }
      if (
        data.studentIDs.length === 0 &&
        membership.role !== "districtAdministrator" &&
        data.schoolID === null
      ) {
        throw new HttpsError(
          "invalid-argument",
          "A non-district aggregate export requires a school scope.",
        );
      }
      for (const studentID of data.studentIDs) {
        const studentSnapshot = await transaction.get(
          firestore.doc(
            `districts/${data.districtID}/students/${studentID}`,
          ),
        );
        const student = requireExistingData(studentSnapshot, "Student");
        const schoolID = requireSchoolID(student, "Student");
        if (
          (data.schoolID !== null && data.schoolID !== schoolID) ||
          !canReadStudentDetail(membership, studentID, schoolID)
        ) {
          throw new HttpsError(
            "permission-denied",
            "The export contains a student outside the member's detail scope.",
          );
        }
      }
      const taskReference = firestore.doc(taskPath);
      const taskSnapshot = await transaction.get(taskReference);
      if (taskSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "The export task already exists.",
        );
      }
      transaction.create(taskReference, {
        schemaVersion: 1,
        recordVersion: 1,
        type: "sensitiveExport",
        state: "queued",
        exportType: data.exportType,
        schoolID: data.schoolID,
        studentIDs: [...data.studentIDs],
        requestedBy: identity.userID,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: identity.userID,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: identity.userID,
      });
      return { recordVersion: 1 };
    },
  });
};

const recordPrivilegedAuditEventHandler = async (
  request: CallableRequest<RecordPrivilegedAuditEventRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseRecordPrivilegedAuditEventRequest(request.data);
  if (data.expectedRecordVersion !== 0) {
    throw new HttpsError(
      "invalid-argument",
      "A new audit event must expect record version zero.",
    );
  }
  return executePrivilegedOperation(getFirestore(), request, data, {
    action: "audit.privileged.record",
    targetPath: (input) => input.targetPath,
    requiredCapability: "audit.read",
    auditDetails: (input) => ({ eventType: input.eventType }),
    mutate: async () => ({ recordVersion: 1 }),
  });
};

export const mutateMembership = onCall(
  callableOptions,
  mutateMembershipHandler,
);
export const provisionStaffMembership = onCall<ProvisionStaffMembershipRequest>(
  callableOptions,
  provisionStaffMembershipHandler,
);
export const grantStudentDetailAccess = onCall(
  callableOptions,
  grantStudentDetailAccessHandler,
);
export const createStudent = onCall(
  callableOptions,
  productionStudentMutationHandlers.createStudent,
);
export const updateStudent = onCall(
  callableOptions,
  productionStudentMutationHandlers.updateStudent,
);
export const archiveStudent = onCall(
  callableOptions,
  productionStudentMutationHandlers.archiveStudent,
);
export const drainStudentClaimRefresh = onDocumentCreated(
  {
    document:
      "districts/{districtID}/studentClaimRefreshes/{operationID}",
    region: "us-central1",
    retry: true,
    timeoutSeconds: 540,
  },
  async (event) => {
    await productionStudentClaimRefreshHandler({
      districtID: event.params.districtID,
      operationID: event.params.operationID,
    });
  },
);
export const transitionPlan = onCall(callableOptions, transitionPlanHandler);
export const issueStudentModeSession = onCall(
  callableOptions,
  issueStudentModeSessionHandler,
);
export const deletePersonalAccountData = onCall(
  { ...callableOptions, timeoutSeconds: 540 },
  deletePersonalAccountDataHandler,
);
export const requestSensitiveExport = onCall(
  callableOptions,
  requestSensitiveExportHandler,
);
export const recordPrivilegedAuditEvent = onCall(
  callableOptions,
  recordPrivilegedAuditEventHandler,
);
