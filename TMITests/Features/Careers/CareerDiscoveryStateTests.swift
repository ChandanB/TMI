import Foundation
import Testing
@testable import TMI

@Suite("Career discovery")
@MainActor
struct CareerDiscoveryStateTests {
    @Test("Matches lead, and everything else stays alphabetical")
    func matchesLeadThenAlphabetical() {
        let state = CareerDiscoveryState()
        let results = state.results(careers: catalog, matches: [match(id: "health/nurse", rank: 1)])

        // The matched career first, then the rest in a stable order rather than
        // whatever order the catalog happened to arrive in.
        #expect(results.map(\.id) == ["health/nurse", "technology/frontend-developer", "arts/illustrator"])
    }

    @Test("Every search term has to land, so more words narrow the list")
    func searchNarrowsWithEveryTerm() {
        var state = CareerDiscoveryState()

        state.query = "developer"
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        state.query = "frontend developer"
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        state.query = "frontend nurse"
        #expect(state.results(careers: catalog, matches: []).isEmpty)
    }

    @Test("Search ignores case, spacing and punctuation")
    func searchNormalizes() {
        var state = CareerDiscoveryState()

        state.query = "  FRONTEND  "
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        // Terms match on substrings, so a partial word still finds the career
        // and punctuation between words does not change the answer.
        state.query = "dev"
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        state.query = "front-end?"
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        // A term that appears nowhere still excludes the career.
        state.query = "frontend welding"
        #expect(state.results(careers: catalog, matches: []).isEmpty)
    }

    @Test("Filters combine as an intersection across groups")
    func filtersIntersectAcrossGroups() {
        var state = CareerDiscoveryState()
        state.educationLevels = [.bachelors]
        #expect(state.results(careers: catalog, matches: []).map(\.id) == ["technology/frontend-developer"])

        // Adding a cluster the bachelors career is not in leaves nothing.
        state.clusterIDs = ["care"]
        #expect(state.results(careers: catalog, matches: []).isEmpty)

        state.clearFilters()
        #expect(!state.hasActiveFilters)
        #expect(state.results(careers: catalog, matches: []).count == catalog.count)
    }

    @Test("A dismissed career does not come back in results")
    func dismissedCareersStayGone() {
        let state = CareerDiscoveryState()
        let results = state.results(
            careers: catalog,
            matches: [],
            dismissedIDs: ["arts/illustrator"]
        )

        #expect(!results.contains { $0.id == "arts/illustrator" })
        #expect(results.count == catalog.count - 1)
    }

    @Test("Comparison holds at most three careers")
    func comparisonIsCappedAtThree() {
        var state = CareerDiscoveryState()

        let addedA = state.toggleComparison("a")
        let addedB = state.toggleComparison("b")
        let addedC = state.toggleComparison("c")
        // Refused rather than silently ignored, so the view can say why.
        let addedD = state.toggleComparison("d")
        #expect(addedA)
        #expect(addedB)
        #expect(addedC)
        #expect(!addedD)
        #expect(state.comparisonIDs == ["a", "b", "c"])

        // Removing one makes room again.
        let removedB = state.toggleComparison("b")
        let addedDAfterRemoval = state.toggleComparison("d")
        #expect(removedB)
        #expect(addedDAfterRemoval)
        #expect(state.comparisonIDs == ["a", "c", "d"])
    }

    @Test("Comparing needs at least two careers")
    func comparisonNeedsTwo() {
        var state = CareerDiscoveryState()
        #expect(!state.canCompare)

        state.toggleComparison("a")
        #expect(!state.canCompare)

        state.toggleComparison("b")
        #expect(state.canCompare)
        #expect(state.isSelectedForComparison("a"))

        state.clearComparison()
        #expect(!state.canCompare)
        #expect(!state.isSelectedForComparison("a"))
    }

    @Test("Persisted comparison state restores deterministically and stays capped")
    func persistedComparisonRestoresWithinLimit() {
        var state = CareerDiscoveryState()

        state.restoreComparisonIDs(["c", "a", "c", "b", "d"])

        #expect(state.comparisonIDs == ["c", "a", "b"])
    }

    @Test("Recently viewed is an explicit filter, not a ranking guess")
    func recentlyViewedFilterUsesPersistedRelationships() {
        var state = CareerDiscoveryState()
        state.showRecentlyViewed = true

        let results = state.results(
            careers: catalog,
            matches: [],
            recentlyViewedIDs: ["health/nurse"]
        )

        #expect(results.map(\.id) == ["health/nurse"])
        state.clearFilters()
        #expect(!state.showRecentlyViewed)
    }

    // MARK: - Fixtures

    private func match(id: String, rank: Int) -> CareerMatch {
        CareerMatch(
            careerID: id,
            title: id,
            score: 5,
            rank: rank,
            matchedInterestIDs: ["helping"],
            matchedClusterIDs: [],
            reasons: ["Matches interests you approved: Helping."],
            algorithmVersion: CareerMatcher.algorithmVersion
        )
    }

    private var catalog: [CareerRecord] {
        [
            CareerRecord(
                id: "technology/frontend-developer",
                title: "Frontend Developer",
                category: "technology",
                subcategory: "Software Development",
                summary: "Builds the parts of an app people see.",
                interestIDs: ["technology"],
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
                clusterIDs: ["arts"],
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
