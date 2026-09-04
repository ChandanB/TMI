import Foundation
import Testing
@testable import TMI

@Suite("Deterministic plan recommendations")
@MainActor
struct PlanRecommendationTests {
    @Test("Nothing is suggested until a staff member identifies a need")
    func noSuggestionWithoutProfessionalJudgement() {
        // Interests and careers are rich data, and none of it is grounds for
        // the app to form its own opinion about a child.
        var input = PlanRecommendationInput()
        input.approvedInterests = [interest(id: "technology", name: "Technology")]
        input.savedCareerIDs = ["technology/frontend-developer"]
        input.completedModels = [.alignYourMind]

        #expect(PlanRecommendationEngine.recommendations(for: input).isEmpty)
    }

    @Test("Only models a staff member's needs point to are suggested")
    func onlySelectedNeedsProduceModels() {
        var input = PlanRecommendationInput()
        input.needTags = [.belonging]
        input.approvedInterests = [interest(id: "technology", name: "Technology")]

        let results = PlanRecommendationEngine.recommendations(for: input)

        // Approved interests do not add "Acknowledge Interests" on their own.
        #expect(results.map(\.model) == [.chaseYourSpace])
    }

    @Test("Repeating a need is emphasis and ranks it higher")
    func repeatedNeedOutranks() {
        var input = PlanRecommendationInput()
        input.needTags = [.belonging, .emotionalRegulation, .belonging]

        let results = PlanRecommendationEngine.recommendations(for: input)

        #expect(results.map(\.model) == [.chaseYourSpace, .alignYourMind])
        #expect(results.map(\.rank) == [1, 2])
    }

    @Test("Every suggestion names the judgement behind it")
    func everySuggestionNamesItsInputs() {
        var input = PlanRecommendationInput()
        input.needTags = [.engagement]
        input.approvedInterests = [
            interest(id: "technology", name: "Technology"),
            interest(id: "art", name: "Art"),
        ]
        input.savedCareerIDs = ["technology/frontend-developer"]

        let result = try? #require(PlanRecommendationEngine.recommendations(for: input).first)

        #expect(result?.reasons.first?.contains("A staff member identified") == true)
        #expect(result?.reasons.contains { $0.contains("Technology") } == true)
        // The records it drew on are citable, so an educator can go and read them.
        #expect(result?.inputRecordIDs == ["art", "technology", "technology/frontend-developer"])
        #expect(result?.rulesVersion == PlanRecommendationEngine.rulesVersion)
    }

    @Test("A recommendation never characterizes the student")
    func recommendationsDoNotDiagnose() {
        var input = PlanRecommendationInput()
        input.needTags = PlanNeedTag.allCases
        input.approvedInterests = [interest(id: "technology", name: "Technology")]

        let reasons = PlanRecommendationEngine.recommendations(for: input).flatMap(\.reasons)

        #expect(!reasons.isEmpty)
        for reason in reasons {
            let lowered = reason.lowercased()
            // The rationale describes what a person decided and what is on
            // file. It does not tell an educator what the student is.
            for phrase in ["trauma", "the student is", "student appears", "suffers", "diagnos", "at risk", "victim"] {
                #expect(!lowered.contains(phrase), "Rationale characterizes the student: \(reason)")
            }
        }
    }

    @Test("A model already running is current work, not a suggestion")
    func activeModelsAreNotSuggested() {
        var input = PlanRecommendationInput()
        input.needTags = [.belonging, .emotionalRegulation]
        input.activeModels = [.chaseYourSpace]

        #expect(PlanRecommendationEngine.recommendations(for: input).map(\.model) == [.alignYourMind])
    }

    @Test("A completed model ranks lower but stays available")
    func completedModelsRankLower() {
        var input = PlanRecommendationInput()
        input.needTags = [.belonging, .emotionalRegulation]
        input.completedModels = [.chaseYourSpace]

        let results = PlanRecommendationEngine.recommendations(for: input)

        #expect(results.map(\.model) == [.alignYourMind, .chaseYourSpace])
        #expect(results.last?.reasons.contains { $0.contains("completed") } == true)
    }

    @Test("Equal needs tie by model, so the order never wobbles")
    func tiesAreStable() {
        var input = PlanRecommendationInput()
        input.needTags = [.belonging, .emotionalRegulation, .selfAdvocacy]

        let first = PlanRecommendationEngine.recommendations(for: input)
        input.needTags = [.selfAdvocacy, .emotionalRegulation, .belonging]
        let reordered = PlanRecommendationEngine.recommendations(for: input)

        #expect(first.map(\.model) == reordered.map(\.model))
        // All equally selected, so all share the top rank rather than the
        // engine inventing a preference between them.
        #expect(first.map(\.rank) == [1, 1, 1])
    }

    @Test("Every need maps to a distinct branded model")
    func everyNeedHasItsOwnModel() {
        let models = PlanNeedTag.allCases.map(\.model)
        #expect(Set(models).count == PlanNeedTag.allCases.count)
        #expect(Set(models) == Set(TMIPlanModel.allCases))
    }

    // MARK: - Fixtures

    private func interest(id: String, name: String) -> StudentInterest {
        StudentInterest(
            studentId: "student-1",
            interestId: id,
            name: name,
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
}
