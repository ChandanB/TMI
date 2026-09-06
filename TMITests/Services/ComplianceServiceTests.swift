import Foundation
import Testing
@testable import TMI

@MainActor
@Suite("Compliance session boundary")
struct ComplianceServiceTests {
    @Test("No trusted session cannot read settings or create an audit")
    func missingSession() async {
        let service = ComplianceService(authorizationSessions: Sessions(value: nil), currentUserID: { "staff" })
        await #expect(throws: ComplianceServiceError.notAuthenticated) {
            try await service.fetchSettings(districtId: "d1")
        }
        await #expect(throws: ComplianceServiceError.notAuthenticated) {
            try await service.runComplianceCheck(districtId: "d1")
        }
    }

    @Test("A verified session cannot select a different district path")
    func crossDistrict() async {
        let service = ComplianceService(authorizationSessions: Sessions(value: session(admin: true)), currentUserID: { "staff" })
        await #expect(throws: ComplianceServiceError.permissionDenied) {
            try await service.fetchSettings(districtId: "other")
        }
        await #expect(throws: ComplianceServiceError.permissionDenied) {
            try await service.getAuditResults(districtId: "other", dateRange: nil)
        }
    }

    @Test("Teachers cannot write compliance settings and mismatched settings cannot be redirected")
    func settingsMutationBoundary() async {
        let teacher = ComplianceService(authorizationSessions: Sessions(value: session(admin: false)), currentUserID: { "staff" })
        await #expect(throws: ComplianceServiceError.permissionDenied) {
            try await teacher.updateSettings(districtId: "d1", settings: ComplianceSettings(districtId: "d1"))
        }
        let admin = ComplianceService(authorizationSessions: Sessions(value: session(admin: true)), currentUserID: { "staff" })
        await #expect(throws: ComplianceServiceError.permissionDenied) {
            try await admin.updateSettings(districtId: "d1", settings: ComplianceSettings(districtId: "other"))
        }
    }

    @Test("An authorized audit request cannot manufacture a compliance score")
    func noFabricatedAudit() async {
        let service = ComplianceService(authorizationSessions: Sessions(value: session(admin: true)), currentUserID: { "staff" })
        await #expect(throws: ComplianceServiceError.auditUnavailable) {
            try await service.runComplianceCheck(districtId: "d1")
        }
    }

    private func session(admin: Bool) -> AuthenticatedSession {
        let user = TMIUser(id: "staff", email: "staff@example.com", displayName: "Staff",
            requestedRole: .teacher, profileCreatedDate: .distantPast)
        return AuthenticatedSession(profile: user,
            claim: TrustedTenantClaim(userID: "staff", districtID: "d1", accessClass: .staff, membershipVersion: 1),
            membership: MembershipContext(userID: "staff", districtID: "d1", schoolIDs: ["s1"],
                role: admin ? .districtAdministrator : .teacher, capabilities: [], assignedStudentIDs: [],
                isActive: true, version: 1))
    }
}

private struct Sessions: AuthorizationSessionProviding {
    let value: AuthenticatedSession?
    func session(authenticatedUserID: String?) -> AuthenticatedSession? { value }
}
