import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} from "firebase/firestore";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const districtID = "d1";
const templatesPath = `districts/${districtID}/formTemplates`;

/**
 * Rules are not filters: a list query is allowed only when the rules hold
 * for every document it could return. A school-scoped teacher must not be
 * able to list another school's templates by leaving schoolId unconstrained.
 */
describe("form template library queries", () => {
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
        activeMembership({ schoolIDs: ["school-1"] }),
      );
      await setDoc(
        doc(db, `districts/${districtID}/members/admin-1`),
        activeMembership({ role: "districtAdministrator", schoolIDs: [] }),
      );
      const base = { districtId: districtID, sections: [], isActive: true };
      await setDoc(doc(db, `${templatesPath}/own-school`), {
        ...base, name: "Own school", schoolId: "school-1", isPublic: false, updatedAt: 3,
      });
      await setDoc(doc(db, `${templatesPath}/other-school`), {
        ...base, name: "Other school", schoolId: "school-2", isPublic: false, updatedAt: 2,
      });
      await setDoc(doc(db, `${templatesPath}/district-wide`), {
        ...base, name: "District wide", schoolId: null, isPublic: true, updatedAt: 1,
      });
    });
  });

  const dbFor = (uid: string) =>
    testEnv.authenticatedContext(uid, trustedClaims(districtID)).firestore();

  it("denies a teacher any listing that leaves schoolId unconstrained", async () => {
    const templates = collection(dbFor("teacher-1"), templatesPath);
    await assertFails(getDocs(query(
      templates,
      where("districtId", "==", districtID),
      orderBy("updatedAt", "desc"),
    )));
    await assertFails(getDocs(query(templates, where("isPublic", "==", true), orderBy("name"))));
    await assertFails(getDocs(query(templates, where("schoolId", "==", "school-2"))));
  });

  it("lets a teacher list their own school's and district-wide templates", async () => {
    const templates = collection(dbFor("teacher-1"), templatesPath);
    await assertSucceeds(getDocs(query(templates, where("schoolId", "==", "school-1"))));
    await assertSucceeds(getDocs(query(templates, where("schoolId", "==", null))));
    await assertSucceeds(getDocs(query(
      templates,
      where("isPublic", "==", true),
      where("schoolId", "==", null),
    )));
  });

  it("keeps direct reads scoped by school", async () => {
    const db = dbFor("teacher-1");
    await assertSucceeds(getDoc(doc(db, `${templatesPath}/own-school`)));
    await assertSucceeds(getDoc(doc(db, `${templatesPath}/district-wide`)));
    await assertFails(getDoc(doc(db, `${templatesPath}/other-school`)));
  });

  it("lets a district administrator list everything", async () => {
    const templates = collection(dbFor("admin-1"), templatesPath);
    await assertSucceeds(getDocs(query(
      templates,
      where("districtId", "==", districtID),
      orderBy("updatedAt", "desc"),
    )));
  });
});
