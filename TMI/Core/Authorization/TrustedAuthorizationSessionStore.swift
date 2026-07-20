import Foundation

protocol AuthorizationSessionProviding: Sendable {
    func session(authenticatedUserID: String?) -> AuthenticatedSession?
}

/// Thread-safe bridge from the authenticated composition root to legacy
/// services while repositories are migrated to explicit dependency injection.
/// Services can read a complete trusted session but cannot construct one from a
/// profile or partially publish authorization state.
final class TrustedAuthorizationSessionStore: AuthorizationSessionProviding, @unchecked Sendable {
    static let shared = TrustedAuthorizationSessionStore()

    private let lock = NSLock()
    private var storedSession: AuthenticatedSession?

    init() {}

    func session(authenticatedUserID: String?) -> AuthenticatedSession? {
        guard let authenticatedUserID else {
            return nil
        }

        lock.lock()
        let session = storedSession
        lock.unlock()

        guard let session,
              session.profile.userID == authenticatedUserID,
              session.claim.userID == authenticatedUserID,
              session.membership.userID == authenticatedUserID,
              session.claim.districtID == session.membership.districtID,
              session.claim.membershipVersion == session.membership.version,
              session.membership.isActive else {
            return nil
        }

        return session
    }

    func publish(_ session: AuthenticatedSession) {
        lock.lock()
        storedSession = session
        lock.unlock()
    }

    func clear() {
        lock.lock()
        storedSession = nil
        lock.unlock()
    }
}
