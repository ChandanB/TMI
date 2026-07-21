import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { deleteApp, initializeApp, type App } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
} from "vitest";
import {
  buildMigrationPlan,
  parseMigrationFixture,
  type MigrationFixture,
} from "../src/migrationManifest.js";
import {
  applyMigrationPlan,
  FirestoreMigrationStore,
  ForwardOnlyMigrationError,
  MemoryMigrationStore,
  MigrationConflictError,
  rollbackMigration,
} from "../src/migrate.js";
import { reconcileMigrationPlan } from "../src/reconcile.js";
import { makeTestEnvironment } from "./testEnvironment.js";

const loadFixture = (name = "gate0.json"): MigrationFixture =>
  parseMigrationFixture(
    JSON.parse(
      readFileSync(
        resolve(process.cwd(), "fixtures", name),
        "utf8",
      ),
    ) as unknown,
  );

describe("forward-only canonical migration", () => {
  let fixture: MigrationFixture;
  let testEnv: RulesTestEnvironment;
  let adminApp: App;

  beforeAll(async () => {
    testEnv = await makeTestEnvironment();
    adminApp = initializeApp(
      { projectId: "demo-tmi" },
      `migration-tests-${Date.now()}`,
    );
  });

  beforeEach(async () => {
    fixture = loadFixture();
    await testEnv.clearFirestore();
  });

  afterAll(async () => {
    await testEnv.cleanup();
    await deleteApp(adminApp);
  });

  it("plans user-scoped and top-level students and plans without writes", () => {
    const plan = buildMigrationPlan(fixture);

    expect(plan.sourceCount).toBe(5);
    expect(plan.writes).toHaveLength(5);
    expect(plan.writes.map((write) => write.manifest.sourcePath)).toEqual(
      expect.arrayContaining([
        "users/teacher-1/students/student-user",
        "users/teacher-1/tmiPlans/plan-user",
        "students/student-top",
        "plans/plan-top",
      ]),
    );
    expect(plan.writes.map((write) => write.manifest.destinationPath)).toEqual(
      expect.arrayContaining([
        "districts/district-a/students/student-user",
        "districts/district-a/plans/plan-user",
        "districts/district-b/students/student-top",
        "districts/district-b/plans/plan-top",
      ]),
    );
  });

  it("keeps the universal release fixture aligned with Gate 0", () => {
    const releaseFixture = loadFixture("release.json");

    expect(buildMigrationPlan(releaseFixture)).toEqual(
      buildMigrationPlan(fixture),
    );
  });

  it("quarantines unresolved ownership and never guesses a tenant", () => {
    const plan = buildMigrationPlan(fixture);
    const unresolved = plan.writes.find(
      (write) => write.manifest.sourcePath === "students/student-unresolved",
    );

    expect(unresolved?.manifest.ownerResolution).toBe("quarantine");
    expect(unresolved?.manifest.destinationPath).toMatch(
      /^migrationQuarantine\/[a-f0-9]{40}$/,
    );
    expect(unresolved?.manifest.destinationPath).not.toContain("districts/");
    expect(unresolved?.data).toMatchObject({
      migrationId: fixture.migrationId,
      legacyPath: "students/student-unresolved",
      legacyId: "student-unresolved",
      reason: "unresolved-tenant-ownership",
    });
  });

  it("uses stable IDs, checksums, and manifests across repeated planning", () => {
    const first = buildMigrationPlan(fixture);
    const second = buildMigrationPlan(fixture);

    expect(second).toEqual(first);
    for (const write of first.writes) {
      expect(write.manifest).toEqual({
        id: expect.stringMatching(/^[a-f0-9]{40}$/),
        sourcePath: expect.any(String),
        destinationPath: expect.any(String),
        schemaVersion: 1,
        ownerResolution: expect.stringMatching(/^(mapped|quarantine)$/),
        checksum: expect.stringMatching(/^[a-f0-9]{64}$/),
      });
      expect(write.data).toMatchObject({
        schemaVersion: 1,
        recordVersion: expect.any(Number),
        createdAt: expect.anything(),
        createdBy: expect.any(String),
        updatedAt: expect.anything(),
        updatedBy: expect.any(String),
        migrationId: fixture.migrationId,
        legacyPath: write.manifest.sourcePath,
        legacyId: write.manifest.sourcePath.split("/").at(-1),
        checksum: write.manifest.checksum,
      });
    }
  });

  it("applies exactly once and makes the second run a no-op", async () => {
    const plan = buildMigrationPlan(fixture);
    const store = new MemoryMigrationStore();

    const first = await applyMigrationPlan(plan, store);
    const second = await applyMigrationPlan(plan, store);

    expect(first).toEqual({
      plannedWrites: 5,
      writesApplied: 5,
      alreadyApplied: 0,
    });
    expect(second).toEqual({
      plannedWrites: 5,
      writesApplied: 0,
      alreadyApplied: 5,
    });
    expect(store.count).toBe(5);
  });

  it("enforces create preconditions against the Firestore emulator", async () => {
    const plan = buildMigrationPlan(fixture);
    const store = new FirestoreMigrationStore(getFirestore(adminApp));

    const first = await applyMigrationPlan(plan, store);
    const second = await applyMigrationPlan(plan, store);
    const report = await reconcileMigrationPlan(plan, store);

    expect(first.writesApplied).toBe(5);
    expect(second).toMatchObject({ writesApplied: 0, alreadyApplied: 5 });
    expect(report.isConsistent).toBe(true);
  });

  it("uses create preconditions and rejects an occupied destination", async () => {
    const plan = buildMigrationPlan(fixture);
    const store = new MemoryMigrationStore();
    const occupiedPath = plan.writes[0]?.manifest.destinationPath;
    expect(occupiedPath).toBeDefined();
    await store.replaceForTesting(occupiedPath ?? "", { owner: "other-data" });

    await expect(applyMigrationPlan(plan, store)).rejects.toBeInstanceOf(
      MigrationConflictError,
    );
  });

  it("reconciles counts, tenant ownership, references, required fields, and equality", async () => {
    const plan = buildMigrationPlan(fixture);
    const store = new MemoryMigrationStore();
    await applyMigrationPlan(plan, store);

    const report = await reconcileMigrationPlan(plan, store);

    expect(report).toEqual({
      expectedCount: 5,
      foundCount: 5,
      mismatches: [],
      isConsistent: true,
    });
  });

  it("reports tampering instead of accepting decoded inequality", async () => {
    const plan = buildMigrationPlan(fixture);
    const store = new MemoryMigrationStore();
    await applyMigrationPlan(plan, store);
    const write = plan.writes.find(
      (candidate) => candidate.manifest.ownerResolution === "mapped",
    );
    expect(write).toBeDefined();
    await store.replaceForTesting(write?.manifest.destinationPath ?? "", {
      ...write?.data,
      name: "Tampered Name",
    });

    const report = await reconcileMigrationPlan(plan, store);

    expect(report.isConsistent).toBe(false);
    expect(report.mismatches).toEqual(
      expect.arrayContaining([
        expect.stringContaining("decoded equality mismatch"),
      ]),
    );
  });

  it("rejects rollback because migrations are forward-only", () => {
    expect(() => rollbackMigration()).toThrow(ForwardOnlyMigrationError);
  });
});
