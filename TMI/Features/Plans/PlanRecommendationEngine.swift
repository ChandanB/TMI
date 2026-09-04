import Foundation

/// Suggests which branded model to start from.
///
/// The ranking comes only from needs an educator has explicitly selected. A
/// student's interests, saved careers and plan history can add supporting
/// detail to a suggestion an educator's judgement already made, and can break
/// a tie between equally-selected needs — but nothing here reads student data
/// and concludes something about the student from it. The engine does not
/// diagnose, does not infer trauma, and produces nothing at all when no need
/// has been selected.
///
/// Results are suggestions. Choosing a model by hand is always available, and
/// nothing here removes that.
nonisolated enum PlanRecommendationEngine {
    static let rulesVersion = 1

    static func recommendations(for input: PlanRecommendationInput) -> [PlanRecommendation] {
        // No professional judgement has been recorded, so there is nothing to
        // suggest. Guessing here would be the engine forming its own opinion
        // about a child.
        guard !input.needTags.isEmpty else { return [] }

        let activeModels = Set(input.activeModels)
        let completedModels = Set(input.completedModels)

        var weightByModel: [TMIPlanModel: Int] = [:]
        var tagsByModel: [TMIPlanModel: [PlanNeedTag]] = [:]
        for tag in input.needTags {
            // Selecting the same need twice is emphasis, and counts twice.
            weightByModel[tag.model, default: 0] += 2
            if tagsByModel[tag.model]?.contains(tag) != true {
                tagsByModel[tag.model, default: []].append(tag)
            }
        }

        struct Scored {
            let recommendation: PlanRecommendation
            let score: Int
        }

        let scored = weightByModel.keys.compactMap { model -> Scored? in
            // A model already running is not a suggestion; it is current work.
            guard !activeModels.contains(model) else { return nil }

            var score = weightByModel[model] ?? 0
            var reasons: [String] = []
            var inputRecordIDs: [String] = []

            let tags = (tagsByModel[model] ?? []).sorted { $0.rawValue < $1.rawValue }
            reasons.append(
                "A staff member identified \(tags.map(\.displayName).joined(separator: ", "))."
            )

            // Supporting detail only. It never puts a model on the list that an
            // educator's selection did not already put there.
            if model == .acknowledgeInterests, !input.approvedInterests.isEmpty {
                let named = input.approvedInterests
                    .sorted { $0.interestId < $1.interestId }
                    .map { $0.name ?? $0.interestId }
                score += 1
                reasons.append("Approved interests to build on: \(named.joined(separator: ", ")).")
                inputRecordIDs.append(
                    contentsOf: input.approvedInterests.map(\.interestId).sorted()
                )
                if !input.savedCareerIDs.isEmpty {
                    reasons.append("The student has saved careers to connect this to.")
                    inputRecordIDs.append(contentsOf: input.savedCareerIDs.sorted())
                }
            }

            if completedModels.contains(model) {
                // Recently finished work ranks lower so a suggestion does not
                // simply repeat it, but it stays available.
                score -= 1
                reasons.append("This model was used before and completed.")
            }

            return Scored(
                recommendation: PlanRecommendation(
                    model: model,
                    rank: 0,
                    inputRecordIDs: inputRecordIDs,
                    reasons: reasons,
                    rulesVersion: rulesVersion
                ),
                score: score
            )
        }
        .sorted {
            $0.score == $1.score
                ? $0.recommendation.model.rawValue < $1.recommendation.model.rawValue
                : $0.score > $1.score
        }

        return scored.enumerated().map { index, entry in
            var rank = index + 1
            while rank > 1 && scored[rank - 2].score == entry.score {
                rank -= 1
            }
            return PlanRecommendation(
                model: entry.recommendation.model,
                rank: rank,
                inputRecordIDs: entry.recommendation.inputRecordIDs,
                reasons: entry.recommendation.reasons,
                rulesVersion: rulesVersion
            )
        }
    }
}
