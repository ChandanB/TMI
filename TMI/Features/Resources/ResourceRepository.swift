import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ResourceRepositoryError: Error, Equatable {
    case permissionDenied
    case notFound
    case decodingFailed
    case encodingFailed
}

@MainActor
protocol ResourceRepository: Sendable {
    func library(member: MembershipContext) async throws -> [Resource]
    func studentResources(studentID: String, member: MembershipContext) async throws -> [Resource]
    func create(_ resource: Resource, member: MembershipContext) async throws -> Resource
    func assign(resourceID: String, toStudent studentID: String, member: MembershipContext) async throws
    func linkToPlan(resourceID: String, planID: String, member: MembershipContext) async throws
}

/// Transport abstraction so the repository is unit-testable in memory (mirrors CanonicalPlanTransport).
@MainActor
protocol ResourceTransport {
    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])]
    func document(atCollectionPath path: String, id: String) async throws -> [String: Any]?
    func setDocument(collectionPath: String, id: String, data: [String: Any], merge: Bool) async throws
}

@MainActor
final class FirebaseResourceRepository: ResourceRepository {
    private let transport: any ResourceTransport
    private let currentUserID: @Sendable () -> String?

    init(
        transport: any ResourceTransport = FirebaseResourceTransport(),
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.transport = transport
        self.currentUserID = currentUserID
    }

    func library(member: MembershipContext) async throws -> [Resource] {
        try authorize(member)
        let documents = try await transport.documents(atCollectionPath: FirestorePaths.resources(districtID: member.districtID))
        return try documents.map { try Self.decode(id: $0.id, data: $0.data, member: member) }
    }

    func studentResources(studentID: String, member: MembershipContext) async throws -> [Resource] {
        try authorize(member)
        let path = FirestorePaths.studentResources(districtID: member.districtID, studentID: studentID)
        let documents = try await transport.documents(atCollectionPath: path)
        return try documents.map { try Self.decode(id: $0.id, data: $0.data, member: member) }
    }

    func create(_ resource: Resource, member: MembershipContext) async throws -> Resource {
        try authorize(member)
        let id = resource.id ?? UUID().uuidString
        var data: [String: Any]
        do {
            data = try Firestore.Encoder().encode(resource)
        } catch {
            throw ResourceRepositoryError.encodingFailed
        }
        data["districtId"] = member.districtID
        data["ownerUid"] = member.userID
        try await transport.setDocument(
            collectionPath: FirestorePaths.resources(districtID: member.districtID),
            id: id,
            data: data,
            merge: false
        )
        return try Self.decode(id: id, data: data, member: member)
    }

    func assign(resourceID: String, toStudent studentID: String, member: MembershipContext) async throws {
        try authorize(member)
        guard let resourceData = try await transport.document(
            atCollectionPath: FirestorePaths.resources(districtID: member.districtID),
            id: resourceID
        ) else {
            throw ResourceRepositoryError.notFound
        }
        // Decode-then-reencode would drop unknown fields; instead denormalize the
        // raw document so studentResources() decodes the same shape as library().
        var data = resourceData
        data["districtId"] = member.districtID
        data["ownerUid"] = member.userID
        data["assignedBy"] = member.userID
        data["assignedAt"] = FieldValue.serverTimestamp()
        let path = FirestorePaths.studentResources(districtID: member.districtID, studentID: studentID)
        try await transport.setDocument(collectionPath: path, id: resourceID, data: data, merge: true)
    }

    func linkToPlan(resourceID: String, planID: String, member: MembershipContext) async throws {
        try authorize(member)
        let path = FirestorePaths.planResources(districtID: member.districtID, planID: planID)
        let data: [String: Any] = [
            "resourceID": resourceID,
            "linkedBy": member.userID,
            "linkedAt": FieldValue.serverTimestamp()
        ]
        try await transport.setDocument(collectionPath: path, id: resourceID, data: data, merge: true)
    }

    private func authorize(_ member: MembershipContext) throws {
        guard member.isActive, !member.userID.isEmpty, !member.districtID.isEmpty,
              currentUserID() == member.userID else {
            throw ResourceRepositoryError.permissionDenied
        }
    }

    private static func decode(id: String, data: [String: Any], member: MembershipContext) throws -> Resource {
        do {
            var resource = try Firestore.Decoder().decode(Resource.self, from: data)
            if resource.id == nil {
                resource.id = id
            }
            // Tolerate nil districtId (global/public resources); a mismatched
            // non-nil districtId means the document does not belong to this caller.
            if let districtId = resource.districtId, districtId != member.districtID {
                throw ResourceRepositoryError.decodingFailed
            }
            return resource
        } catch let error as ResourceRepositoryError {
            throw error
        } catch {
            throw ResourceRepositoryError.decodingFailed
        }
    }
}

@MainActor
final class FirebaseResourceTransport: ResourceTransport {
    init() {}

    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])] {
        let snapshot = try await Firestore.firestore().collection(path).getDocuments()
        return snapshot.documents.map { (id: $0.documentID, data: $0.data()) }
    }

    func document(atCollectionPath path: String, id: String) async throws -> [String: Any]? {
        try await Firestore.firestore().collection(path).document(id).getDocument().data()
    }

    func setDocument(collectionPath: String, id: String, data: [String: Any], merge: Bool = true) async throws {
        try await Firestore.firestore().collection(collectionPath).document(id).setData(data, merge: merge)
    }
}
