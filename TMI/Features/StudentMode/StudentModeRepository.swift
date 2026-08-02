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

nonisolated struct StudentModeRestoreRequest: Sendable, Equatable {
    let districtID: String
    let sessionID: String

    var payload: [String: Any] {
        [
            "districtID": districtID,
            "sessionID": sessionID,
        ]
    }
}

nonisolated enum StudentModeServerStatus: String, Sendable, Equatable {
    case active
    case ended
    case revoked
    case expired

    var isTerminal: Bool {
        self != .active
    }
}

nonisolated struct StudentModeRestoreResponse: Sendable, Equatable {
    let status: StudentModeServerStatus
    let sessionID: String
    let districtID: String
    let studentID: String?
    let assignmentIDs: Set<String>?
    let allowedOperations: Set<StudentModeOperation>?
    let customToken: String?
    let recordVersion: Int
    let issuedAt: Date?
    let expiresAt: Date?
    let profile: StudentModeProfile?
}

nonisolated enum StudentModeStartupResolution: Sendable, Equatable {
    case clear
    case active(StudentModeGrant, StudentModeProfile)
    case terminal(StudentModeContainmentRecord, StudentModeServerStatus)
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

nonisolated enum StudentModeRepositoryError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case cancelled
    case authenticationRequired
    case conflict
    case validation
    case unavailable
    case containmentCorrupt
}

nonisolated struct StudentModeRepository: Sendable {
    typealias IssueSession = @Sendable (
        StudentModeIssueRequest
    ) async throws -> StudentModeIssueResponse
    typealias RestoreSession = @Sendable (
        StudentModeRestoreRequest
    ) async throws -> StudentModeRestoreResponse
    typealias EndSession = @Sendable (
        StudentModeEndRequest
    ) async throws -> StudentModeEndResponse
    typealias SignInRespondent = @Sendable (String) async throws -> Void
    typealias SignOutRespondent = @Sendable () async throws -> Void
    typealias PersistedRespondentRecord = @Sendable () async throws
        -> StudentModeContainmentRecord?

    private let issueSessionTransport: IssueSession
    private let restoreSessionTransport: RestoreSession
    private let endSessionTransport: EndSession
    private let containmentStore: StudentModeContainmentStore
    private let persistedRespondentRecord: PersistedRespondentRecord
    private let signInRespondent: SignInRespondent
    private let signOutRespondent: SignOutRespondent

    init(
        issueSession: @escaping IssueSession,
        restoreSession: @escaping RestoreSession = { _ in
            throw StudentModeRepositoryError.unavailable
        },
        endSession: @escaping EndSession,
        containmentStore: StudentModeContainmentStore = .empty,
        persistedRespondentRecord: @escaping PersistedRespondentRecord = { nil },
        signInRespondent: @escaping SignInRespondent = { _ in },
        signOutRespondent: @escaping SignOutRespondent = {}
    ) {
        issueSessionTransport = issueSession
        restoreSessionTransport = restoreSession
        endSessionTransport = endSession
        self.containmentStore = containmentStore
        self.persistedRespondentRecord = persistedRespondentRecord
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

        let containmentRecord = StudentModeContainmentRecord(
            districtID: response.districtID,
            sessionID: response.sessionID
        )
        do {
            try await containmentStore.save(containmentRecord)
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

    func restorePersistedSession(
        staffIdentity: StudentModeStaffIdentity,
        now: Date = Date()
    ) async throws -> StudentModeStartupResolution {
        guard isValid(identity: staffIdentity) else {
            throw StudentModeRepositoryError.authenticationRequired
        }
        let markerLoad = await containmentStore.load()
        let respondentRecord: StudentModeContainmentRecord?
        do {
            respondentRecord = try await persistedRespondentRecord()
        } catch {
            throw map(error)
        }
        let record: StudentModeContainmentRecord
        switch markerLoad {
        case .missing:
            guard let respondentRecord else {
                return .clear
            }
            record = respondentRecord
        case .record(let storedRecord):
            if let respondentRecord, respondentRecord != storedRecord {
                throw StudentModeRepositoryError.containmentCorrupt
            }
            record = storedRecord
        case .corrupt:
            throw StudentModeRepositoryError.containmentCorrupt
        }
        guard record.isValid,
              record.districtID == staffIdentity.districtID else {
            throw StudentModeRepositoryError.containmentCorrupt
        }
        let response: StudentModeRestoreResponse
        do {
            response = try await restoreSessionTransport(
                StudentModeRestoreRequest(
                    districtID: record.districtID,
                    sessionID: record.sessionID
                )
            )
        } catch {
            throw map(error)
        }
        guard response.sessionID == record.sessionID,
              response.districtID == record.districtID,
              response.recordVersion > 0 else {
            throw StudentModeRepositoryError.invalidResponse
        }
        if response.status.isTerminal {
            return .terminal(record, response.status)
        }
        guard let studentID = response.studentID,
              let assignmentIDs = response.assignmentIDs,
              let allowedOperations = response.allowedOperations,
              let customToken = response.customToken,
              let issuedAt = response.issuedAt,
              let expiresAt = response.expiresAt,
              let profile = response.profile,
              isValidIdentifier(studentID),
              assignmentIDs.count == 1,
              allowedOperations == StudentModeOperation.surveyAssignment,
              !customToken.isEmpty,
              profile.studentID == studentID,
              issuedAt < expiresAt,
              now < expiresAt,
              expiresAt.timeIntervalSince(issuedAt)
                <= StudentModeSession.duration(forRequestedMinutes: 60) else {
            throw StudentModeRepositoryError.invalidResponse
        }
        let scope: StudentModeScope
        do {
            scope = try StudentModeScope(
                districtID: response.districtID,
                studentID: studentID,
                assignmentIDs: assignmentIDs,
                allowedOperations: allowedOperations
            )
            try await containmentStore.save(record)
            try await signInRespondent(customToken)
        } catch let error as StudentModeSessionError {
            _ = error
            throw StudentModeRepositoryError.invalidResponse
        } catch {
            throw map(error)
        }
        return .active(
            StudentModeGrant(
                sessionID: response.sessionID,
                scope: scope,
                recordVersion: response.recordVersion,
                issuedAt: issuedAt,
                expiresAt: expiresAt,
                staffIdentity: staffIdentity
            ),
            profile
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
            try await containmentStore.clear()
        } catch {
            throw StudentModeRepositoryError.authenticationRequired
        }
    }

    func releaseVerifiedTerminalSession(
        _ record: StudentModeContainmentRecord
    ) async throws {
        guard record.isValid else {
            throw StudentModeRepositoryError.containmentCorrupt
        }
        do {
            try await signOutRespondent()
            try await containmentStore.clear()
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
            restoreSession: { request in
                try await runtime.restoreSession(request)
            },
            endSession: { request in
                try await runtime.endSession(request)
            },
            containmentStore: .keychain(),
            persistedRespondentRecord: {
                try await runtime.persistedRespondentRecord()
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

    func restoreSession(
        _ request: StudentModeRestoreRequest
    ) async throws -> StudentModeRestoreResponse {
        do {
            let result = try await functions
                .httpsCallable("restoreStudentModeSession")
                .call(request.payload)
            return try Self.parseRestoreResponse(result.data)
        } catch {
            throw Self.callableError(from: error)
        }
    }

    func persistedRespondentRecord() async throws
        -> StudentModeContainmentRecord? {
        guard let user = respondentAuth.currentUser else {
            return nil
        }
        let token = try await user.getIDTokenResult(forcingRefresh: false)
        guard token.claims["tmiAccessClass"] as? String == "respondent",
              let districtID = token.claims["tmiDistrictID"] as? String,
              let sessionID = token.claims["tmiSessionID"] as? String else {
            throw StudentModeRepositoryError.containmentCorrupt
        }
        let record = StudentModeContainmentRecord(
            districtID: districtID,
            sessionID: sessionID
        )
        guard record.isValid else {
            throw StudentModeRepositoryError.containmentCorrupt
        }
        return record
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

    private static func parseRestoreResponse(
        _ value: Any
    ) throws -> StudentModeRestoreResponse {
        guard let data = value as? [String: Any],
              let statusValue = data["status"] as? String,
              let status = StudentModeServerStatus(rawValue: statusValue),
              let sessionID = data["sessionID"] as? String,
              let districtID = data["districtID"] as? String,
              let recordVersion = Self.integer(data["recordVersion"]) else {
            throw StudentModeCallableError.malformedResponse
        }
        if status.isTerminal {
            return StudentModeRestoreResponse(
                status: status,
                sessionID: sessionID,
                districtID: districtID,
                studentID: nil,
                assignmentIDs: nil,
                allowedOperations: nil,
                customToken: nil,
                recordVersion: recordVersion,
                issuedAt: nil,
                expiresAt: nil,
                profile: nil
            )
        }
        guard let studentID = data["studentID"] as? String,
              let assignmentIDs = data["assignmentIDs"] as? [String],
              let operationValues = data["allowedOperations"] as? [String],
              let customToken = data["customToken"] as? String,
              let issuedAt = Self.date(data["issuedAt"]),
              let expiresAt = Self.date(data["expiresAt"]),
              let profileData = data["profile"] as? [String: Any],
              Self.integer(profileData["schemaVersion"]) == 1,
              profileData["districtID"] as? String == districtID,
              let profileStudentID = profileData["studentID"] as? String,
              profileStudentID == studentID,
              let displayName = profileData["displayName"] as? String,
              let grade = profileData["grade"] as? String else {
            throw StudentModeCallableError.malformedResponse
        }
        let operations = Set(
            operationValues.compactMap(StudentModeOperation.init(rawValue:))
        )
        guard operations.count == operationValues.count else {
            throw StudentModeCallableError.malformedResponse
        }
        return StudentModeRestoreResponse(
            status: status,
            sessionID: sessionID,
            districtID: districtID,
            studentID: studentID,
            assignmentIDs: Set(assignmentIDs),
            allowedOperations: operations,
            customToken: customToken,
            recordVersion: recordVersion,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            profile: StudentModeProfile(
                studentID: profileStudentID,
                displayName: displayName,
                grade: grade,
                pronouns: profileData["pronouns"] as? String
            )
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
