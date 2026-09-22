import Foundation
import Testing
@testable import TMI

@Suite("Early-childhood discovery content")
struct EarlyChildhoodContentTests {
    @Test("Picture Choice is a valid, picture-only definition")
    func pictureChoiceDefinition() throws {
        let definition = try #require(EarlyChildhoodSurveyContent.pictureChoice())
        #expect(definition.questions.allSatisfy { $0.kind == .imageChoice })
        #expect(definition.questions.allSatisfy { (2...4).contains($0.options.count) })
        #expect(definition.questions.flatMap(\.options).allSatisfy { $0.imageReference?.hasPrefix("sf:") == true })
        #expect(!definition.interestRules.isEmpty)
    }

    @Test("Observation checklist is valid and covers every play interest")
    func observationDefinition() throws {
        let definition = try #require(EarlyChildhoodSurveyContent.observation())
        let optionIDs = Set(definition.questions.flatMap(\.options).map(\.id))
        #expect(optionIDs == Set(EarlyChildhoodSurveyContent.interests.map(\.id)))
    }

    @Test("Client play interests match the server vocabulary")
    func vocabularyMatchesServer() {
        // Mirrors `playInterestCatalog` in functions/src/observations.ts.
        let server = [
            "building-blocks", "vehicles", "art-sensory", "music-movement",
            "books-stories", "pretend-play", "animals-nature", "water-sand",
        ]
        #expect(EarlyChildhoodSurveyContent.interests.map(\.id) == server)
    }

    @Test("An observation needs at least one interest and a consistent focus")
    func observationDraftValidation() {
        var draft = InterestObservationDraft()
        #expect(!draft.isValid)
        draft.observedInterestIDs = ["vehicles"]
        #expect(draft.isValid)
        draft.longestAttentionInterestID = "water-sand"
        #expect(!draft.isValid)
        draft.longestAttentionInterestID = "vehicles"
        #expect(draft.isValid)
        draft.note = String(repeating: "a", count: 2_001)
        #expect(!draft.isValid)
    }

    @Test("Fallback pictures exist for fixture references")
    func fallbackSymbols() {
        #expect(SurveyOptionImage.fallbackSymbol(for: "survey/forest") == "tree.fill")
        #expect(SurveyOptionImage.fallbackSymbol(for: "unknown/thing") == "photo")
        #expect(SurveyOptionImage.fallbackSymbol(for: nil) == "photo")
    }

    @Test("Family input needs content and stays within server limits")
    func familyInputDraft() {
        var draft = FamilyInputDraft()
        #expect(!draft.isValid)
        draft.answers["favoriteThings"] = "   "
        #expect(!draft.isValid)
        draft.favoritePlayInterestIDs = ["vehicles"]
        #expect(draft.isValid)
        draft.answers["favoriteThings"] = "Trucks"
        #expect(draft.trimmedAnswers == ["favoriteThings": "Trucks"])
        draft.relationship = String(repeating: "x", count: 81)
        #expect(!draft.isValid)
    }

    @Test("Family questions mirror the server form")
    func familyQuestionsMatchServer() {
        // Mirrors `textQuestionIDs` in functions/src/familyInput.ts.
        #expect(FamilyInputDraft.questions.map(\.id) == [
            "favoriteThings", "comfortsWhenUpset", "routinesAtHome",
            "languagesAtHome", "hopesForThisYear", "anythingElse",
        ])
        #expect(FamilyInputDraft.formID == "ec-family-all-about-me")
        #expect(FamilyInputDraft.formVersion == 1)
    }
}
