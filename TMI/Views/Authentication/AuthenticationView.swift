// AuthenticationView.swift

import FirebaseAuth
import FirebaseCore
import Observation
import SwiftUI

// MARK: - State Types

/// Represents the possible authentication states
enum AuthenticationState: Equatable {
  case unauthenticated
  case authenticating
  case authenticated(User)
  case error(String)
}

// MARK: - Environment Key
extension EnvironmentValues {
  @Entry var authStateModel: AuthStateModel = AuthStateModel()
}

// MARK: - State Model

@Observable
final class AuthStateModel: BaseStateModel<AuthenticationState, IdentifiableError> {
  // MARK: - Dependencies
  private var firebaseManager: FirebaseManager

  // MARK: - Form Fields
  private(set) var email: String = ""
  private(set) var password: String = ""

  // MARK: - Computed Properties
  var isLoggedIn: Bool {
    if case .loaded(.authenticated) = state {
      return true
    }
    return false
  }

  var isAuthenticating: Bool {
    if case .loaded(.authenticating) = state {
      return true
    }
    return false
  }

  var currentUser: User? {
    if case .loaded(.authenticated(let user)) = state {
      return user
    }
    return nil
  }

  override var errorMessage: String? {
    if case .loaded(.error(let message)) = state {
      return message
    }
    if case .error(let error) = state {
      return error.message
    }
    return nil
  }

  // MARK: - Initialization
  init(firebaseManager: FirebaseManager = FIREBASE_MANAGER) {
    self.firebaseManager = firebaseManager
    super.init()

    Task { await fetch() }
  }

  override func fetch() async {
    // Initialize UI state
    ui.set("showingRegistration", value: false)
    ui.set("showingForgotPassword", value: false)
    ui.set("focusedField", value: nil as Field?)

    setupFirebase()
    setupAuthListener()
  }

  // MARK: - Setup Methods

  private func setupFirebase() {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }

  @MainActor private func setupAuthListener() {
    let currentUser = Auth.auth().currentUser
    if let currentUser = currentUser {
      updateState(.loaded(.authenticated(currentUser)))
    } else {
      updateState(.loaded(.unauthenticated))
    }

    let _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      guard let self = self else { return }

      Task { @MainActor in
        if let user = user {
          self.updateState(.loaded(.authenticated(user)))
        } else {
          self.updateState(.loaded(.unauthenticated))
        }
      }
    }
  }

  // MARK: - Form Field Methods

  func updateEmail(_ newValue: String) {
    email = newValue
  }

  func updatePassword(_ newValue: String) {
    password = newValue
  }

  func clearCredentials() {
    email = ""
    password = ""
  }

  // MARK: - Authentication Methods

  @MainActor
  func signIn() async {
    guard !email.isEmpty, !password.isEmpty else {
      updateState(.loaded(.error("Email and password cannot be empty")))
      return
    }

    updateState(.loaded(.authenticating))

    do {
      try await firebaseManager.signIn(email: email, password: password)
      if let user = Auth.auth().currentUser {
        updateState(.loaded(.authenticated(user)))
        clearCredentials()
      } else {
        updateState(.loaded(.error("Authentication succeeded but user is nil")))
      }
    } catch {
      updateState(.loaded(.error(error.localizedDescription)))
    }
  }

  @MainActor
  func resetPassword() async {
    guard !email.isEmpty else {
      updateState(.loaded(.error("Please enter your email address")))
      return
    }

    guard validateEmail() else {
      updateState(.loaded(.error("Please enter a valid email address")))
      return
    }

    updateState(.loaded(.authenticating))

    do {
      try await firebaseManager.resetPassword(email: email)
      // Keep the current state but show success message
      if case .loaded = state {
        ui.alertMessage = "Password reset email sent. Please check your inbox."
        ui.isShowingAlert = true
      }
    } catch {
      updateState(.loaded(.error("Failed to send password reset: \(error.localizedDescription)")))
    }
  }

  @MainActor
  func signOut() {
    do {
      try firebaseManager.signOut()
      updateState(.loaded(.unauthenticated))
    } catch {
      updateState(.loaded(.error("Error signing out: \(error.localizedDescription)")))
    }
  }

  // MARK: - Validation Methods

  func validateEmail() -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
  }

  // MARK: - UI State Accessors

  var showingRegistration: Bool {
    get { return ui.get("showingRegistration") ?? false }
    set { ui.set("showingRegistration", value: newValue) }
  }

  var showingForgotPassword: Bool {
    get { return ui.get("showingForgotPassword") ?? false }
    set { ui.set("showingForgotPassword", value: newValue) }
  }

  var focusedField: Field? {
    get { return ui.get("focusedField") }
    set { ui.set("focusedField", value: newValue) }
  }
}

// MARK: - Field Enum
enum Field: Hashable {
  case email
  case password
}

struct AuthenticationView: View {
  @Environment(\.authStateModel) var stateModel
  @State private var showingRegistration = false
  @State private var showingForgotPassword = false
  @State private var showingRoleSelection = false
  @State private var showingSupportResources = false
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?
  @State private var appearAnimation = false

  // Track animation state
  @State private var animateEmail = false
  @State private var animatePassword = false
  @State private var animateButtons = false

  enum Field: Hashable {
    case email
    case password
  }

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
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundColor(.white)

            Text("Tangible Modification Intervention")
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.7))
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

            // Login Card - Using unified TMIGlassCard
            TMIGlassCard(style: .auth) {
              VStack(spacing: 24) {
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
                  }
                )
                .focused($focusedField, equals: .email)
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
                  }
                )
                .focused($focusedField, equals: .password)
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
                      .font(.system(size: 15))
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

                // Enhanced Error Message with Trauma-Informed Design
                if let errorMessage = stateModel.errorMessage {
                  TraumaInformedErrorView(
                    message: errorMessage,
                    showingSupportResources: $showingSupportResources
                  )
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
                    showingRoleSelection = true
                  }) {
                    Text("Don't have an account? ")
                      .foregroundColor(.white.opacity(0.7))
                      + Text("Create Account")
                      .foregroundColor(Color.tmiSecondary)
                      .fontWeight(.semibold)
                  }

                  // Support Resources Button
                  Button(action: {
                    showingSupportResources = true
                  }) {
                    HStack(spacing: 6) {
                      Image(systemName: "heart.circle")
                        .font(.system(size: 14))
                      Text("Need Help or Support?")
                        .font(.system(size: 14))
                    }
                    .foregroundColor(Color.tmiSecondary.opacity(0.8))
                  }
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
        RegistrationView()
          .preferredColorScheme(.dark)
      }
      .sheet(isPresented: $showingRoleSelection) {
        RoleSelectionView()
          .preferredColorScheme(.dark)
      }
      .sheet(isPresented: $showingSupportResources) {
        SupportResourcesView()
          .preferredColorScheme(.dark)
      }
      .alert("Reset Password", isPresented: $showingForgotPassword) {
        TextField(
          "Email",
          text: Binding(
            get: { stateModel.email },
            set: { stateModel.updateEmail($0) }
          )
        )
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
      .onChange(of: stateModel.isLoggedIn) { _, isLoggedIn in
        if isLoggedIn {
          dismiss()
        }
      }
      .preferredColorScheme(.dark)
      .onAppear {
        // Set initial focus to email field after a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          focusedField = .email
        }

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
}

// MARK: - Trauma-Informed Error View

struct TraumaInformedErrorView: View {
  let message: String
  @Binding var showingSupportResources: Bool

  var body: some View {
    TMIGlassCard(style: .error) {
      VStack(spacing: 16) {
        // Gentle, non-threatening icon
        Image(systemName: "heart.circle")
          .font(.system(size: 32))
          .foregroundColor(Color.tmiSecondary)

        // Gentle error message
        Text(message)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.9))
          .multilineTextAlignment(.center)

        // Reassuring message
        Text("You're safe. Take your time, and try again when you're ready.")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)

        // Support options
        HStack(spacing: 16) {
          Button(action: {
            showingSupportResources = true
          }) {
            HStack(spacing: 4) {
              Image(systemName: "heart")
              Text("Get Support")
            }
            .font(.system(size: 12))
            .foregroundColor(Color.tmiSecondary)
          }

          Button(action: {
            // Clear error (would be handled by state model)
          }) {
            Text("I'm Ready to Try Again")
              .font(.system(size: 12))
              .foregroundColor(.white.opacity(0.8))
          }
        }
        .padding(.top, 8)
      }
      .padding(.vertical, 8)
    }
    .padding(.horizontal, 20)
  }
}

// MARK: - Support Resources View

struct SupportResourcesView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .auth)

        ScrollView {
          VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
              Image(systemName: "heart.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.tmiSecondary)

              Text("We're Here to Help")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

              Text(
                "Your safety and wellbeing are our top priorities. Here are some resources that might help."
              )
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.8))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 30)
            }
            .padding(.top, 20)

            // Support resources
            LazyVStack(spacing: 16) {
              SupportResourceCard(
                icon: "message.circle",
                title: "Chat Support",
                description: "Get real-time help from our support team",
                action: {}
              )

              SupportResourceCard(
                icon: "phone.circle",
                title: "Call Support",
                description: "Speak directly with someone who can help",
                action: {}
              )

              SupportResourceCard(
                icon: "questionmark.circle",
                title: "Help Center",
                description: "Find answers to common questions",
                action: {}
              )

              SupportResourceCard(
                icon: "person.2.circle",
                title: "Crisis Support",
                description: "24/7 crisis support and resources",
                isEmergency: true,
                action: {}
              )

              SupportResourceCard(
                icon: "envelope.circle",
                title: "Email Support",
                description: "Send us a detailed message about your issue",
                action: {}
              )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
          }
        }
      }
      .navigationTitle("Support Resources")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(Color.tmiSecondary)
        }
      }
    }
  }
}

// MARK: - Support Resource Card

struct SupportResourceCard: View {
  let icon: String
  let title: String
  let description: String
  let isEmergency: Bool
  let action: () -> Void

  init(
    icon: String, title: String, description: String, isEmergency: Bool = false,
    action: @escaping () -> Void
  ) {
    self.icon = icon
    self.title = title
    self.description = description
    self.isEmergency = isEmergency
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      TMIGlassCard(style: .form) {
        HStack(spacing: 16) {
          Image(systemName: icon)
            .font(.system(size: 24))
            .foregroundColor(isEmergency ? .red : Color.tmiSecondary)

          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

              if isEmergency {
                Text("URGENT")
                  .font(.system(size: 10, weight: .bold))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.red)
                  .foregroundColor(.white)
                  .cornerRadius(4)
              }

              Spacer()
            }

            Text(description)
              .font(.system(size: 14))
              .foregroundColor(.white.opacity(0.8))
              .multilineTextAlignment(.leading)
          }

          Image(systemName: "arrow.right")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 4)
      }
    }
  }
}

#Preview {
  AuthenticationView()
}
