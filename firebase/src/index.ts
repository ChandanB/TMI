import { createHash } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from "firebase-functions/v2/https";
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
          assignedStudentIDs: [...data.assignedStudentIDs],
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

const grantStudentDetailAccessHandler = async (
  request: CallableRequest<GrantStudentDetailAccessRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseGrantStudentDetailAccessRequest(request.data);
  const firestore = getFirestore();
  const result = await executePrivilegedOperation(
    firestore,
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
        const studentReference = firestore.doc(
          `districts/${data.districtID}/students/${data.studentID}`,
        );
        const targetReference = firestore.doc(
          `districts/${data.districtID}/members/${data.targetUserID}`,
        );
        const [studentSnapshot, targetSnapshot] = await Promise.all([
          transaction.get(studentReference),
          transaction.get(targetReference),
        ]);
        const student = requireExistingData(studentSnapshot, "Student");
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
        const targetSchoolIDs = requireStoredIdentifierArray(
          target.schoolIDs,
          "membership.schoolIDs",
        );
        if (!targetSchoolIDs.includes(schoolID)) {
          throw new HttpsError(
            "failed-precondition",
            "The target member is not assigned to the student's school.",
          );
        }
        const assignments = new Set(
          requireStoredIdentifierArray(
            target.assignedStudentIDs,
            "membership.assignedStudentIDs",
          ),
        );
        assignments.add(data.studentID);
        const nextVersion = data.expectedRecordVersion + 1;
        transaction.update(targetReference, {
          assignedStudentIDs: [...assignments].sort(),
          recordVersion: nextVersion,
          version: nextVersion,
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
