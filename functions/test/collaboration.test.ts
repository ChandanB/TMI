import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getFirestore } from "firebase-admin/firestore";
import { collection, doc, getDoc, getDocs, query, setDoc, where } from "firebase/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { createTask } from "../src/index.js";
import { createCollaborationHandlers, notificationID } from "../src/collaboration.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

const now = new Date("2026-09-22T15:00:00.000Z");
const handlers = createCollaborationHandlers({ firestore: () => getFirestore(), now: () => now });
const call = <T>(data: T, uid = "teacher"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);
const base = (key: string, version = 0) => ({ districtID: "d1", expectedRecordVersion: version, idempotencyKey: key, reasonCode: "collaboration" });

describe("collaboration", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    const writer = { capabilities: ["student.read.detail", "student.write.detail"], assignedStudentIDs: ["s1"] };
    await db.doc("districts/d1/members/teacher").set(activeMembership(writer));
    await db.doc("districts/d1/members/colleague").set(activeMembership(writer));
    await db.doc("districts/d1/members/counselor").set(activeMembership({
      role: "counselor",
      capabilities: ["student.read.detail", "student.write.detail", "student.restricted.read", "student.restricted.write"],
      assignedStudentIDs: ["s1"],
    }));
    await db.doc("districts/d1/members/outsider").set(activeMembership({ schoolIDs: ["school-2"], assignedStudentIDs: [] }));
    await db.doc("districts/d1/students/s1").set({ districtId: "d1", schoolId: "school-1", assignedMemberIDs: ["teacher", "colleague", "counselor"] });
  });

  it("exports callables", () => {
    expect(createTask.run).toBeTypeOf("function");
  });

  it("creates notes, lets only the author revise, and keeps revisions", async () => {
    const created = await handlers.saveStudentNote(call({ ...base("note-1"), studentID: "s1", category: "academic", body: "Reading more at home." }));
    expect(created.noteID).toBe("note-1");
    await expect(handlers.saveStudentNote(call({ ...base("note-1b", 1), studentID: "s1", noteID: "note-1", category: "academic", body: "Edited" }, "colleague")))
      .rejects.toMatchObject({ code: "permission-denied" });
    await handlers.saveStudentNote(call({ ...base("note-1c", 1), studentID: "s1", noteID: "note-1", category: "family", body: "Reading nightly with family." }));
    const list = await handlers.listStudentNotes(call({ districtID: "d1", studentID: "s1" }, "colleague"));
    expect(list.notes).toEqual([expect.objectContaining({ noteID: "note-1", category: "family", revisionCount: 1, isAuthor: false })]);
    const audit = JSON.stringify((await db.doc("districts/d1/auditEvents/note-1").get()).data());
    expect(audit).not.toContain("Reading more at home");
    await expect(handlers.listStudentNotes(call({ districtID: "d1", studentID: "s1" }, "outsider")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("keeps restricted records behind the capability and audits reads", async () => {
    await expect(handlers.createRestrictedRecord(call({ ...base("r1"), studentID: "s1", category: "safety", body: "Sensitive" })))
      .rejects.toMatchObject({ code: "permission-denied" });
    await handlers.createRestrictedRecord(call({ ...base("r2"), studentID: "s1", category: "safety", body: "Sensitive" }, "counselor"));
    const read = await handlers.listRestrictedRecords(call({ ...base("read-1"), studentID: "s1" }, "counselor"));
    expect(read.records).toEqual([expect.objectContaining({ recordID: "r2", body: "Sensitive" })]);
    expect((await db.doc("districts/d1/auditEvents/read-1").get()).data()).toMatchObject({ action: "student.restricted.read", actorUserID: "counselor" });
    const client = env.authenticatedContext("counselor", trustedClaims("d1")).firestore();
    await assertFails(getDoc(doc(client, "districts/d1/students/s1/restrictedRecords/r2")));
  });

  it("creates, notifies, reassigns, and completes tasks", async () => {
    const created = await handlers.createTask(call({ ...base("task-1"), title: "Call family about reading log", assigneeUserID: "colleague", dueDate: "2026-09-20T15:00:00.000Z", studentID: "s1" }));
    expect(created.taskID).toBe("task-1");
    const notification = (await db.doc(`districts/d1/notifications/${notificationID("colleague", "task-assigned-task-1")}`).get()).data();
    expect(notification).toMatchObject({ recipientUserID: "colleague", type: "task_assigned", isRead: false, title: "New task assigned to you" });

    const mine = await handlers.listTasks(call({ districtID: "d1" }, "colleague"));
    expect(mine.tasks).toEqual([expect.objectContaining({ taskID: "task-1", isOverdue: true, studentID: "s1" })]);

    await expect(handlers.updateTask(call({ ...base("u1", 1), taskID: "task-1", status: "open", assigneeUserID: "teacher" }, "colleague")))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(handlers.updateTask(call({ ...base("u2", 1), taskID: "task-1", status: "open", assigneeUserID: "outsider" })))
      .rejects.toMatchObject({ code: "failed-precondition" });
    await handlers.updateTask(call({ ...base("u3", 1), taskID: "task-1", status: "done", outcome: "Family agreed to nightly reading." }, "colleague"));
    const done = await handlers.listTasks(call({ districtID: "d1", studentID: "s1", includeClosed: true }));
    expect(done.tasks[0]).toMatchObject({ status: "done", outcome: "Family agreed to nightly reading.", isOverdue: false });
    const open = await handlers.listTasks(call({ districtID: "d1" }, "colleague"));
    expect(open.tasks).toHaveLength(0);
  });

  it("lets recipients read their notifications and blocks client writes to notes and tasks", async () => {
    await handlers.createTask(call({ ...base("task-2"), title: "Follow up", assigneeUserID: "colleague" }));
    const colleague = env.authenticatedContext("colleague", trustedClaims("d1")).firestore();
    await assertSucceeds(getDocs(query(collection(colleague, "districts/d1/notifications"), where("recipientUserID", "==", "colleague"))));
    await assertFails(setDoc(doc(colleague, "districts/d1/tasks/forged"), { createdBy: "colleague", assigneeUserID: "colleague" }));
    await assertFails(setDoc(doc(colleague, "districts/d1/students/s1/notes/forged"), { body: "x", authorUserID: "teacher" }));
  });
});
