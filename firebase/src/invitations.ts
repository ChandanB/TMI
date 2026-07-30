import { createHash, createHmac, randomBytes } from "node:crypto";
import { getAuth } from "firebase-admin/auth";
import {
  Timestamp,
  getFirestore,
  type DocumentData,
  type Firestore,
} from "firebase-admin/firestore";
import {
  HttpsError,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {
  capabilityValues,
  isValidIdentifier,
  rejectUnexpectedFields,
  requireRecord,
  requireString,
  staffRoleValues,
  type Capability,
  type StaffRole,
} from "./authz.js";

export const requiredPolicyVersions = {
  privacyPolicy: "2026-07-20",
  acceptableUsePolicy: "2026-07-20",
} as const;

export interface ProvisionStaffMembershipRequest {
  readonly invitationCode: string;
  readonly displayName: string;
  readonly privacyPolicyVersion: string;
  readonly acceptableUsePolicyVersion: string;
}

export interface ProvisionStaffMembershipResult {
  readonly userID: string;
  readonly districtID: string;
  readonly schoolIDs: readonly string[];
  readonly role: StaffRole;
  readonly capabilities: readonly Capability[];
  readonly assignedStudentIDs: readonly string[];
  readonly isActive: true;
  readonly version: number;
  readonly replayed: boolean;
}

export interface ProvisioningAuthUser {
  readonly userID: string;
  readonly email: string | undefined;
  readonly emailVerified: boolean;
  readonly disabled: boolean;
  readonly customClaims: Readonly<Record<string, unknown>>;
}

export interface ProvisionStaffMembershipDependencies {
  readonly firestore: Firestore;
  readonly now: () => Date;
  readonly requireVerifiedEmail: boolean;
  readonly getAuthUser: (userID: string) => Promise<ProvisioningAuthUser>;
  readonly setCustomUserClaims: (
    userID: string,
    claims: Readonly<Record<string, unknown>>,
  ) => Promise<void>;
}

interface TrustedInvitation {
  readonly recordVersion: number;
  readonly districtID: string;
  readonly recipientEmailHash: string;
  readonly role: StaffRole;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly isActive: boolean;
  readonly expiresAt: Timestamp;
  readonly consumedByUserID: string | null;
  readonly consumedAt: Timestamp | null;
}

const allowedRequestFields = new Set([
  "invitationCode",
  "displayName",
  "privacyPolicyVersion",
  "acceptableUsePolicyVersion",
]);
const allowedRoles = new Set<string>(staffRoleValues);
const allowedCapabilities = new Set<string>(capabilityValues);
const opaqueInvitationPattern = /^[A-Za-z0-9_-]{43}$/;
const sha256Pattern = /^[a-f0-9]{64}$/;

export const hashInvitationCode = (invitationCode: string): string =>
  createHash("sha256").update(invitationCode, "utf8").digest("hex");

export const generateStaffInvitationCode = (): string =>
  randomBytes(32).toString("base64url");

export const hashInvitationRecipientEmail = (
  invitationCode: string,
  email: string,
): string =>
  createHmac("sha256", invitationCode)
    .update("tmi:staff-invitation-recipient:v1\0", "utf8")
    .update(normalizeEmail(email), "utf8")
    .digest("hex");

export const parseProvisionStaffMembershipRequest = (
  value: unknown,
): ProvisionStaffMembershipRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, allowedRequestFields);
  const invitationCode = requireString(
    data.invitationCode,
    "invitationCode",
    256,
  );
  if (!opaqueInvitationPattern.test(invitationCode)) {
    throw new HttpsError(
      "invalid-argument",
      "invitationCode must be an opaque invitation value.",
    );
  }

  const privacyPolicyVersion = requireString(
    data.privacyPolicyVersion,
    "privacyPolicyVersion",
    100,
  );
  const acceptableUsePolicyVersion = requireString(
    data.acceptableUsePolicyVersion,
    "acceptableUsePolicyVersion",
    100,
  );
  if (
    privacyPolicyVersion !== requiredPolicyVersions.privacyPolicy ||
    acceptableUsePolicyVersion !== requiredPolicyVersions.acceptableUsePolicy
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Current privacy and acceptable-use terms must be accepted.",
    );
  }

  return {
    invitationCode,
    displayName: requireString(data.displayName, "displayName", 200),
    privacyPolicyVersion,
    acceptableUsePolicyVersion,
  };
};

export const createProvisionStaffMembershipHandler = (
  dependencies: ProvisionStaffMembershipDependencies,
) => async (
  request: CallableRequest<ProvisionStaffMembershipRequest>,
): Promise<ProvisionStaffMembershipResult> => {
  const data = parseProvisionStaffMembershipRequest(request.data);
  const userID = requireOnboardingIdentity(request);
  const authUser = await dependencies.getAuthUser(userID);
  const normalizedEmail = validateAuthUser(
    authUser,
    userID,
    dependencies.requireVerifiedEmail,
  );

  const invitationReference = dependencies.firestore.doc(
    `staffInvitations/${hashInvitationCode(data.invitationCode)}`,
  );
  const timestamp = Timestamp.fromDate(dependencies.now());
  const result = await dependencies.firestore.runTransaction(
    async (transaction) => {
      const invitationSnapshot = await transaction.get(invitationReference);
      if (!invitationSnapshot.exists) {
        throw unusableInvitationError();
      }
      const invitation = parseTrustedInvitation(
        invitationSnapshot.data() ?? {},
      );
      if (invitation.consumedByUserID !== null) {
        if (invitation.consumedByUserID !== userID) {
          throw unusableInvitationError();
        }
        return readIdempotentMembership(
          dependencies.firestore,
          transaction,
          invitation,
          userID,
          normalizedEmail,
          authUser.customClaims,
        );
      }
      if (
        !invitation.isActive ||
        invitation.expiresAt.toMillis() <= dependencies.now().getTime() ||
        invitation.recipientEmailHash !==
          hashInvitationRecipientEmail(data.invitationCode, normalizedEmail)
      ) {
        throw unusableInvitationError();
      }

      const paths = onboardingPaths(invitation.districtID, userID);
      const references = {
        membership: dependencies.firestore.doc(paths.membership),
        profile: dependencies.firestore.doc(paths.profile),
        preferences: dependencies.firestore.doc(paths.preferences),
        privacy: dependencies.firestore.doc(paths.privacyAcknowledgement),
        acceptableUse: dependencies.firestore.doc(
          paths.acceptableUseAcknowledgement,
        ),
        audit: dependencies.firestore.doc(paths.audit),
      };
      const existingSnapshots = await Promise.all([
        transaction.get(references.membership),
        transaction.get(references.profile),
        transaction.get(references.preferences),
        transaction.get(references.privacy),
        transaction.get(references.acceptableUse),
        transaction.get(references.audit),
      ]);
      const [
        membershipSnapshot,
        profileSnapshot,
        preferencesSnapshot,
        privacySnapshot,
        acceptableUseSnapshot,
        auditSnapshot,
      ] = existingSnapshots;
      const existingMembership = membershipSnapshot.data();
      const membershipVersion = existingMembership?.version ?? 1;
      const assignedStudentIDs = existingMembership?.assignedStudentIDs ?? [];
      if (
        membershipSnapshot.exists &&
        !isCompatibleMembership(existingMembership, invitation, userID)
      ) {
        throw incompatibleExistingRecordError();
      }
      requireCompatibleTrustedClaims(
        authUser.customClaims,
        invitation,
        membershipVersion,
      );
      if (
        profileSnapshot.exists &&
        !isCompatibleProfile(profileSnapshot.data(), userID, normalizedEmail)
      ) {
        throw incompatibleExistingRecordError();
      }
      if (
        preferencesSnapshot.exists &&
        !isCompatiblePreferences(preferencesSnapshot.data())
      ) {
        throw incompatibleExistingRecordError();
      }
      const expectedAuditHash = hashAuditRequest({
        userID,
        districtID: invitation.districtID,
        role: invitation.role,
        schoolIDs: invitation.schoolIDs,
        capabilities: invitation.capabilities,
        privacyPolicyVersion: data.privacyPolicyVersion,
        acceptableUsePolicyVersion: data.acceptableUsePolicyVersion,
      });
      if (
        privacySnapshot.exists &&
        !isCompatibleAcknowledgement(
          privacySnapshot.data(),
          "privacyPolicy",
          data.privacyPolicyVersion,
          userID,
        )
      ) {
        throw incompatibleExistingRecordError();
      }
      if (
        acceptableUseSnapshot.exists &&
        !isCompatibleAcknowledgement(
          acceptableUseSnapshot.data(),
          "acceptableUsePolicy",
          data.acceptableUsePolicyVersion,
          userID,
        )
      ) {
        throw incompatibleExistingRecordError();
      }
      if (
        auditSnapshot.exists &&
        !isCompatibleAudit(
          auditSnapshot.data(),
          invitation,
          paths.membership,
          userID,
          expectedAuditHash,
        )
      ) {
        throw incompatibleExistingRecordError();
      }

      if (!membershipSnapshot.exists) transaction.create(references.membership, {
        schemaVersion: 1,
        recordVersion: 1,
        userID,
        districtID: invitation.districtID,
        schoolIDs: [...invitation.schoolIDs],
        role: invitation.role,
        capabilities: [...invitation.capabilities],
        assignedStudentIDs: [],
        isActive: true,
        version: 1,
        createdAt: timestamp,
        createdBy: userID,
        updatedAt: timestamp,
        updatedBy: userID,
      });
      if (!profileSnapshot.exists) transaction.create(references.profile, {
        schemaVersion: 1,
        recordVersion: 1,
        userID,
        displayName: data.displayName,
        email: normalizedEmail,
        isEmailVerified: authUser.emailVerified,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      if (!preferencesSnapshot.exists) transaction.create(references.preferences, {
        schemaVersion: 1,
        recordVersion: 1,
        onboardingComplete: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
      if (!privacySnapshot.exists) transaction.create(references.privacy, {
        schemaVersion: 1,
        recordVersion: 1,
        documentID: "privacyPolicy",
        version: data.privacyPolicyVersion,
        acceptedAt: timestamp,
        operationID: `staff-provision-${userID}`,
      });
      if (!acceptableUseSnapshot.exists) transaction.create(references.acceptableUse, {
        schemaVersion: 1,
        recordVersion: 1,
        documentID: "acceptableUsePolicy",
        version: data.acceptableUsePolicyVersion,
        acceptedAt: timestamp,
        operationID: `staff-provision-${userID}`,
      });
      if (!auditSnapshot.exists) transaction.create(references.audit, {
        schemaVersion: 1,
        recordVersion: 1,
        action: "staff.membership.provision",
        actorUserID: userID,
        districtID: invitation.districtID,
        targetPath: paths.membership,
        reasonCode: "staff-invitation-accepted",
        requestHash: expectedAuditHash,
        details: {
          role: invitation.role,
          schoolIDs: [...invitation.schoolIDs],
          capabilities: [...invitation.capabilities],
        },
        result: { recordVersion: 1 },
        createdAt: timestamp,
      });
      transaction.update(invitationReference, {
        recordVersion: invitation.recordVersion + 1,
        isActive: false,
        consumedByUserID: userID,
        consumedAt: timestamp,
      });
      return membershipResult(
        invitation,
        userID,
        false,
        membershipVersion,
        assignedStudentIDs,
      );
    },
  );

  try {
    await dependencies.setCustomUserClaims(userID, {
      ...authUser.customClaims,
      tmiDistrictID: result.districtID,
      tmiAccessClass: "staff",
      tmiMembershipVersion: result.version,
    });
  } catch {
    throw new HttpsError(
      "unavailable",
      "Membership was provisioned, but authorization refresh is pending. Retry.",
    );
  }
  return result;
};

export const createProductionProvisionStaffMembershipHandler = () =>
  createProvisionStaffMembershipHandler({
    firestore: getFirestore(),
    now: () => new Date(),
    requireVerifiedEmail: false,
    getAuthUser: async (userID) => {
      const user = await getAuth().getUser(userID);
      return {
        userID: user.uid,
        email: user.email,
        emailVerified: user.emailVerified,
        disabled: user.disabled,
        customClaims: user.customClaims ?? {},
      };
    },
    setCustomUserClaims: async (userID, claims) => {
      await getAuth().setCustomUserClaims(userID, claims);
    },
  });

const requireOnboardingIdentity = (
  request: Pick<CallableRequest<unknown>, "app" | "auth">,
): string => {
  if (request.auth === undefined) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.app === undefined) {
    throw new HttpsError(
      "failed-precondition",
      "A verified App Check token is required.",
    );
  }
  if (!isValidIdentifier(request.auth.uid)) {
    throw new HttpsError(
      "permission-denied",
      "The authenticated identity is malformed.",
    );
  }
  return request.auth.uid;
};

const validateAuthUser = (
  authUser: ProvisioningAuthUser,
  requestedUserID: string,
  requireVerifiedEmail: boolean,
): string => {
  if (
    authUser.userID !== requestedUserID ||
    authUser.disabled ||
    typeof authUser.email !== "string" ||
    authUser.email.trim().length === 0
  ) {
    throw new HttpsError(
      "permission-denied",
      "The authenticated account cannot accept an invitation.",
    );
  }
  if (requireVerifiedEmail && !authUser.emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the account email before accepting an invitation.",
    );
  }
  return normalizeEmail(authUser.email);
};

const normalizeEmail = (email: string): string =>
  email.trim().toLocaleLowerCase("en-US");

const requireCompatibleTrustedClaims = (
  claims: Readonly<Record<string, unknown>>,
  invitation: TrustedInvitation,
  expectedMembershipVersion: number | true,
): void => {
  const districtID = claims.tmiDistrictID;
  const accessClass = claims.tmiAccessClass;
  const membershipVersion = claims.tmiMembershipVersion;
  const hasTrustedClaim =
    districtID !== undefined ||
    accessClass !== undefined ||
    membershipVersion !== undefined;
  if (!hasTrustedClaim) {
    return;
  }
  if (
    districtID === invitation.districtID &&
    accessClass === "staff" &&
    claims.tmiMembershipVersion ===
      (expectedMembershipVersion === true ? 1 : expectedMembershipVersion)
  ) {
    return;
  }
  throw new HttpsError(
    "permission-denied",
    "The account already has incompatible trusted authorization claims.",
  );
};

const incompatibleExistingRecordError = (): HttpsError =>
  new HttpsError(
    "permission-denied",
    "Existing onboarding records are incompatible with this invitation.",
  );

const isCompatibleMembership = (
  membership: DocumentData | undefined,
  invitation: TrustedInvitation,
  userID: string,
): membership is DocumentData =>
  membership?.schemaVersion === 1 &&
  membership.recordVersion === 1 &&
  membership.userID === userID &&
  membership.districtID === invitation.districtID &&
  membership.role === invitation.role &&
  equalStringArrays(membership.schoolIDs, invitation.schoolIDs) &&
  equalStringArrays(membership.capabilities, invitation.capabilities) &&
  parseIdentifierArray(membership.assignedStudentIDs, 10_000) !== null &&
  membership.isActive === true &&
  Number.isSafeInteger(membership.version) &&
  membership.version > 0;

const isCompatibleProfile = (
  profile: DocumentData | undefined,
  userID: string,
  normalizedEmail: string,
): boolean =>
  profile?.schemaVersion === 1 &&
  profile.recordVersion === 1 &&
  profile.userID === userID &&
  typeof profile.email === "string" &&
  normalizeEmail(profile.email) === normalizedEmail;

const preferenceAuthorityFields = new Set([
  "userID", "districtID", "schoolIDs", "role", "capabilities",
  "assignedStudentIDs", "isActive", "version", "tmiDistrictID",
  "tmiAccessClass", "tmiMembershipVersion",
]);

const isCompatiblePreferences = (
  preferences: DocumentData | undefined,
): boolean =>
  preferences?.schemaVersion === 1 &&
  preferences.recordVersion === 1 &&
  typeof preferences.onboardingComplete === "boolean" &&
  !Object.keys(preferences).some((key) => preferenceAuthorityFields.has(key));

const isCompatibleAcknowledgement = (
  acknowledgement: DocumentData | undefined,
  documentID: string,
  version: string,
  userID: string,
): boolean =>
  acknowledgement?.schemaVersion === 1 &&
  acknowledgement.recordVersion === 1 &&
  acknowledgement.documentID === documentID &&
  acknowledgement.version === version &&
  acknowledgement.operationID === `staff-provision-${userID}`;

const isCompatibleAudit = (
  audit: DocumentData | undefined,
  invitation: TrustedInvitation,
  membershipPath: string,
  userID: string,
  expectedHash: string,
): boolean =>
  audit?.schemaVersion === 1 &&
  audit.recordVersion === 1 &&
  audit.action === "staff.membership.provision" &&
  audit.actorUserID === userID &&
  audit.districtID === invitation.districtID &&
  audit.targetPath === membershipPath &&
  audit.reasonCode === "staff-invitation-accepted" &&
  audit.requestHash === expectedHash &&
  audit.details?.role === invitation.role &&
  equalStringArrays(audit.details?.schoolIDs, invitation.schoolIDs) &&
  equalStringArrays(audit.details?.capabilities, invitation.capabilities) &&
  audit.result?.recordVersion === 1;

const parseTrustedInvitation = (data: DocumentData): TrustedInvitation => {
  const schemaVersion = data.schemaVersion;
  const recordVersion = data.recordVersion;
  const districtID = data.districtID;
  const recipientEmailHash = data.recipientEmailHash;
  const role = data.role;
  const schoolIDs = parseIdentifierArray(data.schoolIDs, 100);
  const capabilities = parseCapabilityArray(data.capabilities);
  const expiresAt = data.expiresAt;
  const consumedByUserID = data.consumedByUserID ?? null;
  const consumedAt = data.consumedAt ?? null;
  const hasValidConsumptionState =
    consumedByUserID === null
      ? consumedAt === null
      : data.isActive === false && consumedAt instanceof Timestamp;
  if (
    schemaVersion !== 1 ||
    typeof recordVersion !== "number" ||
    !Number.isSafeInteger(recordVersion) ||
    recordVersion < 1 ||
    !isValidIdentifier(districtID) ||
    typeof recipientEmailHash !== "string" ||
    !sha256Pattern.test(recipientEmailHash) ||
    typeof role !== "string" ||
    !allowedRoles.has(role) ||
    schoolIDs === null ||
    (role !== "districtAdministrator" && schoolIDs.length === 0) ||
    capabilities === null ||
    typeof data.isActive !== "boolean" ||
    !(expiresAt instanceof Timestamp) ||
    (consumedByUserID !== null && !isValidIdentifier(consumedByUserID)) ||
    !hasValidConsumptionState
  ) {
    throw new HttpsError("data-loss", "The invitation record is malformed.");
  }
  return {
    recordVersion,
    districtID,
    recipientEmailHash,
    role: role as StaffRole,
    schoolIDs,
    capabilities,
    isActive: data.isActive,
    expiresAt,
    consumedByUserID,
    consumedAt,
  };
};

const parseIdentifierArray = (
  value: unknown,
  maximumCount: number,
): string[] | null => {
  if (!Array.isArray(value) || value.length > maximumCount) {
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

const parseCapabilityArray = (value: unknown): Capability[] | null => {
  if (!Array.isArray(value) || value.length > capabilityValues.length) {
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

const readIdempotentMembership = async (
  firestore: Firestore,
  transaction: FirebaseFirestore.Transaction,
  invitation: TrustedInvitation,
  userID: string,
  normalizedEmail: string,
  trustedClaims: Readonly<Record<string, unknown>>,
): Promise<ProvisionStaffMembershipResult> => {
  const paths = onboardingPaths(invitation.districtID, userID);
  const [
    membershipSnapshot,
    profileSnapshot,
    preferencesSnapshot,
    privacySnapshot,
    acceptableUseSnapshot,
    auditSnapshot,
  ] = await Promise.all([
    transaction.get(firestore.doc(paths.membership)),
    transaction.get(firestore.doc(paths.profile)),
    transaction.get(firestore.doc(paths.preferences)),
    transaction.get(firestore.doc(paths.privacyAcknowledgement)),
    transaction.get(firestore.doc(paths.acceptableUseAcknowledgement)),
    transaction.get(firestore.doc(paths.audit)),
  ]);
  const membership = membershipSnapshot.data();
  const profile = profileSnapshot.data();
  const preferences = preferencesSnapshot.data();
  const privacy = privacySnapshot.data();
  const acceptableUse = acceptableUseSnapshot.data();
  const audit = auditSnapshot.data();
  const expectedAuditHash = hashAuditRequest({
    userID,
    districtID: invitation.districtID,
    role: invitation.role,
    schoolIDs: invitation.schoolIDs,
    capabilities: invitation.capabilities,
    privacyPolicyVersion: requiredPolicyVersions.privacyPolicy,
    acceptableUsePolicyVersion: requiredPolicyVersions.acceptableUsePolicy,
  });
  if (
    !membershipSnapshot.exists ||
    !isCompatibleMembership(membership, invitation, userID) ||
    !profileSnapshot.exists ||
    !isCompatibleProfile(profile, userID, normalizedEmail) ||
    !preferencesSnapshot.exists ||
    !isCompatiblePreferences(preferences) ||
    !privacySnapshot.exists ||
    !isCompatibleAcknowledgement(
      privacy,
      "privacyPolicy",
      requiredPolicyVersions.privacyPolicy,
      userID,
    ) ||
    !acceptableUseSnapshot.exists ||
    !isCompatibleAcknowledgement(
      acceptableUse,
      "acceptableUsePolicy",
      requiredPolicyVersions.acceptableUsePolicy,
      userID,
    ) ||
    !auditSnapshot.exists ||
    !isCompatibleAudit(
      audit,
      invitation,
      paths.membership,
      userID,
      expectedAuditHash,
    )
  ) {
    throw new HttpsError(
      "data-loss",
      "The provisioned membership is missing or malformed.",
    );
  }
  requireCompatibleTrustedClaims(trustedClaims, invitation, membership.version);
  return membershipResult(
    invitation,
    userID,
    true,
    membership.version,
    membership.assignedStudentIDs,
  );
};

const equalStringArrays = (
  value: unknown,
  expected: readonly string[],
): boolean =>
  Array.isArray(value) &&
  value.length === expected.length &&
  value.every((item, index) => item === expected[index]);

const membershipResult = (
  invitation: TrustedInvitation,
  userID: string,
  replayed: boolean,
  version = 1,
  assignedStudentIDs: readonly string[] = [],
): ProvisionStaffMembershipResult => ({
  userID,
  districtID: invitation.districtID,
  schoolIDs: [...invitation.schoolIDs],
  role: invitation.role,
  capabilities: [...invitation.capabilities],
  assignedStudentIDs: [...assignedStudentIDs],
  isActive: true,
  version,
  replayed,
});

const onboardingPaths = (districtID: string, userID: string) => ({
  membership: `districts/${districtID}/members/${userID}`,
  profile: `users/${userID}/private/profile`,
  preferences: `users/${userID}/preferences/settings`,
  privacyAcknowledgement:
    `districts/${districtID}/members/${userID}/acknowledgements/privacyPolicy`,
  acceptableUseAcknowledgement:
    `districts/${districtID}/members/${userID}/acknowledgements/acceptableUsePolicy`,
  audit: `districts/${districtID}/auditEvents/staff-provision-${userID}`,
});

const unusableInvitationError = (): HttpsError =>
  new HttpsError("permission-denied", "The invitation cannot be used.");

const hashAuditRequest = (value: unknown): string =>
  createHash("sha256").update(JSON.stringify(value), "utf8").digest("hex");
