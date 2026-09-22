import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { adminCreateInvitation, mutateMembership } from "../src/index.js";
import { createAdministrationHandlers } from "../src/administration.js";
import {
  createProvisionStaffMembershipHandler,
  requiredPolicyVersions,
} from "../src/invitations.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const now = new Date("2026-09-22T15:00:00.000Z");
const handlers = createAdministrationHandlers({
  firestore: getFirestore(),
  now: () => now,
  getUsers: async (ids) => ids.map((userID) => ({ userID, email: `${userID}@example.test`, displayName: userID })),
});

const request = <T>(data: T, uid = "district-admin"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);

const invite = (overrides: Record<string, unknown> = {}, uid = "district-admin") =>
  handlers.createInvitation(request({
    districtID: "d1",
    idempotencyKey: `invite-${Math.random().toString(36).slice(2)}`,
    schoolIDs: ["school-1"],
    role: "teacher",
    capabilities: ["student.read.detail", "student.write.detail"],
    recipientEmail: "new.teacher@example.test",
    expiresInDays: 14,
    label: "Room 4",
    ...overrides,
  }, uid));

describe("district staff administration", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1").set({ districtID: "d1", name: "District One" });
    await db.doc("districts/d1/schools/school-1").set({ name: "School One" });
    await db.doc("districts/d1/schools/school-2").set({ name: "School Two" });
    await db.doc("districts/d1/members/district-admin").set(activeMembership({
      role: "districtAdministrator",
      schoolIDs: [],
      capabilities: ["staff.manage", "student.read.detail", "student.write.detail", "audit.read"],
      assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/members/school-admin").set(activeMembership({
      role: "schoolAdministrator",
      schoolIDs: ["school-1"],
      capabilities: ["staff.manage", "student.read.detail"],
      assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/members/teacher-a").set(activeMembership({ schoolIDs: ["school-1"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/members/teacher-b").set(activeMembership({ schoolIDs: ["school-2"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/members/plain-teacher").set(activeMembership({ assignedStudentIDs: [] }));
  });

  it("exports the admin callables", () => {
    expect(adminCreateInvitation.run).toBeTypeOf("function");
  });

  it("requires staff.manage", async () => {
    await expect(handlers.listStaff(request({ districtID: "d1" }, "plain-teacher")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("scopes the staff directory for school administrators", async () => {
    const district = await handlers.listStaff(request({ districtID: "d1" }));
    expect(district.staff.map((member) => member.userID).sort()).toEqual(
      ["district-admin", "plain-teacher", "school-admin", "teacher-a", "teacher-b"],
    );
    const school = await handlers.listStaff(request({ districtID: "d1" }, "school-admin"));
    const ids = school.staff.map((member) => member.userID).sort();
    expect(ids).toContain("teacher-a");
    expect(ids).not.toContain("teacher-b");
    expect(ids).not.toContain("district-admin");
    expect(school.staff.find((member) => member.userID === "school-admin")?.isManageable).toBe(false);
  });

  it("creates invitations the provisioning callable accepts", async () => {
    const created = await invite();
    const provision = createProvisionStaffMembershipHandler({
      firestore: db,
      now: () => now,
      requireVerifiedEmail: false,
      getAuthUser: async () => ({ userID: "new-teacher", email: "new.teacher@example.test", emailVerified: true, disabled: false, customClaims: {} }),
      setCustomUserClaims: async () => {},
    });
    await expect(provision(request({
      invitationCode: created.invitationCode,
      displayName: "New Teacher",
      privacyPolicyVersion: requiredPolicyVersions.privacyPolicy,
      acceptableUsePolicyVersion: requiredPolicyVersions.acceptableUsePolicy,
    }, "new-teacher"))).resolves.toMatchObject({ districtID: "d1", role: "teacher" });
    const list = await handlers.listInvitations(request({ districtID: "d1" }));
    expect(list.invitations[0]).toMatchObject({ status: "consumed", createdBy: "district-admin" });
  });

  it("enforces the capability ceiling and school scope", async () => {
    await expect(invite({ capabilities: ["student.restricted.write"] }))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(invite({ capabilities: ["student.write.detail"] }, "school-admin"))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(invite({ schoolIDs: ["school-2"], capabilities: [] }, "school-admin"))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(invite({ role: "districtAdministrator", schoolIDs: [], capabilities: [] }, "school-admin"))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(invite({ capabilities: ["student.read.detail"] }, "school-admin"))
      .resolves.toMatchObject({ invitationCode: expect.any(String) });
  });

  it("revokes only unredeemed invitations in scope", async () => {
    const created = await invite({ schoolIDs: ["school-2"] });
    await expect(handlers.revokeInvitation(request({ districtID: "d1", invitationID: created.invitationID }, "school-admin")))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(handlers.revokeInvitation(request({ districtID: "d1", invitationID: created.invitationID })))
      .resolves.toEqual({ revoked: true });
    const list = await handlers.listInvitations(request({ districtID: "d1" }));
    expect(list.invitations[0]?.status).toBe("revoked");
  });

  it("refuses a replayed creation because the code cannot be shown twice", async () => {
    await invite({ idempotencyKey: "same-key" });
    await expect(invite({ idempotencyKey: "same-key" })).rejects.toMatchObject({ code: "already-exists" });
  });

  it("mutateMembership keeps userID and refuses capabilities the caller lacks", async () => {
    await db.doc("districts/d1/members/teacher-a").update({ recordVersion: 1, version: 1 });
    await expect(mutateMembership.run(request({
      districtID: "d1",
      targetUserID: "teacher-a",
      role: "teacher",
      schoolIDs: ["school-1"],
      capabilities: ["student.restricted.write"],
      assignedStudentIDs: [],
      isActive: true,
      expectedRecordVersion: 1,
      idempotencyKey: "escalate-attempt",
      reasonCode: "staff-reassignment",
    }))).rejects.toMatchObject({ code: "permission-denied" });
  });
});
