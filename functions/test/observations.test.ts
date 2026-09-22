import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import { doc, getDoc } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { recordInterestObservation } from "../src/index.js";
import { createRecordInterestObservationHandler } from "../src/observations.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const handler = createRecordInterestObservationHandler(() => getFirestore());

const call = (data: Record<string, unknown>, uid = "caregiver") =>
  handler({
    data: {
      districtID: "d1",
      expectedRecordVersion: 0,
      idempotencyKey: "obs-1",
      reasonCode: "caregiver-observation",
      studentID: "child-1",
      observedInterestIDs: ["vehicles", "water-sand"],
      longestAttentionInterestID: "vehicles",
      engagement: 4,
      note: "Lined up cars and named colors.",
      ...data,
    },
    auth: { uid, token: { uid, ...trustedClaims("d1") } },
    app: { appId: "test-app" },
  } as unknown as CallableRequest<unknown>);

describe("caregiver interest observations", () => {
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
    await db.doc("districts/d1/members/viewer").set(activeMembership({
      capabilities: ["student.read.detail"],
      assignedStudentIDs: ["child-1"],
    }));
    await db.doc("districts/d1/students/child-1").set({
      districtId: "d1",
      schoolId: "school-1",
      assignedMemberIDs: ["caregiver", "viewer"],
      isArchived: false,
    });
  });

  it("exports the callable", () => {
    expect(recordInterestObservation.run).toBeTypeOf("function");
  });

  it("records an immutable observation and server-named interest edges", async () => {
    await expect(call({})).resolves.toMatchObject({ operationID: "obs-1", replayed: false });
    const observation = await db.doc("districts/d1/students/child-1/observations/obs-1").get();
    expect(observation.data()).toMatchObject({
      observedInterestIDs: ["vehicles", "water-sand"],
      longestAttentionInterestID: "vehicles",
      engagement: 4,
      observedBy: "caregiver",
    });
    const vehicles = (await db.doc("districts/d1/students/child-1/interests/vehicles").get()).data();
    expect(vehicles).toMatchObject({ name: "Trucks & vehicles", category: "Play", strength: 5, source: "staff" });
    const water = (await db.doc("districts/d1/students/child-1/interests/water-sand").get()).data();
    expect(water).toMatchObject({ strength: 3, sourceObservationId: "obs-1" });
    const audit = await db.doc("districts/d1/auditEvents/obs-1").get();
    expect(audit.data()).toMatchObject({ action: "student.interests.observe", actorUserID: "caregiver" });
  });

  it("replays idempotently and never lowers an existing strength", async () => {
    await call({});
    await expect(call({})).resolves.toMatchObject({ replayed: true });
    await call({ idempotencyKey: "obs-2", observedInterestIDs: ["vehicles"], longestAttentionInterestID: null });
    const vehicles = (await db.doc("districts/d1/students/child-1/interests/vehicles").get()).data();
    expect(vehicles?.strength).toBe(5);
    expect(vehicles?.mergeHistory).toHaveLength(2);
  });

  it("rejects unknown interests, non-zero versions, and read-only staff", async () => {
    await expect(call({ observedInterestIDs: ["crypto"] })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(call({ expectedRecordVersion: 1 })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(call({ idempotencyKey: "obs-3" }, "viewer")).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("lets assigned readers read observations but never write them", async () => {
    await call({});
    const reader = env.authenticatedContext("viewer", trustedClaims("d1")).firestore();
    await assertSucceeds(getDoc(doc(reader, "districts/d1/students/child-1/observations/obs-1")));
    const outsider = env.authenticatedContext("outsider", trustedClaims("d2")).firestore();
    await assertFails(getDoc(doc(outsider, "districts/d1/students/child-1/observations/obs-1")));
  });
});
