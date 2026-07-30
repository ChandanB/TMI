// AuthenticationView.swift

import FirebaseAuth
import FirebaseCore
import Observation
import SwiftUI

struct AuthenticationView: View {
  @Environment(\.authStateModel) var stateModel
  @Environment(\.appDependencies) private var dependencies
  @State private var showingRegistration = false
  @State private var showingForgotPassword = false
  @State private var isRefreshingVerification = false
  @State private var verificationMessage: String?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @FocusState private var focusedField: Field?
  @State private var appearAnimation = false

  // Track animation state
  @State private var animateEmail = false
  @State private var animatePassword = false
  @State private var animateButtons = false

  var body: some View {
    ZStack {
      // Dynamic background - Using unified TMIBackgroundView
      TMIBackgroundView(variant: .auth)

      // Content
      ScrollView {
        VStack(spacing: 30) {
          Spacer()
            .frame(minHeight: 80)

          // Logo
          TMILogoView()
            .padding(.top, 40)
            .scaleEffect(appearAnimation ? 1.0 : 0.6)
            .opacity(appearAnimation ? 1.0 : 0)
            .animation(
              Animation.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.6)
                .delay(0.1),
              value: appearAnimation
            )

          // Welcome Text
          VStack(spacing: 8) {
            Text("Welcome to TMI")
              .font(
                .system(
                  size: 28 * dynamicTypeSize.tmiFontScale,
                  weight: .bold,
                  design: .rounded
                )
              )
              .foregroundColor(Color.tmiTextPrimary)
              .accessibilityIdentifier("authentication.signIn.screen")

            Text("Tangible Modification Intervention")
              .font(.system(size: 16 * dynamicTypeSize.tmiFontScale))
              .foregroundColor(Color.tmiTextSecondary)
          }
          .padding(.bottom, 20)
          .opacity(appearAnimation ? 1.0 : 0)
          .offset(y: appearAnimation ? 0 : 20)
          .animation(
            Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.6)
              .delay(0.2),
            value: appearAnimation
          )

          HStack {
            Spacer()

            // Login Card - Using unified TMICard
            TMICard(style: .elevated) {
              VStack(spacing: 24) {
                if stateModel.requiresVerification {
                  emailVerificationStatus
                }

                // Email field - Using unified TMITextField
                TMITextField(
                  icon: "envelope.fill",
                  placeholder: "Email",
                  text: Binding(
                    get: { stateModel.email },
                    set: { stateModel.updateEmail($0) }
                  ),
                  keyboardType: .emailAddress,
                  onSubmit: {
                    focusedField = .password
                  },
                  focus: focusBinding(for: .email)
                )
                .accessibilityIdentifier("authentication.signIn.email")
                .offset(x: animateEmail ? 0 : -30)
                .opacity(animateEmail ? 1.0 : 0)
                .animation(
                  Animation.spring(response: 0.6, dampingFraction: 0.8)
                    .delay(0.3),
                  value: animateEmail
                )

                // Password field - Using unified TMITextField
                TMITextField(
                  icon: "lock.fill",
                  placeholder: "Password",
                  text: Binding(
                    get: { stateModel.password },
                    set: { stateModel.updatePassword($0) }
                  ),
                  isSecure: true,
                  onSubmit: {
                    authenticate()
                  },
                  focus: focusBinding(for: .password)
                )
                .accessibilityIdentifier("authentication.signIn.password")
                .offset(x: animatePassword ? 0 : -30)
                .opacity(animatePassword ? 1.0 : 0)
                .animation(
                  Animation.spring(response: 0.6, dampingFraction: 0.8)
                    .delay(0.4),
                  value: animatePassword
                )

                // Forgot Password
                HStack {
                  Spacer()
                  Button(action: {
                    showingForgotPassword = true
                  }) {
                    Text("Forgot Password?")
                      .font(
                        .system(
                          size: 13 * dynamicTypeSize.tmiFontScale,
                          weight: .medium
                        )
                      )
                      .foregroundColor(Color.tmiSecondary)
                  }
                  .padding(.top, 4)
                }
                .opacity(animateButtons ? 1.0 : 0)
                .animation(
                  Animation.easeInOut(duration: 0.5)
                    .delay(0.5),
                  value: animateButtons
                )

                // Authentication error
                if let errorMessage = stateModel.errorMessage {
                  AuthenticationErrorView(message: errorMessage)
                  .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Login Button - Using unified TMIButton
                TMIButton(
                  text: "Log In",
                  icon: "arrow.right",
                  style: .primary,
                  isLoading: stateModel.isAuthenticating,
                  action: authenticate
                )
                .accessibilityIdentifier("authentication.signIn.logIn")
                .disabled(stateModel.isAuthenticating)
                .padding(.top, 10)
                .opacity(animateButtons ? 1.0 : 0)
                .animation(
                  Animation.easeInOut(duration: 0.5)
                    .delay(0.6),
                  value: animateButtons
                )

                // Enhanced Sign Up Section
                VStack(spacing: 12) {
                  Button(action: {
                    showingRegistration = true
                  }) {
                    ViewThatFits(in: .horizontal) {
                      HStack(spacing: 0) {
                        Text("Don't have an account? ")
                          .foregroundColor(Color.tmiTextSecondary)
                        Text("Create Account")
                          .foregroundColor(Color.tmiSecondary)
                          .fontWeight(.semibold)
                      }

                      VStack(spacing: 4) {
                        Text("Don't have an account?")
                          .foregroundColor(Color.tmiTextSecondary)
                        Text("Create Account")
                          .foregroundColor(Color.tmiSecondary)
                          .fontWeight(.semibold)
                      }
                    }
                    .font(.system(size: 17 * dynamicTypeSize.tmiFontScale))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                  }
                  .accessibilityIdentifier("authentication.signIn.createAccount")
                }
                .padding(.top, 10)
                .opacity(animateButtons ? 1.0 : 0)
                .animation(
                  Animation.easeInOut(duration: 0.5)
                    .delay(0.7),
                  value: animateButtons
                )
              }
            }
            .frame(maxWidth: 800)
            .padding(.horizontal)
            .offset(y: appearAnimation ? 0 : 50)
            .opacity(appearAnimation ? 1.0 : 0)
            .animation(
              Animation.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.5)
                .delay(0.3),
              value: appearAnimation
            )

            Spacer()
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 100)  // Extra padding at bottom for keyboard
        .padding(.top)
      }
      .task {
        await stateModel.fetch()
      }
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showingRegistration) {
        SimplifiedRegistrationView()
          .tmiSheetStyle()
      }
      .alert("Reset Password", isPresented: $showingForgotPassword) {
        TextField("Email", text: Binding(
          get: { stateModel.email },
          set: { stateModel.updateEmail($0) }
        ))
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        Button("Cancel", role: .cancel) {}
        Button("Reset") {
          Task {
            await stateModel.resetPassword()
          }
        }
      } message: {
        Text("Enter your email address and we'll send you a link to reset your password.")
      }
      .errorBoundary()
      .onAppear {
        // Trigger animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          appearAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          animateEmail = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
          animatePassword = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          animateButtons = true
        }
      }
    }
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
        .font(.system(size: 28, weight: .semibold))
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
    TMICard(style: .default) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(TMIColors.errorText)

        Text(message)
          .font(.system(size: 14))
          .foregroundColor(TMIColors.errorText)
          .multilineTextAlignment(.leading)

        Spacer(minLength: 0)
      }
      .padding(.vertical, 8)
    }
    .padding(.horizontal, 20)
  }
}

#Preview {
  AuthenticationView()
}
