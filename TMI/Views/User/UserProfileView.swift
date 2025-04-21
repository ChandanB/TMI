//
//  UserProfileStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/16/24.
//

import SwiftUI
import FirebaseAuth
import Observation

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

struct UserProfileStateModelKey: EnvironmentKey {
    static let defaultValue: UserProfileStateModel = UserProfileStateModel()
}

extension EnvironmentValues {
    var userProfileStateModel: UserProfileStateModel {
        get { self[UserProfileStateModelKey.self] }
        set { self[UserProfileStateModelKey.self] = newValue }
    }
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
            handleError(FirebaseError.missingData("No profile data to update"), userFriendlyMessage: "No profile data to update")
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
            handleError(FirebaseError.missingData("No profile data available"), userFriendlyMessage: "No profile data available")
            return
        }
        
        guard !profileData.newEmail.isEmpty, !profileData.currentPassword.isEmpty else {
            handleError(FirebaseError.missingData("Please fill in all fields"), userFriendlyMessage: "Please fill in all fields")
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

import SwiftUI
import FirebaseAuth

struct UserProfileView: View {
    @Environment(\.userProfileStateModel) private var stateModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
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
                        
                        Text(error.message)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await stateModel.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if case .loaded = stateModel.state {
                        Button("Save") {
                            Task {
                                await stateModel.updateProfile()
                            }
                        }
                        .disabled(stateModel.isLoading)
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
            .sheet(isPresented: Binding(
                get: { stateModel.isChangingEmail },
                set: { stateModel.isChangingEmail = $0 }
            )) {
                if case .loaded(let profileData) = stateModel.state {
                    ChangeEmailView(stateModel: stateModel, profileData: profileData)
                }
            }
        }
    }
    
    @ViewBuilder
    private func userProfileForm(_ profileData: UserProfileData) -> some View {
        Form {
            Section(header: Text("Profile Information")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(profileData.email)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Email Status")
                    Spacer()
                    if profileData.isEmailVerified {
                        Label("Verified", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            Task {
                                await stateModel.sendVerificationEmail()
                            }
                        }) {
                            Text("Verify Now")
                                .foregroundColor(Color.tmiPrimary)
                        }
                    }
                }
                
                TextField("Display Name", text: Binding(
                    get: { profileData.displayName },
                    set: { stateModel.updateDisplayName($0) }
                ))
            }
            
            Section(header: Text("Account Settings")) {
                Button("Change Email") {
                    stateModel.isChangingEmail = true
                }
                
                NavigationLink(destination: ChangePasswordView()) {
                    Text("Change Password")
                }
            }
            
            Section {
                Button("Sign Out") {
                    stateModel.signOut()
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct ChangeEmailView: View {
    let stateModel: UserProfileStateModel
    let profileData: UserProfileData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Change Email")) {
                    TextField("New Email", text: Binding(
                        get: { profileData.newEmail },
                        set: { stateModel.updateNewEmail($0) }
                    ))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    
                    SecureField("Current Password", text: Binding(
                        get: { profileData.currentPassword },
                        set: { stateModel.updateCurrentPassword($0) }
                    ))
                }
                
                Text("You'll need to verify your new email after changing it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await stateModel.updateEmail()
                        }
                    }
                    .disabled(profileData.newEmail.isEmpty ||
                              profileData.currentPassword.isEmpty ||
                              stateModel.isLoading)
                }
            }
            .overlay {
                if stateModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
}


#Preview {
    UserProfileView()
}
