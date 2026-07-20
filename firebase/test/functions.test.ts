import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import {
  deletePersonalAccountData,
  grantStudentDetailAccess,
  issueStudentModeSession,
  mutateMembership,
  recordPrivilegedAuditEvent,
  requestSensitiveExport,
  transitionPlan,
  type TransitionPlanRequest,
} from "../src/index.js";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const callableRequest = <T>(
  data: T,
  options: {
    uid?: string;
    claims?: Record<string, unknown>;
    includeAppCheck?: boolean;
  } = {},
): CallableRequest<T> => {
  const uid = options.uid ?? "approver-1";
  const claims = options.claims ?? trustedClaims("d1");
  const request = {
    data,
    auth: {
      uid,
      token: { uid, ...claims },
      rawToken: "test-token",
    },
    app:
      options.includeAppCheck === false
        ? undefined
        : { appId: "test-app", token: { app_id: "test-app" } },
    rawRequest: {},
    acceptsStreaming: false,
  };

  return request as unknown as CallableRequest<T>;
};

const transitionRequest = (
  overrides: Partial<TransitionPlanRequest> = {},
): TransitionPlanRequest => ({
  districtID: "d1",
  planID: "plan-1",
  nextStatus: "approved",
  reasonCode: "plan-review-complete",
  expectedRecordVersion: 2,
  idempotencyKey: "transition-plan-1",
  ...overrides,
});

const expectHttpsError = async (
  promise: Promise<unknown>,
  code: string,
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code });
};

describe("privileged callable boundary", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, "districts/d1/members/approver-1"),
        activeMembership({
          role: "schoolAdministrator",
          capabilities: ["plan.approve"],
        }),
      );
      await setDoc(doc(db, "districts/d1/plans/plan-1"), {
        districtId: "d1",
        schoolId: "school-1",
        studentIDs: ["student-1"],
        status: "submitted",
        recordVersion: 2,
      });
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("exports every privileged operation as a callable", () => {
    for (const callable of [
      mutateMembership,
      grantStudentDetailAccess,
      transitionPlan,
      issueStudentModeSession,
      deletePersonalAccountData,
      requestSensitiveExport,
      recordPrivilegedAuditEvent,
    ]) {
      expect(callable.run).toBeTypeOf("function");
    }
  });

  it("requires verified Auth and App Check context", async () => {
    await expectHttpsError(
      transitionPlan.run(
        callableRequest(transitionRequest(), { includeAppCheck: false }),
      ),
      "failed-precondition",
    );

    const requestWithoutAuth = callableRequest(transitionRequest());
    delete (requestWithoutAuth as { auth?: unknown }).auth;
    await expectHttpsError(
      transitionPlan.run(requestWithoutAuth),
      "unauthenticated",
    );
  });

  it("rejects cross-district, stale, and malformed trusted claims", async () => {
    await expectHttpsError(
      transitionPlan.run(
        callableRequest(transitionRequest({ districtID: "d2" })),
      ),
      "permission-denied",
    );
    await expectHttpsError(
      transitionPlan.run(
        callableRequest(transitionRequest(), {
          claims: trustedClaims("d1", 2),
        }),
      ),
      "permission-denied",
    );
    await expectHttpsError(
      transitionPlan.run(
        callableRequest(transitionRequest(), {
          claims: {
            tmiDistrictID: "d1",
            tmiAccessClass: "administrator",
            tmiMembershipVersion: 1,
          },
        }),
      ),
      "permission-denied",
    );
  });

  it("rejects inactive memberships and missing capabilities", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "districts/d1/members/approver-1"),
        activeMembership({
          isActive: false,
          capabilities: ["plan.approve"],
        }),
      );
    });
    await expectHttpsError(
      transitionPlan.run(callableRequest(transitionRequest())),
      "permission-denied",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "districts/d1/members/approver-1"),
        activeMembership({ capabilities: [] }),
      );
    });
    await expectHttpsError(
      transitionPlan.run(callableRequest(transitionRequest())),
      "permission-denied",
    );
  });

  it("prevents a school administrator from capturing another school's member", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, "districts/d1/members/approver-1"),
        activeMembership({
          role: "schoolAdministrator",
          capabilities: ["staff.manage"],
        }),
      );
      await setDoc(doc(db, "districts/d1/members/teacher-2"), {
        ...activeMembership({
          schoolIDs: ["school-2"],
          assignedStudentIDs: [],
        }),
        recordVersion: 3,
        version: 3,
      });
    });

    await expectHttpsError(
      mutateMembership.run(
        callableRequest({
          districtID: "d1",
          targetUserID: "teacher-2",
          role: "teacher",
          schoolIDs: ["school-1"],
          capabilities: [],
          assignedStudentIDs: [],
          isActive: true,
          expectedRecordVersion: 3,
          idempotencyKey: "capture-other-school-member",
          reasonCode: "staff-reassignment",
        }),
      ),
      "permission-denied",
    );
  });

  it("rejects stale aggregate versions without mutating the record", async () => {
    await expectHttpsError(
      transitionPlan.run(
        callableRequest(transitionRequest({ expectedRecordVersion: 1 })),
      ),
      "aborted",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(
        doc(context.firestore(), "districts/d1/plans/plan-1"),
      );
      expect(snapshot.data()?.recordVersion).toBe(2);
      expect(snapshot.data()?.status).toBe("submitted");
    });
  });

  it("applies one audited transition and safely replays its idempotency key", async () => {
    const request = callableRequest(transitionRequest());
    const first = await transitionPlan.run(request);
    const replay = await transitionPlan.run(request);

    expect(first).toMatchObject({
      operationID: "transition-plan-1",
      recordVersion: 3,
      replayed: false,
    });
    expect(replay).toMatchObject({
      operationID: "transition-plan-1",
      recordVersion: 3,
      replayed: true,
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const plan = await getDoc(doc(db, "districts/d1/plans/plan-1"));
      const audit = await getDoc(
        doc(db, "districts/d1/auditEvents/transition-plan-1"),
      );
      expect(plan.data()?.recordVersion).toBe(3);
      expect(plan.data()?.status).toBe("approved");
      expect(audit.data()).toMatchObject({
        action: "plan.transition",
        actorUserID: "approver-1",
        targetPath: "districts/d1/plans/plan-1",
        reasonCode: "plan-review-complete",
        result: { recordVersion: 3 },
      });
    });
  });

  it("rejects reuse of an idempotency key for changed input", async () => {
    await transitionPlan.run(callableRequest(transitionRequest()));

    await expectHttpsError(
      transitionPlan.run(
        callableRequest(
          transitionRequest({ nextStatus: "changesRequested" }),
        ),
      ),
      "already-exists",
    );
  });
});
