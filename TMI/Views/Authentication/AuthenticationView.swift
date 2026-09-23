// AuthenticationView.swift

import FirebaseAuth
import FirebaseCore
import Observation
import SwiftUI

struct AuthenticationView: View {
  @Environment(\.authStateModel) var stateModel
  @Environment(\.appDependencies) private var dependencies
  @State private var showingForgotPassword = false
  @State private var isRefreshingVerification = false
  @State private var verificationMessage: String?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @FocusState private var focusedField: Field?
  @State private var hasAppeared = false
  @State private var resetRequest: PasswordResetRequest?
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

  private var usesWideLayout: Bool {
#if os(macOS)
    true
#else
    horizontalSizeClass == .regular
#endif
  }

  #if DEBUG
  @State private var didAttemptDebugAutoLogin = false
  #endif

  let onCreateAccount: @MainActor () -> Void

  init(onCreateAccount: @escaping @MainActor () -> Void = {}) {
    self.onCreateAccount = onCreateAccount
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        TMIGoldenHourBackground(animated: true)
          .ignoresSafeArea()

        if usesWideLayout {
          HStack(spacing: 0) {
            brandPanel
              .frame(width: max(proxy.size.width * 0.4, 320))
            ScrollView {
              formCard
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .padding(.horizontal, TMISpacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
          }
          .ignoresSafeArea(edges: .vertical)
        } else {
          ScrollView {
            VStack(spacing: TMISpacing.xl) {
              brandLockup
              formCard
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.xl)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
          }
          .scrollBounceBehavior(.basedOnSize)
          .scrollDismissesKeyboard(.interactively)
        }
      }
    }
    .opacity(hasAppeared ? 1 : 0)
    .task {
      withAnimation(.easeOut(duration: 0.45)) { hasAppeared = true }
      await stateModel.fetch()
      #if DEBUG
      // Optional: launch with `-TMIDebugAutoLogin` (and the debug env vars set)
      // to skip the login screen automatically. DEBUG-only; runs at most once.
      if !didAttemptDebugAutoLogin,
         ProcessInfo.processInfo.arguments.contains("-TMIDebugAutoLogin"),
         stateModel.isDebugSignInAvailable,
         !stateModel.isLoggedIn {
        didAttemptDebugAutoLogin = true
        await stateModel.debugSignIn()
      }
      #endif
    }
    .sheet(item: $resetRequest) { _ in
      PasswordResetSheet(
        email: stateModel.email,
        send: { email in
          stateModel.updateEmail(email)
          await stateModel.resetPassword()
        }
      )
    }
    .sensoryFeedback(.error, trigger: stateModel.errorMessage) { _, new in new != nil }
    .errorBoundary()
  }

  // MARK: Brand

  /// iPhone: the app icon's mark and the name, above the form.
  private var brandLockup: some View {
    VStack(spacing: TMISpacing.ms) {
      TMISchoolhouseMark(size: 76, onTile: true)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
      Text("TMI")
        .font(.tmiEditorial(.largeTitle))
        .foregroundStyle(TMIColors.goldenHourText)
      Text("Tangible Modification Intervention")
        .tmiEyebrow(TMIColors.goldenHourSecondaryText)
        .multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("TMI, Tangible Modification Intervention")
  }

  /// iPad and Mac: the icon's charcoal ground as a brand panel.
  private var brandPanel: some View {
    ZStack(alignment: .bottomLeading) {
      Color(light: 0x2F2D2C, dark: 0x1E1D1C)
      VStack(alignment: .leading, spacing: TMISpacing.lg) {
        Spacer()
        TMISchoolhouseShape()
          .fill(TMIColors.brand, style: FillStyle(eoFill: true))
          .frame(width: 120, height: 120)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
          Text("TMI")
            .font(.tmiEditorial(.largeTitle))
            .foregroundStyle(Color(light: 0xFFF7EA, dark: 0xFFF7EA))
          Text("Support plans that start with what each student cares about.")
            .font(.title3)
            .foregroundStyle(Color(light: 0xD9CBB7, dark: 0xD9CBB7))
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Text("Tangible Modification Intervention")
          .tmiEyebrow(Color(light: 0xA8998A, dark: 0xA8998A))
      }
      .padding(TMISpacing.xxl)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("TMI, Tangible Modification Intervention")
  }

  // MARK: Form

  private var formCard: some View {
    VStack(alignment: .leading, spacing: TMISpacing.ml) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Sign in to TMI")
          .font(.title2.weight(.semibold))
          .foregroundStyle(TMIColors.textPrimary)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("authentication.signIn.screen")
        Text("Use the email your school or district invited.")
          .font(.subheadline)
          .foregroundStyle(TMIColors.textSecondary)
      }

      if dependencies.flags.staffEmailVerificationRequired
          && stateModel.requiresVerification {
        emailVerificationStatus
      } else {
        credentialFields
      }

      TMIDivider()

      Button {
        self.onCreateAccount()
      } label: {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 4) {
            Text("Have an invitation?")
              .foregroundStyle(TMIColors.textSecondary)
            Text("Create Account")
              .foregroundStyle(TMIColors.accent)
              .fontWeight(.semibold)
          }
          VStack(spacing: 2) {
            Text("Have an invitation?")
              .foregroundStyle(TMIColors.textSecondary)
            Text("Create Account")
              .foregroundStyle(TMIColors.accent)
              .fontWeight(.semibold)
          }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, minHeight: TMISizing.minTouchTarget)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("authentication.signIn.createAccount")
    }
    .tmiSurface(.floating, padding: TMISpacing.lg, radius: TMIRadius.card + 6)
  }

  @ViewBuilder
  private var credentialFields: some View {
    VStack(spacing: TMISpacing.ms) {
      TMITextField(
        icon: "envelope",
        placeholder: "Email",
        text: Binding(
          get: { stateModel.email },
          set: { stateModel.updateEmail($0) }
        ),
        keyboardType: .emailAddress,
        onSubmit: {
          focusedField = .password
        },
        focus: focusBinding(for: .email),
        content: .username
      )
      .accessibilityIdentifier("authentication.signIn.email")

      TMITextField(
        icon: "lock",
        placeholder: "Password",
        text: Binding(
          get: { stateModel.password },
          set: { stateModel.updatePassword($0) }
        ),
        isSecure: true,
        onSubmit: {
          authenticate()
        },
        focus: focusBinding(for: .password),
        content: .password,
        submitLabel: .go
      )
      .accessibilityIdentifier("authentication.signIn.password")
    }

    VStack(alignment: .leading, spacing: TMISpacing.sm) {
      if let errorMessage = stateModel.errorMessage {
        AuthenticationErrorView(message: errorMessage)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
      // No fixedSize: at accessibility text sizes a fixed-width link forced
      // the whole card wider than the screen.
      Button("Forgot password?") {
        resetRequest = PasswordResetRequest()
      }
      .font(.subheadline.weight(.medium))
      .foregroundStyle(TMIColors.accent)
      .buttonStyle(.plain)
      .multilineTextAlignment(.trailing)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .animation(TMIAnimation.smooth, value: stateModel.errorMessage)

    TMIButton(
      text: "Sign In",
      icon: "arrow.right",
      style: .primary,
      isLoading: stateModel.isAuthenticating,
      action: authenticate
    )
    .accessibilityIdentifier("authentication.signIn.logIn")
    .disabled(stateModel.isAuthenticating)
    .keyboardShortcut(.defaultAction)
#if os(macOS)
    .frame(maxWidth: .infinity)
#endif

    #if DEBUG
    // Developer-only shortcut past the login screen. Compiled out
    // of Release/App Store builds; shown only when the scheme
    // supplies TMI_DEBUG_EMAIL / TMI_DEBUG_PASSWORD.
    if stateModel.isDebugSignInAvailable {
      Button {
        Task { await stateModel.debugSignIn() }
      } label: {
        Label("Debug sign-in", systemImage: "hammer.fill")
          .font(.footnote.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.tmiSecondary)
      .disabled(stateModel.isAuthenticating)
      .accessibilityIdentifier("authentication.signIn.debug")
    }
    #endif
  }

  private func authenticate() {
    Task {
      await stateModel.signIn()
    }
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

  private var emailVerificationStatus: some View {
    VStack(spacing: 12) {
      Image(systemName: "envelope.badge.shield.half.filled")
        .font(.title.weight(.semibold))
        .foregroundColor(Color.tmiSecondary)

      Text("Verify Your Email")
        .font(.headline)
        .foregroundColor(Color.tmiTextPrimary)

      Text("Open the verification link we sent, then return here to finish setting up your staff access.")
        .font(.subheadline)
        .foregroundColor(Color.tmiTextSecondary)
        .multilineTextAlignment(.center)

      if let verificationMessage {
        Text(verificationMessage)
          .font(.footnote)
          .foregroundColor(Color.tmiTextSecondary)
          .multilineTextAlignment(.center)
      }

      TMIButton(
        text: "I've Verified My Email",
        icon: "checkmark.shield",
        style: .secondary,
        isLoading: isRefreshingVerification,
        action: completeEmailVerification
      )
      .disabled(isRefreshingVerification)

      Button("Resend Verification Email", action: resendVerificationEmail)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(Color.tmiSecondary)
        .disabled(isRefreshingVerification)
    }
    .padding(.bottom, 8)
    .accessibilityElement(children: .contain)
  }

  private func completeEmailVerification() {
    Task { @MainActor in
      guard let authentication = dependencies.authentication else {
        verificationMessage = "Email verification is temporarily unavailable."
        return
      }

      isRefreshingVerification = true
      defer { isRefreshingVerification = false }
      do {
        let session = try await authentication.refresh()
        if session.access == .emailVerificationRequired {
          verificationMessage = "We haven't detected the verification yet. Open the link and try again."
          return
        }
        verificationMessage = nil
        await stateModel.fetch()
      } catch {
        verificationMessage = "We couldn't finish verifying your account. Try again."
      }
    }
  }

  private func resendVerificationEmail() {
    Task { @MainActor in
      guard let authentication = dependencies.authentication else {
        verificationMessage = "Email verification is temporarily unavailable."
        return
      }

      isRefreshingVerification = true
      defer { isRefreshingVerification = false }
      do {
        try await authentication.sendVerification()
        verificationMessage = "A new verification email was sent."
      } catch {
        verificationMessage = "We couldn't send another verification email. Try again."
      }
    }
  }
}

// MARK: - Authentication Error View

struct AuthenticationErrorView: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "exclamationmark.circle.fill")
      .font(.subheadline)
      .foregroundStyle(TMIColors.errorText)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.updatesFrequently)
  }
}

// MARK: - Password reset

struct PasswordResetRequest: Identifiable {
  let id = UUID()
}

/// Replaces the old alert-with-a-text-field, which never confirmed success.
private struct PasswordResetSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State var email: String
  let send: (String) async -> Void

  @State private var isSending = false
  @State private var didSend = false

  var body: some View {
    NavigationStack {
      Form {
        if didSend {
          Section {
            VStack(spacing: TMISpacing.ms) {
              Image(systemName: "envelope.badge.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TMIColors.accent)
              Text("Check your inbox")
                .font(.title3.weight(.semibold))
              Text("If an account exists for \(email), a reset link is on its way.")
                .font(.subheadline)
                .foregroundStyle(TMIColors.textSecondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
          }
        } else {
          Section {
            TextField("Email", text: $email)
#if os(iOS)
              .keyboardType(.emailAddress)
              .textInputAutocapitalization(.never)
#endif
              .textContentType(.username)
              .autocorrectionDisabled()
              .submitLabel(.send)
              .onSubmit { Task { await submit() } }
          } footer: {
            Text("We’ll email you a link to choose a new password.")
          }
        }
      }
      .navigationTitle("Reset Password")
#if os(iOS)
      .toolbarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(didSend ? "Done" : "Cancel") { dismiss() }
        }
        if !didSend {
          ToolbarItem(placement: .confirmationAction) {
            Button("Send") { Task { await submit() } }
              .disabled(isSending || !email.contains("@"))
          }
        }
      }
    }
    .presentationDetents([.medium])
    .tmiMacSheetFrame(minWidth: 420, minHeight: 280)
    .sensoryFeedback(.success, trigger: didSend)
  }

  private func submit() async {
    guard !isSending else { return }
    isSending = true
    await send(email.trimmingCharacters(in: .whitespacesAndNewlines))
    isSending = false
    withAnimation(TMIAnimation.smooth) { didSend = true }
  }
}

#Preview {
  AuthenticationView()
}
