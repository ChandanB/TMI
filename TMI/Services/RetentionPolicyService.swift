//
//  RetentionPolicyService.swift
//  TMI
//
//  Applies district data retention policies to student records
//

import Foundation

final class RetentionPolicyService {
    static let shared = RetentionPolicyService()

    private let complianceService = ComplianceService.shared

    private init() {}

    func loadPolicy(districtId: String) async throws -> RetentionPolicy? {
        guard let settings = try await complianceService.fetchSettings(districtId: districtId) else {
            return nil
        }

        return RetentionPolicy(
            districtId: districtId,
            retentionDays: settings.retentionPolicyDays,
            autoDelete: settings.autoDeleteEnabled,
            anonymizeAfterRetention: settings.dataRetentionEnabled && !settings.autoDeleteEnabled
        )
    }

    func applyRetentionPolicy(districtId: String) async throws -> RetentionPolicyResult {
        guard try await loadPolicy(districtId: districtId) != nil else {
            throw RetentionPolicyError.missingPolicy(districtId)
        }
        // Student records are institution-owned and canonical roster mutations
        // are server-authoritative. A background client must never hard-delete
        // or anonymize them from a legacy collection.
        throw RetentionPolicyError.serverOwnedOperation
    }
}

enum RetentionPolicyError: LocalizedError {
    case missingPolicy(String)
    case serverOwnedOperation

    var errorDescription: String? {
        switch self {
        case .missingPolicy(let districtId):
            return "No retention policy configured for district \(districtId)"
        case .serverOwnedOperation:
            return "Retention changes must be run by the district retention workflow."
        }
    }
}
