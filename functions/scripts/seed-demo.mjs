#!/usr/bin/env node
// Investor-demo seeder for the real tmi-education tenant. Writes with the Admin
// SDK (bypasses security rules) so it can create the private profile, district,
// schools, students, canonical plans, the careers catalog, student interests &
// saved careers, resources, and meetings a fresh districtAdministrator needs to
// demo the whole product. Idempotent: fixed document IDs, re-runnable.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   node scripts/seed-demo.mjs --uid <uid> --email tmi@test.tmi \
//     --district riverside-usd --project tmi-education
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const args = {};
for (let i = 0; i < process.argv.length; i++) {
  const t = process.argv[i];
  if (t.startsWith("--")) args[t.slice(2)] = process.argv[i + 1];
}
const uid = args.uid;
const email = args.email ?? "tmi@test.tmi";
const districtID = args.district ?? "riverside-usd";
const projectId = args.project ?? process.env.GCLOUD_PROJECT;
if (!uid) { console.error("--uid required"); process.exit(1); }

const app = initializeApp({ projectId, credential: applicationDefault() });
const db = getFirestore(app);
const now = Timestamp.now();
const daysFromNow = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);
const norm = (s) => s.toLowerCase().trim().replace(/\s+/g, " ");

const HIGH = "riverside-high";
const MIDDLE = "lincoln-middle";

const students = [
  { first: "Maya", last: "Thompson", grade: "10", school: HIGH, pronouns: "she/her" },
  { first: "Ethan", last: "Rodriguez", grade: "11", school: HIGH, pronouns: "he/him" },
  { first: "Aisha", last: "Khan", grade: "9", school: HIGH, pronouns: "she/her" },
  { first: "Liam", last: "Nguyen", grade: "12", school: HIGH, pronouns: "he/him" },
  { first: "Sofia", last: "Martinez", grade: "10", school: HIGH, pronouns: "she/her" },
  { first: "Jayden", last: "Williams", grade: "7", school: MIDDLE, pronouns: "he/him" },
  { first: "Olivia", last: "Chen", grade: "8", school: MIDDLE, pronouns: "she/her" },
  { first: "Noah", last: "Patel", grade: "6", school: MIDDLE, pronouns: "he/him" },
  { first: "Zoe", last: "Johnson", grade: "8", school: MIDDLE, pronouns: "they/them" },
  { first: "Diego", last: "Garcia", grade: "7", school: MIDDLE, pronouns: "he/him" },
];
const sid = (i) => `demo-student-${String(i + 1).padStart(2, "0")}`;

const plans = [
  { sIdx: 0, model: "chaseYourSpace", title: "Chase Your Space — Maya Thompson", status: "active", approval: "approved", summary: "Building a consistent morning routine and a calm-down space to re-engage in first period." },
  { sIdx: 1, model: "acknowledgeInterests", title: "Acknowledge Interests — Ethan Rodriguez", status: "active", approval: "approved", summary: "Channeling Ethan's interest in automotive mechanics into project-based coursework." },
  { sIdx: 2, model: "alignYourMind", title: "Align Your Mind — Aisha Khan", status: "active", approval: "approved", summary: "Mindfulness check-ins and goal framing to reduce test anxiety." },
  { sIdx: 4, model: "directAndCorrect", title: "Direct & Correct — Sofia Martinez", status: "pendingApproval", approval: "pending", summary: "Restorative approach to repeated tardiness with clear, supportive expectations." },
  { sIdx: 6, model: "meekToProtector", title: "Meek to Protector — Olivia Chen", status: "draft", approval: "notRequested", summary: "Confidence-building through peer mentorship in the robotics club." },
];

// Careers catalog (catalogs/careers/items/{id}); interestIDs match student interests below.
const careers = [
  { id: "software-developer", title: "Software Developer", category: "Technology", summary: "Designs and builds applications and systems.", interestIDs: ["technology", "problem-solving"], education: "bachelors" },
  { id: "automotive-technician", title: "Automotive Technician", category: "Skilled Trades", summary: "Diagnoses and repairs vehicles.", interestIDs: ["mechanics", "problem-solving"], education: "certificate" },
  { id: "registered-nurse", title: "Registered Nurse", category: "Healthcare", summary: "Provides and coordinates patient care.", interestIDs: ["helping-others", "science"], education: "associates" },
  { id: "graphic-designer", title: "Graphic Designer", category: "Arts & Media", summary: "Creates visual concepts and designs.", interestIDs: ["art", "technology"], education: "bachelors" },
  { id: "civil-engineer", title: "Civil Engineer", category: "Engineering", summary: "Designs infrastructure like roads and bridges.", interestIDs: ["problem-solving", "science"], education: "bachelors" },
  { id: "physical-therapist", title: "Physical Therapist", category: "Healthcare", summary: "Helps patients recover movement and manage pain.", interestIDs: ["helping-others", "sports"], education: "doctorate" },
  { id: "electrician", title: "Electrician", category: "Skilled Trades", summary: "Installs and maintains electrical systems.", interestIDs: ["mechanics"], education: "certificate" },
  { id: "teacher", title: "Teacher", category: "Education", summary: "Educates and mentors students.", interestIDs: ["helping-others"], education: "bachelors" },
  { id: "data-analyst", title: "Data Analyst", category: "Technology", summary: "Turns data into insights for decisions.", interestIDs: ["technology", "problem-solving"], education: "bachelors" },
  { id: "musician", title: "Musician", category: "Arts & Media", summary: "Performs, composes, and records music.", interestIDs: ["music", "art"], education: "varies" },
  { id: "athletic-trainer", title: "Athletic Trainer", category: "Healthcare", summary: "Prevents and treats sports injuries.", interestIDs: ["sports", "helping-others"], education: "bachelors" },
  { id: "environmental-scientist", title: "Environmental Scientist", category: "Science", summary: "Studies the environment and protects it.", interestIDs: ["science"], education: "bachelors" },
];

const INTERESTS = {
  technology: "Technology", "problem-solving": "Problem Solving", mechanics: "Hands-on / Mechanics",
  "helping-others": "Helping Others", science: "Science", art: "Art & Design",
  sports: "Sports & Fitness", music: "Music",
};

// Which students get which interests (interestId list) and saved careers (career ids).
const studentInterests = {
  0: ["art", "technology", "helping-others"],   // Maya
  1: ["mechanics", "problem-solving"],           // Ethan
  2: ["science", "helping-others"],              // Aisha
  4: ["sports", "helping-others"],               // Sofia
  6: ["technology", "problem-solving", "music"], // Olivia
};
const studentCareers = {
  0: ["graphic-designer", "software-developer"],
  1: ["automotive-technician", "electrician"],
  2: ["registered-nurse", "environmental-scientist"],
  4: ["athletic-trainer", "physical-therapist"],
  6: ["software-developer", "data-analyst"],
};

const resources = [
  { id: "res-growth-mindset", title: "Growth Mindset for Students", description: "A short guide to building resilience and a growth mindset.", category: "article", url: "https://example.org/growth-mindset", tags: ["sel", "mindset"] },
  { id: "res-study-skills", title: "Study Skills Toolkit", description: "Practical study and time-management strategies.", category: "course", url: "https://example.org/study-skills", tags: ["academics"] },
  { id: "res-calm-breathing", title: "2-Minute Calm Breathing", description: "A guided breathing exercise for de-escalation.", category: "video", url: "https://example.org/calm-breathing", tags: ["sel", "regulation"] },
  { id: "res-career-explorer", title: "Career Explorer Workbook", description: "Interactive workbook connecting interests to careers.", category: "interactiveContent", url: "https://example.org/career-explorer", tags: ["careers"] },
  { id: "res-family-guide", title: "Family Collaboration Guide", description: "How families can support a TMI plan at home.", category: "article", url: "https://example.org/family-guide", tags: ["family"] },
  { id: "res-conflict-resolution", title: "Peer Conflict Resolution", description: "Restorative steps for resolving peer conflict.", category: "book", url: "https://example.org/conflict-resolution", tags: ["sel", "behavior"] },
];
const studentResources = { 0: ["res-growth-mindset", "res-study-skills"], 2: ["res-calm-breathing"], 4: ["res-career-explorer"] };

const meetings = [
  { id: "demo-meeting-01", title: "TMI Plan Kickoff — Maya Thompson", type: "Plan Review", student: 0, plan: "demo-plan-01", startInDays: 1, desc: "Review the Chase Your Space plan and set the first two-week goals." },
  { id: "demo-meeting-02", title: "Progress Check — Ethan Rodriguez", type: "Progress Review", student: 1, plan: "demo-plan-02", startInDays: 3, desc: "Check progress on project-based coursework and interest alignment." },
  { id: "demo-meeting-03", title: "Family Conference — Aisha Khan", type: "Family Conference", student: 2, plan: "demo-plan-03", startInDays: 5, desc: "Family conference to align on mindfulness supports at home." },
];

async function main() {
  const batch = db.batch();

  // Profile (login gate)
  batch.set(db.doc(`users/${uid}/private/profile`), {
    userID: uid, email, displayName: "Demo Administrator", isEmailVerified: true,
    requestedRole: "administrator", organization: "Riverside Unified School District",
    createdAt: now, lastLoginAt: now,
  }, { merge: true });

  // District + schools
  batch.set(db.doc(`districts/${districtID}`), { districtID, name: "Riverside Unified School District", updatedAt: now }, { merge: true });
  batch.set(db.doc(`districts/${districtID}/schools/${HIGH}`), { schoolID: HIGH, districtID, name: "Riverside High School", updatedAt: now }, { merge: true });
  batch.set(db.doc(`districts/${districtID}/schools/${MIDDLE}`), { schoolID: MIDDLE, districtID, name: "Lincoln Middle School", updatedAt: now }, { merge: true });

  // Students
  students.forEach((s, i) => {
    const displayName = `${s.first} ${s.last}`;
    batch.set(db.doc(`districts/${districtID}/students/${sid(i)}`), {
      districtId: districtID, schoolId: s.school, displayName, normalizedDisplayName: norm(displayName),
      grade: s.grade, pronouns: s.pronouns, studentIdentifier: `S-${1000 + i}`, normalizedStudentIdentifier: norm(`S-${1000 + i}`),
      assignedMemberIDs: [uid], isArchived: false, schemaVersion: 1, recordVersion: 1,
      createdAt: now, createdBy: uid, updatedAt: now, updatedBy: uid,
    }, { merge: true });
  });

  // Plans
  plans.forEach((p, i) => {
    batch.set(db.doc(`districts/${districtID}/plans/demo-plan-${String(i + 1).padStart(2, "0")}`), {
      districtId: districtID, studentIDs: [sid(p.sIdx)], schoolIDs: [students[p.sIdx].school],
      assignedMemberIDs: [uid], ownerMemberID: uid, modelID: p.model, title: p.title, summary: p.summary,
      status: p.status, approvalStatus: p.approval, startDate: now, signalsReviewed: true, needTags: [],
      interestsAndCareersReviewed: true, relatedInterestIDs: [], relatedCareerIDs: [], supportMaterialsReviewed: true,
      recommendationInputRecordIDs: [], schemaVersion: 1, recordVersion: 1,
      createdBy: uid, createdAt: now, updatedBy: uid, updatedAt: now,
    }, { merge: true });
  });

  // Careers catalog
  careers.forEach((c) => {
    batch.set(db.doc(`catalogs/careers/items/${c.id}`), {
      careerID: c.id, title: c.title, category: c.category, summary: c.summary,
      interestIDs: c.interestIDs, clusterIDs: [], educationLevel: c.education, aliases: [], isApproved: true,
    }, { merge: true });
  });

  // Student interests (edges) + saved careers
  for (const [idx, ints] of Object.entries(studentInterests)) {
    ints.forEach((interestId, rank) => {
      batch.set(db.doc(`districts/${districtID}/students/${sid(+idx)}/interests/${interestId}`), {
        studentId: sid(+idx), interestId, name: INTERESTS[interestId] ?? interestId, category: "Interest",
        strength: 5 - rank, rank: rank + 1, source: "staff", capturedAt: now, updatedAt: now, createdBy: uid, mergeHistory: [],
      }, { merge: true });
    });
  }
  for (const [idx, careerIDs] of Object.entries(studentCareers)) {
    careerIDs.forEach((careerID) => {
      batch.set(db.doc(`districts/${districtID}/students/${sid(+idx)}/careers/${careerID}`), {
        districtID, studentID: sid(+idx), careerID, isSaved: true, isDismissed: false, isCompared: false,
        linkedPlanIDs: [], schemaVersion: 1, recordVersion: 1, lastViewedAt: now,
        createdAt: now, createdBy: uid, updatedAt: now, updatedBy: uid,
      }, { merge: true });
    });
  }

  // Resource library + student-assigned resources
  const resourceDoc = (r) => ({
    title: r.title, description: r.description, category: r.category, url: r.url,
    createdAt: now, updatedAt: now, tags: r.tags, recommendedFor: [], isFeatured: false,
    scope: "district", districtId: districtID, ownerUid: uid,
  });
  resources.forEach((r) => batch.set(db.doc(`districts/${districtID}/resources/${r.id}`), resourceDoc(r), { merge: true }));
  const byId = Object.fromEntries(resources.map((r) => [r.id, r]));
  for (const [idx, ids] of Object.entries(studentResources)) {
    ids.forEach((rid) => batch.set(db.doc(`districts/${districtID}/students/${sid(+idx)}/resources/${rid}`), resourceDoc(byId[rid]), { merge: true }));
  }

  // Meetings
  meetings.forEach((m) => {
    batch.set(db.doc(`districts/${districtID}/meetings/${m.id}`), {
      title: m.title, description: m.desc, startTime: daysFromNow(m.startInDays),
      endTime: Timestamp.fromMillis(daysFromNow(m.startInDays).toMillis() + 45 * 60000),
      location: "Counseling Office", meetingType: m.type, organizer: uid, participants: [],
      relatedStudentIds: [sid(m.student)], relatedPlanId: m.plan, status: "Scheduled", actionItems: [],
      createdAt: now, lastUpdated: now, participantUserIDs: [uid],
    }, { merge: true });
  });

  await batch.commit();
  console.log(`Seeded: profile + ${districtID} + 2 schools + ${students.length} students + ${plans.length} plans + ${careers.length} careers + student interests/careers + ${resources.length} resources + ${meetings.length} meetings for ${email}.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
