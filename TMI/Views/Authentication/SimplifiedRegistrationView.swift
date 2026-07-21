//
//  SimplifiedRegistrationView.swift
//  TMI
//
//  Single-page registration with Student, Staff, or Guardian selection
//

import FirebaseAuth
import SwiftUI

nonisolated enum AccountType: String, CaseIterable, Identifiable {
    case teacher = "Teacher"
    case counselor = "Counselor"
    case administrator = "Administrator"
    case socialWorker = "Social Worker"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .teacher: return "person.fill"
        case .counselor: return "brain.head.profile"
        case .administrator: return "person.badge.key.fill"
        case .socialWorker: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .teacher: return .blue
        case .counselor: return .purple
        case .administrator: return .orange
        case .socialWorker: return .pink
        }
    }

    var userRole: UserRole {
        switch self {
        case .teacher: return .teacher
        case .counselor: return .counselor
        case .administrator: return .administrator
        case .socialWorker: return .socialWorker
        }
    }
}

struct SimplifiedRegistrationView: View {
    private enum Layout {
        static let contentWidth: CGFloat = 720
    }

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAccountType: AccountType = .teacher
    @State private var isRegistering = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authStateModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case displayName, email, password, confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .auth)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.tmiPrimary)

                            Text("Create Account")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.tmiTextPrimary)

                            Text("Join the TMI community")
                                .font(.system(size: 16))
                                .foregroundColor(Color.tmiTextSecondary)
                        }
                        .padding(.top, 20)

                        // Account Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I am a...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.tmiTextSecondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                ForEach(AccountType.allCases) { type in
                                    AccountTypeButton(
                                        type: type,
                                        isSelected: selectedAccountType == type,
                                        action: { selectedAccountType = type }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Registration Form
                        TMICard(style: .elevated) {
                            VStack(spacing: 20) {
                                TMITextField(
                                    icon: "person.fill",
                                    placeholder: "Full Name",
                                    text: $displayName,
                                    onSubmit: { focusedField = .email }
                                )
                                .focused($focusedField, equals: .displayName)

                                TMITextField(
                                    icon: "envelope.fill",
                                    placeholder: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    onSubmit: { focusedField = .password }
                                )
                                .focused($focusedField, equals: .email)

                                TMITextField(
                                    icon: "lock.fill",
                                    placeholder: "Password (min 8 characters)",
                                    text: $password,
                                    isSecure: true,
                                    onSubmit: { focusedField = .confirmPassword }
                                )
                                .focused($focusedField, equals: .password)

                                TMITextField(
                                    icon: "lock.shield.fill",
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    onSubmit: { register() }
                                )
                                .focused($focusedField, equals: .confirmPassword)

                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .transition(.opacity)
                                }

                                TMIButton(
                                    text: isRegistering ? "Creating Account..." : "Create Account",
                                    icon: "checkmark.circle",
                                    style: .primary,
                                    isLoading: isRegistering,
                                    action: register
                                )
                                .disabled(isRegistering)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: Layout.contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.tmiTextPrimary)
                }
            }
        }
    }

    private func register() {
        // Validate
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your name"
            return
        }

        guard !email.isEmpty else {
            errorMessage = "Please enter an email address"
            return
        }

        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isRegistering = true
        errorMessage = nil

        Task {
            do {
                // Split full name into first and last
                let nameParts = displayName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                let firstName = String(nameParts.first ?? "")
                let lastName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""

                // Use AuthenticationService for unified registration
                _ = try await AuthenticationService.shared.signUp(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    role: selectedAccountType.userRole,
                    institutionCode: nil
                )

                // Force AuthStateModel to reload and fetch the TMIUser from Firestore
                await authStateModel.fetch()

                await MainActor.run {
                    isRegistering = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Account Type Button

struct AccountTypeButton: View {
    let type: AccountType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? type.color.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 60, height: 60)

                    if isSelected {
                        Circle()
                            .stroke(type.color, lineWidth: 2)
                            .frame(width: 60, height: 60)
                    }

                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? type.color : Color.tmiTextTertiary)
                }

                Text(type.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.tmiTextPrimary : Color.tmiTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.08) : Color.tmiInputBackground.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SimplifiedRegistrationView()
        .environment(\.authStateModel, AuthStateModel(automaticallyStart: false))
}
