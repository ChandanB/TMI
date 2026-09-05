import Foundation
import Testing
@testable import TMI

@MainActor
struct PlanResourcesSectionModelTests {
    private let member = MembershipContext(
        userID: "teacher-1", districtID: "district-1", schoolIDs: ["school-1"],
        role: .teacher, capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: ["student-1"], isActive: true, version: 1
    )

    private func resource(id: String) -> Resource {
        var resource = Resource.sampleResources[0]
        resource.id = id
        return resource
    }

    @Test("Load populates linked and library from the repository")
    func loadPopulatesLinkedAndLibrary() async throws {
        let repository = FakeResourceRepository()
        repository.libraryResult = [resource(id: "lib-1"), resource(id: "lib-2")]
        repository.planResourcesResult = [resource(id: "lib-1")]

        let model = PlanResourcesSectionModel(repository: repository)
        await model.load(planID: "plan-1", member: member)

        #expect(model.linked.map(\.id) == ["lib-1"])
        #expect(model.library.map(\.id) == ["lib-1", "lib-2"])
        #expect(model.errorMessage == nil)
        #expect(repository.planResourcesCalls.count == 1)
        #expect(repository.planResourcesCalls.first?.planID == "plan-1")
        #expect(repository.planResourcesCalls.first?.member == member)
        #expect(repository.libraryCalls == [member])
    }

    @Test("Load sets errorMessage and leaves lists empty when the repository throws")
    func loadSetsErrorMessageOnThrow() async throws {
        let repository = FakeResourceRepository()
        repository.libraryError = ResourceRepositoryError.permissionDenied
        repository.planResourcesError = ResourceRepositoryError.permissionDenied

        let model = PlanResourcesSectionModel(repository: repository)
        await model.load(planID: "plan-1", member: member)

        #expect(model.linked.isEmpty)
        #expect(model.library.isEmpty)
        #expect(model.errorMessage != nil)
    }

    @Test("LinkFromLibrary calls repository.linkToPlan with the right args and refreshes linked")
    func linkFromLibraryRefreshesLinked() async throws {
        let repository = FakeResourceRepository()
        repository.libraryResult = [resource(id: "lib-1")]
        repository.planResourcesResult = []

        let model = PlanResourcesSectionModel(repository: repository)
        await model.load(planID: "plan-1", member: member)
        #expect(model.linked.isEmpty)

        repository.planResourcesResult = [resource(id: "lib-1")]
        await model.linkFromLibrary(resourceID: "lib-1", planID: "plan-1", member: member)

        #expect(repository.linkToPlanCalls.count == 1)
        let call = try #require(repository.linkToPlanCalls.first)
        #expect(call.resourceID == "lib-1")
        #expect(call.planID == "plan-1")
        #expect(call.member == member)
        #expect(model.linked.map(\.id) == ["lib-1"])
        #expect(model.errorMessage == nil)
    }

    @Test("LinkFromLibrary sets errorMessage when the repository throws")
    func linkFromLibrarySetsErrorMessageOnThrow() async throws {
        let repository = FakeResourceRepository()
        repository.linkToPlanError = ResourceRepositoryError.permissionDenied

        let model = PlanResourcesSectionModel(repository: repository)
        await model.linkFromLibrary(resourceID: "lib-1", planID: "plan-1", member: member)

        #expect(model.errorMessage != nil)
    }
}

@MainActor
private final class FakeResourceRepository: ResourceRepository {
    var libraryResult: [Resource] = []
    var planResourcesResult: [Resource] = []
    var libraryError: Error?
    var planResourcesError: Error?
    var linkToPlanError: Error?

    private(set) var libraryCalls: [MembershipContext] = []
    private(set) var planResourcesCalls: [(planID: String, member: MembershipContext)] = []
    private(set) var linkToPlanCalls: [(resourceID: String, planID: String, member: MembershipContext)] = []

    func library(member: MembershipContext) async throws -> [Resource] {
        libraryCalls.append(member)
        if let libraryError { throw libraryError }
        return libraryResult
    }

    func studentResources(studentID: String, member: MembershipContext) async throws -> [Resource] {
        []
    }

    func create(_ resource: Resource, member: MembershipContext) async throws -> Resource {
        resource
    }

    func assign(resourceID: String, toStudent studentID: String, member: MembershipContext) async throws {}

    func linkToPlan(resourceID: String, planID: String, member: MembershipContext) async throws {
        linkToPlanCalls.append((resourceID: resourceID, planID: planID, member: member))
        if let linkToPlanError { throw linkToPlanError }
    }

    func planResources(planID: String, member: MembershipContext) async throws -> [Resource] {
        planResourcesCalls.append((planID: planID, member: member))
        if let planResourcesError { throw planResourcesError }
        return planResourcesResult
    }
}
