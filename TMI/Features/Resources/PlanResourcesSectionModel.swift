import Foundation

/// Backs `PlanResourceListSection`: loads the resources already linked to a
/// plan plus the district library, and links a library resource to the plan.
/// There is no unlink/remove path here — `ResourceRepository` does not expose
/// one (that's tracked separately, not part of this task).
@MainActor
@Observable
final class PlanResourcesSectionModel {
    private let repository: any ResourceRepository

    private(set) var linked: [Resource] = []
    private(set) var library: [Resource] = []
    var errorMessage: String?
    private(set) var isLoading = false

    init(repository: any ResourceRepository) {
        self.repository = repository
    }

    func load(planID: String, member: MembershipContext) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let linkedResources = repository.planResources(planID: planID, member: member)
            async let libraryResources = repository.library(member: member)
            let (linkedResult, libraryResult) = try await (linkedResources, libraryResources)
            linked = linkedResult
            library = libraryResult
            errorMessage = nil
        } catch {
            linked = []
            library = []
            errorMessage = "Resources could not be loaded. Try again."
        }
    }

    func linkFromLibrary(resourceID: String, planID: String, member: MembershipContext) async {
        do {
            try await repository.linkToPlan(resourceID: resourceID, planID: planID, member: member)
            linked = try await repository.planResources(planID: planID, member: member)
            errorMessage = nil
        } catch {
            errorMessage = "This resource could not be linked. Try again."
        }
    }
}
