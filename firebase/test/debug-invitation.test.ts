import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase-admin/firestore";
import {
  hashInvitationCode,
  hashInvitationRecipientEmail,
} from "../src/invitations.js";
import {
  buildDebugInvitationRecord,
  debugInvitationScope,
} from "../src/debugInvitation.js";

const invitationCode = "VE1JLURlYnVnLUNhbm9uaWNhbC1JbnZpdGUtMjAyNiE";
const now = new Date("2026-08-04T16:30:00.000Z");

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
