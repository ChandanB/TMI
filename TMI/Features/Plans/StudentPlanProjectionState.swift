import Observation

@MainActor
@Observable
final class StudentPlanProjectionState {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded([StudentPlanProjection])
        case unavailable
        case failed
    }

    private(set) var phase: Phase = .idle
    private let repository: StudentPlanProjectionRepository
    private var requestKey: String?

    init(repository: StudentPlanProjectionRepository) {
        self.repository = repository
    }

    func load(grant: StudentModeGrant) async {
        let key = Self.key(for: grant)
        requestKey = key

        guard grant.scope.allowedOperations.contains(.readStudentVisiblePlan) else {
            phase = .unavailable
            return
        }
        phase = .loading
        do {
            let projections = try await repository.projections(grant: grant)
            guard requestKey == key else { return }
            phase = .loaded(projections)
        } catch StudentPlanProjectionRepositoryError.capabilityUnavailable {
            guard requestKey == key else { return }
            phase = .unavailable
        } catch {
            guard requestKey == key else { return }
            phase = .failed
        }
    }

    func clear() {
        requestKey = nil
        phase = .idle
    }

    private static func key(for grant: StudentModeGrant) -> String {
        "\(grant.sessionID):\(grant.scope.studentID):\(grant.recordVersion)"
    }
}
