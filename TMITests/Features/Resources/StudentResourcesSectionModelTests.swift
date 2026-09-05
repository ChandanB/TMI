import Foundation
import Testing
@testable import TMI

@MainActor
struct StudentResourcesSectionModelTests {
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

    @Test("Load populates assigned and library from the repository")
    func loadPopulatesAssignedAndLibrary() async throws {
        let repository = FakeResourceRepository()
        repository.libraryResult = [resource(id: "lib-1"), resource(id: "lib-2")]
        repository.studentResourcesResult = [resource(id: "lib-1")]

        let model = StudentResourcesSectionModel(repository: repository)
        await model.load(studentID: "student-1", member: member)

        #expect(model.assigned.map(\.id) == ["lib-1"])
        #expect(model.library.map(\.id) == ["lib-1", "lib-2"])
        #expect(model.errorMessage == nil)
        #expect(repository.studentResourcesCalls.count == 1)
        #expect(repository.studentResourcesCalls.first?.studentID == "student-1")
        #expect(repository.studentResourcesCalls.first?.member == member)
        #expect(repository.libraryCalls == [member])
    }

    @Test("Load sets errorMessage and leaves lists empty when the repository throws")
    func loadSetsErrorMessageOnThrow() async throws {
        let repository = FakeResourceRepository()
        repository.libraryError = ResourceRepositoryError.permissionDenied
        repository.studentResourcesError = ResourceRepositoryError.permissionDenied

        let model = StudentResourcesSectionModel(repository: repository)
        await model.load(studentID: "student-1", member: member)

        #expect(model.assigned.isEmpty)
        #expect(model.library.isEmpty)
        #expect(model.errorMessage != nil)
    }

    @Test("AssignFromLibrary calls repository.assign with the right args and refreshes assigned")
    func assignFromLibraryRefreshesAssigned() async throws {
        let repository = FakeResourceRepository()
        repository.libraryResult = [resource(id: "lib-1")]
        repository.studentResourcesResult = []

        let model = StudentResourcesSectionModel(repository: repository)
        await model.load(studentID: "student-1", member: member)
        #expect(model.assigned.isEmpty)

        repository.studentResourcesResult = [resource(id: "lib-1")]
        await model.assignFromLibrary(resourceID: "lib-1", studentID: "student-1", member: member)

        #expect(repository.assignCalls.count == 1)
        let call = try #require(repository.assignCalls.first)
        #expect(call.resourceID == "lib-1")
        #expect(call.studentID == "student-1")
        #expect(call.member == member)
        #expect(model.assigned.map(\.id) == ["lib-1"])
        #expect(model.errorMessage == nil)
    }

    @Test("AssignFromLibrary sets errorMessage when the repository throws")
    func assignFromLibrarySetsErrorMessageOnThrow() async throws {
        let repository = FakeResourceRepository()
        repository.assignError = ResourceRepositoryError.permissionDenied

        let model = StudentResourcesSectionModel(repository: repository)
        await model.assignFromLibrary(resourceID: "lib-1", studentID: "student-1", member: member)

        #expect(model.errorMessage != nil)
    }
}

@MainActor
private final class FakeResourceRepository: ResourceRepository {
    var libraryResult: [Resource] = []
    var studentResourcesResult: [Resource] = []
    var libraryError: Error?
    var studentResourcesError: Error?
    var assignError: Error?

    private(set) var libraryCalls: [MembershipContext] = []
    private(set) var studentResourcesCalls: [(studentID: String, member: MembershipContext)] = []
    private(set) var assignCalls: [(resourceID: String, studentID: String, member: MembershipContext)] = []

    func library(member: MembershipContext) async throws -> [Resource] {
        libraryCalls.append(member)
        if let libraryError { throw libraryError }
        return libraryResult
    }

    func studentResources(studentID: String, member: MembershipContext) async throws -> [Resource] {
        studentResourcesCalls.append((studentID: studentID, member: member))
        if let studentResourcesError { throw studentResourcesError }
        return studentResourcesResult
    }

    func create(_ resource: Resource, member: MembershipContext) async throws -> Resource {
        resource
    }

    func assign(resourceID: String, toStudent studentID: String, member: MembershipContext) async throws {
        assignCalls.append((resourceID: resourceID, studentID: studentID, member: member))
        if let assignError { throw assignError }
    }

    func linkToPlan(resourceID: String, planID: String, member: MembershipContext) async throws {}
}
