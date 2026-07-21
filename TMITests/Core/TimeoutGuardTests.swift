import Foundation
import Testing
@testable import TMI

@Suite("Timeout guards")
struct TimeoutGuardTests {
    private struct SourceContract: Sendable {
        let path: String
        let tenSecondGuards: Int
        let fifteenSecondGuards: Int
    }

    private static let sourceContracts: [SourceContract] = [
        .init(path: "TMI/Services/Library/CareerLibraryService.swift", tenSecondGuards: 2, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/Library/InterestLibraryService.swift", tenSecondGuards: 2, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/Library/ResourceLibraryService.swift", tenSecondGuards: 2, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/StudentData/PlanResourceLinkService.swift", tenSecondGuards: 2, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/StudentData/StudentCareerService.swift", tenSecondGuards: 2, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/StudentData/StudentInterestService.swift", tenSecondGuards: 3, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/StudentService.swift", tenSecondGuards: 5, fifteenSecondGuards: 3),
        .init(path: "TMI/Services/SurveyService.swift", tenSecondGuards: 13, fifteenSecondGuards: 0),
        .init(path: "TMI/Services/TMIAuthService.swift", tenSecondGuards: 1, fifteenSecondGuards: 0),
        .init(path: "TMI/StateModels/InterestsAndHobbiesStateModel.swift", tenSecondGuards: 1, fifteenSecondGuards: 0),
    ]

    @Test("Fast operations complete before their deadline")
    func fastCompletion() async throws {
        let result = try await withTimeout(seconds: 1) { @MainActor @Sendable in
            MainActor.preconditionIsolated()
            return 42
        }

        #expect(result == 42)
    }

    @Test("Slow operations throw the shared timeout error")
    func timeout() async {
        do {
            try await withTimeout(seconds: 0.01) { @MainActor @Sendable in
                try await Task.sleep(for: .seconds(1))
            }
            Issue.record("Expected ConcurrencyError.timeout")
        } catch ConcurrencyError.timeout {
            // Expected.
        } catch {
            Issue.record("Expected ConcurrencyError.timeout, received \(error)")
        }
    }

    @Test("Firestore timeout inventory remains complete")
    func sourceContractInventory() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var totalGuards = 0

        for contract in Self.sourceContracts {
            let source = try String(
                contentsOf: projectRoot.appending(path: contract.path),
                encoding: .utf8
            )
            let tenSecondGuards = source.occurrenceCount(of: "withTimeout(seconds: 10)")
            let fifteenSecondGuards = source.occurrenceCount(of: "withTimeout(seconds: 15)")

            #expect(
                tenSecondGuards == contract.tenSecondGuards,
                "Expected \(contract.tenSecondGuards) ten-second guards in \(contract.path), found \(tenSecondGuards)"
            )
            #expect(
                fifteenSecondGuards == contract.fifteenSecondGuards,
                "Expected \(contract.fifteenSecondGuards) fifteen-second guards in \(contract.path), found \(fifteenSecondGuards)"
            )
            totalGuards += tenSecondGuards + fifteenSecondGuards
        }

        let helperSource = try String(
            contentsOf: projectRoot.appending(path: "TMI/Helpers/ConcurrencyHelpers.swift"),
            encoding: .utf8
        )
        let interestsStateSource = try String(
            contentsOf: projectRoot.appending(path: "TMI/StateModels/InterestsAndHobbiesStateModel.swift"),
            encoding: .utf8
        )
        #expect(helperSource.contains("operation: @escaping @MainActor @Sendable"))
        #expect(interestsStateSource.contains("catch ConcurrencyError.timeout"))
        #expect(interestsStateSource.contains("IdentifiableError(message: \"Fetch timed out\")"))
        #expect(totalGuards == 36)
    }
}

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
