import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFunctions

nonisolated struct StudentModeIssueRequest: Sendable, Equatable {
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let durationMinutes: Int
    let expectedStudentRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String

    var payload: [String: Any] {
        [
            "districtID": districtID,
            "studentID": studentID,
            "assignmentIDs": assignmentIDs.sorted(),
            "durationMinutes": durationMinutes,
            "expectedRecordVersion": expectedStudentRecordVersion,
            "idempotencyKey": idempotencyKey,
            "reasonCode": reasonCode,
        ]
    }
}

nonisolated struct StudentModeIssueResponse: Sendable, Equatable {
    let sessionID: String
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let allowedOperations: Set<StudentModeOperation>
    let customToken: String
    let recordVersion: Int
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
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String

    var payload: [String: Any] {
        [
            "districtID": districtID,
            "sessionID": sessionID,
            "disposition": disposition.rawValue,
            "expectedRecordVersion": expectedRecordVersion,
            "idempotencyKey": idempotencyKey,
            "reasonCode": reasonCode,
        ]
    }
}

nonisolated struct StudentModeEndResponse: Sendable, Equatable {
    let sessionID: String
    let ended: Bool
    let recordVersion: Int
}

nonisolated enum StudentModeCallableError: Error, Equatable, Sendable {
    case cancelled
    case unauthenticated
    case permissionDenied
    case alreadyExists
    case failedPrecondition
    case aborted
    case invalidArgument
    case outOfRange
    case unavailable
    case deadlineExceeded
    case malformedResponse
    case unknown
}

nonisolated enum StudentModeRepositoryError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case cancelled
    case authenticationRequired
    case conflict
    case validation
    case unavailable
}

nonisolated struct StudentModeRepository: Sendable {
    typealias IssueSession = @Sendable (
        StudentModeIssueRequest
    ) async throws -> StudentModeIssueResponse
    typealias EndSession = @Sendable (
        StudentModeEndRequest
    ) async throws -> StudentModeEndResponse
    typealias SignInRespondent = @Sendable (String) async throws -> Void
    typealias SignOutRespondent = @Sendable () async throws -> Void

    private let issueSessionTransport: IssueSession
    private let endSessionTransport: EndSession
    private let signInRespondent: SignInRespondent
    private let signOutRespondent: SignOutRespondent

    init(
        issueSession: @escaping IssueSession,
        endSession: @escaping EndSession,
        signInRespondent: @escaping SignInRespondent = { _ in },
        signOutRespondent: @escaping SignOutRespondent = {}
    ) {
        issueSessionTransport = issueSession
        endSessionTransport = endSession
        self.signInRespondent = signInRespondent
        self.signOutRespondent = signOutRespondent
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
            reasonCode: reasonCode
        )
        let response: StudentModeIssueResponse
        do {
            response = try await issueSessionTransport(request)
        } catch {
            throw map(error)
        }

        guard isValidIdentifier(response.sessionID),
              !response.customToken.isEmpty,
              response.recordVersion > 0,
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

        do {
            try await signInRespondent(response.customToken)
        } catch {
            throw map(error)
        }

        return StudentModeGrant(
            sessionID: response.sessionID,
            scope: scope,
            recordVersion: response.recordVersion,
            issuedAt: response.issuedAt,
            expiresAt: response.expiresAt,
            staffIdentity: staffIdentity
        )
    }

    func endSession(
        sessionID: String,
        staffIdentity: StudentModeStaffIdentity,
        expectedRecordVersion: Int,
        disposition: StudentModeEndDisposition,
        idempotencyKey: String,
        reasonCode: String
    ) async throws {
        guard isValidIdentifier(sessionID),
              isValid(identity: staffIdentity),
              expectedRecordVersion > 0,
              isValidIdentifier(idempotencyKey),
              !reasonCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentModeRepositoryError.invalidRequest
        }
        let request = StudentModeEndRequest(
            districtID: staffIdentity.districtID,
            sessionID: sessionID,
            disposition: disposition,
            expectedRecordVersion: expectedRecordVersion,
            idempotencyKey: idempotencyKey,
            reasonCode: reasonCode
        )
        let response: StudentModeEndResponse
        do {
            response = try await endSessionTransport(request)
        } catch {
            throw map(error)
        }
        guard response.ended,
              response.sessionID == sessionID,
              response.recordVersion == expectedRecordVersion + 1 else {
            throw StudentModeRepositoryError.invalidResponse
        }
        do {
            try await signOutRespondent()
        } catch {
            throw StudentModeRepositoryError.authenticationRequired
        }
    }

    private func map(_ error: Error) -> StudentModeRepositoryError {
        if let repositoryError = error as? StudentModeRepositoryError {
            return repositoryError
        }
        guard let callableError = error as? StudentModeCallableError else {
            return .unavailable
        }
        switch callableError {
        case .cancelled:
            return .cancelled
        case .unauthenticated, .permissionDenied:
            return .authenticationRequired
        case .alreadyExists, .failedPrecondition, .aborted:
            return .conflict
        case .invalidArgument, .outOfRange:
            return .validation
        case .malformedResponse:
            return .invalidResponse
        case .unavailable, .deadlineExceeded, .unknown:
            return .unavailable
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

extension StudentModeRepository {
    @MainActor
    static func firebase(
        functions: Functions = Functions.functions(region: "us-central1")
    ) -> StudentModeRepository {
        let runtime = FirebaseStudentModeRuntime(functions: functions)
        return StudentModeRepository(
            issueSession: { request in
                try await runtime.issueSession(request)
            },
            endSession: { request in
                try await runtime.endSession(request)
            },
            signInRespondent: { token in
                try await runtime.signInRespondent(withCustomToken: token)
            },
            signOutRespondent: {
                try await runtime.signOutRespondent()
            }
        )
    }
}

@MainActor
private final class FirebaseStudentModeRuntime: @unchecked Sendable {
    private static let respondentAppName = "TMIStudentModeRespondent"

    private let functions: Functions
    private let respondentAuth: Auth

    init(functions: Functions) {
        self.functions = functions
        if FirebaseApp.app(name: Self.respondentAppName) == nil,
           let defaultOptions = FirebaseApp.app()?.options {
            FirebaseApp.configure(
                name: Self.respondentAppName,
                options: defaultOptions
            )
        }
        guard let respondentApp = FirebaseApp.app(name: Self.respondentAppName) else {
            preconditionFailure("Firebase must be configured before Student Mode.")
        }
        respondentAuth = Auth.auth(app: respondentApp)
    }

    func issueSession(
        _ request: StudentModeIssueRequest
    ) async throws -> StudentModeIssueResponse {
        do {
            let result = try await functions
                .httpsCallable("issueStudentModeSession")
                .call(request.payload)
            return try Self.parseIssueResponse(result.data)
        } catch {
            throw Self.callableError(from: error)
        }
    }

    func endSession(
        _ request: StudentModeEndRequest
    ) async throws -> StudentModeEndResponse {
        do {
            let result = try await functions
                .httpsCallable("endStudentModeSession")
                .call(request.payload)
            return try Self.parseEndResponse(result.data)
        } catch {
            throw Self.callableError(from: error)
        }
    }

    func signInRespondent(withCustomToken token: String) async throws {
        _ = try await respondentAuth.signIn(withCustomToken: token)
    }

    func signOutRespondent() throws {
        try respondentAuth.signOut()
    }

    private static func parseIssueResponse(
        _ value: Any
    ) throws -> StudentModeIssueResponse {
        guard let data = value as? [String: Any],
              let sessionID = data["sessionID"] as? String,
              let districtID = data["districtID"] as? String,
              let studentID = data["studentID"] as? String,
              let assignmentIDs = data["assignmentIDs"] as? [String],
              let operationValues = data["allowedOperations"] as? [String],
              let customToken = data["customToken"] as? String,
              let recordVersion = Self.integer(data["recordVersion"]),
              let issuedAt = Self.date(data["issuedAt"]),
              let expiresAt = Self.date(data["expiresAt"]) else {
            throw StudentModeCallableError.malformedResponse
        }
        let operations = Set(operationValues.compactMap(StudentModeOperation.init(rawValue:)))
        guard operations.count == operationValues.count else {
            throw StudentModeCallableError.malformedResponse
        }
        return StudentModeIssueResponse(
            sessionID: sessionID,
            districtID: districtID,
            studentID: studentID,
            assignmentIDs: Set(assignmentIDs),
            allowedOperations: operations,
            customToken: customToken,
            recordVersion: recordVersion,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
    }

    private static func parseEndResponse(
        _ value: Any
    ) throws -> StudentModeEndResponse {
        guard let data = value as? [String: Any],
              let sessionID = data["sessionID"] as? String,
              let ended = data["ended"] as? Bool,
              let recordVersion = Self.integer(data["recordVersion"]) else {
            throw StudentModeCallableError.malformedResponse
        }
        return StudentModeEndResponse(
            sessionID: sessionID,
            ended: ended,
            recordVersion: recordVersion
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber, !(value is Bool) {
            return value.intValue
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value = value as? String else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func callableError(from error: Error) -> StudentModeCallableError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unknown
        }
        switch code {
        case .cancelled:
            return .cancelled
        case .unauthenticated:
            return .unauthenticated
        case .permissionDenied:
            return .permissionDenied
        case .alreadyExists:
            return .alreadyExists
        case .failedPrecondition:
            return .failedPrecondition
        case .aborted:
            return .aborted
        case .invalidArgument:
            return .invalidArgument
        case .outOfRange:
            return .outOfRange
        case .unavailable:
            return .unavailable
        case .deadlineExceeded:
            return .deadlineExceeded
        default:
            return .unknown
        }
    }
}
