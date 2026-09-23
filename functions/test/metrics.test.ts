import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";
import { exportDistrictReport, getDistrictReport } from "../src/index.js";
import {
  createMetricsHandlers,
  localDate,
  rateMetric,
  startOfLocalDay,
  weekStart,
  type MetricValue,
} from "../src/metrics.js";
import { activeMembership, makeTestEnvironment, trustedClaims } from "./testEnvironment.js";

// Fixed clock: 2026-09-22 12:00 UTC.
const now = Date.UTC(2026, 8, 22, 12);
const day = 86_400_000;
const at = (daysAgo: number) => Timestamp.fromMillis(now - daysAgo * day);

const handlers = createMetricsHandlers({ firestore: () => getFirestore(), now: () => now });
const call = <T>(data: T, uid = "district-admin"): CallableRequest<T> => ({
  data,
  auth: { uid, token: { uid, ...trustedClaims("d1") }, rawToken: "t" },
  app: { appId: "test-app" },
} as unknown as CallableRequest<T>);
const metric = (metrics: readonly MetricValue[], id: string) => metrics.find((item) => item.id === id);

describe("district reporting", () => {
  let env: RulesTestEnvironment;
  const db = getFirestore();

  beforeAll(async () => { env = await makeTestEnvironment(); });
  afterAll(async () => { await env.cleanup(); });

  beforeEach(async () => {
    await env.clearFirestore();
    await db.doc("districts/d1").set({ name: "Unified", programType: "k12" });
    await db.doc("districts/d1/schools/school-1").set({ name: "Lincoln Elementary" });
    await db.doc("districts/d1/schools/school-2").set({ name: "Sunshine Center", programType: "earlyChildhood" });
    await db.doc("districts/d1/members/district-admin").set(activeMembership({
      role: "districtAdministrator", schoolIDs: [], capabilities: ["report.export"], assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/members/school-admin").set(activeMembership({
      role: "schoolAdministrator", schoolIDs: ["school-1"], capabilities: [], assignedStudentIDs: [],
    }));
    await db.doc("districts/d1/members/teacher").set(activeMembership({ schoolIDs: ["school-1"] }));
    await db.doc("districts/d1/members/inactive").set(activeMembership({ schoolIDs: ["school-1"], isActive: false }));

    // school-1: six students (s1–s6) plus one archived; school-2: two children.
    for (let index = 1; index <= 6; index += 1) {
      await db.doc(`districts/d1/students/s${index}`).set({
        districtId: "d1", schoolId: "school-1", displayName: `Student ${index}`, grade: index <= 3 ? "3" : "4",
        assignedMemberIDs: index === 1 ? ["teacher"] : [],
      });
    }
    await db.doc("districts/d1/students/archived").set({ districtId: "d1", schoolId: "school-1", isArchived: true });
    await db.doc("districts/d1/students/c1").set({ districtId: "d1", schoolId: "school-2", displayName: "Child 1", ageGroup: "preschool3" });
    await db.doc("districts/d1/students/c2").set({ districtId: "d1", schoolId: "school-2", displayName: "Child 2", ageGroup: "preschool3" });

    // Surveys: s1 (in window), s2 (in window), s3 (draft only), archived (ignored).
    await db.doc("districts/d1/students/s1/responses/r1").set({ state: "submitted", submittedAt: at(3) });
    await db.doc("districts/d1/students/s2/responses/r1").set({ state: "reviewed", submittedAt: at(200) });
    await db.doc("districts/d1/students/s3/responses/r1").set({ state: "draft" });
    await db.doc("districts/d1/students/archived/responses/r1").set({ state: "submitted", submittedAt: at(1) });
    await db.doc("districts/d1/students/s1/interests/art").set({ name: "Art" });

    // Plans: s1 active, s2 approved 4 days after submission, s3 pending 10 days, school-2 plan draft.
    await db.doc("districts/d1/plans/p1").set({ status: "active", modelID: "alignYourMind", schoolIDs: ["school-1"], studentIDs: ["s1"] });
    await db.doc("districts/d1/plans/p2").set({
      status: "approved", modelID: "chaseYourSpace", schoolIDs: ["school-1"], studentIDs: ["s2"],
      submittedForApprovalAt: at(10), approvedAt: at(6),
    });
    await db.doc("districts/d1/plans/p3").set({ status: "pendingApproval", schoolIDs: ["school-1"], studentIDs: ["s3"], submittedForApprovalAt: at(10) });
    await db.doc("districts/d1/plans/p4").set({ status: "draft", schoolIDs: ["school-2"], studentIDs: ["c1"] });
    await db.doc("districts/d1/plans/p5").set({ status: "archived", schoolIDs: ["school-1"], studentIDs: ["s4"] });

    // Tasks: one overdue, one open future, one done on time, one done late.
    const task = (overrides: Record<string, unknown>) => ({ kind: "followUp", status: "open", studentID: "s1", dueDate: null, completedAt: null, ...overrides });
    await db.doc("districts/d1/tasks/t1").set(task({ dueDate: at(2) }));
    await db.doc("districts/d1/tasks/t2").set(task({ dueDate: at(-5), studentID: "s2" }));
    await db.doc("districts/d1/tasks/t3").set(task({ status: "done", dueDate: at(5), completedAt: at(6) }));
    await db.doc("districts/d1/tasks/t4").set(task({ status: "done", dueDate: at(9), completedAt: at(4) }));
    await db.doc("districts/d1/tasks/export").set({ kind: "export", status: "open", studentID: "s1", dueDate: at(9) });

    // Forms: one active assignment to s1–s3; s1 submitted.
    await db.doc("districts/d1/formAssignments/a1").set({ isActive: true, studentIDs: ["s1", "s2", "s3"] });
    await db.doc("districts/d1/formAssignments/a1/respondents/s1").set({ state: "submitted" });
    await db.doc("districts/d1/formAssignments/a1/respondents/s2").set({ state: "draft" });

    // Early childhood observations.
    await db.doc("districts/d1/students/c1/observations/o1").set({ createdAt: at(1) });
    await db.doc("districts/d1/students/c1/familyInputs/f1").set({ submittedAt: at(2) });
  });

  it("exports the callables", () => {
    expect(getDistrictReport.run).toBeTypeOf("function");
    expect(exportDistrictReport.run).toBeTypeOf("function");
  });

  it("computes the district-wide report from hand-calculated fixtures", async () => {
    const { report } = await handlers.getDistrictReport(call({ districtID: "d1", from: "2026-06-25", to: "2026-09-22", timeZone: "UTC" }));
    const value = (id: string) => metric(report.metrics, id);
    expect(value("sites.count")?.value).toBe(2);
    expect(value("staff.active")?.value).toBe(3);
    expect(value("students.served")?.value).toBe(8);
    expect(value("surveys.coverage")).toMatchObject({ numerator: 2, denominator: 8, value: 0.25 });
    expect(value("surveys.submitted")?.value).toBe(1);
    expect(value("interests.coverage")).toMatchObject({ numerator: 1, denominator: 8 });
    expect(value("plans.coverage")).toMatchObject({ numerator: 2, denominator: 8 });
    expect(value("plans.active")?.value).toBe(1);
    expect(value("plans.pendingApproval")?.value).toBe(1);
    expect(value("plans.pendingStale")?.value).toBe(1);
    expect(value("plans.approvalDays")).toMatchObject({ value: 4, status: "ok" });
    expect(value("tasks.open")?.value).toBe(2);
    expect(value("tasks.overdue")?.value).toBe(1);
    // Two completed with due dates is under the sample minimum.
    expect(value("tasks.onTime")?.status).toBe("insufficientSample");
    expect(value("forms.completion")?.status).toBe("insufficientSample");
    expect(value("ec.observations")?.value).toBe(1);
    expect(value("ec.familyInputs")?.value).toBe(1);
    expect(report.plansByStatus).toEqual({ active: 1, approved: 1, pendingApproval: 1, draft: 1 });
    expect(report.plansByModel).toEqual({ alignYourMind: 1, chaseYourSpace: 1 });
    expect(report.sites.map((site) => [site.schoolID, site.studentsServed.value])).toEqual([["school-1", 6], ["school-2", 2]]);
    expect(report.trend.reduce((total, week) => total + week.surveysSubmitted, 0)).toBe(1);
  });

  it("applies grade and staff filters", async () => {
    const graded = await handlers.getDistrictReport(call({ districtID: "d1", grade: "3", refresh: true }));
    expect(metric(graded.report.metrics, "students.served")?.value).toBe(3);
    const staffed = await handlers.getDistrictReport(call({ districtID: "d1", staffUserID: "teacher", refresh: true }));
    expect(metric(staffed.report.metrics, "students.served")?.value).toBe(1);
    expect(metric(staffed.report.metrics, "staff.active")?.value).toBe(1);
  });

  it("limits school administrators to their own sites and denies teachers", async () => {
    const own = await handlers.getDistrictReport(call({ districtID: "d1" }, "school-admin"));
    expect(own.report.scope.schoolIDs).toEqual(["school-1"]);
    expect(own.report.includesEarlyChildhood).toBe(false);
    expect(metric(own.report.metrics, "ec.observations")).toBeUndefined();
    await expect(handlers.getDistrictReport(call({ districtID: "d1", schoolID: "school-2" }, "school-admin")))
      .rejects.toMatchObject({ code: "permission-denied" });
    await expect(handlers.getDistrictReport(call({ districtID: "d1" }, "teacher")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("serves a fresh snapshot until asked to refresh", async () => {
    await handlers.getDistrictReport(call({ districtID: "d1", schoolID: "school-1" }));
    await db.doc("districts/d1/students/s7").set({ districtId: "d1", schoolId: "school-1" });
    const cached = await handlers.getDistrictReport(call({ districtID: "d1", schoolID: "school-1" }));
    expect(metric(cached.report.metrics, "students.served")?.value).toBe(6);
    const refreshed = await handlers.getDistrictReport(call({ districtID: "d1", schoolID: "school-1", refresh: true }));
    expect(metric(refreshed.report.metrics, "students.served")?.value).toBe(7);
  });

  it("exports an audited CSV that needs the export capability", async () => {
    const result = await handlers.exportDistrictReport(call({ districtID: "d1", format: "csv" }));
    expect(result.csv).toContain("Metric dictionary version,1");
    expect(result.csv).toContain("Interest survey coverage,25%,2,8,ok");
    expect(result.csv).toContain("Suppressed (fewer than 5)");
    const audits = await db.collection("districts/d1/auditEvents").where("action", "==", "report.district.export").get();
    expect(audits.size).toBe(1);
    await expect(handlers.exportDistrictReport(call({ districtID: "d1", format: "csv" }, "school-admin")))
      .rejects.toMatchObject({ code: "permission-denied" });
  });

  it("lists students needing attention within detail scope and audits the drill-down", async () => {
    const result = await handlers.listStudentsNeedingAttention(call({ districtID: "d1", schoolID: "school-1" }, "school-admin"));
    const byID = new Map(result.students.map((student) => [student.studentID, student.reasons]));
    expect(byID.get("s1")).toEqual(["overdueFollowUp"]);
    expect(byID.get("s3")).toEqual(["noSurvey", "noPlan", "approvalWaiting"]);
    expect(byID.has("s2")).toBe(false);
    expect(byID.has("archived")).toBe(false);
    const audits = await db.collection("districts/d1/auditEvents").where("action", "==", "report.student.drilldown").get();
    expect(audits.docs[0]?.data().details.studentIDs).toContain("s3");
  });

  it("handles time zones, week starts, and suppression", () => {
    expect(startOfLocalDay("2026-03-08", "America/New_York")).toBe(Date.UTC(2026, 2, 8, 5));
    expect(startOfLocalDay("2026-03-09", "America/New_York")).toBe(Date.UTC(2026, 2, 9, 4));
    expect(localDate(Date.UTC(2026, 8, 22, 3), "America/Los_Angeles")).toBe("2026-09-21");
    expect(weekStart("2026-09-27")).toBe("2026-09-21");
    expect(rateMetric("x", 1, 4).status).toBe("insufficientSample");
    expect(rateMetric("x", 0, 5)).toMatchObject({ value: 0, status: "zero" });
  });

  it("rejects malformed windows", async () => {
    await expect(handlers.getDistrictReport(call({ districtID: "d1", from: "2026-09-30", to: "2026-09-01" })))
      .rejects.toMatchObject({ code: "invalid-argument" });
    await expect(handlers.getDistrictReport(call({ districtID: "d1", timeZone: "Mars/Olympus" })))
      .rejects.toMatchObject({ code: "invalid-argument" });
  });
});
