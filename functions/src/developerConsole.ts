import { randomUUID } from "node:crypto";
import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import {
  HttpsError,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {
  capabilityValues,
  isValidIdentifier,
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
  type StaffRole,
} from "./authz.js";
import {
  generateStaffInvitationCode,
  hashInvitationCode,
  hashInvitationRecipientEmail,
} from "./invitations.js";

/**
 * Developer console: operator-only administration of tenants, invitations and
 * staff memberships across districts.
 *
 * Authority never comes from the client. A caller is an operator only when
 * `platformOperators/{uid}` exists with `isActive: true`; that collection is
 * written exclusively by `scripts/manage-operator.mjs` through the Admin SDK and
 * is denied to every client by the Firestore rules. Custom claims are not used
 * because membership refreshes replace the claim set wholesale.
 *
 * The console is additionally switched off unless the deployment opts in, so a
 * production district project cannot expose it by accident.
 */

export const programTypeValues = ["k12", "earlyChildhood"] as const;
export type ProgramType = (typeof programTypeValues)[number];

export const organizationKindValues = [
  "schoolDistrict",
  "earlyLearningProvider",
] as const;
export type OrganizationKind = (typeof organizationKindValues)[number];

export const defaultCapabilitiesByRole: Readonly<
  Record<StaffRole, readonly Capability[]>
> = {
  teacher: ["student.read.detail", "student.write.detail"],
  counselor: ["student.read.detail", "student.write.detail"],
  socialWorker: ["student.read.detail"],
  schoolAdministrator: [
    "student.read.detail",
    "student.write.detail",
    "staff.manage",
    "report.export",
  ],
  districtAdministrator: [
    "student.read.detail",
    "student.write.detail",
    "student.restricted.read",
    "plan.approve",
    "staff.manage",
    "report.export",
    "audit.read",
  ],
};

export type InvitationStatus = "active" | "consumed" | "expired" | "revoked";

export interface DeveloperConsoleUser {
  readonly userID: string;
  readonly email: string | undefined;
  readonly displayName: string | undefined;
  readonly customClaims: Readonly<Record<string, unknown>>;
}

export interface DeveloperConsoleDependencies {
  readonly firestore: Firestore;
  readonly now: () => Date;
  readonly projectID: string;
  readonly isEnabled: boolean;
  readonly getUser: (userID: string) => Promise<DeveloperConsoleUser>;
  readonly getUserByEmail: (
    email: string,
  ) => Promise<DeveloperConsoleUser | null>;
  readonly getUsers: (
    userIDs: readonly string[],
  ) => Promise<readonly DeveloperConsoleUser[]>;
  readonly setCustomUserClaims: (
    userID: string,
    claims: Readonly<Record<string, unknown>>,
  ) => Promise<void>;
}

interface OperatorIdentity {
  readonly userID: string;
}

const maximumInvitationDays = 90;
const maximumListCount = 500;
const allowedCapabilities = new Set<string>(capabilityValues);

// MARK: - Authority

const requireCallerIdentity = (
  request: Pick<CallableRequest<unknown>, "auth" | "app">,
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

const isActiveOperator = async (
  firestore: Firestore,
  userID: string,
): Promise<boolean> => {
  const snapshot = await firestore.doc(`platformOperators/${userID}`).get();
  return snapshot.exists && snapshot.data()?.isActive === true;
};

export const requireOperator = async (
  dependencies: DeveloperConsoleDependencies,
  request: Pick<CallableRequest<unknown>, "auth" | "app">,
): Promise<OperatorIdentity> => {
  if (!dependencies.isEnabled) {
    throw new HttpsError(
      "failed-precondition",
      "The developer console is disabled for this project.",
    );
  }
  const userID = requireCallerIdentity(request);
  if (!(await isActiveOperator(dependencies.firestore, userID))) {
    throw new HttpsError(
      "permission-denied",
      "This account is not a platform operator.",
    );
  }
  return { userID };
};

// MARK: - Audit

const writeOperatorAudit = (
  transaction: Transaction,
  firestore: Firestore,
  operator: OperatorIdentity,
  action: string,
  districtID: string | null,
  targetPath: string,
  details: Readonly<Record<string, unknown>>,
  timestamp: Timestamp,
): void => {
  const eventID = `operator-${randomUUID()}`;
  const event = {
    schemaVersion: 1,
    recordVersion: 1,
    action,
    actorKind: "platformOperator",
    actorUserID: operator.userID,
    districtID,
    targetPath,
    reasonCode: "developer-console",
    details,
    createdAt: timestamp,
  };
  transaction.create(firestore.doc(`operatorAuditEvents/${eventID}`), event);
  if (districtID !== null) {
    transaction.create(
      firestore.doc(`districts/${districtID}/auditEvents/${eventID}`),
      event,
    );
  }
};

// MARK: - Parsing helpers

const parse = <T>(
  value: unknown,
  fields: readonly string[],
  build: (data: Record<string, unknown>) => T,
): T => {
  const data = requireRecord(value ?? {});
  rejectUnexpectedFields(data, new Set(fields));
  return build(data);
};

const optionalIdentifier = (
  value: unknown,
  fieldName: string,
): string | null =>
  value === undefined || value === null
    ? null
    : requireIdentifier(value, fieldName);

const requireCapabilities = (value: unknown): Capability[] => {
  if (!Array.isArray(value) || value.length > capabilityValues.length) {
    throw new HttpsError("invalid-argument", "capabilities is malformed.");
  }
  const capabilities = value.map((item) => {
    if (typeof item !== "string" || !allowedCapabilities.has(item)) {
      throw new HttpsError(
        "invalid-argument",
        "capabilities contains an unknown value.",
      );
    }
    return item as Capability;
  });
  if (new Set(capabilities).size !== capabilities.length) {
    throw new HttpsError(
      "invalid-argument",
      "capabilities must not contain duplicates.",
    );
  }
  return capabilities;
};

const requireEmail = (value: unknown): string => {
  const email = requireString(value, "recipientEmail", 320)
    .trim()
    .toLocaleLowerCase("en-US");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "recipientEmail is malformed.");
  }
  return email;
};

const requireSchoolScope = (
  role: StaffRole,
  schoolIDs: readonly string[],
): void => {
  if (role !== "districtAdministrator" && schoolIDs.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Every role except district administrator needs at least one school.",
    );
  }
};

const timestampISO = (value: unknown): string | null =>
  value instanceof Timestamp ? value.toDate().toISOString() : null;

const stringOrNull = (value: unknown): string | null =>
  typeof value === "string" ? value : null;

const stringArray = (value: unknown): string[] =>
  Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];

const requireExistingSchools = async (
  firestore: Firestore,
  transaction: Transaction,
  districtID: string,
  schoolIDs: readonly string[],
): Promise<void> => {
  const snapshots = await Promise.all(
    schoolIDs.map((schoolID) =>
      transaction.get(
        firestore.doc(`districts/${districtID}/schools/${schoolID}`),
      ),
    ),
  );
  const missing = schoolIDs.filter((_, index) => !snapshots[index]?.exists);
  if (missing.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      `Unknown schools: ${missing.join(", ")}.`,
    );
  }
};

// MARK: - Tenants

export interface DevSchoolSummary {
  readonly schoolID: string;
  readonly name: string;
  readonly programType: ProgramType | null;
}

export interface DevTenantSummary {
  readonly districtID: string;
  readonly name: string;
  readonly organizationKind: OrganizationKind;
  readonly programType: ProgramType;
  readonly memberCount: number;
  readonly schools: readonly DevSchoolSummary[];
}

const programTypeOrNull = (value: unknown): ProgramType | null =>
  typeof value === "string" &&
  (programTypeValues as readonly string[]).includes(value)
    ? (value as ProgramType)
    : null;

const organizationKindOrDefault = (value: unknown): OrganizationKind =>
  typeof value === "string" &&
  (organizationKindValues as readonly string[]).includes(value)
    ? (value as OrganizationKind)
    : "schoolDistrict";

const listTenants = async (
  dependencies: DeveloperConsoleDependencies,
): Promise<DevTenantSummary[]> => {
  const firestore = dependencies.firestore;
  const districts = await firestore
    .collection("districts")
    .limit(maximumListCount)
    .get();
  return Promise.all(
    districts.docs.map(async (district) => {
      const [schools, members] = await Promise.all([
        district.ref.collection("schools").limit(maximumListCount).get(),
        district.ref.collection("members").count().get(),
      ]);
      const data = district.data();
      return {
        districtID: district.id,
        name: stringOrNull(data.name) ?? district.id,
        organizationKind: organizationKindOrDefault(data.organizationKind),
        programType: programTypeOrNull(data.programType) ?? "k12",
        memberCount: members.data().count,
        schools: schools.docs
          .map((school) => ({
            schoolID: school.id,
            name: stringOrNull(school.data().name) ?? school.id,
            programType: programTypeOrNull(school.data().programType),
          }))
          .sort((left, right) => left.name.localeCompare(right.name)),
      };
    }),
  ).then((tenants) =>
    tenants.sort((left, right) => left.name.localeCompare(right.name)),
  );
};

export interface UpsertDistrictRequest {
  readonly districtID: string;
  readonly name: string;
  readonly organizationKind: OrganizationKind;
  readonly programType: ProgramType;
}

export const parseUpsertDistrictRequest = (
  value: unknown,
): UpsertDistrictRequest =>
  parse(
    value,
    ["districtID", "name", "organizationKind", "programType"],
    (data) => ({
      districtID: requireIdentifier(data.districtID, "districtID"),
      name: requireString(data.name, "name", 200),
      organizationKind: requireEnum(
        data.organizationKind,
        "organizationKind",
        organizationKindValues,
      ),
      programType: requireEnum(data.programType, "programType", programTypeValues),
    }),
  );

const upsertDistrict = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  data: UpsertDistrictRequest,
): Promise<{ readonly created: boolean }> => {
  const firestore = dependencies.firestore;
  const timestamp = Timestamp.fromDate(dependencies.now());
  const reference = firestore.doc(`districts/${data.districtID}`);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const created = !snapshot.exists;
    transaction.set(
      reference,
      {
        districtID: data.districtID,
        name: data.name,
        organizationKind: data.organizationKind,
        programType: data.programType,
        updatedAt: timestamp,
        updatedBy: operator.userID,
        ...(created ? { createdAt: timestamp, createdBy: operator.userID } : {}),
      },
      { merge: true },
    );
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      created ? "district.create" : "district.update",
      data.districtID,
      reference.path,
      {
        name: data.name,
        organizationKind: data.organizationKind,
        programType: data.programType,
      },
      timestamp,
    );
    return { created };
  });
};

export interface UpsertSchoolRequest {
  readonly districtID: string;
  readonly schoolID: string;
  readonly name: string;
  readonly programType: ProgramType | null;
}

export const parseUpsertSchoolRequest = (value: unknown): UpsertSchoolRequest =>
  parse(
    value,
    ["districtID", "schoolID", "name", "programType"],
    (data) => ({
      districtID: requireIdentifier(data.districtID, "districtID"),
      schoolID: requireIdentifier(data.schoolID, "schoolID"),
      name: requireString(data.name, "name", 200),
      programType:
        data.programType === undefined || data.programType === null
          ? null
          : requireEnum(data.programType, "programType", programTypeValues),
    }),
  );

const upsertSchool = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  data: UpsertSchoolRequest,
): Promise<{ readonly created: boolean }> => {
  const firestore = dependencies.firestore;
  const timestamp = Timestamp.fromDate(dependencies.now());
  const district = firestore.doc(`districts/${data.districtID}`);
  const reference = firestore.doc(
    `districts/${data.districtID}/schools/${data.schoolID}`,
  );
  return firestore.runTransaction(async (transaction) => {
    const [districtSnapshot, snapshot] = await Promise.all([
      transaction.get(district),
      transaction.get(reference),
    ]);
    if (!districtSnapshot.exists) {
      throw new HttpsError("not-found", "The district does not exist.");
    }
    const created = !snapshot.exists;
    transaction.set(
      reference,
      {
        schoolID: data.schoolID,
        districtID: data.districtID,
        name: data.name,
        programType: data.programType ?? FieldValue.delete(),
        updatedAt: timestamp,
        updatedBy: operator.userID,
        ...(created ? { createdAt: timestamp, createdBy: operator.userID } : {}),
      },
      { merge: true },
    );
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      created ? "school.create" : "school.update",
      data.districtID,
      reference.path,
      { name: data.name, programType: data.programType },
      timestamp,
    );
    return { created };
  });
};

// MARK: - Invitations

export interface DevInvitationSummary {
  readonly invitationID: string;
  readonly districtID: string;
  readonly role: StaffRole;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly label: string | null;
  readonly status: InvitationStatus;
  readonly createdAt: string | null;
  readonly createdBy: string | null;
  readonly expiresAt: string | null;
  readonly consumedAt: string | null;
  readonly consumedByUserID: string | null;
  readonly revokedAt: string | null;
}

export const invitationStatus = (
  data: DocumentData,
  now: Date,
): InvitationStatus => {
  if (data.consumedByUserID != null) {
    return "consumed";
  }
  if (data.revokedAt instanceof Timestamp || data.isActive !== true) {
    return "revoked";
  }
  if (
    !(data.expiresAt instanceof Timestamp) ||
    data.expiresAt.toMillis() <= now.getTime()
  ) {
    return "expired";
  }
  return "active";
};

const invitationSummary = (
  invitationID: string,
  data: DocumentData,
  now: Date,
): DevInvitationSummary => ({
  invitationID,
  districtID: stringOrNull(data.districtID) ?? "",
  role: (stringOrNull(data.role) ?? "teacher") as StaffRole,
  schoolIDs: stringArray(data.schoolIDs),
  capabilities: stringArray(data.capabilities).filter((item) =>
    allowedCapabilities.has(item),
  ) as Capability[],
  label: stringOrNull(data.label),
  status: invitationStatus(data, now),
  createdAt: timestampISO(data.createdAt),
  createdBy: stringOrNull(data.createdBy),
  expiresAt: timestampISO(data.expiresAt),
  consumedAt: timestampISO(data.consumedAt),
  consumedByUserID: stringOrNull(data.consumedByUserID),
  revokedAt: timestampISO(data.revokedAt),
});

export const parseListInvitationsRequest = (
  value: unknown,
): { readonly districtID: string | null } =>
  parse(value, ["districtID"], (data) => ({
    districtID: optionalIdentifier(data.districtID, "districtID"),
  }));

const listInvitations = async (
  dependencies: DeveloperConsoleDependencies,
  districtID: string | null,
): Promise<DevInvitationSummary[]> => {
  const collection = dependencies.firestore.collection("staffInvitations");
  const query =
    districtID === null ? collection : collection.where("districtID", "==", districtID);
  const snapshot = await query.limit(maximumListCount).get();
  const now = dependencies.now();
  return snapshot.docs
    .map((document) => invitationSummary(document.id, document.data(), now))
    .sort((left, right) =>
      (right.createdAt ?? "").localeCompare(left.createdAt ?? ""),
    );
};

export interface CreateInvitationRequest {
  readonly districtID: string;
  readonly schoolIDs: readonly string[];
  readonly role: StaffRole;
  readonly capabilities: readonly Capability[];
  readonly recipientEmail: string;
  readonly expiresInDays: number;
  readonly label: string | null;
}

export const parseCreateInvitationRequest = (
  value: unknown,
): CreateInvitationRequest =>
  parse(
    value,
    [
      "districtID",
      "schoolIDs",
      "role",
      "capabilities",
      "recipientEmail",
      "expiresInDays",
      "label",
    ],
    (data) => {
      const role = requireEnum(data.role, "role", staffRoleValues);
      const schoolIDs = requireIdentifierArray(data.schoolIDs, "schoolIDs", {
        allowEmpty: true,
        maximumCount: 100,
      });
      requireSchoolScope(role, schoolIDs);
      return {
        districtID: requireIdentifier(data.districtID, "districtID"),
        schoolIDs,
        role,
        capabilities: requireCapabilities(data.capabilities),
        recipientEmail: requireEmail(data.recipientEmail),
        expiresInDays: requireInteger(
          data.expiresInDays,
          "expiresInDays",
          1,
          maximumInvitationDays,
        ),
        label:
          data.label === undefined || data.label === null
            ? null
            : requireString(data.label, "label", 120),
      };
    },
  );

export interface CreatedInvitation {
  readonly invitationID: string;
  readonly invitationCode: string;
  readonly expiresAt: string;
}

const createInvitation = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  data: CreateInvitationRequest,
): Promise<CreatedInvitation> => {
  const firestore = dependencies.firestore;
  const now = dependencies.now();
  const timestamp = Timestamp.fromDate(now);
  const expiresAt = Timestamp.fromDate(
    new Date(now.getTime() + data.expiresInDays * 86_400_000),
  );
  const invitationCode = generateStaffInvitationCode();
  const invitationID = hashInvitationCode(invitationCode);
  const reference = firestore.doc(`staffInvitations/${invitationID}`);
  await firestore.runTransaction(async (transaction) => {
    const district = await transaction.get(
      firestore.doc(`districts/${data.districtID}`),
    );
    if (!district.exists) {
      throw new HttpsError("not-found", "The district does not exist.");
    }
    await requireExistingSchools(
      firestore,
      transaction,
      data.districtID,
      data.schoolIDs,
    );
    transaction.create(reference, {
      schemaVersion: 1,
      recordVersion: 1,
      districtID: data.districtID,
      recipientEmailHash: hashInvitationRecipientEmail(
        invitationCode,
        data.recipientEmail,
      ),
      role: data.role,
      schoolIDs: [...data.schoolIDs],
      capabilities: [...data.capabilities],
      isActive: true,
      expiresAt,
      consumedByUserID: null,
      consumedAt: null,
      label: data.label,
      createdAt: timestamp,
      createdBy: operator.userID,
    });
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      "invitation.create",
      data.districtID,
      reference.path,
      {
        role: data.role,
        schoolIDs: [...data.schoolIDs],
        capabilities: [...data.capabilities],
        expiresInDays: data.expiresInDays,
      },
      timestamp,
    );
  });
  return {
    invitationID,
    invitationCode,
    expiresAt: expiresAt.toDate().toISOString(),
  };
};

export const parseInvitationTargetRequest = (
  value: unknown,
): { readonly invitationID: string } =>
  parse(value, ["invitationID"], (data) => {
    const invitationID = requireIdentifier(data.invitationID, "invitationID");
    if (!/^[a-f0-9]{64}$/.test(invitationID)) {
      throw new HttpsError("invalid-argument", "invitationID is malformed.");
    }
    return { invitationID };
  });

const revokeInvitation = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  invitationID: string,
): Promise<DevInvitationSummary> => {
  const firestore = dependencies.firestore;
  const now = dependencies.now();
  const timestamp = Timestamp.fromDate(now);
  const reference = firestore.doc(`staffInvitations/${invitationID}`);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "The invitation does not exist.");
    }
    const data = snapshot.data() ?? {};
    if (data.consumedByUserID != null) {
      throw new HttpsError(
        "failed-precondition",
        "A consumed invitation cannot be revoked; change the membership instead.",
      );
    }
    const recordVersion =
      typeof data.recordVersion === "number" ? data.recordVersion : 1;
    const next = {
      isActive: false,
      revokedAt: timestamp,
      revokedBy: operator.userID,
      recordVersion: recordVersion + 1,
    };
    transaction.update(reference, next);
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      "invitation.revoke",
      stringOrNull(data.districtID),
      reference.path,
      {},
      timestamp,
    );
    return invitationSummary(invitationID, { ...data, ...next }, now);
  });
};

const deleteInvitation = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  invitationID: string,
): Promise<{ readonly deleted: true }> => {
  const firestore = dependencies.firestore;
  const now = dependencies.now();
  const timestamp = Timestamp.fromDate(now);
  const reference = firestore.doc(`staffInvitations/${invitationID}`);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "The invitation does not exist.");
    }
    const data = snapshot.data() ?? {};
    const status = invitationStatus(data, now);
    if (status === "consumed" || status === "active") {
      throw new HttpsError(
        "failed-precondition",
        "Only revoked or expired, unconsumed invitations can be deleted.",
      );
    }
    transaction.delete(reference);
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      "invitation.delete",
      stringOrNull(data.districtID),
      reference.path,
      { status },
      timestamp,
    );
    return { deleted: true };
  });
};

// MARK: - Members

export interface DevMemberSummary {
  readonly userID: string;
  readonly email: string | null;
  readonly displayName: string | null;
  readonly role: StaffRole | null;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly assignedStudentCount: number;
  readonly isActive: boolean;
  readonly version: number;
  readonly claimDistrictID: string | null;
}

const listMembers = async (
  dependencies: DeveloperConsoleDependencies,
  districtID: string,
): Promise<DevMemberSummary[]> => {
  const snapshot = await dependencies.firestore
    .collection(`districts/${districtID}/members`)
    .limit(maximumListCount)
    .get();
  const users = await dependencies.getUsers(snapshot.docs.map((doc) => doc.id));
  const usersByID = new Map(users.map((user) => [user.userID, user]));
  return snapshot.docs
    .map((document) => {
      const data = document.data();
      const user = usersByID.get(document.id);
      const role = stringOrNull(data.role);
      return {
        userID: document.id,
        email: user?.email ?? null,
        displayName: user?.displayName ?? null,
        role: (staffRoleValues as readonly string[]).includes(role ?? "")
          ? (role as StaffRole)
          : null,
        schoolIDs: stringArray(data.schoolIDs),
        capabilities: stringArray(data.capabilities).filter((item) =>
          allowedCapabilities.has(item),
        ) as Capability[],
        assignedStudentCount: stringArray(data.assignedStudentIDs).length,
        isActive: data.isActive === true,
        version: typeof data.version === "number" ? data.version : 0,
        claimDistrictID: stringOrNull(user?.customClaims.tmiDistrictID),
      };
    })
    .sort((left, right) =>
      (left.displayName ?? left.email ?? left.userID).localeCompare(
        right.displayName ?? right.email ?? right.userID,
      ),
    );
};

export interface UpsertMembershipRequest {
  readonly districtID: string;
  readonly userID: string | null;
  readonly email: string | null;
  readonly role: StaffRole;
  readonly schoolIDs: readonly string[];
  readonly capabilities: readonly Capability[];
  readonly isActive: boolean;
}

export const parseUpsertMembershipRequest = (
  value: unknown,
): UpsertMembershipRequest =>
  parse(
    value,
    [
      "districtID",
      "userID",
      "email",
      "role",
      "schoolIDs",
      "capabilities",
      "isActive",
    ],
    (data) => {
      const role = requireEnum(data.role, "role", staffRoleValues);
      const schoolIDs = requireIdentifierArray(data.schoolIDs, "schoolIDs", {
        allowEmpty: true,
        maximumCount: 100,
      });
      requireSchoolScope(role, schoolIDs);
      const userID = optionalIdentifier(data.userID, "userID");
      const email =
        data.email === undefined || data.email === null
          ? null
          : requireEmail(data.email);
      if ((userID === null) === (email === null)) {
        throw new HttpsError(
          "invalid-argument",
          "Provide exactly one of userID or email.",
        );
      }
      return {
        districtID: requireIdentifier(data.districtID, "districtID"),
        userID,
        email,
        role,
        schoolIDs,
        capabilities: requireCapabilities(data.capabilities),
        isActive: requireBoolean(data.isActive, "isActive"),
      };
    },
  );

const upsertMembership = async (
  dependencies: DeveloperConsoleDependencies,
  operator: OperatorIdentity,
  data: UpsertMembershipRequest,
): Promise<{ readonly userID: string; readonly version: number }> => {
  const firestore = dependencies.firestore;
  const timestamp = Timestamp.fromDate(dependencies.now());
  const user =
    data.userID !== null
      ? await dependencies.getUser(data.userID)
      : await dependencies.getUserByEmail(data.email ?? "");
  if (user === null) {
    throw new HttpsError("not-found", "No account exists for that email.");
  }
  const reference = firestore.doc(
    `districts/${data.districtID}/members/${user.userID}`,
  );
  const version = await firestore.runTransaction(async (transaction) => {
    const district = await transaction.get(
      firestore.doc(`districts/${data.districtID}`),
    );
    if (!district.exists) {
      throw new HttpsError("not-found", "The district does not exist.");
    }
    await requireExistingSchools(
      firestore,
      transaction,
      data.districtID,
      data.schoolIDs,
    );
    const snapshot = await transaction.get(reference);
    const existing = snapshot.data();
    const currentVersion =
      typeof existing?.version === "number" ? existing.version : 0;
    const nextVersion = currentVersion + 1;
    transaction.set(reference, {
      schemaVersion: 1,
      recordVersion: nextVersion,
      version: nextVersion,
      userID: user.userID,
      districtID: data.districtID,
      schoolIDs: [...data.schoolIDs],
      role: data.role,
      capabilities: [...data.capabilities],
      assignedStudentIDs: stringArray(existing?.assignedStudentIDs),
      isActive: data.isActive,
      createdAt: existing?.createdAt ?? timestamp,
      createdBy: existing?.createdBy ?? operator.userID,
      updatedAt: timestamp,
      updatedBy: operator.userID,
    });
    writeOperatorAudit(
      transaction,
      firestore,
      operator,
      snapshot.exists ? "membership.update" : "membership.create",
      data.districtID,
      reference.path,
      {
        targetUserID: user.userID,
        role: data.role,
        schoolIDs: [...data.schoolIDs],
        capabilities: [...data.capabilities],
        isActive: data.isActive,
      },
      timestamp,
    );
    return nextVersion;
  });
  // The trusted claims follow the most recently edited membership, which is
  // how an operator moves an account (including their own) between tenants.
  await dependencies.setCustomUserClaims(user.userID, {
    ...user.customClaims,
    tmiDistrictID: data.districtID,
    tmiAccessClass: "staff",
    tmiMembershipVersion: version,
  });
  return { userID: user.userID, version };
};

// MARK: - Handlers

export const parseDistrictTargetRequest = (
  value: unknown,
): { readonly districtID: string } =>
  parse(value, ["districtID"], (data) => ({
    districtID: requireIdentifier(data.districtID, "districtID"),
  }));

export const createDeveloperConsoleHandlers = (
  dependencies: DeveloperConsoleDependencies,
) => ({
  status: async (request: CallableRequest<unknown>) => {
    const userID = requireCallerIdentity(request);
    return {
      isEnabled: dependencies.isEnabled,
      isOperator:
        dependencies.isEnabled &&
        (await isActiveOperator(dependencies.firestore, userID)),
      projectID: dependencies.projectID,
    };
  },
  listTenants: async (request: CallableRequest<unknown>) => {
    await requireOperator(dependencies, request);
    parse(request.data, [], () => null);
    return { tenants: await listTenants(dependencies) };
  },
  upsertDistrict: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    return upsertDistrict(
      dependencies,
      operator,
      parseUpsertDistrictRequest(request.data),
    );
  },
  upsertSchool: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    return upsertSchool(
      dependencies,
      operator,
      parseUpsertSchoolRequest(request.data),
    );
  },
  listInvitations: async (request: CallableRequest<unknown>) => {
    await requireOperator(dependencies, request);
    const data = parseListInvitationsRequest(request.data);
    return { invitations: await listInvitations(dependencies, data.districtID) };
  },
  createInvitation: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    return createInvitation(
      dependencies,
      operator,
      parseCreateInvitationRequest(request.data),
    );
  },
  revokeInvitation: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    const data = parseInvitationTargetRequest(request.data);
    return {
      invitation: await revokeInvitation(dependencies, operator, data.invitationID),
    };
  },
  deleteInvitation: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    const data = parseInvitationTargetRequest(request.data);
    return deleteInvitation(dependencies, operator, data.invitationID);
  },
  listMembers: async (request: CallableRequest<unknown>) => {
    await requireOperator(dependencies, request);
    const data = parseDistrictTargetRequest(request.data);
    return { members: await listMembers(dependencies, data.districtID) };
  },
  upsertMembership: async (request: CallableRequest<unknown>) => {
    const operator = await requireOperator(dependencies, request);
    return upsertMembership(
      dependencies,
      operator,
      parseUpsertMembershipRequest(request.data),
    );
  },
});

export type DeveloperConsoleHandlers = ReturnType<
  typeof createDeveloperConsoleHandlers
>;

/** Projects allowed to run the console unless explicitly overridden. */
export const developerConsoleProjects = new Set(["tmi-education", "demo-tmi"]);

export const isDeveloperConsoleEnabled = (
  projectID: string,
  override: string | undefined,
): boolean => {
  if (override === "true") return true;
  if (override === "false") return false;
  return developerConsoleProjects.has(projectID);
};
