import FirebaseFirestore
import Foundation

enum MembershipReadSource: Sendable, Equatable {
    case server
}

struct MembershipStoreRequest: Sendable, Equatable {
    let path: String
    let source: MembershipReadSource
}

struct MembershipStoreRecord: Codable, Sendable, Equatable {
    let schoolIDs: Set<String>
    let role: StaffRole
    let capabilities: Set<Capability>
    let assignedStudentIDs: Set<String>
    let isActive: Bool
    let version: Int
}

protocol MembershipStore: Sendable {
    func membership(for request: MembershipStoreRequest) async throws -> MembershipStoreRecord?
}

struct FirebaseMembershipStore: MembershipStore, @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func membership(for request: MembershipStoreRequest) async throws -> MembershipStoreRecord? {
        guard request.source == .server else {
            throw MembershipRepositoryError.unavailable
        }

        let snapshot = try await firestore.document(request.path).getDocument(source: .server)
        guard snapshot.exists else {
            return nil
        }
        return try snapshot.data(as: MembershipStoreRecord.self)
    }
}

protocol MembershipProviding: Sendable {
    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext
}

actor MembershipRepository: MembershipProviding {
    private struct MemberKey: Hashable, Sendable {
        let districtID: String
        let userID: String
    }

    private let store: any MembershipStore
    private var latestVersionByMember: [MemberKey: Int] = [:]

    init(store: any MembershipStore) {
        self.store = store
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        guard claim.accessClass == .staff,
              TrustedIdentifier.isValid(claim.userID),
              TrustedIdentifier.isValid(claim.districtID),
              claim.membershipVersion > 0 else {
            throw MembershipRepositoryError.invalidClaim
        }

        let request = MembershipStoreRequest(
            path: "districts/\(claim.districtID)/members/\(claim.userID)",
            source: .server
        )
        let record: MembershipStoreRecord
        do {
            guard let storedRecord = try await store.membership(for: request) else {
                throw MembershipRepositoryError.notFound
            }
            record = storedRecord
        } catch let error as MembershipRepositoryError {
            throw error
        } catch {
            throw MembershipRepositoryError.unavailable
        }

        guard record.isActive else {
            throw MembershipRepositoryError.inactive
        }
        guard record.version > 0,
              record.version == claim.membershipVersion else {
            throw MembershipRepositoryError.versionMismatch
        }
        guard record.schoolIDs.allSatisfy(TrustedIdentifier.isValid),
              record.assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid) else {
            throw MembershipRepositoryError.malformed
        }

        let memberKey = MemberKey(
            districtID: claim.districtID,
            userID: claim.userID
        )
        if let latestVersion = latestVersionByMember[memberKey],
           record.version < latestVersion {
            throw MembershipRepositoryError.stale
        }
        latestVersionByMember[memberKey] = record.version

        return MembershipContext(
            userID: claim.userID,
            districtID: claim.districtID,
            schoolIDs: record.schoolIDs,
            role: record.role,
            capabilities: record.capabilities,
            assignedStudentIDs: record.assignedStudentIDs,
            isActive: record.isActive,
            version: record.version
        )
    }
}

enum MembershipRepositoryError: Error, Equatable {
    case invalidClaim
    case notFound
    case unavailable
    case inactive
    case versionMismatch
    case malformed
    case stale
}
