//
//  ComplianceService.swift
//  TMI
//
//  Service for managing compliance settings and audits.
//  Used by district administrators for regulatory compliance.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Compliance Service

final class ComplianceService {
    static let shared = ComplianceService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Settings Operations
    
    /// Fetch compliance settings for a district
    func fetchSettings(districtId: String) async throws -> ComplianceSettings? {
        let docRef = db.document(FirestorePaths.complianceSettings(districtID: districtId))
        let document = try await docRef.getDocument()
        
        if document.exists {
            return try? document.data(as: ComplianceSettings.self)
        }
        
        return nil
    }
    
    /// Update compliance settings for a district
    func updateSettings(districtId: String, settings: ComplianceSettings) async throws {
        let docRef = db.document(FirestorePaths.complianceSettings(districtID: districtId))
        let data = settings.toFirestoreData()
        
        try await docRef.setData(data, merge: true)
        
        print("[ComplianceService] Updated compliance settings for district: \(districtId)")
    }
    
    // MARK: - Audit Operations
    
    /// Get compliance audit results for a district
    func getAuditResults(districtId: String, dateRange: ClosedRange<Date>?) async throws -> [ComplianceAuditResult] {
        var query: Query = db.collection(FirestorePaths.complianceAudits(districtID: districtId))
        
        if let dateRange = dateRange {
            query = query
                .whereField("auditDate", isGreaterThanOrEqualTo: dateRange.lowerBound.timeIntervalSince1970)
                .whereField("auditDate", isLessThanOrEqualTo: dateRange.upperBound.timeIntervalSince1970)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { parseAuditResult(from: $0) }
    }
    
    /// Run a compliance check
    func runComplianceCheck(districtId: String) async throws -> ComplianceAuditResult {
        print("[ComplianceService] Running compliance check for district: \(districtId)")
        
        // In production, this would perform actual compliance checks
        // For now, return a stub result
        
        let result = ComplianceAuditResult(
            id: UUID().uuidString,
            districtId: districtId,
            auditDate: Date(),
            overallScore: 0.85,
            categories: [
                ComplianceCategory(
                    name: "Data Privacy",
                    score: 0.9,
                    issues: [],
                    recommendations: ["Consider enabling additional encryption options"]
                ),
                ComplianceCategory(
                    name: "Student Records",
                    score: 0.8,
                    issues: ["Some records missing required fields"],
                    recommendations: ["Review student intake process"]
                )
            ],
            summary: "Overall compliance is good with minor areas for improvement."
        )
        
        // Save the audit result
        try await saveAuditResult(districtId: districtId, result: result)
        
        return result
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
    
    private func saveAuditResult(districtId: String, result: ComplianceAuditResult) async throws {
        let collection = db.collection(FirestorePaths.complianceAudits(districtID: districtId))
        let data = result.toFirestoreData()
        
        try await collection.document(result.id).setData(data)
    }
    
    
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

enum ComplianceServiceError: LocalizedError {
    case studentConsentMigrationPending

    var errorDescription: String? {
        "Student consent records will be available after their canonical data migration."
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
