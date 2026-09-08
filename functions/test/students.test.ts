import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import {
  archiveStudent,
  createStudent,
  createStudentClaimRefreshHandler,
  createGrantStudentDetailAccessHandler,
  createStudentMutationHandlers,
  drainStudentClaimRefresh,
  updateStudent,
  type ArchiveStudentRequest,
  type CreateStudentRequest,
  type UpdateStudentRequest,
} from "../src/index.js";
import {
  activeMembership,
  makeTestEnvironment,
  trustedClaims,
} from "./testEnvironment.js";

const districtID = "d1";
const schoolID = "school-1";

const callableRequest = <T>(
  data: T,
  options: {
    readonly uid?: string;
    readonly membershipVersion?: number;
    readonly requestDistrictID?: string;
    readonly includeAuth?: boolean;
    readonly includeAppCheck?: boolean;
  } = {},
): CallableRequest<T> => {
  const uid = options.uid ?? "teacher-1";
  const claims = trustedClaims(
    options.requestDistrictID ?? districtID,
    options.membershipVersion ?? 1,
  );
  return {
    data,
    auth:
      options.includeAuth === false
        ? undefined
        : {
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
  } as unknown as CallableRequest<T>;
};

const createRequest = (
  overrides: Partial<CreateStudentRequest> = {},
): CreateStudentRequest => ({
  districtID,
  schoolID,
  displayName: "Ava Stone",
  grade: "7",
  studentIdentifier: "0012",
  dateOfBirth: "2013-04-12T00:00:00.000Z",
  pronouns: "she/her",
  assignedMemberIDs: ["teacher-1"],
  expectedRecordVersion: 0,
  idempotencyKey: "create-student-1",
  reasonCode: "roster-create",
  ...overrides,
});

const updateRequest = (
  overrides: Partial<UpdateStudentRequest> = {},
): UpdateStudentRequest => ({
  districtID,
  studentID: "student-existing",
  schoolID,
  displayName: "Existing Student Updated",
  grade: "8",
  studentIdentifier: "existing-1",
  assignedMemberIDs: ["teacher-1"],
  expectedRecordVersion: 4,
  idempotencyKey: "update-student-1",
  reasonCode: "roster-update",
  ...overrides,
});

const archiveRequest = (
  overrides: Partial<ArchiveStudentRequest> = {},
): ArchiveStudentRequest => ({
  districtID,
  studentID: "student-existing",
  expectedRecordVersion: 4,
  idempotencyKey: "archive-student-1",
  reasonCode: "roster-archive",
  ...overrides,
});

const expectHttpsError = async (
  promise: Promise<unknown>,
  code: string,
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code });
};

describe("trusted student roster mutations", () => {
  let testEnv: RulesTestEnvironment;
  let firestore: Firestore;
  let refreshedUserIDs: string[];
  let handlers: ReturnType<typeof createStudentMutationHandlers>;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
    firestore = getFirestore();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    refreshedUserIDs = [];
    handlers = createStudentMutationHandlers({
      firestore,
      refreshTrustedClaimsForUser: async (userID) => {
        refreshedUserIDs.push(userID);
      },
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all([
        setDoc(
          doc(db, "districts/d1/members/teacher-1"),
          activeMembership({
            districtID,
            assignedStudentIDs: ["student-existing"],
            recordVersion: 1,
          }),
        ),
        setDoc(
          doc(db, "districts/d1/members/teacher-2"),
          activeMembership({
            districtID,
            assignedStudentIDs: [],
            recordVersion: 3,
            version: 3,
          }),
        ),
        setDoc(
          doc(db, "districts/d1/members/teacher-other-school"),
          activeMembership({
            districtID,
            schoolIDs: ["school-2"],
            assignedStudentIDs: [],
            recordVersion: 1,
          }),
        ),
        setDoc(
          doc(db, "districts/d1/members/admin-1"),
          activeMembership({
            districtID,
            role: "schoolAdministrator",
            capabilities: ["student.write.detail", "staff.manage"],
            assignedStudentIDs: [],
            recordVersion: 1,
          }),
        ),
        setDoc(
          doc(db, "districts/d2/members/teacher-d2"),
          activeMembership({
            districtID: "d2",
            schoolIDs: ["school-2"],
            assignedStudentIDs: [],
            recordVersion: 1,
          }),
        ),
        setDoc(doc(db, "districts/d1/students/student-existing"), {
          districtId: districtID,
          schoolId: schoolID,
          displayName: "Existing Student",
          normalizedDisplayName: "existing student",
          grade: "7",
          studentIdentifier: "existing-1",
          normalizedStudentIdentifier: "existing-1",
          assignedMemberIDs: ["teacher-1"],
          isArchived: false,
          schemaVersion: 1,
          recordVersion: 4,
        }),
        setDoc(doc(db, "districts/d1/students/student-unassigned"), {
          districtId: districtID,
          schoolId: schoolID,
          displayName: "Unassigned Student",
          normalizedDisplayName: "unassigned student",
          grade: "7",
          assignedMemberIDs: [],
          isArchived: false,
          schemaVersion: 1,
          recordVersion: 2,
        }),
        setDoc(doc(db, "districts/d1/students/student-archived-duplicate"), {
          districtId: districtID,
          schoolId: schoolID,
          displayName: "Ava Stone",
          normalizedDisplayName: "ava stone",
          grade: "7",
          studentIdentifier: "archived-identifier",
          normalizedStudentIdentifier: "archived-identifier",
          assignedMemberIDs: [],
          isArchived: true,
          schemaVersion: 1,
          recordVersion: 5,
        }),
      ]);
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("exports strict App Check callables", async () => {
    expect(createStudent.run).toBeTypeOf("function");
    expect(updateStudent.run).toBeTypeOf("function");
    expect(archiveStudent.run).toBeTypeOf("function");
    expect(drainStudentClaimRefresh.run).toBeTypeOf("function");

    await expectHttpsError(
      handlers.createStudent(
        callableRequest(createRequest(), { includeAppCheck: false }),
      ),
      "failed-precondition",
    );
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(createRequest(), { includeAuth: false }),
      ),
      "unauthenticated",
    );
  });

  it("retries only unfinished claim refresh users after a partial failure", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "districts/d1/studentClaimRefreshes/partial-refresh",
        ),
        {
          schemaVersion: 1,
          districtID,
          affectedUserIDs: ["teacher-1", "teacher-2", "teacher-3"],
        },
      );
    });
    const attempts: string[] = [];
    let teacher2ShouldFail = true;
    const drain = createStudentClaimRefreshHandler({
      firestore,
      refreshTrustedClaimsForUser: async (userID) => {
        attempts.push(userID);
        if (userID === "teacher-2" && teacher2ShouldFail) {
          teacher2ShouldFail = false;
          throw new Error("synthetic partial Auth outage");
        }
      },
    });

    await expect(
      drain({ districtID, operationID: "partial-refresh" }),
    ).rejects.toThrow("synthetic partial Auth outage");
    const partial = await firestore
      .doc("districts/d1/studentClaimRefreshes/partial-refresh")
      .get();
    expect(partial.get("completedUserIDs")).toEqual([
      "teacher-1",
      "teacher-3",
    ]);
    expect(partial.get("completedAt")).toBeUndefined();

    await drain({ districtID, operationID: "partial-refresh" });
    await drain({ districtID, operationID: "partial-refresh" });
    const completed = await firestore
      .doc("districts/d1/studentClaimRefreshes/partial-refresh")
      .get();
    expect(completed.get("completedUserIDs").sort()).toEqual([
      "teacher-1",
      "teacher-2",
      "teacher-3",
    ]);
    expect(completed.get("completedAt")).toBeDefined();
    expect(attempts.filter((userID) => userID === "teacher-1")).toHaveLength(1);
    expect(attempts.filter((userID) => userID === "teacher-2")).toHaveLength(2);
    expect(attempts.filter((userID) => userID === "teacher-3")).toHaveLength(1);
  });

  it("does not refresh an already completed claim task", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "districts/d1/studentClaimRefreshes/already-completed",
        ),
        {
          schemaVersion: 1,
          districtID,
          affectedUserIDs: ["teacher-1"],
          completedUserIDs: ["teacher-1"],
          completedAt: Timestamp.now(),
        },
      );
    });
    let refreshCount = 0;
    const drain = createStudentClaimRefreshHandler({
      firestore,
      refreshTrustedClaimsForUser: async () => {
        refreshCount += 1;
      },
    });

    await drain({ districtID, operationID: "already-completed" });

    expect(refreshCount).toBe(0);
  });

  it("creates a canonical assigned student, updates membership authority, and audits once", async () => {
    const result = await handlers.createStudent(
      callableRequest(
        createRequest({
          displayName: "  Ava   Rivera  ",
          grade: "  Grade   7 ",
          studentIdentifier: " 0013 ",
          idempotencyKey: "create-canonical-student",
        }),
      ),
    );

    expect(result).toMatchObject({
      operationID: "create-canonical-student",
      recordVersion: 1,
      replayed: false,
    });
    expect(result.membership).toEqual({
      districtID,
      schoolIDs: [schoolID],
      role: "teacher",
      capabilities: [],
      assignedStudentIDs: ["student-existing", result.studentID].sort(),
      isActive: true,
      version: 2,
    });
    expect(result.studentID).toMatch(/^student_[a-f0-9]{32}$/);
    expect(refreshedUserIDs).toEqual(["teacher-1"]);

    const [student, membership, audit] = await Promise.all([
      firestore.doc(`districts/d1/students/${result.studentID}`).get(),
      firestore.doc("districts/d1/members/teacher-1").get(),
      firestore.doc("districts/d1/auditEvents/create-canonical-student").get(),
    ]);
    expect(student.data()).toMatchObject({
      districtId: districtID,
      schoolId: schoolID,
      displayName: "Ava Rivera",
      normalizedDisplayName: "ava rivera",
      grade: "Grade 7",
      studentIdentifier: "0013",
      normalizedStudentIdentifier: "0013",
      pronouns: "she/her",
      assignedMemberIDs: ["teacher-1"],
      isArchived: false,
      schemaVersion: 1,
      recordVersion: 1,
      createdBy: "teacher-1",
      updatedBy: "teacher-1",
    });
    expect(student.get("dateOfBirth")?.toDate().toISOString()).toBe(
      "2013-04-12T00:00:00.000Z",
    );
    expect(membership.data()).toMatchObject({
      assignedStudentIDs: ["student-existing", result.studentID].sort(),
      version: 2,
      recordVersion: 2,
      updatedBy: "teacher-1",
    });
    expect(audit.data()).toMatchObject({
      action: "student.create",
      actorUserID: "teacher-1",
      districtID,
      targetPath: `districts/d1/students/${result.studentID}`,
      reasonCode: "roster-create",
      result: { recordVersion: 1 },
    });
  });

  it("safely replays create after the caller refreshes its incremented membership claim", async () => {
    const data = createRequest({
      displayName: "Replay Student",
      studentIdentifier: "replay-1",
      idempotencyKey: "create-replay-student",
    });
    const first = await handlers.createStudent(callableRequest(data));
    const replay = await handlers.createStudent(
      callableRequest(data, { membershipVersion: 2 }),
    );

    expect(replay).toEqual({ ...first, replayed: true });
    expect(refreshedUserIDs).toEqual(["teacher-1"]);
    const matching = await firestore
      .collection("districts/d1/students")
      .where("normalizedStudentIdentifier", "==", "replay-1")
      .get();
    expect(matching.size).toBe(1);
  });

  it("repairs post-commit claim refresh on an exact stale-claim replay only", async () => {
    let refreshAttempts = 0;
    handlers = createStudentMutationHandlers({
      firestore,
      refreshTrustedClaimsForUser: async () => {
        refreshAttempts += 1;
        if (refreshAttempts === 1) {
          throw new Error("synthetic Auth refresh outage");
        }
      },
    });
    const data = createRequest({
      displayName: "Refresh Recovery Student",
      grade: "9",
      studentIdentifier: "refresh-recovery-1",
      idempotencyKey: "create-refresh-recovery",
    });

    await expect(
      handlers.createStudent(callableRequest(data)),
    ).rejects.toThrow("synthetic Auth refresh outage");
    expect(refreshAttempts).toBe(1);
    expect(
      (await firestore.doc("districts/d1/members/teacher-1").get()).get(
        "version",
      ),
    ).toBe(2);

    const repairedReplay = await handlers.createStudent(
      callableRequest(data, { membershipVersion: 1 }),
    );
    const repeatedReplay = await handlers.createStudent(
      callableRequest(data, { membershipVersion: 1 }),
    );
    expect(repairedReplay).toMatchObject({
      replayed: true,
      membership: { version: 2 },
    });
    expect(repeatedReplay).toMatchObject({ replayed: true });
    expect(refreshAttempts).toBe(2);

    await expectHttpsError(
      handlers.createStudent(
        callableRequest(
          createRequest({
            displayName: "Different Stale Operation",
            studentIdentifier: "different-stale-operation",
            idempotencyKey: "different-stale-operation",
          }),
          { membershipVersion: 1 },
        ),
      ),
      "permission-denied",
    );
  });

  it("rejects cross-tenant, malformed, future-date, and self-promoted input", async () => {
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(createRequest({ districtID: "d2" })),
      ),
      "permission-denied",
    );
    await expectHttpsError(
      handlers.createStudent(
        callableRequest({ ...createRequest(), role: "districtAdministrator" } as never),
      ),
      "invalid-argument",
    );
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(createRequest({ displayName: "Bad\u0000Name" })),
      ),
      "invalid-argument",
    );
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(
          createRequest({ dateOfBirth: "2999-01-01T00:00:00.000Z" }),
        ),
      ),
      "invalid-argument",
    );
  });

  it("rejects duplicates within the school even when the candidate is archived", async () => {
    await expect(
      handlers.createStudent(callableRequest(createRequest())),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: {
        kind: "student-duplicate",
        candidateIDs: ["student-archived-duplicate"],
      },
    });

    await expect(
      handlers.createStudent(
        callableRequest(
          createRequest({
            displayName: "Different Name",
            grade: "10",
            studentIdentifier: "EXISTING-1",
          }),
        ),
      ),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: {
        kind: "student-duplicate",
        candidateIDs: ["student-existing"],
      },
    });
  });

  it("requires ordinary creators to assign themselves and prevents assignment expansion", async () => {
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(
          createRequest({
            displayName: "No Caller",
            studentIdentifier: "no-caller",
            assignedMemberIDs: [],
          }),
        ),
      ),
      "permission-denied",
    );
    await expectHttpsError(
      handlers.createStudent(
        callableRequest(
          createRequest({
            displayName: "Expanded Assignment",
            studentIdentifier: "expanded-assignment",
            assignedMemberIDs: ["teacher-1", "teacher-2"],
          }),
        ),
      ),
      "permission-denied",
    );
  });

  it("rejects create requests above the 200-member assignment cap", async () => {
    const assignedMemberIDs = Array.from(
      { length: 201 },
      (_, index) => `member-${index.toString().padStart(3, "0")}`,
    );

    await expectHttpsError(
      handlers.createStudent(
        callableRequest(
          createRequest({
            displayName: "Oversized Assignment",
            studentIdentifier: "oversized-assignment",
            assignedMemberIDs,
          }),
          { uid: "admin-1" },
        ),
      ),
      "invalid-argument",
    );
  });

  it("denies unassigned writes and stale versions without mutation", async () => {
    await expectHttpsError(
      handlers.updateStudent(
        callableRequest(
          updateRequest({
            studentID: "student-unassigned",
            expectedRecordVersion: 2,
          }),
        ),
      ),
      "permission-denied",
    );
    await expect(
      handlers.updateStudent(
        callableRequest(updateRequest({ expectedRecordVersion: 3 })),
      ),
    ).rejects.toMatchObject({
      code: "aborted",
      details: {
        kind: "record-version-conflict",
        expectedRecordVersion: 3,
        actualRecordVersion: 4,
      },
    });

    expect((await firestore.doc("districts/d1/students/student-existing").get()).get("recordVersion"))
      .toBe(4);
  });

  it("rejects updates when a legacy student already exceeds the assignment cap", async () => {
    const oversizedAssignments = Array.from(
      { length: 201 },
      (_, index) => `legacy-member-${index.toString().padStart(3, "0")}`,
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "districts/d1/students/student-legacy-cap"), {
        districtId: districtID,
        schoolId: schoolID,
        displayName: "Legacy Oversized",
        normalizedDisplayName: "legacy oversized",
        grade: "7",
        assignedMemberIDs: oversizedAssignments,
        isArchived: false,
        schemaVersion: 1,
        recordVersion: 1,
      });
    });

    await expectHttpsError(
      handlers.updateStudent(
        callableRequest(
          updateRequest({
            studentID: "student-legacy-cap",
            displayName: "Legacy Oversized Updated",
            studentIdentifier: "legacy-oversized",
            assignedMemberIDs: [],
            expectedRecordVersion: 1,
            idempotencyKey: "update-legacy-oversized",
          }),
          { uid: "admin-1" },
        ),
      ),
      "failed-precondition",
    );
  });

  it("supports a fully disjoint 200-member reassignment below the transaction ceiling", async () => {
    const previousMemberIDs = Array.from(
      { length: 200 },
      (_, index) => `old-member-${index.toString().padStart(3, "0")}`,
    );
    const nextMemberIDs = Array.from(
      { length: 200 },
      (_, index) => `new-member-${index.toString().padStart(3, "0")}`,
    );
    const studentID = "student-disjoint-cap";
    const batch = firestore.batch();
    for (const userID of previousMemberIDs) {
      batch.set(firestore.doc(`districts/d1/members/${userID}`), {
        ...activeMembership({
          districtID,
          assignedStudentIDs: [studentID],
        }),
        recordVersion: 1,
      });
    }
    for (const userID of nextMemberIDs) {
      batch.set(firestore.doc(`districts/d1/members/${userID}`), {
        ...activeMembership({ districtID, assignedStudentIDs: [] }),
        recordVersion: 1,
      });
    }
    batch.set(firestore.doc(`districts/d1/students/${studentID}`), {
      districtId: districtID,
      schoolId: schoolID,
      displayName: "Disjoint Cap Student",
      normalizedDisplayName: "disjoint cap student",
      grade: "8",
      studentIdentifier: "disjoint-cap",
      normalizedStudentIdentifier: "disjoint-cap",
      assignedMemberIDs: previousMemberIDs,
      isArchived: false,
      schemaVersion: 1,
      recordVersion: 1,
    });
    await batch.commit();

    const result = await handlers.updateStudent(
      callableRequest(
        updateRequest({
          studentID,
          displayName: "Disjoint Cap Student Updated",
          studentIdentifier: "disjoint-cap-updated",
          assignedMemberIDs: nextMemberIDs,
          expectedRecordVersion: 1,
          idempotencyKey: "update-disjoint-cap",
        }),
        { uid: "admin-1" },
      ),
    );

    expect(result.recordVersion).toBe(2);
    expect(refreshedUserIDs).toHaveLength(400);
    expect(
      (await firestore.doc(`districts/d1/students/${studentID}`).get()).get(
        "assignedMemberIDs",
      ),
    ).toEqual(nextMemberIDs);
    expect(
      (await firestore.doc("districts/d1/members/old-member-000").get()).data(),
    ).toMatchObject({ assignedStudentIDs: [], version: 2, recordVersion: 2 });
    expect(
      (await firestore.doc("districts/d1/members/new-member-199").get()).data(),
    ).toMatchObject({
      assignedStudentIDs: [studentID],
      version: 2,
      recordVersion: 2,
    });
  }, 120_000);

  it("grants student detail access by updating both assignment authorities", async () => {
    const refreshed: string[] = [];
    const grant = createGrantStudentDetailAccessHandler({
      firestore,
      refreshTrustedClaimsForUser: async (userID) => {
        refreshed.push(userID);
      },
    });

    const result = await grant(
      callableRequest(
        {
          districtID,
          targetUserID: "teacher-2",
          studentID: "student-existing",
          expectedRecordVersion: 3,
          idempotencyKey: "grant-student-detail-access",
          reasonCode: "staff-assignment",
        },
        { uid: "admin-1" },
      ),
    );

    expect(result).toMatchObject({ recordVersion: 4, replayed: false });
    expect(refreshed).toEqual(["teacher-2"]);
    const [membership, student, audit] = await Promise.all([
      firestore.doc("districts/d1/members/teacher-2").get(),
      firestore.doc("districts/d1/students/student-existing").get(),
      firestore.doc("districts/d1/auditEvents/grant-student-detail-access").get(),
    ]);
    expect(membership.data()).toMatchObject({
      assignedStudentIDs: ["student-existing"],
      version: 4,
      recordVersion: 4,
    });
    expect(student.data()).toMatchObject({
      assignedMemberIDs: ["teacher-1", "teacher-2"],
      recordVersion: 5,
      updatedBy: "admin-1",
    });
    expect(audit.data()).toMatchObject({
      action: "student.detailAccess.grant",
      result: { recordVersion: 4 },
    });

    const teacher2DB = testEnv
      .authenticatedContext("teacher-2", trustedClaims(districtID, 4))
      .firestore();
    await assertSucceeds(
      getDoc(doc(teacher2DB, "districts/d1/students/student-existing")),
    );
  });

  it("keeps student and membership assignments consistent in one administered update", async () => {
    const result = await handlers.updateStudent(
      callableRequest(
        updateRequest({
          assignedMemberIDs: ["teacher-2"],
          idempotencyKey: "admin-reassign-student",
        }),
        { uid: "admin-1" },
      ),
    );

    expect(result).toMatchObject({
      studentID: "student-existing",
      recordVersion: 5,
      replayed: false,
    });
    expect(refreshedUserIDs.sort()).toEqual(["teacher-1", "teacher-2"]);

    const [student, removedMember, addedMember, audit] = await Promise.all([
      firestore.doc("districts/d1/students/student-existing").get(),
      firestore.doc("districts/d1/members/teacher-1").get(),
      firestore.doc("districts/d1/members/teacher-2").get(),
      firestore.doc("districts/d1/auditEvents/admin-reassign-student").get(),
    ]);
    expect(student.data()).toMatchObject({
      assignedMemberIDs: ["teacher-2"],
      recordVersion: 5,
      updatedBy: "admin-1",
    });
    expect(removedMember.data()).toMatchObject({
      assignedStudentIDs: [],
      version: 2,
      recordVersion: 2,
    });
    expect(addedMember.data()).toMatchObject({
      assignedStudentIDs: ["student-existing"],
      version: 4,
      recordVersion: 4,
    });
    expect(audit.data()).toMatchObject({
      action: "student.update",
      targetPath: "districts/d1/students/student-existing",
      result: { recordVersion: 5 },
    });
  });

  it("rejects assignments to members outside the student's school", async () => {
    await expectHttpsError(
      handlers.updateStudent(
        callableRequest(
          updateRequest({
            assignedMemberIDs: ["teacher-other-school"],
          }),
          { uid: "admin-1" },
        ),
      ),
      "failed-precondition",
    );
  });

  it("rejects a school move when retained assignees lack the new school scope", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "districts/d1/members/admin-1"),
        { schoolIDs: ["school-1", "school-2"] },
      );
    });

    await expectHttpsError(
      handlers.updateStudent(
        callableRequest(
          updateRequest({
            schoolID: "school-2",
            assignedMemberIDs: ["teacher-1"],
            idempotencyKey: "move-student-school",
          }),
          { uid: "admin-1" },
        ),
      ),
      "failed-precondition",
    );
  });

  it("archives online through the audited callable and safely replays", async () => {
    const data = archiveRequest();
    const first = await handlers.archiveStudent(callableRequest(data));
    const replay = await handlers.archiveStudent(callableRequest(data));

    expect(first).toMatchObject({
      studentID: "student-existing",
      recordVersion: 5,
      replayed: false,
    });
    expect(replay).toEqual({ ...first, replayed: true });
    expect((await firestore.doc("districts/d1/students/student-existing").get()).data())
      .toMatchObject({ isArchived: true, recordVersion: 5 });
    expect((await firestore.doc("districts/d1/auditEvents/archive-student-1").get()).data())
      .toMatchObject({
        action: "student.archive",
        actorUserID: "teacher-1",
        result: { recordVersion: 5 },
      });
  });

  it("returns actionable version details for an archive conflict", async () => {
    await expect(
      handlers.archiveStudent(
        callableRequest(archiveRequest({ expectedRecordVersion: 2 })),
      ),
    ).rejects.toMatchObject({
      code: "aborted",
      details: {
        kind: "record-version-conflict",
        expectedRecordVersion: 2,
        actualRecordVersion: 4,
      },
    });
  });

  it("rejects replay-key reuse with changed student input", async () => {
    const data = archiveRequest();
    await handlers.archiveStudent(callableRequest(data));

    await expect(
      handlers.archiveStudent(
        callableRequest({ ...data, reasonCode: "different-reason" }),
      ),
    ).rejects.toMatchObject({
      code: "already-exists",
      details: { kind: "idempotency-key-reused" },
    });
  });
});

describe("student Firestore rules", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, "districts/d1/members/teacher-1"),
        activeMembership({
          districtID,
          schoolIDs: ["school-1"],
          assignedStudentIDs: ["student-assigned", "student-cross-school"],
        }),
      );
      await Promise.all([
        setDoc(doc(db, "districts/d1/students/student-assigned"), {
          districtId: districtID,
          schoolId: "school-1",
          displayName: "Assigned",
          assignedMemberIDs: ["teacher-1"],
        }),
        setDoc(doc(db, "districts/d1/students/student-unassigned"), {
          districtId: districtID,
          schoolId: "school-1",
          displayName: "Unassigned",
          assignedMemberIDs: [],
        }),
        setDoc(doc(db, "districts/d1/students/student-cross-school"), {
          districtId: districtID,
          schoolId: "school-2",
          displayName: "Cross School",
          assignedMemberIDs: ["teacher-1"],
        }),
      ]);
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("denies every direct client student create, update, and delete", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims(districtID))
      .firestore();

    await assertFails(
      setDoc(doc(db, "districts/d1/students/client-created"), {
        districtId: districtID,
        schoolId: schoolID,
        displayName: "Forged",
        assignedMemberIDs: ["teacher-1"],
      }),
    );
    await assertFails(
      updateDoc(doc(db, "districts/d1/students/student-assigned"), {
        displayName: "Forged Update",
      }),
    );
    await assertFails(
      deleteDoc(doc(db, "districts/d1/students/student-assigned")),
    );
  });

  it("allows school-wide teacher reads while preserving optional assignment filtering", async () => {
    const db = testEnv
      .authenticatedContext("teacher-1", trustedClaims(districtID))
      .firestore();
    const students = collection(db, "districts/d1/students");

    const schoolRoster = await assertSucceeds(
      getDocs(query(students, where("schoolId", "==", "school-1"))),
    );
    expect(schoolRoster.docs.map((snapshot) => snapshot.id).sort()).toEqual([
      "student-assigned",
      "student-unassigned",
    ]);

    const assignedInSchool = await assertSucceeds(
      getDocs(
        query(
          students,
          where("assignedMemberIDs", "array-contains", "teacher-1"),
          where("schoolId", "==", "school-1"),
        ),
      ),
    );
    expect(assignedInSchool.docs.map((snapshot) => snapshot.id)).toEqual([
      "student-assigned",
    ]);
    await assertFails(
      getDocs(
        query(
          students,
          where("assignedMemberIDs", "array-contains", "teacher-1"),
        ),
      ),
    );
    await assertSucceeds(getDoc(doc(db, "districts/d1/students/student-unassigned")));
    await assertFails(
      getDoc(doc(db, "districts/d1/students/student-cross-school")),
    );
  });
});
