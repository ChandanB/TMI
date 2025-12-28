//
//  PlanApprovalService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing TMI plan approval workflow
@Observable
class PlanApprovalService {
    private let db = Firestore.firestore()

    // MARK: - Submission

    /// Submit a plan for approval
    func submitPlanForApproval(_ planId: String, createdBy: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PlanApprovalError.userNotAuthenticated
        }

        // Create approval history entry
        let historyEntry = ApprovalHistoryEntry(
            action: .submitted,
            actionBy: currentUser.uid,
            comment: "Submitted for administrative approval"
        )

        // Update plan
        try await db.collection("users")
            .document(createdBy)
            .collection("tmiPlans")
            .document(planId)
            .updateData([
                "approvalStatus": PlanApprovalStatus.pendingApproval.rawValue,
                "submittedForApprovalAt": Timestamp(date: Date()),
                "approvalHistory": FieldValue.arrayUnion([
                    [
                        "action": historyEntry.action.rawValue,
                        "actionBy": historyEntry.actionBy,
                        "timestamp": Timestamp(date: historyEntry.timestamp),
                        "comment": historyEntry.comment ?? ""
                    ]
                ]),
                "lastUpdated": Timestamp(date: Date())
            ])

        print("[PlanApprovalService] Submitted plan \(planId) for approval")
    }

    // MARK: - Approval Actions

    /// Approve a plan
    func approvePlan(_ planId: String, createdBy: String, comment: String? = nil) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PlanApprovalError.userNotAuthenticated
        }

        // Verify user has approval permissions
        guard try await hasApprovalPermissions(currentUser.uid) else {
            throw PlanApprovalError.insufficientPermissions
        }

        let historyEntry = ApprovalHistoryEntry(
            action: .approved,
            actionBy: currentUser.uid,
            comment: comment
        )

        try await db.collection("users")
            .document(createdBy)
            .collection("tmiPlans")
            .document(planId)
            .updateData([
                "approvalStatus": PlanApprovalStatus.approved.rawValue,
                "approvedBy": currentUser.uid,
                "approvedAt": Timestamp(date: Date()),
                "approvalHistory": FieldValue.arrayUnion([
                    [
                        "action": historyEntry.action.rawValue,
                        "actionBy": historyEntry.actionBy,
                        "timestamp": Timestamp(date: historyEntry.timestamp),
                        "comment": historyEntry.comment ?? ""
                    ]
                ]),
                "lastUpdated": Timestamp(date: Date())
            ])

        print("[PlanApprovalService] Approved plan \(planId)")
    }

    /// Reject a plan
    func rejectPlan(_ planId: String, createdBy: String, reason: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PlanApprovalError.userNotAuthenticated
        }

        guard try await hasApprovalPermissions(currentUser.uid) else {
            throw PlanApprovalError.insufficientPermissions
        }

        let historyEntry = ApprovalHistoryEntry(
            action: .rejected,
            actionBy: currentUser.uid,
            comment: reason
        )

        try await db.collection("users")
            .document(createdBy)
            .collection("tmiPlans")
            .document(planId)
            .updateData([
                "approvalStatus": PlanApprovalStatus.rejected.rawValue,
                "rejectionReason": reason,
                "approvalHistory": FieldValue.arrayUnion([
                    [
                        "action": historyEntry.action.rawValue,
                        "actionBy": historyEntry.actionBy,
                        "timestamp": Timestamp(date: historyEntry.timestamp),
                        "comment": historyEntry.comment ?? ""
                    ]
                ]),
                "lastUpdated": Timestamp(date: Date())
            ])

        print("[PlanApprovalService] Rejected plan \(planId): \(reason)")
    }

    /// Request changes on a plan
    func requestChanges(_ planId: String, createdBy: String, feedback: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PlanApprovalError.userNotAuthenticated
        }

        guard try await hasApprovalPermissions(currentUser.uid) else {
            throw PlanApprovalError.insufficientPermissions
        }

        let historyEntry = ApprovalHistoryEntry(
            action: .changesRequested,
            actionBy: currentUser.uid,
            comment: feedback
        )

        try await db.collection("users")
            .document(createdBy)
            .collection("tmiPlans")
            .document(planId)
            .updateData([
                "approvalStatus": PlanApprovalStatus.changesRequested.rawValue,
                "rejectionReason": feedback,
                "approvalHistory": FieldValue.arrayUnion([
                    [
                        "action": historyEntry.action.rawValue,
                        "actionBy": historyEntry.actionBy,
                        "timestamp": Timestamp(date: historyEntry.timestamp),
                        "comment": historyEntry.comment ?? ""
                    ]
                ]),
                "lastUpdated": Timestamp(date: Date())
            ])

        print("[PlanApprovalService] Requested changes on plan \(planId)")
    }

    // MARK: - Fetching

    /// Fetch plans pending approval for a district
    func fetchPendingApprovalPlans(districtId: String) async throws -> [TMIPlan] {
        // Get all users in the district
        let usersSnapshot = try await db.collection("users")
            .whereField("districtId", isEqualTo: districtId)
            .getDocuments()

        var pendingPlans: [TMIPlan] = []

        // Fetch pending plans for each user
        for userDoc in usersSnapshot.documents {
            let userId = userDoc.documentID

            let plansSnapshot = try await db.collection("users")
                .document(userId)
                .collection("tmiPlans")
                .whereField("approvalStatus", isEqualTo: PlanApprovalStatus.pendingApproval.rawValue)
                .order(by: "submittedForApprovalAt", descending: true)
                .getDocuments()

            let userPlans = plansSnapshot.documents.compactMap { try? $0.data(as: TMIPlan.self) }
            pendingPlans.append(contentsOf: userPlans)
        }

        return pendingPlans.sorted { ($0.submittedForApprovalAt ?? Date.distantPast) > ($1.submittedForApprovalAt ?? Date.distantPast) }
    }

    /// Fetch plans by approval status
    func fetchPlansByStatus(_ status: PlanApprovalStatus, userId: String) async throws -> [TMIPlan] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("tmiPlans")
            .whereField("approvalStatus", isEqualTo: status.rawValue)
            .order(by: "lastUpdated", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: TMIPlan.self) }
    }

    /// Get approval statistics for a district
    func getApprovalStatistics(districtId: String) async throws -> PlanApprovalStatistics {
        let usersSnapshot = try await db.collection("users")
            .whereField("districtId", isEqualTo: districtId)
            .getDocuments()

        var allPlans: [TMIPlan] = []

        for userDoc in usersSnapshot.documents {
            let userId = userDoc.documentID
            let plansSnapshot = try await db.collection("users")
                .document(userId)
                .collection("tmiPlans")
                .getDocuments()

            let userPlans = plansSnapshot.documents.compactMap { try? $0.data(as: TMIPlan.self) }
            allPlans.append(contentsOf: userPlans)
        }

        return PlanApprovalStatistics(plans: allPlans)
    }

    // MARK: - Permissions

    /// Check if user has approval permissions
    func hasApprovalPermissions(_ userId: String) async throws -> Bool {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data(),
              let roleString = userData["role"] as? String else {
            return false
        }

        // Administrators, district admins, and superintendents can approve plans
        return ["administrator", "admin", "district_admin", "superintendent"].contains(roleString)
    }

    /// Get user info for display in approval history
    func getUserInfo(_ userId: String) async throws -> (name: String, role: String) {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else {
            throw PlanApprovalError.userNotFound
        }

        let firstName = userData["firstName"] as? String ?? ""
        let lastName = userData["lastName"] as? String ?? ""
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let role = userData["role"] as? String ?? "unknown"

        return (name.isEmpty ? "Unknown User" : name, role)
    }
}

// MARK: - Approval Statistics

struct PlanApprovalStatistics: Codable, Sendable {
    let totalPlans: Int
    let draftPlans: Int
    let pendingApprovalPlans: Int
    let approvedPlans: Int
    let rejectedPlans: Int
    let changesRequestedPlans: Int
    let approvalRate: Double

    init(plans: [TMIPlan]) {
        self.totalPlans = plans.count

        self.draftPlans = plans.filter { $0.approvalStatus == .draft }.count
        self.pendingApprovalPlans = plans.filter { $0.approvalStatus == .pendingApproval }.count
        self.approvedPlans = plans.filter { $0.approvalStatus == .approved }.count
        self.rejectedPlans = plans.filter { $0.approvalStatus == .rejected }.count
        self.changesRequestedPlans = plans.filter { $0.approvalStatus == .changesRequested }.count

        let totalSubmitted = pendingApprovalPlans + approvedPlans + rejectedPlans + changesRequestedPlans
        self.approvalRate = totalSubmitted > 0
            ? Double(approvedPlans) / Double(totalSubmitted)
            : 0.0
    }
}

// MARK: - Error Handling

enum PlanApprovalError: Error, LocalizedError {
    case userNotAuthenticated
    case insufficientPermissions
    case planNotFound
    case userNotFound
    case invalidStatus

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .insufficientPermissions:
            return "Insufficient permissions to perform this action"
        case .planNotFound:
            return "Plan not found"
        case .userNotFound:
            return "User not found"
        case .invalidStatus:
            return "Invalid approval status"
        }
    }
}
