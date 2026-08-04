import { createHash, randomUUID } from "node:crypto";
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
  assertDistrict,
  canManageSchool,
  canReadStudentDetail,
  capabilityValues,
  executePrivilegedOperation,
  parseBaseRequest,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  isValidIdentifier,
  requireBoolean,
  requireEnum,
  requireIdentifier,
  requireIdentifierArray,
  requireInteger,
  requireCapability,
  requireTrustedMembership,
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
  readonly durationMinutes?: number;
}

export interface EndStudentModeSessionRequest
  extends PrivilegedBaseRequest {
  readonly sessionID: string;
  readonly disposition: "ended" | "revoked";
}

export interface RestoreStudentModeSessionRequest {
  readonly districtID: string;
  readonly sessionID: string;
}

type SurveyAnswerType =
  | "single"
  | "multiple"
  | "text"
  | "rating"
  | "image";

interface SurveyAnswerPayload {
  readonly type: SurveyAnswerType;
  readonly value: string | number | readonly string[];
}

export interface SaveSurveyDraftRequest {
  readonly districtID: string;
  readonly studentID: string;
  readonly assignmentID: string;
  readonly attemptID: string;
  readonly definitionID: string;
  readonly definitionVersion: number;
  readonly expectedRecordVersion: number;
  readonly operationID: string;
  readonly answers: Readonly<Record<string, SurveyAnswerPayload>>;
}

export interface SubmitSurveyResponseRequest
  extends SaveSurveyDraftRequest {}

export interface ReviewSurveyResponseRequest extends PrivilegedBaseRequest {
  readonly studentID: string;
  readonly responseID: string;
}

type SurveyAssignmentMutationAction = "create" | "reassign" | "revoke";

export interface MutateSurveyAssignmentRequest extends PrivilegedBaseRequest {
  readonly action: SurveyAssignmentMutationAction;
  readonly assignmentID: string;
  readonly studentID: string;
  readonly definitionID: string;
  readonly definitionVersion: number;
}

export interface SurveyAssignmentMutationResult
  extends PrivilegedOperationResult {
  readonly assignment: SurveyAssignmentMutationEnvelope;
}

interface SurveyAssignmentMutationEnvelope {
  readonly schemaVersion: 1;
  readonly recordVersion: number;
  readonly assignmentID: string;
  readonly attemptID: string;
  readonly districtID: string;
  readonly studentID: string;
  readonly definitionID: string;
  readonly definitionVersion: number;
  readonly state: "active" | "revoked";
  readonly assignedAt: string;
  readonly revokedAt: string | null;
}

export interface StudentModeRespondentClaims
  extends Record<string, unknown> {
  readonly tmiDistrictID: string;
  readonly tmiAccessClass: "respondent";
  readonly tmiStudentID: string;
  readonly tmiSessionID: string;
  readonly tmiAssignmentIDs: readonly [string];
  readonly tmiAllowedOperations: readonly StudentModeOperation[];
}

const studentModeOperationValues = [
  "readStudentSafeProfile",
  "readAssignment",
  "readCareerCatalog",
  "readStudentVisiblePlan",
  "writeDraft",
  "submitAssignment",
  "updateInterests",
  "writeReflection",
  "writeCheckIn",
  "updateCareerState",
  "requestHelp",
] as const;

type StudentModeOperation = (typeof studentModeOperationValues)[number];

const surveyStudentModeOperations = [
  "readStudentSafeProfile",
  "readAssignment",
  "writeDraft",
  "submitAssignment",
  "requestHelp",
] as const satisfies readonly StudentModeOperation[];

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
      { allowEmpty: false, maximumCount: 1 },
    ),
    durationMinutes: Math.min(
      data.durationMinutes === undefined
        ? 30
        : requireInteger(
            data.durationMinutes,
            "durationMinutes",
            1,
          ),
      60,
    ),
  };
};

const parseEndStudentModeSessionRequest = (
  value: unknown,
): EndStudentModeSessionRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("sessionID", "disposition"),
  );
  return {
    ...parseBaseRequest(data),
    sessionID: requireIdentifier(data.sessionID, "sessionID"),
    disposition: requireEnum(
      data.disposition,
      "disposition",
      ["ended", "revoked"] as const,
    ),
  };
};

const parseRestoreStudentModeSessionRequest = (
  value: unknown,
): RestoreStudentModeSessionRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, new Set(["districtID", "sessionID"]));
  return {
    districtID: requireIdentifier(data.districtID, "districtID"),
    sessionID: requireIdentifier(data.sessionID, "sessionID"),
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

interface StudentModeDependencies {
  readonly firestore: Firestore;
  readonly createCustomToken: (
    userID: string,
    claims: StudentModeRespondentClaims,
  ) => Promise<string>;
}

type StudentModeRestoredState =
  | {
    readonly status: "active";
    readonly recordVersion: number;
    readonly studentID: string;
    readonly assignmentID: string;
    readonly operations: readonly StudentModeOperation[];
    readonly respondentUserID: string;
    readonly issuedAt: Timestamp;
    readonly expiresAt: Timestamp;
    readonly profile: Readonly<Record<string, unknown>>;
  }
  | {
    readonly status: "ended" | "revoked" | "expired";
    readonly recordVersion: number;
  };

const assignmentContainsStudent = (
  assignment: DocumentData,
  student: DocumentData,
  studentID: string,
): boolean => {
  const projectedStudentIDs = assignment.studentIDs;
  if (!Array.isArray(projectedStudentIDs) ||
      !projectedStudentIDs.includes(studentID)) {
    return false;
  }
  const cohort = assignment.cohort;
  if (typeof cohort !== "object" || cohort === null || Array.isArray(cohort)) {
    return (
      Array.isArray(projectedStudentIDs) &&
      projectedStudentIDs.includes(studentID)
    );
  }
  const cohortData = cohort as Record<string, unknown>;
  switch (cohortData.type) {
    case "allStudents":
      return true;
    case "school":
      return cohortData.schoolId === student.schoolId;
    case "grade":
      return cohortData.grade === student.grade;
    case "specificStudents":
    case "customClass":
      return (
        Array.isArray(cohortData.studentIds) &&
        cohortData.studentIds.includes(studentID)
      );
    default:
      return false;
  }
};

const isStudentModeAssignmentType = (assignment: DocumentData): boolean =>
  assignment.assignmentType === undefined ||
  assignment.assignmentType === "survey" ||
  assignment.assignmentType === "form";

const studentModeOperationsForAssignment = (
  assignment: DocumentData,
): readonly StudentModeOperation[] => {
  if (!isStudentModeAssignmentType(assignment)) {
    throw new HttpsError(
      "permission-denied",
      "The assignment type is not available in Student Mode.",
    );
  }
  return surveyStudentModeOperations;
};

const studentSafeProfile = (
  student: DocumentData,
  districtID: string,
  studentID: string,
): Readonly<Record<string, unknown>> => ({
  schemaVersion: 1,
  districtID,
  studentID,
  ...(typeof student.displayName === "string"
    ? { displayName: student.displayName }
    : {}),
  ...(typeof student.grade === "string" ? { grade: student.grade } : {}),
  ...(typeof student.pronouns === "string"
    ? { pronouns: student.pronouns }
    : {}),
});

const sessionIDFromAuditTarget = (
  targetPath: unknown,
  districtID: string,
): string => {
  const prefix = `districts/${districtID}/studentModeSessions/`;
  if (
    typeof targetPath !== "string" ||
    !targetPath.startsWith(prefix)
  ) {
    throw new HttpsError(
      "data-loss",
      "The Student Mode audit target is malformed.",
    );
  }
  return requireIdentifier(
    targetPath.slice(prefix.length),
    "audit sessionID",
  );
};

export const createStudentModeHandlers = (
  dependencies: StudentModeDependencies,
) => ({
  issueSession: async (
    request: CallableRequest<IssueStudentModeSessionRequest>,
  ): Promise<
    PrivilegedOperationResult & {
      readonly sessionID: string;
      readonly districtID: string;
      readonly studentID: string;
      readonly assignmentIDs: readonly [string];
      readonly allowedOperations: readonly StudentModeOperation[];
      readonly customToken: string;
      readonly issuedAt: string;
      readonly expiresAt: string;
    }
  > => {
    const data = parseIssueStudentModeSessionRequest(request.data);
    const assignmentID = data.assignmentIDs[0];
    if (assignmentID === undefined || data.durationMinutes === undefined) {
      throw new HttpsError(
        "invalid-argument",
        "Exactly one assignment and a valid duration are required.",
      );
    }
    const durationMinutes = data.durationMinutes;
    const callerIdentity = parseTrustedCallableIdentity(request);
    assertDistrict(callerIdentity, data.districtID);
    await dependencies.firestore.runTransaction(async (transaction) => {
      const membership = await requireTrustedMembership(
        dependencies.firestore,
        transaction,
        callerIdentity,
      );
      requireCapability(membership, "student.read.detail");
      const [studentSnapshot, assignmentSnapshot] = await Promise.all([
        transaction.get(
          dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          ),
        ),
        transaction.get(
          dependencies.firestore.doc(
            `districts/${data.districtID}/formAssignments/${assignmentID}`,
          ),
        ),
      ]);
      const student = requireExistingData(studentSnapshot, "Student");
      assertRecordVersion(
        student.recordVersion,
        data.expectedRecordVersion,
      );
      const schoolID = requireSchoolID(student, "Student");
      if (
        student.districtId !== data.districtID ||
        student.isArchived === true ||
        !membership.assignedStudentIDs.has(data.studentID) ||
        !membership.schoolIDs.has(schoolID) ||
        !canReadStudentDetail(membership, data.studentID, schoolID)
      ) {
        throw new HttpsError(
          "permission-denied",
          "Student Mode requires a directly assigned active student.",
        );
      }
      const assignment = requireExistingData(
        assignmentSnapshot,
        "Assignment",
      );
      if (
        assignment.districtId !== data.districtID ||
        assignment.isActive !== true ||
        !isStudentModeAssignmentType(assignment) ||
        !assignmentContainsStudent(assignment, student, data.studentID)
      ) {
        throw new HttpsError(
          "permission-denied",
          "The assignment is not active for the selected student.",
        );
      }
    });
    const candidateSessionID = `sm_${randomUUID().replaceAll("-", "")}`;
    const candidateSessionPath =
      `districts/${data.districtID}/studentModeSessions/${candidateSessionID}`;
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "studentMode.session.issue",
        targetPath: () => candidateSessionPath,
        requiredCapability: "student.read.detail",
        auditDetails: () => ({
          studentID: data.studentID,
          assignmentIDs: [assignmentID],
          durationMinutes,
        }),
        mutate: async ({ transaction, membership, identity }) => {
          const studentReference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          );
          const assignmentReference = dependencies.firestore.doc(
            `districts/${data.districtID}/formAssignments/${assignmentID}`,
          );
          const sessionReference = dependencies.firestore.doc(
            candidateSessionPath,
          );
          const safeProfileReference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}/studentSafe/profile`,
          );
          const [studentSnapshot, assignmentSnapshot, sessionSnapshot] =
            await Promise.all([
              transaction.get(studentReference),
              transaction.get(assignmentReference),
              transaction.get(sessionReference),
            ]);
          const student = requireExistingData(studentSnapshot, "Student");
          assertRecordVersion(
            student.recordVersion,
            data.expectedRecordVersion,
          );
          const schoolID = requireSchoolID(student, "Student");
          if (
            student.districtId !== data.districtID ||
            student.isArchived === true ||
            !membership.assignedStudentIDs.has(data.studentID) ||
            !membership.schoolIDs.has(schoolID) ||
            !canReadStudentDetail(
              membership,
              data.studentID,
              schoolID,
            )
          ) {
            throw new HttpsError(
              "permission-denied",
              "Student Mode requires a directly assigned active student.",
            );
          }
          const assignment = requireExistingData(
            assignmentSnapshot,
            "Assignment",
          );
          if (
            assignment.districtId !== data.districtID ||
            assignment.isActive !== true ||
            !isStudentModeAssignmentType(assignment) ||
            !assignmentContainsStudent(assignment, student, data.studentID)
          ) {
            throw new HttpsError(
              "permission-denied",
              "The assignment is not active for the selected student.",
            );
          }
          const allowedOperations =
            studentModeOperationsForAssignment(assignment);
          if (sessionSnapshot.exists) {
            throw new HttpsError(
              "already-exists",
              "The generated Student Mode session already exists.",
            );
          }
          const issuedAt = Timestamp.now();
          const expiresAt = Timestamp.fromMillis(
            issuedAt.toMillis() + durationMinutes * 60_000,
          );
          const respondentUserID = `studentMode_${createHash("sha256")
            .update(candidateSessionID)
            .digest("hex")}`;
          transaction.create(sessionReference, {
            schemaVersion: 1,
            recordVersion: 1,
            districtID: data.districtID,
            schoolId: schoolID,
            studentID: data.studentID,
            assignmentIDs: [assignmentID],
            allowedOperations: [...allowedOperations],
            educatorUserID: identity.userID,
            respondentUserID,
            status: "active",
            issuedAt,
            expiresAt,
            lastActivityAt: issuedAt,
          });
          transaction.set(
            safeProfileReference,
            studentSafeProfile(student, data.districtID, data.studentID),
          );
          return { recordVersion: 1 };
        },
      },
    );
    let sessionID = candidateSessionID;
    if (result.replayed) {
      const audit = await dependencies.firestore
        .doc(
          `districts/${data.districtID}/auditEvents/${data.idempotencyKey}`,
        )
        .get();
      sessionID = sessionIDFromAuditTarget(
        audit.get("targetPath"),
        data.districtID,
      );
    }
    const session = await dependencies.firestore
      .doc(
        `districts/${data.districtID}/studentModeSessions/${sessionID}`,
      )
      .get();
    const issuedAt = session.get("issuedAt");
    const expiresAt = session.get("expiresAt");
    const respondentUserID = session.get("respondentUserID");
    const storedAllowedOperations = session.get("allowedOperations");
    if (
      !(issuedAt instanceof Timestamp) ||
      !(expiresAt instanceof Timestamp) ||
      typeof respondentUserID !== "string" ||
      !Array.isArray(storedAllowedOperations) ||
      !storedAllowedOperations.every(
        (operation): operation is StudentModeOperation =>
          typeof operation === "string" &&
          studentModeOperationValues.includes(
            operation as StudentModeOperation,
          ),
      )
    ) {
      throw new HttpsError(
        "data-loss",
        "The Student Mode session credential state is missing.",
      );
    }
    if (
      session.get("status") !== "active" ||
      expiresAt.toMillis() <= Date.now()
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The Student Mode session is no longer active.",
      );
    }
    const tokenPayload: StudentModeRespondentClaims = {
      tmiDistrictID: data.districtID,
      tmiAccessClass: "respondent",
      tmiStudentID: data.studentID,
      tmiSessionID: sessionID,
      tmiAssignmentIDs: [assignmentID],
      tmiAllowedOperations: [...storedAllowedOperations],
    };
    if (Buffer.byteLength(JSON.stringify(tokenPayload), "utf8") > 900) {
      throw new HttpsError(
        "invalid-argument",
        "The Student Mode identifiers are too large for a secure token.",
      );
    }
    const customToken = await dependencies.createCustomToken(
      respondentUserID,
      tokenPayload,
    );
    return {
      ...result,
      sessionID,
      districtID: data.districtID,
      studentID: data.studentID,
      assignmentIDs: [assignmentID],
      allowedOperations: [...storedAllowedOperations],
      customToken,
      issuedAt: issuedAt.toDate().toISOString(),
      expiresAt: expiresAt.toDate().toISOString(),
    };
  },

  restoreSession: async (
    request: CallableRequest<RestoreStudentModeSessionRequest>,
  ): Promise<
    | {
      readonly status: "active";
      readonly sessionID: string;
      readonly districtID: string;
      readonly studentID: string;
      readonly assignmentIDs: readonly [string];
      readonly allowedOperations: readonly StudentModeOperation[];
      readonly customToken: string;
      readonly recordVersion: number;
      readonly issuedAt: string;
      readonly expiresAt: string;
      readonly profile: Readonly<Record<string, unknown>>;
    }
    | {
      readonly status: "ended" | "revoked" | "expired";
      readonly sessionID: string;
      readonly districtID: string;
      readonly recordVersion: number;
    }
  > => {
    const data = parseRestoreStudentModeSessionRequest(request.data);
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, data.districtID);
    const restored =
      await dependencies.firestore.runTransaction<StudentModeRestoredState>(
      async (transaction) => {
        const membership = await requireTrustedMembership(
          dependencies.firestore,
          transaction,
          identity,
        );
        requireCapability(membership, "student.read.detail");
        const sessionReference = dependencies.firestore.doc(
          `districts/${data.districtID}/studentModeSessions/${data.sessionID}`,
        );
        const sessionSnapshot = await transaction.get(sessionReference);
        const session = requireExistingData(
          sessionSnapshot,
          "Student Mode session",
        );
        const recordVersion = requireInteger(
          session.recordVersion,
          "Student Mode session.recordVersion",
          1,
        );
        if (
          session.districtID !== data.districtID ||
          session.educatorUserID !== identity.userID
        ) {
          throw new HttpsError(
            "permission-denied",
            "Only the issuing educator can restore this Student Mode session.",
          );
        }
        if (session.status === "ended" || session.status === "revoked") {
          return {
            status: session.status,
            recordVersion,
          } as const;
        }
        const expiresAt = session.expiresAt;
        if (!(expiresAt instanceof Timestamp)) {
          throw new HttpsError(
            "data-loss",
            "The Student Mode session expiry is malformed.",
          );
        }
        if (expiresAt.toMillis() <= Date.now()) {
          return { status: "expired", recordVersion } as const;
        }
        if (session.status !== "active") {
          throw new HttpsError(
            "data-loss",
            "The Student Mode session status is malformed.",
          );
        }
        const studentID = requireIdentifier(
          session.studentID,
          "Student Mode session.studentID",
        );
        const assignmentIDs = requireIdentifierArray(
          session.assignmentIDs,
          "Student Mode session.assignmentIDs",
          { allowEmpty: false, maximumCount: 1 },
        );
        const assignmentID = assignmentIDs[0];
        const operations = session.allowedOperations;
        const respondentUserID = requireIdentifier(
          session.respondentUserID,
          "Student Mode session.respondentUserID",
        );
        const issuedAt = session.issuedAt;
        if (
          assignmentID === undefined ||
          !(issuedAt instanceof Timestamp) ||
          !Array.isArray(operations) ||
          operations.length === 0 ||
          !operations.every(
            (operation): operation is StudentModeOperation =>
              typeof operation === "string" &&
              studentModeOperationValues.includes(
                operation as StudentModeOperation,
              ),
          )
        ) {
          throw new HttpsError(
            "data-loss",
            "The Student Mode session scope is malformed.",
          );
        }
        const [studentSnapshot, assignmentSnapshot] = await Promise.all([
          transaction.get(
            dependencies.firestore.doc(
              `districts/${data.districtID}/students/${studentID}`,
            ),
          ),
          transaction.get(
            dependencies.firestore.doc(
              `districts/${data.districtID}/formAssignments/${assignmentID}`,
            ),
          ),
        ]);
        const student = requireExistingData(studentSnapshot, "Student");
        const schoolID = requireSchoolID(student, "Student");
        if (
          student.districtId !== data.districtID ||
          student.isArchived === true ||
          !membership.assignedStudentIDs.has(studentID) ||
          !membership.schoolIDs.has(schoolID) ||
          !canReadStudentDetail(membership, studentID, schoolID)
        ) {
          throw new HttpsError(
            "permission-denied",
            "The restored student is outside the educator's current scope.",
          );
        }
        const assignment = assignmentSnapshot.data();
        if (
          assignment === undefined ||
          assignment.districtId !== data.districtID ||
          assignment.isActive !== true ||
          !isStudentModeAssignmentType(assignment) ||
          !assignmentContainsStudent(assignment, student, studentID)
        ) {
          const revokedRecordVersion = recordVersion + 1;
          transaction.update(sessionReference, {
            status: "revoked",
            recordVersion: revokedRecordVersion,
            endedAt: FieldValue.serverTimestamp(),
            endedBy: identity.userID,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: identity.userID,
            revocationReason: "assignment-no-longer-eligible",
          });
          return {
            status: "revoked",
            recordVersion: revokedRecordVersion,
          } as const;
        }
        const expectedOperations = studentModeOperationsForAssignment(
          assignment,
        );
        const storedOperationSet = new Set(operations);
        if (
          storedOperationSet.size !== operations.length ||
          expectedOperations.length !== operations.length ||
          !expectedOperations.every((operation) =>
            storedOperationSet.has(operation),
          )
        ) {
          throw new HttpsError(
            "data-loss",
            "The Student Mode session operations are malformed.",
          );
        }
        return {
          status: "active",
          recordVersion,
          studentID,
          assignmentID,
          operations: [...operations],
          respondentUserID,
          issuedAt,
          expiresAt,
          profile: studentSafeProfile(
            student,
            data.districtID,
            studentID,
          ),
        } as const;
      },
      );
    if (restored.status !== "active") {
      return {
        status: restored.status,
        sessionID: data.sessionID,
        districtID: data.districtID,
        recordVersion: restored.recordVersion,
      };
    }
    const tokenPayload: StudentModeRespondentClaims = {
      tmiDistrictID: data.districtID,
      tmiAccessClass: "respondent",
      tmiStudentID: restored.studentID,
      tmiSessionID: data.sessionID,
      tmiAssignmentIDs: [restored.assignmentID],
      tmiAllowedOperations: [...restored.operations],
    };
    if (Buffer.byteLength(JSON.stringify(tokenPayload), "utf8") > 900) {
      throw new HttpsError(
        "invalid-argument",
        "The Student Mode identifiers are too large for a secure token.",
      );
    }
    const customToken = await dependencies.createCustomToken(
      restored.respondentUserID,
      tokenPayload,
    );
    return {
      status: "active",
      sessionID: data.sessionID,
      districtID: data.districtID,
      studentID: restored.studentID,
      assignmentIDs: [restored.assignmentID],
      allowedOperations: [...restored.operations],
      customToken,
      recordVersion: restored.recordVersion,
      issuedAt: restored.issuedAt.toDate().toISOString(),
      expiresAt: restored.expiresAt.toDate().toISOString(),
      profile: restored.profile,
    };
  },

  endSession: async (
    request: CallableRequest<EndStudentModeSessionRequest>,
  ): Promise<
    PrivilegedOperationResult & {
      readonly sessionID: string;
      readonly ended: true;
      readonly disposition: "ended" | "revoked";
    }
  > => {
    const data = parseEndStudentModeSessionRequest(request.data);
    const sessionPath =
      `districts/${data.districtID}/studentModeSessions/${data.sessionID}`;
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "studentMode.session.end",
        targetPath: () => sessionPath,
        requiredCapability: "student.read.detail",
        auditDetails: () => ({
          sessionID: data.sessionID,
          disposition: data.disposition,
        }),
        mutate: async ({ transaction, identity, membership }) => {
          const reference = dependencies.firestore.doc(sessionPath);
          const snapshot = await transaction.get(reference);
          const session = requireExistingData(snapshot, "Student Mode session");
          assertRecordVersion(
            session.recordVersion,
            data.expectedRecordVersion,
          );
          const schoolID = requireSchoolID(session, "Student Mode session");
          const isIssuingEducator =
            session.educatorUserID === identity.userID;
          const isScopedAdministratorRevocation =
            data.disposition === "revoked" &&
            canManageSchool(membership, schoolID);
          if (
            session.districtID !== data.districtID ||
            (!isIssuingEducator && !isScopedAdministratorRevocation)
          ) {
            throw new HttpsError(
              "permission-denied",
              "The member cannot end this Student Mode session.",
            );
          }
          if (session.status !== "active") {
            throw new HttpsError(
              "failed-precondition",
              "The Student Mode session is no longer active.",
            );
          }
          transaction.update(reference, {
            recordVersion: data.expectedRecordVersion + 1,
            status: data.disposition,
            endedAt: FieldValue.serverTimestamp(),
            endedBy: identity.userID,
          });
          return {
            recordVersion: data.expectedRecordVersion + 1,
          };
        },
      },
    );
    return {
      ...result,
      sessionID: data.sessionID,
      ended: true,
      disposition: data.disposition,
    };
  },
});

const productionStudentModeHandlers = createStudentModeHandlers({
  firestore: getFirestore(),
  createCustomToken: async (userID, claims) =>
    getAuth().createCustomToken(userID, claims),
});

const surveyAnswerTypeValues = [
  "single",
  "multiple",
  "text",
  "rating",
  "image",
] as const satisfies readonly SurveyAnswerType[];
const surveyQuestionTypeValues = [
  "singleChoice",
  "multiSelect",
  "shortText",
  "rating",
  "imageChoice",
] as const;
type SurveyQuestionType = (typeof surveyQuestionTypeValues)[number];
const surveyBranchEffectValues = ["show", "hide"] as const;
const surveyPredicateTypeValues = [
  "equals",
  "contains",
  "ratingAtLeast",
  "textIsNotEmpty",
] as const;
type SurveyPredicateType = (typeof surveyPredicateTypeValues)[number];

interface ParsedSurveyQuestion {
  readonly id: string;
  readonly type: SurveyQuestionType;
  readonly required: boolean;
  readonly optionIDs: ReadonlySet<string>;
  readonly maxSelections?: number;
  readonly maxLength?: number;
  readonly minimum?: number;
  readonly maximum?: number;
}

interface ParsedSurveyBranchRule {
  readonly id: string;
  readonly sourceQuestionID: string;
  readonly targetQuestionID: string;
  readonly priority: number;
  readonly effect: "show" | "hide";
  readonly predicate: {
    readonly type: SurveyPredicateType;
    readonly value?: string | number;
  };
}

interface ParsedSurveyDefinition {
  readonly data: DocumentData;
  readonly definitionID: string;
  readonly version: number;
  readonly questions: readonly ParsedSurveyQuestion[];
  readonly branchRules: readonly ParsedSurveyBranchRule[];
}

interface RespondentSurveyIdentity {
  readonly userID: string;
  readonly districtID: string;
  readonly studentID: string;
  readonly sessionID: string;
  readonly assignmentID: string;
  readonly operations: ReadonlySet<string>;
}

interface SurveyScopeData {
  readonly identity: RespondentSurveyIdentity;
  readonly assignment: DocumentData;
  readonly definition: ParsedSurveyDefinition;
}

interface SurveyDependencies {
  readonly firestore: Firestore;
}

const surveyResponsePath = (
  districtID: string,
  studentID: string,
  attemptID: string,
): string =>
  `districts/${districtID}/students/${studentID}/responses/${attemptID}`;

const surveyDefinitionPath = (
  definitionID: string,
  version: number,
): string =>
  `catalogs/surveyDefinitions/items/${definitionID}__v${version}`;

const surveyDataLoss = (message: string): never => {
  throw new HttpsError("failed-precondition", message);
};

const storedSurveyDataLoss = (message: string): never => {
  throw new HttpsError("data-loss", message);
};

const parseSurveyAnswers = (
  value: unknown,
): Readonly<Record<string, SurveyAnswerPayload>> => {
  const record = requireRecord(value, "answers");
  const entries = Object.entries(record);
  if (entries.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "answers contains too many questions.",
    );
  }
  const answers: Record<string, SurveyAnswerPayload> = {};
  for (const [questionID, rawAnswer] of entries) {
    requireIdentifier(questionID, "answer questionID");
    const answer = requireRecord(rawAnswer, `answers.${questionID}`);
    rejectUnexpectedFields(answer, new Set(["type", "value"]));
    const type = requireEnum(
      answer.type,
      `answers.${questionID}.type`,
      surveyAnswerTypeValues,
    );
    switch (type) {
      case "single":
      case "image":
        answers[questionID] = {
          type,
          value: requireIdentifier(
            answer.value,
            `answers.${questionID}.value`,
          ),
        };
        break;
      case "multiple": {
        const values = requireIdentifierArray(
          answer.value,
          `answers.${questionID}.value`,
          { allowEmpty: true, maximumCount: 100 },
        );
        if (new Set(values).size !== values.length) {
          throw new HttpsError(
            "invalid-argument",
            `answers.${questionID}.value contains duplicates.`,
          );
        }
        answers[questionID] = { type, value: [...values].sort() };
        break;
      }
      case "text": {
        if (
          typeof answer.value !== "string" ||
          Buffer.byteLength(answer.value, "utf8") > 4_000 ||
          /\p{Cc}/u.test(answer.value)
        ) {
          throw new HttpsError(
            "invalid-argument",
            `answers.${questionID}.value is malformed.`,
          );
        }
        answers[questionID] = { type, value: answer.value };
        break;
      }
      case "rating":
        answers[questionID] = {
          type,
          value: requireInteger(
            answer.value,
            `answers.${questionID}.value`,
            Number.MIN_SAFE_INTEGER,
          ),
        };
        break;
    }
  }
  return Object.fromEntries(
    Object.entries(answers).sort(([left], [right]) =>
      left < right ? -1 : left > right ? 1 : 0,
    ),
  );
};

const parseSurveyMutationRequest = (
  value: unknown,
): SaveSurveyDraftRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    new Set([
      "districtID",
      "studentID",
      "assignmentID",
      "attemptID",
      "definitionID",
      "definitionVersion",
      "expectedRecordVersion",
      "operationID",
      "answers",
    ]),
  );
  const operationID = requireIdentifier(data.operationID, "operationID");
  if (Buffer.byteLength(operationID, "utf8") > 128) {
    throw new HttpsError(
      "invalid-argument",
      "operationID must not exceed 128 UTF-8 bytes.",
    );
  }
  return {
    districtID: requireIdentifier(data.districtID, "districtID"),
    studentID: requireIdentifier(data.studentID, "studentID"),
    assignmentID: requireIdentifier(data.assignmentID, "assignmentID"),
    attemptID: requireIdentifier(data.attemptID, "attemptID"),
    definitionID: requireIdentifier(data.definitionID, "definitionID"),
    definitionVersion: requireInteger(
      data.definitionVersion,
      "definitionVersion",
      1,
    ),
    expectedRecordVersion: requireInteger(
      data.expectedRecordVersion,
      "expectedRecordVersion",
      0,
    ),
    operationID,
    answers: parseSurveyAnswers(data.answers),
  };
};

const parseReviewSurveyResponseRequest = (
  value: unknown,
): ReviewSurveyResponseRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields("studentID", "responseID"),
  );
  const base = parseBaseRequest(data);
  if (Buffer.byteLength(base.idempotencyKey, "utf8") > 128) {
    throw new HttpsError(
      "invalid-argument",
      "idempotencyKey must not exceed 128 UTF-8 bytes.",
    );
  }
  return {
    ...base,
    studentID: requireIdentifier(data.studentID, "studentID"),
    responseID: requireIdentifier(data.responseID, "responseID"),
  };
};

const parseMutateSurveyAssignmentRequest = (
  value: unknown,
): MutateSurveyAssignmentRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    withBaseFields(
      "action",
      "assignmentID",
      "studentID",
      "definitionID",
      "definitionVersion",
    ),
  );
  return {
    ...parseBaseRequest(data),
    action: requireEnum(
      data.action,
      "action",
      ["create", "reassign", "revoke"] as const,
    ),
    assignmentID: requireIdentifier(data.assignmentID, "assignmentID"),
    studentID: requireIdentifier(data.studentID, "studentID"),
    definitionID: requireIdentifier(data.definitionID, "definitionID"),
    definitionVersion: requireInteger(
      data.definitionVersion,
      "definitionVersion",
      1,
    ),
  };
};

const parseRespondentSurveyIdentity = <T>(
  request: CallableRequest<T>,
): RespondentSurveyIdentity => {
  if (request.auth === undefined) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.app === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "App Check verification is required.",
    );
  }
  const token = request.auth.token;
  const assignmentIDs = requireIdentifierArray(
    token.tmiAssignmentIDs,
    "trusted assignment IDs",
    { allowEmpty: false, maximumCount: 1 },
  );
  const operations = requireIdentifierArray(
    token.tmiAllowedOperations,
    "trusted operations",
    { allowEmpty: false, maximumCount: studentModeOperationValues.length },
  );
  const assignmentID = assignmentIDs[0];
  if (
    token.tmiAccessClass !== "respondent" ||
    assignmentID === undefined ||
    new Set(operations).size !== operations.length ||
    !operations.every((operation) =>
      studentModeOperationValues.includes(
        operation as StudentModeOperation,
      ))
  ) {
    throw new HttpsError(
      "permission-denied",
      "The respondent credential scope is malformed.",
    );
  }
  return {
    userID: request.auth.uid,
    districtID: requireIdentifier(token.tmiDistrictID, "trusted districtID"),
    studentID: requireIdentifier(token.tmiStudentID, "trusted studentID"),
    sessionID: requireIdentifier(token.tmiSessionID, "trusted sessionID"),
    assignmentID,
    operations: new Set(operations),
  };
};

const surveyDefinitionLimits = {
  maximumQuestionCount: 100,
  maximumBranchRuleCount: 200,
  maximumOptionCount: 100,
  maximumTextLength: 4_000,
  maximumPromptUTF8Bytes: 500,
  maximumLabelUTF8Bytes: 200,
  maximumImageReferenceUTF8Bytes: 500,
} as const;

const parseSurveyDefinition = (
  data: DocumentData | undefined,
  expectedID: string,
  expectedVersion: number,
): ParsedSurveyDefinition => {
  if (data === undefined) {
    return surveyDataLoss("The assigned survey definition does not exist.");
  }
  if (
    data.schemaVersion !== 1 ||
    data.state !== "published" ||
    data.definitionID !== expectedID ||
    data.version !== expectedVersion ||
    !(data.publishedAt instanceof Timestamp) ||
    typeof data.title !== "string" ||
    data.title.length === 0 ||
    !Array.isArray(data.questions) ||
    data.questions.length === 0 ||
    data.questions.length > surveyDefinitionLimits.maximumQuestionCount ||
    !Array.isArray(data.branchRules) ||
    data.branchRules.length > surveyDefinitionLimits.maximumBranchRuleCount
  ) {
    return surveyDataLoss("The assigned survey definition is malformed.");
  }
  const questionIDs = new Set<string>();
  const questions: ParsedSurveyQuestion[] = data.questions.map(
    (rawQuestion: unknown) => {
      const question = requireRecord(rawQuestion, "survey question");
      const id = requireIdentifier(question.id, "survey question.id");
      if (questionIDs.has(id)) {
        return surveyDataLoss("The survey definition repeats a question ID.");
      }
      questionIDs.add(id);
      const type = requireEnum(
        question.type,
        "survey question.type",
        surveyQuestionTypeValues,
      );
      if (
        typeof question.prompt !== "string" ||
        question.prompt.length === 0 ||
        question.prompt !== question.prompt.trim() ||
        Buffer.byteLength(question.prompt, "utf8") >
          surveyDefinitionLimits.maximumPromptUTF8Bytes ||
        /\p{Cc}/u.test(question.prompt)
      ) {
        return surveyDataLoss("The survey question prompt is malformed.");
      }
      if (typeof question.required !== "boolean") {
        return surveyDataLoss("The survey question required flag is malformed.");
      }
      if (
        !Array.isArray(question.options) ||
        question.options.length > surveyDefinitionLimits.maximumOptionCount
      ) {
        return surveyDataLoss("The survey question options are malformed.");
      }
      const optionIDs = new Set<string>();
      for (const rawOption of question.options) {
        const option = requireRecord(rawOption, "survey option");
        const optionID = requireIdentifier(option.id, "survey option.id");
        if (
          typeof option.label !== "string" ||
          option.label.length === 0 ||
          option.label !== option.label.trim() ||
          Buffer.byteLength(option.label, "utf8") >
            surveyDefinitionLimits.maximumLabelUTF8Bytes ||
          /\p{Cc}/u.test(option.label)
        ) {
          return surveyDataLoss("The survey option label is malformed.");
        }
        if (
          (type === "imageChoice" &&
            (typeof option.imageReference !== "string" ||
              option.imageReference.length === 0)) ||
          (option.imageReference !== undefined &&
            (typeof option.imageReference !== "string" ||
              option.imageReference.length === 0 ||
              option.imageReference !== option.imageReference.trim() ||
              Buffer.byteLength(option.imageReference, "utf8") >
                surveyDefinitionLimits.maximumImageReferenceUTF8Bytes ||
              /\p{Cc}/u.test(option.imageReference)))
        ) {
          return surveyDataLoss("The survey option image reference is malformed.");
        }
        if (optionIDs.has(optionID)) {
          return surveyDataLoss("The survey question repeats an option ID.");
        }
        optionIDs.add(optionID);
      }
      const base = {
        id,
        type,
        required: question.required,
        optionIDs,
      };
      switch (type) {
        case "singleChoice":
        case "imageChoice":
          if (optionIDs.size === 0) {
            return surveyDataLoss("A choice question has no options.");
          }
          return base;
        case "multiSelect": {
          if (optionIDs.size === 0) {
            return surveyDataLoss("A multi-select question has no options.");
          }
          const maxSelections = question.maxSelections === undefined
            ? optionIDs.size
            : requireInteger(
              question.maxSelections,
              "survey question.maxSelections",
              1,
              optionIDs.size,
            );
          return { ...base, maxSelections };
        }
        case "shortText": {
          if (optionIDs.size !== 0) {
            return surveyDataLoss("A text question cannot have options.");
          }
          const maxLength = requireInteger(
            question.maxLength,
            "survey question.maxLength",
            1,
            surveyDefinitionLimits.maximumTextLength,
          );
          return { ...base, maxLength };
        }
        case "rating": {
          if (optionIDs.size !== 0) {
            return surveyDataLoss("A rating question cannot have options.");
          }
          const minimum = requireInteger(
            question.minimum,
            "survey question.minimum",
            Number.MIN_SAFE_INTEGER,
          );
          const maximum = requireInteger(
            question.maximum,
            "survey question.maximum",
            minimum + 1,
          );
          return { ...base, minimum, maximum };
        }
      }
    },
  );
  const questionsByID = new Map(questions.map((question) => [question.id, question]));
  const ruleIDs = new Set<string>();
  const branchRules: ParsedSurveyBranchRule[] = data.branchRules.map(
    (rawRule: unknown) => {
      const rule = requireRecord(rawRule, "survey branch rule");
      const id = requireIdentifier(rule.id, "survey branch rule.id");
      if (ruleIDs.has(id)) {
        return surveyDataLoss("The survey definition repeats a branch rule ID.");
      }
      ruleIDs.add(id);
      const sourceQuestionID = requireIdentifier(
        rule.sourceQuestionID,
        "survey branch rule.sourceQuestionID",
      );
      const targetQuestionID = requireIdentifier(
        rule.targetQuestionID,
        "survey branch rule.targetQuestionID",
      );
      const source = questionsByID.get(sourceQuestionID);
      if (source === undefined || !questionsByID.has(targetQuestionID)) {
        return surveyDataLoss("A survey branch references an unknown question.");
      }
      const predicateData = requireRecord(
        rule.predicate,
        "survey branch rule.predicate",
      );
      const predicateType = requireEnum(
        predicateData.type,
        "survey branch rule.predicate.type",
        surveyPredicateTypeValues,
      );
      let predicate: ParsedSurveyBranchRule["predicate"];
      switch (predicateType) {
        case "equals":
        case "contains": {
          const optionID = requireIdentifier(
            predicateData.value,
            "survey branch rule.predicate.value",
          );
          const expectedType = predicateType === "contains"
            ? "multiSelect"
            : source.type;
          if (
            (predicateType === "contains" && expectedType !== source.type) ||
            (predicateType === "equals" &&
              source.type !== "singleChoice" &&
              source.type !== "imageChoice") ||
            !source.optionIDs.has(optionID)
          ) {
            return surveyDataLoss("A survey branch predicate is incompatible.");
          }
          predicate = { type: predicateType, value: optionID };
          break;
        }
        case "ratingAtLeast": {
          if (
            source.type !== "rating" ||
            source.minimum === undefined ||
            source.maximum === undefined
          ) {
            return surveyDataLoss("A survey branch predicate is incompatible.");
          }
          const value = requireInteger(
            predicateData.value,
            "survey branch rule.predicate.value",
            source.minimum,
            source.maximum,
          );
          predicate = { type: predicateType, value };
          break;
        }
        case "textIsNotEmpty":
          if (source.type !== "shortText") {
            return surveyDataLoss("A survey branch predicate is incompatible.");
          }
          predicate = { type: predicateType };
          break;
      }
      return {
        id,
        sourceQuestionID,
        targetQuestionID,
        priority: requireInteger(
          rule.priority,
          "survey branch rule.priority",
          Number.MIN_SAFE_INTEGER,
        ),
        effect: requireEnum(
          rule.effect,
          "survey branch rule.effect",
          surveyBranchEffectValues,
        ),
        predicate,
      };
    },
  );
  const dependencies = new Map<string, Set<string>>();
  for (const rule of branchRules) {
    const existing = dependencies.get(rule.targetQuestionID) ?? new Set<string>();
    existing.add(rule.sourceQuestionID);
    dependencies.set(rule.targetQuestionID, existing);
  }
  const visited = new Set<string>();
  const visiting = new Set<string>();
  const visit = (questionID: string): void => {
    if (visiting.has(questionID)) {
      return surveyDataLoss("The survey branch graph contains a cycle.");
    }
    if (visited.has(questionID)) {
      return;
    }
    visiting.add(questionID);
    for (const dependency of dependencies.get(questionID) ?? []) {
      visit(dependency);
    }
    visiting.delete(questionID);
    visited.add(questionID);
  };
  for (const question of questions) {
    visit(question.id);
  }
  return {
    data,
    definitionID: expectedID,
    version: expectedVersion,
    questions,
    branchRules,
  };
};

const validateAnswersAgainstDefinition = (
  answers: Readonly<Record<string, SurveyAnswerPayload>>,
  definition: ParsedSurveyDefinition,
  requireVisible: boolean,
): void => {
  const questionsByID = new Map(
    definition.questions.map((question) => [question.id, question]),
  );
  for (const [questionID, answer] of Object.entries(answers)) {
    const question = questionsByID.get(questionID);
    if (question === undefined) {
      throw new HttpsError(
        "invalid-argument",
        "An answer references an unknown question.",
      );
    }
    const typeMatches =
      (question.type === "singleChoice" && answer.type === "single") ||
      (question.type === "multiSelect" && answer.type === "multiple") ||
      (question.type === "shortText" && answer.type === "text") ||
      (question.type === "rating" && answer.type === "rating") ||
      (question.type === "imageChoice" && answer.type === "image");
    if (!typeMatches) {
      throw new HttpsError("invalid-argument", "An answer has the wrong type.");
    }
    if (typeof answer.value === "string") {
      if (
        (answer.type === "single" || answer.type === "image") &&
        !question.optionIDs.has(answer.value)
      ) {
        throw new HttpsError("invalid-argument", "An answer option is unknown.");
      }
      if (answer.type === "text" && answer.value.length > (question.maxLength ?? 0)) {
        throw new HttpsError("invalid-argument", "A text answer is too long.");
      }
    } else if (Array.isArray(answer.value)) {
      if (
        answer.value.length > (question.maxSelections ?? 0) ||
        !answer.value.every((optionID) => question.optionIDs.has(optionID))
      ) {
        throw new HttpsError("invalid-argument", "A multi-select answer is invalid.");
      }
    } else {
      if (
        typeof answer.value !== "number" ||
        answer.value < (question.minimum ?? Number.MAX_SAFE_INTEGER) ||
        answer.value > (question.maximum ?? Number.MIN_SAFE_INTEGER)
      ) {
        throw new HttpsError("invalid-argument", "A rating answer is out of range.");
      }
    }
  }
  if (!requireVisible) {
    return;
  }
  const rulesByTarget = new Map<string, ParsedSurveyBranchRule[]>();
  for (const rule of definition.branchRules) {
    const rules = rulesByTarget.get(rule.targetQuestionID) ?? [];
    rules.push(rule);
    rulesByTarget.set(rule.targetQuestionID, rules);
  }
  const visibility = new Map<string, boolean>();
  const predicateMatches = (
    rule: ParsedSurveyBranchRule,
    answer: SurveyAnswerPayload | undefined,
  ): boolean => {
    if (answer === undefined) {
      return false;
    }
    switch (rule.predicate.type) {
      case "equals":
        return answer.value === rule.predicate.value;
      case "contains":
        return Array.isArray(answer.value) &&
          answer.value.includes(rule.predicate.value as string);
      case "ratingAtLeast":
        return typeof answer.value === "number" &&
          answer.value >= (rule.predicate.value as number);
      case "textIsNotEmpty":
        return typeof answer.value === "string" && answer.value.trim().length > 0;
    }
  };
  const isVisible = (questionID: string): boolean => {
    const cached = visibility.get(questionID);
    if (cached !== undefined) {
      return cached;
    }
    const rules = rulesByTarget.get(questionID);
    if (rules === undefined || rules.length === 0) {
      visibility.set(questionID, true);
      return true;
    }
    const ordered = [...rules].sort((left, right) =>
      left.priority !== right.priority
        ? right.priority - left.priority
        : left.id < right.id ? -1 : left.id > right.id ? 1 : 0,
    );
    for (const rule of ordered) {
      if (
        isVisible(rule.sourceQuestionID) &&
        predicateMatches(rule, answers[rule.sourceQuestionID])
      ) {
        const result = rule.effect === "show";
        visibility.set(questionID, result);
        return result;
      }
    }
    visibility.set(questionID, false);
    return false;
  };
  for (const question of definition.questions) {
    if (!question.required || !isVisible(question.id)) {
      continue;
    }
    const answer = answers[question.id];
    const meaningful = answer !== undefined &&
      (typeof answer.value === "number" ||
        (typeof answer.value === "string" && answer.value.trim().length > 0) ||
        (Array.isArray(answer.value) && answer.value.length > 0));
    if (!meaningful) {
      throw new HttpsError(
        "failed-precondition",
        `A required visible answer is missing for ${question.id}.`,
      );
    }
  }
};

const surveyRequestFingerprint = (
  data: SaveSurveyDraftRequest,
): string => createHash("sha256").update(JSON.stringify(data)).digest("hex");

const requireSurveyScope = async (
  firestore: Firestore,
  transaction: Transaction,
  request: CallableRequest<SaveSurveyDraftRequest>,
  data: SaveSurveyDraftRequest,
  operation: "writeDraft" | "submitAssignment",
): Promise<SurveyScopeData> => {
  const identity = parseRespondentSurveyIdentity(request);
  if (
    identity.districtID !== data.districtID ||
    identity.studentID !== data.studentID ||
    identity.assignmentID !== data.assignmentID ||
    !identity.operations.has(operation)
  ) {
    throw new HttpsError(
      "permission-denied",
      "The survey request is outside the respondent session scope.",
    );
  }
  const sessionReference = firestore.doc(
    `districts/${identity.districtID}/studentModeSessions/${identity.sessionID}`,
  );
  const assignmentReference = firestore.doc(
    `districts/${identity.districtID}/formAssignments/${identity.assignmentID}`,
  );
  const studentReference = firestore.doc(
    `districts/${identity.districtID}/students/${identity.studentID}`,
  );
  const definitionReference = firestore.doc(
    surveyDefinitionPath(data.definitionID, data.definitionVersion),
  );
  const [sessionSnapshot, assignmentSnapshot, studentSnapshot, definitionSnapshot] =
    await Promise.all([
      transaction.get(sessionReference),
      transaction.get(assignmentReference),
      transaction.get(studentReference),
      transaction.get(definitionReference),
    ]);
  const session = sessionSnapshot.data();
  const assignment = assignmentSnapshot.data();
  const student = studentSnapshot.data();
  const expiresAt = session?.expiresAt;
  const storedAssignments = session?.assignmentIDs;
  const storedOperations = session?.allowedOperations;
  if (expiresAt instanceof Timestamp && expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "The respondent session has expired.",
      { kind: "survey-session-expired" },
    );
  }
  if (
    session === undefined ||
    session.status !== "active" ||
    !(expiresAt instanceof Timestamp) ||
    session.districtID !== identity.districtID ||
    session.studentID !== identity.studentID ||
    session.respondentUserID !== identity.userID ||
    !Array.isArray(storedAssignments) ||
    storedAssignments.length !== 1 ||
    storedAssignments[0] !== identity.assignmentID ||
    !Array.isArray(storedOperations) ||
    storedOperations.length !== identity.operations.size ||
    !storedOperations.every((value: unknown) =>
      typeof value === "string" && identity.operations.has(value))
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The respondent session is no longer active.",
      { kind: "survey-session-revoked" },
    );
  }
  if (
    assignment === undefined ||
    assignment.districtId !== identity.districtID ||
    assignment.assignmentType !== "survey" ||
    assignment.isActive !== true ||
    !Array.isArray(assignment.studentIDs) ||
    !assignment.studentIDs.includes(identity.studentID) ||
    assignment.definitionID !== data.definitionID ||
    assignment.definitionVersion !== data.definitionVersion ||
    assignment.attemptID !== data.attemptID
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The survey assignment is revoked or does not match this attempt.",
      { kind: "survey-assignment-revoked" },
    );
  }
  if (
    student === undefined ||
    student.districtId !== identity.districtID ||
    student.isArchived === true
  ) {
    throw new HttpsError(
      "permission-denied",
      "The assigned student is unavailable.",
    );
  }
  const parsedDefinition = parseSurveyDefinition(
    definitionSnapshot.data(),
    data.definitionID,
    data.definitionVersion,
  );
  validateAnswersAgainstDefinition(data.answers, parsedDefinition, false);
  return { identity, assignment, definition: parsedDefinition };
};

const maximumSurveyOperationCount = 128;

interface StoredSurveyOperationResult {
  readonly fingerprint: string;
  readonly userID: string;
  readonly sessionID: string | null;
  readonly recordVersion: number;
}

const requireStoredOperationIDs = (value: unknown): string[] => {
  if (
    !Array.isArray(value) ||
    value.length > maximumSurveyOperationCount ||
    !value.every((item) =>
      isValidIdentifier(item) && Buffer.byteLength(item, "utf8") <= 128) ||
    new Set(value).size !== value.length
  ) {
    return storedSurveyDataLoss(
      "The survey response operation history is malformed.",
    );
  }
  return value;
};

const requireStoredOperationResults = (
  value: unknown,
  operationIDs: readonly string[],
  responseRecordVersion: number,
): Readonly<Record<string, StoredSurveyOperationResult>> => {
  const record = requireRecord(value, "survey response operation results");
  if (
    Object.keys(record).length !== operationIDs.length ||
    !operationIDs.every((operationID) => operationID in record)
  ) {
    return storedSurveyDataLoss(
      "The survey response operation results are malformed.",
    );
  }
  const results: Record<string, StoredSurveyOperationResult> = {};
  for (const operationID of operationIDs) {
    const result = requireRecord(
      record[operationID],
      "survey response operation result",
    );
    if (
      typeof result.fingerprint !== "string" ||
      result.fingerprint.length !== 64 ||
      typeof result.userID !== "string" ||
      (result.sessionID !== null && typeof result.sessionID !== "string")
    ) {
      return storedSurveyDataLoss(
        "The survey response operation result is malformed.",
      );
    }
    const recordVersion = requireInteger(
      result.recordVersion,
      "survey response operation result.recordVersion",
      1,
    );
    if (recordVersion > responseRecordVersion) {
      return storedSurveyDataLoss(
        "The survey response operation result version is malformed.",
      );
    }
    results[operationID] = {
      fingerprint: result.fingerprint,
      userID: result.userID,
      sessionID: result.sessionID,
      recordVersion,
    };
  }
  return results;
};

const exactSurveyReplay = (
  response: DocumentData,
  operationID: string,
  fingerprint: string,
  identity: RespondentSurveyIdentity,
): number | undefined => {
  const operationIDs = requireStoredOperationIDs(response.operationIDs);
  if (!operationIDs.includes(operationID)) {
    return undefined;
  }
  const results = requireStoredOperationResults(
    response.operationResults,
    operationIDs,
    requireInteger(response.recordVersion, "survey response.recordVersion", 1),
  );
  const result = results[operationID];
  if (result === undefined) {
    return storedSurveyDataLoss("The survey replay result is missing.");
  }
  if (
    result.userID !== identity.userID ||
    result.sessionID !== identity.sessionID
  ) {
    throw new HttpsError(
      "permission-denied",
      "The survey operation belongs to a different respondent session.",
    );
  }
  if (result.fingerprint !== fingerprint) {
    throw new HttpsError(
      "already-exists",
      "The survey operation ID was reused with different content.",
    );
  }
  return result.recordVersion;
};

const surveyAssignmentEnvelopeKeys = new Set([
  "schemaVersion",
  "recordVersion",
  "assignmentID",
  "attemptID",
  "districtID",
  "studentID",
  "definitionID",
  "definitionVersion",
  "state",
  "assignedAt",
  "revokedAt",
]);

const requireSurveyAssignmentEnvelope = (
  value: unknown,
  data: MutateSurveyAssignmentRequest,
  recordVersion: number,
): SurveyAssignmentMutationEnvelope => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return storedSurveyDataLoss(
      "The survey assignment operation result is malformed.",
    );
  }
  const assignment = value as Record<string, unknown>;
  if (
    Object.keys(assignment).length !== surveyAssignmentEnvelopeKeys.size ||
    !Object.keys(assignment).every((key) =>
      surveyAssignmentEnvelopeKeys.has(key)) ||
    assignment.schemaVersion !== 1 ||
    assignment.recordVersion !== recordVersion ||
    assignment.assignmentID !== data.assignmentID ||
    !isValidIdentifier(assignment.attemptID) ||
    assignment.districtID !== data.districtID ||
    assignment.studentID !== data.studentID ||
    assignment.definitionID !== data.definitionID ||
    assignment.definitionVersion !== data.definitionVersion ||
    (assignment.state !== "active" && assignment.state !== "revoked") ||
    typeof assignment.assignedAt !== "string"
  ) {
    return storedSurveyDataLoss(
      "The survey assignment operation result is malformed.",
    );
  }
  const assignedAt = new Date(assignment.assignedAt);
  if (
    Number.isNaN(assignedAt.getTime()) ||
    assignedAt.toISOString() !== assignment.assignedAt
  ) {
    return storedSurveyDataLoss(
      "The survey assignment operation timestamp is malformed.",
    );
  }
  if (assignment.state === "active" && assignment.revokedAt !== null) {
    return storedSurveyDataLoss(
      "The active survey assignment result cannot be revoked.",
    );
  }
  if (assignment.state === "revoked") {
    if (typeof assignment.revokedAt !== "string") {
      return storedSurveyDataLoss(
        "The revoked survey assignment result is missing its timestamp.",
      );
    }
    const revokedAt = new Date(assignment.revokedAt);
    if (
      Number.isNaN(revokedAt.getTime()) ||
      revokedAt.toISOString() !== assignment.revokedAt ||
      revokedAt < assignedAt
    ) {
      return storedSurveyDataLoss(
        "The survey assignment revocation timestamp is malformed.",
      );
    }
  }
  return assignment as unknown as SurveyAssignmentMutationEnvelope;
};

const requireStoredSurveyAssignmentForMutation = (
  assignment: DocumentData,
  data: MutateSurveyAssignmentRequest,
  schoolID: string,
): {
  readonly attemptID: string;
  readonly assignedAt: Timestamp;
} => {
  const attemptID = assignment.attemptID;
  const assignedAt = assignment.assignedAt;
  const revokedAt = assignment.revokedAt;
  if (
    assignment.schemaVersion !== 1 ||
    assignment.assignmentID !== data.assignmentID ||
    assignment.districtId !== data.districtID ||
    assignment.schoolId !== schoolID ||
    assignment.assignmentType !== "survey" ||
    typeof assignment.isActive !== "boolean" ||
    !Array.isArray(assignment.studentIDs) ||
    assignment.studentIDs.length !== 1 ||
    assignment.studentIDs[0] !== data.studentID ||
    assignment.definitionID !== data.definitionID ||
    assignment.definitionVersion !== data.definitionVersion ||
    !isValidIdentifier(attemptID) ||
    !isValidIdentifier(assignment.assignedBy) ||
    !isValidIdentifier(assignment.createdBy) ||
    !isValidIdentifier(assignment.updatedBy) ||
    !(assignedAt instanceof Timestamp) ||
    !(assignment.createdAt instanceof Timestamp) ||
    !(assignment.updatedAt instanceof Timestamp) ||
    (revokedAt !== null && !(revokedAt instanceof Timestamp)) ||
    (assignment.isActive === true && revokedAt !== null) ||
    (assignment.isActive === false && !(revokedAt instanceof Timestamp))
  ) {
    return storedSurveyDataLoss(
      "The stored survey assignment schema is malformed.",
    );
  }
  return { attemptID, assignedAt };
};

export const createSurveyHandlers = (
  dependencies: SurveyDependencies,
) => ({
  mutateAssignment: async (
    request: CallableRequest<MutateSurveyAssignmentRequest>,
  ): Promise<SurveyAssignmentMutationResult> => {
    if (request.app === undefined) {
      throw new HttpsError(
        "failed-precondition",
        "App Check verification is required.",
      );
    }
    const data = parseMutateSurveyAssignmentRequest(request.data);
    if (data.action === "create" && data.expectedRecordVersion !== 0) {
      throw new HttpsError(
        "invalid-argument",
        "A new survey assignment must expect record version zero.",
      );
    }
    if (data.action !== "create" && data.expectedRecordVersion < 1) {
      throw new HttpsError(
        "invalid-argument",
        "An existing survey assignment must expect a positive record version.",
      );
    }
    const assignmentPath =
      `districts/${data.districtID}/formAssignments/${data.assignmentID}`;
    const generatedAttemptID = createHash("sha256")
      .update([
        data.districtID,
        data.assignmentID,
        data.action,
        data.idempotencyKey,
      ].join("\u0000"))
      .digest("hex");
    const operationTimestamp = Timestamp.now();
    const operationTimestampISO = operationTimestamp.toDate().toISOString();
    let operationAssignment: SurveyAssignmentMutationEnvelope | undefined;
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: `survey.assignment.${data.action}`,
        targetPath: () => assignmentPath,
        requiredCapability: "student.write.detail",
        auditDetails: () => {
          if (operationAssignment === undefined) {
            return storedSurveyDataLoss(
              "The survey assignment operation result was not captured.",
            );
          }
          return {
            action: data.action,
            assignmentID: data.assignmentID,
            studentID: data.studentID,
            definitionID: data.definitionID,
            definitionVersion: data.definitionVersion,
            generatedAttemptID:
              data.action === "revoke" ? null : generatedAttemptID,
            assignment: operationAssignment,
          };
        },
        mutate: async ({ transaction, membership, identity }) => {
          const assignmentReference = dependencies.firestore.doc(
            assignmentPath,
          );
          const studentReference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          );
          const definitionReference = dependencies.firestore.doc(
            surveyDefinitionPath(data.definitionID, data.definitionVersion),
          );
          const [assignmentSnapshot, studentSnapshot, definitionSnapshot] =
            await Promise.all([
              transaction.get(assignmentReference),
              transaction.get(studentReference),
              transaction.get(definitionReference),
            ]);
          const student = requireExistingData(studentSnapshot, "Student");
          const schoolID = requireSchoolID(student, "Student");
          if (
            student.districtId !== data.districtID ||
            student.isArchived === true ||
            !canReadStudentDetail(membership, data.studentID, schoolID)
          ) {
            throw new HttpsError(
              "permission-denied",
              "The survey assignment student is outside the member's scope.",
            );
          }
          parseSurveyDefinition(
            definitionSnapshot.data(),
            data.definitionID,
            data.definitionVersion,
          );
          if (data.action === "create") {
            if (assignmentSnapshot.exists) {
              throw new HttpsError(
                "already-exists",
                "The survey assignment already exists.",
              );
            }
            operationAssignment = {
              schemaVersion: 1,
              recordVersion: 1,
              assignmentID: data.assignmentID,
              attemptID: generatedAttemptID,
              districtID: data.districtID,
              studentID: data.studentID,
              definitionID: data.definitionID,
              definitionVersion: data.definitionVersion,
              state: "active",
              assignedAt: operationTimestampISO,
              revokedAt: null,
            };
            transaction.create(assignmentReference, {
              schemaVersion: 1,
              recordVersion: 1,
              assignmentID: data.assignmentID,
              attemptID: generatedAttemptID,
              districtId: data.districtID,
              schoolId: schoolID,
              assignmentType: "survey",
              isActive: true,
              studentIDs: [data.studentID],
              definitionID: data.definitionID,
              definitionVersion: data.definitionVersion,
              assignedBy: identity.userID,
              assignedAt: operationTimestamp,
              revokedAt: null,
              createdAt: operationTimestamp,
              createdBy: identity.userID,
              updatedAt: operationTimestamp,
              updatedBy: identity.userID,
            });
            return { recordVersion: 1 };
          }
          const assignment = requireExistingData(
            assignmentSnapshot,
            "Survey assignment",
          );
          assertRecordVersion(
            assignment.recordVersion,
            data.expectedRecordVersion,
          );
          const storedAssignment = requireStoredSurveyAssignmentForMutation(
            assignment,
            data,
            schoolID,
          );
          const nextVersion = data.expectedRecordVersion + 1;
          if (data.action === "reassign") {
            if (generatedAttemptID === storedAssignment.attemptID) {
              return storedSurveyDataLoss(
                "A reassignment must generate a new attempt identity.",
              );
            }
            operationAssignment = {
              schemaVersion: 1,
              recordVersion: nextVersion,
              assignmentID: data.assignmentID,
              attemptID: generatedAttemptID,
              districtID: data.districtID,
              studentID: data.studentID,
              definitionID: data.definitionID,
              definitionVersion: data.definitionVersion,
              state: "active",
              assignedAt: operationTimestampISO,
              revokedAt: null,
            };
            transaction.update(assignmentReference, {
              recordVersion: nextVersion,
              attemptID: generatedAttemptID,
              isActive: true,
              assignedBy: identity.userID,
              assignedAt: operationTimestamp,
              revokedAt: null,
              updatedAt: operationTimestamp,
              updatedBy: identity.userID,
            });
          } else {
            if (assignment.isActive !== true) {
              throw new HttpsError(
                "failed-precondition",
                "The survey assignment is already revoked.",
              );
            }
            operationAssignment = {
              schemaVersion: 1,
              recordVersion: nextVersion,
              assignmentID: data.assignmentID,
              attemptID: storedAssignment.attemptID,
              districtID: data.districtID,
              studentID: data.studentID,
              definitionID: data.definitionID,
              definitionVersion: data.definitionVersion,
              state: "revoked",
              assignedAt: storedAssignment.assignedAt.toDate().toISOString(),
              revokedAt: operationTimestampISO,
            };
            transaction.update(assignmentReference, {
              recordVersion: nextVersion,
              isActive: false,
              revokedAt: operationTimestamp,
              updatedAt: operationTimestamp,
              updatedBy: identity.userID,
            });
          }
          return { recordVersion: nextVersion };
        },
      },
    );
    if (result.replayed) {
      const auditSnapshot = await dependencies.firestore.doc(
        `districts/${data.districtID}/auditEvents/${data.idempotencyKey}`,
      ).get();
      const audit = auditSnapshot.data();
      if (audit === undefined) {
        return storedSurveyDataLoss(
          "The survey assignment audit result is missing.",
        );
      }
      const details = audit.details;
      if (typeof details !== "object" || details === null) {
        return storedSurveyDataLoss(
          "The survey assignment audit details are malformed.",
        );
      }
      operationAssignment = requireSurveyAssignmentEnvelope(
        (details as Record<string, unknown>).assignment,
        data,
        result.recordVersion,
      );
    }
    if (operationAssignment === undefined) {
      return storedSurveyDataLoss(
        "The survey assignment operation result is missing.",
      );
    }
    return {
      ...result,
      assignment: operationAssignment,
    };
  },

  saveDraft: async (
    request: CallableRequest<SaveSurveyDraftRequest>,
  ): Promise<PrivilegedOperationResult> => {
    const data = parseSurveyMutationRequest(request.data);
    const identity = parseRespondentSurveyIdentity(request);
    const fingerprint = surveyRequestFingerprint(data);
    return dependencies.firestore.runTransaction(async (transaction) => {
      const scope = await requireSurveyScope(
        dependencies.firestore,
        transaction,
        request,
        data,
        "writeDraft",
      );
      const reference = dependencies.firestore.doc(
        surveyResponsePath(data.districtID, data.studentID, data.attemptID),
      );
      const snapshot = await transaction.get(reference);
      const response = snapshot.data();
      const replayVersion = response === undefined ? undefined : exactSurveyReplay(
        response,
        data.operationID,
        fingerprint,
        scope.identity,
      );
      if (replayVersion !== undefined) {
        return {
          operationID: data.operationID,
          recordVersion: replayVersion,
          replayed: true,
        };
      }
      if (response === undefined) {
        if (data.expectedRecordVersion !== 0) {
          throw new HttpsError("aborted", "The survey draft version is stale.");
        }
        transaction.create(reference, {
          schemaVersion: 1,
          responseID: data.attemptID,
          districtID: data.districtID,
          studentID: data.studentID,
          assignmentID: data.assignmentID,
          attemptID: data.attemptID,
          definitionID: data.definitionID,
          definitionVersion: data.definitionVersion,
          state: "draft",
          recordVersion: 1,
          answers: data.answers,
          operationIDs: [data.operationID],
          operationResults: {
            [data.operationID]: {
              fingerprint,
              userID: scope.identity.userID,
              sessionID: scope.identity.sessionID,
              recordVersion: 1,
            },
          },
          respondentUserID: scope.identity.userID,
          respondentSessionID: scope.identity.sessionID,
          syncState: "synced",
          hasPendingChanges: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          operationID: data.operationID,
          recordVersion: 1,
          replayed: false,
        };
      }
      const currentVersion = requireInteger(
        response.recordVersion,
        "survey response.recordVersion",
        1,
      );
      if (
        currentVersion !== data.expectedRecordVersion ||
        response.state !== "draft"
      ) {
        throw new HttpsError(
          response.state === "draft" ? "aborted" : "failed-precondition",
          "The survey response can no longer be edited.",
        );
      }
      if (
        response.districtID !== data.districtID ||
        response.studentID !== data.studentID ||
        response.assignmentID !== data.assignmentID ||
        response.attemptID !== data.attemptID ||
        response.definitionID !== data.definitionID ||
        response.definitionVersion !== data.definitionVersion
      ) {
        return surveyDataLoss("The stored survey response scope is malformed.");
      }
      const operationIDs = requireStoredOperationIDs(response.operationIDs);
      if (operationIDs.length >= maximumSurveyOperationCount) {
        throw new HttpsError(
          "resource-exhausted",
          "The survey operation history is full.",
        );
      }
      const operationResults = requireStoredOperationResults(
        response.operationResults,
        operationIDs,
        currentVersion,
      );
      const nextVersion = currentVersion + 1;
      transaction.update(reference, {
        answers: data.answers,
        operationIDs: [...operationIDs, data.operationID],
        operationResults: {
          ...operationResults,
          [data.operationID]: {
            fingerprint,
            userID: scope.identity.userID,
            sessionID: scope.identity.sessionID,
            recordVersion: nextVersion,
          },
        },
        respondentUserID: scope.identity.userID,
        respondentSessionID: scope.identity.sessionID,
        recordVersion: nextVersion,
        syncState: "synced",
        hasPendingChanges: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        operationID: data.operationID,
        recordVersion: nextVersion,
        replayed: false,
      };
    });
  },

  submitResponse: async (
    request: CallableRequest<SubmitSurveyResponseRequest>,
  ): Promise<PrivilegedOperationResult & { readonly submittedAt: string }> => {
    const data = parseSurveyMutationRequest(request.data);
    parseRespondentSurveyIdentity(request);
    const fingerprint = surveyRequestFingerprint(data);
    const result = await dependencies.firestore.runTransaction<
      PrivilegedOperationResult
    >(async (transaction) => {
      const scope = await requireSurveyScope(
        dependencies.firestore,
        transaction,
        request,
        data,
        "submitAssignment",
      );
      validateAnswersAgainstDefinition(data.answers, scope.definition, true);
      const reference = dependencies.firestore.doc(
        surveyResponsePath(data.districtID, data.studentID, data.attemptID),
      );
      const snapshot = await transaction.get(reference);
      const response = snapshot.data();
      if (response === undefined) {
        throw new HttpsError(
          "failed-precondition",
          "A synchronized survey draft is required before submission.",
        );
      }
      const replayVersion = exactSurveyReplay(
        response,
        data.operationID,
        fingerprint,
        scope.identity,
      );
      if (replayVersion !== undefined) {
        if (response.state !== "submitted" && response.state !== "reviewed") {
          return surveyDataLoss("The survey submission replay state is malformed.");
        }
        if (!(response.submittedAt instanceof Timestamp)) {
          return surveyDataLoss("The survey submission time is malformed.");
        }
        return {
          operationID: data.operationID,
          recordVersion: replayVersion,
          replayed: true,
        };
      }
      const currentVersion = requireInteger(
        response.recordVersion,
        "survey response.recordVersion",
        1,
      );
      if (
        currentVersion !== data.expectedRecordVersion ||
        response.state !== "draft"
      ) {
        throw new HttpsError(
          response.state === "draft" ? "aborted" : "failed-precondition",
          "The survey response cannot be submitted from its current state.",
        );
      }
      if (JSON.stringify(response.answers) !== JSON.stringify(data.answers)) {
        throw new HttpsError(
          "aborted",
          "The submitted answers do not match the current draft version.",
        );
      }
      const operationIDs = requireStoredOperationIDs(response.operationIDs);
      if (operationIDs.length >= maximumSurveyOperationCount) {
        throw new HttpsError(
          "resource-exhausted",
          "The survey operation history is full.",
        );
      }
      const operationResults = requireStoredOperationResults(
        response.operationResults,
        operationIDs,
        currentVersion,
      );
      const nextVersion = currentVersion + 1;
      transaction.update(reference, {
        state: "submitted",
        recordVersion: nextVersion,
        operationIDs: [...operationIDs, data.operationID],
        operationResults: {
          ...operationResults,
          [data.operationID]: {
            fingerprint,
            userID: scope.identity.userID,
            sessionID: scope.identity.sessionID,
            recordVersion: nextVersion,
          },
        },
        serverMetadata: {
          submissionOperationID: data.operationID,
          reviewedBy: null,
          reviewOperationID: null,
        },
        submittedAt: FieldValue.serverTimestamp(),
        frozenDefinition: scope.definition.data,
        sourceHistory: {
          definitionID: data.definitionID,
          definitionVersion: data.definitionVersion,
          assignmentID: data.assignmentID,
          attemptID: data.attemptID,
          respondentSessionID: scope.identity.sessionID,
        },
        syncState: "synced",
        hasPendingChanges: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        operationID: data.operationID,
        recordVersion: nextVersion,
        replayed: false,
      };
    });
    const submittedSnapshot = await dependencies.firestore.doc(
      surveyResponsePath(data.districtID, data.studentID, data.attemptID),
    ).get();
    const submittedAt = submittedSnapshot.get("submittedAt");
    if (!(submittedAt instanceof Timestamp)) {
      return surveyDataLoss("The survey submission time is malformed.");
    }
    return {
      operationID: result.operationID,
      recordVersion: result.recordVersion,
      replayed: result.replayed,
      submittedAt: submittedAt.toDate().toISOString(),
    };
  },

  reviewResponse: async (
    request: CallableRequest<ReviewSurveyResponseRequest>,
  ): Promise<PrivilegedOperationResult & {
    readonly reviewedAt: string;
    readonly reviewerUserID: string;
  }> => {
    const data = parseReviewSurveyResponseRequest(request.data);
    const reviewerIdentity = parseTrustedCallableIdentity(request);
    const result = await executePrivilegedOperation(
      dependencies.firestore,
      request,
      data,
      {
        action: "survey.response.review",
        targetPath: () => surveyResponsePath(
          data.districtID,
          data.studentID,
          data.responseID,
        ),
        requiredCapability: "student.write.detail",
        auditDetails: () => ({
          studentID: data.studentID,
          responseID: data.responseID,
        }),
        mutate: async ({ transaction, membership, identity }) => {
          const responseReference = dependencies.firestore.doc(
            surveyResponsePath(
              data.districtID,
              data.studentID,
              data.responseID,
            ),
          );
          const studentReference = dependencies.firestore.doc(
            `districts/${data.districtID}/students/${data.studentID}`,
          );
          const [responseSnapshot, studentSnapshot] = await Promise.all([
            transaction.get(responseReference),
            transaction.get(studentReference),
          ]);
          const response = requireExistingData(
            responseSnapshot,
            "Survey response",
          );
          const student = requireExistingData(studentSnapshot, "Student");
          const schoolID = requireSchoolID(student, "Student");
          if (
            student.districtId !== data.districtID ||
            !canReadStudentDetail(membership, data.studentID, schoolID) ||
            response.districtID !== data.districtID ||
            response.studentID !== data.studentID ||
            response.responseID !== data.responseID
          ) {
            throw new HttpsError(
              "permission-denied",
              "The survey response is outside the member's scope.",
            );
          }
          assertRecordVersion(
            response.recordVersion,
            data.expectedRecordVersion,
          );
          if (response.state !== "submitted") {
            throw new HttpsError(
              "failed-precondition",
              "Only a submitted survey response can be reviewed.",
            );
          }
          const operationIDs = requireStoredOperationIDs(response.operationIDs);
          if (operationIDs.includes(data.idempotencyKey)) {
            throw new HttpsError(
              "already-exists",
              "The review ID collides with an existing survey operation.",
            );
          }
          if (operationIDs.length >= maximumSurveyOperationCount) {
            throw new HttpsError(
              "resource-exhausted",
              "The survey operation history is full.",
            );
          }
          const operationResults = requireStoredOperationResults(
            response.operationResults,
            operationIDs,
            data.expectedRecordVersion,
          );
          const serverMetadata = requireRecord(
            response.serverMetadata,
            "survey response server metadata",
          );
          if (typeof serverMetadata.submissionOperationID !== "string") {
            return surveyDataLoss("The survey submission metadata is malformed.");
          }
          const nextVersion = data.expectedRecordVersion + 1;
          transaction.update(responseReference, {
            state: "reviewed",
            recordVersion: nextVersion,
            operationIDs: [...operationIDs, data.idempotencyKey],
            operationResults: {
              ...operationResults,
              [data.idempotencyKey]: {
                fingerprint: createHash("sha256")
                  .update(JSON.stringify(data))
                  .digest("hex"),
                userID: identity.userID,
                sessionID: null,
                recordVersion: nextVersion,
              },
            },
            reviewedAt: FieldValue.serverTimestamp(),
            serverMetadata: {
              submissionOperationID: serverMetadata.submissionOperationID,
              reviewedBy: identity.userID,
              reviewOperationID: data.idempotencyKey,
            },
            updatedAt: FieldValue.serverTimestamp(),
          });
          return { recordVersion: nextVersion };
        },
      },
    );
    const snapshot = await dependencies.firestore.doc(
      surveyResponsePath(data.districtID, data.studentID, data.responseID),
    ).get();
    const reviewedAt = snapshot.get("reviewedAt");
    if (!(reviewedAt instanceof Timestamp)) {
      return surveyDataLoss("The survey review time is malformed.");
    }
    return {
      ...result,
      reviewedAt: reviewedAt.toDate().toISOString(),
      reviewerUserID: reviewerIdentity.userID,
    };
  },
});

const productionSurveyHandlers = createSurveyHandlers({
  firestore: getFirestore(),
});

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
  productionStudentModeHandlers.issueSession,
);
export const restoreStudentModeSession = onCall(
  callableOptions,
  productionStudentModeHandlers.restoreSession,
);
export const endStudentModeSession = onCall(
  callableOptions,
  productionStudentModeHandlers.endSession,
);
export const saveSurveyDraft = onCall(
  callableOptions,
  productionSurveyHandlers.saveDraft,
);
export const mutateSurveyAssignment = onCall(
  callableOptions,
  productionSurveyHandlers.mutateAssignment,
);
export const submitSurveyResponse = onCall(
  callableOptions,
  productionSurveyHandlers.submitResponse,
);
export const reviewSurveyResponse = onCall(
  callableOptions,
  productionSurveyHandlers.reviewResponse,
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
