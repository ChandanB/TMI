#!/usr/bin/env node
// Early-childhood demo seeder. Creates an early-learning provider with one
// center (programType earlyChildhood), children with age groups and dates of
// birth, caregiver-observed interests, family-facing resources, draft and
// active plans worded for young children, and a family conference. No career
// data is written: career exploration is not part of the early-childhood flow.
//
// Admin SDK (bypasses rules). Idempotent: fixed document IDs, re-runnable.
// Pair with provision-staff.mjs (--program-type earlyChildhood) or the
// in-app Developer Mode to give an account a membership in this tenant.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   node scripts/seed-early-childhood-demo.mjs --uid <staff uid> \
//     [--district sunshine-early-learning] [--project tmi-education]
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed-early-childhood-demo.mjs --uid <uid> --project demo-tmi
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const args = {};
for (let i = 0; i < process.argv.length; i++) {
  const token = process.argv[i];
  if (token.startsWith("--")) args[token.slice(2)] = process.argv[i + 1];
}
const uid = args.uid;
const districtID = args.district ?? "sunshine-early-learning";
const projectId = args.project ?? process.env.GCLOUD_PROJECT;
if (!uid) {
  console.error("--uid required");
  process.exit(1);
}

const app = initializeApp({
  projectId,
  ...(process.env.GOOGLE_APPLICATION_CREDENTIALS ? { credential: applicationDefault() } : {}),
});
const db = getFirestore(app);
const now = Timestamp.now();
const daysFromNow = (days) => Timestamp.fromMillis(Date.now() + days * 86_400_000);
const monthsAgo = (months) => {
  const date = new Date();
  date.setMonth(date.getMonth() - months);
  return Timestamp.fromDate(date);
};
const norm = (value) => value.toLowerCase().trim().replace(/\s+/g, " ");

const CENTER = "sunshine-east";
const childID = (index) => `ec-child-${String(index + 1).padStart(2, "0")}`;

const children = [
  { first: "Mila", last: "Hart", ageGroup: "Infant", months: 9 },
  { first: "Theo", last: "Banks", ageGroup: "Toddler", months: 20 },
  { first: "Nora", last: "Quinn", ageGroup: "Twos", months: 30 },
  { first: "Kai", last: "Rivera", ageGroup: "Preschool 3s", months: 41 },
  { first: "Ava", last: "Okafor", ageGroup: "Pre-K 4s", months: 52 },
  { first: "Leo", last: "Nakamura", ageGroup: "Pre-K 4s", months: 55 },
];

// Interests caregivers observed during play (source: staff observation).
const INTERESTS = {
  "building-blocks": "Building & blocks",
  "music-movement": "Music & movement",
  "animals-nature": "Animals & nature",
  "pretend-play": "Pretend play",
  "books-stories": "Books & stories",
  "art-sensory": "Art & sensory play",
  "vehicles": "Trucks & vehicles",
  "water-sand": "Water & sand play",
};
const observedInterests = {
  1: ["vehicles", "water-sand"],
  2: ["books-stories", "music-movement"],
  3: ["building-blocks", "pretend-play", "vehicles"],
  4: ["animals-nature", "art-sensory", "books-stories"],
  5: ["music-movement", "building-blocks"],
};

const plans = [
  {
    child: 3, model: "alignYourMind", status: "active", approval: "approved",
    title: "Align Your Mind — Kai Rivera",
    summary: "Building calm-down routines during transitions using Kai's love of vehicles (\"parking\" toys before clean-up).",
    need: "Kai becomes upset at transitions between centers and needs predictable routines to self-regulate.",
    voice: "Kai lines up cars and says \"parking!\" when calm; family shares he loves bedtime truck books.",
  },
  {
    child: 4, model: "acknowledgeInterests", status: "pendingApproval", approval: "pending",
    title: "Acknowledge Your Interests and Hobbies — Ava Okafor",
    summary: "Using Ava's interest in animals to grow expressive language through picture books and pretend vet play.",
    need: "Ava uses few words with peers; interest-based play may encourage conversation.",
    voice: "Ava brings animal figures to the book corner and names them for caregivers; family reports she narrates play at home.",
  },
  {
    child: 2, model: "acknowledgeInterests", status: "draft", approval: "notRequested",
    title: "Acknowledge Your Interests and Hobbies — Nora Quinn",
    summary: "Circle-time songs and books to support Nora's participation in group activities.",
    need: "Nora watches group activities but rarely joins.",
    voice: "Nora sways and claps during music time and brings board books to caregivers.",
  },
];

const resources = [
  { id: "ec-res-routines", title: "Visual Routines at Home", description: "Picture schedules families can use for morning and bedtime.", category: "article", url: "https://example.org/visual-routines", tags: ["family", "routines"] },
  { id: "ec-res-transitions", title: "Transition Songs Collection", description: "Short songs caregivers use to signal clean-up and moving between activities.", category: "video", url: "https://example.org/transition-songs", tags: ["regulation", "music"] },
  { id: "ec-res-read-aloud", title: "Dialogic Reading Tips", description: "Ways to invite toddlers and preschoolers to talk about picture books.", category: "article", url: "https://example.org/dialogic-reading", tags: ["language", "family"] },
  { id: "ec-res-play-ideas", title: "Interest-Based Play Ideas", description: "Low-cost activity ideas organized by what children love to play.", category: "interactiveContent", url: "https://example.org/play-ideas", tags: ["play"] },
];
const childResources = { 3: ["ec-res-transitions", "ec-res-routines"], 4: ["ec-res-read-aloud"] };

async function main() {
  const batch = db.batch();

  batch.set(db.doc(`districts/${districtID}`), {
    districtID, name: "Sunshine Early Learning", organizationKind: "earlyLearningProvider",
    programType: "earlyChildhood", updatedAt: now,
  }, { merge: true });
  batch.set(db.doc(`districts/${districtID}/schools/${CENTER}`), {
    schoolID: CENTER, districtID, name: "Sunshine East Center", updatedAt: now,
  }, { merge: true });

  children.forEach((child, index) => {
    const displayName = `${child.first} ${child.last}`;
    batch.set(db.doc(`districts/${districtID}/students/${childID(index)}`), {
      districtId: districtID, schoolId: CENTER, displayName, normalizedDisplayName: norm(displayName),
      grade: child.ageGroup, dateOfBirth: monthsAgo(child.months),
      assignedMemberIDs: [uid], isArchived: false, schemaVersion: 1, recordVersion: 1,
      createdAt: now, createdBy: uid, updatedAt: now, updatedBy: uid,
    }, { merge: true });
  });

  for (const [index, interestIDs] of Object.entries(observedInterests)) {
    interestIDs.forEach((interestId, rank) => {
      batch.set(db.doc(`districts/${districtID}/students/${childID(+index)}/interests/${interestId}`), {
        studentId: childID(+index), interestId, name: INTERESTS[interestId], category: "Play",
        strength: 5 - rank, rank: rank + 1, source: "staff", capturedAt: now, updatedAt: now,
        createdBy: uid, mergeHistory: [],
      }, { merge: true });
    });
  }

  plans.forEach((plan, index) => {
    batch.set(db.doc(`districts/${districtID}/plans/ec-plan-${String(index + 1).padStart(2, "0")}`), {
      districtId: districtID, studentIDs: [childID(plan.child)], schoolIDs: [CENTER],
      assignedMemberIDs: [uid], ownerMemberID: uid, modelID: plan.model, title: plan.title,
      summary: plan.summary, professionalNeed: plan.need, studentVoice: plan.voice,
      status: plan.status, approvalStatus: plan.approval, startDate: now,
      reviewDate: daysFromNow(28), targetDate: daysFromNow(84),
      signalsReviewed: true, needTags: [], interestsAndCareersReviewed: true,
      relatedInterestIDs: observedInterests[plan.child] ?? [], relatedCareerIDs: [],
      supportMaterialsReviewed: true, familyCollaborationPermission: "notAuthorized",
      recommendationInputRecordIDs: [], schemaVersion: 1, recordVersion: 1,
      createdBy: uid, createdAt: now, updatedBy: uid, updatedAt: now,
    }, { merge: true });
  });

  const resourceDoc = (resource) => ({
    title: resource.title, description: resource.description, category: resource.category,
    url: resource.url, createdAt: now, updatedAt: now, tags: resource.tags, recommendedFor: [],
    isFeatured: false, scope: "district", districtId: districtID, ownerUid: uid,
  });
  resources.forEach((resource) =>
    batch.set(db.doc(`districts/${districtID}/resources/${resource.id}`), resourceDoc(resource), { merge: true }));
  const resourcesByID = Object.fromEntries(resources.map((resource) => [resource.id, resource]));
  for (const [index, ids] of Object.entries(childResources)) {
    ids.forEach((id) => batch.set(
      db.doc(`districts/${districtID}/students/${childID(+index)}/resources/${id}`),
      resourceDoc(resourcesByID[id]),
      { merge: true },
    ));
  }

  batch.set(db.doc(`districts/${districtID}/meetings/ec-meeting-01`), {
    title: "Family Conference — Kai Rivera", description: "Share transition routines that work at the center and hear what works at home.",
    startTime: daysFromNow(4), endTime: Timestamp.fromMillis(daysFromNow(4).toMillis() + 30 * 60000),
    location: "Sunshine East — Family Room", meetingType: "Parent Conference", organizer: uid, participants: [],
    relatedStudentIds: [childID(3)], relatedPlanId: "ec-plan-01", status: "Scheduled", actionItems: [],
    createdAt: now, lastUpdated: now, participantUserIDs: [uid],
  }, { merge: true });

  await batch.commit();
  console.log(`Seeded early-childhood tenant ${districtID}: 1 center, ${children.length} children, ${plans.length} plans, ${resources.length} resources, 1 meeting.`);
  console.log("Give an account access with Developer Mode or provision-staff.mjs --district " + districtID + " --school " + CENTER + " --program-type earlyChildhood.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
