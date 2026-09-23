import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { searchWorkspace } from "../src/index.js";
import { createSearchHandlers, normalizeQuery } from "../src/search.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const handlers = createSearchHandlers({
  firestore: () => getFirestore(),
  getUsers: async (ids) => ids.map((userID) => ({ userID, displayName: `Name ${userID}` })),
});
const call = <T>(data: T, uid = "teacher"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);

describe("workspace search", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1/members/teacher").set(activeMembership({ schoolIDs: ["school-1"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/members/counselor").set(activeMembership({ role: "counselor", schoolIDs: ["school-1"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/members/other").set(activeMembership({ schoolIDs: ["school-2"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/students/s1").set({ districtId: "d1", schoolId: "school-1", displayName: "Maya Thompson", normalizedDisplayName: "maya thompson", grade: "10" });
    await db.doc("districts/d1/students/s2").set({ districtId: "d1", schoolId: "school-2", displayName: "Maya Chen", normalizedDisplayName: "maya chen", grade: "8" });
    await db.doc("districts/d1/plans/p1").set({ title: "Align Your Mind — Maya Thompson", studentIDs: ["s1"], schoolIDs: ["school-1"], assignedMemberIDs: [], status: "active" });
    await db.doc("districts/d1/plans/p2").set({ title: "Chase Your Space — Maya Chen", studentIDs: ["s2"], schoolIDs: ["school-2"], assignedMemberIDs: [], status: "draft" });
    await db.doc("districts/d1/resources/r1").set({ title: "Calm breathing for Maya's class", category: "video" });
    await db.doc("districts/d1/resources/r2").set({ title: "Maya school-2 only", schoolId: "school-2" });
    await db.doc("catalogs/careers/items/c1").set({ title: "Marine Biologist", category: "Science", isApproved: true });
  });

  it("exports the callable", () => {
    expect(searchWorkspace.run).toBeTypeOf("function");
  });

  it("returns only records the caller can open", async () => {
    const result = await handlers.searchWorkspace(call({ districtID: "d1", query: "Maya" }));
    expect(result.students.map((item) => item.id)).toEqual(["s1"]);
    expect(result.plans.map((item) => item.id)).toEqual(["p1"]);
    expect(result.resources.map((item) => item.id)).toEqual(["r1"]);
  });

  it("limits counselors to assigned students and searches careers", async () => {
    const counselor = await handlers.searchWorkspace(call({ districtID: "d1", query: "maya" }, "counselor"));
    expect(counselor.students).toEqual([]);
    const careers = await handlers.searchWorkspace(call({ districtID: "d1", query: "marine" }));
    expect(careers.careers.map((item) => item.id)).toEqual(["c1"]);
    const noCareers = await handlers.searchWorkspace(call({ districtID: "d1", query: "marine", includeCareers: false }));
    expect(noCareers.careers).toEqual([]);
  });

  it("rejects too-short queries and normalizes accents", async () => {
    await expect(handlers.searchWorkspace(call({ districtID: "d1", query: "m" }))).rejects.toMatchObject({ code: "invalid-argument" });
    expect(normalizeQuery("  José  Núñez ")).toBe("jose nunez");
  });

  it("lists colleagues who can see a student", async () => {
    const all = await handlers.listColleagues(call({ districtID: "d1", studentID: "s1" }));
    expect(all.colleagues.map((item) => item.userID).sort()).toEqual(["counselor", "teacher"]);
    await expect(handlers.listColleagues(call({ districtID: "d1", studentID: "s2" }))).rejects.toMatchObject({ code: "permission-denied" });
  });
});
