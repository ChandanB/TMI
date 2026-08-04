import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import type { CallableRequest } from "firebase-functions/v2/https";
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { getFirestore } from "firebase-admin/firestore";
import {
  createSurveyHandlers,
  type ReviewSurveyResponseRequest,
  type SaveSurveyDraftRequest,
  type SubmitSurveyResponseRequest,
} from "../src/index.js";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const districtID = "d1";
const studentID = "student-1";
const assignmentID = "assignment-1";
const attemptID = "attempt-1";
const definitionID = "interest-discovery";
const definitionVersion = 3;
const sessionID = "session-1";
const respondentUserID = "respondent-1";
const staffUserID = "teacher-1";

const completeAnswers = {
  single: { type: "single", value: "art" },
  multiple: { type: "multiple", value: ["drawing"] },
  text: { type: "text", value: "Art club" },
  rating: { type: "rating", value: 4 },
  image: { type: "image", value: "city" },
} as const;

const definition = {
  schemaVersion: 1,
  definitionID,
  version: definitionVersion,
  state: "published",
  title: "Interest discovery",
  questions: [
    {
      id: "single",
      type: "singleChoice",
      required: true,
      options: [{ id: "science" }, { id: "art" }],
    },
    {
      id: "multiple",
      type: "multiSelect",
      required: true,
      maxSelections: 2,
      options: [{ id: "building" }, { id: "drawing" }],
    },
    {
      id: "text",
      type: "shortText",
      required: true,
      maxLength: 120,
      options: [],
    },
    {
      id: "rating",
      type: "rating",
      required: true,
      minimum: 1,
      maximum: 5,
      options: [],
    },
    {
      id: "image",
      type: "imageChoice",
      required: true,
      options: [{ id: "forest" }, { id: "city" }],
    },
  ],
  branchRules: [],
};

const callableRequest = <T>(
  data: T,
  options: {
    readonly respondent?: boolean;
    readonly uid?: string;
    readonly claims?: Record<string, unknown>;
    readonly includeAuth?: boolean;
    readonly includeAppCheck?: boolean;
  } = {},
): CallableRequest<T> => {
  const respondent = options.respondent ?? false;
  const uid = options.uid ?? (respondent ? respondentUserID : staffUserID);
  const defaultClaims = respondent
    ? {
        tmiDistrictID: districtID,
        tmiAccessClass: "respondent",
        tmiStudentID: studentID,
        tmiSessionID: sessionID,
        tmiAssignmentIDs: [assignmentID],
        tmiAllowedOperations: [
          "readStudentSafeProfile",
          "readAssignment",
          "writeDraft",
          "submitAssignment",
          "requestHelp",
        ],
      }
    : trustedClaims(districtID);
  return {
    data,
    auth:
      options.includeAuth === false
        ? undefined
        : {
            uid,
            token: { uid, ...defaultClaims, ...options.claims },
            rawToken: "test-token",
          },
    app:
      options.includeAppCheck === false
        ? undefined
        : { appId: "test-app", token: { app_id: "test-app" } },
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<T>;
};

const saveRequest = (
  overrides: Partial<SaveSurveyDraftRequest> = {},
): SaveSurveyDraftRequest => ({
  districtID,
  studentID,
  assignmentID,
  attemptID,
  definitionID,
  definitionVersion,
  expectedRecordVersion: 0,
  operationID: "save-1",
  answers: completeAnswers,
  ...overrides,
});

const submitRequest = (
  overrides: Partial<SubmitSurveyResponseRequest> = {},
): SubmitSurveyResponseRequest => ({
  districtID,
  studentID,
  assignmentID,
  attemptID,
  definitionID,
  definitionVersion,
  expectedRecordVersion: 1,
  operationID: "submit-1",
  answers: completeAnswers,
  ...overrides,
});

const reviewRequest = (
  overrides: Partial<ReviewSurveyResponseRequest> = {},
): ReviewSurveyResponseRequest => ({
  districtID,
  studentID,
  responseID: attemptID,
  expectedRecordVersion: 2,
  idempotencyKey: "review-1",
  reasonCode: "educator-review",
  ...overrides,
});

const expectHttpsError = async (
  promise: Promise<unknown>,
  code: string,
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code });
};

describe("Canonical survey transactions", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(doc(db, `districts/${districtID}/members/${staffUserID}`),
          activeMembership({
            districtID,
            capabilities: ["student.read.detail", "student.write.detail"],
            assignedStudentIDs: [studentID],
          })),
        setDoc(doc(db, `districts/${districtID}/students/${studentID}`), {
          districtId: districtID,
          schoolId: "school-1",
          assignedMemberIDs: [staffUserID],
          isArchived: false,
          recordVersion: 1,
        }),
        setDoc(doc(db, `districts/${districtID}/formAssignments/${assignmentID}`), {
          districtId: districtID,
          schoolId: "school-1",
          assignmentType: "survey",
          isActive: true,
          studentIDs: [studentID],
          definitionID,
          definitionVersion,
          attemptID,
        }),
        setDoc(doc(db, `districts/${districtID}/studentModeSessions/${sessionID}`), {
          districtID,
          schoolId: "school-1",
          studentID,
          assignmentIDs: [assignmentID],
          allowedOperations: [
            "readStudentSafeProfile",
            "readAssignment",
            "writeDraft",
            "submitAssignment",
            "requestHelp",
          ],
          respondentUserID,
          educatorUserID: staffUserID,
          status: "active",
          recordVersion: 1,
          expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
        }),
        setDoc(doc(db, `catalogs/surveyDefinitions/items/${definitionID}__v${definitionVersion}`), definition),
      ]);
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  const handlers = () => createSurveyHandlers({ firestore: getFirestore() });

  it("saves one idempotent scoped draft without advancing twice", async () => {
    const first = await handlers().saveDraft(
      callableRequest(saveRequest(), { respondent: true }),
    );
    const repeated = await handlers().saveDraft(
      callableRequest(saveRequest(), { respondent: true }),
    );

    expect(first).toMatchObject({ recordVersion: 1, replayed: false });
    expect(repeated).toMatchObject({ recordVersion: 1, replayed: true });
    const response = await getFirestore()
      .doc(`districts/${districtID}/students/${studentID}/responses/${attemptID}`)
      .get();
    expect(response.data()).toMatchObject({
      state: "draft",
      assignmentID,
      attemptID,
      operationIDs: ["save-1"],
      recordVersion: 1,
    });
  });

  it("submits exactly once with immutable source history and server time", async () => {
    await handlers().saveDraft(
      callableRequest(saveRequest(), { respondent: true }),
    );
    const submitted = await handlers().submitResponse(
      callableRequest(submitRequest(), { respondent: true }),
    );
    const retried = await handlers().submitResponse(
      callableRequest(submitRequest(), { respondent: true }),
    );

    expect(submitted).toMatchObject({ recordVersion: 2, replayed: false });
    expect(retried).toMatchObject({ recordVersion: 2, replayed: true });
    const snapshot = await getFirestore()
      .doc(`districts/${districtID}/students/${studentID}/responses/${attemptID}`)
      .get();
    expect(snapshot.data()).toMatchObject({
      state: "submitted",
      answers: completeAnswers,
      frozenDefinition: definition,
      sourceHistory: {
        definitionID,
        definitionVersion,
        assignmentID,
        attemptID,
        respondentSessionID: sessionID,
      },
      submissionOperationID: "submit-1",
      recordVersion: 2,
    });
    expect(snapshot.get("submittedAt")).toMatchObject({
      seconds: expect.any(Number),
    });
  });

  it("rejects missing auth or App Check and respondent authority supplied by the client", async () => {
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest(), { respondent: true, includeAuth: false })),
      "unauthenticated",
    );
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest(), { respondent: true, includeAppCheck: false })),
      "failed-precondition",
    );
    await expectHttpsError(
      handlers().saveDraft(callableRequest({ ...saveRequest(), role: "administrator" } as SaveSurveyDraftRequest, { respondent: true })),
      "invalid-argument",
    );
  });

  it("rejects every cross-tenant, cross-student, and cross-assignment request", async () => {
    for (const overrides of [
      { districtID: "d2", operationID: "cross-district" },
      { studentID: "student-2", operationID: "cross-student" },
      { assignmentID: "assignment-2", operationID: "cross-assignment" },
    ]) {
      await expectHttpsError(
        handlers().saveDraft(callableRequest(saveRequest(overrides), { respondent: true })),
        "permission-denied",
      );
    }
  });

  it("rejects revoked assignment and expired or malformed respondent session", async () => {
    const assignmentPath = `districts/${districtID}/formAssignments/${assignmentID}`;
    const sessionPath = `districts/${districtID}/studentModeSessions/${sessionID}`;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), assignmentPath), { isActive: false });
    });
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest(), { respondent: true })),
      "failed-precondition",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), assignmentPath), {
        isActive: true,
        assignmentType: "unknown",
      });
    });
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest(), { respondent: true })),
      "failed-precondition",
    );

    const malformedOperations = [
      "readAssignment",
      "writeDraft",
      "submitAssignment",
      "unknownOperation",
    ];
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), assignmentPath), {
        assignmentType: "survey",
      });
      await updateDoc(doc(context.firestore(), sessionPath), {
        allowedOperations: malformedOperations,
      });
    });
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest(), {
        respondent: true,
        claims: { tmiAllowedOperations: malformedOperations },
      })),
      "permission-denied",
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), sessionPath), {
        allowedOperations: [
          "readStudentSafeProfile",
          "readAssignment",
          "writeDraft",
          "submitAssignment",
          "requestHelp",
        ],
        expiresAt: Timestamp.fromMillis(Date.now() - 1),
      });
    });
    await expectHttpsError(
      handlers().submitResponse(callableRequest(submitRequest({ expectedRecordVersion: 0 }), { respondent: true })),
      "failed-precondition",
    );
  });

  it("rejects stale versions, definition mismatches, malformed answers, and missing visible required answers", async () => {
    await handlers().saveDraft(
      callableRequest(saveRequest(), { respondent: true }),
    );
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest({ expectedRecordVersion: 0, operationID: "stale" }), { respondent: true })),
      "aborted",
    );
    await expectHttpsError(
      handlers().submitResponse(callableRequest(submitRequest({ definitionVersion: 2 }), { respondent: true })),
      "failed-precondition",
    );
    await expectHttpsError(
      handlers().submitResponse(callableRequest(submitRequest({
        answers: { ...completeAnswers, rating: { type: "unknown", value: 4 } },
      } as unknown as Partial<SubmitSurveyResponseRequest>), { respondent: true })),
      "invalid-argument",
    );
    const { text: _text, ...missingText } = completeAnswers;
    await expectHttpsError(
      handlers().submitResponse(callableRequest(submitRequest({ answers: missingText }), { respondent: true })),
      "failed-precondition",
    );
  });

  it("rejects unknown branch references and cycles fail closed", async () => {
    const definitionPath = `catalogs/surveyDefinitions/items/${definitionID}__v${definitionVersion}`;
    for (const branchRules of [
      [{ id: "unknown", sourceQuestionID: "missing", targetQuestionID: "text", priority: 0, effect: "show", predicate: { type: "textIsNotEmpty" } }],
      [
        { id: "one", sourceQuestionID: "single", targetQuestionID: "text", priority: 0, effect: "show", predicate: { type: "equals", value: "art" } },
        { id: "two", sourceQuestionID: "text", targetQuestionID: "single", priority: 0, effect: "show", predicate: { type: "textIsNotEmpty" } },
      ],
    ]) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), definitionPath), { branchRules });
      });
      await expectHttpsError(
        handlers().saveDraft(callableRequest(saveRequest({ operationID: `branch-${branchRules.length}` }), { respondent: true })),
        "failed-precondition",
      );
    }
  });

  it("denies edits and downgrade after submit while staff review preserves answers", async () => {
    await handlers().saveDraft(
      callableRequest(saveRequest(), { respondent: true }),
    );
    await handlers().submitResponse(
      callableRequest(submitRequest(), { respondent: true }),
    );
    await expectHttpsError(
      handlers().saveDraft(callableRequest(saveRequest({
        expectedRecordVersion: 2,
        operationID: "edit-after-submit",
      }), { respondent: true })),
      "failed-precondition",
    );
    const reviewed = await handlers().reviewResponse(
      callableRequest(reviewRequest()),
    );
    expect(reviewed).toMatchObject({ recordVersion: 3, replayed: false });
    const replayed = await handlers().reviewResponse(
      callableRequest(reviewRequest()),
    );
    expect(replayed).toMatchObject({ recordVersion: 3, replayed: true });
    const snapshot = await getFirestore()
      .doc(`districts/${districtID}/students/${studentID}/responses/${attemptID}`)
      .get();
    expect(snapshot.data()).toMatchObject({
      state: "reviewed",
      answers: completeAnswers,
      reviewedBy: staffUserID,
      recordVersion: 3,
    });
  });

  it("requires trusted staff membership, capability, and exact student scope for review", async () => {
    await handlers().saveDraft(callableRequest(saveRequest(), { respondent: true }));
    await handlers().submitResponse(callableRequest(submitRequest(), { respondent: true }));

    await expectHttpsError(
      handlers().reviewResponse(callableRequest(reviewRequest(), { includeAuth: false })),
      "unauthenticated",
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), `districts/${districtID}/members/${staffUserID}`),
        { capabilities: ["student.read.detail"] },
      );
    });
    await expectHttpsError(
      handlers().reviewResponse(callableRequest(reviewRequest())),
      "permission-denied",
    );
  });

  it("rules allow only exact scoped reads and deny every direct response write", async () => {
    await handlers().saveDraft(callableRequest(saveRequest(), { respondent: true }));
    const claims = {
      tmiDistrictID: districtID,
      tmiAccessClass: "respondent",
      tmiStudentID: studentID,
      tmiSessionID: sessionID,
      tmiAssignmentIDs: [assignmentID],
      tmiAllowedOperations: [
        "readStudentSafeProfile",
        "readAssignment",
        "writeDraft",
        "submitAssignment",
        "requestHelp",
      ],
    };
    const respondentDB = testEnv.authenticatedContext(respondentUserID, claims).firestore();
    const responsePath = `districts/${districtID}/students/${studentID}/responses/${attemptID}`;
    await assertSucceeds(getDoc(doc(respondentDB, responsePath)));
    await assertSucceeds(getDoc(doc(
      respondentDB,
      `catalogs/surveyDefinitions/items/${definitionID}__v${definitionVersion}`,
    )));
    await assertFails(setDoc(doc(respondentDB, responsePath), {
      districtID,
      studentID,
      assignmentID,
      state: "submitted",
      answers: completeAnswers,
    }, { merge: true }));
    await assertFails(getDoc(doc(
      respondentDB,
      `districts/${districtID}/students/student-2/responses/${attemptID}`,
    )));
    const staffDB = testEnv.authenticatedContext(
      staffUserID,
      trustedClaims(districtID),
    ).firestore();
    await assertFails(updateDoc(doc(staffDB, responsePath), { state: "reviewed" }));
  });
});
