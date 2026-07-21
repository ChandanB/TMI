import Foundation

nonisolated protocol AuthorizationSessionProviding: Sendable {
    func session(authenticatedUserID: String?) -> AuthenticatedSession?
}

/// Thread-safe bridge from the authenticated composition root to legacy
/// services while repositories are migrated to explicit dependency injection.
/// Services can read a complete trusted session but cannot construct one from a
/// profile or partially publish authorization state.
nonisolated final class TrustedAuthorizationSessionStore: AuthorizationSessionProviding, @unchecked Sendable {
    static let shared = TrustedAuthorizationSessionStore()

    private typealias SessionUpdateContinuation =
        AsyncStream<AuthenticatedSession>.Continuation

    private let lock = NSLock()
    private var storedSession: AuthenticatedSession?
    private var sessionUpdateContinuations: [UUID: SessionUpdateContinuation] = [:]

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
        guard storedSession != session else {
            lock.unlock()
            return
        }
        storedSession = session
        let continuations = Array(sessionUpdateContinuations.values)
        lock.unlock()

        continuations.forEach { continuation in
            continuation.yield(session)
        }
    }

    func clear() {
        lock.lock()
        storedSession = nil
        lock.unlock()
    }

    /// Delivers the current trusted session, when present, followed by future
    /// publications. Clearing the bridge does not emit an authorization event;
    /// identity changes remain the authentication model's responsibility.
    func sessionUpdates() -> AsyncStream<AuthenticatedSession> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let continuationID = UUID()
            continuation.onTermination = { [weak self] _ in
                self?.removeSessionUpdateContinuation(id: continuationID)
            }

            self.lock.lock()
            self.sessionUpdateContinuations[continuationID] = continuation
            let currentSession = self.storedSession
            self.lock.unlock()

            if let currentSession {
                continuation.yield(currentSession)
            }
        }
    }

    private func removeSessionUpdateContinuation(id: UUID) {
        lock.lock()
        sessionUpdateContinuations.removeValue(forKey: id)
        lock.unlock()
    }
}
