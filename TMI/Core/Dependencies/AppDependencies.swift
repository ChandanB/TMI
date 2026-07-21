import FirebaseFirestore
import SwiftUI

nonisolated struct AppDependencies: Sendable {
    enum Runtime: Sendable, Equatable {
        case production
        case preview
        case unconfigured
    }

    let runtime: Runtime
    let flags: FeatureFlags
    let membership: any MembershipProviding
    let logger: TMILogger

    static func production(firestore: Firestore) -> AppDependencies {
        production(
            membershipStore: FirebaseMembershipStore(firestore: firestore)
        )
    }

    static func production(
        membershipStore: any MembershipStore
    ) -> AppDependencies {
        AppDependencies(
            runtime: .production,
            flags: .production,
            membership: MembershipRepository(store: membershipStore),
            logger: .production
        )
    }

    static func preview(
        memberships: [MembershipContext] = []
    ) -> AppDependencies {
        AppDependencies(
            runtime: .preview,
            flags: .production,
            membership: InMemoryMembershipProvider(memberships: memberships),
            logger: TMILogger(category: "Preview")
        )
    }

    /// A fail-closed default for views rendered without the application root.
    static let unconfigured = AppDependencies(
        runtime: .unconfigured,
        flags: .production,
        membership: UnavailableMembershipProvider(),
        logger: .production
    )
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies = .unconfigured
}

nonisolated struct InMemoryMembershipProvider: MembershipProviding {
    private struct Key: Hashable, Sendable {
        let userID: String
        let districtID: String
    }

    private let memberships: [Key: MembershipContext]

    init(memberships: [MembershipContext]) {
        self.memberships = Dictionary(
            uniqueKeysWithValues: memberships.map {
                (Key(userID: $0.userID, districtID: $0.districtID), $0)
            }
        )
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        guard claim.accessClass == .staff else {
            throw MembershipRepositoryError.invalidClaim
        }

        let key = Key(userID: claim.userID, districtID: claim.districtID)
        guard let membership = memberships[key] else {
            throw MembershipRepositoryError.notFound
        }
        guard membership.isActive else {
            throw MembershipRepositoryError.inactive
        }
        guard membership.version == claim.membershipVersion else {
            throw MembershipRepositoryError.versionMismatch
        }
        return membership
    }
}

nonisolated private struct UnavailableMembershipProvider: MembershipProviding {
    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        throw MembershipRepositoryError.unavailable
    }
}
