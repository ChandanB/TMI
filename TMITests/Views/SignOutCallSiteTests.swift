import Foundation
import Testing

@Suite("Sign Out Call Sites")
struct SignOutCallSiteTests {
    @Test("AuthStateModel sign-out results cannot be discarded silently")
    func signOutResultIsNotDiscardable() throws {
        let source = try source(at: "TMI/StateModels/AuthStateModel.swift")

        #expect(source.contains("@discardableResult\n  @MainActor\n  func signOut() -> Bool") == false)
    }

    @Test("Every visible AuthStateModel sign-out flow handles failure with retry guidance")
    func everyVisibleSignOutFlowHandlesFailure() throws {
        let paths = [
            "TMI/Views/MainTabView.swift",
            "TMI/Views/Students/StudentMainView.swift",
            "TMI/Views/Settings/SettingsView.swift",
            "TMI/Views/Settings/DeleteAccountView.swift",
        ]

        for path in paths {
            let source = try source(at: path)

            #expect(source.contains("guard authStateModel.signOut() else"), "Missing Bool failure branch in \(path)")
            #expect(source.contains(".alert(\"Couldn’t Sign Out\""), "Missing failure alert in \(path)")
            #expect(source.contains("Button(\"Retry\", action: attemptSignOut)"), "Missing sign-out retry in \(path)")
            #expect(source.contains("Button(\"Cancel\", role: .cancel)"), "Missing cancel action in \(path)")
            #expect(
                source.contains("Your account is still signed in. Check your connection and try again."),
                "Missing standard failure guidance in \(path)"
            )
        }
    }

    @Test("MainTabView clears student context only after successful sign-out")
    func mainTabCleanupIsSuccessOnly() throws {
        let source = try source(at: "TMI/Views/MainTabView.swift")
        let method = try methodSource(named: "attemptSignOut", in: source)
        let signOut = try #require(method.range(of: "guard authStateModel.signOut() else"))
        let cleanup = try #require(method.range(of: "studentContext.clearContext()"))

        #expect(signOut.lowerBound < cleanup.lowerBound)
    }

    @Test("SettingsView mounts the log-out confirmation on its root view")
    func settingsSignOutConfirmationIsReachable() throws {
        let source = try source(at: "TMI/Views/Settings/SettingsView.swift")
        let bodyEnd = try #require(source.range(of: "// MARK: - Role-Specific Sections"))
        let rootViewSource = source[..<bodyEnd.lowerBound]

        #expect(rootViewSource.contains(".alert(\"Log Out\""))
    }

    @Test("DeleteAccountView retries sign-out without deleting the account again")
    func deletionRetryOnlySignsOut() throws {
        let source = try source(at: "TMI/Views/Settings/DeleteAccountView.swift")
        let retryMethod = try methodSource(named: "attemptSignOut", in: source)
        let deletion = try #require(source.range(of: "deleteAccount(password: password)"))
        let deletionCompleted = try #require(source.range(of: "accountDeletionCompleted = true"))
        let firstSignOutAttempt = try #require(source.range(of: "attemptSignOut()", range: deletionCompleted.upperBound..<source.endIndex))

        #expect(deletion.lowerBound < deletionCompleted.lowerBound)
        #expect(deletionCompleted.lowerBound < firstSignOutAttempt.lowerBound)
        #expect(retryMethod.contains("deleteAccount(password: password)") == false)
    }

    @Test("TMIApp uses an explicit self capture for bootstrap access")
    func bootstrapCaptureIsExplicit() throws {
        let source = try source(at: "TMI/App/TMIApp.swift")

        #expect(source.contains("await self.performBootstrap(for: self.accountAccess)"))
    }

    private func source(at relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func methodSource(named name: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: "private func \(name)"))
        let remainder = source[start.lowerBound...]
        let nextMethod = remainder.dropFirst().range(of: "\n    private func ")
        let end = nextMethod?.lowerBound ?? source.endIndex
        return source[start.lowerBound..<end]
    }
}
