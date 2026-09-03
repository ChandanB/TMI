import Foundation

/// Issues Student Mode sessions without Cloud Functions.
///
/// The deployed design mints a short-lived, student-scoped Firebase identity
/// with `issueStudentModeSession`, and Firestore rules gate respondent access
/// on those custom claims. Minting a custom token requires the Admin SDK, so
/// with Functions undeployed that identity cannot exist at all.
///
/// In this mode Student Mode runs inside the supervising educator's session.
/// Containment is the client-side session: the inactivity lock, the restricted
/// surface, and the educator authentication required to exit, all of which are
/// already enforced by `StudentModeSession`. Firestore still authorizes every
/// read and write, but against the educator's membership rather than a
/// student-scoped token.
///
/// The reduction is real and deliberate: a session left open exposes the
/// educator's credential rather than a token limited to one student and one
/// assignment. Restore `usesTrustedMutationCallables` once Functions are
/// deployed and the respondent identity comes back with it.
nonisolated struct LocalStudentModeRuntime: Sendable {
    /// Stands in for the custom token the callable would return. It is never
    /// sent to Firebase; sign-in is a no-op because the educator's session is
    /// already the acting identity.
    static let localSessionToken = "local-student-mode-session"

    private let now: @Sendable () -> Date
    private let makeSessionID: @Sendable () -> String

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        makeSessionID: @escaping @Sendable () -> String = {
            "sms_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        }
    ) {
        self.now = now
        self.makeSessionID = makeSessionID
    }

    func issueSession(
        _ request: StudentModeIssueRequest
    ) async throws -> StudentModeIssueResponse {
        let issuedAt = now()
        let expiresAt = issuedAt.addingTimeInterval(
            TimeInterval(request.durationMinutes * 60)
        )
        return StudentModeIssueResponse(
            sessionID: makeSessionID(),
            districtID: request.districtID,
            studentID: request.studentID,
            assignmentIDs: request.assignmentIDs,
            // Both launch sites request exactly this set; anything else is
            // rejected by the repository's scope comparison.
            allowedOperations: StudentModeOperation.surveyAssignment,
            customToken: Self.localSessionToken,
            recordVersion: request.expectedStudentRecordVersion,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
    }

    func endSession(
        _ request: StudentModeEndRequest
    ) async throws -> StudentModeEndResponse {
        StudentModeEndResponse(
            sessionID: request.sessionID,
            ended: true,
            recordVersion: request.expectedRecordVersion
        )
    }

    /// There is no server session to restore. The keychain containment record
    /// is the only durable trace, and `StudentModeRepository` treats a missing
    /// respondent record as a session that must be ended rather than resumed.
    func persistedRespondentRecord() async throws -> StudentModeContainmentRecord? {
        nil
    }

    func signInRespondent(withCustomToken token: String) async throws {
        guard token == Self.localSessionToken else {
            throw StudentModeRepositoryError.invalidResponse
        }
    }

    func signOutRespondent() async throws {}
}
