import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import {
  deleteField,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { provisionStaffMembership } from "../src/index.js";
import {
  createProvisionStaffMembershipHandler,
  generateStaffInvitationCode,
  hashInvitationCode,
  hashInvitationRecipientEmail,
  requiredPolicyVersions,
  type ProvisionStaffMembershipRequest,
  type ProvisioningAuthUser,
} from "../src/invitations.js";
import { makeTestEnvironment } from "./testEnvironment.js";

const now = new Date("2026-07-21T15:00:00.000Z");
const invitationCode = "w7YjTz0Z5ZqXGcJb8H5N8z1WmQ3pK6dS9vR2cF4hAbC";
const userID = "staff-synthetic-1";
const email = "staff-1@example.test";
const districtID = "district-synthetic-1";
const schoolID = "school-synthetic-1";

const requestData = (): ProvisionStaffMembershipRequest => ({
  invitationCode,
  displayName: "Synthetic Staff One",
  privacyPolicyVersion: requiredPolicyVersions.privacyPolicy,
  acceptableUsePolicyVersion: requiredPolicyVersions.acceptableUsePolicy,
});

const callableRequest = (
  data: unknown = requestData(),
  options: {
    readonly uid?: string;
    readonly includeAuth?: boolean;
    readonly includeAppCheck?: boolean;
  } = {},
): CallableRequest<ProvisionStaffMembershipRequest> => ({
  data,
  auth:
    options.includeAuth === false
      ? undefined
      : {
          uid: options.uid ?? userID,
          token: { uid: options.uid ?? userID },
          rawToken: "synthetic-token",
        },
  app:
    options.includeAppCheck === false
      ? undefined
      : { appId: "synthetic-app", token: { app_id: "synthetic-app" } },
  rawRequest: {},
  acceptsStreaming: false,
}) as unknown as CallableRequest<ProvisionStaffMembershipRequest>;

describe("staff invitation provisioning", () => {
  let testEnv: RulesTestEnvironment;
  let firestore: Firestore;
  let authUser: ProvisioningAuthUser;
  let claimsWrites: Readonly<Record<string, unknown>>[];
  let claimsError: Error | undefined;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
    firestore = getFirestore();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    authUser = {
      userID,
      email: "  Staff-1@Example.Test  ",
      emailVerified: true,
      disabled: false,
      customClaims: {},
    };
    claimsWrites = [];
    claimsError = undefined;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "staffInvitations", hashInvitationCode(invitationCode)),
        {
          schemaVersion: 1,
          recordVersion: 1,
          districtID,
          recipientEmailHash: hashInvitationRecipientEmail(invitationCode, email),
          role: "teacher",
          schoolIDs: [schoolID],
          capabilities: ["student.read.detail"],
          isActive: true,
          expiresAt: Timestamp.fromDate(
            new Date(now.getTime() + 24 * 60 * 60 * 1_000),
          ),
        },
      );
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("exports the provisioning boundary as a callable", () => {
    expect(provisionStaffMembership.run).toBeTypeOf("function");
  });

  it("keys the recipient email digest to the opaque invitation secret", () => {
    const anotherCode = "B2cD4eF6gH8jK0mN2pQ4rS6tV8wX0yZ2aC4dE6fGXyZ";

    expect(hashInvitationRecipientEmail(invitationCode, email)).not.toBe(
      hashInvitationRecipientEmail(anotherCode, email),
    );
    expect(hashInvitationRecipientEmail(invitationCode, email)).toMatch(
      /^[a-f0-9]{64}$/,
    );
  });

  it("issues a 32-byte opaque invitation secret for trusted invitation creation", () => {
    const first = generateStaffInvitationCode();
    const second = generateStaffInvitationCode();

    expect(first).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(second).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(first).not.toBe(second);
    expect(hashInvitationCode(first)).not.toContain(first);
  });

  it("creates the canonical onboarding records before issuing trusted claims", async () => {
    const handler = makeHandler();

    const result = await handler(callableRequest());

    expect(result).toMatchObject({
      userID,
      districtID,
      role: "teacher",
      schoolIDs: [schoolID],
      capabilities: ["student.read.detail"],
      assignedStudentIDs: [],
      isActive: true,
      version: 1,
      replayed: false,
    });
    expect(claimsWrites).toEqual([
      {
        tmiDistrictID: districtID,
        tmiAccessClass: "staff",
        tmiMembershipVersion: 1,
      },
    ]);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const [membership, profile, preferences, privacy, acceptableUse, audit, invitation] =
        await Promise.all([
          getDoc(doc(db, `districts/${districtID}/members/${userID}`)),
          getDoc(doc(db, `users/${userID}/private/profile`)),
          getDoc(doc(db, `users/${userID}/preferences/settings`)),
          getDoc(
            doc(
              db,
              `districts/${districtID}/members/${userID}/acknowledgements/privacyPolicy`,
            ),
          ),
          getDoc(
            doc(
              db,
              `districts/${districtID}/members/${userID}/acknowledgements/acceptableUsePolicy`,
            ),
          ),
          getDoc(
            doc(db, `districts/${districtID}/auditEvents/staff-provision-${userID}`),
          ),
          getDoc(doc(db, "staffInvitations", hashInvitationCode(invitationCode))),
        ]);

      expect(membership.data()).toMatchObject({
        userID,
        districtID,
        role: "teacher",
        schoolIDs: [schoolID],
        capabilities: ["student.read.detail"],
        assignedStudentIDs: [],
        isActive: true,
        version: 1,
        createdBy: userID,
        updatedBy: userID,
      });
      expect(profile.data()).toMatchObject({
        userID,
        displayName: "Synthetic Staff One",
        email,
        isEmailVerified: true,
      });
      expect(preferences.data()).toMatchObject({
        onboardingComplete: false,
      });
      expect(privacy.data()).toMatchObject({
        documentID: "privacyPolicy",
        version: requiredPolicyVersions.privacyPolicy,
        operationID: `staff-provision-${userID}`,
      });
      expect(acceptableUse.data()).toMatchObject({
        documentID: "acceptableUsePolicy",
        version: requiredPolicyVersions.acceptableUsePolicy,
        operationID: `staff-provision-${userID}`,
      });
      expect(invitation.data()).toMatchObject({
        isActive: false,
        consumedByUserID: userID,
      });
      expect(audit.data()).toMatchObject({
        action: "staff.membership.provision",
        actorUserID: userID,
        districtID,
        targetPath: `districts/${districtID}/members/${userID}`,
        details: {
          role: "teacher",
          schoolIDs: [schoolID],
          capabilities: ["student.read.detail"],
        },
      });
      expect(audit.data()?.requestHash).toMatch(/^[a-f0-9]{64}$/);
      const serializedAudit = JSON.stringify(audit.data());
      expect(serializedAudit).not.toContain(email);
      expect(serializedAudit).not.toContain(invitationCode);
      expect(serializedAudit).not.toContain("Synthetic Staff One");
      expect(JSON.stringify(profile.data())).not.toContain("teacher");
      expect(JSON.stringify(profile.data())).not.toContain(districtID);
      expect(JSON.stringify(profile.data())).not.toContain(schoolID);
      expect(JSON.stringify(invitation.data())).not.toContain(invitationCode);
      expect(
        (await getDoc(doc(db, "staffInvitations", invitationCode))).exists(),
      ).toBe(false);
    });
  });

  it("requires authenticated App Check context without writing records", async () => {
    const handler = makeHandler();

    await expectHttpsError(
      handler(callableRequest(requestData(), { includeAuth: false })),
      "unauthenticated",
    );
    await expectHttpsError(
      handler(callableRequest(requestData(), { includeAppCheck: false })),
      "failed-precondition",
    );

    expect(claimsWrites).toEqual([]);
    expect((await firestore.doc(`districts/${districtID}/members/${userID}`).get()).exists)
      .toBe(false);
  });

  it("accepts a server-owned district administrator invitation without school scope", async () => {
    await seedInvitation({
      role: "districtAdministrator",
      schoolIDs: [],
      capabilities: ["staff.manage", "audit.read"],
    });

    const result = await makeHandler()(callableRequest());

    expect(result).toMatchObject({
      role: "districtAdministrator",
      schoolIDs: [],
      capabilities: ["staff.manage", "audit.read"],
    });
  });

  it("requires authoritative email verification before consuming an invitation", async () => {
    authUser = { ...authUser, emailVerified: false };

    await expectHttpsError(
      makeHandler(() => authUser, true)(callableRequest()),
      "failed-precondition",
    );

    expect(claimsWrites).toEqual([]);
    await expectInvitationToRemainActive();
  });

  it("allows an email-bound unverified account under the temporary policy", async () => {
    authUser = { ...authUser, emailVerified: false };

    const result = await makeHandler(
      () => authUser,
      false,
    )(callableRequest());

    expect(result.replayed).toBe(false);
    expect(claimsWrites).toEqual([
      {
        tmiDistrictID: districtID,
        tmiAccessClass: "staff",
        tmiMembershipVersion: 1,
      },
    ]);
    const profile = await firestore.doc(`users/${userID}/private/profile`).get();
    expect(profile.data()).toMatchObject({
      email,
      isEmailVerified: false,
    });
  });

  it("rejects missing, malformed, and authority-bearing request fields", async () => {
    const handler = makeHandler();
    const base = requestData();

    await expectHttpsError(
      handler(callableRequest({ ...base, invitationCode: "" })),
      "invalid-argument",
    );
    await expectHttpsError(
      handler(callableRequest({ ...base, invitationCode: "short-code" })),
      "invalid-argument",
    );
    await expectHttpsError(
      handler(callableRequest({ ...base, districtID })),
      "invalid-argument",
    );
    await expectHttpsError(
      handler(callableRequest({ ...base, requestedRole: "districtAdministrator" })),
      "invalid-argument",
    );
    await expectHttpsError(
      handler(callableRequest({ ...base, capabilities: ["staff.manage"] })),
      "invalid-argument",
    );

    expect(claimsWrites).toEqual([]);
    await expectInvitationToRemainActive();
  });

  it("requires the configured privacy and acceptable-use versions", async () => {
    await expectHttpsError(
      makeHandler()(
        callableRequest({
          ...requestData(),
          privacyPolicyVersion: "stale-policy",
        }),
      ),
      "failed-precondition",
    );

    expect(claimsWrites).toEqual([]);
    await expectInvitationToRemainActive();
  });

  it("returns one public denial for missing, inactive, expired, or email-mismatched invitations", async () => {
    const handler = makeHandler();

    await testEnv.clearFirestore();
    await expectHttpsError(handler(callableRequest()), "permission-denied");

    await seedInvitation({ isActive: false });
    await expectHttpsError(handler(callableRequest()), "permission-denied");

    await seedInvitation({
      isActive: true,
      expiresAt: Timestamp.fromDate(new Date(now.getTime() - 1_000)),
    });
    await expectHttpsError(handler(callableRequest()), "permission-denied");

    await seedInvitation({
      expiresAt: Timestamp.fromDate(new Date(now.getTime() + 60_000)),
      recipientEmailHash: hashInvitationRecipientEmail(
        invitationCode,
        "another-staff@example.test",
      ),
    });
    await expectHttpsError(handler(callableRequest()), "permission-denied");

    expect(claimsWrites).toEqual([]);
  });

  it("refuses conflicting pre-existing onboarding records transactionally", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${userID}/preferences/settings`), {
        onboardingComplete: true,
      });
    });

    await expectHttpsError(makeHandler()(callableRequest()), "already-exists");

    expect(claimsWrites).toEqual([]);
    expect((await firestore.doc(`districts/${districtID}/members/${userID}`).get()).exists)
      .toBe(false);
    await expectInvitationToRemainActive();
  });

  it("rejects a malformed trusted invitation schema before provisioning", async () => {
    await seedInvitation({ schemaVersion: 2 });

    await expectHttpsError(makeHandler()(callableRequest()), "data-loss");

    expect(claimsWrites).toEqual([]);
    expect((await firestore.doc(`districts/${districtID}/members/${userID}`).get()).exists)
      .toBe(false);
  });

  it("is idempotent for the same UID and refuses replay by another UID", async () => {
    const handler = makeHandler();
    const first = await handler(callableRequest());
    authUser = { ...authUser, customClaims: claimsWrites[0] ?? {} };
    const replay = await handler(callableRequest());

    expect(first.replayed).toBe(false);
    expect(replay.replayed).toBe(true);

    authUser = { ...authUser, userID: "staff-synthetic-2" };
    await expectHttpsError(
      handler(callableRequest(requestData(), { uid: "staff-synthetic-2" })),
      "permission-denied",
    );

    expect(claimsWrites).toHaveLength(2);
  });

  it("allows exactly one UID to consume the invitation under contention", async () => {
    const firstUser = authUser;
    const secondUser: ProvisioningAuthUser = {
      ...authUser,
      userID: "staff-synthetic-2",
    };
    const firstHandler = makeHandler(() => firstUser);
    const secondHandler = makeHandler(() => secondUser);

    const results = await Promise.allSettled([
      firstHandler(callableRequest()),
      secondHandler(
        callableRequest(requestData(), { uid: secondUser.userID }),
      ),
    ]);

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1);
    expect(claimsWrites).toHaveLength(1);
  });

  it("repairs claims on same-user retry after an Auth claim write fails", async () => {
    const handler = makeHandler();
    claimsError = new Error("synthetic claims outage");

    await expectHttpsError(handler(callableRequest()), "unavailable");
    expect((await firestore.doc(`districts/${districtID}/members/${userID}`).get()).exists)
      .toBe(true);

    claimsError = undefined;
    const replay = await handler(callableRequest());

    expect(replay.replayed).toBe(true);
    expect(claimsWrites).toHaveLength(1);
  });

  it("refuses claim repair when the canonical membership or audit was altered", async () => {
    const handler = makeHandler();
    await handler(callableRequest());

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), `districts/${districtID}/members/${userID}`),
        { capabilities: ["staff.manage"] },
      );
    });
    await expectHttpsError(handler(callableRequest()), "data-loss");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `districts/${districtID}/members/${userID}`), {
        capabilities: ["student.read.detail"],
      });
      await updateDoc(
        doc(db, `districts/${districtID}/auditEvents/staff-provision-${userID}`),
        { requestHash: "0".repeat(64) },
      );
    });
    await expectHttpsError(handler(callableRequest()), "data-loss");

    expect(claimsWrites).toHaveLength(1);
  });

  it("refuses replay when consumed invitation state is internally inconsistent", async () => {
    const handler = makeHandler();
    await handler(callableRequest());
    authUser = { ...authUser, customClaims: claimsWrites[0] ?? {} };

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "staffInvitations", hashInvitationCode(invitationCode)),
        {
          isActive: true,
          consumedAt: deleteField(),
        },
      );
    });

    await expectHttpsError(handler(callableRequest()), "data-loss");
    expect(claimsWrites).toHaveLength(1);
  });

  it("refuses an account carrying conflicting trusted claims", async () => {
    authUser = {
      ...authUser,
      customClaims: {
        tmiDistrictID: "district-synthetic-other",
        tmiAccessClass: "staff",
        tmiMembershipVersion: 4,
      },
    };

    await expectHttpsError(makeHandler()(callableRequest()), "permission-denied");

    expect(claimsWrites).toEqual([]);
    await expectInvitationToRemainActive();
  });

  function makeHandler(
    authUserProvider: () => ProvisioningAuthUser = () => authUser,
    requireVerifiedEmail = true,
  ) {
    return createProvisionStaffMembershipHandler({
      firestore,
      now: () => now,
      requireVerifiedEmail,
      getAuthUser: async () => authUserProvider(),
      setCustomUserClaims: async (requestedUserID, claims) => {
        const membership = await firestore
          .doc(`districts/${districtID}/members/${requestedUserID}`)
          .get();
        expect(membership.exists).toBe(true);
        if (claimsError !== undefined) {
          throw claimsError;
        }
        claimsWrites.push(claims);
      },
    });
  }

  async function seedInvitation(
    overrides: Readonly<Record<string, unknown>>,
  ): Promise<void> {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "staffInvitations", hashInvitationCode(invitationCode)),
        {
          schemaVersion: 1,
          recordVersion: 1,
          districtID,
          recipientEmailHash: hashInvitationRecipientEmail(invitationCode, email),
          role: "teacher",
          schoolIDs: [schoolID],
          capabilities: ["student.read.detail"],
          isActive: true,
          expiresAt: Timestamp.fromDate(
            new Date(now.getTime() + 24 * 60 * 60 * 1_000),
          ),
          ...overrides,
        },
      );
    });
  }

  async function expectInvitationToRemainActive(): Promise<void> {
    const invitation = await firestore
      .doc(`staffInvitations/${hashInvitationCode(invitationCode)}`)
      .get();
    expect(invitation.data()?.isActive).toBe(true);
    expect(invitation.data()?.consumedByUserID).toBeUndefined();
  }
});

const expectHttpsError = async (
  promise: Promise<unknown>,
  code: string,
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code });
};
