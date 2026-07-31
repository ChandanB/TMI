import Foundation
import Testing
@testable import TMI

@Suite("Secure Student Mode session")
@MainActor
struct StudentModeSessionTests {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Duration defaults to thirty minutes and caps at sixty")
    func durationPolicy() {
        #expect(StudentModeSession.duration(forRequestedMinutes: nil) == 30 * 60)
        #expect(StudentModeSession.duration(forRequestedMinutes: 45) == 45 * 60)
        #expect(StudentModeSession.duration(forRequestedMinutes: 90) == 60 * 60)
    }

    @Test("A scope contains exactly one student and one assignment")
    func oneStudentOneAssignmentScope() throws {
        let scope = try StudentModeScope(
            districtID: "district-a",
            studentID: "student-a",
            assignmentIDs: ["assignment-a"],
            allowedOperations: [.readAssignment, .writeDraft]
        )

        #expect(scope.studentID == "student-a")
        #expect(scope.assignmentIDs == ["assignment-a"])
        #expect(throws: StudentModeSessionError.invalidScope) {
            _ = try StudentModeScope(
                districtID: "district-a",
                studentID: "student-a",
                assignmentIDs: ["assignment-a", "assignment-b"],
                allowedOperations: [.readAssignment]
            )
        }
        #expect(throws: StudentModeSessionError.invalidScope) {
            _ = try StudentModeScope(
                districtID: "district-a",
                studentID: "student-a",
                assignmentIDs: [],
                allowedOperations: [.readAssignment]
            )
        }
    }

    @Test("Inactivity locks at exactly five minutes")
    func inactivityBoundary() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)

        session.evaluate(at: start.addingTimeInterval(299.999))
        #expect(session.state.isActive)

        session.evaluate(at: start.addingTimeInterval(300))
        #expect(session.state == .locked(.inactivity))
    }

    @Test("Explicit activity moves the inactivity boundary")
    func explicitActivity() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)

        session.recordActivity(at: start.addingTimeInterval(299))
        session.evaluate(at: start.addingTimeInterval(598.999))
        #expect(session.state.isActive)
        session.evaluate(at: start.addingTimeInterval(599))
        #expect(session.state == .locked(.inactivity))
    }

    @Test("Protected background time locks at exactly thirty seconds")
    func backgroundBoundary() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)
        session.enterBackground(at: start.addingTimeInterval(10))

        session.returnToForeground(at: start.addingTimeInterval(39.999))
        #expect(session.state.isActive)

        session.enterBackground(at: start.addingTimeInterval(40))
        session.returnToForeground(at: start.addingTimeInterval(70))
        #expect(session.state == .locked(.backgroundProtection))
    }

    @Test("The fifth failed exit attempt locks the session")
    func failedExitBoundary() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)

        for attempt in 1 ... 4 {
            session.recordFailedExitAttempt(at: start.addingTimeInterval(Double(attempt)))
            #expect(session.state.isActive)
        }
        session.recordFailedExitAttempt(at: start.addingTimeInterval(5))

        #expect(session.state == .locked(.failedExitAttempts))
    }

    @Test("Expiry occurs at the exact expiry instant")
    func expiryBoundary() throws {
        let expiry = start.addingTimeInterval(1_800)
        let session = StudentModeSession()
        session.activate(
            try grant(expiresAt: expiry),
            at: expiry.addingTimeInterval(-1)
        )

        session.evaluate(at: expiry.addingTimeInterval(-0.001))
        #expect(session.state.isActive)
        session.evaluate(at: expiry)
        #expect(session.state.isExpired)
    }

    @Test("Revoking the scoped assignment locks immediately")
    func assignmentRevocation() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)

        session.revokeAssignment("assignment-a", at: start.addingTimeInterval(1))

        #expect(session.state == .locked(.assignmentRevoked))
    }

    @Test("Secure exit clears all respondent state")
    func secureExitReset() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)
        session.recordFailedExitAttempt(at: start.addingTimeInterval(1))
        session.enterBackground(at: start.addingTimeInterval(2))

        session.secureExit()

        #expect(session.state == .inactive)
        #expect(session.failedExitAttemptCount == 0)
        #expect(session.lastActivityAt == nil)
        #expect(session.backgroundedAt == nil)
    }

    private func grant(expiresAt: Date) throws -> StudentModeGrant {
        StudentModeGrant(
            sessionID: "opaque-session-a",
            scope: try StudentModeScope(
                districtID: "district-a",
                studentID: "student-a",
                assignmentIDs: ["assignment-a"],
                allowedOperations: [.readAssignment, .writeDraft]
            ),
            respondentToken: "respondent-token",
            issuedAt: start,
            expiresAt: expiresAt,
            staffIdentity: StudentModeStaffIdentity(
                userID: "staff-a",
                districtID: "district-a",
                membershipVersion: 4
            )
        )
    }
}

@Suite("Student Mode repository")
struct StudentModeRepositoryTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Issuance preserves staff identity and validates the trusted response scope")
    func issuePreservesIdentity() async throws {
        let transport = StudentModeTransportSpy()
        let repository = StudentModeRepository(
            issueSession: { request in
                await transport.recordIssue(request)
                return self.response(for: request)
            },
            endSession: { request in
                await transport.recordEnd(request)
                return StudentModeEndResponse(sessionID: request.sessionID, ended: true)
            }
        )
        let identity = staffIdentity()
        let scope = try studentScope()

        let grant = try await repository.issueSession(
            scope: scope,
            requestedDurationMinutes: nil,
            staffIdentity: identity,
            expectedStudentRecordVersion: 7,
            idempotencyKey: "issue-a",
            reasonCode: "educator-launch",
            now: now
        )

        #expect(grant.staffIdentity == identity)
        #expect(grant.scope == scope)
        #expect(grant.respondentToken == "respondent-token")
        let request = await transport.lastIssue
        #expect(request?.durationMinutes == 30)
        #expect(request?.staffIdentity == identity)
        #expect(request?.allowedOperations == nil)
    }

    @Test("Requested duration is capped before transport")
    func durationIsCapped() async throws {
        let transport = StudentModeTransportSpy()
        let repository = StudentModeRepository(
            issueSession: { request in
                await transport.recordIssue(request)
                return self.response(for: request)
            },
            endSession: { _ in StudentModeEndResponse(sessionID: "unused", ended: true) }
        )

        _ = try await repository.issueSession(
            scope: try studentScope(),
            requestedDurationMinutes: 90,
            staffIdentity: staffIdentity(),
            expectedStudentRecordVersion: 7,
            idempotencyKey: "issue-a",
            reasonCode: "educator-launch",
            now: now
        )

        #expect(await transport.lastIssue?.durationMinutes == 60)
    }

    @Test("Cross-student district assignment and operation responses are rejected")
    func responseScopeValidation() async throws {
        for mutation in StudentModeResponseMutation.allCases {
            let repository = StudentModeRepository(
                issueSession: { request in
                    mutation.apply(to: self.response(for: request))
                },
                endSession: { _ in StudentModeEndResponse(sessionID: "unused", ended: true) }
            )

            await #expect(throws: StudentModeRepositoryError.invalidResponse) {
                _ = try await repository.issueSession(
                    scope: try self.studentScope(),
                    requestedDurationMinutes: 30,
                    staffIdentity: self.staffIdentity(),
                    expectedStudentRecordVersion: 7,
                    idempotencyKey: "issue-a",
                    reasonCode: "educator-launch",
                    now: self.now
                )
            }
        }
    }

    @Test("Transport failures are recoverable and do not erase staff identity")
    func transportFailureIsRecoverable() async throws {
        let repository = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { _ in throw StudentModeTransportTestError.offline }
        )
        let identity = staffIdentity()

        await #expect(throws: StudentModeRepositoryError.transportUnavailable) {
            _ = try await repository.issueSession(
                scope: try self.studentScope(),
                requestedDurationMinutes: 30,
                staffIdentity: identity,
                expectedStudentRecordVersion: 7,
                idempotencyKey: "issue-a",
                reasonCode: "educator-launch",
                now: self.now
            )
        }
        #expect(identity == staffIdentity())
    }

    @Test("Ending validates acknowledgement without changing staff authentication")
    func endSessionValidation() async throws {
        let identity = staffIdentity()
        let repository = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { request in
                #expect(request.staffIdentity == identity)
                return StudentModeEndResponse(sessionID: request.sessionID, ended: true)
            }
        )

        try await repository.endSession(
            sessionID: "opaque-session-a",
            staffIdentity: identity,
            disposition: .ended,
            idempotencyKey: "end-a",
            reasonCode: "secure-exit"
        )

        let malformed = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { _ in
                StudentModeEndResponse(sessionID: "different-session", ended: true)
            }
        )
        await #expect(throws: StudentModeRepositoryError.invalidResponse) {
            try await malformed.endSession(
                sessionID: "opaque-session-a",
                staffIdentity: identity,
                disposition: .ended,
                idempotencyKey: "end-a",
                reasonCode: "secure-exit"
            )
        }
    }

    private func staffIdentity() -> StudentModeStaffIdentity {
        StudentModeStaffIdentity(
            userID: "staff-a",
            districtID: "district-a",
            membershipVersion: 4
        )
    }

    private func studentScope() throws -> StudentModeScope {
        try StudentModeScope(
            districtID: "district-a",
            studentID: "student-a",
            assignmentIDs: ["assignment-a"],
            allowedOperations: [.readAssignment, .writeDraft]
        )
    }

    private func response(
        for request: StudentModeIssueRequest
    ) -> StudentModeIssueResponse {
        StudentModeIssueResponse(
            sessionID: "opaque-session-a",
            districtID: request.districtID,
            studentID: request.studentID,
            assignmentIDs: request.assignmentIDs,
            allowedOperations: [.readAssignment, .writeDraft],
            respondentToken: "respondent-token",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(
                TimeInterval(request.durationMinutes * 60)
            )
        )
    }
}

private actor StudentModeTransportSpy {
    private(set) var lastIssue: StudentModeIssueRequest?
    private(set) var lastEnd: StudentModeEndRequest?

    func recordIssue(_ request: StudentModeIssueRequest) {
        lastIssue = request
    }

    func recordEnd(_ request: StudentModeEndRequest) {
        lastEnd = request
    }
}

private enum StudentModeTransportTestError: Error {
    case offline
}

private enum StudentModeResponseMutation: CaseIterable {
    case district
    case student
    case assignment
    case operations
    case expired
    case duration
    case sessionID

    func apply(to response: StudentModeIssueResponse) -> StudentModeIssueResponse {
        switch self {
        case .district:
            return response.replacing(districtID: "district-b")
        case .student:
            return response.replacing(studentID: "student-b")
        case .assignment:
            return response.replacing(assignmentIDs: ["assignment-b"])
        case .operations:
            return response.replacing(allowedOperations: [.requestHelp])
        case .expired:
            return response.replacing(expiresAt: response.issuedAt)
        case .duration:
            return response.replacing(
                expiresAt: response.issuedAt.addingTimeInterval(3_601)
            )
        case .sessionID:
            return response.replacing(sessionID: "")
        }
    }
}

private extension StudentModeIssueResponse {
    func replacing(
        sessionID: String? = nil,
        districtID: String? = nil,
        studentID: String? = nil,
        assignmentIDs: Set<String>? = nil,
        allowedOperations: Set<StudentModeOperation>? = nil,
        expiresAt: Date? = nil
    ) -> StudentModeIssueResponse {
        StudentModeIssueResponse(
            sessionID: sessionID ?? self.sessionID,
            districtID: districtID ?? self.districtID,
            studentID: studentID ?? self.studentID,
            assignmentIDs: assignmentIDs ?? self.assignmentIDs,
            allowedOperations: allowedOperations ?? self.allowedOperations,
            respondentToken: respondentToken,
            issuedAt: issuedAt,
            expiresAt: expiresAt ?? self.expiresAt
        )
    }
}
