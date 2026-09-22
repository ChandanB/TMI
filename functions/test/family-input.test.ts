import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import { doc, getDoc, setDoc } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { recordFamilyInput } from "../src/index.js";
import { createRecordFamilyInputHandler, familyInputFormID } from "../src/familyInput.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const handler = createRecordFamilyInputHandler(() => getFirestore());

const call = (data: Record<string, unknown>, uid = "caregiver") =>
  handler({
    data: {
      districtID: "d1",
      expectedRecordVersion: 0,
      idempotencyKey: "family-1",
      reasonCode: "family-intake",
      studentID: "child-1",
      formID: familyInputFormID,
      formVersion: 1,
      completedBy: "family",
      relationship: "Parent",
      answers: { favoriteThings: "Trucks and bath time", comfortsWhenUpset: "A song and a hug" },
      favoritePlayInterestIDs: ["vehicles", "water-sand"],
      ...data,
    },
    auth: { uid, token: { uid, ...trustedClaims("d1") } },
    app: { appId: "test-app" },
  } as unknown as CallableRequest<unknown>);

describe("family input", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1/members/caregiver").set(activeMembership({
      capabilities: ["student.read.detail", "student.write.detail"],
      assignedStudentIDs: ["child-1"],
    }));
    await db.doc("districts/d1/students/child-1").set({
      districtId: "d1", schoolId: "school-1", assignedMemberIDs: ["caregiver"], isArchived: false,
    });
  });

  it("exports the callable", () => {
    expect(recordFamilyInput.run).toBeTypeOf("function");
  });

  it("stores the family's answers immutably and audits without their words", async () => {
    await expect(call({})).resolves.toMatchObject({ operationID: "family-1" });
    const stored = (await db.doc("districts/d1/students/child-1/familyInputs/family-1").get()).data();
    expect(stored).toMatchObject({
      completedBy: "family",
      relationship: "Parent",
      answers: { favoriteThings: "Trucks and bath time" },
      favoritePlayInterestIDs: ["vehicles", "water-sand"],
      submittedBy: "caregiver",
    });
    const audit = JSON.stringify((await db.doc("districts/d1/auditEvents/family-1").get()).data());
    expect(audit).not.toContain("Trucks and bath time");
    expect(audit).toContain("student.familyInput.record");
  });

  it("rejects stale forms, unknown fields, empty input, and unknown interests", async () => {
    await expect(call({ formVersion: 2 })).rejects.toMatchObject({ code: "failed-precondition" });
    await expect(call({ answers: { diagnosis: "x" } })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(call({ answers: {}, favoritePlayInterestIDs: [] })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(call({ favoritePlayInterestIDs: ["crypto"] })).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("is readable by assigned staff and never writable by clients", async () => {
    await call({});
    const reader = env.authenticatedContext("caregiver", trustedClaims("d1")).firestore();
    await assertSucceeds(getDoc(doc(reader, "districts/d1/students/child-1/familyInputs/family-1")));
    await assertFails(setDoc(doc(reader, "districts/d1/students/child-1/familyInputs/forged"), { answers: {} }));
  });
});
