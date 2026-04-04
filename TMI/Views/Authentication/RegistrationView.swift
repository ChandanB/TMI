// RegistrationView.swift

import FirebaseAuth
import SwiftUI

struct RegistrationView: View {
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var displayName = ""
  @State private var selectedRole: UserRole = .teacher
  @State private var institutionCode = ""
  @State private var isRegistering = false
  @State private var errorMessage: String?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.authStateModel) private var authStateModel
  @FocusState private var focusedField: Field?

  // Animation states
  @State private var appearAnimation = false
  @State private var animateFields = false
  @State private var animateButton = false

  enum Field: Hashable {
    case displayName
    case email
    case password
    case confirmPassword
    case institutionCode
  }

  var body: some View {
    ZStack {
      // Dynamic background - Using unified TMIBackgroundView
      TMIBackgroundView(variant: .auth)

      // Content
      ScrollView {
        VStack(spacing: 30) {
          // Header with animated icon
          VStack(spacing: 8) {
            ZStack {
              Circle()
                .fill(Color.tmiSecondary.opacity(0.2))
                .frame(width: 90, height: 90)
                .blur(radius: 10)

              Image(systemName: "person.crop.circle.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(Color.tmiTextPrimary)
            }
            .scaleEffect(appearAnimation ? 1.0 : 0.7)
            .opacity(appearAnimation ? 1.0 : 0)
            .animation(
              Animation.spring(response: 0.6, dampingFraction: 0.7)
                .delay(0.1),
              value: appearAnimation
            )

            Text("Create Account")
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundColor(Color.tmiTextPrimary)
              .padding(.top, 10)

            Text("Join the TMI community")
              .font(.system(size: 16))
              .foregroundColor(Color.tmiTextSecondary)
          }
          .padding(.top, 30)
          .opacity(appearAnimation ? 1.0 : 0)
          .offset(y: appearAnimation ? 0 : 20)
          .animation(
            Animation.spring(response: 0.6, dampingFraction: 0.8)
              .delay(0.2),
            value: appearAnimation
          )

          // Registration Form - Using unified TMICard
          TMICard(style: .elevated) {
            VStack(spacing: 24) {
              // Display Name field
              TMITextField(
                icon: "person.fill",
                placeholder: "Display Name",
                text: $displayName,
                onSubmit: {
                  focusedField = .email
                }
              )
              .focused($focusedField, equals: .displayName)
              .offset(x: animateFields ? 0 : -30)
              .opacity(animateFields ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.3),
                value: animateFields
              )

              // Email field - Using unified TMITextField
              TMITextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress,
                onSubmit: {
                  focusedField = .password
                }
              )
              .focused($focusedField, equals: .email)
              .offset(x: animateFields ? 0 : -30)
              .opacity(animateFields ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.35),
                value: animateFields
              )

              // Password field - Using unified TMITextField
              TMITextField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                isSecure: true,
                onSubmit: {
                  focusedField = .confirmPassword
                }
              )
              .focused($focusedField, equals: .password)
              .offset(x: animateFields ? 0 : -30)
              .opacity(animateFields ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.4),
                value: animateFields
              )

              // Confirm Password field - Using unified TMITextField
              TMITextField(
                icon: "lock.shield.fill",
                placeholder: "Confirm Password",
                text: $confirmPassword,
                isSecure: true,
                onSubmit: {
                  if selectedRole.requiresInstitutionalAffiliation {
                    focusedField = .institutionCode
                  } else {
                    register()
                  }
                }
              )
              .focused($focusedField, equals: .confirmPassword)
              .offset(x: animateFields ? 0 : -30)
              .opacity(animateFields ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.45),
                value: animateFields
              )

              // Role Selection
              VStack(alignment: .leading, spacing: 12) {
                Text("I am a...")
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(Color.tmiTextSecondary)

                Picker("Role", selection: $selectedRole) {
                  ForEach(UserRole.allCases) { role in
                    Text(role.displayName).tag(role)
                  }
                }
                .pickerStyle(.segmented)
                .tint(.tmiPrimary)
              }
              .offset(x: animateFields ? 0 : -30)
              .opacity(animateFields ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.5),
                value: animateFields
              )

              if selectedRole.requiresInstitutionalAffiliation {
                TMITextField(
                  icon: "building.2.fill",
                  placeholder: "Institution Code",
                  text: $institutionCode,
                  onSubmit: {
                    register()
                  }
                )
                .focused($focusedField, equals: .institutionCode)
                .offset(x: animateFields ? 0 : -30)
                .opacity(animateFields ? 1.0 : 0)
                .animation(
                  Animation.spring(response: 0.6, dampingFraction: 0.8)
                    .delay(0.55),
                  value: animateFields
                )

                Text("Enter the code provided by your school or district.")
                  .font(.system(size: 12))
                  .foregroundColor(Color.tmiTextSecondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }

              // Error Message
              if let errorMessage = errorMessage {
                Text(errorMessage)
                  .font(.system(size: 14))
                  .foregroundColor(Color.red.opacity(0.9))
                  .padding(.horizontal)
                  .transition(.opacity.combined(with: .move(edge: .bottom)))
              }

              // Register Button - Using unified TMIButton
              TMIButton(
                text: "Create Account",
                icon: "checkmark.circle",
                style: .primary,
                isLoading: isRegistering,
                action: register
              )
              .padding(.top, 10)
              .scaleEffect(animateButton ? 1.0 : 0.9)
              .opacity(animateButton ? 1.0 : 0)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.6),
                value: animateButton
              )
            }
          }
          .offset(y: appearAnimation ? 0 : 50)
          .opacity(appearAnimation ? 1.0 : 0)
          .animation(
            Animation.spring(response: 0.7, dampingFraction: 0.8)
              .delay(0.3),
            value: appearAnimation
          )

          // Back to Login Button
          Button(action: {
            dismiss()
          }) {
            HStack(spacing: 5) {
              Image(systemName: "arrow.left")
                .font(.system(size: 14))
              Text("Back to Login")
                .font(.system(size: 16))
            }
            .foregroundColor(Color.tmiTextSecondary)
            .padding(.vertical, 15)
          }
          .padding(.top, 10)
          .opacity(animateButton ? 1.0 : 0)
          .animation(
            Animation.easeInOut(duration: 0.5)
              .delay(0.7),
            value: animateButton
          )

          Spacer(minLength: 50)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 100)  // Extra padding at bottom for keyboard
      }
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .foregroundColor(Color.tmiTextPrimary)
              .font(.system(size: 17, weight: .medium))
              .padding(8)
              .background(
                Circle()
                  .fill(Color.white.opacity(0.1))
              )
          }
        }
      }
      .onChange(of: selectedRole) { _, newRole in
        if !newRole.requiresInstitutionalAffiliation {
          institutionCode = ""
        }
      }
      .onAppear {
        // Set initial focus to displayName field after a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          focusedField = .displayName
        }

        // Trigger animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          appearAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          animateFields = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          animateButton = true
        }
      }
    }
  }

  private func register() {
    // Validate input
    guard !displayName.isEmpty else {
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

    guard !password.isEmpty else {
      errorMessage = "Please enter a password"
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

    let trimmedInstitutionCode = institutionCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if selectedRole.requiresInstitutionalAffiliation && trimmedInstitutionCode.isEmpty {
      errorMessage = "Please enter your institution code"
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
          role: selectedRole,
          institutionCode: selectedRole.requiresInstitutionalAffiliation ? trimmedInstitutionCode : nil,
          districtId: nil
        )

        // Force AuthStateModel to reload and fetch the TMIUser from Firestore
        await authStateModel.fetch()

        // The AuthStateModel will automatically load the user after auth
        // Just dismiss and let the natural flow happen
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

#Preview {
  RegistrationView()
}
