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
  const normalizedName = {
    fieldPath: "normalizedDisplayName",
    order: "ASCENDING",
  } as const;
  const normalizedIdentifier = {
    fieldPath: "normalizedStudentIdentifier",
    order: "ASCENDING",
  } as const;
  const recentOrder = [
    { fieldPath: "updatedAt", order: "DESCENDING" },
    { fieldPath: "__name__", order: "ASCENDING" },
  ] as const;

  for (let mask = 0; mask < 1 << equalityFields.length; mask += 1) {
    const selected = equalityFields.filter(
      (_, index) => (mask & (1 << index)) !== 0,
    );

    const alphabetical = [...selected, normalizedName];
    if (alphabetical.length >= 2) {
      required.add(signature(alphabetical));
    }
    required.add(signature([
      ...selected,
      normalizedIdentifier,
      normalizedName,
    ]));

    required.add(signature([...selected, ...recentOrder]));
    required.add(signature([
      ...selected,
      normalizedIdentifier,
      ...recentOrder,
    ]));
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

    expect(expected.size).toBe(63);
    expect(actual).toEqual(expected);
    expect(configuration.indexes).toHaveLength(68);
    expect(configuration.indexes.length).toBeLessThanOrEqual(200);
    expect(
      studentIndexes.some((index) =>
        index.fields.some((field) => field.fieldPath === "name"),
      ),
    ).toBe(false);
  });
});
