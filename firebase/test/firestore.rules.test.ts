import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
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
          capabilities: ["student.read.detail"],
          assignedStudentIDs: [],
        }),
      );
      await setDoc(doc(db, "districts/d1/students/student-1"), {
        districtId: "d1",
        schoolId: "school-1",
        name: "Assigned Student",
      });
      await setDoc(doc(db, "districts/d1/students/student-2"), {
        districtId: "d1",
        schoolId: "school-1",
        name: "Unassigned Student",
      });
      await setDoc(doc(db, "districts/d2/students/student-3"), {
        districtId: "d2",
        schoolId: "school-2",
        name: "Other District Student",
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

  it("allows assigned detail and denies unassigned or cross-tenant reads", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .firestore();

    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-1")));
    await assertFails(getDoc(doc(db, "districts/d1/students/student-2")));
    await assertFails(getDoc(doc(db, "districts/d2/students/student-3")));
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

  it("requires explicit administrator drill-down but permits scoped aggregate reads", async () => {
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
    await assertFails(getDoc(doc(adminDB, "districts/d1/students/student-2")));
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
    await assertFails(deleteDoc(doc(db, "users/admin-1")));
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
