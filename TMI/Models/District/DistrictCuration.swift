//
//  DistrictCuration.swift
//  TMI
//
//  Phase 6: District Curation Models (Schema Only)
//  Future feature for districts to curate global content
//

import Foundation
@preconcurrency import FirebaseFirestore

// MARK: - District Interest Curation

/// Allows districts to approve/hide global interests
struct DistrictInterestCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let interestId: String
    let status: CurationStatus
    let curatedBy: String  // UID of district admin
    let curatedAt: Date
    let notes: String?

    enum CurationStatus: String, Codable, CaseIterable, Sendable {
        case approved = "approved"
        case hidden = "hidden"
        case flagged = "flagged"  // Needs review
    }
}

// MARK: - District Career Curation

/// Allows districts to approve/hide global careers
struct DistrictCareerCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let careerId: String
    let status: CurationStatus
    let curatedBy: String
    let curatedAt: Date
    let notes: String?
    let priority: Int?  // Optional priority ranking

    enum CurationStatus: String, Codable, CaseIterable, Sendable {
        case approved = "approved"
        case hidden = "hidden"
        case featured = "featured"  // Highlighted for district
        case flagged = "flagged"
    }
}

// MARK: - District Resource Curation

/// Allows districts to approve/hide/customize global resources
struct DistrictResourceCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let resourceId: String
    let status: CurationStatus
    let curatedBy: String
    let curatedAt: Date
    let notes: String?
    let customDescription: String?  // District-specific override
    let requiredForRoles: [String]?  // Optional role requirements

    enum CurationStatus: String, Codable, CaseIterable, Sendable {
        case approved = "approved"
        case hidden = "hidden"
        case featured = "featured"
        case required = "required"  // Mandatory for all in district
        case flagged = "flagged"
    }
}

// MARK: - District Content Policy

/// District-wide content policies
struct DistrictContentPolicy: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let policyType: PolicyType
    let setting: PolicySetting
    let updatedBy: String
    let updatedAt: Date

    enum PolicyType: String, Codable, CaseIterable, Sendable {
        case interestApproval = "interest_approval"  // Require approval before showing
        case careerApproval = "career_approval"
        case resourceApproval = "resource_approval"
        case aiContentReview = "ai_content_review"  // Review AI-generated content
    }

    enum PolicySetting: String, Codable, CaseIterable, Sendable {
        case autoApprove = "auto_approve"  // Show all by default
        case requireReview = "require_review"  // Hide until reviewed
        case moderateAI = "moderate_ai"  // Only AI content needs review
    }
}

// MARK: - Firestore Collection Paths (for future implementation)

extension DistrictInterestCuration {
    static func collectionPath(districtId: String) -> String {
        "districts/\(districtId)/interestCurations"
    }
}

extension DistrictCareerCuration {
    static func collectionPath(districtId: String) -> String {
        "districts/\(districtId)/careerCurations"
    }
}

extension DistrictResourceCuration {
    static func collectionPath(districtId: String) -> String {
        "districts/\(districtId)/resourceCurations"
    }
}

extension DistrictContentPolicy {
    static func collectionPath(districtId: String) -> String {
        "districts/\(districtId)/contentPolicies"
    }
}
