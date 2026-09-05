import Foundation

/// Backs `StudentResourceListSection`: loads the resources already assigned to
/// a student plus the district library, and assigns a library resource to the
/// student. There is no unassign/remove path here — `ResourceRepository` does
/// not expose one (that's tracked separately, not part of this task).
@MainActor
@Observable
final class StudentResourcesSectionModel {
    private let repository: any ResourceRepository

    private(set) var assigned: [Resource] = []
    private(set) var library: [Resource] = []
    var errorMessage: String?
    private(set) var isLoading = false

    init(repository: any ResourceRepository) {
        self.repository = repository
    }

    func load(studentID: String, member: MembershipContext) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let assignedResources = repository.studentResources(studentID: studentID, member: member)
            async let libraryResources = repository.library(member: member)
            let (assignedResult, libraryResult) = try await (assignedResources, libraryResources)
            assigned = assignedResult
            library = libraryResult
            errorMessage = nil
        } catch {
            assigned = []
            library = []
            errorMessage = "Resources could not be loaded. Try again."
        }
    }

    func assignFromLibrary(resourceID: String, studentID: String, member: MembershipContext) async {
        do {
            try await repository.assign(resourceID: resourceID, toStudent: studentID, member: member)
            assigned = try await repository.studentResources(studentID: studentID, member: member)
            errorMessage = nil
        } catch {
            errorMessage = "This resource could not be assigned. Try again."
        }
    }

    func createAndAssign(_ resource: Resource, studentID: String, member: MembershipContext) async {
        do {
            let created = try await repository.create(resource, member: member)
            guard let resourceID = created.id else {
                errorMessage = "This resource could not be assigned. Try again."
                return
            }
            try await repository.assign(resourceID: resourceID, toStudent: studentID, member: member)
            library.append(created)
            assigned = try await repository.studentResources(studentID: studentID, member: member)
            errorMessage = nil
        } catch {
            errorMessage = "This resource could not be created. Try again."
        }
    }
}
