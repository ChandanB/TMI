import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { deletePersonalAccountData } from "../src/index.js";
import {
  createDeletePersonalAccountDataHandler,
  personalAccountSubcollections,
  type DeletePersonalAccountDataRequest,
} from "../src/accountDeletion.js";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const now = new Date("2026-07-20T20:00:00.000Z");
const nowSeconds = Math.floor(now.getTime() / 1_000);

const retainedLegacyCollections = [
  "students",
  "plans",
  "tmiPlans",
  "formTemplates",
  "formAssignments",
  "formSubmissions",
  "meetings",
  "consents",
  "auditLogs",
] as const;

const canonicalInstitutionCollections = [
  "students",
  "plans",
  "formTemplates",
  "formAssignments",
  "formSubmissions",
  "meetings",
  "consents",
  "restrictedRecords",
  "auditLogs",
  "metricSnapshots",
] as const;

const deletionRequest = (
  overrides: Partial<DeletePersonalAccountDataRequest> = {},
  options: { readonly uid?: string; readonly authTime?: number } = {},
): CallableRequest<DeletePersonalAccountDataRequest> => {
  const uid = options.uid ?? "user-1";
  const data: DeletePersonalAccountDataRequest = {
    districtID: "d1",
    userID: "user-1",
    expectedRecordVersion: 4,
    idempotencyKey: "delete-operation-1",
    reasonCode: "user-requested-account-deletion",
    ...overrides,
  };
  return {
    data,
    auth: {
      uid,
      token: {
        uid,
        ...trustedClaims("d1"),
        auth_time: options.authTime ?? nowSeconds,
      },
      rawToken: "test-token",
    },
    app: { appId: "test-app", token: { app_id: "test-app" } },
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<DeletePersonalAccountDataRequest>;
};

describe("retention-safe personal account deletion", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
    expect(deletePersonalAccountData.run).toBeTypeOf("function");
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "districts/d1/members/user-1"), {
        ...activeMembership(),
        userID: "user-1",
        email: "educator@example.com",
        displayName: "Example Educator",
      });
      await setDoc(doc(db, "users/user-1"), {
        recordVersion: 4,
        email: "educator@example.com",
        displayName: "Example Educator",
      });

      for (const collectionName of personalAccountSubcollections) {
        await setDoc(
          doc(db, `users/user-1/${collectionName}/personal-record`),
          { ownerID: "user-1", personal: true },
        );
      }
      for (const collectionName of retainedLegacyCollections) {
        await setDoc(
          doc(db, `users/user-1/${collectionName}/institution-record`),
          { districtID: "d1", institutional: true },
        );
      }
      for (const collectionName of canonicalInstitutionCollections) {
        await setDoc(
          doc(db, `districts/d1/${collectionName}/institution-record`),
          { districtID: "d1", institutional: true },
        );
      }
      await setDoc(
        doc(db, "districts/d1/auditEvents/existing-institution-audit"),
        { districtID: "d1", institutional: true },
      );
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("is idempotent, deidentifies attribution, and preserves institution records", async () => {
    const firestore = getFirestore();
    const events: string[] = [];
    const handler = createDeletePersonalAccountDataHandler({
      firestore,
      now: () => now,
      deleteStoragePrefix: async (prefix) => {
        events.push(`storage:${prefix}`);
      },
      deleteAuthUser: async (userID) => {
        const [personalRoot, institutionRecord, audit] = await Promise.all([
          firestore.doc("users/user-1").get(),
          firestore.doc("districts/d1/students/institution-record").get(),
          firestore.doc("districts/d1/auditEvents/delete-operation-1").get(),
        ]);
        expect(personalRoot.exists).toBe(false);
        expect(institutionRecord.exists).toBe(true);
        expect(audit.exists).toBe(true);
        events.push(`auth:${userID}`);
      },
    });

    const first = await handler(deletionRequest());
    const replay = await handler(deletionRequest());

    expect(first).toMatchObject({
      operationID: "delete-operation-1",
      recordVersion: 5,
      replayed: false,
    });
    expect(replay).toMatchObject({
      operationID: "delete-operation-1",
      recordVersion: 5,
      replayed: true,
    });
    expect(events).toEqual([
      "storage:users/user-1/",
      "storage:profile_images/user-1/",
      "auth:user-1",
      "auth:user-1",
    ]);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      expect((await getDoc(doc(db, "users/user-1"))).exists()).toBe(false);
      for (const collectionName of personalAccountSubcollections) {
        expect(
          (
            await getDoc(
              doc(db, `users/user-1/${collectionName}/personal-record`),
            )
          ).exists(),
        ).toBe(false);
      }
      for (const collectionName of retainedLegacyCollections) {
        expect(
          (
            await getDoc(
              doc(db, `users/user-1/${collectionName}/institution-record`),
            )
          ).exists(),
        ).toBe(true);
      }
      for (const collectionName of canonicalInstitutionCollections) {
        expect(
          (
            await getDoc(
              doc(db, `districts/d1/${collectionName}/institution-record`),
            )
          ).exists(),
        ).toBe(true);
      }
      expect(
        (
          await getDoc(
            doc(db, "districts/d1/auditEvents/existing-institution-audit"),
          )
        ).exists(),
      ).toBe(true);

      const audit = (
        await getDoc(doc(db, "districts/d1/auditEvents/delete-operation-1"))
      ).data();
      const attributionID = audit?.actorAttributionID;
      expect(attributionID).toMatch(/^[a-f0-9]{64}$/);
      expect(audit).not.toHaveProperty("actorUserID");
      expect(JSON.stringify(audit)).not.toContain("user-1");
      expect(JSON.stringify(audit)).not.toContain("educator@example.com");

      const formerUser = (
        await getDoc(doc(db, `districts/d1/formerUsers/${attributionID}`))
      ).data();
      expect(formerUser).toMatchObject({
        kind: "formerUser",
        districtID: "d1",
        attributionID,
      });
      expect(JSON.stringify(formerUser)).not.toContain("user-1");
      expect(JSON.stringify(formerUser)).not.toContain("educator@example.com");

      const membership = (
        await getDoc(doc(db, "districts/d1/members/user-1"))
      ).data();
      expect(membership).toMatchObject({
        isActive: false,
        formerUserAttributionID: attributionID,
        role: "teacher",
      });
      expect(membership).not.toHaveProperty("userID");
      expect(membership).not.toHaveProperty("email");
      expect(membership).not.toHaveProperty("displayName");
    });
  });

  it("refuses a mismatched authenticated user without touching data", async () => {
    const externalCalls: string[] = [];
    const handler = createDeletePersonalAccountDataHandler({
      firestore: getFirestore(),
      now: () => now,
      deleteStoragePrefix: async (prefix) => {
        externalCalls.push(prefix);
      },
      deleteAuthUser: async (userID) => {
        externalCalls.push(userID);
      },
    });

    await expect(
      handler(deletionRequest({ userID: "different-user" })),
    ).rejects.toMatchObject({ code: "permission-denied" });
    expect(externalCalls).toEqual([]);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      expect(
        (await getDoc(doc(context.firestore(), "users/user-1"))).exists(),
      ).toBe(true);
      expect(
        (
          await getDoc(
            doc(
              context.firestore(),
              "districts/d1/students/institution-record",
            ),
          )
        ).exists(),
      ).toBe(true);
    });
  });

  it("requires recent reauthentication before cleanup begins", async () => {
    const externalCalls: string[] = [];
    const handler = createDeletePersonalAccountDataHandler({
      firestore: getFirestore(),
      now: () => now,
      deleteStoragePrefix: async (prefix) => {
        externalCalls.push(prefix);
      },
      deleteAuthUser: async (userID) => {
        externalCalls.push(userID);
      },
    });

    await expect(
      handler(deletionRequest({}, { authTime: nowSeconds - 11 * 60 })),
    ).rejects.toMatchObject({ code: "failed-precondition" });
    expect(externalCalls).toEqual([]);
  });
});
