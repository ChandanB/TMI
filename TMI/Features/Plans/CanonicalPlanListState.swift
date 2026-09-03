import Observation

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
    var showOpenOnly = true

    private let repository: any PlanRecordRepository

    init(repository: any PlanRecordRepository) {
        self.repository = repository
    }

    var visiblePlans: [PlanRecord] {
        guard case .loaded(let plans) = phase else { return [] }
        return showOpenOnly ? plans.filter { $0.status.isOpen } : plans
    }

    func load(member: MembershipContext) async {
        if case .loaded = phase {} else { phase = .loading }
        do {
            let plans = try await repository.plans(member: member)
            phase = plans.isEmpty ? .empty : .loaded(plans)
        } catch PlanRecordRepositoryError.permissionDenied {
            phase = .permissionDenied
        } catch PlanRecordRepositoryError.unavailable {
            phase = .failed("You appear to be offline. Plans will load when you reconnect.")
        } catch {
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
            // Someone else moved it first; the reload shows where it landed.
            phase = .failed("That plan changed somewhere else. Reloading.")
            await load(member: member)
        } catch {
            phase = .failed("That change could not be saved.")
        }
    }
}
