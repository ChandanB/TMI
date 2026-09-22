#if DEBUG
import Foundation
import Testing
@testable import TMI

@MainActor
private final class FakeDeveloperConsoleRepository: DeveloperConsoleRepository {
    var statusResult: Result<DeveloperConsoleStatus, DeveloperConsoleError> = .success(
        DeveloperConsoleStatus(isEnabled: true, isOperator: true, projectID: "demo-tmi")
    )
    var storedTenants: [DevTenant] = []
    var storedInvitations: [DevInvitation] = []
    var storedMembers: [DevMember] = []
    var failNextMutation: DeveloperConsoleError?
    private(set) var tenantLoads = 0
    private(set) var createdDrafts: [DevInvitationDraft] = []
    private(set) var revokedIDs: [String] = []
    private(set) var savedMemberships: [DevMembershipDraft] = []

    func status() async throws -> DeveloperConsoleStatus { try statusResult.get() }

    func tenants() async throws -> [DevTenant] {
        tenantLoads += 1
        return storedTenants
    }

    func upsertDistrict(districtID: String, name: String, organizationKind: OrganizationKind, programType: ProgramType) async throws {
        try failIfNeeded()
        storedTenants.append(DevTenant(districtID: districtID, name: name, organizationKind: organizationKind, programType: programType, memberCount: 0, schools: []))
    }

    func upsertSchool(districtID: String, schoolID: String, name: String, programType: ProgramType?) async throws {
        try failIfNeeded()
    }

    func invitations(districtID: String?) async throws -> [DevInvitation] {
        storedInvitations.filter { districtID == nil || $0.districtID == districtID }
    }

    func createInvitation(_ draft: DevInvitationDraft) async throws -> DevCreatedInvitation {
        try failIfNeeded()
        createdDrafts.append(draft)
        storedInvitations.append(Self.invitation(id: "id-\(createdDrafts.count)", districtID: draft.districtID, status: .active))
        return DevCreatedInvitation(invitationID: "id-\(createdDrafts.count)", invitationCode: "code", expiresAt: "2026-10-01T00:00:00.000Z")
    }

    func revokeInvitation(invitationID: String) async throws {
        try failIfNeeded()
        revokedIDs.append(invitationID)
    }

    func deleteInvitation(invitationID: String) async throws {
        try failIfNeeded()
        storedInvitations.removeAll { $0.invitationID == invitationID }
    }

    func members(districtID: String) async throws -> [DevMember] { storedMembers }

    func upsertMembership(_ draft: DevMembershipDraft) async throws -> Int {
        try failIfNeeded()
        savedMemberships.append(draft)
        return 2
    }

    private func failIfNeeded() throws {
        if let error = failNextMutation {
            failNextMutation = nil
            throw error
        }
    }

    static func invitation(id: String, districtID: String, status: DevInvitationStatus) -> DevInvitation {
        DevInvitation(invitationID: id, districtID: districtID, role: .teacher, schoolIDs: ["s1"], capabilities: [.studentReadDetail], label: nil, status: status, createdAt: nil, createdBy: nil, expiresAt: nil, consumedAt: nil, consumedByUserID: nil, revokedAt: nil)
    }
}

@Suite("Developer Mode state")
@MainActor
struct DeveloperModeStateTests {
    @Test("Operators load tenants; non-operators do not")
    func loadRespectsOperatorStatus() async {
        let repository = FakeDeveloperConsoleRepository()
        repository.storedTenants = [DevTenant(districtID: "d1", name: "One", organizationKind: .schoolDistrict, programType: .k12, memberCount: 1, schools: [])]
        let state = DeveloperModeState(repository: repository)
        await state.load()
        #expect(state.phase == .ready)
        #expect(state.isOperator)
        #expect(state.tenants.map(\.districtID) == ["d1"])

        let outsider = FakeDeveloperConsoleRepository()
        outsider.statusResult = .success(DeveloperConsoleStatus(isEnabled: true, isOperator: false, projectID: "demo-tmi"))
        let outsiderState = DeveloperModeState(repository: outsider)
        await outsiderState.load()
        #expect(!outsiderState.isOperator)
        #expect(outsider.tenantLoads == 0)
    }

    @Test("Status failures surface as a failed phase")
    func statusFailure() async {
        let repository = FakeDeveloperConsoleRepository()
        repository.statusResult = .failure(.notDeployed)
        let state = DeveloperModeState(repository: repository)
        await state.load()
        #expect(state.phase == .failed(.notDeployed))
    }

    @Test("Creating an invitation keeps the one-time code and reloads the list")
    func createInvitation() async {
        let repository = FakeDeveloperConsoleRepository()
        let state = DeveloperModeState(repository: repository)
        let draft = DevInvitationDraft.defaults(districtID: "d1", schoolIDs: ["s1"])
        let created = await state.createInvitation(draft, filter: "d1")
        #expect(created)
        #expect(state.createdInvitation?.invitationCode == "code")
        #expect(state.invitations.count == 1)
        #expect(repository.createdDrafts.first?.capabilities == [.studentReadDetail, .studentWriteDetail])
    }

    @Test("A rejected mutation reports an error and leaves data unchanged")
    func rejectedMutation() async {
        let repository = FakeDeveloperConsoleRepository()
        repository.storedInvitations = [FakeDeveloperConsoleRepository.invitation(id: "a", districtID: "d1", status: .active)]
        let state = DeveloperModeState(repository: repository)
        await state.loadInvitations(districtID: nil)
        repository.failNextMutation = .rejected("A consumed invitation cannot be revoked.")
        await state.revoke(state.invitations[0], filter: nil)
        #expect(state.actionError == .rejected("A consumed invitation cannot be revoked."))
        #expect(repository.revokedIDs.isEmpty)
        #expect(state.invitations.count == 1)
    }

    @Test("Invitation status actions follow the server lifecycle")
    func statusActions() {
        #expect(DevInvitationStatus.active.canRevoke)
        #expect(!DevInvitationStatus.active.canDelete)
        #expect(!DevInvitationStatus.consumed.canRevoke)
        #expect(!DevInvitationStatus.consumed.canDelete)
        #expect(DevInvitationStatus.revoked.canDelete)
        #expect(DevInvitationStatus.expired.canDelete)
    }

    @Test("Role defaults mirror the server capability sets")
    func roleDefaults() {
        #expect(DeveloperConsoleDefaults.capabilities(for: .socialWorker) == [.studentReadDetail])
        #expect(!DeveloperConsoleDefaults.capabilities(for: .districtAdministrator).contains(.studentRestrictedWrite))
        #expect(DeveloperConsoleDefaults.capabilities(for: .schoolAdministrator).contains(.staffManage))
    }

    @Test("Identifiers are slugged from display names")
    func slugs() {
        #expect(DeveloperIdentifier.slug(from: "Sunshine Early Learning Center") == "sunshine-early-learning-center")
        #expect(DeveloperIdentifier.slug(from: "  Café Niños #2 ") == "cafe-ninos-2")
        #expect(DeveloperIdentifier.isValid("riverside-usd"))
        #expect(!DeveloperIdentifier.isValid("bad/id"))
        #expect(!DeveloperIdentifier.isValid(""))
    }

    @Test("Program type resolves site override before organization default")
    func programResolution() {
        #expect(ProgramType.resolve(site: nil, organization: .earlyChildhood) == .earlyChildhood)
        #expect(ProgramType.resolve(site: .k12, organization: .earlyChildhood) == .k12)
        #expect(ProgramType.resolve(site: nil, organization: nil) == .k12)
    }

    @Test("Server errors map to actionable console errors")
    func errorMapping() {
        #expect(DeveloperConsoleError.map(URLError(.notConnectedToInternet)) == .unavailable)
        #expect(DeveloperConsoleError.map(DeveloperConsoleError.notOperator) == .notOperator)
    }
}
#endif
