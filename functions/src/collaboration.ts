import { createHash } from "node:crypto";
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
  canReadStudentDetail,
  canWriteStudentDetail,
  executePrivilegedOperation,
  isValidIdentifier,
  parseBaseRequest,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireEnum,
  requireIdentifier,
  requireRecord,
  requireString,
  requireTrustedMembership,
  type PrivilegedBaseRequest,
  type PrivilegedOperationResult,
  type TrustedMembership,
} from "./authz.js";

/**
 * Collaboration: team notes, restricted records, person-owned follow-up
 * tasks, and the in-app notifications they produce.
 *
 * - Team notes (`students/{s}/notes`) are readable by staff who can read the
 *   student; only the author can revise, and every revision is kept.
 * - Restricted records (`students/{s}/restrictedRecords`) are physically
 *   separate, need the restricted capabilities, and every read is audited.
 * - Tasks (`districts/{d}/tasks`, `kind: "followUp"`) belong to one assignee
 *   and may link back to a student, plan, meeting, or form.
 * - Notifications are written only here, grouped by event key, and never
 *   carry student detail in their title.
 */

export const noteCategories = [
  "general", "academic", "socialEmotional", "behavior", "family", "attendance", "meetingFollowUp",
] as const;
export type NoteCategory = (typeof noteCategories)[number];

export const taskStatuses = ["open", "done", "cancelled"] as const;
export type TaskStatus = (typeof taskStatuses)[number];

const maximumNoteBytes = 10_000;

interface StaffContext {
  readonly userID: string;
  readonly membership: TrustedMembership;
}

const staffTransaction = async <T>(
  firestore: Firestore,
  request: CallableRequest<unknown>,
  districtID: string,
  body: (transaction: Transaction, context: StaffContext) => Promise<T>,
  readOnly = false,
): Promise<T> => {
  const identity = parseTrustedCallableIdentity(request);
  assertDistrict(identity, districtID);
  return firestore.runTransaction(async (transaction) => {
    const membership = await requireTrustedMembership(firestore, transaction, identity);
    return body(transaction, { userID: identity.userID, membership });
  }, readOnly ? { readOnly: true } : undefined);
};

const requireStudent = async (
  firestore: Firestore,
  transaction: Transaction,
  districtID: string,
  studentID: string,
): Promise<{ readonly data: DocumentData; readonly schoolID: string }> => {
  const snapshot = await transaction.get(firestore.doc(`districts/${districtID}/students/${studentID}`));
  const data = snapshot.data();
  if (!snapshot.exists || data === undefined || data.districtId !== districtID || !isValidIdentifier(data.schoolId)) {
    throw new HttpsError("not-found", "Student was not found.");
  }
  return { data, schoolID: data.schoolId };
};

const iso = (value: unknown): string | null =>
  value instanceof Timestamp ? value.toDate().toISOString() : null;

const text = (value: unknown, field: string, maximumBytes: number): string =>
  requireString(typeof value === "string" ? value.trim() : value, field, maximumBytes);

const optionalText = (value: unknown, field: string, maximumBytes: number): string | null =>
  value === undefined || value === null || (typeof value === "string" && value.trim() === "")
    ? null
    : text(value, field, maximumBytes);

// MARK: - Notifications

export type NotificationType =
  | "task_assigned"
  | "form_submitted"
  | "plan_approval"
  | "help_request"
  | "system_message";

export interface NotificationEvent {
  readonly districtID: string;
  readonly recipientUserID: string;
  readonly type: NotificationType;
  readonly title: string;
  readonly message: string;
  readonly actionURL: string | null;
  readonly targetID: string | null;
  /** Events with the same key for the same person are grouped into one. */
  readonly eventKey: string;
}

export const notificationID = (recipientUserID: string, eventKey: string): string =>
  createHash("sha256").update(`${recipientUserID}\u0000${eventKey}`).digest("hex").slice(0, 40);

/**
 * Writes (or regroups) one in-app notification. Must run after every read in
 * the transaction. Titles are generic so lock-screen text never reveals
 * student information.
 */
export const enqueueNotification = (
  transaction: Transaction,
  firestore: Firestore,
  event: NotificationEvent,
  now: Timestamp = Timestamp.now(),
): void => {
  const id = notificationID(event.recipientUserID, event.eventKey);
  transaction.set(firestore.doc(`districts/${event.districtID}/notifications/${id}`), {
    id,
    schemaVersion: 1,
    recipientUserID: event.recipientUserID,
    type: event.type,
    title: event.title,
    message: event.message,
    actionUrl: event.actionURL,
    targetId: event.targetID,
    eventKey: event.eventKey,
    isRead: false,
    readAt: null,
    timestamp: now,
    occurrences: FieldValue.increment(1),
  }, { merge: true });
};

// MARK: - Notes

export interface NoteSummary {
  readonly noteID: string;
  readonly category: NoteCategory;
  readonly body: string;
  readonly authorUserID: string;
  readonly createdAt: string | null;
  readonly updatedAt: string | null;
  readonly revisionCount: number;
  readonly recordVersion: number;
  readonly isAuthor: boolean;
}

const noteSummary = (id: string, data: DocumentData, callerID: string): NoteSummary => ({
  noteID: id,
  category: (noteCategories as readonly string[]).includes(data.category) ? data.category : "general",
  body: typeof data.body === "string" ? data.body : "",
  authorUserID: typeof data.authorUserID === "string" ? data.authorUserID : "",
  createdAt: iso(data.createdAt),
  updatedAt: iso(data.updatedAt),
  revisionCount: Array.isArray(data.revisions) ? data.revisions.length : 0,
  recordVersion: typeof data.recordVersion === "number" ? data.recordVersion : 1,
  isAuthor: data.authorUserID === callerID,
});

// MARK: - Tasks

export interface TaskSummary {
  readonly taskID: string;
  readonly title: string;
  readonly details: string | null;
  readonly status: TaskStatus;
  readonly assigneeUserID: string;
  readonly createdBy: string;
  readonly dueDate: string | null;
  readonly studentID: string | null;
  readonly planID: string | null;
  readonly meetingID: string | null;
  readonly outcome: string | null;
  readonly completedAt: string | null;
  readonly recordVersion: number;
  readonly isOverdue: boolean;
}

const taskSummary = (id: string, data: DocumentData, now: Date): TaskSummary => {
  const status = (taskStatuses as readonly string[]).includes(data.status) ? (data.status as TaskStatus) : "open";
  const due = data.dueDate instanceof Timestamp ? data.dueDate : null;
  return {
    taskID: id,
    title: typeof data.title === "string" ? data.title : "Task",
    details: typeof data.details === "string" ? data.details : null,
    status,
    assigneeUserID: typeof data.assigneeUserID === "string" ? data.assigneeUserID : "",
    createdBy: typeof data.createdBy === "string" ? data.createdBy : "",
    dueDate: iso(due),
    studentID: typeof data.studentID === "string" ? data.studentID : null,
    planID: typeof data.planID === "string" ? data.planID : null,
    meetingID: typeof data.meetingID === "string" ? data.meetingID : null,
    outcome: typeof data.outcome === "string" ? data.outcome : null,
    completedAt: iso(data.completedAt),
    recordVersion: typeof data.recordVersion === "number" ? data.recordVersion : 1,
    isOverdue: status === "open" && due !== null && due.toMillis() < now.getTime(),
  };
};

/** The assignee must be an active member who can read the linked student. */
const requireAssignee = async (
  firestore: Firestore,
  transaction: Transaction,
  districtID: string,
  assigneeUserID: string,
  studentID: string | null,
  schoolID: string | null,
): Promise<void> => {
  const snapshot = await transaction.get(firestore.doc(`districts/${districtID}/members/${assigneeUserID}`));
  const data = snapshot.data();
  if (!snapshot.exists || data?.isActive !== true) {
    throw new HttpsError("failed-precondition", "The assignee isn't an active staff member.");
  }
  if (studentID !== null && schoolID !== null) {
    const assignee: TrustedMembership = {
      userID: assigneeUserID,
      districtID,
      schoolIDs: new Set(Array.isArray(data.schoolIDs) ? data.schoolIDs : []),
      role: data.role,
      capabilities: new Set(Array.isArray(data.capabilities) ? data.capabilities : []),
      assignedStudentIDs: new Set(Array.isArray(data.assignedStudentIDs) ? data.assignedStudentIDs : []),
      version: typeof data.version === "number" ? data.version : 1,
    };
    if (!canReadStudentDetail(assignee, studentID, schoolID)) {
      throw new HttpsError("failed-precondition", "The assignee can't see this student, so they can't own the task.");
    }
  }
};

interface CreateTaskRequest extends PrivilegedBaseRequest {
  readonly title: string;
  readonly details: string | null;
  readonly assigneeUserID: string;
  readonly dueDate: string | null;
  readonly studentID: string | null;
  readonly planID: string | null;
  readonly meetingID: string | null;
}

interface UpdateTaskRequest extends PrivilegedBaseRequest {
  readonly taskID: string;
  readonly status: TaskStatus;
  readonly outcome: string | null;
  readonly title: string | null;
  readonly dueDate: string | null;
  readonly assigneeUserID: string | null;
}

const optionalDate = (value: unknown, field: string): Timestamp | null => {
  if (value === undefined || value === null || value === "") return null;
  const date = new Date(requireString(value, field, 64));
  if (Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${field} must be an ISO-8601 date.`);
  }
  return Timestamp.fromDate(date);
};

// MARK: - Handlers

export interface CollaborationDependencies {
  readonly firestore: () => Firestore;
  readonly now: () => Date;
}

export const createCollaborationHandlers = (dependencies: CollaborationDependencies) => ({
  // Notes ---------------------------------------------------------------

  listStudentNotes: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "studentID"]));
    const districtID = requireIdentifier(data.districtID, "districtID");
    const studentID = requireIdentifier(data.studentID, "studentID");
    const db = dependencies.firestore();
    return staffTransaction(db, request, districtID, async (transaction, context) => {
      const student = await requireStudent(db, transaction, districtID, studentID);
      if (!canReadStudentDetail(context.membership, studentID, student.schoolID)) {
        throw new HttpsError("permission-denied", "This student is outside your access.");
      }
      const notes = await transaction.get(
        db.collection(`districts/${districtID}/students/${studentID}/notes`).limit(200),
      );
      return {
        notes: notes.docs
          .filter((document) => document.data().kind === "teamNote")
          .map((document) => noteSummary(document.id, document.data(), context.userID))
          .sort((left, right) => (right.createdAt ?? "").localeCompare(left.createdAt ?? "")),
        canWrite: canWriteStudentDetail(context.membership, studentID, student.schoolID)
          && context.membership.capabilities.has("student.write.detail"),
      };
    }, true);
  },

  saveStudentNote: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult & { noteID: string }> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode",
      "studentID", "noteID", "category", "body",
    ]));
    const base = parseBaseRequest(raw);
    const data = {
      ...base,
      studentID: requireIdentifier(raw.studentID, "studentID"),
      noteID: raw.noteID === undefined || raw.noteID === null ? null : requireIdentifier(raw.noteID, "noteID"),
      category: requireEnum(raw.category, "category", noteCategories),
      body: text(raw.body, "body", maximumNoteBytes),
    };
    const db = dependencies.firestore();
    const noteID = data.noteID ?? data.idempotencyKey;
    const result = await executePrivilegedOperation(db, request as CallableRequest<typeof data>, data, {
      action: data.noteID === null ? "student.note.create" : "student.note.revise",
      targetPath: (input) => `districts/${input.districtID}/students/${input.studentID}/notes/${noteID}`,
      requiredCapability: "student.write.detail",
      // Audit the fact of the note, never its words.
      auditDetails: (input) => ({ studentID: input.studentID, noteID, category: input.category }),
      mutate: async ({ transaction, membership, identity }) => {
        const student = await requireStudent(db, transaction, data.districtID, data.studentID);
        if (!canWriteStudentDetail(membership, data.studentID, student.schoolID)) {
          throw new HttpsError("permission-denied", "This student is outside your writable access.");
        }
        const reference = db.doc(`districts/${data.districtID}/students/${data.studentID}/notes/${noteID}`);
        const snapshot = await transaction.get(reference);
        const now = Timestamp.fromDate(dependencies.now());
        if (data.noteID === null) {
          if (data.expectedRecordVersion !== 0) {
            throw new HttpsError("invalid-argument", "A new note must expect record version zero.");
          }
          transaction.create(reference, {
            schemaVersion: 1,
            recordVersion: 1,
            kind: "teamNote",
            districtID: data.districtID,
            studentID: data.studentID,
            schoolID: student.schoolID,
            category: data.category,
            body: data.body,
            authorUserID: identity.userID,
            revisions: [],
            createdAt: now,
            updatedAt: now,
          });
          return { recordVersion: 1 };
        }
        const existing = snapshot.data();
        if (!snapshot.exists || existing?.kind !== "teamNote") {
          throw new HttpsError("not-found", "Note was not found.");
        }
        if (existing.authorUserID !== identity.userID) {
          throw new HttpsError("permission-denied", "Only the author can revise a note.");
        }
        const current = typeof existing.recordVersion === "number" ? existing.recordVersion : 1;
        if (current !== data.expectedRecordVersion) {
          throw new HttpsError("aborted", "The note changed since you opened it.", {
            kind: "record-version-conflict", expectedRecordVersion: data.expectedRecordVersion, actualRecordVersion: current,
          });
        }
        const history = Array.isArray(existing.revisions) ? existing.revisions.slice(-49) : [];
        transaction.update(reference, {
          recordVersion: current + 1,
          category: data.category,
          body: data.body,
          revisions: [...history, {
            body: existing.body,
            category: existing.category,
            revisedAt: now,
            revisedBy: identity.userID,
          }],
          updatedAt: now,
        });
        return { recordVersion: current + 1 };
      },
    });
    return { ...result, noteID };
  },

  // Restricted records ------------------------------------------------------

  /** Reading restricted records is itself audited. */
  listRestrictedRecords: async (request: CallableRequest<unknown>) => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set(["districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode", "studentID"]));
    const data = { ...parseBaseRequest(raw), studentID: requireIdentifier(raw.studentID, "studentID") };
    const db = dependencies.firestore();
    let records: DocumentData[] = [];
    await executePrivilegedOperation(db, request as CallableRequest<typeof data>, data, {
      action: "student.restricted.read",
      targetPath: (input) => `districts/${input.districtID}/students/${input.studentID}/restrictedRecords`,
      requiredCapability: "student.restricted.read",
      auditDetails: (input) => ({ studentID: input.studentID }),
      mutate: async ({ transaction, membership }) => {
        const student = await requireStudent(db, transaction, data.districtID, data.studentID);
        if (!canReadStudentDetail(membership, data.studentID, student.schoolID)) {
          throw new HttpsError("permission-denied", "This student is outside your access.");
        }
        const snapshot = await transaction.get(
          db.collection(`districts/${data.districtID}/students/${data.studentID}/restrictedRecords`).limit(200),
        );
        records = snapshot.docs.map((document) => ({ id: document.id, ...document.data() }));
        return { recordVersion: data.expectedRecordVersion };
      },
    });
    return {
      records: records
        .map((record) => ({
          recordID: record.id,
          category: typeof record.category === "string" ? record.category : "general",
          body: typeof record.body === "string" ? record.body : "",
          authorUserID: typeof record.authorUserID === "string" ? record.authorUserID : "",
          createdAt: iso(record.createdAt),
        }))
        .sort((left, right) => (right.createdAt ?? "").localeCompare(left.createdAt ?? "")),
    };
  },

  createRestrictedRecord: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode", "studentID", "category", "body",
    ]));
    const data = {
      ...parseBaseRequest(raw),
      studentID: requireIdentifier(raw.studentID, "studentID"),
      category: requireString(raw.category, "category", 60),
      body: text(raw.body, "body", maximumNoteBytes),
    };
    if (data.expectedRecordVersion !== 0) {
      throw new HttpsError("invalid-argument", "A new record must expect record version zero.");
    }
    const db = dependencies.firestore();
    return executePrivilegedOperation(db, request as CallableRequest<typeof data>, data, {
      action: "student.restricted.create",
      targetPath: (input) => `districts/${input.districtID}/students/${input.studentID}/restrictedRecords/${input.idempotencyKey}`,
      requiredCapability: "student.restricted.write",
      auditDetails: (input) => ({ studentID: input.studentID }),
      mutate: async ({ transaction, membership, identity }) => {
        const student = await requireStudent(db, transaction, data.districtID, data.studentID);
        if (!canReadStudentDetail(membership, data.studentID, student.schoolID)) {
          throw new HttpsError("permission-denied", "This student is outside your access.");
        }
        transaction.create(
          db.doc(`districts/${data.districtID}/students/${data.studentID}/restrictedRecords/${data.idempotencyKey}`),
          {
            schemaVersion: 1,
            recordVersion: 1,
            districtID: data.districtID,
            studentID: data.studentID,
            category: data.category,
            body: data.body,
            authorUserID: identity.userID,
            createdAt: Timestamp.fromDate(dependencies.now()),
          },
        );
        return { recordVersion: 1 };
      },
    });
  },

  // Tasks -----------------------------------------------------------------

  listTasks: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data ?? {});
    rejectUnexpectedFields(data, new Set(["districtID", "studentID", "includeClosed"]));
    const districtID = requireIdentifier(data.districtID, "districtID");
    const studentID = data.studentID === undefined || data.studentID === null
      ? null
      : requireIdentifier(data.studentID, "studentID");
    const includeClosed = data.includeClosed === true;
    const db = dependencies.firestore();
    const now = dependencies.now();
    return staffTransaction(db, request, districtID, async (transaction, context) => {
      const tasks = db.collection(`districts/${districtID}/tasks`);
      let documents: FirebaseFirestore.QueryDocumentSnapshot[];
      if (studentID !== null) {
        const student = await requireStudent(db, transaction, districtID, studentID);
        if (!canReadStudentDetail(context.membership, studentID, student.schoolID)) {
          throw new HttpsError("permission-denied", "This student is outside your access.");
        }
        documents = (await transaction.get(tasks.where("studentID", "==", studentID).limit(200))).docs;
      } else {
        const [assigned, created] = await Promise.all([
          transaction.get(tasks.where("assigneeUserID", "==", context.userID).limit(200)),
          transaction.get(tasks.where("createdBy", "==", context.userID).limit(200)),
        ]);
        const byID = new Map([...assigned.docs, ...created.docs].map((document) => [document.id, document]));
        documents = [...byID.values()];
      }
      return {
        tasks: documents
          .filter((document) => document.data().kind === "followUp")
          .map((document) => taskSummary(document.id, document.data(), now))
          .filter((task) => includeClosed || task.status === "open")
          .sort((left, right) => (left.dueDate ?? "9999").localeCompare(right.dueDate ?? "9999")),
      };
    }, true);
  },

  createTask: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult & { taskID: string }> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode",
      "title", "details", "assigneeUserID", "dueDate", "studentID", "planID", "meetingID",
    ]));
    const data: CreateTaskRequest = {
      ...parseBaseRequest(raw),
      title: text(raw.title, "title", 300),
      details: optionalText(raw.details, "details", 4_000),
      assigneeUserID: requireIdentifier(raw.assigneeUserID, "assigneeUserID"),
      dueDate: raw.dueDate === undefined || raw.dueDate === null ? null : requireString(raw.dueDate, "dueDate", 64),
      studentID: raw.studentID === undefined || raw.studentID === null ? null : requireIdentifier(raw.studentID, "studentID"),
      planID: raw.planID === undefined || raw.planID === null ? null : requireIdentifier(raw.planID, "planID"),
      meetingID: raw.meetingID === undefined || raw.meetingID === null ? null : requireIdentifier(raw.meetingID, "meetingID"),
    };
    if (data.expectedRecordVersion !== 0) {
      throw new HttpsError("invalid-argument", "A new task must expect record version zero.");
    }
    const dueDate = optionalDate(data.dueDate, "dueDate");
    const db = dependencies.firestore();
    const taskID = data.idempotencyKey;
    const result = await executePrivilegedOperation(db, request as CallableRequest<CreateTaskRequest>, data, {
      action: "task.create",
      targetPath: (input) => `districts/${input.districtID}/tasks/${taskID}`,
      requiredCapability: null,
      auditDetails: (input) => ({ assigneeUserID: input.assigneeUserID, studentID: input.studentID, planID: input.planID, meetingID: input.meetingID }),
      mutate: async ({ transaction, membership, identity }) => {
        let schoolID: string | null = null;
        if (data.studentID !== null) {
          const student = await requireStudent(db, transaction, data.districtID, data.studentID);
          schoolID = student.schoolID;
          if (!canReadStudentDetail(membership, data.studentID, schoolID)) {
            throw new HttpsError("permission-denied", "This student is outside your access.");
          }
        }
        if (data.assigneeUserID !== identity.userID) {
          await requireAssignee(db, transaction, data.districtID, data.assigneeUserID, data.studentID, schoolID);
        }
        const now = Timestamp.fromDate(dependencies.now());
        transaction.create(db.doc(`districts/${data.districtID}/tasks/${taskID}`), {
          schemaVersion: 1,
          recordVersion: 1,
          kind: "followUp",
          districtId: data.districtID,
          title: data.title,
          details: data.details,
          status: "open",
          assigneeUserID: data.assigneeUserID,
          createdBy: identity.userID,
          dueDate,
          studentID: data.studentID,
          schoolID,
          planID: data.planID,
          meetingID: data.meetingID,
          outcome: null,
          completedAt: null,
          createdAt: now,
          updatedAt: now,
          updatedBy: identity.userID,
        });
        if (data.assigneeUserID !== identity.userID) {
          enqueueNotification(transaction, db, {
            districtID: data.districtID,
            recipientUserID: data.assigneeUserID,
            type: "task_assigned",
            title: "New task assigned to you",
            message: data.title,
            actionURL: "tmi://tasks",
            targetID: taskID,
            eventKey: `task-assigned-${taskID}`,
          }, now);
        }
        return { recordVersion: 1 };
      },
    });
    return { ...result, taskID };
  },

  updateTask: async (request: CallableRequest<unknown>): Promise<PrivilegedOperationResult> => {
    const raw = requireRecord(request.data);
    rejectUnexpectedFields(raw, new Set([
      "districtID", "expectedRecordVersion", "idempotencyKey", "reasonCode",
      "taskID", "status", "outcome", "title", "dueDate", "assigneeUserID",
    ]));
    const data: UpdateTaskRequest = {
      ...parseBaseRequest(raw),
      taskID: requireIdentifier(raw.taskID, "taskID"),
      status: requireEnum(raw.status, "status", taskStatuses),
      outcome: optionalText(raw.outcome, "outcome", 4_000),
      title: optionalText(raw.title, "title", 300),
      dueDate: raw.dueDate === undefined || raw.dueDate === null ? null : requireString(raw.dueDate, "dueDate", 64),
      assigneeUserID: raw.assigneeUserID === undefined || raw.assigneeUserID === null
        ? null
        : requireIdentifier(raw.assigneeUserID, "assigneeUserID"),
    };
    const dueDate = optionalDate(data.dueDate, "dueDate");
    const db = dependencies.firestore();
    return executePrivilegedOperation(db, request as CallableRequest<UpdateTaskRequest>, data, {
      action: "task.update",
      targetPath: (input) => `districts/${input.districtID}/tasks/${input.taskID}`,
      requiredCapability: null,
      auditDetails: (input) => ({ taskID: input.taskID, status: input.status, reassignedTo: input.assigneeUserID }),
      mutate: async ({ transaction, identity }) => {
        const reference = db.doc(`districts/${data.districtID}/tasks/${data.taskID}`);
        const snapshot = await transaction.get(reference);
        const existing = snapshot.data();
        if (!snapshot.exists || existing?.kind !== "followUp") {
          throw new HttpsError("not-found", "Task was not found.");
        }
        const isCreator = existing.createdBy === identity.userID;
        const isAssignee = existing.assigneeUserID === identity.userID;
        if (!isCreator && !isAssignee) {
          throw new HttpsError("permission-denied", "Only the task's owner or creator can change it.");
        }
        const reassigning = data.assigneeUserID !== null && data.assigneeUserID !== existing.assigneeUserID;
        if (reassigning && !isCreator) {
          throw new HttpsError("permission-denied", "Only the task's creator can reassign it.");
        }
        if (reassigning) {
          await requireAssignee(
            db, transaction, data.districtID, data.assigneeUserID!,
            typeof existing.studentID === "string" ? existing.studentID : null,
            typeof existing.schoolID === "string" ? existing.schoolID : null,
          );
        }
        const current = typeof existing.recordVersion === "number" ? existing.recordVersion : 1;
        if (current !== data.expectedRecordVersion) {
          throw new HttpsError("aborted", "The task changed since you opened it.", {
            kind: "record-version-conflict", expectedRecordVersion: data.expectedRecordVersion, actualRecordVersion: current,
          });
        }
        const now = Timestamp.fromDate(dependencies.now());
        transaction.update(reference, {
          recordVersion: current + 1,
          status: data.status,
          outcome: data.outcome ?? existing.outcome ?? null,
          title: data.title ?? existing.title,
          dueDate: data.dueDate === null ? existing.dueDate ?? null : dueDate,
          assigneeUserID: data.assigneeUserID ?? existing.assigneeUserID,
          completedAt: data.status === "open" ? null : existing.completedAt ?? now,
          updatedAt: now,
          updatedBy: identity.userID,
        });
        if (reassigning) {
          enqueueNotification(transaction, db, {
            districtID: data.districtID,
            recipientUserID: data.assigneeUserID!,
            type: "task_assigned",
            title: "A task was assigned to you",
            message: data.title ?? existing.title,
            actionURL: "tmi://tasks",
            targetID: data.taskID,
            eventKey: `task-assigned-${data.taskID}-${data.assigneeUserID}`,
          }, now);
        }
        return { recordVersion: current + 1 };
      },
    });
  },
});
