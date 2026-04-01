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
}
