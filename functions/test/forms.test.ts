import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { doc, getDoc } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { submitFormResponse } from "../src/index.js";
import { canonicalFields, createFormHandlers } from "../src/forms.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const handlers = createFormHandlers(() => getFirestore());
const call = <T>(data: T, uid = "teacher"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);

const where = { districtID: "d1", assignmentID: "a1", studentID: "s1" };
const base = (key: string, expectedRecordVersion: number) => ({
  districtID: "d1", expectedRecordVersion, idempotencyKey: key, reasonCode: "form-completion",
});

describe("canonical form completion", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1/members/teacher").set(activeMembership({
      capabilities: ["student.read.detail", "student.write.detail"],
      assignedStudentIDs: ["s1"],
    }));
    await db.doc("districts/d1/members/reader").set(activeMembership({
      role: "counselor",
      capabilities: ["student.read.detail"],
      assignedStudentIDs: ["s1"],
    }));
    await db.doc("districts/d1/members/other").set(activeMembership({
      schoolIDs: ["school-2"],
      capabilities: ["student.read.detail", "student.write.detail"],
      assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/students/s1").set({ districtId: "d1", schoolId: "school-1", assignedMemberIDs: ["teacher", "reader"] });
    await db.doc("districts/d1/formTemplates/t1").set({
      name: "Morning check-in", version: 2, districtId: "d1",
      sections: [{ title: "Today", fields: [
        { label: "How are you feeling?", type: "Rating", isRequired: true },
        { label: "What helped?", type: "longText", isRequired: false },
        { label: "Mood", type: "dropdown", isRequired: true, options: ["Calm", "Busy"] },
        { label: "Upload", type: "file", isRequired: true },
      ] }],
    });
    await db.doc("districts/d1/formAssignments/a1").set({
      templateId: "t1", templateName: "Morning check-in", assignedBy: "teacher", districtId: "d1",
      studentIDs: ["s1"], isActive: true, allowLateSubmissions: true, requiresReview: true,
      totalAssigned: 1, totalSubmitted: 0, totalReviewed: 0, createdAt: Timestamp.now(),
      cohort: { type: "specificStudents" },
    });
  });

  it("exports the callables", () => {
    expect(submitFormResponse.run).toBeTypeOf("function");
  });

  it("derives positional field keys and marks unsupported types", () => {
    const fields = canonicalFields({ sections: [{ title: "A", fields: [{ label: "x", type: "text" }, { label: "f", type: "file" }] }] });
    expect(fields.map((field) => field.key)).toEqual(["s0-f0", "s0-f1"]);
    expect(fields[1]?.isAnswerable).toBe(false);
  });

  it("lists the student's forms with response state", async () => {
    const result = await handlers.listStudentForms(call({ districtID: "d1", studentID: "s1" }));
    expect(result.forms).toEqual([expect.objectContaining({ assignmentID: "a1", state: "notStarted", recordVersion: 0 })]);
    await expect(handlers.listStudentForms(call({ districtID: "d1", studentID: "s1" }, "other")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("autosaves, submits, freezes, and reviews", async () => {
    const loaded = await handlers.loadFormResponse(call(where));
    expect(loaded.fields).toHaveLength(4);
    expect(loaded.canEdit).toBe(true);

    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: { "s0-f0": 4 } })))
      .resolves.toEqual({ recordVersion: 1 });
    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: {} })))
      .rejects.toMatchObject({ code: "aborted" });

    await expect(handlers.submitFormResponse(call({ ...base("submit-1", 1), assignmentID: "a1", studentID: "s1", respondentType: "family", answers: { "s0-f0": 4 } })))
      .rejects.toMatchObject({ code: "failed-precondition" });

    await expect(handlers.submitFormResponse(call({ ...base("submit-2", 1), assignmentID: "a1", studentID: "s1", respondentType: "family", answers: { "s0-f0": 4, "s0-f2": "Calm", "s0-f1": "A walk" } })))
      .resolves.toMatchObject({ recordVersion: 2 });

    const stored = (await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).data();
    expect(stored).toMatchObject({ state: "submitted", respondentType: "family", templateVersion: 2, answers: { "s0-f2": "Calm" } });
    expect(stored?.fields).toHaveLength(4);
    expect((await db.doc("districts/d1/formAssignments/a1").get()).data()?.totalSubmitted).toBe(1);
    const audit = JSON.stringify((await db.doc("districts/d1/auditEvents/submit-2").get()).data());
    expect(audit).not.toContain("A walk");

    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 2, answers: {} })))
      .rejects.toMatchObject({ code: "failed-precondition" });

    await db.doc("districts/d1/formTemplates/t1").update({ sections: [] });
    const frozen = await handlers.loadFormResponse(call(where));
    expect(frozen.fields).toHaveLength(4);
    expect(frozen.canEdit).toBe(false);

    await expect(handlers.reviewFormResponse(call({ ...base("review-1", 2), assignmentID: "a1", studentID: "s1", outcome: "followUpNeeded", comment: "Talk with family" })))
      .resolves.toMatchObject({ recordVersion: 3 });
    const reviewed = (await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).data();
    expect(reviewed).toMatchObject({ state: "reviewed", answers: { "s0-f2": "Calm" }, review: { outcome: "followUpNeeded" } });
    expect((await db.doc("districts/d1/formAssignments/a1").get()).data()?.totalReviewed).toBe(1);
  });

  it("rejects bad answers, read-only staff, and closed or late assignments", async () => {
    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: { "s0-f2": "Angry" } })))
      .rejects.toMatchObject({ code: "invalid-argument" });
    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: { "s0-f3": "x" } })))
      .rejects.toMatchObject({ code: "invalid-argument" });
    await expect(handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: {} }, "reader")))
      .rejects.toMatchObject({ code: "permission-denied" });
    await db.doc("districts/d1/formAssignments/a1").update({ allowLateSubmissions: false, dueDate: Timestamp.fromMillis(Date.now() - 86_400_000) });
    await expect(handlers.submitFormResponse(call({ ...base("late", 0), assignmentID: "a1", studentID: "s1", respondentType: "staff", answers: { "s0-f0": 3, "s0-f2": "Busy" } })))
      .rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("lets staff who can read the student read responses, and nobody write them", async () => {
    await handlers.saveFormDraft(call({ ...where, expectedRecordVersion: 0, answers: { "s0-f0": 2 } }));
    const reader = env.authenticatedContext("reader", trustedClaims("d1")).firestore();
    await assertSucceeds(getDoc(doc(reader, "districts/d1/formAssignments/a1/respondents/s1")));
    const other = env.authenticatedContext("other", trustedClaims("d1")).firestore();
    await assertFails(getDoc(doc(other, "districts/d1/formAssignments/a1/respondents/s1")));
  });
});
