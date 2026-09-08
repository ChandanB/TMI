import { createHash } from "node:crypto";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import {
  HttpsError,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {
  assertDistrict,
  assertRecordVersion,
  parseBaseRequest,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireIdentifier,
  requireRecord,
  requireTrustedMembership,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
  type StaffRole,
} from "./authz.js";

export const personalAccountSubcollections = [
  "private",
  "preferences",
  "notifications",
  "recommendations",
  "savedCareers",
  "careerBookmarks",
  "careerExplorations",
  "careerState",
  "settings",
  "activity",
  "interests",
  "hobbies",
  "resources",
] as const;

const retainedAccountSubcollections = new Set([
  "students",
  "plans",
  "tmiPlans",
  "formTemplates",
  "formAssignments",
  "formSubmissions",
  "meetings",
  "interestSurveys",
  "consents",
  "restrictedRecords",
  "auditLogs",
  "auditEvents",
  "complianceAudits",
  "metricSnapshots",
]);

const unsafeCollection = personalAccountSubcollections.find((collectionName) =>
  retainedAccountSubcollections.has(collectionName),
);
if (unsafeCollection !== undefined) {
  throw new Error(
    `Unsafe account deletion policy overlap: ${unsafeCollection}.`,
  );
}

const accountDeletionAction = "account.personalData.delete";
const operationStatusInProgress = "inProgress";
const operationStatusReadyForAuth = "readyForAuthDeletion";
const maximumReauthenticationAgeSeconds = 10 * 60;
const maximumClockSkewSeconds = 60;

export interface DeletePersonalAccountDataRequest
  extends PrivilegedBaseRequest {
  readonly userID: string;
}

export interface AccountDeletionDependencies {
  readonly firestore: Firestore;
  readonly now: () => Date;
  readonly deleteStoragePrefix: (prefix: string) => Promise<void>;
  readonly deleteAuthUser: (userID: string) => Promise<void>;
}

interface PreparedDeletion {
  readonly cleanupRequired: boolean;
  readonly replayed: boolean;
  readonly lastRole: StaffRole;
}

export const parseDeletePersonalAccountDataRequest = (
  value: unknown,
): DeletePersonalAccountDataRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(
    data,
    new Set([
      "districtID",
      "userID",
      "expectedRecordVersion",
      "idempotencyKey",
      "reasonCode",
    ]),
  );
  return {
    ...parseBaseRequest(data),
    userID: requireIdentifier(data.userID, "userID"),
  };
};

export const createDeletePersonalAccountDataHandler = (
  dependencies: AccountDeletionDependencies,
) => async (
  request: CallableRequest<DeletePersonalAccountDataRequest>,
): Promise<PrivilegedOperationResult> => {
  const data = parseDeletePersonalAccountDataRequest(request.data);
  const identity = parseTrustedCallableIdentity(request);
  assertDistrict(identity, data.districtID);
  if (identity.userID !== data.userID) {
    throw new HttpsError(
      "permission-denied",
      "An account can only delete its own personal data.",
    );
  }
  requireRecentReauthentication(request, dependencies.now());

  const requestHash = hashCanonicalJSON(data);
  const attributionID = createAttributionID(data);
  const operationReference = dependencies.firestore.doc(
    `districts/${data.districtID}/accountDeletionOperations/${data.idempotencyKey}`,
  );
  const userReference = dependencies.firestore.doc(`users/${data.userID}`);

  const prepared = await dependencies.firestore.runTransaction(
    async (transaction) => {
      const operationSnapshot = await transaction.get(operationReference);
      if (operationSnapshot.exists) {
        const operation = validatePriorOperation(
          operationSnapshot.data() ?? {},
          requestHash,
          attributionID,
        );
        return {
          cleanupRequired: operation.status === operationStatusInProgress,
          replayed: true,
          lastRole: operation.lastRole,
        };
      }

      const membership = await requireTrustedMembership(
        dependencies.firestore,
        transaction,
        identity,
      );
      const userSnapshot = await transaction.get(userReference);
      if (userSnapshot.exists) {
        assertRecordVersion(
          userSnapshot.data()?.recordVersion ?? 0,
          data.expectedRecordVersion,
        );
      } else if (data.expectedRecordVersion !== 0) {
        throw new HttpsError("not-found", "Personal profile was not found.");
      }

      transaction.create(operationReference, {
        schemaVersion: 1,
        recordVersion: data.expectedRecordVersion + 1,
        action: accountDeletionAction,
        requestHash,
        actorAttributionID: attributionID,
        lastRole: membership.role,
        status: operationStatusInProgress,
        createdAt: Timestamp.fromDate(dependencies.now()),
      });
      return {
        cleanupRequired: true,
        replayed: false,
        lastRole: membership.role,
      };
    },
  );

  if (prepared.cleanupRequired) {
    for (const collectionName of personalAccountSubcollections) {
      await dependencies.firestore.recursiveDelete(
        userReference.collection(collectionName),
      );
    }
    for (const prefix of [
      `users/${data.userID}/`,
      `profile_images/${data.userID}/`,
    ]) {
      await dependencies.deleteStoragePrefix(prefix);
    }
    await userReference.delete();
    await finalizeInstitutionalAttribution(
      dependencies,
      data,
      requestHash,
      attributionID,
      prepared.lastRole,
    );
  }

  // This must remain the final mutation. A ready-for-Auth marker makes retries
  // skip completed cleanup while safely retrying a failed Auth deletion.
  await dependencies.deleteAuthUser(data.userID);

  return {
    operationID: data.idempotencyKey,
    recordVersion: data.expectedRecordVersion + 1,
    replayed: prepared.replayed,
  };
};

export const createProductionDeletePersonalAccountDataHandler = () =>
  createDeletePersonalAccountDataHandler({
    firestore: getFirestore(),
    now: () => new Date(),
    deleteStoragePrefix: async (prefix) => {
      await getStorage().bucket().deleteFiles({ prefix });
    },
    deleteAuthUser: async (userID) => {
      try {
        await getAuth().deleteUser(userID);
      } catch (error) {
        if (!isAuthUserNotFound(error)) {
          throw error;
        }
      }
    },
  });

const requireRecentReauthentication = (
  request: Pick<CallableRequest<unknown>, "auth">,
  now: Date,
): void => {
  const authTime = request.auth?.token.auth_time;
  const nowSeconds = Math.floor(now.getTime() / 1_000);
  if (
    typeof authTime !== "number" ||
    !Number.isSafeInteger(authTime) ||
    authTime > nowSeconds + maximumClockSkewSeconds ||
    nowSeconds - authTime > maximumReauthenticationAgeSeconds
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Recent reauthentication is required before account deletion.",
    );
  }
};

const finalizeInstitutionalAttribution = async (
  dependencies: AccountDeletionDependencies,
  data: DeletePersonalAccountDataRequest,
  requestHash: string,
  attributionID: string,
  lastRole: StaffRole,
): Promise<void> => {
  const operationReference = dependencies.firestore.doc(
    `districts/${data.districtID}/accountDeletionOperations/${data.idempotencyKey}`,
  );
  const membershipReference = dependencies.firestore.doc(
    `districts/${data.districtID}/members/${data.userID}`,
  );
  const formerUserReference = dependencies.firestore.doc(
    `districts/${data.districtID}/formerUsers/${attributionID}`,
  );
  const auditReference = dependencies.firestore.doc(
    `districts/${data.districtID}/auditEvents/${data.idempotencyKey}`,
  );
  const timestamp = Timestamp.fromDate(dependencies.now());

  await dependencies.firestore.runTransaction(async (transaction) => {
    const [operationSnapshot, membershipSnapshot, formerUserSnapshot, auditSnapshot] =
      await Promise.all([
        transaction.get(operationReference),
        transaction.get(membershipReference),
        transaction.get(formerUserReference),
        transaction.get(auditReference),
      ]);
    const operation = validatePriorOperation(
      operationSnapshot.data() ?? {},
      requestHash,
      attributionID,
    );
    if (operation.status === operationStatusReadyForAuth) {
      return;
    }
    if (!membershipSnapshot.exists) {
      throw new HttpsError(
        "data-loss",
        "The institutional membership record is missing.",
      );
    }
    if (formerUserSnapshot.exists || auditSnapshot.exists) {
      throw new HttpsError(
        "already-exists",
        "The deletion attribution key conflicts with an existing record.",
      );
    }

    transaction.create(formerUserReference, {
      schemaVersion: 1,
      recordVersion: 1,
      kind: "formerUser",
      districtID: data.districtID,
      attributionID,
      lastRole,
      endedAt: timestamp,
    });
    transaction.create(auditReference, {
      schemaVersion: 1,
      recordVersion: 1,
      action: accountDeletionAction,
      actorType: "formerUser",
      actorAttributionID: attributionID,
      districtID: data.districtID,
      targetPath: `districts/${data.districtID}/formerUsers/${attributionID}`,
      reasonCode: data.reasonCode,
      requestHash,
      details: {
        deletedScope: "personal-account-data",
        institutionalRecordsPreserved: true,
        deletedSubcollections: [...personalAccountSubcollections],
      },
      result: { recordVersion: data.expectedRecordVersion + 1 },
      createdAt: timestamp,
    });
    transaction.update(membershipReference, {
      isActive: false,
      formerUserAttributionID: attributionID,
      endedAt: timestamp,
      updatedAt: timestamp,
      userID: FieldValue.delete(),
      uid: FieldValue.delete(),
      email: FieldValue.delete(),
      displayName: FieldValue.delete(),
      name: FieldValue.delete(),
      photoURL: FieldValue.delete(),
      profilePhotoURL: FieldValue.delete(),
    });
    transaction.update(operationReference, {
      status: operationStatusReadyForAuth,
      cleanupCompletedAt: timestamp,
    });
  });
};

const validatePriorOperation = (
  operation: DocumentData,
  requestHash: string,
  attributionID: string,
): { readonly status: string; readonly lastRole: StaffRole } => {
  const status = operation.status;
  const lastRole = operation.lastRole;
  if (
    operation.action !== accountDeletionAction ||
    operation.requestHash !== requestHash ||
    operation.actorAttributionID !== attributionID
  ) {
    throw new HttpsError(
      "already-exists",
      "The idempotency key was already used for a different operation.",
    );
  }
  if (
    status !== operationStatusInProgress &&
    status !== operationStatusReadyForAuth
  ) {
    throw new HttpsError("data-loss", "The deletion state is malformed.");
  }
  if (!isStaffRole(lastRole)) {
    throw new HttpsError("data-loss", "The former role is malformed.");
  }
  return { status, lastRole };
};

const staffRoles = new Set<string>([
  "teacher",
  "counselor",
  "socialWorker",
  "schoolAdministrator",
  "districtAdministrator",
]);

const isStaffRole = (value: unknown): value is StaffRole =>
  typeof value === "string" && staffRoles.has(value);

const createAttributionID = (
  data: DeletePersonalAccountDataRequest,
): string =>
  createHash("sha256")
    .update(
      [
        "tmi-former-user-v1",
        data.districtID,
        data.userID,
        data.idempotencyKey,
      ].join(":"),
    )
    .digest("hex");

const hashCanonicalJSON = (value: unknown): string =>
  createHash("sha256")
    .update(JSON.stringify(canonicalize(value)))
    .digest("hex");

const canonicalize = (value: unknown): unknown => {
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
};

const isAuthUserNotFound = (error: unknown): boolean =>
  typeof error === "object" &&
  error !== null &&
  "code" in error &&
  (error as { readonly code?: unknown }).code === "auth/user-not-found";
