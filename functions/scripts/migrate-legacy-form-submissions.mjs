#!/usr/bin/env node
/**
 * Moves legacy per-user form submissions (users/{uid}/formSubmissions) into
 * canonical respondent records. Dry run by default; pass --apply to write.
 * Never overwrites existing respondents; conflicts and unresolved records are
 * listed for manual repair. Safe to re-run.
 *
 * Build first (npm run build), then:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json node scripts/migrate-legacy-form-submissions.mjs --project tmi-education
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json node scripts/migrate-legacy-form-submissions.mjs --project tmi-education --apply
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { migrateLegacyFormSubmissions } from "../lib/src/formMigration.js";

const argv = process.argv.slice(2);
const apply = argv.includes("--apply");
const projectIndex = argv.indexOf("--project");
const projectId = projectIndex >= 0 ? argv[projectIndex + 1] : process.env.GCLOUD_PROJECT;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS && !process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("error: set GOOGLE_APPLICATION_CREDENTIALS, or FIRESTORE_EMULATOR_HOST for the emulator");
  process.exit(1);
}

initializeApp({
  projectId,
  ...(process.env.GOOGLE_APPLICATION_CREDENTIALS ? { credential: applicationDefault() } : {}),
});

const report = await migrateLegacyFormSubmissions(getFirestore(), { dryRun: !apply });
console.log(`${apply ? "Applied" : "Dry run"} on ${projectId}:`, report.counts);
for (const outcome of report.outcomes) {
  if (outcome.kind === "conflict" || outcome.kind === "unresolved") {
    console.log(`  ${outcome.kind}: ${outcome.source}${"reason" in outcome ? ` (${outcome.reason})` : ` → ${outcome.destination}`}`);
  }
}
if (!apply && report.counts.migrated > 0) console.log("Re-run with --apply to write these records.");
