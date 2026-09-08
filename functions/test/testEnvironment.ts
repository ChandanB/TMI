import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const hostAndPort = (value: string | undefined, fallbackPort: number) => {
  const [host = "127.0.0.1", rawPort] = value?.split(":") ?? [];
  return { host, port: Number(rawPort ?? fallbackPort) };
};

export const trustedClaims = (
  districtID: string,
  membershipVersion = 1,
) => ({
  tmiDistrictID: districtID,
  tmiAccessClass: "staff",
  tmiMembershipVersion: membershipVersion,
});

export const activeMembership = (
  overrides: Record<string, unknown> = {},
) => ({
  schoolIDs: ["school-1"],
  role: "teacher",
  capabilities: [],
  assignedStudentIDs: ["student-1"],
  isActive: true,
  version: 1,
  ...overrides,
});

export async function makeTestEnvironment(): Promise<RulesTestEnvironment> {
  const firestore = hostAndPort(process.env.FIRESTORE_EMULATOR_HOST, 8080);
  const storage = hostAndPort(process.env.FIREBASE_STORAGE_EMULATOR_HOST, 9199);

  return initializeTestEnvironment({
    projectId: "demo-tmi",
    firestore: {
      ...firestore,
      rules: readFileSync(resolve(process.cwd(), "../firestore.rules"), "utf8"),
    },
    storage: {
      ...storage,
      rules: readFileSync(resolve(process.cwd(), "../storage.rules"), "utf8"),
    },
  });
}
