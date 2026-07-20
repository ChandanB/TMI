//
//  DeleteAccountView.swift
//  TMI
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.dismiss) private var dismiss

    enum DeletionStep {
        case warning
        case confirm
    }

    @State private var step: DeletionStep = .warning
    @State private var password: String = ""
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingSignOutFailure = false
    @State private var accountDeletionCompleted = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundColor(.tmiTextSecondary)
                        .padding()
                        .disabled(isDeleting)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)

                            Text("Delete Account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.tmiTextPrimary)
                        }
                        .padding(.top, 8)

                        if step == .warning {
                            warningContent
                        } else {
                            confirmContent
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Couldn’t Sign Out", isPresented: $showingSignOutFailure) {
            Button("Retry", action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your account is still signed in. Check your connection and try again.")
        }
    }

    // MARK: - Warning Step

    private var warningContent: some View {
        VStack(spacing: 20) {
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This will permanently delete:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.tmiTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        consequenceRow(
                            icon: "person.fill",
                            text: "Personal profile and preferences",
                            color: .red
                        )
                        consequenceRow(
                            icon: "heart.fill",
                            text: "Personal interests, activity, and saved resources",
                            color: .red
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Institutional records retained")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.tmiTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        consequenceRow(
                            icon: "person.2.fill",
                            text: "Student records and TMI plans",
                            color: .tmiSecondary
                        )
                        consequenceRow(
                            icon: "building.2.fill",
                            text: "School forms, meetings, consents, and audit records",
                            color: .tmiSecondary
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            Text("This action cannot be undone.")
                .font(.system(size: 14))
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            TMIButton(text: "Continue", style: .primary) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    step = .confirm
                }
            }

            Button("Cancel") { dismiss() }
                .font(.system(size: 16))
                .foregroundColor(.tmiTextSecondary)
        }
    }

    private func consequenceRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.tmiTextPrimary)
        }
    }

    // MARK: - Confirm Step

    private var confirmContent: some View {
        VStack(spacing: 20) {
            Text("Enter your password to confirm deletion.")
                .font(.system(size: 15))
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            TMICard(style: .default) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .font(.system(size: 16))
                    .foregroundColor(.tmiTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .disabled(isDeleting || accountDeletionCompleted)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            TMIButton(
                text: accountDeletionCompleted ? "Retry Sign Out" : "Permanently Delete Account",
                style: .destructive,
                isLoading: isDeleting,
                isDisabled: !accountDeletionCompleted
                    && password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task {
                    if accountDeletionCompleted {
                        attemptSignOut()
                    } else {
                        await deleteAccount()
                    }
                }
            }
            .accessibilityLabel(
                accountDeletionCompleted ? "Retry Sign Out" : "Permanently Delete Account"
            )
            .accessibilityValue(isDeleting ? "Deleting account" : "")

            Button("Go Back") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    errorMessage = nil
                    step = .warning
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.tmiTextSecondary)
            .disabled(isDeleting || accountDeletionCompleted)
        }
    }

    // MARK: - Deletion Logic

    @MainActor
    private func attemptSignOut() {
        guard authStateModel.signOut() else {
            showingSignOutFailure = true
            return
        }
    }

    @MainActor
    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await AccountDeletionService.shared.deleteAccount(password: password)
            password = ""
            accountDeletionCompleted = true
            attemptSignOut()
        } catch let error as AccountDeletionError {
            withAnimation {
                if error == .incorrectPassword {
                    errorMessage = "Incorrect password. Please try again."
                } else {
                    errorMessage = "Deletion failed. Check your connection and try again."
                }
            }
        } catch {
            withAnimation { errorMessage = "Deletion failed. Check your connection and try again." }
        }
    }
}

#Preview {
    DeleteAccountView()
}
