import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { buildMigrationPlan, parseMigrationFixture, type MigrationFixture } from "../src/migrationManifest.js";
import { applyMigrationPlan, MemoryMigrationStore, MigrationConflictError } from "../src/migrate.js";
import { reconcileMigrationPlan } from "../src/reconcile.js";

const fixture = (): MigrationFixture => parseMigrationFixture(
  JSON.parse(readFileSync(resolve(process.cwd(), "fixtures/release2.json"), "utf8")) as unknown,
);

describe("Release 2 discovery migration", () => {
  it("contains exactly 537 unique Firestore-safe careers without unsourced claims", () => {
    const plan = buildMigrationPlan(fixture());
    const careers = plan.writes.filter((write) => write.manifest.destinationPath.startsWith("catalogs/careers/items/"));
    expect(careers).toHaveLength(537);
    expect(new Set(careers.map((write) => write.manifest.destinationPath)).size).toBe(537);
    expect(careers.every((write) => write.data.salary === undefined && write.data.outlook === undefined)).toBe(true);
  });

  it("applies once, writes zero on replay, and reconciles exactly", async () => {
    const plan = buildMigrationPlan(fixture());
    const store = new MemoryMigrationStore();
    const first = await applyMigrationPlan(plan, store);
    const second = await applyMigrationPlan(plan, store);
    const report = await reconcileMigrationPlan(plan, store);
    expect(first.writesApplied).toBe(plan.writes.length);
    expect(second.writesApplied).toBe(0);
    expect(second.alreadyApplied).toBe(plan.writes.length);
    expect(report.isConsistent).toBe(true);
  });

  it("stops rather than overwriting a conflicting canonical career", async () => {
    const plan = buildMigrationPlan(fixture());
    const store = new MemoryMigrationStore();
    const career = plan.writes.find((write) => write.manifest.destinationPath.startsWith("catalogs/careers/items/"))!;
    await store.replaceForTesting(career.manifest.destinationPath, { title: "Conflict" });
    await expect(applyMigrationPlan(plan, store)).rejects.toBeInstanceOf(MigrationConflictError);
  });

  it("quarantines completed attempts when immutable provenance cannot be reconstructed", () => {
    const plan = buildMigrationPlan(fixture());
    const attempt = plan.writes.find((write) => write.manifest.sourcePath.includes("interestSurveys/completed-attempt"));
    expect(attempt?.manifest.ownerResolution).toBe("quarantine");
    expect(attempt?.data.reason).toBe("unverifiable-completed-survey-provenance");
    expect(attempt?.data.sourceData).toBeDefined();
  });

  it("resolves slash, title, and legacy UUID aliases to one saved relationship", () => {
    const plan = buildMigrationPlan(fixture());
    const relationships = plan.writes.filter((write) => write.manifest.destinationPath.includes("/students/student-1/careers/"));
    expect(relationships).toHaveLength(1);
    expect(relationships[0]?.data.careerId).toBe(relationships[0]?.manifest.destinationPath.split("/").at(-1));
  });
});
