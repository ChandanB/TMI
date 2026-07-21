import Foundation

nonisolated protocol InstitutionalSSOProvider: Sendable {
    func beginSignIn(configurationID: String) async throws -> AuthSession
}

nonisolated enum InstitutionalSSOAvailability: Sendable, Equatable {
    case unavailable
    case available
}

nonisolated enum InstitutionalSSOError: Error, Equatable {
    case unavailable
    case invalidConfiguration
}

nonisolated struct InstitutionalSSOCoordinator: Sendable {
    private let flags: FeatureFlags
    private let provider: (any InstitutionalSSOProvider)?

    init(
        flags: FeatureFlags,
        provider: (any InstitutionalSSOProvider)?
    ) {
        self.flags = flags
        self.provider = provider
    }

    var availability: InstitutionalSSOAvailability {
        flags.institutionalSSO && provider != nil ? .available : .unavailable
    }

    func beginSignIn(configurationID: String) async throws -> AuthSession {
        guard availability == .available, let provider else {
            throw InstitutionalSSOError.unavailable
        }
        let configurationID = configurationID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrustedIdentifier.isValid(configurationID) else {
            throw InstitutionalSSOError.invalidConfiguration
        }
        return try await provider.beginSignIn(configurationID: configurationID)
    }
}
