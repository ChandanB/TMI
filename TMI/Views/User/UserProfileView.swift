//
//  UserProfileStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/16/24.
//

import FirebaseAuth
import Observation
import SwiftUI

// MARK: - User Profile Data Model

struct UserProfileData: Equatable {
  var displayName: String = ""
  var email: String = ""
  var role: String = "student"
  var isEmailVerified: Bool = false

  // For email update
  var newEmail: String = ""
  var currentPassword: String = ""
}

// MARK: - Environment Key
extension EnvironmentValues {
  @Entry var userProfileStateModel: UserProfileStateModel = UserProfileStateModel()
}

// MARK: - State Model

@Observable
final class UserProfileStateModel: BaseStateModel<UserProfileData, IdentifiableError> {
  // MARK: - Dependencies
  private let firebaseManager: FirebaseManager

  // MARK: - Initialization

  init(firebaseManager: FirebaseManager = FIREBASE_MANAGER) {
    self.firebaseManager = firebaseManager
    super.init()

    // Initialize UI state
    ui.set("isChangingEmail", value: false)

    // Load user data on initialization
    Task { @MainActor in
      await fetch()
    }
  }

  // MARK: - Data Fetching

  @MainActor
  override func fetch() async {
    updateState(.loading)

    guard let user = Auth.auth().currentUser else {
      handleError(FirebaseError.authError("Not logged in"), userFriendlyMessage: "Not logged in")
      return
    }

    // Initialize profile data with Auth data
    var profileData = UserProfileData()
    profileData.email = user.email ?? ""
    profileData.displayName = user.displayName ?? ""
    profileData.isEmailVerified = user.isEmailVerified

    do {
      // Load user profile from Firestore
      if let userData = try await firebaseManager.getCurrentUserProfile() {
        profileData.displayName = userData["displayName"] as? String ?? profileData.displayName
        profileData.role = userData["role"] as? String ?? "student"

        updateState(.loaded(profileData))
      } else {
        handleError(FirebaseError.documentNotFound, userFriendlyMessage: "User profile not found")
      }
    } catch {
      handleError(error, userFriendlyMessage: "Failed to load profile")
    }
  }

  @MainActor
  override func refresh() async {
    resetState()
    await fetch()
  }

  // MARK: - Profile Update Methods

  @MainActor
  func updateProfile() async {
    guard let profileData = state.value else {
      handleError(
        FirebaseError.missingData("No profile data to update"),
        userFriendlyMessage: "No profile data to update")
      return
    }

    updateState(.loading)

    do {
      // Update displayName in Auth
      if let user = Auth.auth().currentUser {
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = profileData.displayName
        try await changeRequest.commitChanges()
      }

      // Update profile in Firestore
      try await firebaseManager.updateUserProfile(data: [
        "displayName": profileData.displayName
      ])

      // Show success message
      ui.alertMessage = "Profile updated successfully"
      ui.isShowingAlert = true

      // Refresh data to ensure we have the latest
      await fetch()
    } catch {
      handleError(error, userFriendlyMessage: "Failed to update profile")
    }
  }

  @MainActor
  func updateEmail() async {
    guard let profileData = state.value else {
      handleError(
        FirebaseError.missingData("No profile data available"),
        userFriendlyMessage: "No profile data available")
      return
    }

    guard !profileData.newEmail.isEmpty, !profileData.currentPassword.isEmpty else {
      handleError(
        FirebaseError.missingData("Please fill in all fields"),
        userFriendlyMessage: "Please fill in all fields")
      return
    }

    updateState(.loading)

    do {
      // Re-authenticate user first (required for sensitive operations)
      try await firebaseManager.reauthenticate(with: profileData.currentPassword)

      // Update email in Auth and Firestore
      try await firebaseManager.updateEmail(to: profileData.newEmail)

      // Update local state
      var updatedProfile = profileData
      updatedProfile.email = profileData.newEmail
      updatedProfile.newEmail = ""
      updatedProfile.currentPassword = ""

      updateState(.loaded(updatedProfile))

      // Close email change sheet
      ui.set("isChangingEmail", value: false)

      // Show success message
      ui.alertMessage = "Email updated successfully"
      ui.isShowingAlert = true
    } catch {
      handleError(error, userFriendlyMessage: "Failed to update email")
    }
  }

  @MainActor
  func sendVerificationEmail() async {
    updateState(.loading)

    do {
      try await firebaseManager.verifyEmail()

      // Show success message
      ui.alertMessage = "Verification email sent"
      ui.isShowingAlert = true

      // Refresh to get updated verification status
      await fetch()
    } catch {
      handleError(error, userFriendlyMessage: "Failed to send verification email")
    }
  }

  @MainActor
  func signOut() {
    do {
      try firebaseManager.signOut()
    } catch {
      handleError(error, userFriendlyMessage: "Failed to sign out")
    }
  }

  // MARK: - Form Field Update Methods

  @MainActor func updateDisplayName(_ newValue: String) {
    guard var profileData = state.value else { return }
    profileData.displayName = newValue
    updateState(.loaded(profileData))
  }

  @MainActor func updateNewEmail(_ newValue: String) {
    guard var profileData = state.value else { return }
    profileData.newEmail = newValue
    updateState(.loaded(profileData))
  }

  @MainActor func updateCurrentPassword(_ newValue: String) {
    guard var profileData = state.value else { return }
    profileData.currentPassword = newValue
    updateState(.loaded(profileData))
  }

  // MARK: - UI State Accessors

  var isChangingEmail: Bool {
    get { return ui.get("isChangingEmail") ?? false }
    set { ui.set("isChangingEmail", value: newValue) }
  }
}

//
//  UserProfileView.swift
//  TMI
//
//  Created by Chandan Brown on 9/16/24.
//

struct UserProfileView: View {
  @Environment(\.userProfileStateModel) private var stateModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        // Unified Background
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()

        Group {
          switch stateModel.state {
          case .idle, .loading:
            ProgressView()
              .scaleEffect(1.5)
              .frame(maxWidth: .infinity, maxHeight: .infinity)

          case .loaded(let profileData):
            userProfileForm(profileData)

          case .error(let error):
            VStack(spacing: 16) {
              Text("Error loading profile")
                .font(.headline)
                .foregroundColor(.white)

              Text(error.message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

              TMIButton(
                text: "Try Again",
                style: .primary,
                action: {
                  Task {
                    await stateModel.refresh()
                  }
                }
              )
            }
            .padding()
          }
        }
      }
      .navigationTitle("Profile")
      .foregroundColor(.white)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if case .loaded = stateModel.state {
            TMIButton(
              text: "Save",
              style: .primary,
              isDisabled: stateModel.isLoading,
              action: {
                Task {
                  await stateModel.updateProfile()
                }
              }
            )
          }
        }
      }
      .alert(isPresented: binding(stateModel, \.ui.isShowingAlert)) {
        Alert(
          title: Text(stateModel.ui.alertMessage.contains("Error") ? "Error" : "Success"),
          message: Text(stateModel.ui.alertMessage),
          dismissButton: .default(Text("OK"))
        )
      }
      .sheet(
        isPresented: Binding(
          get: { stateModel.isChangingEmail },
          set: { stateModel.isChangingEmail = $0 }
        )
      ) {
        if case .loaded(let profileData) = stateModel.state {
          ChangeEmailView(stateModel: stateModel, profileData: profileData)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  @ViewBuilder
  private func userProfileForm(_ profileData: UserProfileData) -> some View {
    ScrollView {
      VStack(spacing: 20) {
        // Profile Information Section
        TMIGlassCard(style: .default) {
          VStack(alignment: .leading, spacing: 16) {
            Text("Profile Information")
              .font(.headline)
              .foregroundColor(.white)

            HStack {
              Text("Email")
                .foregroundColor(.white)
              Spacer()
              Text(profileData.email)
                .foregroundColor(.white.opacity(0.7))
            }

            HStack {
              Text("Email Status")
                .foregroundColor(.white)
              Spacer()
              if profileData.isEmailVerified {
                Label("Verified", systemImage: "checkmark.circle.fill")
                  .foregroundColor(.green)
              } else {
                TMIButton(
                  text: "Verify Now",
                  style: .tertiary,
                  action: {
                    Task {
                      await stateModel.sendVerificationEmail()
                    }
                  }
                )
              }
            }

            VStack(alignment: .leading, spacing: 8) {
              Text("Display Name")
                .foregroundColor(.white)

              TMITextField(
                icon: "person",
                placeholder: "Display Name",
                text: Binding(
                  get: { profileData.displayName },
                  set: { stateModel.updateDisplayName($0) }
                )
              )
            }
          }
        }

        // Account Settings Section
        TMIGlassCard(style: .default) {
          VStack(alignment: .leading, spacing: 16) {
            Text("Account Settings")
              .font(.headline)
              .foregroundColor(.white)

            TMIButton(
              text: "Change Email",
              icon: "envelope",
              style: .secondary,
              action: {
                stateModel.isChangingEmail = true
              }
            )

            NavigationLink(destination: ChangePasswordView()) {
              HStack {
                Image(systemName: "lock")
                  .foregroundColor(Color.tmiPrimary)
                Text("Change Password")
                  .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundColor(.white.opacity(0.6))
              }
              .padding(.vertical, 8)
            }
          }
        }

        // Sign Out Section
        TMIGlassCard(style: .default) {
          TMIButton(
            text: "Sign Out",
            icon: "rectangle.portrait.and.arrow.right",
            style: .destructive,
            action: {
              stateModel.signOut()
              dismiss()
            }
          )
        }
      }
      .padding(20)
    }
  }
}

struct ChangeEmailView: View {
  let stateModel: UserProfileStateModel
  let profileData: UserProfileData
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        // Unified Background
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            TMIGlassCard(style: .default) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Change Email")
                  .font(.headline)
                  .foregroundColor(.white)

                TMITextField(
                  icon: "envelope",
                  placeholder: "New Email",
                  text: Binding(
                    get: { profileData.newEmail },
                    set: { stateModel.updateNewEmail($0) }
                  ),
                  keyboardType: .emailAddress
                )

                TMITextField(
                  icon: "lock",
                  placeholder: "Current Password",
                  text: Binding(
                    get: { profileData.currentPassword },
                    set: { stateModel.updateCurrentPassword($0) }
                  ),
                  isSecure: true
                )

                Text("You'll need to verify your new email after changing it.")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.7))
                  .padding(.top, 8)
              }
            }
          }
          .padding(20)
        }

        if stateModel.isLoading {
          ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.4))
        }
      }
      .navigationTitle("Change Email")
      .navigationBarTitleDisplayMode(.inline)
      .foregroundColor(.white)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          TMIButton(
            text: "Save",
            style: .primary,
            isDisabled: profileData.newEmail.isEmpty || profileData.currentPassword.isEmpty
              || stateModel.isLoading,
            action: {
              Task {
                await stateModel.updateEmail()
              }
            }
          )
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  UserProfileView()
}
