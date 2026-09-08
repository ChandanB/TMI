import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import { assertFails, assertSucceeds, type RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

describe("holistic collaboration review regressions", () => {
  let env: RulesTestEnvironment;
  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      await setDoc(doc(db, "districts/d1/members/staff"), activeMembership({
        role: "counselor", capabilities: ["student.read.detail", "student.write.detail"],
      }));
      await setDoc(doc(db, "districts/d1/members/other"), activeMembership({
        role: "counselor", assignedStudentIDs: [], capabilities: ["student.read.detail"],
      }));
      await setDoc(doc(db, "districts/d2/members/foreign"), activeMembership());
      await setDoc(doc(db, "districts/d1/students/student-1"), {
        districtId: "d1", schoolId: "school-1", assignedMemberIDs: ["staff"],
      });
      await setDoc(doc(db, "districts/d1/students/student-2"), {
        districtId: "d1", schoolId: "school-1", assignedMemberIDs: [],
      });
      await setDoc(doc(db, "districts/d1/plans/plan-1"), {
        districtId: "d1", schoolIDs: ["school-1"], studentIDs: ["student-1"],
        assignedMemberIDs: ["staff"], status: "draft",
      });
    });
  });

  it("meeting participants can create, query, and preserve access on full updates", async () => {
    const db = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    const ref = doc(db, "districts/d1/meetings/meeting-1");
    const data = { title: "Plan review", organizer: "staff", participants: [], participantUserIDs: ["staff"] };
    await assertSucceeds(setDoc(ref, data));
    await assertSucceeds(getDocs(query(collection(db, "districts/d1/meetings"), where("participantUserIDs", "array-contains", "staff"))));
    await assertSucceeds(setDoc(ref, { ...data, title: "Updated review" }));
    await assertFails(setDoc(ref, { title: "Drops visibility", organizer: "staff", participants: [] }));
    await assertFails(deleteDoc(ref));
    const other = env.authenticatedContext("other", trustedClaims("d1")).firestore();
    await assertFails(getDoc(doc(other, ref.path)));
    await assertFails(updateDoc(doc(other, ref.path), { participantUserIDs: ["other"] }));
  });

  it("meeting creation without the rule's participant identity is denied", async () => {
    const db = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    await assertFails(setDoc(doc(db, "districts/d1/meetings/missing"), { organizer: "staff", participants: [] }));
    const foreign = env.authenticatedContext("foreign", trustedClaims("d2")).firestore();
    await assertFails(setDoc(doc(foreign, "districts/d1/meetings/foreign"), { participantUserIDs: ["foreign"] }));
  });

  it.each(["draft", "changesRequested"])("plan resource linking is allowed in %s", async status => {
    await env.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), "districts/d1/plans/plan-1"), { status });
    });
    const db = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    await assertSucceeds(setDoc(doc(db, "districts/d1/plans/plan-1/resources/resource-1"), { planID: "plan-1", title: "Learning resource" }));
    await assertFails(setDoc(doc(db, "districts/d1/plans/plan-1/resources/missing-plan"), { title: "Missing scope" }));
  });

  it.each(["pendingApproval", "approved", "active", "paused", "completed", "archived"])("plan resource linking is denied in %s", async status => {
    await env.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), "districts/d1/plans/plan-1"), { status });
    });
    const db = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    await assertFails(setDoc(doc(db, "districts/d1/plans/plan-1/resources/resource-1"), { planID: "plan-1" }));
  });

  it("recommendation writes require collaboration on both old and new students", async () => {
    const db = env.authenticatedContext("staff", trustedClaims("d1")).firestore();
    const ref = doc(db, "districts/d1/recommendations/rec-1");
    await assertSucceeds(setDoc(ref, { studentId: "student-1", title: "Explore a project" }));
    await assertSucceeds(getDocs(query(collection(db, "districts/d1/recommendations"), where("studentId", "==", "student-1"))));
    await assertSucceeds(updateDoc(ref, { title: "Review the project" }));
    await assertFails(updateDoc(ref, { studentId: "student-2" }));
    const other = env.authenticatedContext("other", trustedClaims("d1")).firestore();
    await assertFails(getDoc(doc(other, ref.path)));
    await assertFails(setDoc(doc(other, "districts/d1/recommendations/new"), { studentId: "student-1" }));
    await assertFails(updateDoc(doc(other, ref.path), { studentId: "student-2" }));
    await assertFails(deleteDoc(doc(other, ref.path)));
    await assertSucceeds(deleteDoc(ref));
  });
});
