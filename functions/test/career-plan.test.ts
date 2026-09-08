import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import * as functions from "../src/index.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";

type AttachRequest = {
  districtID: string;
  studentID: string;
  careerID: string;
  planID: string;
};

const request = (
  overrides: Partial<AttachRequest> = {},
  claims: Record<string, unknown> = trustedClaims("d1"),
): CallableRequest<AttachRequest> => ({
  data: {
    districtID: "d1",
    studentID: "student-1",
    careerID: "career-1",
    planID: "plan-1",
    ...overrides,
  },
  auth: { uid: "staff", token: { uid: "staff", ...claims } },
  app: { appId: "test-app" },
} as unknown as CallableRequest<AttachRequest>);

const attach = (call: CallableRequest<AttachRequest>) => {
  const callable = (functions as unknown as {
    attachCareerToPlan?: { run: (value: CallableRequest<AttachRequest>) => Promise<unknown> };
  }).attachCareerToPlan;
  expect(callable, "attachCareerToPlan callable export").toBeDefined();
  return callable!.run(call);
};

describe("trusted career-to-plan attachment", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();
  const member = db.doc("districts/d1/members/staff");
  const student = db.doc("districts/d1/students/student-1");
  const plan = db.doc("districts/d1/plans/plan-1");
  const relationship = student.collection("careers").doc("career-1");

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await member.set(activeMembership({
      capabilities: ["student.read.detail", "student.write.detail"],
    }));
    await student.set({
      districtId: "d1",
      schoolId: "school-1",
      assignedMemberIDs: ["staff"],
    });
    await plan.set({
      districtId: "d1",
      schoolIDs: ["school-1"],
      studentIDs: ["student-1"],
      assignedMemberIDs: ["staff"],
      status: "draft",
      relatedCareerIDs: [],
      recordVersion: 4,
    });
    await db.doc("catalogs/careers/items/career-1").set({
      title: "Engineer",
      category: "Technology",
      summary: "Designs and builds systems.",
      isApproved: true,
    });
  });

  it("creates both canonical edges and an audit record atomically", async () => {
    await expect(attach(request())).resolves.toEqual({
      districtID: "d1",
      planID: "plan-1",
      careerID: "career-1",
      studentID: "student-1",
    });

    expect((await relationship.get()).data()).toMatchObject({
      districtID: "d1",
      studentID: "student-1",
      careerID: "career-1",
      isSaved: false,
      isDismissed: false,
      isCompared: false,
      linkedPlanIDs: ["plan-1"],
      schemaVersion: 1,
      recordVersion: 1,
      createdBy: "staff",
      updatedBy: "staff",
    });
    expect((await relationship.get()).get("createdAt")).toBeInstanceOf(Timestamp);
    expect((await plan.get()).data()).toMatchObject({
      relatedCareerIDs: ["career-1"],
      recordVersion: 5,
      updatedBy: "staff",
    });
    const audits = await db.collection("districts/d1/auditEvents")
      .where("action", "==", "career.plan.attach").get();
    expect(audits.size).toBe(1);
    expect(audits.docs[0]!.data()).toMatchObject({
      actorUserID: "staff",
      targetPath: "districts/d1/plans/plan-1",
      details: { studentID: "student-1", careerID: "career-1", planID: "plan-1" },
    });
  });

  it("replays idempotently without changing versions, metadata, or audit count", async () => {
    await relationship.set({
      districtID: "d1", studentID: "student-1", careerID: "career-1",
      isSaved: false, isDismissed: true, isCompared: true,
      linkedPlanIDs: [], lastViewedAt: Timestamp.fromMillis(1_000),
      schemaVersion: 1, recordVersion: 8,
      createdAt: Timestamp.fromMillis(500), createdBy: "student-session",
      updatedAt: Timestamp.fromMillis(1_000), updatedBy: "student-session",
    });

    await attach(request());
    const firstRelationship = (await relationship.get()).data()!;
    const firstPlan = (await plan.get()).data()!;
    await attach(request());
    const replayedRelationship = (await relationship.get()).data()!;
    const replayedPlan = (await plan.get()).data()!;

    expect(firstRelationship).toMatchObject({
      isSaved: false, isDismissed: true, isCompared: true,
      linkedPlanIDs: ["plan-1"], recordVersion: 9,
      createdBy: "student-session", updatedBy: "staff",
    });
    expect(firstRelationship.lastViewedAt).toEqual(Timestamp.fromMillis(1_000));
    expect(replayedRelationship).toEqual(firstRelationship);
    expect(replayedPlan).toEqual(firstPlan);
    expect(replayedPlan.recordVersion).toBe(5);
    expect((await db.collection("districts/d1/auditEvents")
      .where("action", "==", "career.plan.attach").get()).size).toBe(1);
  });

  it("adds a missing student edge without bumping a plan that already has the career", async () => {
    await plan.update({ relatedCareerIDs: ["career-1"] });

    await expect(attach(request())).resolves.toMatchObject({ districtID: "d1" });

    expect((await relationship.get()).get("linkedPlanIDs")).toEqual(["plan-1"]);
    expect((await plan.get()).get("recordVersion")).toBe(4);
    expect((await db.collection("districts/d1/auditEvents")
      .where("action", "==", "career.plan.attach").get()).size).toBe(1);
  });

  it("creates a distinct edge and audit for a second student on a multi-student plan", async () => {
    await member.update({ assignedStudentIDs: ["student-1", "student-2"] });
    await db.doc("districts/d1/students/student-2").set({
      districtId: "d1", schoolId: "school-1", assignedMemberIDs: [],
    });
    await plan.update({
      studentIDs: ["student-1", "student-2"],
      relatedCareerIDs: ["career-1"],
    });
    await attach(request());
    await attach(request({ studentID: "student-2" }));

    expect((await db.doc("districts/d1/students/student-2/careers/career-1").get())
      .get("linkedPlanIDs")).toEqual(["plan-1"]);
    expect((await plan.get()).get("recordVersion")).toBe(4);
    expect((await db.collection("districts/d1/auditEvents")
      .where("action", "==", "career.plan.attach").get()).size).toBe(2);
  });

  it("rejects an existing relationship with mismatched stored identity", async () => {
    await relationship.set({
      districtID: "d1", studentID: "student-other", careerID: "career-1",
      isSaved: false, isDismissed: false, isCompared: false,
      linkedPlanIDs: [], schemaVersion: 1, recordVersion: 1,
      createdAt: Timestamp.now(), createdBy: "staff",
      updatedAt: Timestamp.now(), updatedBy: "staff",
    });

    await expect(attach(request())).rejects.toMatchObject({ code: "data-loss" });
    expect((await plan.get()).get("recordVersion")).toBe(4);
  });

  it.each(["pendingApproval", "approved", "active", "paused", "completed", "archived"])(
    "rejects frozen or non-editable %s plans",
    async (status) => {
      await plan.update({ status });
      await expect(attach(request())).rejects.toMatchObject({ code: "failed-precondition" });
    },
  );

  it("allows changes-requested plans", async () => {
    await plan.update({ status: "changesRequested" });
    await expect(attach(request())).resolves.toEqual({
      districtID: "d1", planID: "plan-1", careerID: "career-1", studentID: "student-1",
    });
  });

  it.each([
    ["cross district", { districtID: "d2" }, trustedClaims("d1")],
    ["student mode", {}, { tmiDistrictID: "d1", tmiAccessClass: "student", tmiMembershipVersion: 1 }],
  ])("rejects %s accounts", async (_label, overrides, claims) => {
    await expect(attach(request(overrides, claims))).rejects.toMatchObject({ code: "permission-denied" });
  });

  it.each([
    ["stale membership", async () => member.update({ version: 2 })],
    ["unassigned membership", async () => member.update({ assignedStudentIDs: [] })],
    ["different student", async () => plan.update({ studentIDs: ["student-2"] })],
    ["unapproved career", async () => db.doc("catalogs/careers/items/career-1").update({ isApproved: false })],
    ["explicitly inactive career", async () => db.doc("catalogs/careers/items/career-1").update({ isActive: false })],
  ])("rejects %s", async (_label, arrange) => {
    await arrange();
    await expect(attach(request())).rejects.toMatchObject({
      code: expect.stringMatching(/permission-denied|failed-precondition/u),
    });
    expect((await relationship.get()).exists).toBe(false);
    expect((await plan.get()).get("recordVersion")).toBe(4);
  });
});
