import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { pathToFileURL } from "node:url";
import {
  buildDebugInvitationRecord,
  debugInvitationLogMessage,
  debugInvitationScope,
  parseDebugInvitationArguments,
  planDebugInvitationAdministration,
  requireDebugInvitationProject,
} from "../lib/src/debugInvitation.js";

export const main = async () => {
  const command = parseDebugInvitationArguments(process.argv.slice(2));
  requireDebugInvitationProject(
    process.env.TMI_DEBUG_INVITATION_PROJECT,
  );
  const invitation = buildDebugInvitationRecord(command.code, new Date());
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
    const administration = planDebugInvitationAdministration(
      command.action,
      invitation,
      snapshot.exists ? snapshot.data() : undefined,
    );
    if (administration.kind === "set") {
      transaction.set(reference, administration.data, { merge: false });
    } else if (administration.kind === "update") {
      transaction.update(reference, administration.data);
    }
  });

  console.log(debugInvitationLogMessage(command.action));
};

const isMain =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  await main();
}
