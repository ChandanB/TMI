#if DEBUG
import Foundation
import Observation

/// Shared state for the DEBUG-only developer console. Every mutation reloads
/// the affected list from the server, so the UI never shows an unconfirmed
/// change.
@Observable
@MainActor
final class DeveloperModeState {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(DeveloperConsoleError)
    }

    private let repository: any DeveloperConsoleRepository

    private(set) var phase: Phase = .idle
    private(set) var status: DeveloperConsoleStatus?
    private(set) var tenants: [DevTenant] = []
    private(set) var invitations: [DevInvitation] = []
    private(set) var members: [DevMember] = []
    private(set) var isWorking = false
    var actionError: DeveloperConsoleError?
    var createdInvitation: DevCreatedInvitation?

    init(repository: any DeveloperConsoleRepository) {
        self.repository = repository
    }

    var isOperator: Bool { status?.isOperator == true }

    func tenant(_ districtID: String) -> DevTenant? {
        tenants.first { $0.districtID == districtID }
    }

    func schoolName(_ schoolID: String, in districtID: String) -> String {
        tenant(districtID)?.schools.first { $0.schoolID == schoolID }?.name ?? schoolID
    }

    // MARK: Loading

    func load() async {
        phase = .loading
        do {
            let status = try await repository.status()
            self.status = status
            if status.isOperator {
                tenants = try await repository.tenants()
            }
            phase = .ready
        } catch {
            phase = .failed(DeveloperConsoleError.map(error))
        }
    }

    func reloadTenants() async {
        await perform { self.tenants = try await self.repository.tenants() }
    }

    func loadInvitations(districtID: String?) async {
        await perform {
            self.invitations = try await self.repository.invitations(districtID: districtID)
        }
    }

    func loadMembers(districtID: String) async {
        await perform {
            self.members = try await self.repository.members(districtID: districtID)
        }
    }

    // MARK: Tenants

    @discardableResult
    func saveDistrict(
        districtID: String,
        name: String,
        organizationKind: OrganizationKind,
        programType: ProgramType
    ) async -> Bool {
        await perform {
            try await self.repository.upsertDistrict(
                districtID: districtID,
                name: name,
                organizationKind: organizationKind,
                programType: programType
            )
            self.tenants = try await self.repository.tenants()
        }
    }

    @discardableResult
    func saveSchool(
        districtID: String,
        schoolID: String,
        name: String,
        programType: ProgramType?
    ) async -> Bool {
        await perform {
            try await self.repository.upsertSchool(
                districtID: districtID,
                schoolID: schoolID,
                name: name,
                programType: programType
            )
            self.tenants = try await self.repository.tenants()
        }
    }

    // MARK: Invitations

    @discardableResult
    func createInvitation(_ draft: DevInvitationDraft, filter: String?) async -> Bool {
        await perform {
            self.createdInvitation = try await self.repository.createInvitation(draft)
            self.invitations = try await self.repository.invitations(districtID: filter)
        }
    }

    func revoke(_ invitation: DevInvitation, filter: String?) async {
        await perform {
            try await self.repository.revokeInvitation(invitationID: invitation.invitationID)
            self.invitations = try await self.repository.invitations(districtID: filter)
        }
    }

    func delete(_ invitation: DevInvitation, filter: String?) async {
        await perform {
            try await self.repository.deleteInvitation(invitationID: invitation.invitationID)
            self.invitations = try await self.repository.invitations(districtID: filter)
        }
    }

    // MARK: Members

    @discardableResult
    func saveMembership(_ draft: DevMembershipDraft) async -> Bool {
        await perform {
            _ = try await self.repository.upsertMembership(draft)
            self.members = try await self.repository.members(districtID: draft.districtID)
        }
    }

    // MARK: -

    @discardableResult
    private func perform(_ work: @MainActor () async throws -> Void) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            actionError = nil
            return true
        } catch {
            actionError = DeveloperConsoleError.map(error)
            return false
        }
    }
}

/// Turns a display name into a Firestore-safe identifier suggestion.
nonisolated enum DeveloperIdentifier {
    static func slug(from name: String) -> String {
        let lowered = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        var result = ""
        var lastWasDash = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash, !result.isEmpty {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return String(result.prefix(64))
    }

    static func isValid(_ identifier: String) -> Bool {
        !identifier.isEmpty
            && identifier.count <= 128
            && identifier.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil
    }
}
#endif
