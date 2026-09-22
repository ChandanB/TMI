import Foundation

/// DRAFT early-childhood discovery content, pending product-owner approval.
///
/// Two activities replace the self-report interest survey for ages 0–5:
/// - **Picture Choice** — a caregiver holds the device and reads each question
///   aloud; a preschooler (3+) points at one of a few pictures.
/// - **Interest observation** — a caregiver records what they have seen the
///   child choose during play. Suitable for every age group, including infants.
///
/// Both map answers to the same play-based interest vocabulary through
/// deterministic `interestRules`, so the canonical analysis, staff review, and
/// interest approval flow are unchanged. Definitions are published server-side
/// to `catalogs/surveyDefinitions`; these values are the source for that
/// publication and for previews/fixtures.
nonisolated enum EarlyChildhoodSurveyContent {
    static let pictureChoiceID = "ec-picture-choice"
    static let observationID = "ec-interest-observation"

    /// Play-based interests used by both activities.
    struct PlayInterest: Sendable {
        let id: String
        let name: String
        let symbol: String
        let clusterID: String
        let clusterName: String
    }

    static let interests: [PlayInterest] = [
        PlayInterest(id: "building-blocks", name: "Building & blocks", symbol: "square.stack.3d.up.fill", clusterID: "making", clusterName: "Making & building"),
        PlayInterest(id: "vehicles", name: "Trucks & vehicles", symbol: "car.fill", clusterID: "making", clusterName: "Making & building"),
        PlayInterest(id: "art-sensory", name: "Art & sensory play", symbol: "paintpalette.fill", clusterID: "creating", clusterName: "Creating"),
        PlayInterest(id: "music-movement", name: "Music & movement", symbol: "music.note", clusterID: "creating", clusterName: "Creating"),
        PlayInterest(id: "books-stories", name: "Books & stories", symbol: "book.fill", clusterID: "language", clusterName: "Stories & talk"),
        PlayInterest(id: "pretend-play", name: "Pretend play", symbol: "theatermasks.fill", clusterID: "language", clusterName: "Stories & talk"),
        PlayInterest(id: "animals-nature", name: "Animals & nature", symbol: "pawprint.fill", clusterID: "exploring", clusterName: "Exploring the world"),
        PlayInterest(id: "water-sand", name: "Water & sand play", symbol: "drop.fill", clusterID: "exploring", clusterName: "Exploring the world"),
    ]

    private static func interest(_ id: String) -> PlayInterest {
        interests.first { $0.id == id } ?? interests[0]
    }

    private static func option(_ interestID: String, label: String? = nil) -> SurveyOption {
        let interest = interest(interestID)
        return SurveyOption(id: interest.id, label: label ?? interest.name, imageReference: "sf:\(interest.symbol)")
    }

    private static func rules(questionID: String, interestIDs: [String], weight: Int) -> [InterestAnalysisRule] {
        interestIDs.map { id in
            let interest = interest(id)
            return InterestAnalysisRule(
                questionID: questionID,
                optionID: id,
                interestID: interest.id,
                interestName: interest.name,
                category: "Play",
                clusterID: interest.clusterID,
                clusterName: interest.clusterName,
                weight: weight
            )
        }
    }

    /// Caregiver-held picture activity for preschoolers. Short: four
    /// questions, two to four pictures each, no reading or typing required.
    static func pictureChoice() -> SurveyDefinition? {
        let questions: [(id: String, prompt: String, options: [String])] = [
            ("play-first", "Which one do you want to play with?", ["building-blocks", "art-sensory", "books-stories"]),
            ("outside", "What do you like to do outside?", ["water-sand", "animals-nature", "vehicles"]),
            ("pretend", "Which one is the most fun?", ["pretend-play", "music-movement", "building-blocks"]),
            ("favorite", "Show me your favorite!", ["vehicles", "animals-nature", "music-movement", "books-stories"]),
        ]
        return try? SurveyDefinition(
            id: pictureChoiceID,
            version: 1,
            title: "My favorite things",
            publishedAt: Date(timeIntervalSince1970: 1_790_000_000),
            questions: questions.map { question in
                SurveyQuestion(
                    id: question.id,
                    prompt: question.prompt,
                    kind: .imageChoice,
                    isRequired: true,
                    options: question.options.map { option($0) }
                )
            },
            interestRules: questions.flatMap { rules(questionID: $0.id, interestIDs: $0.options, weight: 2) }
        )
    }

    /// Caregiver observation checklist, completed in the staff experience.
    static func observation() -> SurveyDefinition? {
        let allIDs = interests.map(\.id)
        return try? SurveyDefinition(
            id: observationID,
            version: 1,
            title: "Interest observation",
            publishedAt: Date(timeIntervalSince1970: 1_790_000_000),
            questions: [
                SurveyQuestion(
                    id: "chooses-often",
                    prompt: "During free play this week, which activities did the child choose on their own?",
                    kind: .multiSelect(maxSelections: nil),
                    isRequired: true,
                    options: allIDs.map { option($0) }
                ),
                SurveyQuestion(
                    id: "stays-longest",
                    prompt: "Which activity held the child's attention the longest?",
                    kind: .singleChoice,
                    isRequired: true,
                    options: allIDs.map { option($0) }
                ),
                SurveyQuestion(
                    id: "engagement",
                    prompt: "How engaged was the child during their favorite activity? (1 = briefly, 5 = deeply focused)",
                    kind: .rating(minimum: 1, maximum: 5),
                    isRequired: false
                ),
                SurveyQuestion(
                    id: "notes",
                    prompt: "What did you see? Describe what the child did, said, or showed (no diagnoses).",
                    kind: .shortText(maxLength: 500),
                    isRequired: false
                ),
            ],
            interestRules: rules(questionID: "chooses-often", interestIDs: allIDs, weight: 2)
                + rules(questionID: "stays-longest", interestIDs: allIDs, weight: 3)
        )
    }
}
