//
//  ChangePasswordView.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import SwiftUI
import FirebaseAuth
import Observation

// MARK: - Password Change Data Model

struct PasswordChangeData: Equatable {
    var currentPassword: String = ""
    var newPassword: String = ""
    var confirmPassword: String = ""
}

// MARK: - Environment Key

struct ChangePasswordStateModelKey: EnvironmentKey {
    static let defaultValue: ChangePasswordStateModel = ChangePasswordStateModel()
}

extension EnvironmentValues {
    var changePasswordStateModel: ChangePasswordStateModel {
        get { self[ChangePasswordStateModelKey.self] }
        set { self[ChangePasswordStateModelKey.self] = newValue }
    }
}

// MARK: - State Model

@Observable
final class ChangePasswordStateModel: BaseStateModel<PasswordChangeData, IdentifiableError> {
    // MARK: - Dependencies
    private let firebaseManager: FirebaseManager
    
    // MARK: - Initialization
    
    init(firebaseManager: FirebaseManager = FIREBASE_MANAGER) {
        self.firebaseManager = firebaseManager
        super.init()
    }
    
    override func fetch() async {
        // Initialize state
        updateState(.loaded(PasswordChangeData()))
    }
    
    // MARK: - Form Field Update Methods
    
    @MainActor func updateCurrentPassword(_ newValue: String) {
        guard var data = state.value else { return }
        data.currentPassword = newValue
        updateState(.loaded(data))
    }
    
    @MainActor func updateNewPassword(_ newValue: String) {
        guard var data = state.value else { return }
        data.newPassword = newValue
        updateState(.loaded(data))
    }
    
    @MainActor func updateConfirmPassword(_ newValue: String) {
        guard var data = state.value else { return }
        data.confirmPassword = newValue
        updateState(.loaded(data))
    }
    
    // MARK: - Password Update Method
    
    @MainActor
    func updatePassword(onSuccess: @escaping () -> Void) async {
        guard let data = state.value else {
            handleError(FirebaseError.missingData("No password data available"),
                        userFriendlyMessage: "No password data available")
            return
        }
        
        // Validate passwords
        guard data.newPassword == data.confirmPassword else {
            handleError(FirebaseError.missingData("New passwords don't match"),
                        userFriendlyMessage: "New passwords don't match")
            return
        }
        
        guard data.newPassword.count >= 8 else {
            handleError(FirebaseError.missingData("Password must be at least 8 characters"),
                        userFriendlyMessage: "Password must be at least 8 characters")
            return
        }
        
        updateState(.loading)
        
        do {
            // First re-authenticate the user
            try await firebaseManager.reauthenticate(with: data.currentPassword)
            
            // Then update the password
            if let user = Auth.auth().currentUser {
                try await user.updatePassword(to: data.newPassword)
                
                // Clear password data
                updateState(.loaded(PasswordChangeData()))
                
                // Show success message
                ui.alertMessage = "Password updated successfully"
                ui.isShowingAlert = true
                
                // Call success callback
                onSuccess()
            }
        } catch {
            handleError(error, userFriendlyMessage: "Failed to update password")
        }
    }
    
    // MARK: - Validation Methods
    
    var isFormValid: Bool {
        guard let data = state.value else { return false }
        return !data.currentPassword.isEmpty &&
        !data.newPassword.isEmpty &&
        !data.confirmPassword.isEmpty &&
        data.newPassword == data.confirmPassword &&
        data.newPassword.count >= 8
    }
}


struct ChangePasswordView: View {
    @Environment(\.changePasswordStateModel) private var stateModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            switch stateModel.state {
            case .idle:
                passwordChangeForm(PasswordChangeData())
                
            case .loaded(let passwordData):
                passwordChangeForm(passwordData)
                
            case .loading:
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
                
            case .error(let error):
                VStack(spacing: 16) {
                    Text("Error")
                        .font(.headline)
                    
                    Text(error.message)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        stateModel.resetState()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: binding(stateModel, \.ui.isShowingAlert)) {
            Alert(
                title: Text("Success"),
                message: Text(stateModel.ui.alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Dismiss the view after acknowledging success
                    dismiss()
                }
            )
        }
    }
    
    @ViewBuilder
    func passwordChangeForm(_ data: PasswordChangeData) -> some View {
        Form {
            Section(header: Text("Change Password")) {
                SecureField("Current Password", text: Binding(
                    get: { data.currentPassword },
                    set: { stateModel.updateCurrentPassword($0) }
                ))
                
                SecureField("New Password", text: Binding(
                    get: { data.newPassword },
                    set: { stateModel.updateNewPassword($0) }
                ))
                
                SecureField("Confirm New Password", text: Binding(
                    get: { data.confirmPassword },
                    set: { stateModel.updateConfirmPassword($0) }
                ))
            }
            
            if data.newPassword.count > 0 && data.newPassword.count < 8 {
                Text("Password must be at least 8 characters")
                    .foregroundColor(.red)
                    .font(.callout)
            }
            
            if data.confirmPassword.count > 0 && data.newPassword != data.confirmPassword {
                Text("New passwords don't match")
                    .foregroundColor(.red)
                    .font(.callout)
            }
            
            Button("Update Password") {
                Task {
                    await stateModel.updatePassword {
                        // Success callback - will dismiss after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                }
            }
            .disabled(!stateModel.isFormValid)
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
