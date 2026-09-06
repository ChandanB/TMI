import Foundation
import Observation

nonisolated enum CanonicalPlanListProgress: Equatable, Sendable {
    case percentage(Int)
    case unavailable
}

nonisolated enum CanonicalPlanRelationship: String, CaseIterable, Equatable, Sendable {
    case owned
    case collaborative
    case approvalAssigned

    var displayName: String {
        switch self {
        case .owned: "Owned by you"
        case .collaborative: "Collaborating"
        case .approvalAssigned: "Needs your approval"
        }
    }
}

nonisolated enum CanonicalPlanAttentionReason: String, CaseIterable, Equatable, Sendable {
    case needsApproval
    case overdueAction
    case pastTargetDate

    var displayName: String {
        switch self {
        case .needsApproval: "Needs approval"
        case .overdueAction: "Overdue action"
        case .pastTargetDate: "Past target date"
        }
    }
}

nonisolated struct CanonicalPlanListItem: Identifiable, Equatable, Sendable {
    let plan: PlanRecord
    let studentDisplayNames: [String]
    let progress: CanonicalPlanListProgress
    let relationships: Set<CanonicalPlanRelationship>
    let attentionReasons: Set<CanonicalPlanAttentionReason>
    let nextReviewDate: Date?

    var id: String { plan.id }
    var ownerMemberID: String { plan.effectiveOwnerMemberID }
}

@MainActor
@Observable
final class CanonicalPlanListState {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded([PlanRecord])
        case empty
        case failed(String)
        case permissionDenied
    }

    private(set) var phase: Phase = .idle
    private(set) var items: [CanonicalPlanListItem] = []

    var showOpenOnly = true
    var searchText = ""
    var statusFilter: PlanRecordStatus?
    var modelFilter: TMIPlanModel?
    var studentFilter: String?
    var ownerFilter: String?
    var schoolFilter: String?
    var relationshipFilter: CanonicalPlanRelationship?
    var attentionFilter: CanonicalPlanAttentionReason?

    private let repository: any PlanRecordRepository
    private let studentRepository: (any StudentRepository)?
    private let children: (any PlanChildRepositoryProtocol)?
    private let studentID: String?
    private let now: @Sendable () -> Date
    private var generation = UUID()

    init(
        repository: any PlanRecordRepository,
        studentRepository: (any StudentRepository)? = nil,
        children: (any PlanChildRepositoryProtocol)? = nil,
        studentID: String? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.studentRepository = studentRepository
        self.children = children
        self.studentID = studentID
        self.now = now
    }

    var visibleItems: [CanonicalPlanListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            let plan = item.plan
            guard !item.relationships.isEmpty else { return false }
            guard !showOpenOnly || plan.status.isOpen else { return false }
            guard statusFilter == nil || plan.status == statusFilter else { return false }
            guard modelFilter == nil || plan.model == modelFilter else { return false }
            guard studentFilter == nil || plan.studentIDs.contains(studentFilter ?? "") else { return false }
            guard ownerFilter == nil || item.ownerMemberID == ownerFilter else { return false }
            guard schoolFilter == nil || plan.schoolIDs.contains(schoolFilter ?? "") else { return false }
            if let relationshipFilter, !item.relationships.contains(relationshipFilter) { return false }
            if let attentionFilter, !item.attentionReasons.contains(attentionFilter) { return false }
            guard !query.isEmpty else { return true }
            return searchValues(for: item).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Compatibility for embedded plan surfaces that still consume the raw
    /// canonical aggregate. New list UI should prefer `visibleItems`.
    var visiblePlans: [PlanRecord] { visibleItems.map(\.plan) }

    var availableStudentIDs: [String] {
        Array(Set(items.flatMap { $0.plan.studentIDs })).sorted()
    }

    var availableOwnerIDs: [String] {
        Array(Set(items.map(\.ownerMemberID))).sorted()
    }

    var availableSchoolIDs: [String] {
        Array(Set(items.flatMap { $0.plan.schoolIDs })).sorted()
    }

    func studentName(for id: String) -> String? {
        for item in items {
            let ids = item.plan.studentIDs.sorted()
            guard let index = ids.firstIndex(of: id), item.studentDisplayNames.indices.contains(index) else {
                continue
            }
            return item.studentDisplayNames[index]
        }
        return nil
    }

    func load(member: MembershipContext) async {
        generation = UUID()
        let request = generation
        phase = .loading
        items = []

        do {
            let records = try await repository.plans(member: member)
            guard request == generation, !Task.isCancelled else { return }
            let plans = records.filter { plan in
                guard let studentID else { return true }
                return plan.studentIDs.contains(studentID)
            }

            guard !plans.isEmpty else {
                phase = .empty
                return
            }

            var projected: [CanonicalPlanListItem] = []
            projected.reserveCapacity(plans.count)
            for plan in plans {
                guard request == generation, !Task.isCancelled else { return }
                projected.append(await item(for: plan, member: member))
            }

            guard request == generation, !Task.isCancelled else { return }
            items = projected
            phase = .loaded(plans)
        } catch PlanRecordRepositoryError.permissionDenied {
            guard request == generation else { return }
            phase = .permissionDenied
        } catch PlanRecordRepositoryError.unavailable {
            guard request == generation else { return }
            phase = .failed("You appear to be offline. Plans will load when you reconnect.")
        } catch {
            guard request == generation else { return }
            phase = .failed("Plans could not be loaded. Pull to try again.")
        }
    }

    func transition(
        _ plan: PlanRecord,
        to status: PlanRecordStatus,
        member: MembershipContext
    ) async {
        do {
            _ = try await repository.transition(
                id: plan.id,
                to: status,
                expectedVersion: plan.metadata.recordVersion,
                member: member
            )
            await load(member: member)
        } catch PlanRecordRepositoryError.illegalTransition(let from, let to) {
            phase = .failed("A \(from.displayName.lowercased()) plan cannot become \(to.displayName.lowercased()).")
        } catch PlanRecordRepositoryError.versionConflict {
            phase = .failed("That plan changed somewhere else. Reloading.")
            await load(member: member)
        } catch {
            phase = .failed("That change could not be saved.")
        }
    }

    private func item(
        for plan: PlanRecord,
        member: MembershipContext
    ) async -> CanonicalPlanListItem {
        let studentNames = await studentDisplayNames(for: plan, member: member)
        let actions = await actionEvidence(for: plan, member: member)
        var relationships: Set<CanonicalPlanRelationship> = []
        var attention: Set<CanonicalPlanAttentionReason> = []

        if plan.effectiveOwnerMemberID == member.userID {
            relationships.insert(.owned)
        } else if plan.assignedMemberIDs.contains(member.userID) {
            relationships.insert(.collaborative)
        }

        if plan.status == .pendingApproval,
           plan.approverMemberIDs.contains(member.userID),
           member.capabilities.contains(.planApprove) {
            relationships.insert(.approvalAssigned)
            attention.insert(.needsApproval)
        }

        if let targetDate = plan.targetDate, plan.status.isOpen, targetDate < now() {
            attention.insert(.pastTargetDate)
        }

        let progress: CanonicalPlanListProgress
        if let actions {
            progress = .percentage(PlanCompletion.percentage(of: actions))
            if actions.contains(where: { $0.status == .open && $0.dueDate < now() }) {
                attention.insert(.overdueAction)
            }
        } else {
            progress = .unavailable
        }

        return CanonicalPlanListItem(
            plan: plan,
            studentDisplayNames: studentNames,
            progress: progress,
            relationships: relationships,
            attentionReasons: attention,
            nextReviewDate: nil
        )
    }

    private func studentDisplayNames(
        for plan: PlanRecord,
        member: MembershipContext
    ) async -> [String] {
        guard let studentRepository else { return plan.studentIDs.sorted() }
        var names: [String] = []
        for studentID in plan.studentIDs.sorted() {
            if let record = try? await studentRepository.student(id: studentID, member: member) {
                names.append(record.displayName)
            } else {
                names.append(studentID)
            }
        }
        return names
    }

    private func actionEvidence(
        for plan: PlanRecord,
        member: MembershipContext
    ) async -> [ActionRecord]? {
        guard let children else { return nil }
        return try? await children.actions(planID: plan.id, member: member)
    }

    private func searchValues(for item: CanonicalPlanListItem) -> [String] {
        let plan = item.plan
        return [
            plan.title,
            plan.summary ?? "",
            plan.model.rawValue,
            plan.status.displayName,
            item.ownerMemberID,
        ]
        + item.studentDisplayNames
        + item.attentionReasons.map(\.displayName)
        + plan.studentIDs.sorted()
        + plan.schoolIDs.sorted()
    }
}
