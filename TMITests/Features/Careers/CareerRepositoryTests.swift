import Foundation
import Testing
@testable import TMI

@Suite("Canonical career catalog")
@MainActor
struct CareerRepositoryTests {
    @Test("The shipped catalog maps onto canonical records without loss of entries")
    func shippedCatalogMapsCompletely() {
        let records = BundledCareerCatalog().careers()

        // All 537 shipped careers are distinct, so mapping drops none of them.
        #expect(records.count == CareerCatalog.allCareers.count)
        #expect(!records.isEmpty)
    }

    @Test("The canonical catalog is deduplicated and stably ordered")
    func catalogIsDeterministic() {
        let first = BundledCareerCatalog().careers()
        let fromReversedSource = BundledCareerCatalog(
            source: CareerCatalog.allCareers.reversed()
        ).careers()

        #expect(first.map(\.id) == fromReversedSource.map(\.id))
        #expect(first.map(\.id) == first.map(\.id).sorted())
        #expect(Set(first.map(\.id)).count == first.count)
    }

    @Test("A duplicated entry collapses to one career")
    func duplicatesCollapse() {
        let duplicated = [
            careerPath(title: "Frontend Developer", category: "technology"),
            careerPath(title: "  frontend   developer ", category: "Technology"),
        ]

        let records = BundledCareerCatalog(source: duplicated).careers()

        #expect(records.count == 1)
        #expect(records[0].id == "technology/frontend-developer")
    }

    @Test("No canonical career states a salary the catalog cannot source")
    func noUnsourcedFigures() {
        // The bundled data carries ranges with no source and no date. Carrying
        // them over would present an unattributed number to a student as fact.
        let records = BundledCareerCatalog().careers()

        #expect(records.allSatisfy { $0.salary == nil })
        #expect(records.allSatisfy { $0.outlook == nil })
    }

    @Test("Education level survives the mapping")
    func educationLevelIsLossless() {
        // Masters and doctorate stay distinct; a student choosing a path cares
        // which one it is.
        #expect(BundledCareerCatalog.educationLevel(from: .masters) == .masters)
        #expect(BundledCareerCatalog.educationLevel(from: .doctorate) == .doctorate)
        #expect(BundledCareerCatalog.educationLevel(from: .vocational) == .certificate)
        #expect(BundledCareerCatalog.educationLevel(from: .certification) == .certificate)
        #expect(BundledCareerCatalog.educationLevel(from: .someCollege) == .associates)
        #expect(BundledCareerCatalog.educationLevel(from: .highSchool) == .highSchool)
        #expect(BundledCareerCatalog.educationLevel(from: .varies) == .varies)
    }

    @Test("Every canonical career keeps something to match on")
    func everyCareerRemainsMatchable() {
        let records = BundledCareerCatalog().careers()
        let unmatchable = records.filter { $0.interestIDs.isEmpty && $0.clusterIDs.isEmpty }

        #expect(
            unmatchable.isEmpty,
            "Careers that can never be matched: \(unmatchable.map(\.id).sorted().prefix(10))"
        )
    }

    @Test("The repository matches against the canonical catalog")
    func repositoryMatchesFromCatalog() {
        let repository = CareerRepository(
            catalog: BundledCareerCatalog(source: [
                careerPath(title: "Frontend Developer", category: "technology"),
                careerPath(title: "Nurse", category: "health", interests: ["helping"]),
            ])
        )

        let matches = repository.matches(
            approvedInterests: [approvedTechnologyInterest],
            clusters: []
        )

        #expect(matches.map(\.careerID) == ["technology/frontend-developer"])
        #expect(repository.career(id: "health/nurse")?.title == "Nurse")
    }

    // MARK: - Fixtures

    private var approvedTechnologyInterest: StudentInterest {
        StudentInterest(
            studentId: "student-1",
            interestId: "technology",
            name: "Technology",
            category: "academic",
            strength: 4,
            rank: 1,
            source: .survey,
            capturedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000),
            createdBy: "teacher-1",
            sourceResponseID: nil,
            sourceDefinitionID: nil,
            sourceDefinitionVersion: nil,
            mergeHistory: []
        )
    }

    private func careerPath(
        title: String,
        category: String,
        interests: [String] = ["technology"]
    ) -> CareerPath {
        CareerPath(
            title: title,
            category: category,
            description: "A career.",
            requiredInterests: interests,
            icon: "star",
            color: "#000000"
        )
    }
}
