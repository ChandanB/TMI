import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  canWriteStudentDetail,
  executePrivilegedOperation,
  isValidIdentifier,
  parseBaseRequest,
  rejectUnexpectedFields,
  requireEnum,
  requireIdentifier,
  requireRecord,
  requireString,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
} from "./authz.js";
import { playInterestCatalog, type PlayInterestID } from "./observations.js";

/**
 * "All About My Child" family input (early childhood). A caregiver either
 * records what the family shares or hands the device to the family inside a
 * locked, single-child hand-off screen; either way the staff member's trusted
 * session submits it. Stored immutably; answers never become plan content
 * without staff action.
 */
export const familyInputFormID = "ec-family-all-about-me";
export const familyInputFormVersion = 1;

const textQuestionIDs = [
  "favoriteThings",
  "comfortsWhenUpset",
  "routinesAtHome",
  "languagesAtHome",
  "hopesForThisYear",
  "anythingElse",
] as const;
type TextQuestionID = (typeof textQuestionIDs)[number];

export interface RecordFamilyInputRequest extends PrivilegedBaseRequest {
  readonly studentID: string;
  readonly formID: string;
  readonly formVersion: number;
  readonly completedBy: "family" | "staffOnBehalfOfFamily";
  readonly relationship: string | null;
  readonly answers: Readonly<Partial<Record<TextQuestionID, string>>>;
  readonly favoritePlayInterestIDs: readonly PlayInterestID[];
}

const allowedFields = new Set([
  "districtID",
  "expectedRecordVersion",
  "idempotencyKey",
  "reasonCode",
  "studentID",
  "formID",
  "formVersion",
  "completedBy",
  "relationship",
  "answers",
  "favoritePlayInterestIDs",
]);

export const parseRecordFamilyInputRequest = (value: unknown): RecordFamilyInputRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, allowedFields);
  const base = parseBaseRequest(data);
  if (base.expectedRecordVersion !== 0) {
    throw new HttpsError("invalid-argument", "Family input is a new record and must expect version zero.");
  }
  if (data.formID !== familyInputFormID || data.formVersion !== familyInputFormVersion) {
    throw new HttpsError("failed-precondition", "The family form version is not current.");
  }
  const answersRecord = requireRecord(data.answers ?? {}, "answers");
  rejectUnexpectedFields(answersRecord, new Set(textQuestionIDs));
  const answers: Partial<Record<TextQuestionID, string>> = {};
  for (const id of textQuestionIDs) {
    const answer = answersRecord[id];
    if (answer !== undefined && answer !== null && answer !== "") {
      answers[id] = requireString(answer, `answers.${id}`, 2_000);
    }
  }
  const favorites = Array.isArray(data.favoritePlayInterestIDs) ? data.favoritePlayInterestIDs : [];
  if (favorites.length > Object.keys(playInterestCatalog).length) {
    throw new HttpsError("invalid-argument", "Too many favorites.");
  }
  const favoritePlayInterestIDs = favorites.map((item) => {
    const id = requireIdentifier(item, "favoritePlayInterestIDs");
    if (!Object.prototype.hasOwnProperty.call(playInterestCatalog, id)) {
      throw new HttpsError("invalid-argument", "favoritePlayInterestIDs contains an unknown interest.");
    }
    return id as PlayInterestID;
  });
  if (Object.keys(answers).length === 0 && favoritePlayInterestIDs.length === 0) {
    throw new HttpsError("invalid-argument", "Family input needs at least one answer.");
  }
  return {
    ...base,
    studentID: requireIdentifier(data.studentID, "studentID"),
    formID: familyInputFormID,
    formVersion: familyInputFormVersion,
    completedBy: requireEnum(data.completedBy, "completedBy", ["family", "staffOnBehalfOfFamily"] as const),
    relationship:
      data.relationship === undefined || data.relationship === null || data.relationship === ""
        ? null
        : requireString(data.relationship, "relationship", 80),
    answers,
    favoritePlayInterestIDs: [...new Set(favoritePlayInterestIDs)],
  };
};

export const createRecordFamilyInputHandler = (
  firestore: () => Firestore,
) => async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult> => {
  const data = parseRecordFamilyInputRequest(request.data);
  const db = firestore();
  return executePrivilegedOperation(
    db,
    request as CallableRequest<RecordFamilyInputRequest>,
    data,
    {
      action: "student.familyInput.record",
      targetPath: () => `districts/${data.districtID}/students/${data.studentID}/familyInputs/${data.idempotencyKey}`,
      requiredCapability: "student.write.detail",
      // Audit records the fact of submission, never the family's words.
      auditDetails: () => ({
        studentID: data.studentID,
        formID: data.formID,
        formVersion: data.formVersion,
        completedBy: data.completedBy,
      }),
      mutate: async ({ transaction, membership, identity }) => {
        const student = await transaction.get(db.doc(`districts/${data.districtID}/students/${data.studentID}`));
        if (!student.exists) {
          throw new HttpsError("not-found", "Student was not found.");
        }
        const studentData = student.data() ?? {};
        const schoolID = studentData.schoolId;
        if (
          !isValidIdentifier(schoolID) ||
          studentData.districtId !== data.districtID ||
          studentData.isArchived === true ||
          !canWriteStudentDetail(membership, data.studentID, schoolID)
        ) {
          throw new HttpsError("permission-denied", "The student is outside the member's writable scope.");
        }
        transaction.create(
          db.doc(`districts/${data.districtID}/students/${data.studentID}/familyInputs/${data.idempotencyKey}`),
          {
            schemaVersion: 1,
            recordVersion: 1,
            districtID: data.districtID,
            studentID: data.studentID,
            schoolID,
            formID: data.formID,
            formVersion: data.formVersion,
            completedBy: data.completedBy,
            relationship: data.relationship,
            answers: data.answers,
            favoritePlayInterestIDs: data.favoritePlayInterestIDs,
            submittedBy: identity.userID,
            submittedAt: Timestamp.now(),
            createdAt: FieldValue.serverTimestamp(),
          },
        );
        return { recordVersion: 1 };
      },
    },
  );
};
