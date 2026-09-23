import { createHash } from "node:crypto";
import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Firestore,
} from "firebase-admin/firestore";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import {
  assertDistrict,
  canReadStudentDetail,
  isValidIdentifier,
  parseTrustedCallableIdentity,
  rejectUnexpectedFields,
  requireBoolean,
  requireEnum,
  requireIdentifier,
  requireRecord,
  requireString,
  requireTrustedMembership,
  type TrustedMembership,
} from "./authz.js";

/**
 * District reporting.
 *
 * Every number the dashboard and exports show is computed here, on the
 * server, from canonical records, using one versioned metric dictionary.
 * Results are cached as server-owned `metricSnapshots` (clients cannot read
 * or write them directly) so dashboards and exports of the same scope agree.
 *
 * Rates whose denominator is smaller than `minimumSample` are suppressed:
 * the value is withheld and marked `insufficientSample`, so a small group
 * can't be singled out.
 */

export const metricDictionaryVersion = 1;
export const minimumSample = 5;
const snapshotFreshnessMs = 10 * 60_000;
const maximumStudents = 1_500;
const maximumAssignments = 300;
const staleApprovalDays = 7;

type Unit = "count" | "rate" | "days";
type Window = "current" | "window";

export interface MetricDefinition {
  readonly id: string;
  readonly label: string;
  readonly unit: Unit;
  readonly window: Window;
  readonly numerator: string;
  readonly denominator: string | null;
  readonly earlyChildhoodOnly?: boolean;
}

export const metricDictionary: readonly MetricDefinition[] = [
  { id: "sites.count", label: "Sites", unit: "count", window: "current", numerator: "Schools or centers in the selected scope.", denominator: null },
  { id: "staff.active", label: "Active staff", unit: "count", window: "current", numerator: "Active memberships assigned to at least one site in scope. District administrators count only at district scope.", denominator: null },
  { id: "students.served", label: "Students served", unit: "count", window: "current", numerator: "Students in scope who are not archived and match the grade and staff filters.", denominator: null },
  { id: "surveys.coverage", label: "Interest survey coverage", unit: "rate", window: "current", numerator: "Students served with at least one submitted interest survey.", denominator: "Students served." },
  { id: "surveys.submitted", label: "Surveys submitted", unit: "count", window: "window", numerator: "Interest surveys submitted during the window by students served.", denominator: null },
  { id: "interests.coverage", label: "Interests confirmed", unit: "rate", window: "current", numerator: "Students served with at least one approved interest.", denominator: "Students served." },
  { id: "plans.coverage", label: "Students with a plan", unit: "rate", window: "current", numerator: "Students served named on at least one approved or active plan.", denominator: "Students served." },
  { id: "plans.active", label: "Active plans", unit: "count", window: "current", numerator: "Plans in scope whose status is active.", denominator: null },
  { id: "plans.pendingApproval", label: "Awaiting approval", unit: "count", window: "current", numerator: "Plans in scope waiting for approval.", denominator: null },
  { id: "plans.pendingStale", label: "Awaiting approval over 7 days", unit: "count", window: "current", numerator: "Plans waiting for approval for more than 7 days.", denominator: null },
  { id: "plans.approvalDays", label: "Median days to approval", unit: "days", window: "window", numerator: "Median days from submission for approval to approval, for plans approved during the window.", denominator: null },
  { id: "plans.completed", label: "Plans completed", unit: "count", window: "window", numerator: "Plans in scope marked completed during the window.", denominator: null },
  { id: "tasks.open", label: "Open follow-ups", unit: "count", window: "current", numerator: "Open follow-up tasks linked to students served.", denominator: null },
  { id: "tasks.overdue", label: "Overdue follow-ups", unit: "count", window: "current", numerator: "Open follow-up tasks linked to students served whose due date has passed.", denominator: null },
  { id: "tasks.onTime", label: "Follow-ups closed on time", unit: "rate", window: "window", numerator: "Follow-ups marked done during the window on or before their due date.", denominator: "Follow-ups with a due date marked done during the window." },
  { id: "forms.completion", label: "Form completion", unit: "rate", window: "current", numerator: "Assigned form responses submitted or reviewed.", denominator: "Form responses assigned to students served on active assignments." },
  { id: "ec.observations", label: "Observations logged", unit: "count", window: "window", numerator: "Caregiver interest observations recorded during the window.", denominator: null, earlyChildhoodOnly: true },
  { id: "ec.familyInputs", label: "Family input received", unit: "count", window: "window", numerator: "Family \"All About Me\" forms received during the window.", denominator: null, earlyChildhoodOnly: true },
];

export type MetricStatus = "ok" | "zero" | "insufficientSample" | "noData";

export interface MetricValue {
  readonly id: string;
  readonly value: number | null;
  readonly numerator: number | null;
  readonly denominator: number | null;
  readonly status: MetricStatus;
}

export interface ReportScope {
  readonly districtID: string;
  readonly schoolIDs: readonly string[];
  readonly isDistrictWide: boolean;
  readonly from: string;
  readonly to: string;
  readonly timeZone: string;
  readonly grade: string | null;
  readonly staffUserID: string | null;
}

// Time helpers ---------------------------------------------------------------

const datePattern = /^\d{4}-\d{2}-\d{2}$/u;

const zoneOffsetMs = (instant: number, timeZone: string): number => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  }).formatToParts(new Date(instant));
  const part = (type: string) => Number(parts.find((item) => item.type === type)?.value ?? 0);
  return Date.UTC(part("year"), part("month") - 1, part("day"), part("hour"), part("minute"), part("second")) - instant;
};

/** The instant a local calendar day starts in `timeZone`. */
export const startOfLocalDay = (date: string, timeZone: string): number => {
  const [year, month, day] = date.split("-").map(Number) as [number, number, number];
  const guess = Date.UTC(year, month - 1, day);
  const first = guess - zoneOffsetMs(guess, timeZone);
  return guess - zoneOffsetMs(first, timeZone);
};

/** The local calendar date of `instant` in `timeZone`, as YYYY-MM-DD. */
export const localDate = (instant: number, timeZone: string): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(instant));

const addDays = (date: string, days: number): string => {
  const [year, month, day] = date.split("-").map(Number) as [number, number, number];
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
};

/** Monday of the week containing `date`. */
export const weekStart = (date: string): string => {
  const [year, month, day] = date.split("-").map(Number) as [number, number, number];
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return addDays(date, -((weekday + 6) % 7));
};

const millis = (value: unknown): number | null => {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
};

const median = (values: readonly number[]): number | null => {
  if (values.length === 0) return null;
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1]! + sorted[middle]!) / 2 : sorted[middle]!;
};

// Metric value helpers -------------------------------------------------------

export const countMetric = (id: string, value: number): MetricValue =>
  ({ id, value, numerator: value, denominator: null, status: value === 0 ? "zero" : "ok" });

export const rateMetric = (id: string, numerator: number, denominator: number): MetricValue => {
  if (denominator < minimumSample) {
    return { id, value: null, numerator: null, denominator: null, status: "insufficientSample" };
  }
  return {
    id,
    value: Math.round((numerator / denominator) * 1000) / 1000,
    numerator,
    denominator,
    status: numerator === 0 ? "zero" : "ok",
  };
};

const daysMetric = (id: string, values: readonly number[]): MetricValue => {
  const value = median(values);
  return value === null
    ? { id, value: null, numerator: null, denominator: null, status: "noData" }
    : { id, value: Math.round(value * 10) / 10, numerator: null, denominator: values.length, status: "ok" };
};

// Request parsing ------------------------------------------------------------

const requestFields = ["districtID", "schoolID", "from", "to", "timeZone", "grade", "staffUserID", "refresh"];

interface ReportRequest {
  readonly districtID: string;
  readonly schoolID: string | null;
  readonly from: string;
  readonly to: string;
  readonly timeZone: string;
  readonly grade: string | null;
  readonly staffUserID: string | null;
  readonly refresh: boolean;
}

const optionalIdentifier = (value: unknown, field: string): string | null =>
  value === undefined || value === null ? null : requireIdentifier(value, field);

const parseReportRequest = (data: Record<string, unknown>, now: number): ReportRequest => {
  const timeZone = data.timeZone === undefined ? "UTC" : requireString(data.timeZone, "timeZone", 64);
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
  } catch {
    throw new HttpsError("invalid-argument", "timeZone must be an IANA time zone.");
  }
  const today = localDate(now, timeZone);
  const to = data.to === undefined ? today : requireString(data.to, "to", 10);
  const from = data.from === undefined ? addDays(to, -89) : requireString(data.from, "from", 10);
  if (!datePattern.test(from) || !datePattern.test(to) || from > to) {
    throw new HttpsError("invalid-argument", "from and to must be YYYY-MM-DD dates with from on or before to.");
  }
  if (startOfLocalDay(to, timeZone) - startOfLocalDay(from, timeZone) > 366 * 86_400_000) {
    throw new HttpsError("invalid-argument", "Reports cover at most one year.");
  }
  const grade = data.grade === undefined || data.grade === null ? null : requireString(data.grade, "grade", 40);
  return {
    districtID: requireIdentifier(data.districtID, "districtID"),
    schoolID: optionalIdentifier(data.schoolID, "schoolID"),
    from,
    to,
    timeZone,
    grade,
    staffUserID: optionalIdentifier(data.staffUserID, "staffUserID"),
    refresh: data.refresh === undefined ? false : requireBoolean(data.refresh, "refresh"),
  };
};

/**
 * Aggregate access: district administrators see any scope; school
 * administrators see only their own sites. Aggregate access never implies
 * access to an individual student's record.
 */
export const resolveReportSites = async (
  firestore: Firestore,
  membership: TrustedMembership,
  districtID: string,
  schoolID: string | null,
): Promise<{ schoolIDs: string[]; isDistrictWide: boolean }> => {
  if (membership.role !== "districtAdministrator" && membership.role !== "schoolAdministrator") {
    throw new HttpsError("permission-denied", "Reports are available to school and district administrators.");
  }
  if (schoolID !== null) {
    if (membership.role !== "districtAdministrator" && !membership.schoolIDs.has(schoolID)) {
      throw new HttpsError("permission-denied", "That site is outside your scope.");
    }
    const school = await firestore.doc(`districts/${districtID}/schools/${schoolID}`).get();
    if (!school.exists) throw new HttpsError("not-found", "That site does not exist.");
    return { schoolIDs: [schoolID], isDistrictWide: false };
  }
  if (membership.role === "districtAdministrator") {
    const schools = await firestore.collection(`districts/${districtID}/schools`).limit(500).get();
    return { schoolIDs: schools.docs.map((document) => document.id).sort(), isDistrictWide: true };
  }
  return { schoolIDs: [...membership.schoolIDs].sort(), isDistrictWide: false };
};

// Computation ----------------------------------------------------------------

const inBatches = async <T, R>(items: readonly T[], size: number, work: (item: T) => Promise<R>): Promise<R[]> => {
  const results: R[] = [];
  for (let index = 0; index < items.length; index += size) {
    results.push(...await Promise.all(items.slice(index, index + size).map(work)));
  }
  return results;
};

interface StudentFacts {
  readonly id: string;
  readonly schoolID: string;
  readonly surveySubmittedAt: number[];
  readonly hasApprovedInterest: boolean;
  readonly observationsAt: number[];
  readonly familyInputsAt: number[];
}

export interface DistrictReport {
  readonly dictionaryVersion: number;
  readonly scope: ReportScope;
  readonly computedAt: string;
  readonly isPartial: boolean;
  readonly includesEarlyChildhood: boolean;
  readonly metrics: readonly MetricValue[];
  readonly plansByStatus: Readonly<Record<string, number>>;
  readonly plansByModel: Readonly<Record<string, number>>;
  readonly trend: readonly { week: string; surveysSubmitted: number; plansApproved: number; tasksCompleted: number; observations: number }[];
  readonly sites: readonly {
    schoolID: string;
    name: string;
    programType: string;
    studentsServed: MetricValue;
    activePlans: MetricValue;
    planCoverage: MetricValue;
    surveyCoverage: MetricValue;
    overdueTasks: MetricValue;
  }[];
}

export const computeDistrictReport = async (
  firestore: Firestore,
  scope: ReportScope,
  now: number,
): Promise<DistrictReport> => {
  const district = firestore.doc(`districts/${scope.districtID}`);
  const windowStart = startOfLocalDay(scope.from, scope.timeZone);
  const windowEnd = startOfLocalDay(addDays(scope.to, 1), scope.timeZone);
  const inWindow = (instant: number | null): instant is number =>
    instant !== null && instant >= windowStart && instant < windowEnd;
  const sites = new Set(scope.schoolIDs);

  const [districtDocument, schoolDocuments, members, studentDocuments, planDocuments, taskDocuments, assignmentDocuments] = await Promise.all([
    district.get(),
    Promise.all(scope.schoolIDs.map((schoolID) => district.collection("schools").doc(schoolID).get())),
    district.collection("members").where("isActive", "==", true).limit(2_000).get(),
    district.collection("students").limit(maximumStudents + 1).get(),
    district.collection("plans").limit(2_000).get(),
    district.collection("tasks").where("kind", "==", "followUp").limit(2_000).get(),
    district.collection("formAssignments").limit(maximumAssignments).get(),
  ]);

  const organizationProgram = districtDocument.data()?.programType === "earlyChildhood" ? "earlyChildhood" : "k12";
  const siteInfo = schoolDocuments.map((document) => ({
    schoolID: document.id,
    name: typeof document.data()?.name === "string" ? document.data()!.name as string : document.id,
    programType: document.data()?.programType === "earlyChildhood" || document.data()?.programType === "k12"
      ? document.data()!.programType as string
      : organizationProgram,
  }));
  const includesEarlyChildhood = siteInfo.some((site) => site.programType === "earlyChildhood");

  const served = studentDocuments.docs.filter((document) => {
    const student = document.data();
    if (student.isArchived === true || !sites.has(student.schoolId)) return false;
    if (scope.grade !== null && student.grade !== scope.grade && student.ageGroup !== scope.grade) return false;
    if (scope.staffUserID !== null) {
      const assigned: unknown[] = Array.isArray(student.assignedMemberIDs) ? student.assignedMemberIDs : [];
      if (!assigned.includes(scope.staffUserID)) return false;
    }
    return true;
  });
  const servedIDs = new Set(served.map((document) => document.id));
  const isPartial = studentDocuments.size > maximumStudents || assignmentDocuments.size >= maximumAssignments;

  const facts: StudentFacts[] = await inBatches(served.slice(0, maximumStudents), 25, async (document) => {
    const student = firestore.doc(document.ref.path);
    const schoolID = document.data().schoolId as string;
    const isEarlyChildhood = siteInfo.find((site) => site.schoolID === schoolID)?.programType === "earlyChildhood";
    const [responses, interests, observations, familyInputs] = await Promise.all([
      student.collection("responses").where("state", "in", ["submitted", "reviewed"]).select("submittedAt").get(),
      student.collection("interests").limit(1).select().get(),
      isEarlyChildhood ? student.collection("observations").select("createdAt").get() : undefined,
      isEarlyChildhood ? student.collection("familyInputs").select("submittedAt").get() : undefined,
    ]);
    return {
      id: document.id,
      schoolID,
      surveySubmittedAt: responses.docs.map((item) => millis(item.data().submittedAt)).filter((value): value is number => value !== null),
      hasApprovedInterest: !interests.empty,
      observationsAt: observations?.docs.map((item) => millis(item.data().createdAt)).filter((value): value is number => value !== null) ?? [],
      familyInputsAt: familyInputs?.docs.map((item) => millis(item.data().submittedAt)).filter((value): value is number => value !== null) ?? [],
    };
  });

  const plans = planDocuments.docs
    .map((document) => ({ id: document.id, ...document.data() }) as DocumentData & { id: string })
    .filter((plan) => {
      if (plan.status === "archived") return false;
      const schoolIDs: unknown[] = Array.isArray(plan.schoolIDs) ? plan.schoolIDs : [plan.schoolId];
      if (!schoolIDs.some((schoolID) => typeof schoolID === "string" && sites.has(schoolID))) return false;
      if (scope.grade !== null || scope.staffUserID !== null) {
        const studentIDs: unknown[] = Array.isArray(plan.studentIDs) ? plan.studentIDs : [];
        return studentIDs.some((studentID) => typeof studentID === "string" && servedIDs.has(studentID));
      }
      return true;
    });
  const planStudents = (plan: DocumentData): string[] =>
    (Array.isArray(plan.studentIDs) ? plan.studentIDs : []).filter((id: unknown): id is string => typeof id === "string");

  const tasks = taskDocuments.docs
    .map((document) => document.data())
    .filter((task) => typeof task.studentID === "string" && servedIDs.has(task.studentID));
  const taskDue = (task: DocumentData): number | null => {
    const due = millis(task.dueDate);
    if (due === null) return null;
    // Due dates are whole days: a task is on time through the end of its due day.
    return startOfLocalDay(addDays(localDate(due, scope.timeZone), 1), scope.timeZone);
  };
  const isOverdue = (task: DocumentData): boolean => {
    const due = taskDue(task);
    return task.status === "open" && due !== null && due <= now;
  };

  // Form completion: one response per (active assignment, served student).
  let formsAssigned = 0;
  let formsSubmitted = 0;
  const activeAssignments = assignmentDocuments.docs.filter((document) =>
    document.data().isActive !== false && document.data().assignmentType !== "survey");
  await inBatches(activeAssignments, 20, async (document) => {
    const assigned = (Array.isArray(document.data().studentIDs) ? document.data().studentIDs : [])
      .filter((studentID: unknown): studentID is string => typeof studentID === "string" && servedIDs.has(studentID));
    if (assigned.length === 0) return;
    formsAssigned += assigned.length;
    const respondents = await document.ref.collection("respondents").where("state", "in", ["submitted", "reviewed"]).select().get();
    const assignedSet = new Set(assigned);
    formsSubmitted += respondents.docs.filter((respondent) => assignedSet.has(respondent.id)).length;
  });

  const studentsWithPlan = new Set(plans
    .filter((plan) => plan.status === "approved" || plan.status === "active")
    .flatMap(planStudents)
    .filter((studentID) => servedIDs.has(studentID)));
  const pending = plans.filter((plan) => plan.status === "pendingApproval");
  const pendingSince = (plan: DocumentData): number | null => millis(plan.submittedForApprovalAt) ?? millis(plan.updatedAt);
  const approvalDays = plans
    .map((plan) => ({ approved: millis(plan.approvedAt), submitted: millis(plan.submittedForApprovalAt) }))
    .filter((item): item is { approved: number; submitted: number } =>
      inWindow(item.approved) && item.submitted !== null && item.submitted <= item.approved)
    .map((item) => (item.approved - item.submitted) / 86_400_000);
  const completedTasks = tasks.filter((task) => task.status === "done" && inWindow(millis(task.completedAt)));
  const completedWithDue = completedTasks.filter((task) => taskDue(task) !== null);

  const count = (predicate: (fact: StudentFacts) => boolean) => facts.filter(predicate).length;
  const servedCount = facts.length;
  const staff = members.docs.filter((document) => {
    const member = document.data();
    if (scope.staffUserID !== null && document.id !== scope.staffUserID) return false;
    if (member.role === "districtAdministrator") return scope.isDistrictWide;
    const schoolIDs: unknown[] = Array.isArray(member.schoolIDs) ? member.schoolIDs : [];
    return schoolIDs.some((schoolID) => typeof schoolID === "string" && sites.has(schoolID));
  });

  const metrics: MetricValue[] = [
    countMetric("sites.count", scope.schoolIDs.length),
    countMetric("staff.active", staff.length),
    countMetric("students.served", servedCount),
    rateMetric("surveys.coverage", count((fact) => fact.surveySubmittedAt.length > 0), servedCount),
    countMetric("surveys.submitted", facts.reduce((total, fact) => total + fact.surveySubmittedAt.filter(inWindow).length, 0)),
    rateMetric("interests.coverage", count((fact) => fact.hasApprovedInterest), servedCount),
    rateMetric("plans.coverage", studentsWithPlan.size, servedCount),
    countMetric("plans.active", plans.filter((plan) => plan.status === "active").length),
    countMetric("plans.pendingApproval", pending.length),
    countMetric("plans.pendingStale", pending.filter((plan) => {
      const since = pendingSince(plan);
      return since !== null && now - since > staleApprovalDays * 86_400_000;
    }).length),
    daysMetric("plans.approvalDays", approvalDays),
    countMetric("plans.completed", plans.filter((plan) => plan.status === "completed" && inWindow(millis(plan.completedAt) ?? millis(plan.updatedAt))).length),
    countMetric("tasks.open", tasks.filter((task) => task.status === "open").length),
    countMetric("tasks.overdue", tasks.filter(isOverdue).length),
    rateMetric("tasks.onTime", completedWithDue.filter((task) => (millis(task.completedAt) ?? Infinity) < taskDue(task)!).length, completedWithDue.length),
    rateMetric("forms.completion", formsSubmitted, formsAssigned),
  ];
  if (includesEarlyChildhood) {
    metrics.push(
      countMetric("ec.observations", facts.reduce((total, fact) => total + fact.observationsAt.filter(inWindow).length, 0)),
      countMetric("ec.familyInputs", facts.reduce((total, fact) => total + fact.familyInputsAt.filter(inWindow).length, 0)),
    );
  }

  const plansByStatus: Record<string, number> = {};
  const plansByModel: Record<string, number> = {};
  for (const plan of plans) {
    const status = typeof plan.status === "string" ? plan.status : "unknown";
    plansByStatus[status] = (plansByStatus[status] ?? 0) + 1;
    if (["approved", "active", "completed"].includes(status)) {
      const model = typeof plan.modelID === "string" ? plan.modelID : typeof plan.model === "string" ? plan.model : "unspecified";
      plansByModel[model] = (plansByModel[model] ?? 0) + 1;
    }
  }

  // Weekly trend, bucketed by local week (Monday start).
  const weeks: string[] = [];
  for (let week = weekStart(scope.from); week <= scope.to; week = addDays(week, 7)) weeks.push(week);
  const bucket = (instants: readonly (number | null)[]) => {
    const counts = new Map<string, number>();
    for (const instant of instants) {
      if (!inWindow(instant)) continue;
      const week = weekStart(localDate(instant, scope.timeZone));
      counts.set(week, (counts.get(week) ?? 0) + 1);
    }
    return counts;
  };
  const surveysByWeek = bucket(facts.flatMap((fact) => fact.surveySubmittedAt));
  const approvalsByWeek = bucket(plans.map((plan) => millis(plan.approvedAt)));
  const tasksByWeek = bucket(completedTasks.map((task) => millis(task.completedAt)));
  const observationsByWeek = bucket(facts.flatMap((fact) => fact.observationsAt));
  const trend = weeks.map((week) => ({
    week,
    surveysSubmitted: surveysByWeek.get(week) ?? 0,
    plansApproved: approvalsByWeek.get(week) ?? 0,
    tasksCompleted: tasksByWeek.get(week) ?? 0,
    observations: observationsByWeek.get(week) ?? 0,
  }));

  const siteBreakdown = siteInfo.map((site) => {
    const siteFacts = facts.filter((fact) => fact.schoolID === site.schoolID);
    const siteStudents = new Set(siteFacts.map((fact) => fact.id));
    const sitePlans = plans.filter((plan) => (Array.isArray(plan.schoolIDs) ? plan.schoolIDs : [plan.schoolId]).includes(site.schoolID));
    return {
      ...site,
      studentsServed: countMetric("students.served", siteFacts.length),
      activePlans: countMetric("plans.active", sitePlans.filter((plan) => plan.status === "active").length),
      planCoverage: rateMetric("plans.coverage", [...studentsWithPlan].filter((studentID) => siteStudents.has(studentID)).length, siteFacts.length),
      surveyCoverage: rateMetric("surveys.coverage", siteFacts.filter((fact) => fact.surveySubmittedAt.length > 0).length, siteFacts.length),
      overdueTasks: countMetric("tasks.overdue", tasks.filter((task) => siteStudents.has(task.studentID) && isOverdue(task)).length),
    };
  });

  return {
    dictionaryVersion: metricDictionaryVersion,
    scope,
    computedAt: new Date(now).toISOString(),
    isPartial,
    includesEarlyChildhood,
    metrics,
    plansByStatus,
    plansByModel,
    trend,
    sites: siteBreakdown,
  };
};

// CSV ------------------------------------------------------------------------

const csvCell = (value: unknown): string => {
  const text = value === null || value === undefined ? "" : String(value);
  // Neutralise spreadsheet formula injection as well as quoting.
  const safe = /^[=+\-@\t\r]/u.test(text) ? `'${text}` : text;
  return /[",\n\r]/u.test(safe) ? `"${safe.replaceAll("\"", "\"\"")}"` : safe;
};

const displayValue = (metric: MetricValue, unit: Unit): string => {
  if (metric.status === "insufficientSample") return `Suppressed (fewer than ${minimumSample})`;
  if (metric.status === "noData" || metric.value === null) return "No data";
  return unit === "rate" ? `${Math.round(metric.value * 1000) / 10}%` : String(metric.value);
};

export const reportCSV = (report: DistrictReport, siteNames: ReadonlyMap<string, string>): string => {
  const rows: unknown[][] = [
    ["TMI district report"],
    ["Metric dictionary version", report.dictionaryVersion],
    ["Computed at (UTC)", report.computedAt],
    ["Window", `${report.scope.from} to ${report.scope.to} (${report.scope.timeZone})`],
    ["Sites", report.scope.schoolIDs.map((id) => siteNames.get(id) ?? id).join("; ")],
    ["Grade or age group filter", report.scope.grade ?? "All"],
    ["Staff filter", report.scope.staffUserID === null ? "All" : "One staff member"],
    ["Partial", report.isPartial ? "Yes — scope exceeds the report limits" : "No"],
    [],
    ["Metric", "Value", "Numerator", "Denominator", "Status", "Window", "Definition"],
  ];
  for (const metric of report.metrics) {
    const definition = metricDictionary.find((item) => item.id === metric.id);
    if (definition === undefined) continue;
    rows.push([
      definition.label,
      displayValue(metric, definition.unit),
      metric.numerator,
      metric.denominator,
      metric.status,
      definition.window === "window" ? "Report window" : "Current",
      definition.denominator === null ? definition.numerator : `${definition.numerator} ÷ ${definition.denominator}`,
    ]);
  }
  rows.push([], ["Site", "Program", "Students served", "Active plans", "Plan coverage", "Survey coverage", "Overdue follow-ups"]);
  for (const site of report.sites) {
    rows.push([
      site.name, site.programType,
      site.studentsServed.value, site.activePlans.value,
      displayValue(site.planCoverage, "rate"), displayValue(site.surveyCoverage, "rate"),
      site.overdueTasks.value,
    ]);
  }
  rows.push([], ["Plan status", "Plans"]);
  for (const [status, value] of Object.entries(report.plansByStatus).sort()) rows.push([status, value]);
  rows.push([], ["Week starting", "Surveys submitted", "Plans approved", "Follow-ups completed", "Observations"]);
  for (const week of report.trend) {
    rows.push([week.week, week.surveysSubmitted, week.plansApproved, week.tasksCompleted, week.observations]);
  }
  return `${rows.map((row) => row.map(csvCell).join(",")).join("\r\n")}\r\n`;
};

// Handlers -------------------------------------------------------------------

export interface MetricsDependencies {
  readonly firestore: () => Firestore;
  readonly now: () => number;
}

const snapshotKey = (scope: ReportScope): string =>
  createHash("sha256").update(JSON.stringify({ ...scope, schoolIDs: [...scope.schoolIDs].sort() })).digest("hex").slice(0, 40);

const needsAttentionReasons = ["noSurvey", "noPlan", "overdueFollowUp", "approvalWaiting"] as const;

export const createMetricsHandlers = (dependencies: MetricsDependencies) => {
  const prepare = async (request: CallableRequest<unknown>, extraFields: readonly string[]) => {
    const data = requireRecord(request.data);
    rejectUnexpectedFields(data, new Set([...requestFields, ...extraFields]));
    const now = dependencies.now();
    const parsed = parseReportRequest(data, now);
    const identity = parseTrustedCallableIdentity(request);
    assertDistrict(identity, parsed.districtID);
    const db = dependencies.firestore();
    const membership = await db.runTransaction(
      (transaction) => requireTrustedMembership(db, transaction, identity),
      { readOnly: true },
    );
    const { schoolIDs, isDistrictWide } = await resolveReportSites(db, membership, parsed.districtID, parsed.schoolID);
    const scope: ReportScope = {
      districtID: parsed.districtID,
      schoolIDs,
      isDistrictWide,
      from: parsed.from,
      to: parsed.to,
      timeZone: parsed.timeZone,
      grade: parsed.grade,
      staffUserID: parsed.staffUserID,
    };
    return { data, parsed, scope, db, membership, identity, now };
  };

  const report = async (db: Firestore, scope: ReportScope, refresh: boolean, now: number) => {
    const reference = db.doc(`districts/${scope.districtID}/metricSnapshots/${snapshotKey(scope)}`);
    if (!refresh) {
      const cached = await reference.get();
      const computedAt = millis(cached.data()?.computedAt);
      if (cached.exists && cached.data()?.dictionaryVersion === metricDictionaryVersion &&
        computedAt !== null && now - computedAt < snapshotFreshnessMs) {
        return cached.data()?.report as DistrictReport;
      }
    }
    const computed = await computeDistrictReport(db, scope, now);
    await reference.set({
      schemaVersion: 1,
      dictionaryVersion: metricDictionaryVersion,
      districtID: scope.districtID,
      // Lets the existing aggregate rule admit a school administrator's own single-site snapshot.
      schoolId: !scope.isDistrictWide && scope.schoolIDs.length === 1 ? scope.schoolIDs[0] : null,
      computedAt: Timestamp.fromMillis(now),
      report: computed,
    });
    return computed;
  };

  const audit = (db: Firestore, districtID: string, actorUserID: string, action: string, details: DocumentData) =>
    db.collection(`districts/${districtID}/auditEvents`).add({
      schemaVersion: 1,
      recordVersion: 1,
      action,
      actorUserID,
      districtID,
      targetPath: `districts/${districtID}/metricSnapshots`,
      reasonCode: details.reasonCode ?? "reporting",
      details,
      result: { recordVersion: 0 },
      createdAt: FieldValue.serverTimestamp(),
    });

  return {
    /** The metric dictionary, so clients show the same definitions exports use. */
    getMetricDictionary: async () => ({
      version: metricDictionaryVersion,
      minimumSample,
      definitions: metricDictionary,
    }),

    getDistrictReport: async (request: CallableRequest<unknown>) => {
      const { parsed, scope, db, now } = await prepare(request, []);
      return { report: await report(db, scope, parsed.refresh, now), definitions: metricDictionary, minimumSample };
    },

    /** Audited export. CSV is built here; PDF is rendered on-device from the same report. */
    exportDistrictReport: async (request: CallableRequest<unknown>) => {
      const { data, parsed, scope, db, membership, identity, now } = await prepare(request, ["format"]);
      if (!membership.capabilities.has("report.export")) {
        throw new HttpsError("permission-denied", "The report.export capability is required.");
      }
      const format = requireEnum(data.format, "format", ["csv", "pdf"] as const);
      const computed = await report(db, scope, parsed.refresh, now);
      const names = new Map(computed.sites.map((site) => [site.schoolID, site.name]));
      await audit(db, scope.districtID, identity.userID, "report.district.export", {
        format,
        schoolIDs: [...scope.schoolIDs],
        from: scope.from,
        to: scope.to,
        grade: scope.grade,
        staffUserID: scope.staffUserID,
        dictionaryVersion: metricDictionaryVersion,
        computedAt: computed.computedAt,
      });
      return {
        report: computed,
        definitions: metricDictionary,
        minimumSample,
        csv: reportCSV(computed, names),
        fileName: `tmi-report-${scope.from}-to-${scope.to}.${format}`,
      };
    },

    /**
     * Drill-down from aggregates to named students. Only students the caller
     * can already open are returned, and every drill-down is audited.
     */
    listStudentsNeedingAttention: async (request: CallableRequest<unknown>) => {
      const { data, scope, db, membership, identity, now } = await prepare(request, ["reasonCode"]);
      const reasonCode = data.reasonCode === undefined ? "reportDrilldown" : requireString(data.reasonCode, "reasonCode", 60);
      const district = db.doc(`districts/${scope.districtID}`);
      const sites = new Set(scope.schoolIDs);
      const [students, plans, tasks] = await Promise.all([
        district.collection("students").limit(maximumStudents).get(),
        district.collection("plans").limit(2_000).get(),
        district.collection("tasks").where("kind", "==", "followUp").where("status", "==", "open").limit(2_000).get(),
      ]);
      const visible = students.docs.filter((document) => {
        const student = document.data();
        return student.isArchived !== true && sites.has(student.schoolId) &&
          isValidIdentifier(student.schoolId) && canReadStudentDetail(membership, document.id, student.schoolId) &&
          (scope.grade === null || student.grade === scope.grade || student.ageGroup === scope.grade);
      });
      const planned = new Set<string>();
      const waiting = new Set<string>();
      for (const plan of plans.docs.map((document) => document.data())) {
        const studentIDs: string[] = Array.isArray(plan.studentIDs) ? plan.studentIDs : [];
        if (plan.status === "approved" || plan.status === "active") studentIDs.forEach((id) => planned.add(id));
        const since = millis(plan.submittedForApprovalAt) ?? millis(plan.updatedAt);
        if (plan.status === "pendingApproval" && since !== null && now - since > staleApprovalDays * 86_400_000) {
          studentIDs.forEach((id) => waiting.add(id));
        }
      }
      const overdue = new Map<string, number>();
      for (const task of tasks.docs.map((document) => document.data())) {
        const due = millis(task.dueDate);
        if (typeof task.studentID === "string" && due !== null && due + 86_400_000 <= now) {
          overdue.set(task.studentID, (overdue.get(task.studentID) ?? 0) + 1);
        }
      }
      const surveyed = await inBatches(visible, 25, async (document) => {
        const responses = await document.ref.collection("responses").where("state", "in", ["submitted", "reviewed"]).limit(1).select().get();
        return [document.id, !responses.empty] as const;
      });
      const hasSurvey = new Map(surveyed);
      const rank = (reasons: readonly string[]) =>
        reasons.reduce((total, reason) => total + (4 - needsAttentionReasons.indexOf(reason as typeof needsAttentionReasons[number])), 0);
      const flagged = visible
        .map((document) => {
          const reasons: string[] = [];
          if (hasSurvey.get(document.id) !== true) reasons.push("noSurvey");
          if (!planned.has(document.id)) reasons.push("noPlan");
          if (overdue.has(document.id)) reasons.push("overdueFollowUp");
          if (waiting.has(document.id)) reasons.push("approvalWaiting");
          const student = document.data();
          return {
            studentID: document.id,
            displayName: typeof student.displayName === "string" ? student.displayName : "Student",
            schoolID: student.schoolId as string,
            grade: typeof student.grade === "string" ? student.grade : typeof student.ageGroup === "string" ? student.ageGroup : "",
            reasons,
            overdueFollowUps: overdue.get(document.id) ?? 0,
          };
        })
        .filter((student) => student.reasons.length > 0)
        .sort((left, right) => rank(right.reasons) - rank(left.reasons) || left.displayName.localeCompare(right.displayName))
        .slice(0, 50);
      await audit(db, scope.districtID, identity.userID, "report.student.drilldown", {
        reasonCode,
        schoolIDs: [...scope.schoolIDs],
        studentIDs: flagged.map((student) => student.studentID),
      });
      return { students: flagged };
    },
  };
};
