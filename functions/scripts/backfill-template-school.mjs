#!/usr/bin/env node
/**
 * Gives district-wide form templates an explicit `schoolId: null`.
 *
 * The formTemplates list rule only admits queries that constrain `schoolId`,
 * and school-scoped staff list district-wide templates with
 * `where("schoolId", "==", null)`. A document that omits the field never
 * matches that query, so templates written before the app stored an explicit
 * null are invisible to them until this runs. Dry run by default.
 *
 * Credentials — one of:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json  (live project)
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
 *
 * Usage:
 *   node scripts/backfill-template-school.mjs --project tmi-education           # report only
 *   node scripts/backfill-template-school.mjs --project tmi-education --apply   # write
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const argv = process.argv.slice(2);
const apply = argv.includes("--apply");
const projectIndex = argv.indexOf("--project");
const projectId = projectIndex >= 0 ? argv[projectIndex + 1] : process.env.GCLOUD_PROJECT;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("error: set GOOGLE_APPLICATION_CREDENTIALS, or FIRESTORE_EMULATOR_HOST for the emulator");
  process.exit(1);
}

const app = initializeApp({
  projectId,
  ...(process.env.GOOGLE_APPLICATION_CREDENTIALS ? { credential: applicationDefault() } : {}),
});
const firestore = getFirestore(app);

const main = async () => {
  const templates = await firestore.collectionGroup("formTemplates").get();
  const missing = templates.docs.filter((document) => !("schoolId" in document.data()));
  console.log(`${templates.size} templates; ${missing.length} without schoolId`);
  for (const document of missing) {
    console.log(`  ${apply ? "fixing" : "would fix"} ${document.ref.path}`);
  }
  if (!apply || missing.length === 0) {
    if (!apply && missing.length > 0) console.log("dry run: re-run with --apply to write");
    return;
  }
  for (let start = 0; start < missing.length; start += 400) {
    const batch = firestore.batch();
    for (const document of missing.slice(start, start + 400)) {
      batch.update(document.ref, { schoolId: null });
    }
    await batch.commit();
  }
  console.log(`updated ${missing.length} templates`);
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
