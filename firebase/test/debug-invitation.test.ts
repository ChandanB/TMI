import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase-admin/firestore";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { fileURLToPath } from "node:url";
import {
  hashInvitationCode,
  hashInvitationRecipientEmail,
} from "../src/invitations.js";
import {
  buildDebugInvitationRecord,
  debugInvitationLogMessage,
  debugInvitationScope,
  parseDebugInvitationArguments,
  planDebugInvitationAdministration,
  readDebugInvitationCode,
  requireDebugInvitationProject,
} from "../src/debugInvitation.js";

const invitationCode = "VE1JLURlYnVnLUNhbm9uaWNhbC1JbnZpdGUtMjAyNiE";
const now = new Date("2026-08-04T16:30:00.000Z");
const firebaseRoot = fileURLToPath(new URL("..", import.meta.url));

describe("canonical Debug invitation", () => {
  it("exports the exact bounded project and staff scope", () => {
    expect(debugInvitationScope).toEqual({
      projectID: "tmi-education",
      email: "tmi-debug@example.com",
      districtID: "district-debug",
      schoolIDs: ["school-debug"],
      capabilities: ["student.read.detail", "student.write.detail"],
    });
  });

  it("builds the trusted invitation record with code-bound hashes", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(invitation.documentID).toBe(hashInvitationCode(invitationCode));
    expect(invitation.data).toEqual({
      schemaVersion: 1,
      recordVersion: 1,
      districtID: "district-debug",
      recipientEmailHash: hashInvitationRecipientEmail(
        invitationCode,
        "tmi-debug@example.com",
      ),
      role: "teacher",
      schoolIDs: ["school-debug"],
      capabilities: ["student.read.detail", "student.write.detail"],
      isActive: true,
      expiresAt: Timestamp.fromDate(
        new Date(now.getTime() + 30 * 86_400_000),
      ),
      consumedByUserID: null,
      consumedAt: null,
    });
  });

  it("expires exactly 30 days after the supplied time without mutating it", () => {
    const originalTime = now.getTime();
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(invitation.data.expiresAt.toMillis()).toBe(
      originalTime + 30 * 86_400_000,
    );
    expect(now.getTime()).toBe(originalTime);
  });

  it("returns independent scope arrays for each record", () => {
    const first = buildDebugInvitationRecord(invitationCode, now);
    const second = buildDebugInvitationRecord(invitationCode, now);

    expect(first.data.schoolIDs).not.toBe(debugInvitationScope.schoolIDs);
    expect(first.data.capabilities).not.toBe(debugInvitationScope.capabilities);
    expect(first.data.schoolIDs).not.toBe(second.data.schoolIDs);
    expect(first.data.capabilities).not.toBe(second.data.capabilities);

    (first.data.schoolIDs as string[]).push("school-unexpected");
    (first.data.capabilities as string[]).push("student.delete");

    expect(debugInvitationScope.schoolIDs).toEqual(["school-debug"]);
    expect(debugInvitationScope.capabilities).toEqual([
      "student.read.detail",
      "student.write.detail",
    ]);
    expect(second.data.schoolIDs).toEqual(["school-debug"]);
    expect(second.data.capabilities).toEqual([
      "student.read.detail",
      "student.write.detail",
    ]);
  });

  it.each([
    "too-short",
    `${invitationCode}A`,
    "VE1JLURlYnVnLUNhbm9uaWNhbC1JbnZpdGUtMjAyNi!",
  ])("rejects malformed opaque invitation %s", (malformedCode) => {
    expect(() => buildDebugInvitationRecord(malformedCode, now)).toThrow(
      /43-character opaque invitation/,
    );
  });
});

describe("Debug invitation administration", () => {
  it.each(["seed", "revoke"] as const)(
    "parses an exact %s action without accepting a code in argv",
    (action) => {
      expect(parseDebugInvitationArguments([action])).toBe(action);
      expect(() =>
        parseDebugInvitationArguments([action, invitationCode]),
      ).toThrow(/Usage: manage-debug-invitation\.mjs <seed\|revoke>$/);
    },
  );

  it.each([
    { argumentsList: [] },
    { argumentsList: ["seed", "unexpected"] },
    { argumentsList: ["delete"] },
    { argumentsList: ["delete", invitationCode] },
  ])("rejects invalid command arguments $argumentsList", ({ argumentsList }) => {
    expect(() => parseDebugInvitationArguments(argumentsList)).toThrow(
      /Usage: manage-debug-invitation\.mjs <seed\|revoke>$/,
    );
  });

  it("reads exactly one trimmed opaque invitation from stdin", () => {
    expect(readDebugInvitationCode(`  ${invitationCode}\n`)).toBe(
      invitationCode,
    );
    expect(() => readDebugInvitationCode("too-short")).toThrow(
      /43-character opaque invitation/,
    );
    expect(() =>
      readDebugInvitationCode(`${invitationCode}\n${invitationCode}`),
    ).toThrow(/43-character opaque invitation/);
  });

  it("requires the exact production project guard", () => {
    expect(requireDebugInvitationProject("tmi-education")).toBe(
      "tmi-education",
    );
    expect(() => requireDebugInvitationProject(undefined)).toThrow(
      /TMI_DEBUG_INVITATION_PROJECT=tmi-education/,
    );
    expect(() => requireDebugInvitationProject("demo-tmi")).toThrow(
      /TMI_DEBUG_INVITATION_PROJECT=tmi-education/,
    );
  });

  it("plans canonical creation when seeding an absent invitation", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(
      planDebugInvitationAdministration("seed", invitation, undefined),
    ).toEqual({ kind: "set", data: invitation.data });
  });

  it("plans canonical replacement when seeding an unconsumed invitation", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(
      planDebugInvitationAdministration("seed", invitation, {
        consumedByUserID: null,
        recordVersion: 19,
        isActive: false,
      }),
    ).toEqual({
      kind: "set",
      data: { ...invitation.data, recordVersion: 20 },
    });
  });

  it("rejects a consumed seed without producing a write", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(() =>
      planDebugInvitationAdministration("seed", invitation, {
        consumedByUserID: "staff-already-consumed",
      }),
    ).toThrow(/consumed; rotate it explicitly/);
  });

  it("plans no write when revoking an absent invitation", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(
      planDebugInvitationAdministration("revoke", invitation, undefined),
    ).toEqual({ kind: "none" });
  });

  it("plans deactivation and increments a valid record version", () => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(
      planDebugInvitationAdministration("revoke", invitation, {
        recordVersion: 19,
      }),
    ).toEqual({
      kind: "update",
      data: { isActive: false, recordVersion: 20 },
    });
  });

  it.each([
    undefined,
    "19",
    Number.NaN,
    0,
    -1,
    1.5,
    Number.MAX_SAFE_INTEGER,
    Number.MAX_SAFE_INTEGER + 1,
  ])("fails closed for malformed seed version %s", (recordVersion) => {
    const invitation = buildDebugInvitationRecord(invitationCode, now);

    expect(() =>
      planDebugInvitationAdministration("seed", invitation, {
        consumedByUserID: null,
        recordVersion,
      }),
    ).toThrow(/valid positive recordVersion below Number\.MAX_SAFE_INTEGER/);
  });

  it.each([
    undefined,
    "19",
    Number.NaN,
    0,
    -1,
    1.5,
    Number.MAX_SAFE_INTEGER,
    Number.MAX_SAFE_INTEGER + 1,
  ])("fails closed for malformed revoke version %s", (recordVersion) => {
      const invitation = buildDebugInvitationRecord(invitationCode, now);

      expect(() =>
        planDebugInvitationAdministration("revoke", invitation, {
          recordVersion,
        }),
      ).toThrow(/valid positive recordVersion below Number\.MAX_SAFE_INTEGER/);
  });

  it("does not expose a stdin secret when the subprocess rejects it", async () => {
    const distinctiveSecret =
      "DISTINCTIVE_DEBUG_INVITATION_SECRET_THAT_MUST_NOT_LEAK";
    const child = spawn(
      "npm",
      ["run", "debug-invitation:seed"],
      {
        cwd: firebaseRoot,
        env: {
          ...process.env,
          TMI_DEBUG_INVITATION_PROJECT: "tmi-education",
        },
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    let output = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => { output += chunk; });
    child.stderr.on("data", (chunk: string) => { output += chunk; });
    child.stdin.end(`${distinctiveSecret}\n`);

    const [exitCode] = await once(child, "close");

    expect(exitCode).not.toBe(0);
    expect(output).toMatch(/43-character opaque invitation/);
    expect(output).not.toContain(distinctiveSecret);
    expect(output).not.toContain("<opaque-code>");
  });

  it.each(["seed", "revoke"] as const)(
    "formats a secret-safe %s log with only action and project",
    (action) => {
      const invitation = buildDebugInvitationRecord(invitationCode, now);
      const message = debugInvitationLogMessage(action);

      expect(message).toBe(`${action} tmi-education`);
      expect(message).not.toContain(invitationCode);
      expect(message).not.toContain(invitation.documentID);
      expect(message).not.toContain(invitation.data.recipientEmailHash);
    },
  );
});
