import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  assertDistrict,
  assertRecordVersion,
  canReadStudentDetail,
  canWriteStudentDetail,
  executePrivilegedOperation,
  isValidIdentifier,
  parseBaseRequest,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireEnum,
  requireIdentifier,
  requireInteger,
  requireRecord,
  requireString,
  requireTrustedMembership,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
  type TrustedMembership,
} from "./authz.js";
import { enqueueNotification } from "./collaboration.js";

/**
 * Canonical form completion and review.
 *
 * One respondent record per student per assignment lives at
 * `districts/{d}/formAssignments/{a}/respondents/{studentID}` and is written
 * only here. Staff complete forms themselves or hand the device to a family
 * member or student inside a locked screen; either way the staff member's
 * trusted session submits. Submission validates answers against the current
 * template, freezes the answers together with a snapshot of the fields, and
 * can never be edited afterwards. Review metadata is stored separately and
 * does not touch the frozen answers.
 */

export const answerableFieldTypes = [
  "text", "longText", "number", "date", "dateTime", "time", "dropdown",
  "multipleChoice", "checkbox", "email", "phoneNumber", "url", "Rating", "Signature",
] as const;
type AnswerableFieldType = (typeof answerableFieldTypes)[number];

export interface CanonicalFormField {
  readonly key: string;
  readonly sectionTitle: string;
  readonly label: string;
  readonly type: string;
  readonly isRequired: boolean;
  readonly options: readonly string[];
  readonly isAnswerable: boolean;
}

export type FormAnswer = string | number | boolean;
export type RespondentType = "staff" | "family" | "student";
export type ResponseState = "notStarted" | "draft" | "submitted" | "reviewed";

const maximumTextBytes = 5_000;
const encoder = new TextEncoder();

/**
 * Stored templates have no field IDs (the client encoder drops nested
 * document IDs), so keys are positional and stable for a given template
 * version: `s{section}-f{field}`, or the field's own id when present.
 */
export const canonicalFields = (template: DocumentData): CanonicalFormField[] => {
  const sections = Array.isArray(template.sections) ? template.sections : [];
  return sections.flatMap((section: DocumentData, sectionIndex: number) => {
    const fields = Array.isArray(section?.fields) ? section.fields : [];
    return fields.map((field: DocumentData, fieldIndex: number) => {
      const type = typeof field?.type === "string" ? field.type : "text";
      return {
        key: typeof field?.id === "string" && isValidIdentifier(field.id)
          ? field.id
          : `s${sectionIndex}-f${fieldIndex}`,
        sectionTitle: typeof section?.title === "string" ? section.title : "",
        label: typeof field?.label === "string" ? field.label : "Question",
        type,
        isRequired: field?.isRequired === true,
        options: Array.isArray(field?.options)
          ? field.options.filter((option: unknown): option is string => typeof option === "string")
          : [],
        isAnswerable: (answerableFieldTypes as readonly string[]).includes(type),
      };
    });
  });
};

const isBlank = (value: FormAnswer | undefined): boolean =>
  value === undefined || (typeof value === "string" && value.trim().length === 0);

/** Type-checks each provided answer against its field. */
export const validateAnswers = (
  fields: readonly CanonicalFormField[],
  value: unknown,
  requireComplete: boolean,
): Record<string, FormAnswer> => {
  const answers = requireRecord(value ?? {}, "answers");
  const fieldsByKey = new Map(fields.map((field) => [field.key, field]));
  const result: Record<string, FormAnswer> = {};
  for (const [key, raw] of Object.entries(answers)) {
    const field = fieldsByKey.get(key);
    if (field === undefined || !field.isAnswerable) {
      throw new HttpsError("invalid-argument", `Unknown or unanswerable field: ${key}.`);
    }
    if (raw === null) continue;
    const type = field.type as AnswerableFieldType;
    switch (type) {
      case "number":
        if (typeof raw !== "number" || !Number.isFinite(raw)) {
          throw new HttpsError("invalid-argument", `${field.label} must be a number.`);
        }
        result[key] = raw;
        break;
      case "checkbox":
        if (typeof raw !== "boolean") {
          throw new HttpsError("invalid-argument", `${field.label} must be yes or no.`);
        }
        result[key] = raw;
        break;
      case "Rating":
        if (typeof raw !== "number" || !Number.isInteger(raw) || raw < 1 || raw > 5) {
          throw new HttpsError("invalid-argument", `${field.label} must be a rating from 1 to 5.`);
        }
        result[key] = raw;
        break;
      case "dropdown":
      case "multipleChoice":
        if (typeof raw !== "string" || !field.options.includes(raw)) {
          throw new HttpsError("invalid-argument", `${field.label} must be one of its options.`);
        }
        result[key] = raw;
        break;
      default:
        if (typeof raw !== "string" || encoder.encode(raw).byteLength > maximumTextBytes || /\p{Cc}/u.test(raw.replace(/[\n\r\t]/g, ""))) {
          throw new HttpsError("invalid-argument", `${field.label} is too long or malformed.`);
        }
        result[key] = raw;
    }
  }
  if (requireComplete) {
    const missing = fields.filter((field) => field.isRequired && field.isAnswerable && isBlank(result[field.key]));
    if (missing.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        `Answer the required questions: ${missing.map((field) => field.label).join(", ")}.`,
        { kind: "form-incomplete", fieldKeys: missing.map((field) => field.key) },
      );
    }
  }
  return result;
};

// MARK: - Shared loading

interface FormContext {
  readonly assignment: DocumentData;
  readonly template: DocumentData;
  readonly fields: CanonicalFormField[];
  readonly respondent: DocumentData | undefined;
  readonly schoolID: string;
}

const paths = (districtID: string, assignmentID: string, studentID: string) => ({
  assignment: `districts/${districtID}/formAssignments/${assignmentID}`,
  respondent: `districts/${districtID}/formAssignments/${assignmentID}/respondents/${studentID}`,
  student: `districts/${districtID}/students/${studentID}`,
});

const loadContext = async (
  firestore: Firestore,
  transaction: Transaction,
  membership: TrustedMembership,
  districtID: string,
  assignmentID: string,
  studentID: string,
  access: "read" | "write",
): Promise<FormContext> => {
  const path = paths(districtID, assignmentID, studentID);
  const [assignmentSnapshot, studentSnapshot, respondentSnapshot] = await Promise.all([
    transaction.get(firestore.doc(path.assignment)),
    transaction.get(firestore.doc(path.student)),
    transaction.get(firestore.doc(path.respondent)),
  ]);
  if (!assignmentSnapshot.exists || !studentSnapshot.exists) {
    throw new HttpsError("not-found", "The form assignment or student was not found.");
  }
  const assignment = assignmentSnapshot.data() ?? {};
  const student = studentSnapshot.data() ?? {};
  const schoolID = student.schoolId;
  const studentIDs: unknown[] = Array.isArray(assignment.studentIDs) ? assignment.studentIDs : [];
  // Writing needs both the role scope and the explicit capability, exactly as
  // the audited submit/review operations require.
  const allowed = access === "read"
    ? canReadStudentDetail(membership, studentID, schoolID)
    : canWriteStudentDetail(membership, studentID, schoolID) &&
      membership.capabilities.has("student.write.detail");
  if (
    !isValidIdentifier(schoolID) ||
    student.districtId !== districtID ||
    (assignment.districtId ?? districtID) !== districtID ||
    !studentIDs.includes(studentID) ||
    !allowed
  ) {
    throw new HttpsError("permission-denied", "This form is outside your access for the student.");
  }
  const templateID = assignment.templateId;
  if (!isValidIdentifier(templateID)) {
    throw new HttpsError("data-loss", "The assignment has no template.");
  }
  const templateSnapshot = await transaction.get(
    firestore.doc(`districts/${districtID}/formTemplates/${templateID}`),
  );
  if (!templateSnapshot.exists) {
    throw new HttpsError("not-found", "The form template was not found.");
  }
  const template = templateSnapshot.data() ?? {};
  return {
    assignment,
    template,
    fields: canonicalFields(template),
    respondent: respondentSnapshot.exists ? respondentSnapshot.data() : undefined,
    schoolID,
  };
};

const stateOf = (respondent: DocumentData | undefined): ResponseState =>
  respondent === undefined ? "notStarted" : (respondent.state as ResponseState) ?? "draft";

const iso = (value: unknown): string | null =>
  value instanceof Timestamp ? value.toDate().toISOString() : null;

// MARK: - Requests

const locator = (data: Record<string, unknown>) => ({
  districtID: requireIdentifier(data.districtID, "districtID"),
  assignmentID: requireIdentifier(data.assignmentID, "assignmentID"),
  studentID: requireIdentifier(data.studentID, "studentID"),
});

export interface SubmitFormRequest extends PrivilegedBaseRequest {
  readonly assignmentID: string;
  readonly studentID: string;
  readonly respondentType: RespondentType;
  readonly answers: unknown;
}

export interface ReviewFormRequest extends PrivilegedBaseRequest {
  readonly assignmentID: string;
  readonly studentID: string;
  readonly outcome: "accepted" | "followUpNeeded";
  readonly comment: string | null;
}

const respondentTypes = ["staff", "family", "student"] as const;

// MARK: - Handlers

export const createFormHandlers = (firestore: () => Firestore) => ({
  /** Forms assigned to one student, with that student's response state. */
  listStudentForms: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "studentID"]));
    const districtID = requireIdentifier(data.districtID, "districtID");
    const studentID = requireIdentifier(data.studentID, "studentID");
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, districtID);
    const db = firestore();
    return db.runTransaction(async (transaction) => {
      const membership = await requireTrustedMembership(db, transaction, identity);
      const student = await transaction.get(db.doc(`districts/${districtID}/students/${studentID}`));
      const schoolID = student.data()?.schoolId;
      if (!student.exists || !canReadStudentDetail(membership, studentID, schoolID)) {
        throw new HttpsError("permission-denied", "This student is outside your access.");
      }
      const assignments = await transaction.get(
        db.collection(`districts/${districtID}/formAssignments`)
          .where("studentIDs", "array-contains", studentID)
          .limit(100),
      );
      const respondents = await Promise.all(assignments.docs.map((document) =>
        transaction.get(document.ref.collection("respondents").doc(studentID))));
      return {
        forms: assignments.docs.map((document, index) => {
          const assignment = document.data();
          const respondent = respondents[index]?.exists ? respondents[index]?.data() : undefined;
          return {
            assignmentID: document.id,
            templateID: assignment.templateId ?? "",
            templateName: assignment.templateName ?? "Form",
            instructions: assignment.instructions ?? null,
            dueDate: iso(assignment.dueDate),
            isActive: assignment.isActive !== false,
            requiresReview: assignment.requiresReview === true,
            state: stateOf(respondent),
            submittedAt: iso(respondent?.submittedAt),
            reviewedAt: iso(respondent?.review?.reviewedAt),
            recordVersion: typeof respondent?.recordVersion === "number" ? respondent.recordVersion : 0,
          };
        }).sort((left, right) => (left.dueDate ?? "9999").localeCompare(right.dueDate ?? "9999")),
      };
    }, { readOnly: true });
  },

  /** The fields to render and the current response for one student. */
  loadFormResponse: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "assignmentID", "studentID"]));
    const where = locator(data);
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, where.districtID);
    const db = firestore();
    return db.runTransaction(async (transaction) => {
      const membership = await requireTrustedMembership(db, transaction, identity);
      const context = await loadContext(db, transaction, membership, where.districtID, where.assignmentID, where.studentID, "read");
      const state = stateOf(context.respondent);
      const frozen = state === "submitted" || state === "reviewed";
      return {
        templateName: context.template.name ?? context.assignment.templateName ?? "Form",
        instructions: context.assignment.instructions ?? null,
        // A submitted response is read against the fields it was answered with.
        fields: frozen && Array.isArray(context.respondent?.fields) ? context.respondent.fields : context.fields,
        answers: context.respondent?.answers ?? {},
        state,
        respondentType: context.respondent?.respondentType ?? null,
        recordVersion: typeof context.respondent?.recordVersion === "number" ? context.respondent.recordVersion : 0,
        submittedAt: iso(context.respondent?.submittedAt),
        review: context.respondent?.review
          ? {
              outcome: context.respondent.review.outcome,
              comment: context.respondent.review.comment ?? null,
              reviewedBy: context.respondent.review.reviewedBy,
              reviewedAt: iso(context.respondent.review.reviewedAt),
            }
          : null,
        canEdit: !frozen &&
          canWriteStudentDetail(membership, where.studentID, context.schoolID) &&
          membership.capabilities.has("student.write.detail"),
      };
    }, { readOnly: true });
  },

  /** Autosaves an editable draft. Version-checked; not audited. */
  saveFormDraft: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "assignmentID", "studentID", "answers", "expectedRecordVersion"]));
    const where = locator(data);
    const expectedRecordVersion = requireInteger(data.expectedRecordVersion, "expectedRecordVersion", 0);
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, where.districtID);
    const db = firestore();
    return db.runTransaction(async (transaction) => {
      const membership = await requireTrustedMembership(db, transaction, identity);
      const context = await loadContext(db, transaction, membership, where.districtID, where.assignmentID, where.studentID, "write");
      const state = stateOf(context.respondent);
      if (state === "submitted" || state === "reviewed") {
        throw new HttpsError("failed-precondition", "This form was already submitted and can't be changed.");
      }
      const currentVersion = typeof context.respondent?.recordVersion === "number" ? context.respondent.recordVersion : 0;
      assertRecordVersion(currentVersion, expectedRecordVersion);
      const answers = validateAnswers(context.fields, data.answers, false);
      const now = Timestamp.now();
      const nextVersion = currentVersion + 1;
      transaction.set(db.doc(paths(where.districtID, where.assignmentID, where.studentID).respondent), {
        schemaVersion: 1,
        recordVersion: nextVersion,
        districtID: where.districtID,
        assignmentID: where.assignmentID,
        studentID: where.studentID,
        templateID: context.assignment.templateId,
        templateVersion: context.template.version ?? 1,
        state: "draft",
        answers,
        createdAt: context.respondent?.createdAt ?? now,
        createdBy: context.respondent?.createdBy ?? identity.userID,
        updatedAt: now,
        updatedBy: identity.userID,
      });
      return { recordVersion: nextVersion };
    });
  },

  /** Validates, freezes, and submits. Audited and idempotent. */
  submitFormResponse: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode",
      "assignmentID", "studentID", "respondentType", "answers",
    ]));
    const data: SubmitFormRequest = {
      ...parseBaseRequest(raw),
      assignmentID: requireIdentifier(raw.assignmentID, "assignmentID"),
      studentID: requireIdentifier(raw.studentID, "studentID"),
      respondentType: requireEnum(raw.respondentType, "respondentType", respondentTypes),
      answers: raw.answers,
    };
    const db = firestore();
    return executePrivilegedOperation(db, request as CallableRequest<SubmitFormRequest>, data, {
      action: "form.response.submit",
      targetPath: (input) => paths(input.districtID, input.assignmentID, input.studentID).respondent,
      requiredCapability: "student.write.detail",
      // The audit trail records the submission, never the answers.
      auditDetails: (input) => ({
        assignmentID: input.assignmentID,
        studentID: input.studentID,
        respondentType: input.respondentType,
      }),
      mutate: async ({ transaction, membership, identity }) => {
        const context = await loadContext(db, transaction, membership, data.districtID, data.assignmentID, data.studentID, "write");
        const state = stateOf(context.respondent);
        if (state === "submitted" || state === "reviewed") {
          throw new HttpsError("failed-precondition", "This form was already submitted.");
        }
        if (context.assignment.isActive === false) {
          throw new HttpsError("failed-precondition", "This form assignment is closed.");
        }
        const dueDate = context.assignment.dueDate;
        if (
          dueDate instanceof Timestamp &&
          dueDate.toMillis() < Date.now() &&
          context.assignment.allowLateSubmissions === false
        ) {
          throw new HttpsError("failed-precondition", "This form is past due and doesn't accept late submissions.");
        }
        const currentVersion = typeof context.respondent?.recordVersion === "number" ? context.respondent.recordVersion : 0;
        assertRecordVersion(currentVersion, data.expectedRecordVersion);
        const answers = validateAnswers(context.fields, data.answers, true);
        const now = Timestamp.now();
        const nextVersion = currentVersion + 1;
        transaction.set(db.doc(paths(data.districtID, data.assignmentID, data.studentID).respondent), {
          schemaVersion: 1,
          recordVersion: nextVersion,
          districtID: data.districtID,
          assignmentID: data.assignmentID,
          studentID: data.studentID,
          templateID: context.assignment.templateId,
          templateVersion: context.template.version ?? 1,
          state: "submitted",
          respondentType: data.respondentType,
          answers,
          fields: context.fields,
          submittedAt: now,
          submittedBy: identity.userID,
          createdAt: context.respondent?.createdAt ?? now,
          createdBy: context.respondent?.createdBy ?? identity.userID,
          updatedAt: now,
          updatedBy: identity.userID,
        });
        transaction.update(db.doc(paths(data.districtID, data.assignmentID, data.studentID).assignment), {
          totalSubmitted: FieldValue.increment(1),
        });
        const assignedBy = context.assignment.assignedBy;
        if (context.assignment.requiresReview === true && isValidIdentifier(assignedBy) && assignedBy !== identity.userID) {
          enqueueNotification(transaction, db, {
            districtID: data.districtID,
            recipientUserID: assignedBy,
            type: "form_submitted",
            title: "A form is ready for review",
            message: typeof context.assignment.templateName === "string" ? context.assignment.templateName : "Form",
            actionURL: `tmi://student/${data.studentID}`,
            targetID: data.assignmentID,
            eventKey: `form-review-${data.assignmentID}`,
          }, now);
        }
        return { recordVersion: nextVersion };
      },
    });
  },

  /** Records a staff review without touching the frozen answers. */
  reviewFormResponse: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode",
      "assignmentID", "studentID", "outcome", "comment",
    ]));
    const data: ReviewFormRequest = {
      ...parseBaseRequest(raw),
      assignmentID: requireIdentifier(raw.assignmentID, "assignmentID"),
      studentID: requireIdentifier(raw.studentID, "studentID"),
      outcome: requireEnum(raw.outcome, "outcome", ["accepted", "followUpNeeded"] as const),
      comment: raw.comment === undefined || raw.comment === null || raw.comment === ""
        ? null
        : requireString(raw.comment, "comment", 2_000),
    };
    const db = firestore();
    return executePrivilegedOperation(db, request as CallableRequest<ReviewFormRequest>, data, {
      action: "form.response.review",
      targetPath: (input) => paths(input.districtID, input.assignmentID, input.studentID).respondent,
      requiredCapability: "student.write.detail",
      auditDetails: (input) => ({ assignmentID: input.assignmentID, studentID: input.studentID, outcome: input.outcome }),
      mutate: async ({ transaction, membership, identity }) => {
        const context = await loadContext(db, transaction, membership, data.districtID, data.assignmentID, data.studentID, "write");
        const state = stateOf(context.respondent);
        if (state !== "submitted" && state !== "reviewed") {
          throw new HttpsError("failed-precondition", "Only submitted forms can be reviewed.");
        }
        const currentVersion = typeof context.respondent?.recordVersion === "number" ? context.respondent.recordVersion : 0;
        assertRecordVersion(currentVersion, data.expectedRecordVersion);
        const now = Timestamp.now();
        const nextVersion = currentVersion + 1;
        const history = Array.isArray(context.respondent?.reviewHistory) ? context.respondent.reviewHistory.slice(-19) : [];
        const review = { outcome: data.outcome, comment: data.comment, reviewedBy: identity.userID, reviewedAt: now };
        transaction.update(db.doc(paths(data.districtID, data.assignmentID, data.studentID).respondent), {
          recordVersion: nextVersion,
          state: "reviewed",
          review,
          reviewHistory: [...history, review],
          updatedAt: now,
          updatedBy: identity.userID,
        });
        if (state === "submitted") {
          transaction.update(db.doc(paths(data.districtID, data.assignmentID, data.studentID).assignment), {
            totalReviewed: FieldValue.increment(1),
          });
        }
        return { recordVersion: nextVersion };
      },
    });
  },
});
