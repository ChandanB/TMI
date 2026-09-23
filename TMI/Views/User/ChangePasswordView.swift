//
//  ChangePasswordView.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import SwiftUI
import FirebaseAuth

/// Changes the signed-in staff member's password.
///
/// Field state is local to the view. (The previous state model started idle
/// and was never loaded, so every keystroke was dropped.)
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    private let firebaseManager: FirebaseManager

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case current, new, confirm }

    init(firebaseManager: FirebaseManager = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
    }

    private var newIsLongEnough: Bool { newPassword.count >= 8 }
    private var confirmationMatches: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }
    private var isFormValid: Bool { !currentPassword.isEmpty && newIsLongEnough && confirmationMatches }

    var body: some View {
        Form {
            Section {
                SecureField("Current password", text: $currentPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .current)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .new }
                    .accessibilityIdentifier("changePassword.current")
            }

            Section {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .new)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }
                    .accessibilityIdentifier("changePassword.new")
                SecureField("Confirm new password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirm)
                    .submitLabel(.done)
                    .onSubmit { Task { await save() } }
                    .accessibilityIdentifier("changePassword.confirm")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    requirement("At least 8 characters", met: newIsLongEnough)
                    requirement("Both new passwords match", met: confirmationMatches)
                }
                .padding(.top, 4)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(TMIColors.errorText)
                        .accessibilityIdentifier("changePassword.error")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .tmiScreenBackground()
        .disabled(isSaving)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .disabled(!isFormValid)
                        .accessibilityIdentifier("changePassword.save")
                }
            }
        }
        .onAppear { focusedField = .current }
        .alert("Password Updated", isPresented: $didSucceed) {
            Button("OK") { dismiss() }
        } message: {
            Text("Use your new password the next time you sign in.")
        }
        .sensoryFeedback(.success, trigger: didSucceed)
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
    }

    private func requirement(_ text: String, met: Bool) -> some View {
        Label(text, systemImage: met ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(met ? TMIColors.successText : TMIColors.textTertiary)
            .contentTransition(.symbolEffect(.replace))
            .animation(TMIAnimation.snappy, value: met)
    }

    private func save() async {
        guard isFormValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await firebaseManager.reauthenticate(with: currentPassword)
            guard let user = Auth.auth().currentUser else {
                errorMessage = "You're signed out. Sign in again, then change your password."
                return
            }
            try await user.updatePassword(to: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            didSucceed = true
        } catch {
            // Keep what was typed; only the current password is usually wrong.
            errorMessage = "Your current password wasn't accepted, or the new one was rejected. Check them and try again."
            focusedField = .current
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
