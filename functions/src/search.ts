import type { DocumentData, Firestore } from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  assertDistrict,
  canReadStudentDetail,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireIdentifier,
  requireRecord,
  requireString,
  requireTrustedMembership,
  type TrustedMembership,
} from "./authz.js";

/**
 * Authorized workspace search and colleague lookup. Everything is filtered on
 * the server against the caller's membership before it is returned, so search
 * can never reveal a record the caller couldn't open.
 */

export const normalizeQuery = (value: string): string =>
  value.trim().split(/\s+/u).join(" ").normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();

export interface SearchDependencies {
  readonly firestore: () => Firestore;
  readonly getUsers: (userIDs: readonly string[]) => Promise<readonly { userID: string; displayName?: string | undefined; email?: string | undefined }[]>;
}

const canReadPlan = (membership: TrustedMembership, plan: DocumentData): boolean => {
  const schoolIDs: string[] = Array.isArray(plan.schoolIDs) ? plan.schoolIDs : [];
  const assigned: string[] = Array.isArray(plan.assignedMemberIDs) ? plan.assignedMemberIDs : [];
  switch (membership.role) {
    case "districtAdministrator":
      return true;
    case "teacher":
    case "schoolAdministrator":
      return assigned.includes(membership.userID) || schoolIDs.some((schoolID) => membership.schoolIDs.has(schoolID));
    case "counselor":
    case "socialWorker":
      return assigned.includes(membership.userID);
  }
};

const matches = (value: unknown, query: string): boolean =>
  typeof value === "string" && normalizeQuery(value).includes(query);

let careerCache: { loadedAt: number; items: { id: string; title: string; category: string }[] } | undefined;

const careers = async (firestore: Firestore) => {
  if (careerCache !== undefined && Date.now() - careerCache.loadedAt < 10 * 60_000) return careerCache.items;
  const snapshot = await firestore.collection("catalogs/careers/items").limit(2_000).get();
  careerCache = {
    loadedAt: Date.now(),
    items: snapshot.docs
      .filter((document) => document.data().isApproved !== false && document.data().isActive !== false)
      .map((document) => ({
        id: document.id,
        title: typeof document.data().title === "string" ? document.data().title : document.id,
        category: typeof document.data().category === "string" ? document.data().category : "",
      })),
  };
  return careerCache.items;
};

export const createSearchHandlers = (dependencies: SearchDependencies) => ({
  searchWorkspace: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "query", "includeCareers"]));
    const districtID = requireIdentifier(data.districtID, "districtID");
    const query = normalizeQuery(requireString(data.query, "query", 100));
    if (query.length < 2) {
      throw new HttpsError("invalid-argument", "Type at least two characters.");
    }
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, districtID);
    const db = dependencies.firestore();
    const membership = await db.runTransaction(
      (transaction) => requireTrustedMembership(db, transaction, identity),
      { readOnly: true },
    );
    const district = db.doc(`districts/${districtID}`);

    const [byName, byIdentifier, plansSnapshot, resourcesSnapshot] = await Promise.all([
      district.collection("students")
        .where("normalizedDisplayName", ">=", query)
        .where("normalizedDisplayName", "<", `${query}`)
        .limit(50).get(),
      district.collection("students")
        .where("normalizedStudentIdentifier", "==", query)
        .limit(10).get(),
      district.collection("plans").limit(300).get(),
      district.collection("resources").limit(300).get(),
    ]);

    const studentsByID = new Map<string, DocumentData>();
    for (const document of [...byName.docs, ...byIdentifier.docs]) {
      const student = document.data();
      if (student.isArchived === true) continue;
      if (canReadStudentDetail(membership, document.id, student.schoolId)) {
        studentsByID.set(document.id, student);
      }
    }
    const students = [...studentsByID.entries()].slice(0, 10).map(([id, student]) => ({
      id,
      title: typeof student.displayName === "string" ? student.displayName : "Student",
      subtitle: typeof student.grade === "string" ? student.grade : "",
      schoolID: typeof student.schoolId === "string" ? student.schoolId : "",
    }));

    const plans = plansSnapshot.docs
      .filter((document) => {
        const plan = document.data();
        const studentIDs: string[] = Array.isArray(plan.studentIDs) ? plan.studentIDs : [];
        return canReadPlan(membership, plan) &&
          (matches(plan.title, query) || studentIDs.some((id) => studentsByID.has(id)));
      })
      .slice(0, 10)
      .map((document) => ({
        id: document.id,
        title: typeof document.data().title === "string" ? document.data().title : "Plan",
        subtitle: typeof document.data().status === "string" ? document.data().status : "",
        studentID: Array.isArray(document.data().studentIDs) ? document.data().studentIDs[0] ?? null : null,
      }));

    const resources = resourcesSnapshot.docs
      .filter((document) => {
        const resource = document.data();
        const schoolID = resource.schoolId;
        const inScope = schoolID === undefined || schoolID === null ||
          membership.role === "districtAdministrator" || membership.schoolIDs.has(schoolID);
        return inScope && (matches(resource.title, query) || matches(resource.description, query));
      })
      .slice(0, 10)
      .map((document) => ({
        id: document.id,
        title: typeof document.data().title === "string" ? document.data().title : "Resource",
        subtitle: typeof document.data().category === "string" ? document.data().category : "",
        url: typeof document.data().url === "string" ? document.data().url : null,
      }));

    const careerResults = data.includeCareers === false
      ? []
      : (await careers(db))
          .filter((career) => normalizeQuery(career.title).includes(query))
          .slice(0, 10)
          .map((career) => ({ id: career.id, title: career.title, subtitle: career.category }));

    return { students, plans, resources, careers: careerResults };
  },

  /** Active colleagues the caller can hand work to, optionally for one student. */
  listColleagues: async (request: CallableRequest<unknown>) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set(["districtID", "studentID"]));
    const districtID = requireIdentifier(data.districtID, "districtID");
    const studentID = data.studentID === undefined || data.studentID === null
      ? null
      : requireIdentifier(data.studentID, "studentID");
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, districtID);
    const db = dependencies.firestore();
    const { membership, schoolID } = await db.runTransaction(async (transaction) => {
      const membership = await requireTrustedMembership(db, transaction, identity);
      if (studentID === null) return { membership, schoolID: null as string | null };
      const student = await transaction.get(db.doc(`districts/${districtID}/students/${studentID}`));
      const schoolID = student.data()?.schoolId;
      if (!student.exists || !canReadStudentDetail(membership, studentID, schoolID)) {
        throw new HttpsError("permission-denied", "This student is outside your access.");
      }
      return { membership, schoolID: schoolID as string };
    }, { readOnly: true });
    const members = await db.collection(`districts/${districtID}/members`).where("isActive", "==", true).limit(500).get();
    const eligible = members.docs.filter((document) => {
      const member = document.data();
      const schoolIDs: string[] = Array.isArray(member.schoolIDs) ? member.schoolIDs : [];
      if (member.role === "districtAdministrator") return true;
      const target = schoolID ?? null;
      return target !== null
        ? schoolIDs.includes(target)
        : schoolIDs.some((id) => membership.schoolIDs.has(id)) || membership.role === "districtAdministrator";
    });
    const users = await dependencies.getUsers(eligible.map((document) => document.id));
    const names = new Map(users.map((user) => [user.userID, user.displayName ?? user.email ?? null]));
    return {
      colleagues: eligible
        .map((document) => ({
          userID: document.id,
          displayName: names.get(document.id) ?? "Staff member",
          role: typeof document.data().role === "string" ? document.data().role : "teacher",
          isSelf: document.id === identity.userID,
        }))
        .sort((left, right) => left.displayName.localeCompare(right.displayName)),
    };
  },
});
