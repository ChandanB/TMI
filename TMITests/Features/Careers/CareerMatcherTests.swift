import Foundation
import Testing
@testable import TMI

@Suite("Deterministic career matching")
@MainActor
struct CareerMatcherTests {
    @Test("No approved interests produces no matches")
    func noApprovedInterestsProducesNothing() {
        // A match built from nothing approved would be a guess presented as a
        // finding about a child.
        #expect(
            CareerMatcher.match(
                careers: catalog,
                approvedInterests: [],
                clusters: [cluster(id: "stem", name: "STEM", score: 7)]
            ).isEmpty
        )
    }

    @Test("Only careers touching an approved interest or cluster appear")
    func unrelatedCareersAreAbsent() {
        let matches = CareerMatcher.match(
            careers: catalog,
            approvedInterests: [interest(id: "technology", name: "Technology", strength: 4)],
            clusters: []
        )

        #expect(matches.map(\.careerID) == ["technology/frontend-developer"])
        #expect(matches[0].matchedInterestIDs == ["technology"])
    }

    @Test("Score sums capped interest and cluster contributions")
    func scoreSumsCappedContributions() {
        let matches = CareerMatcher.match(
            careers: catalog,
            approvedInterests: [
                // Beyond the cap; contributes 5, not 40.
                interest(id: "technology", name: "Technology", strength: 40),
            ],
            clusters: [cluster(id: "stem", name: "STEM", score: 99)]
        )

        let frontend = try? #require(matches.first { $0.careerID == "technology/frontend-developer" })
        #expect(frontend?.score == 10)
    }

    @Test("Ties break by identifier, so the order never wobbles")
    func tiesBreakDeterministically() {
        let approved = [interest(id: "creative_arts", name: "Creative Arts", strength: 3)]
        let first = CareerMatcher.match(careers: catalog, approvedInterests: approved, clusters: [])
        let reversed = CareerMatcher.match(
            careers: catalog.reversed(),
            approvedInterests: approved,
            clusters: []
        )

        #expect(first.map(\.careerID) == reversed.map(\.careerID))
        #expect(first.map(\.careerID) == ["arts/illustrator", "technology/frontend-developer"])
        // Equal scores share a rank rather than inventing an order.
        #expect(first.map(\.rank) == [1, 1])
    }

    @Test("Every match names what it matched on")
    func everyMatchExplainsItself() {
        let matches = CareerMatcher.match(
            careers: catalog,
            approvedInterests: [interest(id: "technology", name: "Technology", strength: 4)],
            clusters: [cluster(id: "stem", name: "Science and Technology", score: 6)]
        )

        let reasons = try? #require(matches.first?.reasons)
        #expect(reasons?.contains { $0.contains("Technology") } == true)
        #expect(reasons?.contains { $0.contains("Science and Technology") } == true)
        // The explanation names inputs; it never characterizes the student.
        #expect(reasons?.allSatisfy { !$0.lowercased().contains("you are") } == true)
    }

    // MARK: - Catalog identity

    @Test("Canonical identity ignores case, spacing and punctuation")
    func canonicalIdentityNormalizes() {
        let canonical = CareerRecord.canonicalID(category: "technology", title: "Frontend Developer")

        #expect(CareerRecord.canonicalID(category: "Technology", title: "frontend developer") == canonical)
        #expect(CareerRecord.canonicalID(category: "technology", title: "  Frontend   Developer ") == canonical)
        // A slash cannot appear in a Firestore document ID, so the separator
        // is "--". The old form survives in `aliases` for anything already
        // written against it.
        #expect(canonical == "technology--frontend-developer")
    }

    // MARK: - Relationship state

    @Test("Saving and dismissing are not held at once")
    func savedAndDismissedAreExclusive() {
        let relationship = CareerRelationship(
            studentID: "student-1",
            careerID: "technology/frontend-developer",
            isSaved: true,
            isDismissed: true,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            updatedBy: "teacher-1"
        )

        #expect(!relationship.isSaved)
        #expect(relationship.isDismissed)
    }

    @Test("Viewing a career is not an opinion about it")
    func viewingIsNotAnOpinion() {
        let viewed = CareerRelationship(
            studentID: "student-1",
            careerID: "technology/frontend-developer",
            lastViewedAt: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            updatedBy: "student-1"
        )

        #expect(!viewed.hasStudentOpinion)
        #expect(!viewed.isSaved)
        #expect(!viewed.isDismissed)
    }

    @Test("A salary is only representable with a source and a date")
    func salaryCarriesProvenance() {
        // The type is the guarantee: there is no way to state a figure without
        // saying where it came from.
        let salary = CareerSalary(
            minimum: 65_000,
            maximum: 130_000,
            currency: "USD",
            source: "BLS Occupational Employment Statistics",
            asOf: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(salary.source.isEmpty == false)
        #expect(career(id: "technology/frontend-developer").salary == nil)
    }

    // MARK: - Fixtures

    private func interest(id: String, name: String, strength: Int) -> StudentInterest {
        StudentInterest(
            studentId: "student-1",
            interestId: id,
            name: name,
            category: "academic",
            strength: strength,
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

    private func cluster(id: String, name: String, score: Int) -> InterestClusterScore {
        InterestClusterScore(id: id, name: name, score: score, rank: 1, matchedInterestIDs: [])
    }

    private func career(id: String) -> CareerRecord {
        try! #require(catalog.first { $0.id == id })
    }

    private var catalog: [CareerRecord] {
        [
            CareerRecord(
                id: "technology/frontend-developer",
                title: "Frontend Developer",
                category: "technology",
                subcategory: "Software Development",
                summary: "Builds the parts of an app people see.",
                interestIDs: ["technology", "creative_arts"],
                clusterIDs: ["stem"],
                educationLevel: .bachelors,
                salary: nil,
                outlook: nil
            ),
            CareerRecord(
                id: "arts/illustrator",
                title: "Illustrator",
                category: "arts",
                subcategory: nil,
                summary: "Draws for a living.",
                interestIDs: ["creative_arts"],
                clusterIDs: [],
                educationLevel: .varies,
                salary: nil,
                outlook: nil
            ),
            CareerRecord(
                id: "health/nurse",
                title: "Nurse",
                category: "health",
                subcategory: nil,
                summary: "Cares for patients.",
                interestIDs: ["helping"],
                clusterIDs: ["care"],
                educationLevel: .associates,
                salary: nil,
                outlook: nil
            ),
        ]
    }
}
