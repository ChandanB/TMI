import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { assertFails, assertSucceeds, type RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { doc, setDoc, updateDoc } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { transitionPlan, type TransitionPlanRequest } from "../src/index.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";
const statuses = ["draft", "pendingApproval", "changesRequested", "approved", "active", "paused", "completed", "archived"] as const;
const edges: Record<string, readonly string[]> = {
  draft: ["pendingApproval", "archived"], pendingApproval: ["draft", "changesRequested", "approved"],
  changesRequested: ["draft", "archived"], approved: ["active"], active: ["paused", "completed"],
  paused: ["active", "completed"], completed: ["archived"], archived: [],
};
const request = (nextStatus = "pendingApproval", overrides = {}): CallableRequest<TransitionPlanRequest> => ({
  data: { districtID: "d1", planID: "p1", nextStatus, expectedRecordVersion: 1, idempotencyKey: "op1", reasonCode: "plan-review", note: "Review explanation and outcome", ...overrides },
  auth: { uid: "staff", token: { uid: "staff", ...trustedClaims("d1") } }, app: { appId: "test-app" },
} as unknown as CallableRequest<TransitionPlanRequest>);
describe("canonical plan lifecycle", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();
  const plan = db.doc("districts/d1/plans/p1");
  const member = db.doc("districts/d1/members/staff");
  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });
  beforeEach(async () => {
    await env.clearFirestore();
    await member.set(activeMembership({ capabilities: ["student.write.detail", "plan.approve", "student.read.detail"] }));
    await plan.set({ districtId: "d1", schoolIDs: ["school-1"], studentIDs: ["student-1"], assignedMemberIDs: ["staff"], status: "draft", approvalStatus: "notRequested", createdBy: "staff", recordVersion: 1, title: "Plan", model: "chaseYourSpace", startDate: Timestamp.now() });
    await db.doc("districts/d1/students/student-1").set({ districtId: "d1", schoolId: "school-1", assignedMemberIDs: ["staff"] });
  });
  it.each(statuses)("enforces all edges from %s", async (from) => {
    for (const to of statuses) {
      await plan.update({ status: from, recordVersion: 1 });
      const call = transitionPlan.run(request(to, { idempotencyKey: `${from}-${to}` }));
      if (edges[from]!.includes(to)) await expect(call).resolves.toMatchObject({ recordVersion: 2, replayed: false });
      else await expect(call).rejects.toMatchObject({ code: "failed-precondition" });
    }
  });
  it("writer may submit but cannot approve or request changes", async () => {
    await member.update({ capabilities: ["student.write.detail"] });
    await expect(transitionPlan.run(request())).resolves.toMatchObject({ recordVersion: 2 });
    for (const next of ["approved", "changesRequested"]) await expect(transitionPlan.run(request(next, { expectedRecordVersion: 2, idempotencyKey: next }))).rejects.toMatchObject({ code: "permission-denied" });
  });
  it("approver capability alone cannot perform writer moves", async () => {
    await member.update({ capabilities: ["plan.approve"] });
    await expect(transitionPlan.run(request())).rejects.toMatchObject({ code: "permission-denied" });
  });
  it("normalizes stored submitted but rejects it as client input", async () => {
    await plan.update({ status: "submitted" });
    await expect(transitionPlan.run(request("approved"))).resolves.toMatchObject({ recordVersion: 2 });
    await expect(transitionPlan.run(request("submitted"))).rejects.toMatchObject({ code: "invalid-argument" });
  });
  it("freezes approval and completion atomically with audit and exact replay", async () => {
    await plan.update({ status: "pendingApproval" });
    await plan.collection("goals").doc("g1").set({ title: "Original goal" });
    await plan.collection("actions").doc("a1").set({ title: "Original action" });
    await transitionPlan.run(request("approved"));
    await expect(transitionPlan.run(request("approved"))).resolves.toEqual({ operationID: "op1", recordVersion: 2, replayed: true });
    const approved = (await plan.get()).data()!;
    expect(approved).toMatchObject({ approvalStatus: "approved", approvedBy: "staff" });
    expect(approved.approvedAt).toBeInstanceOf(Timestamp);
    expect(approved.updatedAt).toEqual(approved.approvedAt);
    let revisions = await plan.collection("revisions").get();
    expect(revisions.size).toBe(1);
    expect(revisions.docs[0]!.data()).toMatchObject({ planID: "p1", status: "approved", reason: "approved", sequence: 1, frozenBy: "staff", goalIDs: ["g1"], actionIDs: ["a1"], note: "Review explanation and outcome" });
    expect((await db.doc("districts/d1/auditEvents/op1").get()).get("createdAt")).toEqual(approved.updatedAt);
    await plan.update({ status: "active" });
    await transitionPlan.run(request("completed", { expectedRecordVersion: 2, idempotencyKey: "complete" }));
    revisions = await plan.collection("revisions").orderBy("sequence").get();
    expect(revisions.size).toBe(2);
    expect(revisions.docs[1]!.get("sequence")).toBe(2);
    expect(revisions.docs[1]!.get("reason")).toBe("completed");
  });
  it.each(["changesRequested", "completed"])("requires explanation for %s", async (next) => {
    await plan.update({ status: next === "completed" ? "active" : "pendingApproval" });
    for (const note of [undefined, "", "   "]) await expect(transitionPlan.run(request(next, { note }))).rejects.toMatchObject({ code: "invalid-argument" });
  });
  it("rejects stale versions and operation-key reuse", async () => {
    await expect(transitionPlan.run(request("pendingApproval", { expectedRecordVersion: 0 }))).rejects.toMatchObject({ code: "aborted" });
    await transitionPlan.run(request());
    await expect(transitionPlan.run(request("archived"))).rejects.toMatchObject({ code: "already-exists" });
    expect((await plan.get()).get("recordVersion")).toBe(2);
    expect((await db.collection("districts/d1/auditEvents").get()).size).toBe(1);
  });
  it.each([{ isActive: false }, { version: 2 }, { schoolIDs: ["school-2"] }, { assignedStudentIDs: [] }, { districtID: "d2" }])("rejects membership %j", async (patch) => {
    await member.update(patch);
    await expect(transitionPlan.run(request())).rejects.toMatchObject({ code: "permission-denied" });
  });
  it.each([{ districtId: "d2" }, { assignedMemberIDs: ["else"] }, { schoolIDs: ["school-1", "school-2"] }, { studentIDs: ["student-1", "student-2"] }])("rejects plan outside scope %j", async (patch) => {
    await plan.update(patch);
    await expect(transitionPlan.run(request())).rejects.toMatchObject({ code: "permission-denied" });
  });
  it("validates actual student schools", async () => {
    await db.doc("districts/d1/students/student-1").update({ schoolId: "school-2" });
    await expect(transitionPlan.run(request())).rejects.toMatchObject({ code: "permission-denied" });
  });
  it("scopes school and district admins", async () => {
    await member.update({ role: "schoolAdministrator", assignedStudentIDs: [] });
    await plan.update({ assignedMemberIDs: [], schoolIDs: ["school-1", "school-2"] });
    await expect(transitionPlan.run(request())).rejects.toMatchObject({ code: "permission-denied" });
    await member.update({ role: "districtAdministrator" });
    await expect(transitionPlan.run(request())).resolves.toMatchObject({ recordVersion: 2 });
    await expect(transitionPlan.run(request("approved", { districtID: "d2", expectedRecordVersion: 2, idempotencyKey: "cross" }))).rejects.toMatchObject({ code: "permission-denied" });
  });
  it("denies direct status, approval, version and history bypasses even for admins", async () => {
    for (const role of ["teacher", "districtAdministrator"]) {
      await member.update({ role });
      await plan.update({ recordVersion: 1 });
      const client = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
      const ref = doc(client, plan.path);
      for (const patch of [{ status: "pendingApproval" }, { approvalStatus: "approved" }, { approvedBy: "staff" }, { recordVersion: 99 }, { approvalHistory: [] }, { revisionSequence: 99 }]) await assertFails(updateDoc(ref, patch));
      await assertFails(updateDoc(ref, {
        relatedCareerIDs: ["career-1"],
        recordVersion: 2,
        updatedBy: "staff",
      }));
      await assertFails(setDoc(doc(client, `${plan.path}/revisions/fake`), { planID: "p1", frozenBy: "staff", sequence: 1 }));
      await assertFails(setDoc(doc(client, `${plan.path}/approvals/fake`), { approvedBy: "staff" }));
      await assertFails(setDoc(doc(client, "districts/d1/auditEvents/fake"), { actorUserID: "staff" }));
      await assertFails(setDoc(doc(client, "districts/d1/plans/forged"), { ...(await plan.get()).data(), startDate: new Date(), approvalStatus: "approved" }));
      await assertFails(setDoc(doc(client, "districts/d1/plans/prelinked"), {
        ...(await plan.get()).data(),
        startDate: new Date(),
        relatedCareerIDs: ["career-1"],
      }));
      await assertSucceeds(updateDoc(ref, { title: "Edited draft", recordVersion: 2, updatedBy: "staff" }));
    }
  });
  it("keeps approved content immutable while allowing active status updates", async () => {
    await plan.collection("goals").doc("g1").set({ planID: "p1", title: "Agreed", status: "notStarted" });
    const client = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    const goal = doc(client, `${plan.path}/goals/g1`);
    await plan.update({ status: "approved" });
    await assertFails(updateDoc(goal, { title: "Replaced without approval" }));
    await plan.update({ status: "active" });
    await assertFails(updateDoc(goal, { title: "Replaced without approval" }));
    await assertSucceeds(updateDoc(goal, { status: "inProgress" }));
    await plan.update({ status: "completed" });
    await assertFails(updateDoc(goal, { status: "met" }));
  });
  it("requires active plan and authentic attribution for progress", async () => {
    const client = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    const entry = doc(client, `${plan.path}/progress/e1`);
    const evidence = { planID: "p1", studentID: "student-1", authorID: "staff", note: "Observed" };
    await assertFails(setDoc(entry, evidence));
    await plan.update({ status: "active" });
    await assertFails(setDoc(entry, { ...evidence, authorID: "another-member" }));
    await assertSucceeds(setDoc(entry, evidence));
    await assertFails(updateDoc(entry, { note: "Rewritten history" }));
  });
  it("prevents resource takeover across schools or from district scope", async () => {
    const client = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    const ref = db.doc("districts/d1/resources/r1");
    for (const schoolId of ["school-2", null]) {
      await ref.set({ schoolId, title: "Original", createdBy: "other" });
      await assertFails(updateDoc(doc(client, ref.path), { schoolId: "school-1", title: "Takeover" }));
    }
    await ref.set({ schoolId: "school-1", title: "Original", createdBy: "staff" });
    await assertSucceeds(updateDoc(doc(client, ref.path), { title: "Updated" }));
  });

});
