import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { exportAssignmentResponses, listAssignmentResponses } from "../src/index.js";
import { canonicalFields, createFormHandlers, scoreAnswers } from "../src/forms.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const handlers = createFormHandlers(() => getFirestore());
const call = <T>(data: T, uid = "teacher"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);

const scoredTemplate = {
  name: "Wellbeing screener", version: 1, districtId: "d1", isScored: true,
  scoreBands: [{ minimum: 0, label: "Low" }, { minimum: 6, label: "Moderate" }, { minimum: 10, label: "High" }],
  sections: [{ title: "Screener", fields: [
    { label: "Sleep", type: "multipleChoice", isRequired: true, options: ["Well", "Poorly"], optionPoints: [0, 3] },
    { label: "Worried?", type: "checkbox", isRequired: false, points: 2 },
    { label: "Stress level", type: "Rating", isRequired: true, points: 1 },
    { label: "Anything else", type: "longText", isRequired: false },
  ] }],
};

describe("scored forms, assignment summaries, and export", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1/members/teacher").set(activeMembership({
      capabilities: ["student.read.detail", "student.write.detail", "report.export"], assignedStudentIDs: ["s1", "s2"],
    }));
    await db.doc("districts/d1/members/noexport").set(activeMembership({
      capabilities: ["student.read.detail", "student.write.detail"], assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/members/outsider").set(activeMembership({ schoolIDs: ["school-9"], capabilities: ["report.export"] }));
    await db.doc("districts/d1/students/s1").set({ districtId: "d1", schoolId: "school-1", displayName: "Ava Diaz" });
    await db.doc("districts/d1/students/s2").set({ districtId: "d1", schoolId: "school-1", displayName: "=cmd|evil" });
    await db.doc("districts/d1/students/s3").set({ districtId: "d1", schoolId: "school-2", displayName: "Hidden" });
    await db.doc("districts/d1/formTemplates/t1").set(scoredTemplate);
    await db.doc("districts/d1/formAssignments/a1").set({
      templateId: "t1", templateName: "Wellbeing screener", assignedBy: "teacher", districtId: "d1",
      studentIDs: ["s1", "s2", "s3"], isActive: true, allowLateSubmissions: true, createdAt: Timestamp.now(),
    });
  });

  it("exports the callables", () => {
    expect(listAssignmentResponses.run).toBeTypeOf("function");
    expect(exportAssignmentResponses.run).toBeTypeOf("function");
  });

  it("scores from the published definition only", () => {
    const fields = canonicalFields(scoredTemplate);
    expect(scoreAnswers(scoredTemplate, fields, { "s0-f0": "Poorly", "s0-f1": true, "s0-f2": 4 }))
      .toMatchObject({ score: 9, maxScore: 10, band: "Moderate" });
    expect(scoreAnswers(scoredTemplate, fields, { "s0-f0": "Well", "s0-f2": 1 })).toMatchObject({ score: 1, band: "Low" });
    expect(scoreAnswers({ ...scoredTemplate, isScored: false }, fields, { "s0-f0": "Poorly" })).toBeNull();
  });

  it("freezes the computed score at submission and rejects client scores", async () => {
    await expect(handlers.submitFormResponse(call({
      districtID: "d1", expectedRecordVersion: 0, idempotencyKey: "k0", reasonCode: "form-completion",
      assignmentID: "a1", studentID: "s1", respondentType: "staff",
      answers: { "s0-f0": "Poorly", "s0-f2": 5 }, score: 100,
    }))).rejects.toMatchObject({ code: "invalid-argument" });

    await handlers.submitFormResponse(call({
      districtID: "d1", expectedRecordVersion: 0, idempotencyKey: "k1", reasonCode: "form-completion",
      assignmentID: "a1", studentID: "s1", respondentType: "staff",
      answers: { "s0-f0": "Poorly", "s0-f1": true, "s0-f2": 5 },
    }));
    const stored = (await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).data();
    expect(stored?.scoring).toMatchObject({ score: 10, maxScore: 10, band: "High" });

    // Changing the template afterwards never rescores a frozen response.
    await db.doc("districts/d1/formTemplates/t1").update({ isScored: false });
    const loaded = await handlers.loadFormResponse(call({ districtID: "d1", assignmentID: "a1", studentID: "s1" }));
    expect(loaded.scoring).toMatchObject({ score: 10, band: "High" });

    await handlers.reviewFormResponse(call({
      districtID: "d1", expectedRecordVersion: 1, idempotencyKey: "k2", reasonCode: "form-review",
      assignmentID: "a1", studentID: "s1", outcome: "followUpNeeded", comment: null,
    }));
    const reviewed = (await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).data();
    expect(reviewed?.scoring?.score).toBe(10);
  });

  it("summarizes an assignment for the students the caller can open", async () => {
    await handlers.submitFormResponse(call({
      districtID: "d1", expectedRecordVersion: 0, idempotencyKey: "k3", reasonCode: "form-completion",
      assignmentID: "a1", studentID: "s1", respondentType: "staff", answers: { "s0-f0": "Well", "s0-f2": 2 },
    }));
    const summary = await handlers.listAssignmentResponses(call({ districtID: "d1", assignmentID: "a1" }));
    expect(summary.counts).toEqual({ assigned: 2, notStarted: 1, draft: 0, submitted: 1, reviewed: 0 });
    expect(summary.isScored).toBe(true);
    expect(summary.averageScore).toBe(2);
    expect(summary.rows.map((row) => row.studentID)).toEqual(["s2", "s1"]);
    expect(summary.rows[0]).not.toHaveProperty("answers");
    await expect(handlers.listAssignmentResponses(call({ districtID: "d1", assignmentID: "a1" }, "outsider")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("exports an audited, formula-safe CSV that needs the export capability", async () => {
    await handlers.submitFormResponse(call({
      districtID: "d1", expectedRecordVersion: 0, idempotencyKey: "k4", reasonCode: "form-completion",
      assignmentID: "a1", studentID: "s2", respondentType: "family", answers: { "s0-f0": "Poorly", "s0-f2": 3, "s0-f3": "+SUM(A1)" },
    }));
    const result = await handlers.exportAssignmentResponses(call({ districtID: "d1", assignmentID: "a1" }));
    expect(result.fileName).toBe("Wellbeing-screener-responses.csv");
    const lines = result.csv.trim().split("\r\n");
    expect(lines[0]).toBe("Student,State,Submitted at,Score,Max score,Band,Review,Sleep,Worried?,Stress level,Anything else");
    expect(lines.find((line) => line.includes("cmd"))).toMatch(/^'=cmd\|evil,submitted,.*,6,10,Moderate,,Poorly,,3,'\+SUM\(A1\)$/u);
    expect(result.csv).not.toContain("Hidden");
    const audits = await db.collection("districts/d1/auditEvents").where("action", "==", "form.responses.export").get();
    expect(audits.docs[0]?.data().details.studentIDs).toEqual(["s2"]);
    await expect(handlers.exportAssignmentResponses(call({ districtID: "d1", assignmentID: "a1" }, "noexport")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });
});
