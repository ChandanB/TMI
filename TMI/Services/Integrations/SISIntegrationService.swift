//
//  SISIntegrationService.swift
//  TMI
//
//  Service scaffolding for SIS providers (Clever, ClassLink, PowerSchool, etc.)
//

import Foundation

final class SISIntegrationService: ExternalIntegration {
    enum Provider: String, CaseIterable {
        case powerschool
        case infiniteCampus
        case aspen
        case skyward
        case clever
        case classlink
    }

    let provider: String

    init(provider: Provider) {
        self.provider = provider.rawValue
    }

    func authenticate(credentials: [String: String]) async throws {
        guard !credentials.isEmpty else {
            throw ExternalIntegrationError.notConfigured("Missing credentials for \(provider)")
        }
        // TODO: Implement provider-specific OAuth/SAML exchange in Cloud Functions.
        throw ExternalIntegrationError.notConfigured("SIS authentication not implemented for \(provider)")
    }

    func syncStudents(districtId: String) async throws -> RosterSyncResult {
        // TODO: Implement roster pull and reconciliation.
        return RosterSyncResult(provider: provider, studentsAdded: 0, studentsUpdated: 0, studentsArchived: 0)
    }

    func syncStaff(districtId: String) async throws -> RosterSyncResult {
        // TODO: Implement staff sync.
        return RosterSyncResult(provider: provider, staffAdded: 0, staffUpdated: 0, staffArchived: 0)
    }

    func syncClasses(districtId: String) async throws -> RosterSyncResult {
        // TODO: Implement class sync.
        return RosterSyncResult(provider: provider, classesSynced: 0)
    }

    func exportGrades(_ grades: [StudentGrade]) async throws {
        // TODO: Implement grade export to SIS.
        if grades.isEmpty {
            return
        }
        throw ExternalIntegrationError.notConfigured("Grade export not implemented for \(provider)")
    }
}
