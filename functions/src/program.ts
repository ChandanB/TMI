import type { Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { programTypeValues, type ProgramType } from "./developerConsole.js";

const isProgramType = (value: unknown): value is ProgramType =>
  typeof value === "string" &&
  (programTypeValues as readonly string[]).includes(value);

/**
 * The effective program for a site: the school's own override, else the
 * organization default, else K-12. Both documents are server-owned.
 */
export const resolveSiteProgram = async (
  firestore: Firestore,
  transaction: Transaction,
  districtID: string,
  schoolID: string,
): Promise<ProgramType> => {
  const [district, school] = await Promise.all([
    transaction.get(firestore.doc(`districts/${districtID}`)),
    transaction.get(firestore.doc(`districts/${districtID}/schools/${schoolID}`)),
  ]);
  const siteProgram = school.data()?.programType;
  if (isProgramType(siteProgram)) return siteProgram;
  const organizationProgram = district.data()?.programType;
  return isProgramType(organizationProgram) ? organizationProgram : "k12";
};

/** Career exploration is not part of the early-childhood program. */
export const requireCareerProgram = (program: ProgramType): void => {
  if (program === "earlyChildhood") {
    throw new HttpsError(
      "failed-precondition",
      "Career exploration is not available for early-childhood sites.",
    );
  }
};
