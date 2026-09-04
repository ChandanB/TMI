import Foundation

/// The search, filter and comparison rules behind career discovery.
///
/// Kept out of the view so the parts a student can get wrong — an empty
/// search, a filter that hides everything, picking a fourth career to
/// compare — are exercised directly rather than through the UI.
nonisolated struct CareerDiscoveryState: Equatable, Sendable {
    /// Comparison is a reading task. Past three columns nobody reads it, and
    /// on a phone it stops fitting at all.
    static let maximumComparisons = 3

    var query: String = ""
    var educationLevels: Set<CareerEducationLevel> = []
    var clusterIDs: Set<String> = []
    var showRecentlyViewed = false
    /// Careers the student picked to compare, in the order they picked them.
    private(set) var comparisonIDs: [String] = []

    var hasActiveFilters: Bool {
        !educationLevels.isEmpty || !clusterIDs.isEmpty || showRecentlyViewed
    }

    var canCompare: Bool { comparisonIDs.count >= 2 }

    func isSelectedForComparison(_ careerID: String) -> Bool {
        comparisonIDs.contains(careerID)
    }

    /// Returns false when the pick was refused because the limit is reached,
    /// so the view can say why instead of silently doing nothing.
    @discardableResult
    mutating func toggleComparison(_ careerID: String) -> Bool {
        if let index = comparisonIDs.firstIndex(of: careerID) {
            comparisonIDs.remove(at: index)
            return true
        }
        guard comparisonIDs.count < Self.maximumComparisons else { return false }
        comparisonIDs.append(careerID)
        return true
    }

    mutating func clearComparison() {
        comparisonIDs.removeAll()
    }

    mutating func restoreComparisonIDs(_ careerIDs: [String]) {
        var seen: Set<String> = []
        comparisonIDs = careerIDs.filter { seen.insert($0).inserted }
        if comparisonIDs.count > Self.maximumComparisons {
            comparisonIDs.removeLast(comparisonIDs.count - Self.maximumComparisons)
        }
    }

    mutating func clearFilters() {
        educationLevels.removeAll()
        clusterIDs.removeAll()
        showRecentlyViewed = false
    }

    /// Careers to show, ordered by match strength where a match exists.
    ///
    /// Matches lead because they are the reason a career is worth reading;
    /// everything else follows alphabetically so the list is never arbitrary.
    func results(
        careers: [CareerRecord],
        matches: [CareerMatch],
        dismissedIDs: Set<String> = [],
        recentlyViewedIDs: Set<String> = []
    ) -> [CareerRecord] {
        let rankByID = Dictionary(
            matches.map { ($0.careerID, $0.rank) },
            uniquingKeysWith: { left, _ in left }
        )
        let terms = Self.searchTerms(query)

        return careers
            .filter { career in
                guard !dismissedIDs.contains(career.id) else { return false }
                guard !showRecentlyViewed || recentlyViewedIDs.contains(career.id) else {
                    return false
                }
                guard educationLevels.isEmpty || educationLevels.contains(career.educationLevel)
                else { return false }
                guard clusterIDs.isEmpty || !clusterIDs.isDisjoint(with: Set(career.clusterIDs))
                else { return false }
                return terms.isEmpty || Self.matchesSearch(career, terms: terms)
            }
            .sorted { left, right in
                switch (rankByID[left.id], rankByID[right.id]) {
                case let (leftRank?, rightRank?):
                    leftRank == rightRank ? left.title < right.title : leftRank < rightRank
                case (.some, .none):
                    true
                case (.none, .some):
                    false
                case (.none, .none):
                    left.title < right.title
                }
            }
    }

    static func searchTerms(_ query: String) -> [String] {
        CareerRecord.normalized(query)
            .split(separator: "-")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Every term has to land somewhere, so adding a word narrows the list
    /// instead of widening it.
    static func matchesSearch(_ career: CareerRecord, terms: [String]) -> Bool {
        let haystack = [
            CareerRecord.normalized(career.title),
            CareerRecord.normalized(career.category),
            CareerRecord.normalized(career.subcategory ?? ""),
            CareerRecord.normalized(career.summary),
        ].joined(separator: "-")
        return terms.allSatisfy { haystack.contains($0) }
    }
}
