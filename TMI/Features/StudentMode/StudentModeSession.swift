import Foundation
import LocalAuthentication
import Observation
import SwiftUI

nonisolated enum StudentModeOperation: String, Codable, CaseIterable, Sendable {
    case readStudentSafeProfile
    case readAssignment
    case readCareerCatalog
    case readStudentVisiblePlan
    case writeDraft
    case submitAssignment
    case updateInterests
    case writeReflection
    case writeCheckIn
    case updateCareerState
    case requestHelp

    static let surveyAssignment: Set<StudentModeOperation> = [
        .readStudentSafeProfile,
        .readAssignment,
        .writeDraft,
        .submitAssignment,
        .requestHelp,
    ]
}

nonisolated enum StudentModeSessionError: Error, Equatable {
    case invalidScope
}

nonisolated struct StudentModeScope: Codable, Hashable, Sendable {
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let allowedOperations: Set<StudentModeOperation>

    init(
        districtID: String,
        studentID: String,
        assignmentIDs: Set<String>,
        allowedOperations: Set<StudentModeOperation>
    ) throws {
        guard Self.isValidIdentifier(districtID),
              Self.isValidIdentifier(studentID),
              assignmentIDs.count == 1,
              assignmentIDs.allSatisfy(Self.isValidIdentifier),
              !allowedOperations.isEmpty else {
            throw StudentModeSessionError.invalidScope
        }
        self.districtID = districtID
        self.studentID = studentID
        self.assignmentIDs = assignmentIDs
        self.allowedOperations = allowedOperations
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

nonisolated struct StudentModeStaffIdentity: Codable, Hashable, Sendable {
    let userID: String
    let districtID: String
    let membershipVersion: Int
}

nonisolated struct StudentModeProfile: Codable, Hashable, Sendable {
    let studentID: String
    let displayName: String
    let grade: String
    let pronouns: String?

    var firstName: String {
        displayName.split(whereSeparator: \.isWhitespace).first.map(String.init)
            ?? displayName
    }

    var initials: String {
        let value = displayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "?" : value
    }
}

nonisolated struct StudentModeGrant: Sendable, Equatable {
    let sessionID: String
    let scope: StudentModeScope
    let recordVersion: Int
    let issuedAt: Date
    let expiresAt: Date
    let staffIdentity: StudentModeStaffIdentity
}

nonisolated enum StudentModeLockReason: Sendable, Equatable {
    case inactivity
    case backgroundProtection
    case failedExitAttempts
    case assignmentRevoked
}

nonisolated enum StudentModeState: Sendable, Equatable {
    case inactive
    case active(StudentModeGrant)
    case locked(StudentModeLockReason)
    case expired

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var isExpired: Bool {
        self == .expired
    }
}

nonisolated enum StudentModeRootPresentation: Sendable, Equatable {
    case staff
    case student(StudentModeProfile)
}

@Observable
@MainActor
final class StudentModeSession {
    typealias AuthenticateStaff = @MainActor @Sendable () async -> Bool
    typealias SecurelyEndRespondentSession =
        @MainActor @Sendable (StudentModeGrant) async throws -> Void

    nonisolated static let defaultDurationMinutes = 30
    nonisolated static let maximumDurationMinutes = 60
    nonisolated static let inactivityInterval: TimeInterval = 5 * 60
    nonisolated static let protectedBackgroundInterval: TimeInterval = 30
    nonisolated static let maximumFailedExitAttempts = 5

    private(set) var state: StudentModeState = .inactive
    private(set) var lastActivityAt: Date?
    private(set) var backgroundedAt: Date?
    private(set) var failedExitAttemptCount = 0
    private(set) var studentProfile: StudentModeProfile?
    private(set) var currentGrant: StudentModeGrant?
    private var authenticateStaffAction: AuthenticateStaff
    private var securelyEndRespondentSession: SecurelyEndRespondentSession

    var isStudentModeActive: Bool {
        state.isActive
    }

    var isStudentModeContained: Bool {
        state != .inactive && currentGrant != nil && studentProfile != nil
    }

    var rootPresentation: StudentModeRootPresentation {
        if isStudentModeContained, let studentProfile {
            return .student(studentProfile)
        }
        return .staff
    }

    init(
        authenticateStaff: @escaping AuthenticateStaff = {
            await StudentModeSession.authenticateDeviceOwner()
        },
        securelyEndRespondentSession: @escaping SecurelyEndRespondentSession = { _ in
            throw StudentModeRepositoryError.unavailable
        }
    ) {
        authenticateStaffAction = authenticateStaff
        self.securelyEndRespondentSession = securelyEndRespondentSession
    }

    func configureSecureExit(repository: StudentModeRepository) {
        securelyEndRespondentSession = { grant in
            try await repository.endSession(
                sessionID: grant.sessionID,
                staffIdentity: grant.staffIdentity,
                expectedRecordVersion: grant.recordVersion,
                disposition: .ended,
                idempotencyKey: UUID().uuidString,
                reasonCode: "secure-exit"
            )
        }
    }

    nonisolated static func duration(
        forRequestedMinutes requestedMinutes: Int?
    ) -> TimeInterval {
        let minutes = min(
            max(requestedMinutes ?? defaultDurationMinutes, 1),
            maximumDurationMinutes
        )
        return TimeInterval(minutes * 60)
    }

    func activate(
        _ grant: StudentModeGrant,
        profile: StudentModeProfile? = nil,
        at now: Date = Date()
    ) {
        guard grant.staffIdentity.districtID == grant.scope.districtID,
              grant.issuedAt < grant.expiresAt,
              now < grant.expiresAt else {
            secureReset(to: .expired)
            return
        }
        state = .active(grant)
        currentGrant = grant
        studentProfile = profile ?? StudentModeProfile(
            studentID: grant.scope.studentID,
            displayName: "Student",
            grade: "",
            pronouns: nil
        )
        lastActivityAt = now
        backgroundedAt = nil
        failedExitAttemptCount = 0
    }

    func recordActivity(at now: Date = Date()) {
        guard evaluateActiveGrant(at: now) != nil else {
            return
        }
        lastActivityAt = now
    }

    func updateActivity() {
        recordActivity()
    }

    func evaluate(at now: Date = Date()) {
        _ = evaluateActiveGrant(at: now)
    }

    func enterBackground(at now: Date = Date()) {
        guard evaluateActiveGrant(at: now) != nil else {
            return
        }
        backgroundedAt = now
    }

    func returnToForeground(at now: Date = Date()) {
        guard evaluateActiveGrant(at: now) != nil,
              let backgroundedAt else {
            return
        }
        if now.timeIntervalSince(backgroundedAt) >= Self.protectedBackgroundInterval {
            lock(.backgroundProtection)
        } else {
            self.backgroundedAt = nil
        }
    }

    func recordFailedExitAttempt(at now: Date = Date()) {
        guard evaluateActiveGrant(at: now) != nil else {
            return
        }
        failedExitAttemptCount += 1
        if failedExitAttemptCount >= Self.maximumFailedExitAttempts {
            lock(.failedExitAttempts)
        }
    }

    func revokeAssignment(_ assignmentID: String, at now: Date = Date()) {
        guard let grant = evaluateActiveGrant(at: now),
              grant.scope.assignmentIDs.contains(assignmentID) else {
            return
        }
        lock(.assignmentRevoked)
    }

    func hasSessionTimedOut() -> Bool {
        evaluate(at: Date())
        return !state.isActive
    }

    func exitStudentMode() async -> Bool {
        guard state != .inactive, let currentGrant else {
            return true
        }
        let authenticated = await authenticateStaffAction()
        guard authenticated else {
            recordFailedExitAttempt()
            return false
        }
        do {
            try await securelyEndRespondentSession(currentGrant)
            secureReset(to: .inactive)
            return true
        } catch {
            return false
        }
    }

    func forceExitDueToTimeout() {
        expire()
    }

    func handleSceneTransition(
        from _: ScenePhase,
        to newPhase: ScenePhase,
        at now: Date = Date()
    ) {
        if newPhase == .background {
            enterBackground(at: now)
        } else if newPhase == .active, backgroundedAt != nil {
            returnToForeground(at: now)
        }
    }

    private func evaluateActiveGrant(at now: Date) -> StudentModeGrant? {
        guard case .active(let grant) = state else {
            return nil
        }
        if now >= grant.expiresAt {
            expire()
            return nil
        }
        if let lastActivityAt,
           now.timeIntervalSince(lastActivityAt) >= Self.inactivityInterval {
            lock(.inactivity)
            return nil
        }
        return grant
    }

    private func lock(_ reason: StudentModeLockReason) {
        state = .locked(reason)
        backgroundedAt = nil
    }

    private func expire() {
        guard currentGrant != nil else {
            secureReset(to: .inactive)
            return
        }
        state = .expired
        backgroundedAt = nil
    }

    private func secureReset(to nextState: StudentModeState) {
        state = nextState
        currentGrant = nil
        studentProfile = nil
        lastActivityAt = nil
        backgroundedAt = nil
        failedExitAttemptCount = 0
    }

    private static func authenticateDeviceOwner() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to exit Student Mode"
            )
        } catch {
            return false
        }
    }
}

private struct StudentModeSessionKey: EnvironmentKey {
    @MainActor static let defaultValue = StudentModeSession()
}

extension EnvironmentValues {
    var studentModeSession: StudentModeSession {
        get { self[StudentModeSessionKey.self] }
        set { self[StudentModeSessionKey.self] = newValue }
    }
}
