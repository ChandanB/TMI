//
//  ComplianceService.swift
//  TMI
//
//  Service for managing compliance settings and audits.
//  Used by district administrators for regulatory compliance.
//

import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseAuth

// MARK: - Compliance Service

@MainActor
final class ComplianceService {
    static let shared = ComplianceService()
    
    private let firestore: Firestore?
    private let authorizationSessions: any AuthorizationSessionProviding
    private let currentUserID: @Sendable () -> String?
    private var db: Firestore { firestore ?? Firestore.firestore() }

    init(
        firestore: Firestore? = nil,
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.firestore = firestore
        self.authorizationSessions = authorizationSessions
        self.currentUserID = currentUserID
    }

    private func authorize(districtID: String, writing: Bool = false) throws -> AuthenticatedSession {
        guard let userID = currentUserID(),
              let session = authorizationSessions.session(authenticatedUserID: userID),
              session.profile.userID == userID,
              session.claim.userID == userID,
              session.claim.accessClass == .staff,
              session.membership.userID == userID,
              session.claim.membershipVersion == session.membership.version,
              session.membership.isActive else {
            throw ComplianceServiceError.notAuthenticated
        }
        guard session.claim.districtID == districtID,
              session.membership.districtID == districtID,
              !writing || session.membership.role == .districtAdministrator else {
            throw ComplianceServiceError.permissionDenied
        }
        return session
    }

    private func revalidate(_ session: AuthenticatedSession, districtID: String, writing: Bool = false) throws {
        guard try authorize(districtID: districtID, writing: writing) == session else {
            throw ComplianceServiceError.permissionDenied
        }
    }
    
    // MARK: - Settings Operations
    
    /// Fetch compliance settings for a district
    func fetchSettings(districtId: String) async throws -> ComplianceSettings? {
        let session = try authorize(districtID: districtId)
        let docRef = db.document(FirestorePaths.complianceSettings(districtID: districtId))
        let document = try await withTimeout(seconds: 10) { try await docRef.getDocument() }
        try revalidate(session, districtID: districtId)
        
        if document.exists {
            let settings = try document.data(as: ComplianceSettings.self)
            guard settings.districtId == districtId else { throw ComplianceServiceError.invalidResponse }
            return settings
        }
        
        return nil
    }
    
    /// Update compliance settings for a district
    func updateSettings(districtId: String, settings: ComplianceSettings) async throws {
        let session = try authorize(districtID: districtId, writing: true)
        guard settings.districtId == districtId else { throw ComplianceServiceError.permissionDenied }
        let docRef = db.document(FirestorePaths.complianceSettings(districtID: districtId))
        try await docRef.setData(settings.toFirestoreData(), merge: true)
        try revalidate(session, districtID: districtId, writing: true)
    }
    
    // MARK: - Audit Operations
    
    /// Get compliance audit results for a district
    func getAuditResults(districtId: String, dateRange: ClosedRange<Date>?) async throws -> [ComplianceAuditResult] {
        let session = try authorize(districtID: districtId)
        var query: Query = db.collection(FirestorePaths.complianceAudits(districtID: districtId))
        
        if let dateRange = dateRange {
            query = query
                .whereField("auditDate", isGreaterThanOrEqualTo: dateRange.lowerBound.timeIntervalSince1970)
                .whereField("auditDate", isLessThanOrEqualTo: dateRange.upperBound.timeIntervalSince1970)
        }
        
        let snapshot = try await query.getDocuments()
        try revalidate(session, districtID: districtId)
        return try snapshot.documents.map {
            guard let record = self.parseAuditResult(from: $0), record.districtId == districtId else {
                throw ComplianceServiceError.invalidResponse
            }
            return record
        }
    }
    
    /// Run a compliance check
    func runComplianceCheck(districtId: String) async throws -> ComplianceAuditResult {
        _ = try authorize(districtID: districtId, writing: true)
        // A settings read is not a regulatory audit. Never persist or display
        // a compliance score without a verified evidence-based evaluator.
        throw ComplianceServiceError.auditUnavailable
    }
    
    // MARK: - Consent Operations
    
    /// Get consent summary for a student
    func getConsentSummary(studentId: String) async throws -> ConsentSummary {
        _ = studentId
        throw ComplianceServiceError.studentConsentMigrationPending
    }
    
    /// Grant consent for a student
    func grantConsent(
        studentId: String,
        consentType: StudentConsent.ConsentType,
        grantedBy: String,
        grantedByName: String,
        expirationDays: Int?
    ) async throws {
        _ = studentId
        _ = consentType
        _ = grantedBy
        _ = grantedByName
        _ = expirationDays
        throw ComplianceServiceError.studentConsentMigrationPending
    }
    
    /// Revoke consent for a student
    func revokeConsent(studentId: String, consentType: StudentConsent.ConsentType) async throws {
        _ = studentId
        _ = consentType
        throw ComplianceServiceError.studentConsentMigrationPending
    }
    
    // MARK: - Private Helpers
    
    private func parseAuditResult(from document: DocumentSnapshot) -> ComplianceAuditResult? {
        guard let data = document.data() else { return nil }
        
        guard let districtId = data["districtId"] as? String,
              let auditDateTimestamp = data["auditDate"] as? Double,
              let overallScore = data["overallScore"] as? Double else {
            return nil
        }
        
        var categories: [ComplianceCategory] = []
        if let categoriesData = data["categories"] as? [[String: Any]] {
            categories = categoriesData.compactMap { catData in
                guard let name = catData["name"] as? String,
                      let score = catData["score"] as? Double else {
                    return nil
                }
                return ComplianceCategory(
                    name: name,
                    score: score,
                    issues: catData["issues"] as? [String] ?? [],
                    recommendations: catData["recommendations"] as? [String] ?? []
                )
            }
        }
        
        return ComplianceAuditResult(
            id: document.documentID,
            districtId: districtId,
            auditDate: Date(timeIntervalSince1970: auditDateTimestamp),
            overallScore: overallScore,
            categories: categories,
            summary: data["summary"] as? String
        )
    }
}

enum ComplianceServiceError: LocalizedError, Equatable {
    case studentConsentMigrationPending
    case notAuthenticated
    case permissionDenied
    case invalidResponse
    case auditUnavailable

    var errorDescription: String? {
        switch self {
        case .studentConsentMigrationPending:
            "Student consent records will be available after their canonical data migration."
        case .notAuthenticated:
            "Sign in with a verified staff account to access district settings."
        case .permissionDenied:
            "You do not have permission to access or change these district settings."
        case .invalidResponse:
            "The district settings or audit records could not be verified."
        case .auditUnavailable:
            "An evidence-based compliance audit is not available. No audit result was created."
        }
    }
}


// MARK: - Compliance Audit Result

struct ComplianceAuditResult: Identifiable, Codable {
    let id: String
    let districtId: String
    let auditDate: Date
    let overallScore: Double
    let categories: [ComplianceCategory]
    let summary: String?
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "districtId": districtId,
            "auditDate": auditDate.timeIntervalSince1970,
            "overallScore": overallScore,
            "categories": categories.map { cat in
                [
                    "name": cat.name,
                    "score": cat.score,
                    "issues": cat.issues,
                    "recommendations": cat.recommendations
                ]
            }
        ]
        
        if let summary = summary {
            data["summary"] = summary
        }
        
        return data
    }
}

struct ComplianceCategory: Codable {
    let name: String
    let score: Double
    let issues: [String]
    let recommendations: [String]
}
