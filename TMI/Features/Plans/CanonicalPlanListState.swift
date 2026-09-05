import Foundation
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
    private let studentID: String?
    private var generation = UUID()

    init(repository: any PlanRecordRepository, studentID: String? = nil) {
        self.studentID = studentID
        self.repository = repository
    }

    var visiblePlans: [PlanRecord] {
        guard case .loaded(let plans) = phase else { return [] }
        return showOpenOnly ? plans.filter { $0.status.isOpen } : plans
    }

    func load(member: MembershipContext) async {
        generation = UUID()
        let request = generation
        phase = .loading
        do {
            let records = try await repository.plans(member: member)
            guard request == generation, !Task.isCancelled else { return }
            let plans = records.filter { self.studentID == nil || $0.studentIDs.contains(self.studentID ?? "") }
            phase = plans.isEmpty ? .empty : .loaded(plans)
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
            // Someone else moved it first; the reload shows where it landed.
            phase = .failed("That plan changed somewhere else. Reloading.")
            await load(member: member)
        } catch {
            phase = .failed("That change could not be saved.")
        }
    }
}
