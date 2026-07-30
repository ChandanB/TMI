import SwiftUI

struct AuthenticationRecoveryView: View {
    @Environment(\.authStateModel) private var authStateModel

    @State private var isRetrying = false
    @State private var signOutErrorMessage: String?
    @State private var isShowingSignOutError = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .auth)

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(TMIColors.aubergine)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("We couldn’t verify your organization access")
                            .font(.title2.bold())
                            .foregroundStyle(TMIColors.aubergine)
                            .multilineTextAlignment(.center)

                        Text("Check your connection and try again. You can also sign out to use a different account.")
                            .font(.body)
                            .foregroundStyle(Color.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        TMIButton(
                            text: "Try Again",
                            icon: "arrow.clockwise",
                            style: .primary,
                            isLoading: isRetrying,
                            isDisabled: isRetrying
                        ) {
                            retryAuthorization()
                        }
                        .accessibilityIdentifier("authentication.recovery.retry")

                        TMIButton(
                            text: "Sign Out",
                            style: .secondary,
                            isDisabled: isRetrying
                        ) {
                            signOut()
                        }
                        .accessibilityIdentifier("authentication.recovery.signOut")
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("authentication.recovery.screen")
        .alert("Unable to Sign Out", isPresented: $isShowingSignOutError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(signOutErrorMessage ?? "We couldn’t sign you out. Please try again.")
        }
    }

    private func retryAuthorization() {
        signOutErrorMessage = nil
        isRetrying = true

        Task { @MainActor in
            await self.authStateModel.retryAuthorization()
            self.isRetrying = false
        }
    }

    private func signOut() {
        signOutErrorMessage = nil
        guard authStateModel.signOut() else {
            signOutErrorMessage = authStateModel.currentError?.message
                ?? "We couldn’t sign you out. Please try again."
            isShowingSignOutError = true
            return
        }
    }
}

#Preview {
    AuthenticationRecoveryView()
        .environment(\.authStateModel, AuthStateModel(automaticallyStart: false))
}
