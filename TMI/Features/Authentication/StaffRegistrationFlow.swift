import Observation

@MainActor
@Observable
final class StaffRegistrationFlow {
    enum Phase: Equatable {
        case idle
        case submitting
        case recovering
        case awaitingAuthorization(userID: String)
        case failed(message: String, recoveryAvailable: Bool)
        case complete
    }

    private(set) var phase: Phase = .idle

    var isOperationActive: Bool {
        switch phase {
        case .submitting, .recovering, .awaitingAuthorization:
            true
        case .idle, .failed, .complete:
            false
        }
    }

    var recoveryAvailable: Bool {
        if case .failed(_, let recoveryAvailable) = phase {
            return recoveryAvailable
        }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message, _) = phase {
            return message
        }
        return nil
    }

    var expectedIdentityID: String? {
        if case .awaitingAuthorization(let userID) = phase {
            return userID
        }
        return nil
    }

    @discardableResult
    func submit(
        _ request: StaffRegistrationRequest,
        using authentication: any AuthenticationProviding
    ) async -> Bool {
        guard !isOperationActive, !recoveryAvailable else { return false }
        phase = .submitting
        do {
            try accept(try await authentication.register(request))
        } catch StaffInvitationProvisioningError.claimRefreshPending {
            await recover(using: authentication)
        } catch {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationMessage(for: error),
                recoveryAvailable: false
            )
        }
        return true
    }

    func retryRecovery(using authentication: any AuthenticationProviding) async {
        guard recoveryAvailable else { return }
        await recover(using: authentication)
    }

    func acceptPublishedIdentity(_ userID: String?) -> Bool {
        guard case .awaitingAuthorization(let expectedUserID) = phase,
              userID == expectedUserID else {
            return false
        }
        phase = .complete
        return true
    }

    func finishAuthorization(with userID: String?) -> Bool {
        guard case .awaitingAuthorization = phase else { return false }
        if acceptPublishedIdentity(userID) {
            return true
        }
        phase = .failed(
            message: AuthStateModel.organizationAccessErrorMessage,
            recoveryAvailable: false
        )
        return false
    }

    private func recover(using authentication: any AuthenticationProviding) async {
        phase = .recovering
        do {
            try accept(try await authentication.refresh())
        } catch StaffInvitationProvisioningError.claimRefreshPending {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationRecoveryMessage,
                recoveryAvailable: true
            )
        } catch {
            phase = .failed(
                message: AuthenticationPresentationPolicy.registrationMessage(for: error),
                recoveryAvailable: false
            )
        }
    }

    private func accept(_ session: AuthSession) throws {
        guard let userID = session.identity?.userID,
              !userID.isEmpty else {
            throw AuthenticationRepositoryError.registrationRollbackFailed
        }
        phase = .awaitingAuthorization(userID: userID)
    }
}
