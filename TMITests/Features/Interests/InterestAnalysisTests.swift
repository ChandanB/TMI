import Foundation
import Testing
@testable import TMI

@Suite("Interest approval availability")
struct InterestApprovalAvailabilityTests {
    @Test("An undeployed approval function explains itself")
    @MainActor
    func approvalUnavailableIsActionable() throws {
        // Approving derives district data about a child from an immutable
        // submission, which only the Admin SDK may write — so there is no
        // client fallback to offer, and the message has to say what to do.
        let message = try #require(
            StudentInterestService.StudentInterestError.approvalUnavailable.errorDescription
        )
        #expect(message.contains("administrator"))
        #expect(message.contains("deploy"))
        // It must not read like a transient failure the reviewer should retry.
        #expect(!message.contains("try again later"))
    }
}

@Suite("Deterministic interest analysis")
struct InterestAnalysisTests {
    @Test("Fixed answers produce exact ranked clusters and proposals")
    func exactRanking() throws {
        let result = try InterestAnalysis.analyze(
            response: response(answers: [
                "single": .single("science"),
                "multiple": .multiple(["building", "drawing"]),
            ]),
            catalog: catalog
        )

        #expect(result.algorithmVersion == 1)
        #expect(result.responseID == "attempt-1")
        #expect(result.definitionID == "interest-discovery")
        #expect(result.definitionVersion == 3)
        #expect(result.clusters.map(\.id) == ["stem", "creative"])
        #expect(result.clusters.map(\.score) == [7, 2])
        #expect(result.clusters.map(\.rank) == [1, 2])
        #expect(result.proposedInterests.map(\.interestID) == ["engineering", "science", "drawing"])
        #expect(result.proposedInterests.map(\.score) == [4, 3, 2])
    }

    @Test("Ties use stable catalog IDs")
    func stableTies() throws {
        let tiedCatalog = catalog.map { rule in
            InterestAnalysisRule(
                questionID: rule.questionID,
                optionID: rule.optionID,
                interestID: rule.interestID,
                interestName: rule.interestName,
                category: rule.category,
                clusterID: rule.clusterID,
                clusterName: rule.clusterName,
                weight: rule.questionID == "multiple" ? 2 : rule.weight
            )
        }
        let result = try InterestAnalysis.analyze(
            response: response(answers: ["multiple": .multiple(["building", "drawing"])]),
            catalog: tiedCatalog
        )

        #expect(result.clusters.map(\.id) == ["creative", "stem"])
        #expect(result.clusters.map(\.rank) == [1, 1])
    }

    @Test("Empty optional answers add no interests")
    func emptyOptionalAnswers() throws {
        let result = try InterestAnalysis.analyze(
            response: response(answers: ["text": .text("   ")]),
            catalog: catalog
        )

        #expect(result.clusters.isEmpty)
        #expect(result.proposedInterests.isEmpty)
        #expect(result.rationale.isEmpty)
    }

    @Test("Repeated analysis is byte-for-byte deterministic")
    func deterministicRepeatability() throws {
        let fixture = try response(answers: [
            "single": .single("science"),
            "multiple": .multiple(["drawing", "building"]),
        ])
        let first = try InterestAnalysis.analyze(response: fixture, catalog: catalog)
        let second = try InterestAnalysis.analyze(response: fixture, catalog: catalog.reversed())

        #expect(first == second)
        #expect(try JSONEncoder.sorted.encode(first) == JSONEncoder.sorted.encode(second))
    }

    private var catalog: [InterestAnalysisRule] {
        [
            .init(questionID: "single", optionID: "science", interestID: "science", interestName: "Science", category: "academic", clusterID: "stem", clusterName: "Science and Technology", weight: 3),
            .init(questionID: "multiple", optionID: "building", interestID: "engineering", interestName: "Engineering", category: "technology", clusterID: "stem", clusterName: "Science and Technology", weight: 4),
            .init(questionID: "multiple", optionID: "drawing", interestID: "drawing", interestName: "Drawing", category: "creative", clusterID: "creative", clusterName: "Creative Arts", weight: 2),
        ]
    }

    private func response(answers: [String: SurveyAnswer]) throws -> SurveyResponse {
        let definition = try SurveyDefinition(
            id: "interest-discovery",
            version: 3,
            title: "Interest discovery",
            publishedAt: Date(timeIntervalSince1970: 1_000),
            questions: [
                .init(id: "single", prompt: "Pick one", kind: .singleChoice, isRequired: false, options: [.init(id: "science", label: "Science")]),
                .init(id: "multiple", prompt: "Pick several", kind: .multiSelect(maxSelections: 2), isRequired: false, options: [.init(id: "building", label: "Building"), .init(id: "drawing", label: "Drawing")]),
                .init(id: "text", prompt: "Optional", kind: .shortText(maxLength: 120), isRequired: false),
            ]
        )
        let assignment = try SurveyAssignment(
            assignmentID: "assignment-1",
            attemptID: "attempt-1",
            districtID: "d1",
            studentID: "student-1",
            definitionID: definition.id,
            definitionVersion: definition.version,
            state: .active,
            assignedAt: Date(timeIntervalSince1970: 2_000)
        )
        var response = SurveyResponse(assignment: assignment, definition: definition)
        for key in answers.keys.sorted() {
            let answer = try #require(answers[key])
            _ = try response.apply(answer: answer, questionID: key, operationID: "answer-\(key)")
        }
        return response
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
