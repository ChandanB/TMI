import Foundation
import Testing
@testable import TMI

@Suite("Secure Student Mode session")
@MainActor
struct StudentModeSessionTests {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Cold launch is contained before asynchronous restoration starts")
    func coldLaunchStartsContained() {
        let session = StudentModeSession()

        #expect(session.state == .restoring)
        #expect(session.isStudentModeContained)
        guard case .student(let profile) = session.rootPresentation else {
            Issue.record("The first root presentation exposed the staff shell.")
            return
        }
        #expect(profile == .restoring)
    }

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
        session.activate(
            try grant(expiresAt: start.addingTimeInterval(1_800)),
            profile: profile(),
            at: start
        )

        session.evaluate(at: start.addingTimeInterval(299.999))
        #expect(session.state.isActive)

        session.evaluate(at: start.addingTimeInterval(300))
        #expect(session.state == .locked(.inactivity))
        #expect(session.isStudentModeContained)
        #expect(session.studentProfile == profile())
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
            profile: profile(),
            at: expiry.addingTimeInterval(-1)
        )

        session.evaluate(at: expiry.addingTimeInterval(-0.001))
        #expect(session.state.isActive)
        session.evaluate(at: expiry)
        #expect(session.state.isExpired)
        #expect(session.isStudentModeContained)
        #expect(session.studentProfile == profile())
    }

    @Test("Revoking the scoped assignment locks immediately")
    func assignmentRevocation() throws {
        let session = StudentModeSession()
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)

        session.revokeAssignment("assignment-a", at: start.addingTimeInterval(1))

        #expect(session.state == .locked(.assignmentRevoked))
    }

    @Test("Secure exit clears all respondent state")
    func secureExitReset() async throws {
        let session = StudentModeSession(
            authenticateStaff: { true },
            securelyEndRespondentSession: { _ in }
        )
        session.activate(try grant(expiresAt: start.addingTimeInterval(1_800)), at: start)
        session.recordFailedExitAttempt(at: start.addingTimeInterval(1))
        session.enterBackground(at: start.addingTimeInterval(2))

        #expect(await session.exitStudentMode())

        #expect(session.state == .inactive)
        #expect(session.failedExitAttemptCount == 0)
        #expect(session.lastActivityAt == nil)
        #expect(session.backgroundedAt == nil)
        #expect(!session.isStudentModeContained)
        #expect(session.studentProfile == nil)
    }

    @Test("Only authenticated server-acknowledged exit releases containment")
    func authenticatedSecureExitBoundary() async throws {
        let exit = StudentModeSecureExitSpy()
        let session = StudentModeSession(
            authenticateStaff: { true },
            securelyEndRespondentSession: { grant in
                await exit.record(grant)
            }
        )
        let grant = try grant(expiresAt: start.addingTimeInterval(1_800))
        session.activate(grant, profile: profile(), at: start)
        session.recordFailedExitAttempt(at: start.addingTimeInterval(1))

        let succeeded = await session.exitStudentMode()

        #expect(succeeded)
        #expect(await exit.endedSessionID == grant.sessionID)
        #expect(session.state == .inactive)
        #expect(!session.isStudentModeContained)
    }

    @Test("Failed authenticated server exit stays in the contained shell")
    func failedServerExitRetainsContainment() async throws {
        let session = StudentModeSession(
            authenticateStaff: { true },
            securelyEndRespondentSession: { _ in
                throw StudentModeRepositoryError.unavailable
            }
        )
        session.activate(
            try grant(expiresAt: start.addingTimeInterval(1_800)),
            profile: profile(),
            at: start
        )

        let succeeded = await session.exitStudentMode()

        #expect(!succeeded)
        #expect(session.isStudentModeContained)
        #expect(session.studentProfile == profile())
    }

    @Test("Scene lifecycle forwards protected background boundaries")
    func sceneLifecycleBoundary() throws {
        let session = StudentModeSession()
        session.activate(
            try grant(expiresAt: start.addingTimeInterval(1_800)),
            profile: profile(),
            at: start
        )

        session.handleSceneTransition(
            from: .active,
            to: .background,
            at: start.addingTimeInterval(10)
        )
        session.handleSceneTransition(
            from: .background,
            to: .inactive,
            at: start.addingTimeInterval(39)
        )
        session.handleSceneTransition(
            from: .inactive,
            to: .active,
            at: start.addingTimeInterval(40)
        )

        #expect(session.state == .locked(.backgroundProtection))
        #expect(session.isStudentModeContained)
    }

    @Test("Root presentation never exposes the staff shell while locked or expired")
    func rootPresentationBoundary() throws {
        let expiry = start.addingTimeInterval(1_800)
        let session = StudentModeSession()
        session.activate(
            try grant(expiresAt: expiry),
            profile: profile(),
            at: start
        )
        session.recordFailedExitAttempt(at: start.addingTimeInterval(1))
        session.recordFailedExitAttempt(at: start.addingTimeInterval(2))
        session.recordFailedExitAttempt(at: start.addingTimeInterval(3))
        session.recordFailedExitAttempt(at: start.addingTimeInterval(4))
        session.recordFailedExitAttempt(at: start.addingTimeInterval(5))
        #expect(session.rootPresentation == .student(profile()))

        let expiringSession = StudentModeSession()
        expiringSession.activate(
            try grant(expiresAt: expiry),
            profile: profile(),
            at: start
        )
        expiringSession.evaluate(at: expiry)
        #expect(expiringSession.rootPresentation == .student(profile()))
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
            recordVersion: 1,
            issuedAt: start,
            expiresAt: expiresAt,
            staffIdentity: StudentModeStaffIdentity(
                userID: "staff-a",
                districtID: "district-a",
                membershipVersion: 4
            )
        )
    }

    private func profile() -> StudentModeProfile {
        StudentModeProfile(
            studentID: "student-a",
            displayName: "Student",
            grade: "7",
            pronouns: nil
        )
    }
}

@Suite("Student Mode repository")
struct StudentModeRepositoryTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("The durable marker contains only opaque containment identifiers")
    func durableMarkerContainsNoStudentOrCredentialData() throws {
        let encoded = try JSONEncoder().encode(containmentRecord())
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "schemaVersion",
            "districtID",
            "sessionID",
        ])
    }

    @Test("An ordinary cold launch clears containment only after proving no persisted evidence")
    @MainActor
    func ordinaryColdLaunchClearsAfterProbe() async {
        let repository = restorationRepository(
            markerLoad: .missing,
            persistedRespondent: nil
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .inactive)
        #expect(session.rootPresentation == .staff)
    }

    @Test("Persisted respondent Auth restores a locked safe shell without a marker")
    @MainActor
    func persistedRespondentAuthRestoresContainment() async {
        let repository = restorationRepository(
            markerLoad: .missing,
            persistedRespondent: containmentRecord()
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .locked(.coldRelaunch))
        #expect(session.studentProfile == restoredProfile())
        #expect(session.rootPresentation == .student(restoredProfile()))
    }

    @Test("Unavailable restoration remains fail-closed")
    @MainActor
    func unavailableRestorationRemainsContained() async {
        let repository = restorationRepository(
            markerLoad: .record(containmentRecord()),
            restoreError: .unavailable
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .restoring)
        #expect(session.rootPresentation == .student(.restoring))
    }

    @Test("Unavailable restoration can retry without releasing containment")
    @MainActor
    func unavailableRestorationCanRetry() async {
        let attempts = StudentModeRetryRestorationSpy()
        let repository = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            restoreSession: { _ in
                if await attempts.shouldFailAttempt() {
                    throw StudentModeRepositoryError.unavailable
                }
                return self.restorationResponse()
            },
            endSession: { _ in throw StudentModeTransportTestError.offline },
            containmentStore: StudentModeContainmentStore(
                load: { .record(self.containmentRecord()) },
                save: { _ in },
                clear: {}
            )
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )
        #expect(session.state == .restoring)

        await session.retryPersistedContainment(now: now)

        #expect(session.state == .locked(.coldRelaunch))
        #expect(await attempts.attemptCount == 2)
    }

    @Test("A corrupt durable marker remains fail-closed without contacting restoration")
    @MainActor
    func corruptMarkerRemainsContained() async {
        let transport = StudentModeRestorationSpy()
        let repository = restorationRepository(
            markerLoad: .corrupt,
            restorationSpy: transport
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .restoring)
        #expect(session.rootPresentation == .student(.restoring))
        #expect(await transport.restoreCount == 0)
    }

    @Test("A restored grant with expanded operations remains fail-closed")
    @MainActor
    func expandedRestoredOperationsRemainContained() async {
        let repository = restorationRepository(
            markerLoad: .record(containmentRecord()),
            restoredOperations: [.readAssignment, .updateInterests]
        )
        let session = StudentModeSession()

        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .restoring)
        #expect(session.rootPresentation == .student(.restoring))
    }

    @Test("Authenticated exit after cold restoration ends server state then signs out and clears marker")
    @MainActor
    func restoredSessionExitsSecurely() async {
        let lifecycle = StudentModePersistenceLifecycleSpy()
        let repository = restorationRepository(
            markerLoad: .record(containmentRecord()),
            lifecycleSpy: lifecycle
        )
        let session = StudentModeSession(authenticateStaff: { true })
        session.configureSecureExit(repository: repository)
        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        let exited = await session.exitStudentMode()

        #expect(exited)
        #expect(session.state == .inactive)
        #expect(session.rootPresentation == .staff)
        #expect(await lifecycle.events == [
            .markerSaved,
            .respondentSignedIn,
            .serverEnded,
            .respondentSignedOut,
            .markerCleared,
        ])
    }

    @Test("Verified terminal restoration requires authentication before sign-out and marker clear")
    @MainActor
    func verifiedTerminalRestorationExitsSecurely() async {
        let lifecycle = StudentModePersistenceLifecycleSpy()
        let repository = restorationRepository(
            markerLoad: .record(containmentRecord()),
            restoredStatus: .expired,
            lifecycleSpy: lifecycle
        )
        let session = StudentModeSession(authenticateStaff: { true })
        session.configureSecureExit(repository: repository)
        await session.restorePersistedContainment(
            repository: repository,
            staffIdentity: staffIdentity(),
            now: now
        )

        #expect(session.state == .expired)
        let exited = await session.exitStudentMode()

        #expect(exited)
        #expect(session.state == .inactive)
        #expect(session.rootPresentation == .staff)
        #expect(await lifecycle.events == [
            .respondentSignedOut,
            .markerCleared,
        ])
    }

    @Test("Issuance preserves staff identity and validates the trusted response scope")
    func issuePreservesIdentity() async throws {
        let transport = StudentModeTransportSpy()
        let respondentAuth = StudentModeRespondentAuthSpy()
        let repository = StudentModeRepository(
            issueSession: { request in
                await transport.recordIssue(request)
                return self.response(for: request)
            },
            endSession: { request in
                await transport.recordEnd(request)
                return StudentModeEndResponse(
                    sessionID: request.sessionID,
                    ended: true,
                    recordVersion: request.expectedRecordVersion + 1
                )
            },
            signInRespondent: { token in
                await respondentAuth.signIn(token: token)
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
        #expect(grant.recordVersion == 1)
        let request = await transport.lastIssue
        #expect(request?.durationMinutes == 30)
        #expect(request?.payload.keys.sorted() == [
            "assignmentIDs",
            "districtID",
            "durationMinutes",
            "expectedRecordVersion",
            "idempotencyKey",
            "reasonCode",
            "studentID",
        ])
        #expect(await respondentAuth.signedInToken == "respondent-token")
    }

    @Test("Requested duration is capped before transport")
    func durationIsCapped() async throws {
        let transport = StudentModeTransportSpy()
        let repository = StudentModeRepository(
            issueSession: { request in
                await transport.recordIssue(request)
                return self.response(for: request)
            },
            endSession: {
                StudentModeEndResponse(
                    sessionID: $0.sessionID,
                    ended: true,
                    recordVersion: $0.expectedRecordVersion + 1
                )
            }
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
                endSession: {
                    StudentModeEndResponse(
                        sessionID: $0.sessionID,
                        ended: true,
                        recordVersion: $0.expectedRecordVersion + 1
                    )
                }
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

        await #expect(throws: StudentModeRepositoryError.unavailable) {
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

    @Test(
        "Callable cancellation auth conflict validation and unavailable errors remain distinct",
        arguments: [
            (StudentModeCallableError.cancelled, StudentModeRepositoryError.cancelled),
            (.unauthenticated, .authenticationRequired),
            (.alreadyExists, .conflict),
            (.invalidArgument, .validation),
            (.unavailable, .unavailable),
        ]
    )
    func typedErrorMapping(
        callableError: StudentModeCallableError,
        expected: StudentModeRepositoryError
    ) async throws {
        let repository = StudentModeRepository(
            issueSession: { _ in throw callableError },
            endSession: { _ in throw callableError }
        )

        await #expect(throws: expected) {
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

    @Test("Ending validates acknowledgement without changing staff authentication")
    func endSessionValidation() async throws {
        let identity = staffIdentity()
        let respondentAuth = StudentModeRespondentAuthSpy()
        let repository = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { request in
                #expect(request.districtID == identity.districtID)
                #expect(request.expectedRecordVersion == 3)
                #expect(request.payload.keys.sorted() == [
                    "disposition",
                    "districtID",
                    "expectedRecordVersion",
                    "idempotencyKey",
                    "reasonCode",
                    "sessionID",
                ])
                return StudentModeEndResponse(
                    sessionID: request.sessionID,
                    ended: true,
                    recordVersion: 4
                )
            },
            signOutRespondent: {
                await respondentAuth.signOut()
            }
        )
        try await repository.endSession(
            sessionID: "opaque-session-a",
            staffIdentity: identity,
            expectedRecordVersion: 3,
            disposition: .ended,
            idempotencyKey: "end-a",
            reasonCode: "secure-exit"
        )
        #expect(await respondentAuth.signOutCount == 1)

        let malformed = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { _ in
                StudentModeEndResponse(
                    sessionID: "different-session",
                    ended: true,
                    recordVersion: 4
                )
            }
        )
        await #expect(throws: StudentModeRepositoryError.invalidResponse) {
            try await malformed.endSession(
                sessionID: "opaque-session-a",
                staffIdentity: identity,
                expectedRecordVersion: 3,
                disposition: .ended,
                idempotencyKey: "end-a",
                reasonCode: "secure-exit"
            )
        }
    }

    @Test("Local cleanup retry does not repeat an acknowledged server end")
    func endSessionCleanupRetrySkipsServerMutation() async throws {
        let lifecycle = StudentModeEndCleanupRetrySpy()
        let repository = StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            endSession: { request in
                try await lifecycle.end(request)
            },
            containmentStore: StudentModeContainmentStore(
                load: { .missing },
                save: { _ in },
                clear: {
                    await lifecycle.clearMarker()
                }
            ),
            signOutRespondent: {
                try await lifecycle.signOut()
            }
        )
        let identity = staffIdentity()

        await #expect(throws: StudentModeRepositoryError.authenticationRequired) {
            try await repository.endSession(
                sessionID: "opaque-session-a",
                staffIdentity: identity,
                expectedRecordVersion: 3,
                disposition: .ended,
                idempotencyKey: "end-first",
                reasonCode: "secure-exit"
            )
        }

        try await repository.endSession(
            sessionID: "opaque-session-a",
            staffIdentity: identity,
            expectedRecordVersion: 3,
            disposition: .ended,
            idempotencyKey: "end-retry",
            reasonCode: "secure-exit"
        )

        #expect(await lifecycle.endCallCount == 1)
        #expect(await lifecycle.signOutCallCount == 2)
        #expect(await lifecycle.markerClearCount == 1)
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
            customToken: "respondent-token",
            recordVersion: 1,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(
                TimeInterval(request.durationMinutes * 60)
            )
        )
    }

    private func containmentRecord() -> StudentModeContainmentRecord {
        StudentModeContainmentRecord(
            districtID: "district-a",
            sessionID: "opaque-session-a"
        )
    }

    private func restoredProfile() -> StudentModeProfile {
        StudentModeProfile(
            studentID: "student-a",
            displayName: "Student",
            grade: "7",
            pronouns: nil
        )
    }

    private func restorationResponse(
        status: StudentModeServerStatus = .active,
        operations: Set<StudentModeOperation> = StudentModeOperation.surveyAssignment
    ) -> StudentModeRestoreResponse {
        let isActive = status == .active
        return StudentModeRestoreResponse(
            status: status,
            sessionID: "opaque-session-a",
            districtID: "district-a",
            studentID: isActive ? "student-a" : nil,
            assignmentIDs: isActive ? ["assignment-a"] : nil,
            allowedOperations: isActive ? operations : nil,
            customToken: isActive ? "restored-respondent-token" : nil,
            recordVersion: 1,
            issuedAt: isActive ? now : nil,
            expiresAt: isActive ? now.addingTimeInterval(1_800) : nil,
            profile: isActive ? restoredProfile() : nil
        )
    }

    private func restorationRepository(
        markerLoad: StudentModeContainmentLoad,
        persistedRespondent: StudentModeContainmentRecord? = nil,
        restoreError: StudentModeRepositoryError? = nil,
        restoredStatus: StudentModeServerStatus = .active,
        restoredOperations: Set<StudentModeOperation> = StudentModeOperation.surveyAssignment,
        restorationSpy: StudentModeRestorationSpy? = nil,
        lifecycleSpy: StudentModePersistenceLifecycleSpy? = nil
    ) -> StudentModeRepository {
        StudentModeRepository(
            issueSession: { _ in throw StudentModeTransportTestError.offline },
            restoreSession: { request in
                await restorationSpy?.recordRestore()
                if let restoreError {
                    throw restoreError
                }
                #expect(request.payload.keys.sorted() == [
                    "districtID",
                    "sessionID",
                ])
                return self.restorationResponse(
                    status: restoredStatus,
                    operations: restoredOperations
                )
            },
            endSession: { request in
                await lifecycleSpy?.record(.serverEnded)
                return StudentModeEndResponse(
                    sessionID: request.sessionID,
                    ended: true,
                    recordVersion: request.expectedRecordVersion + 1
                )
            },
            containmentStore: StudentModeContainmentStore(
                load: { markerLoad },
                save: { _ in
                    await lifecycleSpy?.record(.markerSaved)
                },
                clear: {
                    await lifecycleSpy?.record(.markerCleared)
                }
            ),
            persistedRespondentRecord: { persistedRespondent },
            signInRespondent: { _ in
                await lifecycleSpy?.record(.respondentSignedIn)
            },
            signOutRespondent: {
                await lifecycleSpy?.record(.respondentSignedOut)
            }
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

private actor StudentModeSecureExitSpy {
    private(set) var endedSessionID: String?

    func record(_ grant: StudentModeGrant) {
        endedSessionID = grant.sessionID
    }
}

private actor StudentModeRespondentAuthSpy {
    private(set) var signedInToken: String?
    private(set) var signOutCount = 0

    func signIn(token: String) {
        signedInToken = token
    }

    func signOut() {
        signOutCount += 1
    }
}

private actor StudentModeRestorationSpy {
    private(set) var restoreCount = 0

    func recordRestore() {
        restoreCount += 1
    }
}

private actor StudentModeRetryRestorationSpy {
    private(set) var attemptCount = 0

    func shouldFailAttempt() -> Bool {
        attemptCount += 1
        return attemptCount == 1
    }
}

private enum StudentModePersistenceEvent: Equatable {
    case markerSaved
    case respondentSignedIn
    case serverEnded
    case respondentSignedOut
    case markerCleared
}

private actor StudentModePersistenceLifecycleSpy {
    private(set) var events: [StudentModePersistenceEvent] = []

    func record(_ event: StudentModePersistenceEvent) {
        events.append(event)
    }
}

private actor StudentModeEndCleanupRetrySpy {
    private(set) var endCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var markerClearCount = 0

    func end(_ request: StudentModeEndRequest) throws -> StudentModeEndResponse {
        endCallCount += 1
        guard endCallCount == 1 else {
            throw StudentModeTransportTestError.offline
        }
        return StudentModeEndResponse(
            sessionID: request.sessionID,
            ended: true,
            recordVersion: request.expectedRecordVersion + 1
        )
    }

    func signOut() throws {
        signOutCallCount += 1
        if signOutCallCount == 1 {
            throw StudentModeTransportTestError.offline
        }
    }

    func clearMarker() {
        markerClearCount += 1
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
            customToken: customToken,
            recordVersion: recordVersion,
            issuedAt: issuedAt,
            expiresAt: expiresAt ?? self.expiresAt
        )
    }
}
