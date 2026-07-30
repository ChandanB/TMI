import SwiftUI

struct StaffAccessSetupView: View {
    @Environment(\.authStateModel) private var authStateModel

    @State private var displayName = ""
    @State private var invitationCode = ""
    @State private var signOutErrorMessage: String?
    @State private var isShowingSignOutError = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .auth)

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(TMIColors.teal)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text("Set Up Staff Access")
                            .font(.largeTitle.bold())
                            .foregroundStyle(TMIColors.aubergine)
                            .multilineTextAlignment(.center)

                        Text(
                            "Enter your name and the invitation code provided by your school or district."
                        )
                        .font(.body)
                        .foregroundStyle(Color.tmiTextSecondary)
                        .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        TMITextField(
                            icon: "person.fill",
                            placeholder: "Full name",
                            text: $displayName
                        )
                        .textContentType(.name)
                        .accessibilityLabel("Full name")
                        .accessibilityIdentifier("authentication.accessSetup.name")

                        TMITextField(
                            icon: "key.fill",
                            placeholder: "Invitation code",
                            text: $invitationCode
                        )
                        .textContentType(.oneTimeCode)
                        .accessibilityLabel("Staff invitation code")
                        .accessibilityIdentifier("authentication.accessSetup.invitation")

                        if let message = authStateModel.currentError?.message {
                            Text(message)
                                .font(.callout)
                                .foregroundStyle(Color.tmiError)
                                .accessibilityLabel("Staff access error: \(message)")
                        }
                    }

                    VStack(spacing: 12) {
                        TMIButton(
                            text: "Continue",
                            icon: "arrow.right",
                            style: .primary,
                            isLoading: authStateModel.isCompletingStaffAccessSetup,
                            isDisabled: authStateModel.isCompletingStaffAccessSetup
                        ) {
                            completeSetup()
                        }
                        .accessibilityIdentifier("authentication.accessSetup.submit")

                        TMIButton(
                            text: "Sign Out",
                            style: .secondary,
                            isDisabled: authStateModel.isCompletingStaffAccessSetup
                        ) {
                            signOut()
                        }
                        .accessibilityIdentifier("authentication.accessSetup.signOut")
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("authentication.accessSetup.screen")
        .alert("Unable to Sign Out", isPresented: $isShowingSignOutError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(signOutErrorMessage ?? "We couldn’t sign you out. Please try again.")
        }
    }

    private func completeSetup() {
        Task { @MainActor in
            await self.authStateModel.completeStaffAccessSetup(
                displayName: self.displayName,
                invitationCode: self.invitationCode
            )
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
    StaffAccessSetupView()
        .environment(\.authStateModel, AuthStateModel(automaticallyStart: false))
}
