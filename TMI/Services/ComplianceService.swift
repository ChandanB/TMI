//
//  ComplianceService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  Service for managing compliance settings and student consent
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ComplianceService {
    static let shared = ComplianceService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Compliance Settings

    /// Fetch compliance settings for a district
    func fetchSettings(districtId: String) async throws -> ComplianceSettings {
        let doc = try await db.collection("districts")
            .document(districtId)
            .collection("settings")
            .document("compliance")
            .getDocument()

        if let settings = try? doc.data(as: ComplianceSettings.self) {
            print("[ComplianceService] ✅ Fetched compliance settings for district")
            return settings
        } else {
            // Return default settings if none exist
            print("[ComplianceService] ⚠️ No settings found, using defaults")
            return ComplianceSettings(districtId: districtId)
        }
    }

    /// Update compliance settings for a district
    func updateSettings(_ settings: ComplianceSettings) async throws {
        var updatedSettings = settings
        updatedSettings.lastUpdated = Date()

        try await db.collection("districts")
            .document(settings.districtId)
            .collection("settings")
            .document("compliance")
            .setData(updatedSettings.toFirestoreData())

        print("[ComplianceService] ✅ Updated compliance settings")

        // Log the change
        try await AuditLogService.shared.log(
            action: .dataRetentionPolicyApplied,
            entityType: .district,
            entityId: settings.districtId,
            metadata: [
                "retentionDays": "\(settings.retentionPolicyDays)",
                "auditRetentionDays": "\(settings.auditRetentionDays)"
            ]
        )
    }

    // MARK: - Student Consent

    /// Fetch all consent records for a student
    func fetchConsents(studentId: String) async throws -> [StudentConsent] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ComplianceService", code: 401)
        }

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("students")
            .document(studentId)
            .collection("consents")
            .getDocuments()

        let consents = snapshot.documents.compactMap { doc -> StudentConsent? in
            try? doc.data(as: StudentConsent.self)
        }

        print("[ComplianceService] 📖 Fetched \(consents.count) consents for student")
        return consents
    }

    /// Grant consent for a student
    func grantConsent(
        studentId: String,
        consentType: StudentConsent.ConsentType,
        grantedBy: String,
        grantedByName: String,
        expirationDays: Int? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ComplianceService", code: 401)
        }

        let expiresAt: Date? = expirationDays.map {
            Date().addingTimeInterval(Double($0 * 86400))
        }

        let consent = StudentConsent(
            studentId: studentId,
            consentType: consentType,
            granted: true,
            grantedBy: grantedBy,
            grantedByName: grantedByName,
            grantedAt: Date(),
            expiresAt: expiresAt
        )

        try await db.collection("users")
            .document(userId)
            .collection("students")
            .document(studentId)
            .collection("consents")
            .document(consentType.rawValue)
            .setData(consent.toFirestoreData())

        print("[ComplianceService] ✅ Granted consent: \(consentType.displayName)")

        // Log the consent grant
        try await AuditLogService.shared.log(
            action: .consentGranted,
            entityType: .student,
            entityId: studentId,
            metadata: [
                "consentType": consentType.rawValue,
                "grantedBy": grantedByName
            ]
        )
    }

    /// Revoke consent for a student
    func revokeConsent(
        studentId: String,
        consentType: StudentConsent.ConsentType
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ComplianceService", code: 401)
        }

        // Update existing consent to revoked
        try await db.collection("users")
            .document(userId)
            .collection("students")
            .document(studentId)
            .collection("consents")
            .document(consentType.rawValue)
            .updateData([
                "granted": false,
                "revokedAt": Timestamp(date: Date())
            ])

        print("[ComplianceService] ❌ Revoked consent: \(consentType.displayName)")

        // Log the consent revocation
        try await AuditLogService.shared.log(
            action: .consentRevoked,
            entityType: .student,
            entityId: studentId,
            metadata: [
                "consentType": consentType.rawValue
            ]
        )
    }

    /// Check if student has active consent for a specific type
    func hasActiveConsent(studentId: String, consentType: StudentConsent.ConsentType) async throws -> Bool {
        let consents = try await fetchConsents(studentId: studentId)

        if let consent = consents.first(where: { $0.consentType == consentType }) {
            return consent.isActive
        }

        return false
    }

    // MARK: - COPPA Compliance

    /// Check if student meets COPPA age requirement
    func meetsCOPPAAgeRequirement(birthDate: Date, settings: ComplianceSettings) -> Bool {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return age >= settings.coppaMinimumAge
    }

    /// Get students requiring parental consent (under COPPA age)
    func getStudentsRequiringConsent(students: [Student], settings: ComplianceSettings) -> [Student] {
        guard settings.coppaEnabled else { return [] }

        return students.filter { student in
            !meetsCOPPAAgeRequirement(birthDate: student.dateOfBirth, settings: settings)
        }
    }

    // MARK: - Data Retention

    /// Apply data retention policy (delete old student data)
    func applyDataRetentionPolicy(districtId: String, settings: ComplianceSettings) async throws -> Int {
        guard settings.dataRetentionEnabled && settings.autoDeleteEnabled else {
            print("[ComplianceService] ⚠️ Data retention not enabled or auto-delete disabled")
            return 0
        }

        let cutoffDate = Date().addingTimeInterval(-Double(settings.retentionPolicyDays * 86400))

        print("[ComplianceService] 🗑️ Applying data retention policy (cutoff: \(cutoffDate.formatted()))")

        // This is a placeholder - in production, you would:
        // 1. Query for students with exitDate < cutoffDate
        // 2. Archive their data
        // 3. Delete the records
        // 4. Log the deletion

        // For now, just return 0 as this is a sensitive operation
        // that should be carefully implemented with backups

        try await AuditLogService.shared.log(
            action: .dataRetentionPolicyApplied,
            entityType: .district,
            entityId: districtId,
            metadata: [
                "retentionDays": "\(settings.retentionPolicyDays)",
                "cutoffDate": cutoffDate.ISO8601Format()
            ]
        )

        return 0
    }

    // MARK: - Consent Summary

    /// Get consent summary for a student
    func getConsentSummary(studentId: String) async throws -> ConsentSummary {
        let consents = try await fetchConsents(studentId: studentId)

        let activeConsents = consents.filter { $0.isActive }
        let expiredConsents = consents.filter { $0.isExpired }
        let revokedConsents = consents.filter { !$0.granted }

        // Check which consent types are missing
        let allTypes = StudentConsent.ConsentType.allCases
        let existingTypes = Set(consents.map { $0.consentType })
        let missingTypes = allTypes.filter { !existingTypes.contains($0) }

        return ConsentSummary(
            totalConsents: consents.count,
            activeConsents: activeConsents.count,
            expiredConsents: expiredConsents.count,
            revokedConsents: revokedConsents.count,
            missingConsentTypes: missingTypes,
            consents: consents
        )
    }
}

// MARK: - Supporting Types

struct ConsentSummary: Codable, Sendable {
    let totalConsents: Int
    let activeConsents: Int
    let expiredConsents: Int
    let revokedConsents: Int
    let missingConsentTypes: [StudentConsent.ConsentType]
    let consents: [StudentConsent]

    var allConsentsActive: Bool {
        totalConsents > 0 && expiredConsents == 0 && revokedConsents == 0
    }

    var hasRequiredConsents: Bool {
        // At minimum, should have general data collection consent
        consents.contains { $0.consentType == .generalDataCollection && $0.isActive }
    }
}
