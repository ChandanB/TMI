import Foundation
import Testing
@testable import TMI

@Suite("Canonical Firestore paths")
struct FirestorePathsTests {
    @Test("Personal profile paths contain no authorization documents")
    func personalProfilePathsAreCanonical() {
        #expect(FirestorePaths.privateProfile(userID: "u1") == "users/u1/private/profile")
        #expect(FirestorePaths.preferences(userID: "u1") == "users/u1/preferences/settings")
    }

    @Test("Student paths are tenant scoped")
    func canonicalStudentPathsAreTenantScoped() {
        #expect(FirestorePaths.students(districtID: "d1") == "districts/d1/students")
        #expect(
            FirestorePaths.student(districtID: "d1", studentID: "s1")
                == "districts/d1/students/s1"
        )
        #expect(
            FirestorePaths.studentInterests(districtID: "d1", studentID: "s1")
                == "districts/d1/students/s1/interests"
        )
        #expect(
            FirestorePaths.studentRestrictedRecords(districtID: "d1", studentID: "s1")
                == "districts/d1/students/s1/restrictedRecords"
        )
        #expect(
            FirestorePaths.studentProgress(districtID: "d1", studentID: "s1")
                == "districts/d1/students/s1/progress"
        )
    }

    @Test("Plan paths are tenant scoped")
    func canonicalPlanPathsAreTenantScoped() {
        #expect(FirestorePaths.plans(districtID: "d1") == "districts/d1/plans")
        #expect(
            FirestorePaths.plan(districtID: "d1", planID: "p1")
                == "districts/d1/plans/p1"
        )
        #expect(
            FirestorePaths.planApprovals(districtID: "d1", planID: "p1")
                == "districts/d1/plans/p1/approvals"
        )
        #expect(
            FirestorePaths.planResources(districtID: "d1", planID: "p1")
                == "districts/d1/plans/p1/resources"
        )
        #expect(
            FirestorePaths.planRevisions(districtID: "d1", planID: "p1")
                == "districts/d1/plans/p1/revisions"
        )
    }

    @Test("Membership and collaboration paths match the blueprint")
    func tenantCollaborationPathsAreCanonical() {
        #expect(FirestorePaths.members(districtID: "d1") == "districts/d1/members")
        #expect(
            FirestorePaths.member(districtID: "d1", userID: "u1")
                == "districts/d1/members/u1"
        )
        #expect(FirestorePaths.formTemplates(districtID: "d1") == "districts/d1/formTemplates")
        #expect(FirestorePaths.formAssignments(districtID: "d1") == "districts/d1/formAssignments")
        #expect(FirestorePaths.resources(districtID: "d1") == "districts/d1/resources")
        #expect(FirestorePaths.notifications(districtID: "d1") == "districts/d1/notifications")
        #expect(FirestorePaths.auditEvents(districtID: "d1") == "districts/d1/auditEvents")
        #expect(FirestorePaths.metricSnapshots(districtID: "d1") == "districts/d1/metricSnapshots")
    }

    @Test("Only the five brand-fixed catalog names are canonical")
    func canonicalCatalogNamesAreExact() {
        #expect(CatalogName.allCases.map(\.rawValue) == [
            "careers",
            "interests",
            "globalResources",
            "tmiModels",
            "surveyDefinitions",
        ])
        #expect(
            FirestorePaths.catalogItems(.careers)
                == "catalogs/careers/items"
        )
        #expect(
            FirestorePaths.catalogItem(.interests, itemID: "i1")
                == "catalogs/interests/items/i1"
        )
    }

    @Test("Production templates contain no legacy collection shape")
    func legacyWriterPathsAreAbsent() {
        let names = FirestorePaths.productionCollectionTemplates

        #expect(!names.contains("users/{uid}/students"))
        #expect(!names.contains("users/{uid}/tmiPlans"))
        #expect(!names.contains("students/{studentId}/studentInterests"))
        #expect(!names.contains("plans/{planId}"))
        #expect(names.contains("districts/{districtId}/students"))
        #expect(names.contains("districts/{districtId}/plans"))
        #expect(names.contains("catalogs/{catalogName}/items"))
    }

    @Test("Every legacy domain has an owning release")
    func legacyPathsHaveMigrationOwners() {
        #expect(
            LegacyFirestorePaths.owner(for: "users/{uid}/students")
                == .release1SecureRoster
        )
        #expect(
            LegacyFirestorePaths.owner(for: "students/{studentId}/studentInterests")
                == .release2Discovery
        )
        #expect(
            LegacyFirestorePaths.owner(for: "users/{uid}/tmiPlans")
                == .release3Intervention
        )
        #expect(
            LegacyFirestorePaths.owner(for: "formAssignments")
                == .release4Collaboration
        )
        #expect(
            LegacyFirestorePaths.owner(for: "generatedResources")
                == .release6OptionalAI
        )
    }

    @Test("Canonical metadata round trips without losing concurrency fields")
    func canonicalMetadataRoundTrips() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = createdAt.addingTimeInterval(60)
        let metadata = CanonicalRecordMetadata(
            schemaVersion: 2,
            recordVersion: 7,
            createdAt: createdAt,
            createdBy: "u1",
            updatedAt: updatedAt,
            updatedBy: "u2"
        )

        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(CanonicalRecordMetadata.self, from: encoded)

        #expect(decoded == metadata)
    }
}
