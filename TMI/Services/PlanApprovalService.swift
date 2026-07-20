//
//  PlanApprovalService.swift
//  TMI
//
//  Service for managing plan approval workflows.
//  Used by district administrators to review and approve TMI plans.
//

import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

// MARK: - Plan Approval Service

final class PlanApprovalService {
    static let shared = PlanApprovalService()

    private let db = Firestore.firestore()
    private let authorizationSessions: any AuthorizationSessionProviding
    private let authorization = RBACService()

    init(
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared
    ) {
        self.authorizationSessions = authorizationSessions
    }

    // MARK: - Fetch Operations
    
    /// Fetch pending approvals for a district
    func fetchPendingApprovals(districtId: String) async throws -> [TMIPlan] {
        _ = try requireDistrictApprover(districtID: districtId)

        // In production, this would query plans with pendingApproval status for the district
        // For now, return empty array as a stub
        
        print("[PlanApprovalService] Fetching pending approvals for district: \(districtId)")
        
        // This would be implemented as:
        // let query = db.collection("tmiPlans")
        //     .whereField("districtId", isEqualTo: districtId)
        //     .whereField("status", isEqualTo: "pending_approval")
        
        return []
    }
    
    /// Fetch pending approval plans (alias for fetchPendingApprovals)
    func fetchPendingApprovalPlans(districtId: String) async throws -> [TMIPlan] {
        return try await fetchPendingApprovals(districtId: districtId)
    }
    
    /// Get approval statistics for a district
    func getApprovalStatistics(districtId: String) async throws -> PlanApprovalStatistics {
        _ = try requireDistrictApprover(districtID: districtId)

        // In production, this would query all plans for the district and calculate statistics
        // For now, return stub statistics
        
        print("[PlanApprovalService] Fetching approval statistics for district: \(districtId)")
        
        // This would be implemented as:
        // let allPlans = try await fetchAllPlansForDistrict(districtId: districtId)
        // let pending = allPlans.filter { $0.status == .pendingApproval }.count
        // let approved = allPlans.filter { $0.status == .approved }.count
        // etc.
        
        return PlanApprovalStatistics(
            totalPlans: 0,
            draftPlans: 0,
            pendingApprovalPlans: 0,
            approvedPlans: 0,
            rejectedPlans: 0,
            changesRequestedPlans: 0,
            approvalRate: 0.0
        )
    }
    
    /// Fetch all approvals (pending, approved, rejected) for a district
    func fetchAllApprovals(districtId: String) async throws -> [PlanApprovalRecord] {
        _ = try requireDistrictApprover(districtID: districtId)
        
        let collection = db.collection("districts").document(districtId).collection("planApprovals")
        let snapshot = try await collection.getDocuments()
        
        return snapshot.documents.compactMap { parseApprovalRecord(from: $0) }
    }
    
    // MARK: - Approval Operations
    
    /// Approve a plan with complete history tracking and notifications
    func approvePlan(plan: TMIPlan, comment: String? = nil) async throws {
        guard let planId = plan.id else {
            throw PlanApprovalError.planNotFound
        }

        let session = try await requirePlanAccess(
            planID: planId,
            operation: .approve
        )
        let uid = session.membership.userID

        // Verify plan is in pending approval status
        guard plan.approvalStatus == .pendingApproval else {
            throw PlanApprovalError.invalidStatus
        }

        // Create approval history entry
        let historyEntry = ApprovalHistoryEntry(
            action: .approved,
            actionBy: uid,
            timestamp: Date(),
            comment: comment
        )

        // Update plan
        let docRef = planDocument(planID: planId, userID: uid)

        try await docRef.updateData([
            "approvalStatus": PlanApprovalStatus.approved.rawValue,
            "approvedBy": uid,
            "approvedAt": FieldValue.serverTimestamp(),
            "currentApprovers": FieldValue.delete(), // Clear approvers list
            "approvalHistory": FieldValue.arrayUnion([
                [
                    "action": historyEntry.action.rawValue,
                    "actionBy": historyEntry.actionBy,
                    "timestamp": FieldValue.serverTimestamp(),
                    "comment": historyEntry.comment as Any
                ]
            ]),
            "lastUpdated": FieldValue.serverTimestamp()
        ])

        print("[PlanApprovalService] ✅ Approved plan: \(planId) by \(uid)")

        // Notify plan creator
        if let submittedBy = plan.submittedBy {
            do {
                try await NotificationService.shared.createNotification(
                    type: .planUpdate,
                    title: "Plan Approved",
                    message: "Your TMI plan '\(plan.title)' has been approved",
                    actionUrl: "tmi://plans/\(planId)",
                    targetId: planId,
                    forUserId: submittedBy
                )
            } catch {
                print("[PlanApprovalService] ⚠️ Failed to notify plan creator: \(error)")
            }
        }
    }
    
    /// Reject a plan with reason and notifications
    func rejectPlan(plan: TMIPlan, reason: String) async throws {
        guard let planId = plan.id else {
            throw PlanApprovalError.planNotFound
        }

        let session = try await requirePlanAccess(
            planID: planId,
            operation: .approve
        )
        let uid = session.membership.userID

        // Verify plan is in pending approval status
        guard plan.approvalStatus == .pendingApproval else {
            throw PlanApprovalError.invalidStatus
        }

        // Create approval history entry
        let historyEntry = ApprovalHistoryEntry(
            action: .rejected,
            actionBy: uid,
            timestamp: Date(),
            comment: reason
        )

        // Update plan
        let docRef = planDocument(planID: planId, userID: uid)

        try await docRef.updateData([
            "approvalStatus": PlanApprovalStatus.rejected.rawValue,
            "rejectionReason": reason,
            "currentApprovers": FieldValue.delete(), // Clear approvers list
            "approvalHistory": FieldValue.arrayUnion([
                [
                    "action": historyEntry.action.rawValue,
                    "actionBy": historyEntry.actionBy,
                    "timestamp": FieldValue.serverTimestamp(),
                    "comment": historyEntry.comment as Any
                ]
            ]),
            "lastUpdated": FieldValue.serverTimestamp()
        ])

        print("[PlanApprovalService] ❌ Rejected plan: \(planId) by \(uid)")

        // Notify plan creator
        if let submittedBy = plan.submittedBy {
            do {
                try await NotificationService.shared.createNotification(
                    type: .planUpdate,
                    title: "Plan Rejected",
                    message: "Your TMI plan '\(plan.title)' was rejected. Reason: \(reason)",
                    actionUrl: "tmi://plans/\(planId)",
                    targetId: planId,
                    forUserId: submittedBy
                )
            } catch {
                print("[PlanApprovalService] ⚠️ Failed to notify plan creator: \(error)")
            }
        }
    }
    
    /// Request revisions/changes on a plan with detailed feedback
    func requestChanges(plan: TMIPlan, feedback: String) async throws {
        guard let planId = plan.id else {
            throw PlanApprovalError.planNotFound
        }

        let session = try await requirePlanAccess(
            planID: planId,
            operation: .approve
        )
        let uid = session.membership.userID

        // Verify plan is in pending approval status
        guard plan.approvalStatus == .pendingApproval else {
            throw PlanApprovalError.invalidStatus
        }

        // Create approval history entry
        let historyEntry = ApprovalHistoryEntry(
            action: .changesRequested,
            actionBy: uid,
            timestamp: Date(),
            comment: feedback
        )

        // Update plan
        let docRef = planDocument(planID: planId, userID: uid)

        try await docRef.updateData([
            "approvalStatus": PlanApprovalStatus.changesRequested.rawValue,
            "rejectionReason": feedback, // Store feedback in rejection reason for visibility
            "currentApprovers": FieldValue.delete(), // Clear approvers list until resubmitted
            "approvalHistory": FieldValue.arrayUnion([
                [
                    "action": historyEntry.action.rawValue,
                    "actionBy": historyEntry.actionBy,
                    "timestamp": FieldValue.serverTimestamp(),
                    "comment": historyEntry.comment as Any
                ]
            ]),
            "lastUpdated": FieldValue.serverTimestamp()
        ])

        print("[PlanApprovalService] 📝 Requested changes for plan: \(planId) by \(uid)")

        // Notify plan creator
        if let submittedBy = plan.submittedBy {
            do {
                try await NotificationService.shared.createNotification(
                    type: .planUpdate,
                    title: "Changes Requested",
                    message: "Changes have been requested for your TMI plan '\(plan.title)'. Feedback: \(feedback)",
                    actionUrl: "tmi://plans/\(planId)",
                    targetId: planId,
                    forUserId: submittedBy
                )
            } catch {
                print("[PlanApprovalService] ⚠️ Failed to notify plan creator: \(error)")
            }
        }
    }

    /// Resubmit a plan after making requested changes
    func resubmitPlan(
        plan: TMIPlan,
        approvers: [String],
        revisionNotes: String? = nil
    ) async throws {
        guard let planId = plan.id else {
            throw PlanApprovalError.planNotFound
        }

        _ = try await requirePlanAccess(planID: planId, operation: .write)
        _ = approvers
        _ = revisionNotes
        throw PlanApprovalError.approvalFailed(
            "Approvers must be selected from the verified district staff directory"
        )
    }
    
    /// Submit a plan for approval with validation and notifications
    func submitForApproval(
        plan: TMIPlan,
        approvers: [String], // UIDs of counselors/admins who should approve
        notifyApprovers: Bool = true
    ) async throws {
        guard let planId = plan.id else {
            throw PlanApprovalError.planNotFound
        }

        _ = try await requirePlanAccess(planID: planId, operation: .write)
        _ = approvers
        _ = notifyApprovers
        throw PlanApprovalError.approvalFailed(
            "Approvers must be selected from the verified district staff directory"
        )
    }

    // MARK: - Private Helpers

    private enum PlanAccessOperation {
        case write
        case approve
    }

    private func authorizedSession() throws -> AuthenticatedSession {
        guard let session = authorizationSessions.session(
            authenticatedUserID: Auth.auth().currentUser?.uid
        ) else {
            throw PlanApprovalError.userNotAuthenticated
        }
        return session
    }

    private func requireDistrictApprover(
        districtID: String
    ) throws -> AuthenticatedSession {
        let session = try authorizedSession()
        guard session.membership.districtID == districtID,
              session.membership.capabilities.contains(.planApprove) else {
            throw PlanApprovalError.authorizationDenied
        }
        return session
    }

    private func requirePlanAccess(
        planID: String,
        operation: PlanAccessOperation
    ) async throws -> AuthenticatedSession {
        let session = try authorizedSession()
        let planService = TMIPlanService(
            authorizationSessions: authorizationSessions
        )
        guard let trustedPlan = try await planService.fetchPlan(byId: planID),
              trustedPlan.districtId == session.membership.districtID else {
            throw PlanApprovalError.authorizationDenied
        }

        let students = try trustedPlan.students.map { student in
            guard let scope = StudentAuthorizationScope(student: student) else {
                throw PlanApprovalError.authorizationDenied
            }
            return scope
        }
        let scope = PlanAuthorizationScope(
            planID: planID,
            districtID: session.membership.districtID,
            students: students
        )

        let isAllowed: Bool
        switch operation {
        case .write:
            isAllowed = authorization.canWritePlan(
                member: session.membership,
                plan: scope
            )
        case .approve:
            isAllowed = authorization.canApprovePlan(
                member: session.membership,
                plan: scope
            )
        }
        guard isAllowed else {
            throw PlanApprovalError.authorizationDenied
        }
        return session
    }

    private func planDocument(
        planID: String,
        userID: String
    ) -> DocumentReference {
        db.collection("users")
            .document(userID)
            .collection("tmiPlans")
            .document(planID)
    }
    
    private func saveApprovalRecord(_ record: PlanApprovalRecord) async throws {
        // Would save to district's planApprovals collection
        // For now, just log
        print("[PlanApprovalService] Saving approval record: \(record.action.rawValue)")
    }
    
    private func updatePlanStatus(planId: String, status: PlanApprovalStatus) async throws {
        // Convert PlanApprovalStatus to PlanStatus for PlanRepository
        let planStatus: PlanStatus
        switch status {
        case .draft:
            planStatus = .draft
        case .pendingApproval:
            planStatus = .pendingApproval
        case .approved:
            planStatus = .approved
        case .rejected:
            planStatus = .rejected
        case .changesRequested:
            planStatus = .needsRevision
        }
        try await PlanRepository.shared.updateStatus(planStatus, forPlanId: planId)
    }
    
    private func parseApprovalRecord(from document: DocumentSnapshot) -> PlanApprovalRecord? {
        guard let data = document.data() else { return nil }
        
        guard let planId = data["planId"] as? String,
              let actionRaw = data["action"] as? String,
              let action = ApprovalAction(rawValue: actionRaw),
              let reviewerId = data["reviewerId"] as? String,
              let reviewedAtTimestamp = data["reviewedAt"] as? Double else {
            return nil
        }
        
        // Convert PlanStatus strings to PlanApprovalStatus
        let previousStatus: PlanApprovalStatus
        if let prevRaw = data["previousStatus"] as? String {
            switch prevRaw {
            case "draft": previousStatus = .draft
            case "pending_approval": previousStatus = .pendingApproval
            case "approved": previousStatus = .approved
            case "rejected": previousStatus = .rejected
            case "needs_revision", "changes_requested": previousStatus = .changesRequested
            default: previousStatus = .draft
            }
        } else {
            previousStatus = .draft
        }
        
        let newStatus: PlanApprovalStatus
        if let newRaw = data["newStatus"] as? String {
            switch newRaw {
            case "draft": newStatus = .draft
            case "pending_approval": newStatus = .pendingApproval
            case "approved": newStatus = .approved
            case "rejected": newStatus = .rejected
            case "needs_revision", "changes_requested": newStatus = .changesRequested
            default: newStatus = .draft
            }
        } else {
            newStatus = .draft
        }
        
        return PlanApprovalRecord(
            id: document.documentID,
            planId: planId,
            action: action,
            reviewerId: reviewerId,
            reviewedAt: Date(timeIntervalSince1970: reviewedAtTimestamp),
            comments: data["comments"] as? String,
            previousStatus: previousStatus,
            newStatus: newStatus
        )
    }
}

// MARK: - Plan Approval Record

struct PlanApprovalRecord: Identifiable, Codable {
    let id: String
    let planId: String
    let action: ApprovalAction
    let reviewerId: String
    let reviewedAt: Date
    let comments: String?
    let previousStatus: PlanApprovalStatus
    let newStatus: PlanApprovalStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case planId
        case action
        case reviewerId
        case reviewedAt
        case comments
        case previousStatus
        case newStatus
    }
    
    init(id: String, planId: String, action: ApprovalAction, reviewerId: String, reviewedAt: Date, comments: String?, previousStatus: PlanApprovalStatus, newStatus: PlanApprovalStatus) {
        self.id = id
        self.planId = planId
        self.action = action
        self.reviewerId = reviewerId
        self.reviewedAt = reviewedAt
        self.comments = comments
        self.previousStatus = previousStatus
        self.newStatus = newStatus
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        planId = try container.decode(String.self, forKey: .planId)
        action = try container.decode(ApprovalAction.self, forKey: .action)
        reviewerId = try container.decode(String.self, forKey: .reviewerId)
        reviewedAt = try container.decode(Date.self, forKey: .reviewedAt)
        comments = try container.decodeIfPresent(String.self, forKey: .comments)
        
        // Decode status strings and convert to PlanApprovalStatus
        let prevRaw = try container.decode(String.self, forKey: .previousStatus)
        switch prevRaw {
        case "draft": previousStatus = .draft
        case "pending_approval": previousStatus = .pendingApproval
        case "approved": previousStatus = .approved
        case "rejected": previousStatus = .rejected
        case "needs_revision", "changes_requested": previousStatus = .changesRequested
        default: previousStatus = .draft
        }
        
        let newRaw = try container.decode(String.self, forKey: .newStatus)
        switch newRaw {
        case "draft": newStatus = .draft
        case "pending_approval": newStatus = .pendingApproval
        case "approved": newStatus = .approved
        case "rejected": newStatus = .rejected
        case "needs_revision", "changes_requested": newStatus = .changesRequested
        default: newStatus = .draft
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(planId, forKey: .planId)
        try container.encode(action, forKey: .action)
        try container.encode(reviewerId, forKey: .reviewerId)
        try container.encode(reviewedAt, forKey: .reviewedAt)
        try container.encodeIfPresent(comments, forKey: .comments)
        try container.encode(previousStatus.rawValue, forKey: .previousStatus)
        try container.encode(newStatus.rawValue, forKey: .newStatus)
    }
}

// MARK: - Plan Approval Statistics

struct PlanApprovalStatistics: Codable, Sendable {
    let totalPlans: Int
    let draftPlans: Int
    let pendingApprovalPlans: Int
    let approvedPlans: Int
    let rejectedPlans: Int
    let changesRequestedPlans: Int
    let approvalRate: Double
}

// MARK: - Errors

enum PlanApprovalError: LocalizedError {
    case userNotAuthenticated
    case planNotFound
    case invalidStatus
    case approvalFailed(String)
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .planNotFound:
            return "Plan not found"
        case .invalidStatus:
            return "Plan is not in a valid status for this action"
        case .approvalFailed(let message):
            return "Approval failed: \(message)"
        case .authorizationDenied:
            return "You don’t have access to approve this plan"
        }
    }
}
