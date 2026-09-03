import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, setDoc, getDoc, updateDoc } from "firebase/firestore";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const districtID = "d1";
const schoolID = "school-1";

/**
 * Direct client writes replace the Cloud Functions callables while the project
 * cannot deploy Functions. These tests pin the authorization boundary that
 * makes that safe.
 */
describe("client-side canonical writes", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, `districts/${districtID}/members/teacher-1`),
        activeMembership({ assignedStudentIDs: [] }),
      );
      await setDoc(
        doc(db, `districts/${districtID}/members/teacher-2`),
        activeMembership({ assignedStudentIDs: [] }),
      );
      // A student belonging to teacher-2 only.
      await setDoc(doc(db, `districts/${districtID}/students/other-student`), {
        districtId: districtID,
        schoolId: schoolID,
        displayName: "Other Student",
        normalizedDisplayName: "other student",
        grade: "7",
        assignedMemberIDs: ["teacher-2"],
        isArchived: false,
        schemaVersion: 1,
        recordVersion: 1,
      });
    });
  });

  const teacherDb = (uid: string) =>
    testEnv
      .authenticatedContext(uid, trustedClaims(districtID))
      .firestore();

  const studentDoc = (overrides: Record<string, unknown> = {}) => ({
    districtId: districtID,
    schoolId: schoolID,
    displayName: "New Student",
    normalizedDisplayName: "new student",
    grade: "7",
    assignedMemberIDs: ["teacher-1"],
    isArchived: false,
    schemaVersion: 1,
    recordVersion: 1,
    ...overrides,
  });

  it("lets a teacher create a student that assigns them, then read it back", async () => {
    const db = teacherDb("teacher-1");
    const ref = doc(db, `districts/${districtID}/students/student-new`);

    await assertSucceeds(setDoc(ref, studentDoc()));
    await assertSucceeds(getDoc(ref));
  });

  it("rejects a create that does not assign the author", async () => {
    const db = teacherDb("teacher-1");
    await assertFails(
      setDoc(
        doc(db, `districts/${districtID}/students/student-new`),
        studentDoc({ assignedMemberIDs: ["teacher-2"] }),
      ),
    );
  });

  it("rejects a create outside the member's school", async () => {
    const db = teacherDb("teacher-1");
    await assertFails(
      setDoc(
        doc(db, `districts/${districtID}/students/student-new`),
        studentDoc({ schoolId: "school-elsewhere" }),
      ),
    );
  });

  it("rejects a create into another district", async () => {
    const db = teacherDb("teacher-1");
    await assertFails(
      setDoc(
        doc(db, `districts/${districtID}/students/student-new`),
        studentDoc({ districtId: "d2" }),
      ),
    );
  });

  it("does not let a teacher attach themselves to someone else's student", async () => {
    const db = teacherDb("teacher-1");
    await assertFails(
      updateDoc(doc(db, `districts/${districtID}/students/other-student`), {
        assignedMemberIDs: ["teacher-2", "teacher-1"],
        recordVersion: 2,
      }),
    );
  });

  it("does not let a teacher read a student that does not list them", async () => {
    const db = teacherDb("teacher-1");
    await assertFails(
      getDoc(doc(db, `districts/${districtID}/students/other-student`)),
    );
  });

  it("requires the record version to advance by exactly one", async () => {
    const db = teacherDb("teacher-1");
    const ref = doc(db, `districts/${districtID}/students/student-new`);
    await assertSucceeds(setDoc(ref, studentDoc()));

    await assertFails(updateDoc(ref, { grade: "8", recordVersion: 1 }));
    await assertFails(updateDoc(ref, { grade: "8", recordVersion: 4 }));
    await assertSucceeds(updateDoc(ref, { grade: "8", recordVersion: 2 }));
  });

  it("keeps districtId and creation metadata immutable", async () => {
    const db = teacherDb("teacher-1");
    const ref = doc(db, `districts/${districtID}/students/student-new`);
    await assertSucceeds(
      setDoc(ref, studentDoc({ createdBy: "teacher-1", createdAt: 1 })),
    );

    await assertFails(updateDoc(ref, { districtId: "d2", recordVersion: 2 }));
    await assertFails(updateDoc(ref, { createdBy: "teacher-2", recordVersion: 2 }));
  });

  it("never allows a client delete", async () => {
    const db = teacherDb("teacher-1");
    const ref = doc(db, `districts/${districtID}/students/student-new`);
    await assertSucceeds(setDoc(ref, studentDoc()));

    const { deleteDoc } = await import("firebase/firestore");
    await assertFails(deleteDoc(ref));
  });

  it("lets a teacher create and read a plan that assigns them", async () => {
    const db = teacherDb("teacher-1");
    const studentRef = doc(db, `districts/${districtID}/students/student-new`);
    await assertSucceeds(setDoc(studentRef, studentDoc()));

    const planRef = doc(db, `districts/${districtID}/plans/plan-1`);
    await assertSucceeds(
      setDoc(planRef, {
        districtId: districtID,
        studentIDs: ["student-new"],
        schoolIDs: [schoolID],
        assignedMemberIDs: ["teacher-1"],
        status: "draft",
        title: "Chase Your Space",
        createdBy: "teacher-1",
      }),
    );
    await assertSucceeds(getDoc(planRef));
  });

  it("does not let a teacher read a plan that does not list them", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `districts/${districtID}/plans/plan-other`),
        {
          districtId: districtID,
          studentIDs: ["other-student"],
          schoolIDs: [schoolID],
          assignedMemberIDs: ["teacher-2"],
          status: "draft",
          title: "Not Yours",
          createdBy: "teacher-2",
        },
      );
    });

    const db = teacherDb("teacher-1");
    await assertFails(
      getDoc(doc(db, `districts/${districtID}/plans/plan-other`)),
    );
  });

  describe("survey responses", () => {
    const attemptID = "attempt-1";

    const responseDoc = (overrides: Record<string, unknown> = {}) => ({
      schemaVersion: 1,
      responseID: attemptID,
      districtID,
      studentID: "student-new",
      assignmentID: "assignment-1",
      attemptID,
      definitionID: "interests",
      definitionVersion: 1,
      state: "draft",
      recordVersion: 1,
      answers: {},
      respondentUserID: "teacher-1",
      syncState: "synced",
      hasPendingChanges: false,
      ...overrides,
    });

    const seedStudent = async (db: ReturnType<typeof teacherDb>) => {
      await assertSucceeds(
        setDoc(doc(db, `districts/${districtID}/students/student-new`), studentDoc()),
      );
    };

    const responseRef = (db: ReturnType<typeof teacherDb>) =>
      doc(
        db,
        `districts/${districtID}/students/student-new/responses/${attemptID}`,
      );

    it("lets the assigned member start and advance a draft attempt", async () => {
      const db = teacherDb("teacher-1");
      await seedStudent(db);

      await assertSucceeds(setDoc(responseRef(db), responseDoc()));
      await assertSucceeds(
        updateDoc(responseRef(db), { answers: { q1: "a" }, recordVersion: 2 }),
      );
    });

    it("lets a draft be submitted but not resurrected afterwards", async () => {
      const db = teacherDb("teacher-1");
      await seedStudent(db);
      await assertSucceeds(setDoc(responseRef(db), responseDoc()));

      await assertSucceeds(
        updateDoc(responseRef(db), { state: "submitted", recordVersion: 2 }),
      );
      // Canonical history is append-forward only; a submitted attempt is closed
      // to the client.
      await assertFails(
        updateDoc(responseRef(db), { state: "draft", recordVersion: 3 }),
      );
      await assertFails(
        updateDoc(responseRef(db), { answers: { q1: "b" }, recordVersion: 3 }),
      );
    });

    it("rejects an attempt that does not start as a version 1 draft", async () => {
      const db = teacherDb("teacher-1");
      await seedStudent(db);

      await assertFails(
        setDoc(responseRef(db), responseDoc({ state: "submitted" })),
      );
      await assertFails(
        setDoc(responseRef(db), responseDoc({ recordVersion: 2 })),
      );
    });

    it("rejects an attempt whose identity does not match its path", async () => {
      const db = teacherDb("teacher-1");
      await seedStudent(db);

      await assertFails(
        setDoc(responseRef(db), responseDoc({ attemptID: "somewhere-else" })),
      );
      await assertFails(
        setDoc(responseRef(db), responseDoc({ studentID: "other-student" })),
      );
      await assertFails(
        setDoc(responseRef(db), responseDoc({ respondentUserID: "teacher-2" })),
      );
    });

    it("keeps attempt identity immutable across updates", async () => {
      const db = teacherDb("teacher-1");
      await seedStudent(db);
      await assertSucceeds(setDoc(responseRef(db), responseDoc()));

      await assertFails(
        updateDoc(responseRef(db), { definitionVersion: 2, recordVersion: 2 }),
      );
      await assertFails(
        updateDoc(responseRef(db), { respondentUserID: "teacher-2", recordVersion: 2 }),
      );
    });

    it("does not let a member write an attempt for a student they cannot write", async () => {
      const db = teacherDb("teacher-1");
      await assertFails(
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/other-student/responses/${attemptID}`,
          ),
          responseDoc({ studentID: "other-student" }),
        ),
      );
    });
  });
});
