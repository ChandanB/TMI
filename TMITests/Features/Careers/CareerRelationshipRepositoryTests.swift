import Foundation
@preconcurrency import FirebaseFirestore
import Testing
@testable import TMI

@Suite("Career relationship persistence")
@MainActor
struct CareerRelationshipRepositoryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_000)
    private let updatedAt = Date(timeIntervalSince1970: 2_000)

    @Test("Canonical relationship fields round trip without changing identity")
    func canonicalFieldsRoundTrip() throws {
        let relationship = CareerRelationship(
            studentID: "student-1",
            careerID: "technology--frontend-developer",
            isSaved: true,
            isCompared: true,
            linkedPlanIDs: ["plan-2", "plan-1"],
            lastViewedAt: updatedAt,
            updatedAt: updatedAt,
            updatedBy: "teacher-2",
            recordVersion: 3,
            createdAt: createdAt,
            createdBy: "teacher-1"
        )

        let fields = CareerRelationshipRepository.fields(
            relationship,
            districtID: "district-1"
        )
        let decoded = try #require(
            CareerRelationshipRepository.record(
                id: relationship.careerID,
                data: fields,
                expectedDistrictID: "district-1",
                expectedStudentID: "student-1"
            )
        )

        #expect(fields["districtID"] as? String == "district-1")
        #expect(decoded == relationship)
        #expect(decoded.linkedPlanIDs == ["plan-1", "plan-2"])
    }

    @Test("Saving and dismissing remain exclusive across updates")
    func savedAndDismissedAreExclusiveAcrossUpdates() {
        let original = relationship()
        let saved = original.settingSaved(true, at: updatedAt, by: "teacher-1")
        let dismissed = saved.settingDismissed(true, at: updatedAt, by: "teacher-1")

        #expect(saved.isSaved)
        #expect(!saved.isDismissed)
        #expect(!dismissed.isSaved)
        #expect(dismissed.isDismissed)
        #expect(dismissed.recordVersion == original.recordVersion + 2)
    }

    @Test("Viewing and comparing are independent from a career opinion")
    func viewingAndComparingAreIndependent() {
        let original = relationship()
        let compared = original.settingCompared(true, at: updatedAt, by: "teacher-1")
        let viewed = compared.markingViewed(at: updatedAt, by: "teacher-1")

        #expect(viewed.isCompared)
        #expect(viewed.lastViewedAt == updatedAt)
        #expect(!viewed.hasStudentOpinion)
        #expect(viewed.recordVersion == original.recordVersion + 2)
    }

    @Test("Malformed or mismatched Firestore identity fails closed")
    func malformedIdentityFailsClosed() {
        var fields = CareerRelationshipRepository.fields(
            relationship(),
            districtID: "district-1"
        )
        fields["careerID"] = "health--nurse"

        #expect(
            CareerRelationshipRepository.record(
                id: "technology--frontend-developer",
                data: fields,
                expectedDistrictID: "district-1",
                expectedStudentID: "student-1"
            ) == nil
        )

        fields["careerID"] = "technology--frontend-developer"
        #expect(
            CareerRelationshipRepository.record(
                id: "technology--frontend-developer",
                data: fields,
                expectedDistrictID: "different-district",
                expectedStudentID: "student-1"
            ) == nil
        )
    }

    private func relationship() -> CareerRelationship {
        CareerRelationship(
            studentID: "student-1",
            careerID: "technology--frontend-developer",
            updatedAt: createdAt,
            updatedBy: "teacher-1",
            recordVersion: 1,
            createdAt: createdAt,
            createdBy: "teacher-1"
        )
    }
}
