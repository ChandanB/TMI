//
//  ExternalIntegration.swift
//  TMI
//
//  Shared protocol for external SIS/LMS integrations
//

import Foundation

protocol ExternalIntegration {
    var provider: String { get }

    func authenticate(credentials: [String: String]) async throws
    func syncStudents(districtId: String) async throws -> RosterSyncResult
    func syncStaff(districtId: String) async throws -> RosterSyncResult
    func syncClasses(districtId: String) async throws -> RosterSyncResult
    func exportGrades(_ grades: [StudentGrade]) async throws
}

enum ExternalIntegrationError: LocalizedError {
    case notConfigured(String)
    case authenticationFailed(String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return "Integration not configured: \(message)"
        case .authenticationFailed(let message):
            return "Integration authentication failed: \(message)"
        case .syncFailed(let message):
            return "Integration sync failed: \(message)"
        }
    }
}
