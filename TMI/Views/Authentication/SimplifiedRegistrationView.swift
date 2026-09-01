//
//  SimplifiedRegistrationView.swift
//  TMI
//
//  Invitation-based staff registration.
//

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
        case .teacher, .administrator: return TMIColors.aubergine
        case .counselor, .socialWorker: return TMIColors.teal
        }
    }

    /// Registration-only compatibility mapping. Trusted access is always
    /// derived from `StaffRole` membership after authentication.
    var userRole: UserRole {
        switch self {
        case .teacher: .teacher
        case .counselor: .counselor
        case .administrator: .administrator
        case .socialWorker: .socialWorker
        }
    }

    var staffRole: StaffRole {
        switch self {
        case .teacher: .teacher
        case .counselor: .counselor
        case .administrator: .schoolAdministrator
        case .socialWorker: .socialWorker
        }
    }
}

struct SimplifiedRegistrationView: View {
    private enum Layout {
        static let contentWidth: CGFloat = 720
    }

    @State private var displayName = ""
    @State private var email = ""
    @State private var invitationCode = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAccountType: AccountType = .teacher
    @State private var flow = StaffRegistrationFlow()
    @State private var validationErrorMessage: String?

    @Binding private var isPresented: Bool
    @Binding private var isOperationActive: Bool
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case displayName, email, invitationCode
    }

    init(
        isPresented: Binding<Bool>,
        isOperationActive: Binding<Bool>
    ) {
        _isPresented = isPresented
        _isOperationActive = isOperationActive
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

                            Text("Create an account with your staff invitation")
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
                                    onSubmit: { focusedField = .email },
                                    focus: focusBinding(for: .displayName)
                                )
                                .accessibilityIdentifier("authentication.registration.name")

                                TMITextField(
                                    icon: "envelope.fill",
                                    placeholder: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    onSubmit: { focusedField = .invitationCode },
                                    focus: focusBinding(for: .email)
                                )
                                .accessibilityIdentifier("authentication.registration.email")

                                TMITextField(
                                    icon: "building.2.crop.circle",
                                    placeholder: "Staff Invitation Code",
                                    text: $invitationCode,
                                    onSubmit: { focusedField = nil },
                                    focus: focusBinding(for: .invitationCode)
                                )
                                .accessibilityIdentifier("authentication.registration.invitation")

                                TMITextField(
                                    icon: "lock.fill",
                                    placeholder: "Password (min 8 characters)",
                                    text: $password,
                                    isSecure: true,
                                    onSubmit: { focusedField = nil }
                                )
                                .accessibilityIdentifier("authentication.registration.password")

                                TMITextField(
                                    icon: "lock.shield.fill",
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    onSubmit: { register() }
                                )
                                .accessibilityIdentifier(
                                    "authentication.registration.confirmPassword"
                                )

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .transition(.opacity)
                                }

                                TMIButton(
                                    text: flow.isOperationActive
                                        ? "Creating Account..."
                                        : "Create Account",
                                    icon: "checkmark.circle",
                                    style: .primary,
                                    isLoading: flow.isOperationActive,
                                    action: register
                                )
                                .disabled(flow.isOperationActive || flow.recoveryAvailable)
                                .accessibilityIdentifier("authentication.registration.submit")
                                .padding(.top, 8)

                                if flow.recoveryAvailable {
                                    TMIButton(
                                        text: "Continue Account Setup",
                                        icon: "arrow.clockwise",
                                        style: .secondary,
                                        action: retryRecovery
                                    )
                                    .disabled(flow.isOperationActive)
                                    .accessibilityIdentifier(
                                        "authentication.registration.retryRecovery"
                                    )
                                }
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
                        guard !self.flow.isOperationActive else {
                            return
                        }
                        self.closeRegistration()
                    }
                    .foregroundColor(Color.tmiTextPrimary)
                    .disabled(flow.isOperationActive)
                    .accessibilityIdentifier("authentication.registration.cancel")
                }
            }
        }
        .accessibilityIdentifier("authentication.registration.screen")
        .onChange(of: flow.isOperationActive, initial: true) { _, isActive in
            self.isOperationActive = isActive
        }
        .onChange(
            of: authStateModel.authenticatedSession?.profile.userID,
            initial: true
        ) { _, userID in
            if self.flow.acceptPublishedIdentity(userID) {
                self.closeRegistration()
            }
        }
    }

    private var errorMessage: String? {
        validationErrorMessage ?? flow.errorMessage
    }

    private func register() {
        guard !flow.isOperationActive, !flow.recoveryAvailable else {
            return
        }

        // Validate
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrorMessage = "Please enter your name"
            return
        }

        guard !email.isEmpty else {
            validationErrorMessage = "Please enter an email address"
            return
        }

        guard isValidEmail(email) else {
            validationErrorMessage = "Please enter a valid email address"
            return
        }

        guard !invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrorMessage = "Enter the staff invitation code provided by your institution"
            return
        }

        guard password.count >= 8 else {
            validationErrorMessage = "Password must be at least 8 characters"
            return
        }

        guard password == confirmPassword else {
            validationErrorMessage = "Passwords do not match"
            return
        }

        guard let authentication = dependencies.authentication else {
            validationErrorMessage = AuthenticationPresentationPolicy.registrationFailureMessage
            return
        }

        let request = StaffRegistrationRequest(
            displayName: displayName,
            email: email,
            password: password,
            requestedRole: selectedAccountType.staffRole,
            invitationCode: invitationCode,
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
        guard flow.reserveSubmission() else {
            return
        }
        validationErrorMessage = nil

        Task {
            await self.flow.performReservedSubmission(
                request,
                using: authentication
            )
            self.clearRegistrationSecrets()
            await self.finishAuthorizationIfReady()
        }
    }

    private func retryRecovery() {
        guard let authentication = dependencies.authentication else {
            validationErrorMessage = AuthenticationPresentationPolicy.registrationFailureMessage
            return
        }
        validationErrorMessage = nil

        Task {
            await self.flow.retryRecovery(using: authentication)
            await self.finishAuthorizationIfReady()
        }
    }

    private func finishAuthorizationIfReady() async {
        guard flow.expectedIdentityID != nil else {
            return
        }

        await authStateModel.fetch()
        if flow.finishAuthorization(
            with: authStateModel.authenticatedSession?.profile.userID
        ) {
            closeRegistration()
        }
    }

    private func closeRegistration() {
        isOperationActive = false
        isPresented = false
    }

    private func clearRegistrationSecrets() {
        password = ""
        confirmPassword = ""
        invitationCode = ""
    }

    private func focusBinding(for field: Field) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { isFocused in
                if isFocused {
                    focusedField = field
                } else if focusedField == field {
                    focusedField = nil
                }
            }
        )
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
    SimplifiedRegistrationPreview()
        .environment(\.authStateModel, AuthStateModel(automaticallyStart: false))
}

private struct SimplifiedRegistrationPreview: View {
    @State private var isPresented = true
    @State private var isOperationActive = false

    var body: some View {
        SimplifiedRegistrationView(
            isPresented: $isPresented,
            isOperationActive: $isOperationActive
        )
    }
}
