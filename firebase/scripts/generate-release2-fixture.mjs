import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const careersDirectory = resolve(here, "../../TMI/Data/Careers");
const output = resolve(here, "../fixtures/release2.json");

const normalized = (value) => value.normalize("NFD").replace(/\p{M}/gu, "")
  .toLowerCase().match(/[\p{L}\p{N}]+/gu)?.join("-") ?? "";
const canonicalID = (category, title) => `${normalized(category)}--${normalized(title)}`;
const legacyUUID = (category, title) => {
  const digest = Buffer.from(createHash("sha256").update(`${normalized(category)}/${normalized(title)}`).digest().subarray(0, 16));
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = digest.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
};
const swiftString = (block, name, required = true) => {
  const match = block.match(new RegExp(`${name}:\\s*\"((?:\\\\.|[^\"])*)\"`, "s"));
  if (!match && required) throw new Error(`Missing ${name}`);
  return match ? JSON.parse(`"${match[1]}"`) : null;
};
const blocks = (source) => {
  const found = [];
  for (let start = source.indexOf("CareerPath("); start >= 0; start = source.indexOf("CareerPath(", start + 1)) {
    let depth = 0; let inString = false; let escaped = false;
    for (let i = start + "CareerPath".length; i < source.length; i += 1) {
      const character = source[i];
      if (inString) { if (escaped) escaped = false; else if (character === "\\") escaped = true; else if (character === '"') inString = false; continue; }
      if (character === '"') inString = true;
      else if (character === "(") depth += 1;
      else if (character === ")" && --depth === 0) { found.push(source.slice(start, i + 1)); start = i; break; }
    }
  }
  return found;
};
const educationMap = { highSchool: "highSchool", someCollege: "associates", bachelors: "bachelors", masters: "masters", doctorate: "doctorate", vocational: "certificate", certification: "certificate", varies: "varies" };
const records = readdirSync(careersDirectory).filter((name) => name.endsWith(".swift")).sort().flatMap((name) =>
  blocks(readFileSync(resolve(careersDirectory, name), "utf8")).map((block) => {
    const title = swiftString(block, "title");
    const category = swiftString(block, "category");
    const subcategory = swiftString(block, "subcategory", false);
    const summary = swiftString(block, "description");
    const interestsMatch = block.match(/requiredInterests:\s*\[([^\]]*)\]/s);
    const interestIDs = interestsMatch ? [...interestsMatch[1].matchAll(/"((?:\\.|[^"])*)"/g)].map((match) => JSON.parse(`"${match[1]}"`)).sort() : [];
    const education = block.match(/educationLevel:\s*\.([A-Za-z]+)/)?.[1] ?? "varies";
    const id = canonicalID(category, title);
    return { id, title, category, ...(subcategory ? { subcategory } : {}), summary, interestIDs, clusterIDs: [category], educationLevel: educationMap[education] ?? "varies", aliases: [`${normalized(category)}/${normalized(title)}`, title, legacyUUID(category, title)], isApproved: true, schemaVersion: 1, recordVersion: 1 };
  }),
);
if (records.length !== 537 || new Set(records.map((record) => record.id)).size !== 537) throw new Error(`Expected 537 unique careers, found ${records.length}/${new Set(records.map((record) => record.id)).size}`);
if (records.some((record) => "salary" in record || "outlook" in record)) throw new Error("Unsourced claim found");
const timestamp = "2026-07-20T12:00:00.000Z";
const fixture = {
  migrationId: "release2-discovery-v1", migrationTimestamp: timestamp, schemaVersion: 1,
  ownership: { "users/teacher-1": "district-a" },
  documents: [
    ...records.map((record) => ({ path: `catalogSeed/${record.id}`, data: record })),
    { path: "users/teacher-1/students/student-1/careerBookmarks/state", data: { savedCareerIDs: [records[0].id.replace("--", "/"), records[0].title, records[0].aliases[2]] } },
    { path: "users/teacher-1/students/student-1/interestSurveys/completed-attempt", data: { state: "completed", answers: { q1: "technology" }, completedAt: timestamp } },
  ],
};
writeFileSync(output, `${JSON.stringify(fixture, null, 2)}\n`);
process.stdout.write(`Wrote ${records.length} canonical careers to ${output}\n`);
