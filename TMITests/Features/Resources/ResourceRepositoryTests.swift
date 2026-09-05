import Foundation
import FirebaseFirestore
import Testing
@testable import TMI

@MainActor
struct ResourceRepositoryTests {
    private let member = MembershipContext(
        userID: "teacher-1", districtID: "district-1", schoolIDs: ["school-1"],
        role: .teacher, capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: ["student-1"], isActive: true, version: 1
    )

    private func resource(id: String? = "resource-1") -> Resource {
        Resource(
            id: id,
            title: "Understanding Trauma",
            description: "A guide for educators.",
            category: .article,
            url: "https://example.com/trauma-guide",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000),
            tags: ["trauma", "guide"],
            recommendedFor: ["Teachers"],
            isFeatured: false,
            thumbnail: nil,
            scope: .district,
            districtId: nil,
            ownerUid: nil
        )
    }

    private func repository(_ transport: MemoryResourceTransport, uid: String? = "teacher-1") -> FirebaseResourceRepository {
        FirebaseResourceRepository(transport: transport, currentUserID: { uid })
    }

    @Test("Missing, wrong, and inactive identity cannot access any operation")
    func authorization() async throws {
        for uid: String? in [nil, "someone-else", "teacher-1"] {
            let transport = MemoryResourceTransport()
            let repository = FirebaseResourceRepository(transport: transport, currentUserID: { uid })
            let context = MembershipContext(
                userID: member.userID, districtID: member.districtID, schoolIDs: member.schoolIDs,
                role: member.role, capabilities: member.capabilities, assignedStudentIDs: [],
                isActive: uid != "teacher-1", version: 1
            )
            await #expect(throws: ResourceRepositoryError.permissionDenied) {
                try await repository.library(member: context)
            }
            await #expect(throws: ResourceRepositoryError.permissionDenied) {
                try await repository.studentResources(studentID: "student-1", member: context)
            }
            await #expect(throws: ResourceRepositoryError.permissionDenied) {
                _ = try await repository.create(self.resource(), member: context)
            }
            await #expect(throws: ResourceRepositoryError.permissionDenied) {
                try await repository.assign(resourceID: "resource-1", toStudent: "student-1", member: context)
            }
            await #expect(throws: ResourceRepositoryError.permissionDenied) {
                try await repository.linkToPlan(resourceID: "resource-1", planID: "plan-1", member: context)
            }
            let writeCount = transport.writeCount
            #expect(writeCount == 0)
        }
    }

    @Test("Create writes to the district-scoped resources collection with owner metadata")
    func createWritesDistrictScopedResource() async throws {
        let transport = MemoryResourceTransport()
        let repository = repository(transport)
        let created = try await repository.create(resource(id: nil), member: member)

        let writes = transport.writes
        #expect(writes.count == 1)
        let write = try #require(writes.first)
        #expect(write.path == FirestorePaths.resources(districtID: member.districtID))
        #expect(write.data["districtId"] as? String == member.districtID)
        #expect(write.data["ownerUid"] as? String == member.userID)
        #expect(write.data["title"] as? String == "Understanding Trauma")

        #expect(created.districtId == member.districtID)
        #expect(created.ownerUid == member.userID)
        #expect(created.id != nil)
        #expect(created.title == "Understanding Trauma")
    }

    @Test("Create overrides caller-supplied districtId and ownerUid")
    func createOverridesOwnership() async throws {
        let transport = MemoryResourceTransport()
        let repository = repository(transport)
        var tampered = resource(id: "resource-2")
        tampered.updatedAt = Date(timeIntervalSince1970: 2_000)
        let created = try await repository.create(tampered, member: member)
        #expect(created.districtId == member.districtID)
        #expect(created.ownerUid == member.userID)
    }

    @Test("Library returns decoded resources for the member's district")
    func libraryReturnsDecodedResources() async throws {
        let transport = MemoryResourceTransport()
        let path = FirestorePaths.resources(districtID: member.districtID)
        var data: [String: Any] = try Firestore.Encoder().encode(resource(id: nil))
        data["districtId"] = member.districtID
        data["ownerUid"] = member.userID
        transport.seed(path: path, id: "resource-1", data: data)

        let repository = repository(transport)
        let library = try await repository.library(member: member)
        #expect(library.count == 1)
        let first = try #require(library.first)
        #expect(first.id == "resource-1")
        #expect(first.title == "Understanding Trauma")
        #expect(first.districtId == member.districtID)
        #expect(first.ownerUid == member.userID)
    }

    @Test("Student resources returns decoded resources for the student's collection")
    func studentResourcesReturnsDecodedResources() async throws {
        let transport = MemoryResourceTransport()
        let path = FirestorePaths.studentResources(districtID: member.districtID, studentID: "student-1")
        var data: [String: Any] = try Firestore.Encoder().encode(resource(id: nil))
        data["districtId"] = member.districtID
        data["ownerUid"] = member.userID
        transport.seed(path: path, id: "resource-1", data: data)

        let repository = repository(transport)
        let results = try await repository.studentResources(studentID: "student-1", member: member)
        #expect(results.count == 1)
        #expect(results.first?.id == "resource-1")
    }

    @Test("Assign writes a link document under the student's resources collection")
    func assignWritesLinkDocument() async throws {
        let transport = MemoryResourceTransport()
        let repository = repository(transport)
        try await repository.assign(resourceID: "resource-1", toStudent: "student-1", member: member)

        let writes = transport.writes
        #expect(writes.count == 1)
        let write = try #require(writes.first)
        #expect(write.path == FirestorePaths.studentResources(districtID: member.districtID, studentID: "student-1"))
        #expect(write.id == "resource-1")
        #expect(write.data["resourceID"] as? String == "resource-1")
        #expect(write.data["assignedBy"] as? String == member.userID)
    }

    @Test("LinkToPlan writes a link document under the plan's resources collection")
    func linkToPlanWritesLinkDocument() async throws {
        let transport = MemoryResourceTransport()
        let repository = repository(transport)
        try await repository.linkToPlan(resourceID: "resource-1", planID: "plan-1", member: member)

        let writes = transport.writes
        #expect(writes.count == 1)
        let write = try #require(writes.first)
        #expect(write.path == FirestorePaths.planResources(districtID: member.districtID, planID: "plan-1"))
        #expect(write.id == "resource-1")
        #expect(write.data["resourceID"] as? String == "resource-1")
        #expect(write.data["linkedBy"] as? String == member.userID)
    }
}

@MainActor
private final class MemoryResourceTransport: ResourceTransport {
    private(set) var writes: [(path: String, id: String, data: [String: Any])] = []
    private var documentsByPath: [String: [(id: String, data: [String: Any])]] = [:]

    var writeCount: Int { writes.count }

    func seed(path: String, id: String, data: [String: Any]) {
        documentsByPath[path, default: []].append((id: id, data: data))
    }

    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])] {
        documentsByPath[path] ?? []
    }

    func setDocument(collectionPath: String, id: String, data: [String: Any]) async throws {
        writes.append((path: collectionPath, id: id, data: data))
        documentsByPath[collectionPath, default: []].append((id: id, data: data))
    }
}
