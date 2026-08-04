import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  buildDebugInvitationRecord,
  debugInvitationScope,
} from "../lib/src/debugInvitation.js";

const argumentsList = process.argv.slice(2);
const [action, code] = argumentsList;
if (
  argumentsList.length !== 2 ||
  !new Set(["seed", "revoke"]).has(action)
) {
  throw new Error(
    "Usage: manage-debug-invitation.mjs <seed|revoke> <opaque-code>",
  );
}

if (process.env.TMI_DEBUG_INVITATION_PROJECT !== debugInvitationScope.projectID) {
  throw new Error("Set TMI_DEBUG_INVITATION_PROJECT=tmi-education explicitly.");
}

const invitation = buildDebugInvitationRecord(code, new Date());
initializeApp({
  credential: applicationDefault(),
  projectId: debugInvitationScope.projectID,
});

const firestore = getFirestore();
const reference = firestore.doc(
  `staffInvitations/${invitation.documentID}`,
);

await firestore.runTransaction(async (transaction) => {
  const snapshot = await transaction.get(reference);
  if (action === "seed") {
    if (snapshot.exists && snapshot.data()?.consumedByUserID != null) {
      throw new Error(
        "The Debug invitation is consumed; rotate it explicitly.",
      );
    }
    transaction.set(reference, invitation.data, { merge: false });
    return;
  }

  if (!snapshot.exists) {
    return;
  }

  const currentVersion = snapshot.data()?.recordVersion;
  const recordVersion =
    typeof currentVersion === "number" &&
    Number.isSafeInteger(currentVersion) &&
    currentVersion >= 1 &&
    currentVersion < Number.MAX_SAFE_INTEGER
      ? currentVersion + 1
      : 2;
  transaction.update(reference, {
    isActive: false,
    recordVersion,
  });
});

const verb = action === "seed" ? "Seeded" : "Revoked";
console.log(
  `${verb} Debug invitation in ${debugInvitationScope.projectID}.`,
);
