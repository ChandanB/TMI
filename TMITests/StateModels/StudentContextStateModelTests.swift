import Foundation
import Testing
@testable import TMI

@Suite("Student Context State Model")
struct StudentContextStateModelTests {
    @Test("Prefetch runs for a newly selected student")
    func prefetchRunsForNewStudent() {
        let shouldPrefetch = StudentContextStateModel.shouldPrefetchEdges(
            requested: true,
            incomingStudentId: "student-1",
            currentStudentId: nil,
            incomingScope: .staff,
            currentScope: .staff,
            hasPrefetchedEdges: false,
            isPrefetching: false
        )

        #expect(shouldPrefetch)
    }

    @Test("Prefetch is skipped when the same context is already warm")
    func prefetchSkippedForWarmContext() {
        let shouldPrefetch = StudentContextStateModel.shouldPrefetchEdges(
            requested: true,
            incomingStudentId: "student-1",
            currentStudentId: "student-1",
            incomingScope: .studentMode,
            currentScope: .studentMode,
            hasPrefetchedEdges: true,
            isPrefetching: false
        )

        #expect(shouldPrefetch == false)
    }

    @Test("Prefetch is skipped while the same student is already in flight")
    func prefetchSkippedWhileInFlight() {
        let shouldPrefetch = StudentContextStateModel.shouldPrefetchEdges(
            requested: true,
            incomingStudentId: "student-1",
            currentStudentId: "student-1",
            incomingScope: .studentMode,
            currentScope: .studentMode,
            hasPrefetchedEdges: false,
            isPrefetching: true
        )

        #expect(shouldPrefetch == false)
    }

    @Test("Edge prefetch keeps actor-isolated branches concurrent")
    func edgePrefetchConcurrencySourceContract() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appending(path: "TMI/StateModels/StudentContextStateModel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("async let interests = Self.loadPrefetchedInterests(for: studentId)"))
        #expect(source.contains("async let plans = Self.loadPrefetchedPlans(for: studentId)"))
        #expect(source.contains("let (loadedInterests, loadedPlans) = await"))
        #expect(source.contains("@MainActor\n    private static func loadPrefetchedInterests"))
        #expect(source.contains("@MainActor\n    private static func loadPrefetchedPlans"))
        #expect(source.components(separatedBy: "catch is CancellationError").count - 1 >= 2)
        #expect(source.contains("StudentCareerService") == false)
        #expect(source.contains("StudentCareerState") == false)
        #expect(source.contains("withTaskGroup") == false)

        guard
            let prefetchStart = source.range(of: "private func prefetchStudentEdges"),
            let prefetchEnd = source.range(
                of: "// MARK: - Environment Key",
                range: prefetchStart.upperBound..<source.endIndex
            )
        else {
            Issue.record("Missing prefetch implementation boundaries")
            return
        }

        let prefetchSource = String(source[prefetchStart.lowerBound..<prefetchEnd.lowerBound])
        guard
            let awaitPosition = prefetchSource.range(
                of: "let (loadedInterests, loadedPlans) = await"
            )?.lowerBound,
            let interestsAssignment = prefetchSource.range(
                of: "self.prefetchedInterests = loadedInterests"
            )?.lowerBound,
            let plansAssignment = prefetchSource.range(
                of: "self.prefetchedPlans = loadedPlans"
            )?.lowerBound
        else {
            Issue.record("Missing awaited prefetch result assignments")
            return
        }

        #expect(awaitPosition < interestsAssignment)
        #expect(awaitPosition < plansAssignment)
    }
}
