import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  assertDistrict,
  capabilityValues,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireCapability,
  requireEnum,
  requireIdentifier,
  requireIdentifierArray,
  requireInteger,
  requireRecord,
  requireString,
  requireTrustedMembership,
  staffRoleValues,
  type Capability,
  type StaffRole,
  type TrustedMembership,
} from "./authz.js";
import {
  buildInvitationRecord,
  invitationSummary,
  requireExistingSchools,
  type DevInvitationSummary,
} from "./developerConsole.js";
import { generateStaffInvitationCode, hashInvitationCode } from "./invitations.js";

/**
 * District/school staff administration for members with `staff.manage`.
 *
 * - District administrators manage their whole district.
 * - Everyone else with `staff.manage` (school administrators) manages only
 *   staff and invitations wholly inside their own schools, and can never
 *   create or edit district administrators.
 * - Nobody can grant a capability they do not hold themselves.
 */

export interface AdministrationUser {
  readonly userID: string;
  readonly email: string | undefined;
  readonly displayName: string | undefined;
}

export interface AdministrationDependencies {
  readonly firestore: Firestore;
  readonly now: () => Date;
  readonly getUsers: (userIDs: readonly string[]) => Promise<readonly AdministrationUser[]>;
}

const allowedCapabilities = new Set<string>(capabilityValues);
const maximumListCount = 500;

const isDistrictAdministrator = (membership: TrustedMembership): boolean =>
  membership.role === "districtAdministrator";

/** Whether the caller may see or manage something scoped to these schools/role. */
export const withinAdministrativeScope = (
  caller: TrustedMembership,
  targetSchoolIDs: readonly string[],
  targetRole: StaffRole | null,
): boolean => {
  if (isDistrictAdministrator(caller)) return true;
  return (
    targetRole !== "districtAdministrator" &&
    targetSchoolIDs.length > 0 &&
    targetSchoolIDs.every((schoolID) => caller.schoolIDs.has(schoolID))
  );
};

/** Capabilities the caller may grant: never more than they hold. */
export const requireCapabilityCeiling = (
  caller: TrustedMembership,
  requested: readonly Capability[],
): void => {
  const exceeding = requested.filter((capability) => !caller.capabilities.has(capability));
  if (exceeding.length > 0) {
    throw new HttpsError(
      "permission-denied",
      `You can't grant capabilities you don't hold: ${exceeding.join(", ")}.`,
    );
  }
};

const requireAdministrator = async (
  dependencies: AdministrationDependencies,
  request: CallableRequest<unknown>,
  districtID: string,
): Promise<TrustedMembership> => {
  const identity = parseTrustedCallableIdentity(request);
  assertDistrict(identity, districtID);
  return dependencies.firestore.runTransaction(async (transaction) => {
    const membership = await requireTrustedMembership(dependencies.firestore, transaction, identity);
    requireCapability(membership, "staff.manage");
    return membership;
  }, { readOnly: true });
};

const parse = <T>(value: unknown, fields: readonly string[], build: (data: Record<string, unknown>) => T): T => {
  const data = requireRecord(value ?? {});
  rejectUnexpectedFields(data, new Set(fields));
  return build(data);
};

const stringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];

// MARK: - Staff directory

export interface AdminStaffMember {
  readonly userID: string;
  readonly email: string | null;
  readonly displayName: string | null;
  readonly role: StaffRole | null;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly assignedStudentIDs: readonly string[];
  readonly isActive: boolean;
  readonly recordVersion: number;
  readonly isSelf: boolean;
  readonly isManageable: boolean;
}

const listStaff = async (
  dependencies: AdministrationDependencies,
  caller: TrustedMembership,
  districtID: string,
): Promise<AdminStaffMember[]> => {
  const snapshot = await dependencies.firestore
    .collection(`districts/${districtID}/members`)
    .limit(maximumListCount)
    .get();
  const visible = snapshot.docs.filter((document) => {
    const data = document.data();
    const role = typeof data.role === "string" ? (data.role as StaffRole) : null;
    const schoolIDs = stringArray(data.schoolIDs);
    // School administrators see staff who share at least one of their schools.
    return isDistrictAdministrator(caller) ||
      document.id === caller.userID ||
      schoolIDs.some((schoolID) => caller.schoolIDs.has(schoolID)) && role !== "districtAdministrator";
  });
  const users = await dependencies.getUsers(visible.map((document) => document.id));
  const usersByID = new Map(users.map((user) => [user.userID, user]));
  return visible
    .map((document) => {
      const data = document.data();
      const role = (staffRoleValues as readonly string[]).includes(data.role) ? (data.role as StaffRole) : null;
      const schoolIDs = stringArray(data.schoolIDs);
      const user = usersByID.get(document.id);
      const version = typeof data.recordVersion === "number"
        ? data.recordVersion
        : typeof data.version === "number" ? data.version : 0;
      return {
        userID: document.id,
        email: user?.email ?? null,
        displayName: user?.displayName ?? null,
        role,
        schoolIDs,
        capabilities: stringArray(data.capabilities).filter((item) => allowedCapabilities.has(item)) as Capability[],
        assignedStudentIDs: stringArray(data.assignedStudentIDs),
        isActive: data.isActive === true,
        recordVersion: version,
        isSelf: document.id === caller.userID,
        isManageable: document.id !== caller.userID && withinAdministrativeScope(caller, schoolIDs, role),
      };
    })
    .sort((left, right) =>
      (left.displayName ?? left.email ?? left.userID).localeCompare(right.displayName ?? right.email ?? right.userID));
};

// MARK: - Invitations

export interface AdminCreateInvitationRequest {
  readonly districtID: string;
  readonly idempotencyKey: string;
  readonly schoolIDs: readonly string[];
  readonly role: StaffRole;
  readonly capabilities: readonly Capability[];
  readonly recipientEmail: string;
  readonly expiresInDays: number;
  readonly label: string | null;
}

export const parseAdminCreateInvitationRequest = (value: unknown): AdminCreateInvitationRequest =>
  parse(
    value,
    ["districtID", "idempotencyKey", "schoolIDs", "role", "capabilities", "recipientEmail", "expiresInDays", "label"],
    (data) => {
      const role = requireEnum(data.role, "role", staffRoleValues);
      const schoolIDs = requireIdentifierArray(data.schoolIDs, "schoolIDs", { allowEmpty: true, maximumCount: 100 });
      if (role !== "districtAdministrator" && schoolIDs.length === 0) {
        throw new HttpsError("invalid-argument", "Choose at least one school for this role.");
      }
      const capabilities = requireIdentifierArray(data.capabilities, "capabilities", {
        allowEmpty: true,
        maximumCount: capabilityValues.length,
      });
      if (!capabilities.every((item) => allowedCapabilities.has(item))) {
        throw new HttpsError("invalid-argument", "capabilities contains an unknown value.");
      }
      const email = requireString(data.recipientEmail, "recipientEmail", 320).trim().toLocaleLowerCase("en-US");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new HttpsError("invalid-argument", "recipientEmail is malformed.");
      }
      return {
        districtID: requireIdentifier(data.districtID, "districtID"),
        idempotencyKey: requireIdentifier(data.idempotencyKey, "idempotencyKey"),
        schoolIDs,
        role,
        capabilities: capabilities as Capability[],
        recipientEmail: email,
        expiresInDays: requireInteger(data.expiresInDays, "expiresInDays", 1, 30),
        label: data.label === undefined || data.label === null || data.label === ""
          ? null
          : requireString(data.label, "label", 120),
      };
    },
  );

const createInvitation = async (
  dependencies: AdministrationDependencies,
  caller: TrustedMembership,
  data: AdminCreateInvitationRequest,
) => {
  if (!withinAdministrativeScope(caller, data.schoolIDs, data.role)) {
    throw new HttpsError("permission-denied", "That invitation is outside your administrative scope.");
  }
  requireCapabilityCeiling(caller, data.capabilities);
  const firestore = dependencies.firestore;
  const now = dependencies.now();
  const timestamp = Timestamp.fromDate(now);
  const expiresAt = Timestamp.fromDate(new Date(now.getTime() + data.expiresInDays * 86_400_000));
  const invitationCode = generateStaffInvitationCode();
  const invitationID = hashInvitationCode(invitationCode);
  const auditReference = firestore.doc(`districts/${data.districtID}/auditEvents/${data.idempotencyKey}`);
  await firestore.runTransaction(async (transaction) => {
    if ((await transaction.get(auditReference)).exists) {
      // The code is never stored, so a retry cannot return it again.
      throw new HttpsError(
        "already-exists",
        "This invitation was already created. Create a new one if the code was lost.",
        { kind: "idempotency-key-reused" },
      );
    }
    await requireExistingSchools(firestore, transaction, data.districtID, data.schoolIDs);
    transaction.create(
      firestore.doc(`staffInvitations/${invitationID}`),
      buildInvitationRecord({ ...data }, invitationCode, caller.userID, timestamp, expiresAt),
    );
    transaction.create(auditReference, {
      schemaVersion: 1,
      recordVersion: 1,
      action: "staff.invitation.create",
      actorUserID: caller.userID,
      districtID: data.districtID,
      targetPath: `staffInvitations/${invitationID}`,
      reasonCode: "staff-administration",
      details: { role: data.role, schoolIDs: [...data.schoolIDs], capabilities: [...data.capabilities] },
      result: { recordVersion: 1 },
      createdAt: timestamp,
    });
  });
  return { invitationID, invitationCode, expiresAt: expiresAt.toDate().toISOString() };
};

const listInvitations = async (
  dependencies: AdministrationDependencies,
  caller: TrustedMembership,
  districtID: string,
): Promise<DevInvitationSummary[]> => {
  const snapshot = await dependencies.firestore
    .collection("staffInvitations")
    .where("districtID", "==", districtID)
    .limit(maximumListCount)
    .get();
  const now = dependencies.now();
  return snapshot.docs
    .map((document) => invitationSummary(document.id, document.data(), now))
    .filter((invitation) => withinAdministrativeScope(caller, invitation.schoolIDs, invitation.role))
    .sort((left, right) => (right.createdAt ?? "").localeCompare(left.createdAt ?? ""));
};

const revokeInvitation = async (
  dependencies: AdministrationDependencies,
  caller: TrustedMembership,
  districtID: string,
  invitationID: string,
) => {
  const firestore = dependencies.firestore;
  const reference = firestore.doc(`staffInvitations/${invitationID}`);
  const timestamp = Timestamp.fromDate(dependencies.now());
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data();
    if (!snapshot.exists || data?.districtID !== districtID) {
      throw new HttpsError("not-found", "The invitation does not exist.");
    }
    const role = typeof data.role === "string" ? (data.role as StaffRole) : null;
    if (!withinAdministrativeScope(caller, stringArray(data.schoolIDs), role)) {
      throw new HttpsError("permission-denied", "That invitation is outside your administrative scope.");
    }
    if (data.consumedByUserID != null) {
      throw new HttpsError("failed-precondition", "A redeemed invitation cannot be revoked; edit the staff member instead.");
    }
    transaction.update(reference, {
      isActive: false,
      revokedAt: timestamp,
      revokedBy: caller.userID,
      recordVersion: (typeof data.recordVersion === "number" ? data.recordVersion : 1) + 1,
    });
    transaction.create(firestore.doc(`districts/${districtID}/auditEvents/invitation-revoke-${invitationID.slice(0, 32)}-${timestamp.toMillis()}`), {
      schemaVersion: 1,
      recordVersion: 1,
      action: "staff.invitation.revoke",
      actorUserID: caller.userID,
      districtID,
      targetPath: reference.path,
      reasonCode: "staff-administration",
      details: {},
      result: { recordVersion: 1 },
      createdAt: timestamp,
    });
  });
  return { revoked: true };
};

// MARK: - Handlers

const districtOnly = (value: unknown) =>
  parse(value, ["districtID"], (data) => ({ districtID: requireIdentifier(data.districtID, "districtID") }));

export const createAdministrationHandlers = (dependencies: AdministrationDependencies) => ({
  listStaff: async (request: CallableRequest<unknown>) => {
    const { districtID } = districtOnly(request.data);
    const caller = await requireAdministrator(dependencies, request, districtID);
    return { staff: await listStaff(dependencies, caller, districtID) };
  },
  listInvitations: async (request: CallableRequest<unknown>) => {
    const { districtID } = districtOnly(request.data);
    const caller = await requireAdministrator(dependencies, request, districtID);
    return { invitations: await listInvitations(dependencies, caller, districtID) };
  },
  createInvitation: async (request: CallableRequest<unknown>) => {
    const data = parseAdminCreateInvitationRequest(request.data);
    const caller = await requireAdministrator(dependencies, request, data.districtID);
    return createInvitation(dependencies, caller, data);
  },
  revokeInvitation: async (request: CallableRequest<unknown>) => {
    const data = parse(request.data, ["districtID", "invitationID"], (value) => ({
      districtID: requireIdentifier(value.districtID, "districtID"),
      invitationID: requireIdentifier(value.invitationID, "invitationID"),
    }));
    const caller = await requireAdministrator(dependencies, request, data.districtID);
    return revokeInvitation(dependencies, caller, data.districtID, data.invitationID);
  },
});
