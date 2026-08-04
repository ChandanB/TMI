import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import type { CallableRequest } from "firebase-functions/v2/https";
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import { getFirestore } from "firebase-admin/firestore";
import {
  createStudentModeHandlers,
  type EndStudentModeSessionRequest,
  type IssueStudentModeSessionRequest,
  type RestoreStudentModeSessionRequest,
  type StudentModeRespondentClaims,
} from "../src/index.js";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const districtID = "d1";
const staffUserID = "teacher-1";
const studentID = "student-1";
const assignmentID = "assignment-1";

const callableRequest = <T>(
  data: T,
  options: {
    readonly uid?: string;
    readonly claims?: Record<string, unknown>;
    readonly includeAppCheck?: boolean;
    readonly includeAuth?: boolean;
  } = {},
): CallableRequest<T> => {
  const uid = options.uid ?? staffUserID;
  const request = {
    data,
    auth:
      options.includeAuth === false
        ? undefined
        : {
            uid,
            token: { uid, ...(options.claims ?? trustedClaims(districtID)) },
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

const issueRequest = (
  overrides: Partial<IssueStudentModeSessionRequest> = {},
): IssueStudentModeSessionRequest => ({
  districtID,
  studentID,
  assignmentIDs: [assignmentID],
  expectedRecordVersion: 1,
  idempotencyKey: "issue-session-1",
  reasonCode: "educator-launch",
  ...overrides,
});

const endRequest = (
  sessionID: string,
  overrides: Partial<EndStudentModeSessionRequest> = {},
): EndStudentModeSessionRequest => ({
  districtID,
  sessionID,
  disposition: "ended",
  expectedRecordVersion: 1,
  idempotencyKey: "end-session-1",
  reasonCode: "secure-exit",
  ...overrides,
});

const restoreRequest = (
  sessionID: string,
  overrides: Partial<RestoreStudentModeSessionRequest> = {},
): RestoreStudentModeSessionRequest => ({
  districtID,
  sessionID,
  ...overrides,
});

const expectHttpsError = async (
  promise: Promise<unknown>,
  code: string,
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code });
};

describe("Student Mode callable trust boundary", () => {
  let testEnv: RulesTestEnvironment;
  let issuedClaims: StudentModeRespondentClaims[] = [];
  let issuedUserIDs: string[] = [];

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    issuedClaims = [];
    issuedUserIDs = [];
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(
          doc(db, `districts/${districtID}/members/${staffUserID}`),
          activeMembership({
            districtID,
            capabilities: ["student.read.detail"],
            assignedStudentIDs: [studentID],
          }),
        ),
        setDoc(doc(db, `districts/${districtID}/students/${studentID}`), {
          districtId: districtID,
          schoolId: "school-1",
          displayName: "Student One",
          grade: "7",
          dateOfBirth: "private",
          assignedMemberIDs: [staffUserID],
          isArchived: false,
          recordVersion: 1,
        }),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/${studentID}/studentSafe/profile`,
          ),
          {
            schemaVersion: 0,
            districtID,
            studentID,
            displayName: "Stale name",
            dateOfBirth: "must-be-removed",
            restrictedData: { note: "must-be-removed" },
          },
        ),
        setDoc(
          doc(db, `districts/${districtID}/formAssignments/${assignmentID}`),
          {
            districtId: districtID,
            schoolId: "school-1",
            templateId: "template-1",
            assignmentType: "survey",
            isActive: true,
            studentIDs: [studentID],
            cohort: {
              type: "specificStudents",
              studentIds: [studentID],
              count: 1,
            },
          },
        ),
      ]);
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  const handlers = () =>
    createStudentModeHandlers({
      firestore: getFirestore(),
      createCustomToken: async (userID, claims) => {
        issuedUserIDs.push(userID);
        issuedClaims.push(claims);
        return `token:${userID}`;
      },
    });

  it("requires staff authentication and App Check", async () => {
    await expectHttpsError(
      handlers().issueSession(
        callableRequest(issueRequest(), { includeAuth: false }),
      ),
      "unauthenticated",
    );
    await expectHttpsError(
      handlers().issueSession(
        callableRequest(issueRequest(), { includeAppCheck: false }),
      ),
      "failed-precondition",
    );
    await expectHttpsError(
      handlers().issueSession(
        callableRequest(issueRequest({ districtID: "d2" })),
      ),
      "permission-denied",
    );
  });

  it("requires an active capability-bearing membership assigned to the student", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/members/${staffUserID}`,
        ),
        activeMembership({
          districtID,
          isActive: false,
          capabilities: ["student.read.detail"],
          assignedStudentIDs: [studentID],
        }),
      );
    });
    await expectHttpsError(
      handlers().issueSession(callableRequest(issueRequest())),
      "permission-denied",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/members/${staffUserID}`,
        ),
        activeMembership({
          districtID,
          capabilities: [],
          assignedStudentIDs: [studentID],
        }),
      );
    });
    await expectHttpsError(
      handlers().issueSession(callableRequest(issueRequest())),
      "permission-denied",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/members/${staffUserID}`,
        ),
        activeMembership({
          districtID,
          capabilities: ["student.read.detail"],
          assignedStudentIDs: [],
        }),
      );
    });
    await expectHttpsError(
      handlers().issueSession(callableRequest(issueRequest())),
      "permission-denied",
    );
  });

  it("rejects inactive cross-student and cross-district assignments", async () => {
    let invalidIndex = 0;
    for (const invalidAssignment of [
      { isActive: false, districtId: districtID, studentIDs: [studentID] },
      {
        isActive: true,
        districtId: districtID,
        studentIDs: ["student-2"],
        cohort: {
          type: "specificStudents",
          studentIds: ["student-2"],
          count: 1,
        },
      },
      { isActive: true, districtId: "d2", studentIDs: [studentID] },
    ]) {
      invalidIndex += 1;
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(
          doc(
            context.firestore(),
            `districts/${districtID}/formAssignments/${assignmentID}`,
          ),
          invalidAssignment,
        );
      });
      await expectHttpsError(
        handlers().issueSession(
          callableRequest(
            issueRequest({ idempotencyKey: `invalid-assignment-${invalidIndex}` }),
          ),
        ),
        "permission-denied",
      );
    }
  });

  it("rejects cohort-only assignments without an exact student projection", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/formAssignments/${assignmentID}`,
        ),
        {
          districtId: districtID,
          schoolId: "school-1",
          templateId: "template-1",
          assignmentType: "survey",
          isActive: true,
          cohort: { type: "allStudents" },
        },
      );
    });

    await expectHttpsError(
      handlers().issueSession(callableRequest(issueRequest())),
      "permission-denied",
    );
  });

  it("issues opaque least-privilege claims with default and capped duration", async () => {
    const first = await handlers().issueSession(
      callableRequest(issueRequest()),
    );
    const capped = await handlers().issueSession(
      callableRequest(
        issueRequest({
          durationMinutes: 99,
          idempotencyKey: "issue-session-2",
        }),
      ),
    );

    expect(first.sessionID).not.toBe("issue-session-1");
    expect(capped.sessionID).not.toBe("issue-session-2");
    expect(first.sessionID).not.toBe(capped.sessionID);
    expect(
      Date.parse(first.expiresAt) - Date.parse(first.issuedAt),
    ).toBe(30 * 60_000);
    expect(
      Date.parse(capped.expiresAt) - Date.parse(capped.issuedAt),
    ).toBe(60 * 60_000);
    expect(issuedUserIDs[0]).toMatch(/^studentMode_/u);
    expect(issuedClaims[0]).toMatchObject({
      tmiDistrictID: districtID,
      tmiAccessClass: "respondent",
      tmiStudentID: studentID,
      tmiSessionID: first.sessionID,
      tmiAssignmentIDs: [assignmentID],
    });
    expect(issuedClaims[0]?.tmiAllowedOperations).toEqual([
      "readStudentSafeProfile",
      "readAssignment",
      "writeDraft",
      "submitAssignment",
      "requestHelp",
    ]);
    expect(first.allowedOperations).toEqual(
      issuedClaims[0]?.tmiAllowedOperations,
    );
    expect(issuedClaims[0]).not.toHaveProperty("tmiMembershipVersion");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const session = await getDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${first.sessionID}`,
        ),
      );
      expect(session.data()).toMatchObject({
        districtID,
        studentID,
        assignmentIDs: [assignmentID],
        educatorUserID: staffUserID,
        respondentUserID: issuedUserIDs[0],
        status: "active",
      });
      const safeProfile = await getDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/students/${studentID}/studentSafe/profile`,
        ),
      );
      expect(safeProfile.data()).toEqual({
        schemaVersion: 1,
        districtID,
        studentID,
        displayName: "Student One",
        grade: "7",
      });
    });
  });

  it("restores an active issued session with only a safe profile and replacement token", async () => {
    const issued = await handlers().issueSession(
      callableRequest(issueRequest()),
    );

    const restored = await handlers().restoreSession(
      callableRequest(restoreRequest(issued.sessionID)),
    );

    expect(restored).toMatchObject({
      status: "active",
      sessionID: issued.sessionID,
      districtID,
      studentID,
      assignmentIDs: [assignmentID],
      allowedOperations: [
        "readStudentSafeProfile",
        "readAssignment",
        "writeDraft",
        "submitAssignment",
        "requestHelp",
      ],
      recordVersion: 1,
      profile: {
        studentID,
        displayName: "Student One",
        grade: "7",
      },
    });
    expect(restored.status).toBe("active");
    if (restored.status !== "active") {
      throw new Error("Expected an active restored Student Mode session.");
    }
    expect(restored.customToken).toMatch(/^token:studentMode_/u);
    expect(restored.profile).not.toHaveProperty("dateOfBirth");
    expect(restored.profile).not.toHaveProperty("restrictedData");
  });

  it("returns verified terminal state without a respondent token after expiry", async () => {
    const issued = await handlers().issueSession(
      callableRequest(issueRequest()),
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${issued.sessionID}`,
        ),
        { expiresAt: Timestamp.fromMillis(Date.now() - 1) },
      );
    });

    const restored = await handlers().restoreSession(
      callableRequest(restoreRequest(issued.sessionID)),
    );

    expect(restored).toMatchObject({
      status: "expired",
      sessionID: issued.sessionID,
      districtID,
      recordVersion: 1,
    });
    expect(restored).not.toHaveProperty("customToken");
    expect(restored).not.toHaveProperty("profile");
  });

  it("returns revoked instead of minting a token when the assignment type changes", async () => {
    const issued = await handlers().issueSession(
      callableRequest(issueRequest()),
    );
    const respondentUserID = issuedUserIDs.at(-1);
    const respondentClaims = issuedClaims.at(-1);
    if (respondentUserID === undefined || respondentClaims === undefined) {
      throw new Error("Expected issued respondent credentials.");
    }
    const safeProfilePath =
      `districts/${districtID}/students/${studentID}/studentSafe/profile`;
    const respondentDB = testEnv
      .authenticatedContext(respondentUserID, respondentClaims)
      .firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/formAssignments/${assignmentID}`,
        ),
        { assignmentType: "careerExploration" },
      );
    });
    await assertSucceeds(getDoc(doc(respondentDB, safeProfilePath)));

    const [restored, concurrentRestore] = await Promise.all([
      handlers().restoreSession(
        callableRequest(restoreRequest(issued.sessionID)),
      ),
      handlers().restoreSession(
        callableRequest(restoreRequest(issued.sessionID)),
      ),
    ]);

    for (const result of [restored, concurrentRestore]) {
      expect(result).toMatchObject({
        status: "revoked",
        sessionID: issued.sessionID,
        districtID,
        recordVersion: 2,
      });
    }
    expect(restored).not.toHaveProperty("customToken");
    expect(restored).not.toHaveProperty("profile");
    await assertFails(getDoc(doc(respondentDB, safeProfilePath)));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const revoked = await getDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${issued.sessionID}`,
        ),
      );
      expect(revoked.data()).toMatchObject({
        status: "revoked",
        recordVersion: 2,
        endedBy: staffUserID,
        updatedBy: staffUserID,
        revocationReason: "assignment-no-longer-eligible",
      });
      expect(revoked.get("endedAt")).toBeInstanceOf(Timestamp);
      expect(revoked.get("updatedAt")).toBeInstanceOf(Timestamp);
    });
  });

  it("denies restoration by a different staff identity", async () => {
    const issued = await handlers().issueSession(
      callableRequest(issueRequest()),
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `districts/${districtID}/members/teacher-2`),
        activeMembership({
          districtID,
          capabilities: ["student.read.detail"],
          assignedStudentIDs: [studentID],
        }),
      );
    });

    await expectHttpsError(
      handlers().restoreSession(
        callableRequest(restoreRequest(issued.sessionID), {
          uid: "teacher-2",
        }),
      ),
      "permission-denied",
    );
  });

  it("ends or revokes an issued session and rejects later mutations", async () => {
    const issued = await handlers().issueSession(
      callableRequest(issueRequest()),
    );
    const ended = await handlers().endSession(
      callableRequest(endRequest(issued.sessionID)),
    );
    expect(ended).toMatchObject({
      sessionID: issued.sessionID,
      ended: true,
      disposition: "ended",
    });
    await expectHttpsError(
      handlers().issueSession(callableRequest(issueRequest())),
      "failed-precondition",
    );

    const revokedIssue = await handlers().issueSession(
      callableRequest(
        issueRequest({ idempotencyKey: "issue-session-revoke" }),
      ),
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `districts/${districtID}/members/admin-1`),
        activeMembership({
          districtID,
          role: "schoolAdministrator",
          capabilities: ["student.read.detail", "staff.manage"],
          assignedStudentIDs: [],
        }),
      );
    });
    await handlers().endSession(
      callableRequest(
        endRequest(revokedIssue.sessionID, {
          disposition: "revoked",
          idempotencyKey: "revoke-session-1",
        }),
        { uid: "admin-1" },
      ),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const revoked = await getDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${revokedIssue.sessionID}`,
        ),
      );
      expect(revoked.data()).toMatchObject({
        status: "revoked",
        endedBy: "admin-1",
      });
    });
  });
});

describe("Student Mode respondent Firestore and Storage boundary", () => {
  let testEnv: RulesTestEnvironment;
  const sessionID = "opaque-session-1";
  const respondentUserID = "respondent-1";
  const allowedOperations = [
    "readStudentSafeProfile",
    "readAssignment",
    "readCareerCatalog",
    "readStudentVisiblePlan",
    "writeDraft",
    "submitAssignment",
    "updateInterests",
    "writeReflection",
    "writeCheckIn",
    "updateCareerState",
    "requestHelp",
  ];

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const activeSession = {
        districtID,
        studentID,
        assignmentIDs: [assignmentID],
        allowedOperations,
        respondentUserID,
        educatorUserID: staffUserID,
        status: "active",
        expiresAt: Timestamp.fromMillis(Date.now() + 30 * 60_000),
      };
      await Promise.all([
        setDoc(
          doc(
            db,
            `districts/${districtID}/studentModeSessions/${sessionID}`,
          ),
          activeSession,
        ),
        setDoc(doc(db, `districts/${districtID}/students/${studentID}`), {
          districtId: districtID,
          displayName: "Restricted full record",
          dateOfBirth: "private",
        }),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/${studentID}/studentSafe/profile`,
          ),
          { districtID, studentID, displayName: "Student-safe name" },
        ),
        setDoc(
          doc(db, `districts/${districtID}/formAssignments/${assignmentID}`),
          {
            districtId: districtID,
            studentIDs: [studentID],
            templateId: "template-1",
            isActive: true,
          },
        ),
        setDoc(
          doc(db, `districts/${districtID}/formTemplates/template-1`),
          { districtId: districtID, title: "Student survey" },
        ),
        setDoc(doc(db, "catalogs/careers/items/career-1"), {
          title: "Engineer",
          isApproved: true,
        }),
        setDoc(doc(db, `districts/${districtID}/plans/plan-1`), {
          districtId: districtID,
          studentIDs: [studentID],
        }),
        setDoc(
          doc(db, `districts/${districtID}/plans/plan-1/goals/goal-1`),
          { studentVisible: true, title: "Visible goal" },
        ),
        setDoc(
          doc(db, `districts/${districtID}/plans/plan-1/forms/form-1`),
          { studentVisible: true, title: "Unassigned plan form" },
        ),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/${studentID}/resources/resource-1`,
          ),
          { studentVisible: true, title: "Visible resource" },
        ),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/${studentID}/notes/note-1`,
          ),
          { text: "staff note" },
        ),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/${studentID}/restrictedRecords/restricted-1`,
          ),
          { text: "restricted" },
        ),
        setDoc(doc(db, `districts/${districtID}/auditEvents/audit-1`), {
          actorUserID: staffUserID,
        }),
        setDoc(
          doc(db, `districts/${districtID}/plans/plan-1/approvals/approval-1`),
          { approvedBy: staffUserID },
        ),
        setDoc(doc(db, `districts/${districtID}/members/${staffUserID}`), {
          role: "teacher",
        }),
        setDoc(doc(db, `districts/${districtID}/schools/school-1`), {
          name: "School",
        }),
        setDoc(doc(db, `districts/${districtID}/tasks/task-1`), {
          createdBy: staffUserID,
        }),
        setDoc(doc(db, `users/${respondentUserID}`), {
          displayName: "Synthetic respondent",
        }),
        setDoc(doc(db, `users/${respondentUserID}/private/profile`), {
          dateOfBirth: "private",
        }),
        setDoc(doc(db, `users/${respondentUserID}/preferences/settings`), {
          notifications: true,
        }),
        setDoc(
          doc(db, `districts/${districtID}/formAssignments/assignment-2`),
          { districtId: districtID, studentIDs: [studentID], isActive: true },
        ),
        setDoc(
          doc(
            db,
            `districts/${districtID}/students/student-2/studentSafe/profile`,
          ),
          { districtID, studentID: "student-2" },
        ),
        uploadBytes(
          ref(
            context.storage(),
            `users/${respondentUserID}/profile/avatar.jpg`,
          ),
          new Uint8Array([1]),
          { contentType: "image/jpeg" },
        ),
        uploadBytes(
          ref(context.storage(), "catalogs/careers/career-1/image.png"),
          new Uint8Array([2]),
          { contentType: "image/png" },
        ),
      ]);
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  const respondentContext = (
    claimOverrides: Record<string, unknown> = {},
  ) =>
    testEnv.authenticatedContext(respondentUserID, {
      tmiDistrictID: districtID,
      tmiAccessClass: "respondent",
      tmiStudentID: studentID,
      tmiSessionID: sessionID,
      tmiAssignmentIDs: [assignmentID],
      tmiAllowedOperations: allowedOperations,
      ...claimOverrides,
    });

  it("reads only student-safe assigned and approved content", async () => {
    const db = respondentContext().firestore();
    for (const path of [
      `districts/${districtID}/students/${studentID}/studentSafe/profile`,
      `districts/${districtID}/formAssignments/${assignmentID}`,
      `districts/${districtID}/formTemplates/template-1`,
      "catalogs/careers/items/career-1",
      `districts/${districtID}/plans/plan-1/goals/goal-1`,
      `districts/${districtID}/students/${studentID}/resources/resource-1`,
    ]) {
      await assertSucceeds(getDoc(doc(db, path)));
    }
  });

  it("writes scoped non-survey state while survey history stays trusted", async () => {
    const db = respondentContext().firestore();
    const scopedFields = {
      districtID,
      studentID,
      respondentSessionID: sessionID,
    };
    const writes: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
      [
        `districts/${districtID}/students/${studentID}/interests/interest-1`,
        { ...scopedFields, interestID: "career-tech" },
      ],
      [
        `districts/${districtID}/students/${studentID}/reflections/reflection-1`,
        { ...scopedFields, text: "I learned something." },
      ],
      [
        `districts/${districtID}/students/${studentID}/checkIns/check-in-1`,
        { ...scopedFields, value: 4 },
      ],
      [
        `districts/${districtID}/students/${studentID}/careers/career-1`,
        { ...scopedFields, careerID: "career-1", state: "saved" },
      ],
      [
        `districts/${districtID}/students/${studentID}/helpRequests/help-1`,
        { ...scopedFields, message: "I need help." },
      ],
    ];
    for (const [path, data] of writes) {
      await assertSucceeds(setDoc(doc(db, path), data));
    }
    await assertFails(
      setDoc(
        doc(
          db,
          `districts/${districtID}/students/${studentID}/responses/response-1`,
        ),
        {
          ...scopedFields,
          assignmentID,
          state: "draft",
          answers: { q1: "answer" },
        },
      ),
    );
  });

  it("allows the exact survey operation set and denies unrelated purposes", async () => {
    const surveyOperations = [
      "readStudentSafeProfile",
      "readAssignment",
      "writeDraft",
      "submitAssignment",
      "requestHelp",
    ];
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${sessionID}`,
        ),
        { allowedOperations: surveyOperations },
      );
    });
    const db = respondentContext({
      tmiAllowedOperations: surveyOperations,
    }).firestore();
    await assertSucceeds(
      getDoc(
        doc(
          db,
          `districts/${districtID}/students/${studentID}/studentSafe/profile`,
        ),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(db, `districts/${districtID}/formAssignments/${assignmentID}`),
      ),
    );
    await assertFails(
      setDoc(
        doc(
          db,
          `districts/${districtID}/students/${studentID}/responses/survey-only`,
        ),
        {
          districtID,
          studentID,
          respondentSessionID: sessionID,
          assignmentID,
          status: "draft",
          answers: {},
        },
      ),
    );
    await assertFails(getDoc(doc(db, "catalogs/careers/items/career-1")));
    await assertFails(
      getDoc(doc(db, `districts/${districtID}/plans/plan-1/goals/goal-1`)),
    );
    await assertFails(
      setDoc(
        doc(
          db,
          `districts/${districtID}/students/${studentID}/interests/not-survey`,
        ),
        {
          districtID,
          studentID,
          respondentSessionID: sessionID,
          interestID: "career-tech",
        },
      ),
    );
  });

  it("denies every direct survey response lifecycle mutation", async () => {
    const db = respondentContext().firestore();
    const response = doc(
      db,
      `districts/${districtID}/students/${studentID}/responses/immutable`,
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(
        context.firestore(),
        `districts/${districtID}/students/${studentID}/responses/immutable`,
      ), {
        districtID,
        studentID,
        respondentSessionID: sessionID,
        assignmentID,
        attemptID: "immutable",
        state: "submitted",
        answers: { q1: "first" },
      });
    });
    await assertSucceeds(getDoc(response));
    await assertFails(updateDoc(response, { answers: { q1: "mutated" } }));
    await assertFails(updateDoc(response, { state: "draft" }));
  });

  it("denies every staff-only read class and cross-scope read", async () => {
    const db = respondentContext().firestore();
    for (const path of [
      `districts/${districtID}/students/${studentID}`,
      `districts/${districtID}/students/${studentID}/notes/note-1`,
      `districts/${districtID}/students/${studentID}/restrictedRecords/restricted-1`,
      `districts/${districtID}/auditEvents/audit-1`,
      `districts/${districtID}/plans/plan-1/approvals/approval-1`,
      `districts/${districtID}/plans/plan-1/forms/form-1`,
      `districts/${districtID}/members/${staffUserID}`,
      `districts/${districtID}/schools/school-1`,
      `districts/${districtID}/tasks/task-1`,
      `districts/${districtID}/formAssignments/assignment-2`,
      `districts/${districtID}/students/student-2/studentSafe/profile`,
      "districts/d2/students/student-1/studentSafe/profile",
      `users/${respondentUserID}`,
      `users/${respondentUserID}/private/profile`,
      `users/${respondentUserID}/preferences/settings`,
    ]) {
      await assertFails(getDoc(doc(db, path)));
    }
  });

  it("requires the assignment to remain active for every respondent operation", async () => {
    const readPaths = [
      `districts/${districtID}/students/${studentID}/studentSafe/profile`,
      "catalogs/careers/items/career-1",
      `districts/${districtID}/plans/plan-1/goals/goal-1`,
    ];
    const writePath =
      `districts/${districtID}/students/${studentID}/interests/post-lock-interest`;
    const writeData = {
      districtID,
      studentID,
      respondentSessionID: sessionID,
      interestID: "career-tech",
    };

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/formAssignments/${assignmentID}`,
        ),
        { isActive: false },
      );
    });
    for (const path of readPaths) {
      await assertFails(getDoc(doc(respondentContext().firestore(), path)));
    }
    await assertFails(
      setDoc(doc(respondentContext().firestore(), writePath), writeData),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/formAssignments/${assignmentID}`,
        ),
      );
    });
    for (const path of readPaths) {
      await assertFails(getDoc(doc(respondentContext().firestore(), path)));
    }
    await assertFails(
      setDoc(doc(respondentContext().firestore(), writePath), writeData),
    );
  });

  it("denies forbidden and cross-student writes", async () => {
    const db = respondentContext().firestore();
    for (const [path, data] of [
      [
        `districts/${districtID}/students/${studentID}/notes/new-note`,
        { districtID, studentID, text: "not allowed" },
      ],
      [
        `districts/${districtID}/students/${studentID}/restrictedRecords/new-record`,
        { districtID, studentID, text: "not allowed" },
      ],
      [
        `districts/${districtID}/auditEvents/new-audit`,
        { districtID, studentID },
      ],
      [
        `districts/${districtID}/plans/plan-1/approvals/new-approval`,
        { districtID, studentID },
      ],
      [
        `districts/${districtID}/students/student-2/interests/interest-1`,
        {
          districtID,
          studentID: "student-2",
          respondentSessionID: sessionID,
        },
      ],
      [
        `districts/${districtID}/students/${studentID}/responses/response-2`,
        {
          districtID,
          studentID,
          respondentSessionID: sessionID,
          assignmentID: "assignment-2",
          status: "draft",
        },
      ],
    ] as const) {
      await assertFails(setDoc(doc(db, path), data));
    }
  });

  it("denies expired revoked malformed and wrong-user sessions", async () => {
    const safePath =
      `districts/${districtID}/students/${studentID}/studentSafe/profile`;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${sessionID}`,
        ),
        { status: "revoked" },
      );
    });
    await assertFails(getDoc(doc(respondentContext().firestore(), safePath)));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          `districts/${districtID}/studentModeSessions/${sessionID}`,
        ),
        {
          status: "active",
          expiresAt: Timestamp.fromMillis(Date.now() - 1),
        },
      );
    });
    await assertFails(getDoc(doc(respondentContext().firestore(), safePath)));
    await assertFails(
      getDoc(
        doc(
          respondentContext({ tmiAssignmentIDs: ["assignment-2"] })
            .firestore(),
          safePath,
        ),
      ),
    );
    await assertFails(
      getDoc(
        doc(
          testEnv
            .authenticatedContext("different-user", {
              tmiDistrictID: districtID,
              tmiAccessClass: "respondent",
              tmiStudentID: studentID,
              tmiSessionID: sessionID,
              tmiAssignmentIDs: [assignmentID],
              tmiAllowedOperations: allowedOperations,
            })
            .firestore(),
          safePath,
        ),
      ),
    );
  });

  it("denies respondent access everywhere in Storage", async () => {
    const storage = respondentContext().storage();
    for (const path of [
      `districts/${districtID}/students/${studentID}/files/file.txt`,
      `users/${respondentUserID}/profile/avatar.jpg`,
      "catalogs/careers/career-1/image.png",
    ]) {
      const file = ref(storage, path);
      await assertFails(uploadBytes(file, new Uint8Array([1, 2, 3])));
      await assertFails(getBytes(file));
    }
  });
});
