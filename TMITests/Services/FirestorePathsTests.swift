import Testing
@testable import TMI

@Suite("FirestorePaths")
struct FirestorePathsTests {
    @Test("students returns district path when districtId provided")
    func studentsWithDistrictId() throws {
        let path = try FirestorePaths.students(districtId: "district1", userId: nil)
        #expect(path.contains("district1"))
    }

    @Test("students returns user path when userId provided")
    func studentsWithUserId() throws {
        let path = try FirestorePaths.students(districtId: nil, userId: "user1")
        #expect(path.contains("user1"))
    }

    @Test("students throws when both nil")
    func studentsWithBothNil() {
        #expect(throws: FirestorePathError.self) {
            try FirestorePaths.students(districtId: nil, userId: nil)
        }
    }

    @Test("plans returns district path when districtId provided")
    func plansWithDistrictId() throws {
        let path = try FirestorePaths.plans(districtId: "district1", userId: nil)
        #expect(path.contains("district1"))
    }

    @Test("plans returns user path when userId provided")
    func plansWithUserId() throws {
        let path = try FirestorePaths.plans(districtId: nil, userId: "user1")
        #expect(path.contains("user1"))
    }

    @Test("plans throws when both nil")
    func plansWithBothNil() {
        #expect(throws: FirestorePathError.self) {
            try FirestorePaths.plans(districtId: nil, userId: nil)
        }
    }
}
