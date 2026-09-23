import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import "../src/index.js";
import { canonicalFields } from "../src/forms.js";
import { mapLegacyAnswers, migrateLegacyFormSubmissions } from "../src/formMigration.js";
import { makeTestEnvironment } from "./testEnvironment.js";

const template = {
  name: "Check-in", version: 3, isScored: true,
  sections: [{ title: "Today", fields: [
    { label: "Mood", type: "dropdown", isRequired: true, options: ["Calm", "Busy"], optionPoints: [0, 2] },
    { label: "Notes", type: "longText", isRequired: false },
  ] }],
};

describe("legacy form submission migration", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();
  const fixed = Timestamp.fromMillis(Date.UTC(2026, 8, 1));

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1").set({ name: "Unified" });
    await db.doc("districts/d1/formTemplates/t1").set(template);
    await db.doc("districts/d1/formAssignments/a1").set({ templateId: "t1", studentIDs: ["s1", "s2", "s3"] });
    for (const id of ["s1", "s2", "s3"]) await db.doc(`districts/d1/students/${id}`).set({ schoolId: "school-1" });
    await db.doc("users/u1/formSubmissions/f1").set({
      formId: "t1", assignmentId: "a1", studentId: "s1", status: "reviewed", score: 99,
      data: { Mood: "Busy", notes: { value: "Rough morning" }, "Old question": "gone" },
      submissionDate: fixed, reviewedBy: "u2", reviewedAt: fixed, feedback: "Followed up",
    });
    await db.doc("users/u1/formSubmissions/f2").set({ assignmentId: "a1", studentId: "s2", status: "draft", data: { "s0-f1": "Draft note" } });
    await db.doc("users/u1/formSubmissions/f3").set({ assignmentId: "missing", studentId: "s1", status: "submitted", data: {} });
    await db.doc("users/u1/formSubmissions/f4").set({ assignmentId: "a1", studentId: "s3", status: "submitted", data: {} });
    await db.doc("districts/d1/formAssignments/a1/respondents/s3").set({ state: "submitted", answers: {} });
  });

  it("maps answers by key and label, keeping the rest", () => {
    const fields = canonicalFields(template);
    expect(mapLegacyAnswers(fields, { mood: "Calm", "s0-f1": "x", Extra: [1] }))
      .toEqual({ answers: { "s0-f0": "Calm", "s0-f1": "x" }, unmapped: { Extra: [1] } });
  });

  it("dry-runs, applies once, and never overwrites", async () => {
    const dry = await migrateLegacyFormSubmissions(db, { dryRun: true, now: () => fixed });
    expect(dry.counts).toEqual({ migrated: 2, alreadyMigrated: 0, conflict: 1, unresolved: 1 });
    expect((await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).exists).toBe(false);

    const applied = await migrateLegacyFormSubmissions(db, { dryRun: false, now: () => fixed });
    expect(applied.counts.migrated).toBe(2);
    const reviewed = (await db.doc("districts/d1/formAssignments/a1/respondents/s1").get()).data();
    expect(reviewed).toMatchObject({
      state: "reviewed",
      answers: { "s0-f0": "Busy", "s0-f1": "Rough morning" },
      scoring: { score: 2, maxScore: 2 },
      review: { comment: "Followed up", reviewedBy: "u2" },
      migration: { source: "users/u1/formSubmissions/f1", legacyScore: 99, unmappedAnswers: { "Old question": "gone" } },
    });
    const draft = (await db.doc("districts/d1/formAssignments/a1/respondents/s2").get()).data();
    expect(draft).toMatchObject({ state: "draft", answers: { "s0-f1": "Draft note" } });
    expect(draft).not.toHaveProperty("fields");

    const again = await migrateLegacyFormSubmissions(db, { dryRun: false, now: () => fixed });
    expect(again.counts).toEqual({ migrated: 0, alreadyMigrated: 2, conflict: 1, unresolved: 1 });
    expect((await db.doc("districts/d1/formAssignments/a1/respondents/s3").get()).data()).toEqual({ state: "submitted", answers: {} });
  });
});
