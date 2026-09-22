import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  assertFails,
} from "@firebase/rules-unit-testing";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { doc, getDoc, setDoc } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import {
  createDeveloperConsoleHandlers,
  defaultCapabilitiesByRole,
  isDeveloperConsoleEnabled,
  type DeveloperConsoleDependencies,
  type DeveloperConsoleUser,
} from "../src/developerConsole.js";
import {
  createProvisionStaffMembershipHandler,
  hashInvitationCode,
  requiredPolicyVersions,
} from "../src/invitations.js";
import {
  devCreateInvitation,
  devListTenants,
  devUpsertMembership,
} from "../src/index.js";
import { makeTestEnvironment } from "./testEnvironment.js";

const operatorID = "operator-1";
const outsiderID = "outsider-1";
const now = new Date("2026-09-22T15:00:00.000Z");

const request = <T>(
  data: T,
  options: { uid?: string; includeAppCheck?: boolean; includeAuth?: boolean } = {},
): CallableRequest<T> =>
  ({
    data,
    auth:
      options.includeAuth === false
        ? undefined
        : {
            uid: options.uid ?? operatorID,
            token: { uid: options.uid ?? operatorID },
            rawToken: "test-token",
          },
    app:
      options.includeAppCheck === false
        ? undefined
        : { appId: "test-app", token: { app_id: "test-app" } },
    rawRequest: {},
    acceptsStreaming: false,
  }) as unknown as CallableRequest<T>;

describe("developer console", () => {
  let testEnv: RulesTestEnvironment;
  let firestore: Firestore;
  let users: Map<string, DeveloperConsoleUser>;
  let claimWrites: Map<string, Readonly<Record<string, unknown>>>;
  let isEnabled: boolean;

  const dependencies = (): DeveloperConsoleDependencies => ({
    firestore,
    now: () => now,
    projectID: "demo-tmi",
    isEnabled,
    getUser: async (userID) => {
      const user = users.get(userID);
      if (user === undefined) throw new Error("user-not-found");
      return user;
    },
    getUserByEmail: async (email) =>
      [...users.values()].find((user) => user.email === email) ?? null,
    getUsers: async (userIDs) =>
      userIDs.flatMap((userID) => {
        const user = users.get(userID);
        return user === undefined ? [] : [user];
      }),
    setCustomUserClaims: async (userID, claims) => {
      claimWrites.set(userID, claims);
      const user = users.get(userID);
      if (user !== undefined) {
        users.set(userID, { ...user, customClaims: claims });
      }
    },
  });

  const handlers = () => createDeveloperConsoleHandlers(dependencies());

  const seedTenant = async () => {
    await handlers().upsertDistrict(
      request({
        districtID: "sunrise",
        name: "Sunrise Learning",
        organizationKind: "earlyLearningProvider",
        programType: "earlyChildhood",
      }),
    );
    await handlers().upsertSchool(
      request({
        districtID: "sunrise",
        schoolID: "sunrise-east",
        name: "Sunrise East Center",
        programType: null,
      }),
    );
  };

  const createInvite = (overrides: Record<string, unknown> = {}) =>
    handlers().createInvitation(
      request({
        districtID: "sunrise",
        schoolIDs: ["sunrise-east"],
        role: "teacher",
        capabilities: [...defaultCapabilitiesByRole.teacher],
        recipientEmail: "New.Teacher@Example.test",
        expiresInDays: 14,
        label: "Pilot classroom lead",
        ...overrides,
      }),
    );

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
    firestore = getFirestore();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    isEnabled = true;
    claimWrites = new Map();
    users = new Map([
      [
        operatorID,
        {
          userID: operatorID,
          email: "dev@example.test",
          displayName: "Developer",
          customClaims: {},
        },
      ],
      [
        "teacher-1",
        {
          userID: "teacher-1",
          email: "new.teacher@example.test",
          displayName: "New Teacher",
          customClaims: {},
        },
      ],
    ]);
    await firestore.doc(`platformOperators/${operatorID}`).set({
      isActive: true,
      email: "dev@example.test",
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("exports the console as callables", () => {
    expect(devListTenants.run).toBeTypeOf("function");
    expect(devCreateInvitation.run).toBeTypeOf("function");
    expect(devUpsertMembership.run).toBeTypeOf("function");
  });

  it("reports operator status without throwing for non-operators", async () => {
    await expect(handlers().status(request({}))).resolves.toMatchObject({
      isOperator: true,
      isEnabled: true,
    });
    await expect(
      handlers().status(request({}, { uid: outsiderID })),
    ).resolves.toMatchObject({ isOperator: false });
  });

  it("denies non-operators, missing App Check, and revoked operators", async () => {
    await expect(
      handlers().listTenants(request({}, { uid: outsiderID })),
    ).rejects.toMatchObject({ code: "permission-denied" });
    await expect(
      handlers().listTenants(request({}, { includeAppCheck: false })),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    await expect(
      handlers().listTenants(request({}, { includeAuth: false })),
    ).rejects.toMatchObject({ code: "unauthenticated" });
    await firestore.doc(`platformOperators/${operatorID}`).set({ isActive: false });
    await expect(handlers().listTenants(request({}))).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  it("is switched off by the project kill switch", async () => {
    isEnabled = false;
    await expect(handlers().listTenants(request({}))).rejects.toMatchObject({
      code: "failed-precondition",
    });
    expect(isDeveloperConsoleEnabled("tmi-education", undefined)).toBe(true);
    expect(isDeveloperConsoleEnabled("district-prod", undefined)).toBe(false);
    expect(isDeveloperConsoleEnabled("tmi-education", "false")).toBe(false);
    expect(isDeveloperConsoleEnabled("district-prod", "true")).toBe(true);
  });

  it("creates, renames, and lists tenants with program types", async () => {
    await seedTenant();
    await handlers().upsertSchool(
      request({
        districtID: "sunrise",
        schoolID: "sunrise-east",
        name: "Sunrise East Early Learning",
        programType: "k12",
      }),
    );
    const { tenants } = await handlers().listTenants(request({}));
    expect(tenants).toEqual([
      {
        districtID: "sunrise",
        name: "Sunrise Learning",
        organizationKind: "earlyLearningProvider",
        programType: "earlyChildhood",
        memberCount: 0,
        schools: [
          {
            schoolID: "sunrise-east",
            name: "Sunrise East Early Learning",
            programType: "k12",
          },
        ],
      },
    ]);
    const audits = await firestore.collection("operatorAuditEvents").get();
    expect(audits.docs.map((item) => item.data().action).sort()).toEqual([
      "district.create",
      "school.create",
      "school.update",
    ]);
  });

  it("rejects schools for a missing district and invites for unknown schools", async () => {
    await expect(
      handlers().upsertSchool(
        request({ districtID: "nope", schoolID: "s", name: "S", programType: null }),
      ),
    ).rejects.toMatchObject({ code: "not-found" });
    await seedTenant();
    await expect(createInvite({ schoolIDs: ["unknown"] })).rejects.toMatchObject({
      code: "failed-precondition",
    });
  });

  it("runs the invitation lifecycle without storing the code or email", async () => {
    await seedTenant();
    const created = await createInvite();
    expect(created.invitationCode).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(created.invitationID).toBe(hashInvitationCode(created.invitationCode));

    const stored = await firestore.doc(`staffInvitations/${created.invitationID}`).get();
    const serialized = JSON.stringify(stored.data());
    expect(serialized).not.toContain(created.invitationCode);
    expect(serialized.toLowerCase()).not.toContain("new.teacher@example.test");

    let listed = await handlers().listInvitations(request({ districtID: "sunrise" }));
    expect(listed.invitations).toHaveLength(1);
    expect(listed.invitations[0]).toMatchObject({
      status: "active",
      label: "Pilot classroom lead",
      role: "teacher",
      createdBy: operatorID,
    });

    await expect(
      handlers().deleteInvitation(request({ invitationID: created.invitationID })),
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const revoked = await handlers().revokeInvitation(
      request({ invitationID: created.invitationID }),
    );
    expect(revoked.invitation.status).toBe("revoked");

    await handlers().deleteInvitation(request({ invitationID: created.invitationID }));
    listed = await handlers().listInvitations(request({}));
    expect(listed.invitations).toHaveLength(0);
  });

  it("creates invitations the provisioning callable accepts", async () => {
    await seedTenant();
    const created = await createInvite();
    const provision = createProvisionStaffMembershipHandler({
      firestore,
      now: () => now,
      requireVerifiedEmail: false,
      getAuthUser: async () => ({
        userID: "teacher-1",
        email: "new.teacher@example.test",
        emailVerified: true,
        disabled: false,
        customClaims: {},
      }),
      setCustomUserClaims: async () => {},
    });
    const result = await provision(
      request(
        {
          invitationCode: created.invitationCode,
          displayName: "New Teacher",
          privacyPolicyVersion: requiredPolicyVersions.privacyPolicy,
          acceptableUsePolicyVersion: requiredPolicyVersions.acceptableUsePolicy,
        },
        { uid: "teacher-1" },
      ),
    );
    expect(result).toMatchObject({ districtID: "sunrise", role: "teacher" });

    const listed = await handlers().listInvitations(request({}));
    expect(listed.invitations[0]).toMatchObject({
      status: "consumed",
      consumedByUserID: "teacher-1",
    });
    await expect(
      handlers().revokeInvitation(request({ invitationID: created.invitationID })),
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("upserts memberships, bumps versions, and refreshes claims", async () => {
    await seedTenant();
    const first = await handlers().upsertMembership(
      request({
        districtID: "sunrise",
        email: "new.teacher@example.test",
        role: "teacher",
        schoolIDs: ["sunrise-east"],
        capabilities: [...defaultCapabilitiesByRole.teacher],
        isActive: true,
      }),
    );
    expect(first).toEqual({ userID: "teacher-1", version: 1 });

    const second = await handlers().upsertMembership(
      request({
        districtID: "sunrise",
        userID: "teacher-1",
        role: "schoolAdministrator",
        schoolIDs: ["sunrise-east"],
        capabilities: [...defaultCapabilitiesByRole.schoolAdministrator],
        isActive: true,
      }),
    );
    expect(second.version).toBe(2);
    expect(claimWrites.get("teacher-1")).toMatchObject({
      tmiDistrictID: "sunrise",
      tmiAccessClass: "staff",
      tmiMembershipVersion: 2,
    });

    const member = await firestore.doc("districts/sunrise/members/teacher-1").get();
    expect(member.data()).toMatchObject({
      userID: "teacher-1",
      role: "schoolAdministrator",
      version: 2,
      recordVersion: 2,
      assignedStudentIDs: [],
    });

    const { members } = await handlers().listMembers(request({ districtID: "sunrise" }));
    expect(members).toEqual([
      expect.objectContaining({
        userID: "teacher-1",
        email: "new.teacher@example.test",
        role: "schoolAdministrator",
        version: 2,
        claimDistrictID: "sunrise",
      }),
    ]);
  });

  it("validates membership requests", async () => {
    await seedTenant();
    await expect(
      handlers().upsertMembership(
        request({
          districtID: "sunrise",
          role: "teacher",
          schoolIDs: [],
          capabilities: [],
          isActive: true,
          userID: "teacher-1",
        }),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(
      handlers().upsertMembership(
        request({
          districtID: "sunrise",
          role: "teacher",
          schoolIDs: ["sunrise-east"],
          capabilities: ["root"],
          isActive: true,
          userID: "teacher-1",
        }),
      ),
    ).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(
      handlers().upsertMembership(
        request({
          districtID: "sunrise",
          role: "teacher",
          schoolIDs: ["sunrise-east"],
          capabilities: [],
          isActive: true,
          email: "missing@example.test",
        }),
      ),
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("denies every client access to operator collections", async () => {
    const context = testEnv.authenticatedContext(operatorID, {
      tmiDistrictID: "sunrise",
      tmiAccessClass: "staff",
      tmiMembershipVersion: 1,
    });
    await assertFails(getDoc(doc(context.firestore(), `platformOperators/${operatorID}`)));
    await assertFails(
      setDoc(doc(context.firestore(), `platformOperators/${outsiderID}`), {
        isActive: true,
      }),
    );
    await assertFails(getDoc(doc(context.firestore(), "operatorAuditEvents/any")));
    await assertFails(getDoc(doc(context.firestore(), "staffInvitations/any")));
  });
});
