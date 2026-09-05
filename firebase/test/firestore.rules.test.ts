import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

describe("canonical Firestore authorization", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, "districts/d1/members/teacher-1"),
        activeMembership(),
      );
      await setDoc(
        doc(db, "districts/d1/members/inactive-1"),
        activeMembership({ isActive: false }),
      );
      await setDoc(
        doc(db, "districts/d1/members/admin-1"),
        activeMembership({
          role: "schoolAdministrator",
          capabilities: [],
          assignedStudentIDs: [],
        }),
      );
      await setDoc(
        doc(db, "districts/d1/members/district-admin-1"),
        activeMembership({
          role: "districtAdministrator",
          schoolIDs: [],
          capabilities: [],
          assignedStudentIDs: [],
        }),
      );
      await setDoc(doc(db, "districts/d1/students/student-1"), {
        districtId: "d1",
        schoolId: "school-1",
        assignedMemberIDs: ["teacher-1"],
        name: "Assigned Student",
      });
      await setDoc(doc(db, "districts/d1/students/student-2"), {
        districtId: "d1",
        schoolId: "school-1",
        assignedMemberIDs: [],
        name: "Unassigned Student",
      });
      await setDoc(doc(db, "districts/d2/students/student-3"), {
        districtId: "d2",
        schoolId: "school-2",
        assignedMemberIDs: [],
        name: "Other District Student",
      });
      await setDoc(doc(db, "districts/d1/plans/plan-unassigned"), {
        districtId: "d1",
        studentIDs: ["student-2"],
        schoolIDs: ["school-1"],
        assignedMemberIDs: [],
      });
      await setDoc(doc(db, "districts/d1/plans/plan-other-school"), {
        districtId: "d1",
        studentIDs: ["student-4"],
        schoolIDs: ["school-2"],
        assignedMemberIDs: [],
      });
      await setDoc(doc(db, "districts/d2/plans/plan-other-district"), {
        districtId: "d2",
        studentIDs: ["student-3"],
        schoolIDs: ["school-2"],
        assignedMemberIDs: [],
      });
      await setDoc(
        doc(db, "districts/d1/students/student-1/restrictedRecords/r1"),
        { category: "restricted" },
      );
      await setDoc(doc(db, "districts/d1/metricSnapshots/snapshot-1"), {
        schoolId: "school-1",
        activeStudents: 10,
      });
      await setDoc(doc(db, "catalogs/careers/items/career-1"), {
        title: "Engineer",
        isActive: true,
      });
      await setDoc(doc(db, "users/admin-1"), {
        displayName: "Admin User",
      });
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("allows only whitelisted personal profile changes", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();

    await assertSucceeds(
      setDoc(doc(db, "users/teacher-1/private/profile"), {
        displayName: "Taylor Teacher",
        photoURL: "https://example.org/avatar.png",
      }),
    );
    await assertFails(
      setDoc(doc(db, "users/teacher-1"), {
        displayName: "Taylor Teacher",
        role: "districtAdministrator",
      }),
    );
  });

  it("allows teachers to read every student in their school and denies cross-tenant reads", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();

    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-1")));
    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-2")));
    await assertFails(getDoc(doc(db, "districts/d2/students/student-3")));
  });

  it("allows school administrators to read their school without an extra read capability", async () => {
    const db = testEnv
      .authenticatedContext("admin-1", trustedClaims("d1"))
      .firestore();

    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-1")));
    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-2")));
  });

  it("allows teachers and school administrators to list unassigned plans in their school", async () => {
    for (const userID of ["teacher-1", "admin-1"]) {
      const db = testEnv
        .authenticatedContext(userID, trustedClaims("d1"))
        .firestore();
      const plans = collection(db, "districts/d1/plans");
      const snapshot = await assertSucceeds(
        getDocs(query(plans, where("schoolIDs", "==", ["school-1"]))),
      );

      expect(snapshot.docs.map((document) => document.id)).toContain("plan-unassigned");
      await assertFails(getDoc(doc(db, "districts/d1/plans/plan-other-school")));
      await assertFails(getDoc(doc(db, "districts/d2/plans/plan-other-district")));
    }
  });

  it("allows district administrators to list every plan in their district", async () => {
    const db = testEnv
      .authenticatedContext("district-admin-1", trustedClaims("d1"))
      .firestore();
    const snapshot = await assertSucceeds(getDocs(collection(db, "districts/d1/plans")));

    expect(snapshot.docs.map((document) => document.id).sort()).toEqual([
      "plan-other-school",
      "plan-unassigned",
    ]);
    await assertFails(getDoc(doc(db, "districts/d2/plans/plan-other-district")));
  });

  it("persists only scoped, versioned career relationships", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();
    const relationship = doc(
      db,
      "districts/d1/students/student-1/careers/technology--frontend-developer",
    );

    await assertSucceeds(
      setDoc(relationship, {
        districtID: "d1",
        studentID: "student-1",
        careerID: "technology--frontend-developer",
        isSaved: true,
        isDismissed: false,
        isCompared: false,
        linkedPlanIDs: [],
        lastViewedAt: serverTimestamp(),
        schemaVersion: 1,
        recordVersion: 1,
        createdAt: serverTimestamp(),
        createdBy: "teacher-1",
        updatedAt: serverTimestamp(),
        updatedBy: "teacher-1",
      }),
    );
    await assertSucceeds(
      updateDoc(relationship, {
        isSaved: false,
        isDismissed: true,
        recordVersion: 2,
        updatedAt: serverTimestamp(),
        updatedBy: "teacher-1",
      }),
    );
    await assertFails(
      updateDoc(relationship, {
        studentID: "student-2",
        recordVersion: 3,
        updatedAt: serverTimestamp(),
        updatedBy: "teacher-1",
      }),
    );
    await assertFails(
      updateDoc(relationship, {
        isSaved: true,
        isDismissed: true,
        recordVersion: 3,
        updatedAt: serverTimestamp(),
        updatedBy: "teacher-1",
      }),
    );
    await assertFails(
      updateDoc(relationship, {
        isSaved: true,
        isDismissed: false,
        recordVersion: 2,
        updatedAt: serverTimestamp(),
        updatedBy: "teacher-1",
      }),
    );
    await assertFails(
      setDoc(
        doc(
          db,
          "districts/d1/students/student-2/careers/technology--frontend-developer",
        ),
        {
          districtID: "d1",
          studentID: "student-2",
          careerID: "technology--frontend-developer",
          isSaved: true,
          isDismissed: false,
          isCompared: false,
          linkedPlanIDs: [],
          lastViewedAt: serverTimestamp(),
          schemaVersion: 1,
          recordVersion: 1,
          createdAt: serverTimestamp(),
          createdBy: "teacher-1",
          updatedAt: serverTimestamp(),
          updatedBy: "teacher-1",
        },
      ),
    );
    await assertFails(deleteDoc(relationship));
  });

  it("denies inactive and membership-version-mismatched sessions", async () => {
    const inactiveDB = testEnv
      .authenticatedContext("inactive-1", trustedClaims("d1"))
      .firestore();
    const staleDB = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1", 2))
      .firestore();

    await assertFails(getDoc(doc(inactiveDB, "districts/d1/students/student-1")));
    await assertFails(getDoc(doc(staleDB, "districts/d1/students/student-1")));
  });

  it("requires explicit capability for restricted records", async () => {
    const teacherDB = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();
    await assertFails(
      getDoc(
        doc(
          teacherDB,
          "districts/d1/students/student-1/restrictedRecords/r1",
        ),
      ),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "districts/d1/members/teacher-1"),
        { capabilities: ["student.restricted.read"] },
      );
    });
    await assertSucceeds(
      getDoc(
        doc(
          teacherDB,
          "districts/d1/students/student-1/restrictedRecords/r1",
        ),
      ),
    );
  });

  it("keeps administrator detail reads available when optional capabilities change", async () => {
    const adminDB = testEnv
      .authenticatedContext("admin-1", trustedClaims("d1"))
      .firestore();

    await assertSucceeds(getDoc(doc(adminDB, "districts/d1/students/student-2")));
    await assertSucceeds(
      getDoc(doc(adminDB, "districts/d1/metricSnapshots/snapshot-1")),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "districts/d1/members/admin-1"), {
        capabilities: [],
      });
    });
    await assertSucceeds(getDoc(doc(adminDB, "districts/d1/students/student-2")));
  });

  it("denies client membership, audit, metric, approval, and hard-delete writes", async () => {
    const db = testEnv
      .authenticatedContext("admin-1", trustedClaims("d1"))
      .firestore();

    await assertFails(
      updateDoc(doc(db, "districts/d1/members/admin-1"), { role: "districtAdministrator" }),
    );
    await assertFails(
      setDoc(doc(db, "districts/d1/auditEvents/event-1"), { action: "forged" }),
    );
    await assertFails(
      setDoc(doc(db, "districts/d1/metricSnapshots/snapshot-2"), { activeStudents: 11 }),
    );
    await assertFails(
      setDoc(doc(db, "districts/d1/plans/plan-1/approvals/a1"), { status: "approved" }),
    );
    await assertFails(
      deleteDoc(doc(db, "districts/d1/students/student-1")),
    );
    // Institution-owned records are never client-deletable. Personal data under
    // users/{uid} is the deliberate exception: the owner erases it during
    // account deletion, which no longer has a trusted callable to run.
    await assertFails(deleteDoc(doc(db, "users/someone-else")));
  });

  it("allows authenticated catalog reads but no client catalog writes", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();
    const anonymousDB = testEnv.unauthenticatedContext().firestore();
    const career = doc(db, "catalogs/careers/items/career-1");

    await assertSucceeds(getDoc(career));
    await assertFails(
      getDoc(doc(anonymousDB, "catalogs/careers/items/career-1")),
    );
    await assertFails(setDoc(doc(db, "catalogs/careers/items/career-2"), { title: "Nurse" }));
  });
});
