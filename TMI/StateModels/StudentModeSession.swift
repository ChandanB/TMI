//
//  StudentModeSession.swift
//  TMI
//
//  Manages secure student-only mode sessions
//

import SwiftUI
import LocalAuthentication

@Observable
class StudentModeSession {
    // MARK: - Published Properties

    /// Currently active student in student mode (nil = staff mode)
    var activeStudent: Student?

    /// Whether student mode is currently active
    var isStudentModeActive: Bool {
        activeStudent != nil
    }

    /// Session start time for timeout tracking
    private(set) var sessionStartTime: Date?

    /// Last activity time for auto-logout
    private(set) var lastActivityTime: Date?

    // MARK: - Configuration

    /// Session timeout in seconds (30 minutes)
    private let sessionTimeout: TimeInterval = 1800

    /// Whether to require biometric authentication to exit
    var requiresBiometricExit: Bool = true

    // MARK: - Session Management

    /// Start a student mode session for the given student
    func startStudentMode(for student: Student) {
        print("[StudentMode] 🎓 Starting student mode for: \(student.name)")

        activeStudent = student
        sessionStartTime = Date()
        lastActivityTime = Date()

        // Post notification for analytics
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentModeStarted"),
            object: nil,
            userInfo: ["studentId": student.id ?? "unknown"]
        )

        TMIHaptics.success()
    }

    /// Update last activity time (prevents timeout)
    func updateActivity() {
        lastActivityTime = Date()
    }

    /// Check if session has timed out
    func hasSessionTimedOut() -> Bool {
        guard let lastActivity = lastActivityTime else { return false }
        return Date().timeIntervalSince(lastActivity) > sessionTimeout
    }

    /// Exit student mode (with optional biometric authentication)
    func exitStudentMode() async -> Bool {
        guard isStudentModeActive else {
            return true
        }

        if requiresBiometricExit {
            let success = await authenticateStaff()
            if success {
                performExit()
            }
            return success
        } else {
            performExit()
            return true
        }
    }

    /// Exit student mode due to timeout
    func forceExitDueToTimeout() {
        print("[StudentMode] ⏰ Session timed out")
        performExit()
    }

    // MARK: - Private Helpers

    private func performExit() {
        guard let student = activeStudent else { return }

        print("[StudentMode] 👋 Exiting student mode for: \(student.name)")

        // Calculate session duration
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Post notification for analytics
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentModeEnded"),
            object: nil,
            userInfo: [
                "studentId": student.id ?? "unknown",
                "duration": duration
            ]
        )

        // Clear session
        activeStudent = nil
        sessionStartTime = nil
        lastActivityTime = nil

        TMIHaptics.lightImpact()
    }

    // MARK: - Biometric Authentication

    private func authenticateStaff() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("[StudentMode] ⚠️ Biometric auth not available: \(error?.localizedDescription ?? "Unknown error")")
            // Fall back to device passcode
            return await authenticateWithPasscode()
        }

        // Perform biometric authentication
        let reason = "Authenticate to exit student mode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                print("[StudentMode] ✅ Staff authenticated successfully")
                TMIHaptics.success()
            }
            return success
        } catch {
            print("[StudentMode] ❌ Authentication failed: \(error.localizedDescription)")
            TMIHaptics.error()
            return false
        }
    }

    private func authenticateWithPasscode() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if device passcode is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("[StudentMode] ⚠️ Passcode auth not available: \(error?.localizedDescription ?? "Unknown error")")
            // If no authentication available, allow exit
            return true
        }

        // Perform passcode authentication
        let reason = "Enter device passcode to exit student mode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                print("[StudentMode] ✅ Staff authenticated with passcode")
                TMIHaptics.success()
            }
            return success
        } catch {
            print("[StudentMode] ❌ Passcode authentication failed: \(error.localizedDescription)")
            TMIHaptics.error()
            return false
        }
    }
}

// MARK: - Environment Key

private struct StudentModeSessionKey: EnvironmentKey {
    static let defaultValue = StudentModeSession()
}

extension EnvironmentValues {
    var studentModeSession: StudentModeSession {
        get { self[StudentModeSessionKey.self] }
        set { self[StudentModeSessionKey.self] = newValue }
    }
}
