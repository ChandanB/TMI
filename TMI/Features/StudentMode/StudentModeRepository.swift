import Foundation

nonisolated struct StudentModeIssueRequest: Sendable, Equatable {
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let durationMinutes: Int
    let expectedStudentRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let staffIdentity: StudentModeStaffIdentity

    // Authority is intentionally absent from the callable payload. The server
    // derives least-privilege operations from the trusted assignment.
    var allowedOperations: Set<StudentModeOperation>? {
        nil
    }
}

nonisolated struct StudentModeIssueResponse: Sendable, Equatable {
    let sessionID: String
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let allowedOperations: Set<StudentModeOperation>
    let respondentToken: String
    let issuedAt: Date
    let expiresAt: Date
}

nonisolated enum StudentModeEndDisposition: String, Sendable {
    case ended
    case revoked
}

nonisolated struct StudentModeEndRequest: Sendable, Equatable {
    let districtID: String
    let sessionID: String
    let disposition: StudentModeEndDisposition
    let idempotencyKey: String
    let reasonCode: String
    let staffIdentity: StudentModeStaffIdentity
}

nonisolated struct StudentModeEndResponse: Sendable, Equatable {
    let sessionID: String
    let ended: Bool
}

nonisolated enum StudentModeRepositoryError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case transportUnavailable
}

nonisolated struct StudentModeRepository: Sendable {
    typealias IssueSession = @Sendable (
        StudentModeIssueRequest
    ) async throws -> StudentModeIssueResponse
    typealias EndSession = @Sendable (
        StudentModeEndRequest
    ) async throws -> StudentModeEndResponse

    private let issueSessionTransport: IssueSession
    private let endSessionTransport: EndSession

    init(
        issueSession: @escaping IssueSession,
        endSession: @escaping EndSession
    ) {
        issueSessionTransport = issueSession
        endSessionTransport = endSession
    }

    func issueSession(
        scope: StudentModeScope,
        requestedDurationMinutes: Int?,
        staffIdentity: StudentModeStaffIdentity,
        expectedStudentRecordVersion: Int,
        idempotencyKey: String,
        reasonCode: String,
        now: Date = Date()
    ) async throws -> StudentModeGrant {
        guard isValid(identity: staffIdentity),
              staffIdentity.districtID == scope.districtID,
              expectedStudentRecordVersion > 0,
              isValidIdentifier(idempotencyKey),
              !reasonCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentModeRepositoryError.invalidRequest
        }
        let durationMinutes = Int(
            StudentModeSession.duration(
                forRequestedMinutes: requestedDurationMinutes
            ) / 60
        )
        let request = StudentModeIssueRequest(
            districtID: scope.districtID,
            studentID: scope.studentID,
            assignmentIDs: scope.assignmentIDs,
            durationMinutes: durationMinutes,
            expectedStudentRecordVersion: expectedStudentRecordVersion,
            idempotencyKey: idempotencyKey,
            reasonCode: reasonCode,
            staffIdentity: staffIdentity
        )
        let response: StudentModeIssueResponse
        do {
            response = try await issueSessionTransport(request)
        } catch let error as StudentModeRepositoryError {
            throw error
        } catch {
            throw StudentModeRepositoryError.transportUnavailable
        }

        guard isValidIdentifier(response.sessionID),
              !response.respondentToken.isEmpty,
              response.districtID == scope.districtID,
              response.studentID == scope.studentID,
              response.assignmentIDs == scope.assignmentIDs,
              response.allowedOperations == scope.allowedOperations,
              response.issuedAt < response.expiresAt,
              now < response.expiresAt,
              response.expiresAt.timeIntervalSince(response.issuedAt)
                <= TimeInterval(durationMinutes * 60),
              response.expiresAt.timeIntervalSince(response.issuedAt)
                <= StudentModeSession.duration(forRequestedMinutes: 60) else {
            throw StudentModeRepositoryError.invalidResponse
        }

        return StudentModeGrant(
            sessionID: response.sessionID,
            scope: scope,
            respondentToken: response.respondentToken,
            issuedAt: response.issuedAt,
            expiresAt: response.expiresAt,
            staffIdentity: staffIdentity
        )
    }

    func endSession(
        sessionID: String,
        staffIdentity: StudentModeStaffIdentity,
        disposition: StudentModeEndDisposition,
        idempotencyKey: String,
        reasonCode: String
    ) async throws {
        guard isValidIdentifier(sessionID),
              isValid(identity: staffIdentity),
              isValidIdentifier(idempotencyKey),
              !reasonCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentModeRepositoryError.invalidRequest
        }
        let request = StudentModeEndRequest(
            districtID: staffIdentity.districtID,
            sessionID: sessionID,
            disposition: disposition,
            idempotencyKey: idempotencyKey,
            reasonCode: reasonCode,
            staffIdentity: staffIdentity
        )
        let response: StudentModeEndResponse
        do {
            response = try await endSessionTransport(request)
        } catch let error as StudentModeRepositoryError {
            throw error
        } catch {
            throw StudentModeRepositoryError.transportUnavailable
        }
        guard response.ended, response.sessionID == sessionID else {
            throw StudentModeRepositoryError.invalidResponse
        }
    }

    private func isValid(identity: StudentModeStaffIdentity) -> Bool {
        isValidIdentifier(identity.userID) &&
            isValidIdentifier(identity.districtID) &&
            identity.membershipVersion > 0
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.contains("/")
    }
}
