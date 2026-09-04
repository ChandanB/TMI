import Foundation

nonisolated struct CareerMatch: Identifiable, Sendable, Equatable {
    var id: String { careerID }

    let careerID: String
    let title: String
    let score: Int
    let rank: Int
    let matchedInterestIDs: [String]
    let matchedClusterIDs: [String]
    /// Plain language naming what actually matched, so a student can see why
    /// this career is in front of them.
    let reasons: [String]
    let algorithmVersion: Int
}

/// Matches careers to a student from what an educator has already approved.
///
/// Deterministic by construction: integer scores, capped inputs, and ties
/// broken by identifier, so the same inputs always produce the same order. It
/// describes what a student said they liked. It does not infer anything about
/// them beyond that.
nonisolated enum CareerMatcher {
    static let algorithmVersion = 1

    /// One interest can carry a career only so far; past this, breadth of
    /// match matters more than the strength of any single interest.
    static let maximumInterestContribution = 5
    static let maximumClusterContribution = 5

    static func match(
        careers: [CareerRecord],
        approvedInterests: [StudentInterest],
        clusters: [InterestClusterScore]
    ) -> [CareerMatch] {
        // Nothing has been approved, so there is nothing to say. A match built
        // from no approved interest would be a guess presented as a finding.
        guard !approvedInterests.isEmpty else { return [] }

        let interestStrength = Dictionary(
            approvedInterests.map { ($0.interestId, $0.strength) },
            uniquingKeysWith: { left, right in max(left, right) }
        )
        let interestNames = Dictionary(
            approvedInterests.map { ($0.interestId, $0.name ?? $0.interestId) },
            uniquingKeysWith: { left, _ in left }
        )
        let clusterScore = Dictionary(
            clusters.map { ($0.id, $0.score) },
            uniquingKeysWith: { left, right in max(left, right) }
        )
        let clusterNames = Dictionary(
            clusters.map { ($0.id, $0.name) },
            uniquingKeysWith: { left, _ in left }
        )

        let scored = careers.compactMap { career -> CareerMatch? in
            let matchedInterests = career.interestIDs
                .filter { interestStrength[$0] != nil }
                .sorted()
            let matchedClusters = career.clusterIDs
                .filter { clusterScore[$0] != nil }
                .sorted()
            guard !matchedInterests.isEmpty || !matchedClusters.isEmpty else { return nil }

            let interestPoints = matchedInterests.reduce(0) { total, interestID in
                total + min(interestStrength[interestID] ?? 0, maximumInterestContribution)
            }
            let clusterPoints = matchedClusters.reduce(0) { total, clusterID in
                total + min(clusterScore[clusterID] ?? 0, maximumClusterContribution)
            }

            var reasons: [String] = []
            if !matchedInterests.isEmpty {
                let named = matchedInterests.map { interestNames[$0] ?? $0 }
                reasons.append("Matches interests you approved: \(named.joined(separator: ", ")).")
            }
            if !matchedClusters.isEmpty {
                let named = matchedClusters.map { clusterNames[$0] ?? $0 }
                reasons.append("Sits in \(named.joined(separator: ", ")).")
            }

            return CareerMatch(
                careerID: career.id,
                title: career.title,
                score: interestPoints + clusterPoints,
                rank: 0,
                matchedInterestIDs: matchedInterests,
                matchedClusterIDs: matchedClusters,
                reasons: reasons,
                algorithmVersion: algorithmVersion
            )
        }.sorted {
            $0.score == $1.score ? $0.careerID < $1.careerID : $0.score > $1.score
        }

        return scored.enumerated().map { index, match in
            var rank = index + 1
            while rank > 1 && scored[rank - 2].score == match.score {
                rank -= 1
            }
            return CareerMatch(
                careerID: match.careerID,
                title: match.title,
                score: match.score,
                rank: rank,
                matchedInterestIDs: match.matchedInterestIDs,
                matchedClusterIDs: match.matchedClusterIDs,
                reasons: match.reasons,
                algorithmVersion: match.algorithmVersion
            )
        }
    }
}
