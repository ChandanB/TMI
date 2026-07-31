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

nonisolated struct StudentModeGrant: Sendable, Equatable {
    let sessionID: String
    let scope: StudentModeScope
    let respondentToken: String
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

@Observable
@MainActor
final class StudentModeSession {
    nonisolated static let defaultDurationMinutes = 30
    nonisolated static let maximumDurationMinutes = 60
    nonisolated static let inactivityInterval: TimeInterval = 5 * 60
    nonisolated static let protectedBackgroundInterval: TimeInterval = 30
    nonisolated static let maximumFailedExitAttempts = 5

    private(set) var state: StudentModeState = .inactive
    private(set) var lastActivityAt: Date?
    private(set) var backgroundedAt: Date?
    private(set) var failedExitAttemptCount = 0
    private(set) var activeStudent: Student?

    var isStudentModeActive: Bool {
        state.isActive
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
        student: Student? = nil,
        at now: Date = Date()
    ) {
        guard grant.staffIdentity.districtID == grant.scope.districtID,
              grant.issuedAt < grant.expiresAt,
              now < grant.expiresAt else {
            secureReset(to: .expired)
            return
        }
        state = .active(grant)
        activeStudent = student
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

    func secureExit() {
        secureReset(to: .inactive)
    }

    func hasSessionTimedOut() -> Bool {
        evaluate(at: Date())
        return !state.isActive
    }

    func exitStudentMode() async -> Bool {
        guard state != .inactive else {
            return true
        }
        let authenticated = await authenticateStaff()
        if authenticated {
            secureExit()
        } else {
            recordFailedExitAttempt()
        }
        return authenticated
    }

    func forceExitDueToTimeout() {
        secureReset(to: .expired)
    }

    private func evaluateActiveGrant(at now: Date) -> StudentModeGrant? {
        guard case .active(let grant) = state else {
            return nil
        }
        if now >= grant.expiresAt {
            secureReset(to: .expired)
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
        activeStudent = nil
        backgroundedAt = nil
    }

    private func secureReset(to nextState: StudentModeState) {
        state = nextState
        activeStudent = nil
        lastActivityAt = nil
        backgroundedAt = nil
        failedExitAttemptCount = 0
    }

    private func authenticateStaff() async -> Bool {
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
