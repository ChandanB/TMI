import Foundation
import Observation

@MainActor
@Observable
final class CanonicalPlanDetailState {
    enum Phase: Equatable {
        case loading
        case loaded(PlanRecord)
        case failed(String)
        case permissionDenied
    }

    enum ChildrenPhase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var childrenPhase: ChildrenPhase = .loading
    private(set) var exportID = UUID()
    private var membership: MembershipContext?
    private var generation = UUID()

    /// Invalidates in-flight requests as well as already displayed private data.
    func updateMembership(_ member: MembershipContext?) {
        guard membership != member else { return }
        membership = member
        clearPrivateState()
        phase = member?.isActive == true ? .loading : .permissionDenied
    }

    private func clearChildren() {
        revisions = []
        goals = []
        actions = []
        progress = []
        childrenPhase = .loading
        exportedPDF = nil
        exportID = UUID()
        exportMessage = nil
    }

    private func clearPrivateState() {
        generation = UUID()
        clearChildren()
        studentDisplayName = nil
        actionMessage = nil
        phase = .permissionDenied
    }

    func hasAccess(_ member: MembershipContext) -> Bool {
        guard membership == member, member.isActive,
              member.capabilities.contains(.studentReadDetail), let plan else { return false }
        return plan.districtID == member.districtID
    }

    private func isCurrent(_ request: UUID, member: MembershipContext) -> Bool {
        generation == request && membership == member && !Task.isCancelled
    }

    private(set) var phase: Phase = .loading
    private(set) var revisions: [PlanRevision] = []
    private(set) var goals: [GoalRecord] = []
    private(set) var actions: [ActionRecord] = []
    private(set) var progress: [ProgressRecord] = []
    private(set) var actionMessage: String?
    private(set) var isMutating = false

    private let planID: String
    private let repository: any PlanRecordRepository
    private let children: (any PlanChildRepositoryProtocol)?
    private let auditing: (any PlanExportAuditing)?

    init(
        planID: String,
        repository: any PlanRecordRepository,
        children: (any PlanChildRepositoryProtocol)? = nil,
        auditing: (any PlanExportAuditing)? = nil
    ) {
        self.planID = planID
        self.repository = repository
        self.children = children
        self.auditing = auditing
    }

    /// The share of due actions actually done, which an educator can recount
    /// by hand.
    var completionPercentage: Int { PlanCompletion.percentage(of: actions) }

    func reloadChildren(member: MembershipContext) async {
        guard hasAccess(member) else {
            updateMembership(member)
            return
        }
        generation = UUID()
        let request = generation
        clearChildren()
        guard let children else {
            childrenPhase = .failed("Plan details are unavailable. Retry when the service is available.")
            return
        }
        do {
            // Stage the entire snapshot locally. No collection is published
            // until every read succeeds under the same membership.
            let loadedGoals = try await children.goals(planID: planID, member: member)
            let loadedActions = try await children.actions(planID: planID, member: member)
            let loadedProgress = try await children.progress(planID: planID, member: member)
            let loadedRevisions = try await children.revisions(planID: planID, member: member)
            guard isCurrent(request, member: member) else { return }
            goals = loadedGoals
            actions = loadedActions
            progress = loadedProgress
            revisions = loadedRevisions
            childrenPhase = .loaded
        } catch {
            guard isCurrent(request, member: member) else { return }
            if error as? PlanRecordRepositoryError == .permissionDenied {
                clearPrivateState()
            } else {
                childrenPhase = .failed("Goals, actions, progress, and history could not be loaded. Retry to see the complete plan.")
            }
        }
    }

    private(set) var exportedPDF: Data?
    private(set) var exportMessage: String?

    /// Exporting is its own permission, separate from reading the plan.
    func canExport(_ member: MembershipContext) -> Bool {
        hasAccess(member) && childrenPhase == .loaded
            && member.capabilities.contains(.reportExport)
    }

    /// Records the export, then builds and renders it.
    ///
    /// The audit identifier is requested first and the export is abandoned if
    /// it cannot be obtained. A child's record does not leave the building
    /// without something, somewhere, recording that it did.
    func export(kind: PlanExportKind, member: MembershipContext) async {
        guard !isMutating else { return }
        exportedPDF = nil
        exportID = UUID()
        guard canExport(member) else {
            exportMessage = "Reload the complete plan with an active membership before exporting."
            return
        }
        guard let auditing else {
            exportMessage = PlanExportAuditError.unavailable.errorDescription
            return
        }
        isMutating = true
        exportMessage = nil
        exportedPDF = nil
        defer { isMutating = false }

        // Refresh the parent and all children before requesting online export
        // authorization. A failed refresh must never export the previous data.
        await load(member: member)
        guard canExport(member), let plan else { return }
        let request = generation
        let auditID: String
        do {
            auditID = try await auditing.recordExport(
                planID: plan.id,
                studentID: plan.studentIDs.sorted().first ?? "",
                kind: kind,
                districtID: plan.districtID
            )
        } catch let error as PlanExportAuditError {
            guard isCurrent(request, member: member) else { return }
            if error == .notAuthorized { clearPrivateState() }
            exportMessage = error.errorDescription
            return
        } catch {
            guard isCurrent(request, member: member) else { return }
            exportMessage = PlanExportAuditError.unavailable.errorDescription
            return
        }

        guard isCurrent(request, member: member), canExport(member) else { return }
        let material = PlanExportMaterial(
            planID: plan.id,
            studentID: plan.studentIDs.sorted().first ?? "",
            studentDisplayName: studentDisplayName ?? "This student",
            model: plan.model,
            rationale: [],
            goals: goals,
            actions: actions,
            progress: progress,
            restrictedNotes: []
        )

        do {
            let document = try PlanExportProjection.document(
                kind: kind,
                material: material,
                capabilities: member.capabilities,
                auditID: auditID
            )
            exportedPDF = PlanExportRenderer.pdfData(for: document)
            exportMessage = exportedPDF == nil
                ? "The export could not be rendered."
                : "Ready to share \(kind.title), audit \(auditID)."
        } catch {
            exportMessage = "You do not have access to export this plan."
        }
    }

    var studentDisplayName: String?

    var plan: PlanRecord? {
        if case .loaded(let plan) = phase { return plan }
        return nil
    }

    func load(member: MembershipContext) async {
        updateMembership(member)
        generation = UUID()
        let request = generation
        clearChildren()
        phase = .loading
        guard member.isActive, member.capabilities.contains(.studentReadDetail) else {
            clearPrivateState()
            return
        }
        do {
            let loaded = try await repository.plan(id: planID, member: member)
            guard isCurrent(request, member: member) else { return }
            guard loaded.districtID == member.districtID else {
                clearPrivateState()
                return
            }
            phase = .loaded(loaded)
            await reloadChildren(member: member)
        } catch {
            guard isCurrent(request, member: member) else { return }
            if error as? PlanRecordRepositoryError == .permissionDenied {
                clearPrivateState()
            } else {
                phase = .failed("This plan could not be loaded. Check your connection and retry.")
            }
        }
    }

    /// ShareLink requests bytes lazily, so a retained share item cannot release
    /// a PDF after membership changes or a refresh invalidates its snapshot.
    func pdfForSharing(id: UUID, member: MembershipContext) throws -> Data {
        guard id == exportID, canExport(member), let exportedPDF else {
            throw PlanExportAuditError.notAuthorized
        }
        return exportedPDF
    }

    /// The transitions this member may actually perform right now.
    ///
    /// The lifecycle table says what is legal for the plan; the member's
    /// capabilities say what is theirs to do. Both have to agree, and the
    /// rules refuse anything these two miss.
    func availableTransitions(for member: MembershipContext) -> [PlanRecordStatus] {
        guard hasAccess(member), let plan else { return [] }
        return PlanLifecycle.allowedTransitions(from: plan.status)
            .filter { status in
                switch status {
                case .active where plan.status == .draft || plan.status == .pendingApproval:
                    false
                case .active where plan.status == .approved:
                    member.capabilities.contains(.studentWriteDetail)
                        && plan.effectiveOwnerMemberID == member.userID
                case .approved, .changesRequested where plan.status == .pendingApproval:
                    member.capabilities.contains(.planApprove)
                        && (plan.approverMemberIDs.isEmpty || plan.approverMemberIDs.contains(member.userID))
                default:
                    member.capabilities.contains(.studentWriteDetail)
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
    }

    func transition(
        to status: PlanRecordStatus,
        note: String? = nil,
        member: MembershipContext
    ) async {
        guard let plan, !isMutating,
              availableTransitions(for: member).contains(status) else { return }
        generation = UUID()
        let request = generation
        clearChildren()
        isMutating = true
        actionMessage = nil
        defer { isMutating = false }
        do {
            let updated = try await repository.transition(
                id: plan.id,
                to: status,
                expectedVersion: plan.metadata.recordVersion,
                note: note,
                member: member
            )
            guard isCurrent(request, member: member) else { return }
            phase = .loaded(updated)
            await reloadChildren(member: member)
            guard hasAccess(member) else { return }
            actionMessage = "Moved to \(status.displayName.lowercased())."
        } catch PlanRecordRepositoryError.permissionDenied {
            guard isCurrent(request, member: member) else { return }
            clearPrivateState()
            actionMessage = "You do not have access to change this plan."
        } catch PlanRecordRepositoryError.unavailable {
            guard isCurrent(request, member: member) else { return }
            childrenPhase = .failed("Reload plan details before continuing.")
            actionMessage = "The change could not be confirmed. Reconnect and reload before retrying."
        } catch PlanRecordRepositoryError.versionConflict(_, _) {
            guard isCurrent(request, member: member) else { return }
            childrenPhase = .failed("Reload plan details before continuing.")
            actionMessage = "Someone else changed this plan. Reload before trying again."
        } catch {
            guard isCurrent(request, member: member) else { return }
            childrenPhase = .failed("Reload plan details before continuing.")
            actionMessage = "The plan could not be changed."
        }
    }
}
