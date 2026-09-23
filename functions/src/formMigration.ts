import type { DocumentData, Firestore } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { isValidIdentifier } from "./authz.js";
import { canonicalFields, scoreAnswers, type CanonicalFormField, type FormAnswer } from "./forms.js";

/**
 * Forward-only migration of legacy per-user form submissions
 * (`users/{uid}/formSubmissions/{id}`) into canonical respondent records
 * (`districts/{d}/formAssignments/{a}/respondents/{studentID}`).
 *
 * - Never overwrites: an existing respondent from another source is a
 *   conflict and is reported, not replaced.
 * - Idempotent: re-running skips records it already migrated.
 * - Legacy answers are matched to canonical fields by key, then by label.
 *   Anything unmatched is preserved under `migration.unmappedAnswers`.
 * - Scores are recomputed from the template's scoring definition; any legacy
 *   score is kept only as provenance.
 */

export const formMigrationVersion = 1;

export type FormMigrationOutcome =
  | { readonly kind: "migrated"; readonly source: string; readonly destination: string }
  | { readonly kind: "alreadyMigrated"; readonly source: string; readonly destination: string }
  | { readonly kind: "conflict"; readonly source: string; readonly destination: string }
  | { readonly kind: "unresolved"; readonly source: string; readonly reason: string };

export interface FormMigrationReport {
  readonly dryRun: boolean;
  readonly outcomes: readonly FormMigrationOutcome[];
  readonly counts: Readonly<Record<FormMigrationOutcome["kind"], number>>;
}

const legacyState = (status: unknown): "draft" | "submitted" | "reviewed" =>
  status === "reviewed" ? "reviewed" : status === "submitted" ? "submitted" : "draft";

const toMillis = (value: unknown): number | null => {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string" && !Number.isNaN(Date.parse(value))) return Date.parse(value);
  return null;
};

const normalizeLabel = (value: string): string => value.trim().toLowerCase().replace(/\s+/gu, " ");

/** Maps legacy answer keys (field ids or labels) onto canonical field keys. */
export const mapLegacyAnswers = (
  fields: readonly CanonicalFormField[],
  data: unknown,
): { answers: Record<string, FormAnswer>; unmapped: Record<string, unknown> } => {
  const answers: Record<string, FormAnswer> = {};
  const unmapped: Record<string, unknown> = {};
  if (typeof data !== "object" || data === null) return { answers, unmapped };
  const byKey = new Map(fields.map((field) => [field.key, field]));
  const byLabel = new Map(fields.map((field) => [normalizeLabel(field.label), field]));
  for (const [key, raw] of Object.entries(data as Record<string, unknown>)) {
    const field = byKey.get(key) ?? byLabel.get(normalizeLabel(key));
    const value = typeof raw === "object" && raw !== null && "value" in raw ? (raw as { value: unknown }).value : raw;
    if (field === undefined || !field.isAnswerable ||
      !(typeof value === "string" || typeof value === "boolean" || (typeof value === "number" && Number.isFinite(value)))) {
      unmapped[key] = raw;
      continue;
    }
    answers[field.key] = value;
  }
  return { answers, unmapped };
};

interface LegacySubmission {
  readonly path: string;
  readonly ownerUserID: string;
  readonly data: DocumentData;
}

export const migrateLegacyFormSubmissions = async (
  firestore: Firestore,
  options: { readonly dryRun: boolean; readonly now?: () => Timestamp },
): Promise<FormMigrationReport> => {
  const now = options.now ?? (() => Timestamp.now());
  const submissions: LegacySubmission[] = (await firestore.collectionGroup("formSubmissions").get()).docs
    .filter((document) => document.ref.parent.parent?.parent.id === "users")
    .map((document) => ({
      path: document.ref.path,
      ownerUserID: document.ref.parent.parent?.id ?? "",
      data: document.data(),
    }))
    .sort((left, right) => left.path.localeCompare(right.path));
  const districts = (await firestore.collection("districts").get()).docs.map((document) => document.id).sort();
  const outcomes: FormMigrationOutcome[] = [];

  for (const submission of submissions) {
    const assignmentID = submission.data.assignmentId;
    const studentID = submission.data.studentId;
    if (!isValidIdentifier(assignmentID) || !isValidIdentifier(studentID)) {
      outcomes.push({ kind: "unresolved", source: submission.path, reason: "missing assignment or student" });
      continue;
    }
    let districtID: string | undefined;
    let assignment: DocumentData | undefined;
    for (const candidate of districts) {
      const snapshot = await firestore.doc(`districts/${candidate}/formAssignments/${assignmentID}`).get();
      if (snapshot.exists) {
        districtID = candidate;
        assignment = snapshot.data();
        break;
      }
    }
    if (districtID === undefined || assignment === undefined) {
      outcomes.push({ kind: "unresolved", source: submission.path, reason: "assignment not found in any district" });
      continue;
    }
    const studentIDs: unknown[] = Array.isArray(assignment.studentIDs) ? assignment.studentIDs : [];
    const student = await firestore.doc(`districts/${districtID}/students/${studentID}`).get();
    if (!student.exists || !studentIDs.includes(studentID)) {
      outcomes.push({ kind: "unresolved", source: submission.path, reason: "student not on the assignment" });
      continue;
    }
    const templateID = assignment.templateId;
    const template = isValidIdentifier(templateID)
      ? (await firestore.doc(`districts/${districtID}/formTemplates/${templateID}`).get()).data()
      : undefined;
    if (template === undefined) {
      outcomes.push({ kind: "unresolved", source: submission.path, reason: "template not found" });
      continue;
    }
    const destination = `districts/${districtID}/formAssignments/${assignmentID}/respondents/${studentID}`;
    const fields = canonicalFields(template);
    const { answers, unmapped } = mapLegacyAnswers(fields, submission.data.data);
    const state = legacyState(submission.data.status);
    const frozen = state !== "draft";
    const submittedAt = toMillis(submission.data.submissionDate);
    const reviewedAt = toMillis(submission.data.reviewedAt);
    const record: DocumentData = {
      schemaVersion: 1,
      recordVersion: 1,
      districtID,
      assignmentID,
      studentID,
      templateID,
      templateVersion: template.version ?? 1,
      state,
      respondentType: "staff",
      answers,
      ...(frozen ? {
        fields,
        scoring: scoreAnswers(template, fields, answers),
        submittedAt: submittedAt === null ? now() : Timestamp.fromMillis(submittedAt),
        submittedBy: submission.ownerUserID,
      } : {}),
      ...(state === "reviewed" ? {
        review: {
          outcome: "accepted",
          comment: typeof submission.data.feedback === "string" ? submission.data.feedback : null,
          reviewedBy: typeof submission.data.reviewedBy === "string" ? submission.data.reviewedBy : submission.ownerUserID,
          reviewedAt: reviewedAt === null ? now() : Timestamp.fromMillis(reviewedAt),
        },
      } : {}),
      createdAt: now(),
      createdBy: submission.ownerUserID,
      updatedAt: now(),
      updatedBy: submission.ownerUserID,
      migration: {
        version: formMigrationVersion,
        source: submission.path,
        legacyScore: typeof submission.data.score === "number" ? submission.data.score : null,
        legacyMaxScore: typeof submission.data.maxScore === "number" ? submission.data.maxScore : null,
        unmappedAnswers: unmapped,
      },
    };

    const reference = firestore.doc(destination);
    const outcome = await firestore.runTransaction(async (transaction): Promise<FormMigrationOutcome> => {
      const existing = await transaction.get(reference);
      if (existing.exists) {
        return existing.data()?.migration?.source === submission.path
          ? { kind: "alreadyMigrated", source: submission.path, destination }
          : { kind: "conflict", source: submission.path, destination };
      }
      if (!options.dryRun) transaction.create(reference, record);
      return { kind: "migrated", source: submission.path, destination };
    });
    outcomes.push(outcome);
  }

  const counts = { migrated: 0, alreadyMigrated: 0, conflict: 0, unresolved: 0 };
  for (const outcome of outcomes) counts[outcome.kind] += 1;
  return { dryRun: options.dryRun, outcomes, counts };
};
