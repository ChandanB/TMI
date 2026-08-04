import { Timestamp } from "firebase-admin/firestore";
import {
  hashInvitationCode,
  hashInvitationRecipientEmail,
} from "./invitations.js";

export const debugInvitationScope = {
  projectID: "tmi-education",
  email: "tmi-debug@example.com",
  districtID: "district-debug",
  schoolIDs: ["school-debug"],
  capabilities: ["student.read.detail", "student.write.detail"],
} as const;

const opaqueInvitationPattern = /^[A-Za-z0-9_-]{43}$/;
const thirtyDaysInMilliseconds = 30 * 86_400_000;

export const buildDebugInvitationRecord = (code: string, now: Date) => {
  if (!opaqueInvitationPattern.test(code)) {
    throw new Error(
      "Debug access requires a 43-character opaque invitation.",
    );
  }

  return {
    documentID: hashInvitationCode(code),
    data: {
      schemaVersion: 1,
      recordVersion: 1,
      districtID: debugInvitationScope.districtID,
      recipientEmailHash: hashInvitationRecipientEmail(
        code,
        debugInvitationScope.email,
      ),
      role: "teacher" as const,
      schoolIDs: [...debugInvitationScope.schoolIDs],
      capabilities: [...debugInvitationScope.capabilities],
      isActive: true,
      expiresAt: Timestamp.fromDate(
        new Date(now.getTime() + thirtyDaysInMilliseconds),
      ),
      consumedByUserID: null,
      consumedAt: null,
    },
  };
};
