#!/usr/bin/env node
/**
 * Provisions a real staff account without deploying Cloud Functions.
 *
 * `provisionStaffMembership` is the authoritative path, but it is a callable
 * and cannot run while Functions are undeployed. This script performs the same
 * writes with the Admin SDK, which is the only way to produce the two things a
 * client can never create for itself:
 *
 *   1. the trusted custom claims the rules read (tmiDistrictID, tmiAccessClass,
 *      tmiMembershipVersion), and
 *   2. the membership document, which is `allow write: if false`.
 *
 * It is idempotent: running it again updates the same records rather than
 * duplicating them, and it never lowers an existing membership version.
 *
 * Credentials — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json  (live project)
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080                        (emulator)
 *
 * Usage:
 *   node scripts/provision-staff.mjs \
 *     --email teacher@example.com \
 *     --password 'chosen-at-run-time' \
 *     --district tmi-pilot \
 *     --school tmi-pilot-school \
 *     --role teacher \
 *     [--project tmi-education] \
 *     [--dry-run]
 *
 * The password is only used when creating a new Auth user. Pass it on stdin
 * with --password-stdin to keep it out of your shell history.
 */
import { createInterface } from "node:readline";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const ROLES = new Set([
  "teacher",
  "counselor",
  "socialWorker",
  "schoolAdministrator",
  "districtAdministrator",
]);

// Mirrors the capability sets the callable grants per role.
const CAPABILITIES = {
  teacher: ["student.read.detail", "student.write.detail"],
  counselor: ["student.read.detail", "student.write.detail"],
  socialWorker: ["student.read.detail"],
  schoolAdministrator: [
    "student.read.detail",
    "student.write.detail",
    "staff.manage",
    "report.export",
  ],
  districtAdministrator: [
    "student.read.detail",
    "student.write.detail",
    "student.restricted.read",
    "plan.approve",
    "staff.manage",
    "report.export",
    "audit.read",
  ],
};

const IDENTIFIER = /^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/;

const parseArgs = (argv) => {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    if (key === "dry-run" || key === "password-stdin") {
      args[key] = true;
      continue;
    }
    args[key] = argv[i + 1];
    i += 1;
  }
  return args;
};

const readStdin = async () => {
  const rl = createInterface({ input: process.stdin, terminal: false });
  for await (const line of rl) {
    rl.close();
    return line.trim();
  }
  return "";
};

const fail = (message) => {
  console.error(`error: ${message}`);
  process.exit(1);
};

const main = async () => {
  const args = parseArgs(process.argv.slice(2));
  const email = (args.email ?? "").trim().toLowerCase();
  const districtID = (args.district ?? "").trim();
  const schoolID = (args.school ?? "").trim();
  const role = (args.role ?? "teacher").trim();
  const projectId = args.project ?? process.env.GCLOUD_PROJECT;

  if (!email.includes("@")) fail("--email is required");
  if (!IDENTIFIER.test(districtID)) fail("--district must be a valid identifier");
  if (!IDENTIFIER.test(schoolID)) fail("--school must be a valid identifier");
  if (!ROLES.has(role)) fail(`--role must be one of: ${[...ROLES].join(", ")}`);

  if (
    !process.env.GOOGLE_APPLICATION_CREDENTIALS &&
    !process.env.FIRESTORE_EMULATOR_HOST
  ) {
    fail(
      "set GOOGLE_APPLICATION_CREDENTIALS to a service account key, or " +
        "FIRESTORE_EMULATOR_HOST to target the emulator",
    );
  }

  let password = args.password;
  if (args["password-stdin"]) password = await readStdin();

  const app = initializeApp({
    projectId,
    ...(process.env.GOOGLE_APPLICATION_CREDENTIALS
      ? { credential: applicationDefault() }
      : {}),
  });
  const auth = getAuth(app);
  const firestore = getFirestore(app);

  let user;
  try {
    user = await auth.getUserByEmail(email);
    console.log(`found existing account ${email} (${user.uid})`);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    if (!password) {
      fail(`no account for ${email}; pass --password or --password-stdin`);
    }
    if (args["dry-run"]) {
      console.log(`[dry run] would create account ${email}`);
      return;
    }
    user = await auth.createUser({ email, password, emailVerified: true });
    console.log(`created account ${email} (${user.uid})`);
  }

  const membershipRef = firestore.doc(
    `districts/${districtID}/members/${user.uid}`,
  );
  const existing = await membershipRef.get();
  // Never lower the version: the claim and the document must agree, and the
  // client compares them on every authorized read.
  const version = existing.exists
    ? Math.max(1, (existing.data().version ?? 0) + 1)
    : 1;

  const membership = {
    districtID,
    schoolIDs: [schoolID],
    role,
    capabilities: CAPABILITIES[role],
    assignedStudentIDs: existing.exists
      ? (existing.data().assignedStudentIDs ?? [])
      : [],
    isActive: true,
    version,
    updatedAt: FieldValue.serverTimestamp(),
  };

  const claims = {
    tmiDistrictID: districtID,
    tmiAccessClass: "staff",
    tmiMembershipVersion: version,
  };

  if (args["dry-run"]) {
    console.log("[dry run] membership:", JSON.stringify(membership, null, 2));
    console.log("[dry run] claims:", JSON.stringify(claims, null, 2));
    return;
  }

  await firestore.doc(`districts/${districtID}`).set(
    { districtID, name: districtID, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  await firestore.doc(`districts/${districtID}/schools/${schoolID}`).set(
    { schoolID, districtID, name: schoolID, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  await membershipRef.set(membership, { merge: true });
  await auth.setCustomUserClaims(user.uid, claims);

  console.log(`provisioned ${role} in ${districtID}/${schoolID} at version ${version}`);
  console.log("sign out and back in so the app picks up the refreshed claims");
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
