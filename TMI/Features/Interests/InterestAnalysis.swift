import Foundation

nonisolated struct InterestAnalysisRule: Codable, Equatable, Sendable {
    let questionID: String
    let optionID: String
    let interestID: String
    let interestName: String
    let category: String
    let clusterID: String
    let clusterName: String
    let weight: Int
}

nonisolated struct InterestClusterScore: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let score: Int
    let rank: Int
    let matchedInterestIDs: [String]
}

nonisolated struct ProposedInterestScore: Codable, Equatable, Identifiable, Sendable {
    var id: String { interestID }
    let interestID: String
    let name: String
    let category: String
    let score: Int
    let rank: Int
    let sourceOptionIDs: [String]
}

nonisolated struct InterestAnalysisResult: Codable, Equatable, Sendable {
    let algorithmVersion: Int
    let responseID: String
    let definitionID: String
    let definitionVersion: Int
    let clusters: [InterestClusterScore]
    let proposedInterests: [ProposedInterestScore]
    let rationale: [String]
}

nonisolated enum InterestAnalysisError: Error, Equatable, Sendable {
    case invalidCatalogRule(String)
}

nonisolated enum InterestAnalysis {
    static let algorithmVersion = 1

    static func analyze<S: Sequence>(
        response: SurveyResponse,
        catalog: S
    ) throws -> InterestAnalysisResult where S.Element == InterestAnalysisRule {
        let orderedRules = try catalog.map { rule in
            guard !rule.questionID.isEmpty,
                  !rule.optionID.isEmpty,
                  !rule.interestID.isEmpty,
                  !rule.clusterID.isEmpty,
                  rule.weight > 0 else {
                throw InterestAnalysisError.invalidCatalogRule(rule.interestID)
            }
            return rule
        }.sorted {
            ($0.questionID, $0.optionID, $0.interestID, $0.clusterID) <
                ($1.questionID, $1.optionID, $1.interestID, $1.clusterID)
        }

        let selected = selectedOptionKeys(from: response.answers)
        let matchedRules = orderedRules.filter {
            selected.contains(OptionKey(questionID: $0.questionID, optionID: $0.optionID))
        }

        let interestGroups = Dictionary(grouping: matchedRules, by: \.interestID)
        let preliminaryInterests: [PreliminaryInterest] = interestGroups.map { interestID, rules in
            let canonical = rules.sorted {
                ($0.interestName, $0.category, $0.clusterID) <
                    ($1.interestName, $1.category, $1.clusterID)
            }[0]
            let score = rules.reduce(0) { partial, rule in partial + rule.weight }
            let optionIDs = rules.map { $0.optionID }.sorted()
            return PreliminaryInterest(
                interestID: interestID,
                name: canonical.interestName,
                category: canonical.category,
                score: score,
                optionIDs: optionIDs
            )
        }.sorted {
            $0.score == $1.score ? $0.interestID < $1.interestID : $0.score > $1.score
        }
        let proposedInterests = preliminaryInterests.enumerated().map { index, interest in
            ProposedInterestScore(
                interestID: interest.interestID,
                name: interest.name,
                category: interest.category,
                score: interest.score,
                rank: competitionRank(at: index, scores: preliminaryInterests.map { $0.score }),
                sourceOptionIDs: interest.optionIDs
            )
        }

        let clusterGroups = Dictionary(grouping: matchedRules, by: \.clusterID)
        let preliminaryClusters: [PreliminaryCluster] = clusterGroups.map { clusterID, rules in
            let names = rules.map { $0.clusterName }.sorted()
            let score = rules.reduce(0) { partial, rule in partial + rule.weight }
            let interests = Array(Set(rules.map { $0.interestID })).sorted()
            return PreliminaryCluster(
                id: clusterID,
                name: names[0],
                score: score,
                interests: interests
            )
        }.sorted {
            $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score
        }
        let clusters = preliminaryClusters.enumerated().map { index, cluster in
            InterestClusterScore(
                id: cluster.id,
                name: cluster.name,
                score: cluster.score,
                rank: competitionRank(at: index, scores: preliminaryClusters.map { $0.score }),
                matchedInterestIDs: cluster.interests
            )
        }
        let rationale = clusters.map {
            "\($0.name) ranked \($0.rank) from \($0.matchedInterestIDs.count) selected interest\($0.matchedInterestIDs.count == 1 ? "" : "s")."
        }

        return InterestAnalysisResult(
            algorithmVersion: algorithmVersion,
            responseID: response.responseID,
            definitionID: response.definitionID,
            definitionVersion: response.definitionVersion,
            clusters: clusters,
            proposedInterests: proposedInterests,
            rationale: rationale
        )
    }

    private struct OptionKey: Hashable {
        let questionID: String
        let optionID: String
    }

    private struct PreliminaryInterest {
        let interestID: String
        let name: String
        let category: String
        let score: Int
        let optionIDs: [String]
    }

    private struct PreliminaryCluster {
        let id: String
        let name: String
        let score: Int
        let interests: [String]
    }

    private static func selectedOptionKeys(
        from answers: [String: SurveyAnswer]
    ) -> Set<OptionKey> {
        Set(answers.flatMap { questionID, answer -> [OptionKey] in
            switch answer {
            case .single(let optionID), .image(let optionID):
                return [OptionKey(questionID: questionID, optionID: optionID)]
            case .multiple(let optionIDs):
                return optionIDs.map { OptionKey(questionID: questionID, optionID: $0) }
            case .text, .rating:
                return []
            }
        })
    }

    private static func competitionRank(at index: Int, scores: [Int]) -> Int {
        guard index > 0 else { return 1 }
        return scores[index] == scores[index - 1]
            ? competitionRank(at: index - 1, scores: scores)
            : index + 1
    }
}
