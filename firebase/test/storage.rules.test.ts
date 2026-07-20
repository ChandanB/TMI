import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

describe("canonical Storage authorization", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "districts/d1/members/teacher-1"),
        activeMembership({ capabilities: ["report.export"] }),
      );
      await setDoc(
        doc(context.firestore(), "districts/d2/members/teacher-2"),
        activeMembership({
          schoolIDs: ["school-2"],
          assignedStudentIDs: ["student-2"],
        }),
      );
      await setDoc(
        doc(context.firestore(), "districts/d1/members/admin-1"),
        activeMembership({
          role: "schoolAdministrator",
          capabilities: ["student.read.detail"],
          assignedStudentIDs: [],
        }),
      );
      await setDoc(
        doc(context.firestore(), "districts/d1/members/exporter-2"),
        activeMembership({ capabilities: ["report.export"] }),
      );
      await setDoc(doc(context.firestore(), "districts/d1/students/student-1"), {
        districtId: "d1",
        schoolId: "school-1",
      });
      await setDoc(doc(context.firestore(), "districts/d1/students/student-4"), {
        districtId: "d1",
        schoolId: "school-2",
      });
      await setDoc(doc(context.firestore(), "districts/d2/students/student-2"), {
        districtId: "d2",
        schoolId: "school-2",
      });
      await setDoc(doc(context.firestore(), "districts/d1/tasks/export-1"), {
        type: "sensitiveExport",
        state: "ready",
        requestedBy: "teacher-1",
      });
      await uploadBytes(
        ref(context.storage(), "districts/d1/students/student-1/files/evidence.txt"),
        new Uint8Array([1]),
      );
      await uploadBytes(
        ref(context.storage(), "districts/d2/students/student-2/files/evidence.txt"),
        new Uint8Array([2]),
      );
      await uploadBytes(
        ref(context.storage(), "districts/d1/students/student-4/files/evidence.txt"),
        new Uint8Array([4]),
      );
      await uploadBytes(
        ref(context.storage(), "districts/d1/exports/export-1/report.pdf"),
        new Uint8Array([3]),
      );
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("allows a user to write only their canonical profile image path", async () => {
    const storage = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .storage();

    await assertSucceeds(
      uploadBytes(
        ref(storage, "users/teacher-1/profile/avatar.jpg"),
        new Uint8Array([1, 2, 3]),
        { contentType: "image/jpeg" },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storage, "users/other-user/profile/avatar.jpg"),
        new Uint8Array([1]),
        { contentType: "image/jpeg" },
      ),
    );
  });

  it("allows assigned student files and denies cross-tenant reads", async () => {
    const storage = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .storage();

    await assertSucceeds(
      getBytes(ref(storage, "districts/d1/students/student-1/files/evidence.txt")),
    );
    await assertFails(
      getBytes(ref(storage, "districts/d2/students/student-2/files/evidence.txt")),
    );
  });

  it("keeps school administrators inside their school boundary", async () => {
    const storage = testEnv
      .authenticatedContext("admin-1", trustedClaims("d1"))
      .storage();

    await assertSucceeds(
      getBytes(ref(storage, "districts/d1/students/student-1/files/evidence.txt")),
    );
    await assertFails(
      getBytes(ref(storage, "districts/d1/students/student-4/files/evidence.txt")),
    );
  });

  it("requires report export capability for sensitive exports", async () => {
    const allowedStorage = testEnv
      .authenticatedContext("teacher-1", trustedClaims("d1"))
      .storage();
    await assertSucceeds(
      getBytes(ref(allowedStorage, "districts/d1/exports/export-1/report.pdf")),
    );

    const otherExporterStorage = testEnv
      .authenticatedContext("exporter-2", trustedClaims("d1"))
      .storage();
    await assertFails(
      getBytes(ref(otherExporterStorage, "districts/d1/exports/export-1/report.pdf")),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "districts/d1/members/teacher-1"),
        activeMembership({ capabilities: [] }),
      );
    });
    await assertFails(
      getBytes(ref(allowedStorage, "districts/d1/exports/export-1/report.pdf")),
    );
  });
});
