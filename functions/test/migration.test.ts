import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { deleteApp, initializeApp, type App } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
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
  type MigrationPlan,
} from "../src/migrationManifest.js";
import {
  applyMigrationPlan,
  FirestoreMigrationStore,
  ForwardOnlyMigrationError,
  MemoryMigrationStore,
  MigrationConflictError,
  MigrationReferenceError,
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

const seedVerifyOnlyWrites = async (
  plan: MigrationPlan,
  store: MemoryMigrationStore,
): Promise<void> => {
  for (const write of plan.writes) {
    if (write.manifest.sourcePath === write.manifest.destinationPath) {
      await store.replaceForTesting(
        write.manifest.destinationPath,
        write.data,
      );
    }
  }
};

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

  it("projects legacy roster fields into the strict canonical student shape", () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const student = releasePlan.writes.find(
      (write) =>
        write.manifest.sourcePath ===
        "users/teacher-1/students/student-strict",
    );

    expect(student?.manifest).toMatchObject({
      destinationPath: "districts/district-a/students/student-strict",
      ownerResolution: "mapped",
    });
    expect(student?.data).toMatchObject({
      districtId: "district-a",
      schoolId: "school-a",
      displayName: "Ava Stone",
      normalizedDisplayName: "ava stone",
      grade: "7",
      studentIdentifier: "A-100",
      normalizedStudentIdentifier: "a-100",
      dateOfBirth: expect.any(Timestamp),
      assignedMemberIDs: ["counselor-1", "teacher-1"],
      isArchived: false,
      schemaVersion: 1,
      recordVersion: 1,
      createdAt: expect.any(Timestamp),
      createdBy: "teacher-1",
      updatedAt: expect.any(Timestamp),
      updatedBy: "teacher-1",
      migrationId: "release1-roster-v1",
      legacyPath: "users/teacher-1/students/student-strict",
      legacyId: "student-strict",
      checksum: expect.stringMatching(/^[a-f0-9]{64}$/),
    });
    expect(student?.data).not.toHaveProperty("name");
    expect(student?.data).not.toHaveProperty("studentID");
    expect(student?.data).not.toHaveProperty("assignedCounselorId");
    expect(student?.data).not.toHaveProperty("primaryTeacherId");
    expect(student?.data).not.toHaveProperty("school");
    expect(Object.keys(student?.data ?? {}).sort()).toEqual([
      "assignedMemberIDs",
      "checksum",
      "createdAt",
      "createdBy",
      "dateOfBirth",
      "displayName",
      "districtId",
      "grade",
      "isArchived",
      "legacyId",
      "legacyPath",
      "migrationId",
      "normalizedDisplayName",
      "normalizedStudentIdentifier",
      "recordVersion",
      "schemaVersion",
      "schoolId",
      "studentIdentifier",
      "updatedAt",
      "updatedBy",
    ]);
  });

  it("maps missing embedded districts only from trusted ownership and quarantines unresolved or conflicting owners", () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const bySourcePath = new Map(
      releasePlan.writes.map((write) => [
        write.manifest.sourcePath,
        write,
      ]),
    );

    expect(
      bySourcePath.get("users/teacher-1/students/student-strict")?.manifest,
    ).toMatchObject({
      destinationPath: "districts/district-a/students/student-strict",
      ownerResolution: "mapped",
    });
    expect(
      bySourcePath.get("students/student-top")?.manifest,
    ).toMatchObject({
      destinationPath: "districts/district-b/students/student-top",
      ownerResolution: "mapped",
    });
    expect(
      bySourcePath.get("students/student-unresolved"),
    ).toMatchObject({
      manifest: {
        ownerResolution: "quarantine",
        destinationPath: expect.stringMatching(
          /^migrationQuarantine\/[a-f0-9]{40}$/,
        ),
      },
      data: {
        reason: "unresolved-tenant-ownership",
      },
    });
    expect(
      bySourcePath.get("students/student-release1-unresolved"),
    ).toMatchObject({
      manifest: {
        ownerResolution: "quarantine",
        destinationPath: expect.stringMatching(
          /^migrationQuarantine\/[a-f0-9]{40}$/,
        ),
      },
      data: {
        reason: "unresolved-tenant-ownership",
      },
    });
    expect(
      bySourcePath.get("students/student-conflict"),
    ).toMatchObject({
      manifest: {
        ownerResolution: "quarantine",
        destinationPath: expect.stringMatching(
          /^migrationQuarantine\/[a-f0-9]{40}$/,
        ),
      },
      data: {
        reason: "tenant-ownership-conflict",
      },
    });
  });

  it("quarantines a student whose school is not trusted for the resolved district", () => {
    const releaseFixture = loadFixture("release1.json");
    const crossDistrictSchoolFixture: MigrationFixture = {
      ...releaseFixture,
      documents: releaseFixture.documents.map((document) =>
        document.path === "students/student-top"
          ? {
              ...document,
              data: {
                ...document.data,
                schoolId: "school-a",
              },
            }
          : document,
      ),
    };

    const student = buildMigrationPlan(
      crossDistrictSchoolFixture,
    ).writes.find(
      (write) => write.manifest.sourcePath === "students/student-top",
    );

    expect(student).toMatchObject({
      manifest: {
        ownerResolution: "quarantine",
        destinationPath: expect.stringMatching(
          /^migrationQuarantine\/[a-f0-9]{40}$/,
        ),
      },
      data: {
        reason: "unresolved-school-ownership",
      },
    });
  });

  it("verifies already-canonical students in place without overwriting them", () => {
    const releaseFixture = loadFixture("release1.json");
    const releasePlan = buildMigrationPlan(releaseFixture);
    const canonical = releasePlan.writes.find(
      (write) =>
        write.manifest.sourcePath ===
        "districts/district-a/students/student-duplicate",
    );

    expect(canonical?.manifest).toMatchObject({
      destinationPath:
        "districts/district-a/students/student-duplicate",
      ownerResolution: "mapped",
    });
    expect(canonical?.data).toMatchObject({
      districtId: "district-a",
      schoolId: "school-a",
      displayName: "Canonical Student",
      normalizedDisplayName: "canonical student",
      assignedMemberIDs: [],
      isArchived: false,
      schemaVersion: 1,
      recordVersion: 3,
      createdAt: expect.any(Timestamp),
      updatedAt: expect.any(Timestamp),
    });
    expect(canonical?.data).not.toHaveProperty("migrationId");
    expect(canonical?.data).not.toHaveProperty("legacyPath");
    expect(canonical?.data).not.toHaveProperty("legacyId");
    expect(canonical?.data).not.toHaveProperty("checksum");
  });

  it("never creates a missing already-canonical source during apply", async () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();

    await expect(applyMigrationPlan(releasePlan, store)).rejects.toThrow(
      /canonical.*verif|verif.*canonical/iu,
    );
    expect(store.count).toBe(0);
  });

  it("keeps a canonical destination and quarantines a colliding legacy duplicate", () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const canonical = releasePlan.writes.find(
      (write) =>
        write.manifest.sourcePath ===
        "districts/district-a/students/student-duplicate",
    );
    const duplicate = releasePlan.writes.find(
      (write) =>
        write.manifest.sourcePath === "students/student-duplicate",
    );
    const destinations = releasePlan.writes.map(
      (write) => write.manifest.destinationPath,
    );

    expect(canonical?.manifest.destinationPath).toBe(
      "districts/district-a/students/student-duplicate",
    );
    expect(duplicate).toMatchObject({
      manifest: {
        ownerResolution: "quarantine",
        destinationPath: expect.stringMatching(
          /^migrationQuarantine\/[a-f0-9]{40}$/,
        ),
      },
      data: {
        reason: "duplicate-canonical-destination",
        canonicalDestinationPath:
          "districts/district-a/students/student-duplicate",
      },
    });
    expect(new Set(destinations).size).toBe(destinations.length);
  });

  it("preserves archived roster state in the canonical projection", () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const archived = releasePlan.writes.find(
      (write) =>
        write.manifest.sourcePath === "students/student-archived",
    );

    expect(archived).toMatchObject({
      manifest: {
        destinationPath:
          "districts/district-a/students/student-archived",
        ownerResolution: "mapped",
      },
      data: {
        displayName: "Archived Student",
        isArchived: true,
        recordVersion: 4,
      },
    });
  });

  it("applies Release 1 once, recognizes canonical data, and reconciles plan references", async () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();
    const canonicalSources = releasePlan.writes.filter(
      (write) =>
        write.manifest.sourcePath === write.manifest.destinationPath,
    );
    expect(canonicalSources).toHaveLength(3);
    for (const write of canonicalSources) {
      await store.replaceForTesting(
        write.manifest.destinationPath,
        write.data,
      );
    }

    const first = await applyMigrationPlan(releasePlan, store);
    const second = await applyMigrationPlan(releasePlan, store);
    const report = await reconcileMigrationPlan(releasePlan, store);

    expect(first).toEqual({
      plannedWrites: 13,
      writesApplied: 10,
      alreadyApplied: 3,
    });
    expect(second).toEqual({
      plannedWrites: 13,
      writesApplied: 0,
      alreadyApplied: 13,
    });
    expect(report).toEqual({
      expectedCount: 13,
      foundCount: 13,
      mismatches: [],
      isConsistent: true,
    });
  });

  it("does not reconcile an assigned student when a canonical member is missing", async () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();
    await seedVerifyOnlyWrites(releasePlan, store);
    await applyMigrationPlan(releasePlan, store);
    await store.deleteForTesting(
      "districts/district-a/members/teacher-1",
    );

    const report = await reconcileMigrationPlan(releasePlan, store);

    expect(report.isConsistent).toBe(false);
    expect(report.mismatches).toEqual(
      expect.arrayContaining([
        expect.stringContaining("missing assigned member (teacher-1)"),
      ]),
    );
  });

  it("does not reconcile a member missing the assigned student back-reference", async () => {
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();
    await seedVerifyOnlyWrites(releasePlan, store);
    await applyMigrationPlan(releasePlan, store);
    const memberPath = "districts/district-a/members/teacher-1";
    const member = await store.read(memberPath);
    expect(member).not.toBeNull();
    await store.replaceForTesting(memberPath, {
      ...member,
      assignedStudentIDs: [],
    });

    const report = await reconcileMigrationPlan(releasePlan, store);

    expect(report.isConsistent).toBe(false);
    expect(report.mismatches).toEqual(
      expect.arrayContaining([
        expect.stringContaining(
          "missing student back-reference (student-strict)",
        ),
      ]),
    );
  });

  it("rejects a missing assigned member before applying any writes", async () => {
    const releaseFixture = loadFixture("release1.json");
    const invalidFixture: MigrationFixture = {
      ...releaseFixture,
      documents: releaseFixture.documents.filter(
        (document) =>
          document.path !==
          "districts/district-a/members/teacher-1",
      ),
    };
    const plan = buildMigrationPlan(invalidFixture);
    const store = new MemoryMigrationStore();
    await seedVerifyOnlyWrites(plan, store);
    const seededCount = store.count;

    await expect(applyMigrationPlan(plan, store)).rejects.toBeInstanceOf(
      MigrationReferenceError,
    );
    expect(store.count).toBe(seededCount);
    expect(
      await store.read(
        "districts/district-a/students/student-strict",
      ),
    ).toBeNull();
  });

  it("rejects a missing assignment back-reference before applying any writes", async () => {
    const releaseFixture = loadFixture("release1.json");
    const invalidFixture: MigrationFixture = {
      ...releaseFixture,
      documents: releaseFixture.documents.map((document) =>
        document.path ===
        "districts/district-a/members/teacher-1"
          ? {
              ...document,
              data: {
                ...document.data,
                assignedStudentIDs: [],
              },
            }
          : document,
      ),
    };
    const plan = buildMigrationPlan(invalidFixture);
    const store = new MemoryMigrationStore();
    await seedVerifyOnlyWrites(plan, store);
    const seededCount = store.count;

    await expect(applyMigrationPlan(plan, store)).rejects.toBeInstanceOf(
      MigrationReferenceError,
    );
    expect(store.count).toBe(seededCount);
    expect(
      await store.read(
        "districts/district-a/students/student-strict",
      ),
    ).toBeNull();
  });

  it("upgrades Gate 0 outputs to Release 1 once and then becomes a no-op", async () => {
    const gatePlan = buildMigrationPlan(loadFixture());
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();
    await applyMigrationPlan(gatePlan, store);
    await seedVerifyOnlyWrites(releasePlan, store);

    const first = await applyMigrationPlan(releasePlan, store);
    const second = await applyMigrationPlan(releasePlan, store);
    const report = await reconcileMigrationPlan(releasePlan, store);

    expect(first).toEqual({
      plannedWrites: 13,
      writesApplied: 10,
      alreadyApplied: 3,
    });
    expect(second).toEqual({
      plannedWrites: 13,
      writesApplied: 0,
      alreadyApplied: 13,
    });
    expect(report.isConsistent).toBe(true);
    expect(report.mismatches).toEqual([]);
  });

  it("rejects an unsafe or modified predecessor before writing Release 1 data", async () => {
    const gatePlan = buildMigrationPlan(loadFixture());
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const store = new MemoryMigrationStore();
    await applyMigrationPlan(gatePlan, store);
    await seedVerifyOnlyWrites(releasePlan, store);
    const overlappingPath =
      "districts/district-a/students/student-user";
    const predecessor = await store.read(overlappingPath);
    expect(predecessor).not.toBeNull();
    await store.replaceForTesting(overlappingPath, {
      ...predecessor,
      displayName: "Modified predecessor",
    });

    await expect(
      applyMigrationPlan(releasePlan, store),
    ).rejects.toBeInstanceOf(MigrationConflictError);
    expect(
      await store.read(
        "districts/district-a/students/student-strict",
      ),
    ).toBeNull();
  });

  it("uses Firestore compare-and-swap for the Gate 0 to Release 1 upgrade", async () => {
    const gatePlan = buildMigrationPlan(loadFixture());
    const releasePlan = buildMigrationPlan(loadFixture("release1.json"));
    const firestore = getFirestore(adminApp);
    const store = new FirestoreMigrationStore(firestore);
    await applyMigrationPlan(gatePlan, store);
    for (const write of releasePlan.writes) {
      if (write.manifest.sourcePath === write.manifest.destinationPath) {
        await firestore.doc(write.manifest.destinationPath).create(write.data);
      }
    }

    const first = await applyMigrationPlan(releasePlan, store);
    const second = await applyMigrationPlan(releasePlan, store);
    const report = await reconcileMigrationPlan(releasePlan, store);

    expect(first).toMatchObject({
      writesApplied: 10,
      alreadyApplied: 3,
    });
    expect(second).toMatchObject({
      writesApplied: 0,
      alreadyApplied: 13,
    });
    expect(report.isConsistent).toBe(true);
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
