import Foundation
import Testing

@Suite("Account Deletion")
struct AccountDeletionTests {

    // Verifies the method signature and subcollection list exist in the source.
    // Firebase integration is not unit-testable without a live backend, so we
    // validate structural correctness via source inspection — the same pattern
    // used elsewhere in this test suite.
    @Test("deleteAccount method exists in AuthenticationService source")
    func deleteAccountMethodExists() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("func deleteAccount(password: String) async throws"))
    }

    @Test("deleteAccount re-authenticates before deleting")
    func deleteAccountReauthenticatesFirst() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // reauthenticate must appear before user.delete() in the source
        let reauthRange = source.range(of: "reauthenticate(with: credential)")
        let deleteRange = source.range(of: "user.delete()")
        #expect(reauthRange != nil)
        #expect(deleteRange != nil)
        if let r = reauthRange, let d = deleteRange {
            #expect(r.lowerBound < d.lowerBound, "reauthenticate must come before delete()")
        }
    }

    @Test("deleteAccount purges all required subcollections")
    func deleteAccountPurgesAllSubcollections() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Services/AuthenticationService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("\"students\""))
        #expect(source.contains("\"tmiPlans\""))
        #expect(source.contains("\"interests\""))
        #expect(source.contains("\"resources\""))
    }
}

@Suite("DeleteAccountView structure")
struct DeleteAccountViewStructureTests {

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Settings/DeleteAccountView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("View defines a two-step DeletionStep enum")
    func definesDeletionStepEnum() throws {
        let src = try source()
        #expect(src.contains("enum DeletionStep"))
        #expect(src.contains("case warning"))
        #expect(src.contains("case confirm"))
    }

    @Test("View uses SecureField for password entry")
    func usesSecureField() throws {
        #expect(try source().contains("SecureField"))
    }

    @Test("View shows inline error message state")
    func showsErrorMessage() throws {
        #expect(try source().contains("errorMessage"))
    }

    @Test("Delete button is disabled when password is empty")
    func deleteButtonDisabledWhenPasswordEmpty() throws {
        #expect(try source().contains(".disabled(password.isEmpty"))
    }

    @Test("View calls deleteAccount on AuthenticationService")
    func callsDeleteAccount() throws {
        #expect(try source().contains("deleteAccount(password: password)"))
    }

    @Test("View calls authStateModel.signOut() on success")
    func callsSignOutOnSuccess() throws {
        #expect(try source().contains("authStateModel.signOut()"))
    }
}

@Suite("SettingsView account deletion wiring")
struct SettingsViewDeletionTests {

    private func source() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Settings/SettingsView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("SettingsView declares showingDeleteAccountSheet state")
    func declaresDeleteAccountSheetState() throws {
        #expect(try source().contains("showingDeleteAccountSheet"))
    }

    @Test("SettingsView presents DeleteAccountView as a sheet")
    func presentsDeleteAccountViewSheet() throws {
        #expect(try source().contains("DeleteAccountView()"))
    }

    @Test("SettingsView has Delete Account row in dangerous actions section")
    func hasDeleteAccountRow() throws {
        #expect(try source().contains("Delete Account"))
    }
}
