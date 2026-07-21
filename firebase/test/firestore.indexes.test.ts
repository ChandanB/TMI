import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

type IndexField =
  | { readonly fieldPath: string; readonly order: "ASCENDING" | "DESCENDING" }
  | { readonly fieldPath: string; readonly arrayConfig: "CONTAINS" };

interface FirestoreIndex {
  readonly collectionGroup: string;
  readonly queryScope: "COLLECTION" | "COLLECTION_GROUP";
  readonly fields: readonly IndexField[];
}

interface FirestoreIndexConfiguration {
  readonly indexes: readonly FirestoreIndex[];
  readonly fieldOverrides: readonly unknown[];
}

const equalityFields: readonly IndexField[] = [
  { fieldPath: "schoolId", order: "ASCENDING" },
  { fieldPath: "assignedMemberIDs", arrayConfig: "CONTAINS" },
  { fieldPath: "grade", order: "ASCENDING" },
  { fieldPath: "isArchived", order: "ASCENDING" },
];

const signature = (fields: readonly IndexField[]): string =>
  JSON.stringify(fields);

const requiredStudentIndexSignatures = (): ReadonlySet<string> => {
  const required = new Set<string>();
  for (let mask = 0; mask < 1 << equalityFields.length; mask += 1) {
    const selected = equalityFields.filter(
      (_, index) => (mask & (1 << index)) !== 0,
    );
    for (const searchField of [
      null,
      { fieldPath: "normalizedStudentIdentifier", order: "ASCENDING" } as const,
      { fieldPath: "normalizedDisplayName", order: "ASCENDING" } as const,
    ]) {
      const fields =
        searchField === null ? selected : [...selected, searchField];
      // Zero- and one-field plans are covered by Firestore's automatic
      // single-field indexes. Every compound shape is provisioned explicitly.
      if (fields.length >= 2) {
        required.add(signature(fields));
      }
    }
  }
  return required;
};

describe("production Firestore indexes", () => {
  it("covers every compound student query shape emitted by the roster planner", () => {
    const configuration = JSON.parse(
      readFileSync(resolve(process.cwd(), "../firestore.indexes.json"), "utf8"),
    ) as FirestoreIndexConfiguration;
    const studentIndexes = configuration.indexes.filter(
      (index) => index.collectionGroup === "students",
    );
    const actual = new Set(
      studentIndexes.map((index) => {
        expect(index.queryScope).toBe("COLLECTION");
        return signature(index.fields);
      }),
    );
    const expected = requiredStudentIndexSignatures();

    expect(expected.size).toBe(41);
    expect(actual).toEqual(expected);
    expect(
      studentIndexes.some((index) =>
        index.fields.some((field) => field.fieldPath === "name"),
      ),
    ).toBe(false);
  });
});
