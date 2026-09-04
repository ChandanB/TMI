import Foundation
import Testing
@testable import TMI

@Suite("Student plan projection loading")
@MainActor
struct StudentPlanProjectionStateTests {
    @Test("A grant without student-visible-plan authority performs no load")
    func missingCapabilityFailsClosed() async throws {
        let calls = LoadCounter()
        let repository = StudentPlanProjectionRepository { _ in
            await calls.record()
            return []
        }
        let state = StudentPlanProjectionState(repository: repository)

        await state.load(grant: try grant(operations: [.readAssignment]))

        #expect(state.phase == .unavailable)
        #expect(await calls.count == 0)
    }

    @Test("The view state owns only redacted projection values")
    func loadsRedactedProjection() async throws {
        let expected = StudentPlanProjection(
            planTitle: "Chase Your Space",
            goals: [],
            progress: [],
            completionPercentage: 0
        )
        let repository = StudentPlanProjectionRepository { _ in [expected] }
        let state = StudentPlanProjectionState(repository: repository)

        await state.load(grant: try grant(operations: [.readStudentVisiblePlan]))

        #expect(state.phase == .loaded([expected]))
    }

    @Test("A response from an old session cannot replace the current session")
    func staleResponseIsIgnored() async throws {
        let gate = ProjectionLoadGate()
        let oldGrant = try grant(sessionID: "old", operations: [.readStudentVisiblePlan])
        let newGrant = try grant(sessionID: "new", operations: [.readStudentVisiblePlan])
        let repository = StudentPlanProjectionRepository { grant in
            if grant.sessionID == "old" {
                await gate.wait()
                return [Self.projection(title: "Old")]
            }
            return [Self.projection(title: "New")]
        }
        let state = StudentPlanProjectionState(repository: repository)

        let oldLoad = Task { await state.load(grant: oldGrant) }
        await gate.waitUntilWaiting()
        await state.load(grant: newGrant)
        await gate.release()
        await oldLoad.value

        #expect(state.phase == .loaded([Self.projection(title: "New")]))
    }

    private func grant(
        sessionID: String = "session-1",
        operations: Set<StudentModeOperation>
    ) throws -> StudentModeGrant {
        StudentModeGrant(
            sessionID: sessionID,
            scope: try StudentModeScope(
                districtID: "district-1",
                studentID: "student-1",
                assignmentIDs: ["assignment-1"],
                allowedOperations: operations
            ),
            recordVersion: 1,
            issuedAt: Date(timeIntervalSince1970: 1_000),
            expiresAt: Date(timeIntervalSince1970: 2_000),
            staffIdentity: StudentModeStaffIdentity(
                userID: "staff-1",
                districtID: "district-1",
                membershipVersion: 1
            )
        )
    }

    private static func projection(title: String) -> StudentPlanProjection {
        StudentPlanProjection(
            planTitle: title,
            goals: [],
            progress: [],
            completionPercentage: 0
        )
    }
}

private actor LoadCounter {
    private(set) var count = 0
    func record() { count += 1 }
}

private actor ProjectionLoadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isWaiting = false
    private var waitingObservers: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        isWaiting = true
        waitingObservers.forEach { $0.resume() }
        waitingObservers.removeAll()
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilWaiting() async {
        guard !isWaiting else { return }
        await withCheckedContinuation { continuation in
            waitingObservers.append(continuation)
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
