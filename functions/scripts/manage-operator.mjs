#!/usr/bin/env node
/**
 * Grants or revokes developer-console (platform operator) authority.
 *
 * Operator status lives only in `platformOperators/{uid}`, which the Firestore
 * rules deny to every client. This Admin SDK script is the sole writer, so a
 * DEBUG build of the app can never promote itself.
 *
 * Credentials — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json  (live project)
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
 *
 * Usage:
 *   node scripts/manage-operator.mjs grant  --email dev@example.com --project tmi-education
 *   node scripts/manage-operator.mjs revoke --email dev@example.com --project tmi-education
 *   node scripts/manage-operator.mjs list   --project tmi-education
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const [action, ...rest] = process.argv.slice(2);
const args = {};
for (let index = 0; index < rest.length; index += 1) {
  if (rest[index].startsWith("--")) {
    args[rest[index].slice(2)] = rest[index + 1];
    index += 1;
  }
}

const fail = (message) => {
  console.error(`error: ${message}`);
  process.exit(1);
};

if (!["grant", "revoke", "list"].includes(action)) {
  fail("usage: manage-operator.mjs <grant|revoke|list> [--email <email>] [--project <id>]");
}
if (
  !process.env.GOOGLE_APPLICATION_CREDENTIALS &&
  !process.env.FIRESTORE_EMULATOR_HOST
) {
  fail("set GOOGLE_APPLICATION_CREDENTIALS, or FIRESTORE_EMULATOR_HOST for the emulator");
}

const projectId = args.project ?? process.env.GCLOUD_PROJECT;
const app = initializeApp({
  projectId,
  ...(process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? { credential: applicationDefault() }
    : {}),
});
const auth = getAuth(app);
const firestore = getFirestore(app);

const main = async () => {
  if (action === "list") {
    const snapshot = await firestore.collection("platformOperators").get();
    for (const document of snapshot.docs) {
      const data = document.data();
      console.log(`${document.id}\t${data.email ?? "?"}\t${data.isActive ? "active" : "revoked"}`);
    }
    if (snapshot.empty) console.log("no operators");
    return;
  }

  const email = (args.email ?? "").trim().toLowerCase();
  if (!email.includes("@")) fail("--email is required");
  const user = await auth.getUserByEmail(email);
  const reference = firestore.doc(`platformOperators/${user.uid}`);
  if (action === "grant") {
    await reference.set(
      {
        userID: user.uid,
        email,
        isActive: true,
        grantedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.log(`granted developer console access to ${email} (${user.uid}) on ${projectId ?? "default project"}`);
  } else {
    await reference.set(
      { isActive: false, revokedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    console.log(`revoked developer console access for ${email} (${user.uid})`);
  }
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
