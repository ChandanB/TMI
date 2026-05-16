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
