//
//  RetentionPolicyService.swift
//  TMI
//
//  Applies district data retention policies to student records
//

import Foundation
import FirebaseFirestore

final class RetentionPolicyService {
    static let shared = RetentionPolicyService()

    private let db = Firestore.firestore()
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
        guard let policy = try await loadPolicy(districtId: districtId) else {
            throw RetentionPolicyError.missingPolicy(districtId)
        }

        guard policy.retentionDays > 0 else {
            return RetentionPolicyResult(
                districtId: districtId,
                evaluatedCount: 0,
                anonymizedCount: 0,
                deletedCount: 0,
                executedAt: Date()
            )
        }

        let cutoff = Date().addingTimeInterval(-Double(policy.retentionDays * 86400))

        let snapshot = try await db.collection("students")
            .whereField("districtId", isEqualTo: districtId)
            .getDocuments()

        var anonymizedCount = 0
        var deletedCount = 0

        for document in snapshot.documents {
            let data = document.data()
            guard let lastActivity = extractDate(from: data["lastInteractionDate"])
                    ?? extractDate(from: data["updatedAt"])
                    ?? extractDate(from: data["createdAt"]) else {
                continue
            }

            guard lastActivity < cutoff else { continue }

            if policy.autoDelete {
                try await document.reference.delete()
                deletedCount += 1
            } else if policy.anonymizeAfterRetention {
                try await anonymizeStudent(document: document)
                anonymizedCount += 1
            }
        }

        return RetentionPolicyResult(
            districtId: districtId,
            evaluatedCount: snapshot.documents.count,
            anonymizedCount: anonymizedCount,
            deletedCount: deletedCount,
            executedAt: Date()
        )
    }

    private func anonymizeStudent(document: QueryDocumentSnapshot) async throws {
        var updates: [String: Any] = [
            "name": "Anonymized Student",
            "dateOfBirth": Date(timeIntervalSince1970: 0).timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970,
            "isAnonymized": true
        ]

        updates["studentID"] = FieldValue.delete()
        updates["photoURL"] = FieldValue.delete()
        updates["surveyResults"] = FieldValue.delete()
        updates["notes"] = FieldValue.delete()

        try await document.reference.updateData(updates)
    }

    private func extractDate(from raw: Any?) -> Date? {
        if let timestamp = raw as? Timestamp {
            return timestamp.dateValue()
        }
        if let seconds = raw as? Double {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

enum RetentionPolicyError: LocalizedError {
    case missingPolicy(String)

    var errorDescription: String? {
        switch self {
        case .missingPolicy(let districtId):
            return "No retention policy configured for district \(districtId)"
        }
    }
}
