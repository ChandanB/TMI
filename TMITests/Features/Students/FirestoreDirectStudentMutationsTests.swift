import Testing
@testable import TMI

/// Records written directly by the client must be indistinguishable from
/// records written by the `createStudent` callable. These vectors are generated
/// from the TypeScript implementation in `firebase/src/index.ts`; if either
/// side changes, a retry through the other path would create a duplicate
/// document instead of colliding.
struct FirestoreDirectStudentMutationsTests {
    @Test("Student identifier derivation matches studentIDForCreate")
    func studentIDMatchesServer() {
        #expect(
            FirestoreDirectStudentMutationBackend.studentID(
                districtID: "d1",
                idempotencyKey: "op-1"
            ) == "student_8f8de701d7141b5477ba9f8d2c34eb29"
        )
        #expect(
            FirestoreDirectStudentMutationBackend.studentID(
                districtID: "district-debug",
                idempotencyKey: "abc"
            ) == "student_b07dbb7fa00231e48c7e2d10a2527b9c"
        )
    }

    @Test("Search normalization matches normalizeSearchText")
    func normalizationMatchesServer() {
        #expect(
            FirestoreDirectStudentMutationBackend
                .normalizeSearchText("  José   Álvarez  ") == "jose alvarez"
        )
        #expect(
            FirestoreDirectStudentMutationBackend
                .normalizeSearchText("Taylor Kim") == "taylor kim"
        )
    }

    @Test("The same idempotency key always derives the same document")
    func derivationIsStable() {
        let first = FirestoreDirectStudentMutationBackend.studentID(
            districtID: "d1",
            idempotencyKey: "repeat"
        )
        let second = FirestoreDirectStudentMutationBackend.studentID(
            districtID: "d1",
            idempotencyKey: "repeat"
        )
        #expect(first == second)
        #expect(
            first != FirestoreDirectStudentMutationBackend.studentID(
                districtID: "d2",
                idempotencyKey: "repeat"
            )
        )
    }
}
