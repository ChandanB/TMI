import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  canWriteStudentDetail,
  executePrivilegedOperation,
  isValidIdentifier,
  parseBaseRequest,
  rejectUnexpectedFields,
  requireIdentifier,
  requireIdentifierArray,
  requireInteger,
  requireRecord,
  requireString,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
} from "./authz.js";

/**
 * Caregiver interest observations (early childhood). Children under five
 * cannot report their own interests, so the observing caregiver records what
 * they saw the child choose during play. The server owns the interest
 * vocabulary: clients send only IDs, and names/categories come from here.
 * Each observation is stored immutably and the resulting interest edges carry
 * `source: "staff"` with a link back to the observation.
 */
export const playInterestCatalog = {
  "building-blocks": "Building & blocks",
  vehicles: "Trucks & vehicles",
  "art-sensory": "Art & sensory play",
  "music-movement": "Music & movement",
  "books-stories": "Books & stories",
  "pretend-play": "Pretend play",
  "animals-nature": "Animals & nature",
  "water-sand": "Water & sand play",
} as const satisfies Record<string, string>;

export type PlayInterestID = keyof typeof playInterestCatalog;

const isPlayInterest = (value: string): value is PlayInterestID =>
  Object.prototype.hasOwnProperty.call(playInterestCatalog, value);

export interface RecordInterestObservationRequest extends PrivilegedBaseRequest {
  readonly studentID: string;
  readonly observedInterestIDs: readonly PlayInterestID[];
  readonly longestAttentionInterestID: PlayInterestID | null;
  readonly engagement: number | null;
  readonly note: string | null;
}

const allowedFields = new Set([
  "districtID",
  "expectedRecordVersion",
  "idempotencyKey",
  "reasonCode",
  "studentID",
  "observedInterestIDs",
  "longestAttentionInterestID",
  "engagement",
  "note",
]);

const requirePlayInterest = (value: unknown, fieldName: string): PlayInterestID => {
  const identifier = requireIdentifier(value, fieldName);
  if (!isPlayInterest(identifier)) {
    throw new HttpsError("invalid-argument", `${fieldName} is not a known play interest.`);
  }
  return identifier;
};

export const parseRecordInterestObservationRequest = (
  value: unknown,
): RecordInterestObservationRequest => {
  const data = requireRecord(value);
  rejectUnexpectedFields(data, allowedFields);
  const base = parseBaseRequest(data);
  if (base.expectedRecordVersion !== 0) {
    throw new HttpsError(
      "invalid-argument",
      "An observation is a new record and must expect record version zero.",
    );
  }
  const observedInterestIDs = requireIdentifierArray(
    data.observedInterestIDs,
    "observedInterestIDs",
    { allowEmpty: false, maximumCount: Object.keys(playInterestCatalog).length },
  ).map((id) => requirePlayInterest(id, "observedInterestIDs"));
  const longestAttentionInterestID =
    data.longestAttentionInterestID === undefined || data.longestAttentionInterestID === null
      ? null
      : requirePlayInterest(data.longestAttentionInterestID, "longestAttentionInterestID");
  return {
    ...base,
    studentID: requireIdentifier(data.studentID, "studentID"),
    observedInterestIDs,
    longestAttentionInterestID,
    engagement:
      data.engagement === undefined || data.engagement === null
        ? null
        : requireInteger(data.engagement, "engagement", 1, 5),
    note:
      data.note === undefined || data.note === null || data.note === ""
        ? null
        : requireString(data.note, "note", 2_000),
  };
};

/** Observed = 3; held attention longest = 5. Existing strengths never drop. */
export const observedStrength = (
  interestID: PlayInterestID,
  data: Pick<RecordInterestObservationRequest, "longestAttentionInterestID">,
): number => (data.longestAttentionInterestID === interestID ? 5 : 3);

export const createRecordInterestObservationHandler = (
  firestore: () => Firestore,
) => async (
  request: CallableRequest<unknown>,
): Promise<PrivilegedOperationResult> => {
  const data = parseRecordInterestObservationRequest(request.data);
  const interestIDs = [
    ...new Set([
      ...data.observedInterestIDs,
      ...(data.longestAttentionInterestID === null ? [] : [data.longestAttentionInterestID]),
    ]),
  ];
  const db = firestore();
  return executePrivilegedOperation(
    db,
    request as CallableRequest<RecordInterestObservationRequest>,
    data,
    {
      action: "student.interests.observe",
      targetPath: () => `districts/${data.districtID}/students/${data.studentID}/observations/${data.idempotencyKey}`,
      requiredCapability: "student.write.detail",
      auditDetails: () => ({
        studentID: data.studentID,
        observedInterestIDs: [...interestIDs].sort(),
      }),
      mutate: async ({ transaction, membership, identity }) => {
        const studentReference = db.doc(`districts/${data.districtID}/students/${data.studentID}`);
        const studentSnapshot = await transaction.get(studentReference);
        if (!studentSnapshot.exists) {
          throw new HttpsError("not-found", "Student was not found.");
        }
        const student = studentSnapshot.data() ?? {};
        const schoolID = student.schoolId;
        if (
          !isValidIdentifier(schoolID) ||
          student.districtId !== data.districtID ||
          student.isArchived === true ||
          !canWriteStudentDetail(membership, data.studentID, schoolID)
        ) {
          throw new HttpsError("permission-denied", "The student is outside the member's writable scope.");
        }

        const edgeReferences = interestIDs.map((interestID) =>
          db.doc(`districts/${data.districtID}/students/${data.studentID}/interests/${interestID}`));
        const existingEdges = await Promise.all(edgeReferences.map((reference) => transaction.get(reference)));
        const observedAt = Timestamp.now();
        const observationReference = db.doc(
          `districts/${data.districtID}/students/${data.studentID}/observations/${data.idempotencyKey}`,
        );

        transaction.create(observationReference, {
          schemaVersion: 1,
          recordVersion: 1,
          districtID: data.districtID,
          studentID: data.studentID,
          schoolID,
          kind: "interest",
          observedInterestIDs: [...data.observedInterestIDs],
          longestAttentionInterestID: data.longestAttentionInterestID,
          engagement: data.engagement,
          note: data.note,
          observedBy: identity.userID,
          observedAt,
          createdAt: FieldValue.serverTimestamp(),
        });

        interestIDs.forEach((interestID, index) => {
          const existing = existingEdges[index]?.data();
          const previousStrength = typeof existing?.strength === "number" ? existing.strength : null;
          const strength = Math.max(previousStrength ?? 0, observedStrength(interestID, data));
          const priorHistory = Array.isArray(existing?.mergeHistory) ? existing.mergeHistory.slice(-19) : [];
          transaction.set(edgeReferences[index]!, {
            schemaVersion: 1,
            studentId: data.studentID,
            interestId: interestID,
            name: playInterestCatalog[interestID],
            category: "Play",
            strength,
            level: strength,
            rank: index + 1,
            source: existing?.source ?? "staff",
            capturedAt: existing?.capturedAt ?? observedAt,
            updatedAt: observedAt,
            createdAt: existing?.createdAt ?? observedAt,
            createdBy: existing?.createdBy ?? identity.userID,
            sourceObservationId: data.idempotencyKey,
            mergeHistory: [
              ...priorHistory,
              {
                observationId: data.idempotencyKey,
                approvedBy: identity.userID,
                approvedAt: observedAt,
                previousStrength,
              },
            ],
          });
        });
        return { recordVersion: 1 };
      },
    },
  );
};
