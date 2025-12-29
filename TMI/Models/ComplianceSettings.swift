//
//  ComplianceSettings.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  Model for compliance settings (COPPA, FERPA, data retention)
//

import Foundation
import FirebaseFirestore

/// District-level compliance settings
struct ComplianceSettings: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let districtId: String

    // COPPA Compliance
    var coppaEnabled: Bool
    var coppaMinimumAge: Int // Typically 13

    // FERPA Compliance
    var ferpaEnabled: Bool
    var requireParentalConsent: Bool
    var consentExpirationDays: Int? // Optional expiration

    // Data Retention
    var dataRetentionEnabled: Bool
    var retentionPolicyDays: Int // Days to retain student data after graduation/exit
    var autoDeleteEnabled: Bool

    // Audit Logging
    var auditLoggingEnabled: Bool
    var auditRetentionDays: Int // How long to keep audit logs
    var logSensitiveOperations: Bool

    // Privacy Settings
    var requireConsentForSurveys: Bool
    var requireConsentForDataSharing: Bool
    var allowDataExport: Bool
    var allowThirdPartyIntegrations: Bool

    // Notification Settings
    var notifyOnDataAccess: Bool
    var notifyOnDataExport: Bool
    var notifyParentsOnMajorChanges: Bool

    let createdAt: Date
    var lastUpdated: Date

    init(
        id: String? = nil,
        districtId: String,
        coppaEnabled: Bool = true,
        coppaMinimumAge: Int = 13,
        ferpaEnabled: Bool = true,
        requireParentalConsent: Bool = true,
        consentExpirationDays: Int? = 365,
        dataRetentionEnabled: Bool = true,
        retentionPolicyDays: Int = 2555, // ~7 years (FERPA requirement)
        autoDeleteEnabled: Bool = false,
        auditLoggingEnabled: Bool = true,
        auditRetentionDays: Int = 2555, // ~7 years
        logSensitiveOperations: Bool = true,
        requireConsentForSurveys: Bool = true,
        requireConsentForDataSharing: Bool = true,
        allowDataExport: Bool = true,
        allowThirdPartyIntegrations: Bool = false,
        notifyOnDataAccess: Bool = false,
        notifyOnDataExport: Bool = true,
        notifyParentsOnMajorChanges: Bool = true,
        createdAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.districtId = districtId
        self.coppaEnabled = coppaEnabled
        self.coppaMinimumAge = coppaMinimumAge
        self.ferpaEnabled = ferpaEnabled
        self.requireParentalConsent = requireParentalConsent
        self.consentExpirationDays = consentExpirationDays
        self.dataRetentionEnabled = dataRetentionEnabled
        self.retentionPolicyDays = retentionPolicyDays
        self.autoDeleteEnabled = autoDeleteEnabled
        self.auditLoggingEnabled = auditLoggingEnabled
        self.auditRetentionDays = auditRetentionDays
        self.logSensitiveOperations = logSensitiveOperations
        self.requireConsentForSurveys = requireConsentForSurveys
        self.requireConsentForDataSharing = requireConsentForDataSharing
        self.allowDataExport = allowDataExport
        self.allowThirdPartyIntegrations = allowThirdPartyIntegrations
        self.notifyOnDataAccess = notifyOnDataAccess
        self.notifyOnDataExport = notifyOnDataExport
        self.notifyParentsOnMajorChanges = notifyParentsOnMajorChanges
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }

    // MARK: - Firestore Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "districtId": districtId,
            "coppaEnabled": coppaEnabled,
            "coppaMinimumAge": coppaMinimumAge,
            "ferpaEnabled": ferpaEnabled,
            "requireParentalConsent": requireParentalConsent,
            "dataRetentionEnabled": dataRetentionEnabled,
            "retentionPolicyDays": retentionPolicyDays,
            "autoDeleteEnabled": autoDeleteEnabled,
            "auditLoggingEnabled": auditLoggingEnabled,
            "auditRetentionDays": auditRetentionDays,
            "logSensitiveOperations": logSensitiveOperations,
            "requireConsentForSurveys": requireConsentForSurveys,
            "requireConsentForDataSharing": requireConsentForDataSharing,
            "allowDataExport": allowDataExport,
            "allowThirdPartyIntegrations": allowThirdPartyIntegrations,
            "notifyOnDataAccess": notifyOnDataAccess,
            "notifyOnDataExport": notifyOnDataExport,
            "notifyParentsOnMajorChanges": notifyParentsOnMajorChanges,
            "createdAt": Timestamp(date: createdAt),
            "lastUpdated": Timestamp(date: lastUpdated)
        ]

        if let consentExpirationDays = consentExpirationDays {
            data["consentExpirationDays"] = consentExpirationDays
        }

        return data
    }
}

/// Student-level consent record
struct StudentConsent: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let studentId: String
    let consentType: ConsentType
    var granted: Bool
    let grantedBy: String? // User ID of parent/guardian
    let grantedByName: String?
    let grantedAt: Date?
    let revokedAt: Date?
    let expiresAt: Date?
    var notes: String?

    enum ConsentType: String, Codable, CaseIterable {
        case generalDataCollection = "general_data_collection"
        case surveys = "surveys"
        case dataSharing = "data_sharing"
        case thirdPartyIntegrations = "third_party_integrations"
        case photoRelease = "photo_release"
        case emergencyContact = "emergency_contact"

        var displayName: String {
            switch self {
            case .generalDataCollection: return "General Data Collection"
            case .surveys: return "Surveys & Assessments"
            case .dataSharing: return "Data Sharing"
            case .thirdPartyIntegrations: return "Third-Party Integrations"
            case .photoRelease: return "Photo/Video Release"
            case .emergencyContact: return "Emergency Contact Information"
            }
        }

        var description: String {
            switch self {
            case .generalDataCollection:
                return "Consent to collect and store student information for educational purposes"
            case .surveys:
                return "Consent to administer surveys and assessments to the student"
            case .dataSharing:
                return "Consent to share student data with approved educational partners"
            case .thirdPartyIntegrations:
                return "Consent to integrate with third-party educational tools"
            case .photoRelease:
                return "Consent to use student photos/videos for educational purposes"
            case .emergencyContact:
                return "Consent to maintain emergency contact information"
            }
        }
    }

    init(
        id: String? = nil,
        studentId: String,
        consentType: ConsentType,
        granted: Bool,
        grantedBy: String? = nil,
        grantedByName: String? = nil,
        grantedAt: Date? = nil,
        revokedAt: Date? = nil,
        expiresAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.studentId = studentId
        self.consentType = consentType
        self.granted = granted
        self.grantedBy = grantedBy
        self.grantedByName = grantedByName
        self.grantedAt = grantedAt
        self.revokedAt = revokedAt
        self.expiresAt = expiresAt
        self.notes = notes
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }

    var isActive: Bool {
        granted && !isExpired
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "studentId": studentId,
            "consentType": consentType.rawValue,
            "granted": granted
        ]

        if let grantedBy = grantedBy {
            data["grantedBy"] = grantedBy
        }

        if let grantedByName = grantedByName {
            data["grantedByName"] = grantedByName
        }

        if let grantedAt = grantedAt {
            data["grantedAt"] = Timestamp(date: grantedAt)
        }

        if let revokedAt = revokedAt {
            data["revokedAt"] = Timestamp(date: revokedAt)
        }

        if let expiresAt = expiresAt {
            data["expiresAt"] = Timestamp(date: expiresAt)
        }

        if let notes = notes {
            data["notes"] = notes
        }

        return data
    }
}

// MARK: - Sample Data

extension ComplianceSettings {
    static var sampleSettings: ComplianceSettings {
        ComplianceSettings(
            districtId: "sample-district",
            coppaEnabled: true,
            coppaMinimumAge: 13,
            ferpaEnabled: true,
            requireParentalConsent: true,
            dataRetentionEnabled: true,
            auditLoggingEnabled: true
        )
    }
}

extension StudentConsent {
    static var sampleConsent: StudentConsent {
        StudentConsent(
            studentId: "sample-student",
            consentType: .generalDataCollection,
            granted: true,
            grantedBy: "parent-123",
            grantedByName: "Jane Doe",
            grantedAt: Date(),
            expiresAt: Date().addingTimeInterval(365 * 86400) // 1 year
        )
    }
}

/// Summary of all consents for a student
struct ConsentSummary {
    let studentId: String
    let consents: [StudentConsent]
    
    var activeConsents: Int {
        consents.filter { $0.isActive }.count
    }
    
    var expiredConsents: Int {
        consents.filter { $0.isExpired }.count
    }
    
    var missingConsentTypes: [StudentConsent.ConsentType] {
        let grantedTypes = Set(consents.filter { $0.isActive }.map { $0.consentType })
        return StudentConsent.ConsentType.allCases.filter { !grantedTypes.contains($0) }
    }
    
    var allConsentsActive: Bool {
        missingConsentTypes.isEmpty && expiredConsents == 0
    }
}
