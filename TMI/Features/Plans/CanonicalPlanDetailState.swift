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

    init(
        planID: String,
        repository: any PlanRecordRepository,
        children: (any PlanChildRepositoryProtocol)? = nil
    ) {
        self.planID = planID
        self.repository = repository
        self.children = children
    }

    /// The share of due actions actually done, which an educator can recount
    /// by hand.
    var completionPercentage: Int { PlanCompletion.percentage(of: actions) }

    func reloadChildren(member: MembershipContext) async {
        goals = (try? await children?.goals(planID: planID, member: member)) ?? goals
        actions = (try? await children?.actions(planID: planID, member: member)) ?? actions
        progress = (try? await children?.progress(planID: planID, member: member)) ?? progress
    }

    var plan: PlanRecord? {
        if case .loaded(let plan) = phase { return plan }
        return nil
    }

    func load(member: MembershipContext) async {
        do {
            phase = .loaded(try await repository.plan(id: planID, member: member))
            // A history that fails to load must not read as a plan with no
            // history, so an empty list here is only ever the real answer.
            revisions = (try? await children?.revisions(planID: planID, member: member)) ?? []
            goals = (try? await children?.goals(planID: planID, member: member)) ?? []
            actions = (try? await children?.actions(planID: planID, member: member)) ?? []
            progress = (try? await children?.progress(planID: planID, member: member)) ?? []
        } catch PlanRecordRepositoryError.permissionDenied {
            phase = .permissionDenied
        } catch PlanRecordRepositoryError.unavailable {
            phase = .failed("You appear to be offline. This plan will load when you reconnect.")
        } catch {
            phase = .failed("This plan could not be loaded.")
        }
    }

    /// The transitions this member may actually perform right now.
    ///
    /// The lifecycle table says what is legal for the plan; the member's
    /// capabilities say what is theirs to do. Both have to agree, and the
    /// rules refuse anything these two miss.
    func availableTransitions(for member: MembershipContext) -> [PlanRecordStatus] {
        guard let plan else { return [] }
        return PlanLifecycle.allowedTransitions(from: plan.status)
            .filter { status in
                switch status {
                // Putting a plan into effect for a child is an approval, not an
                // edit, so it needs approval authority.
                case .active where plan.status == .pendingApproval:
                    member.capabilities.contains(.planApprove)
                case .changesRequested:
                    member.capabilities.contains(.planApprove)
                default:
                    member.capabilities.contains(.studentWriteDetail)
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
    }

    func transition(
        to status: PlanRecordStatus,
        member: MembershipContext
    ) async {
        guard let plan, !isMutating else { return }
        isMutating = true
        actionMessage = nil
        defer { isMutating = false }
        do {
            let updated = try await repository.transition(
                id: plan.id,
                to: status,
                expectedVersion: plan.metadata.recordVersion,
                member: member
            )
            phase = .loaded(updated)
            actionMessage = "Moved to \(status.displayName.lowercased())."
        } catch PlanRecordRepositoryError.permissionDenied {
            actionMessage = "You do not have access to change this plan."
        } catch PlanRecordRepositoryError.unavailable {
            actionMessage = "You appear to be offline. Nothing was changed."
        } catch PlanRecordRepositoryError.versionConflict(_, _) {
            actionMessage = "Someone else changed this plan. Reload before trying again."
        } catch {
            actionMessage = "The plan could not be changed."
        }
    }
}
