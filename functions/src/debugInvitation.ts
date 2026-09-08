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
const commandUsage = "Usage: manage-debug-invitation.mjs <seed|revoke>";

export type DebugInvitationAction = "seed" | "revoke";

const requireOpaqueInvitationCode = (code: string): string => {
  if (!opaqueInvitationPattern.test(code)) {
    throw new Error(
      "Debug access requires a 43-character opaque invitation.",
    );
  }
  return code;
};

export const parseDebugInvitationArguments = (
  argumentsList: readonly string[],
): DebugInvitationAction => {
  const action = argumentsList[0];
  if (
    argumentsList.length !== 1 ||
    (action !== "seed" && action !== "revoke")
  ) {
    throw new Error(commandUsage);
  }

  return action;
};

export const readDebugInvitationCode = (standardInput: string): string =>
  requireOpaqueInvitationCode(standardInput.trim());

export const requireDebugInvitationProject = (
  projectID: string | undefined,
): typeof debugInvitationScope.projectID => {
  if (projectID !== debugInvitationScope.projectID) {
    throw new Error(
      "Set TMI_DEBUG_INVITATION_PROJECT=tmi-education explicitly.",
    );
  }
  return projectID;
};

export const buildDebugInvitationRecord = (code: string, now: Date) => {
  requireOpaqueInvitationCode(code);

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

export type DebugInvitationRecord = ReturnType<
  typeof buildDebugInvitationRecord
>;

export type DebugInvitationAdministration =
  | {
      readonly kind: "set";
      readonly data: DebugInvitationRecord["data"];
    }
  | {
      readonly kind: "update";
      readonly data: {
        readonly isActive: false;
        readonly recordVersion: number;
      };
    }
  | { readonly kind: "none" };

export const planDebugInvitationAdministration = (
  action: DebugInvitationAction,
  invitation: DebugInvitationRecord,
  existingData: Readonly<Record<string, unknown>> | undefined,
): DebugInvitationAdministration => {
  if (action === "seed") {
    if (existingData === undefined) {
      return { kind: "set", data: invitation.data };
    }
    if (existingData?.consumedByUserID != null) {
      throw new Error(
        "The Debug invitation is consumed; rotate it explicitly.",
      );
    }
    return {
      kind: "set",
      data: {
        ...invitation.data,
        recordVersion: nextExistingRecordVersion(existingData),
      },
    };
  }

  if (existingData === undefined) {
    return { kind: "none" };
  }

  return {
    kind: "update",
    data: {
      isActive: false,
      recordVersion: nextExistingRecordVersion(existingData),
    },
  };
};

const nextExistingRecordVersion = (
  existingData: Readonly<Record<string, unknown>>,
): number => {
  const currentVersion = existingData.recordVersion;
  if (
    typeof currentVersion !== "number" ||
    !Number.isSafeInteger(currentVersion) ||
    currentVersion < 1 ||
    currentVersion >= Number.MAX_SAFE_INTEGER
  ) {
    throw new Error(
      "Existing Debug invitation requires a valid positive recordVersion below Number.MAX_SAFE_INTEGER.",
    );
  }
  return currentVersion + 1;
};

export const debugInvitationLogMessage = (
  action: DebugInvitationAction,
): string => `${action} ${debugInvitationScope.projectID}`;
