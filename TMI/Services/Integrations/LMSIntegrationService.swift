//
//  LMSIntegrationService.swift
//  TMI
//
//  Service scaffolding for LMS providers (Google Classroom, Canvas, etc.)
//

import Foundation

final class LMSIntegrationService: ExternalIntegration {
    enum Provider: String, CaseIterable {
        case googleClassroom
        case canvas
        case schoology
        case microsoftTeams
    }

    let provider: String

    init(provider: Provider) {
        self.provider = provider.rawValue
    }

    func authenticate(credentials: [String: String]) async throws {
        guard !credentials.isEmpty else {
            throw ExternalIntegrationError.notConfigured("Missing credentials for \(provider)")
        }
        // TODO: Implement provider-specific OAuth flow.
        throw ExternalIntegrationError.notConfigured("LMS authentication not implemented for \(provider)")
    }

    func syncStudents(districtId: String) async throws -> RosterSyncResult {
        // LMS sync is typically class-focused; no-op for now.
        return RosterSyncResult(provider: provider)
    }

    func syncStaff(districtId: String) async throws -> RosterSyncResult {
        return RosterSyncResult(provider: provider)
    }

    func syncClasses(districtId: String) async throws -> RosterSyncResult {
        // TODO: Pull classroom rosters and map to cohorts.
        return RosterSyncResult(provider: provider, classesSynced: 0)
    }

    func exportGrades(_ grades: [StudentGrade]) async throws {
        if grades.isEmpty {
            return
        }
        throw ExternalIntegrationError.notConfigured("Grade export not implemented for \(provider)")
    }
}
