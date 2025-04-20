// AuthenticationView.swift

import SwiftUI
import FirebaseCore
import FirebaseAuth
import Observation

@Observable
class AuthenticationViewModel {
    // State properties
    var isLoggedIn: Bool = false
    var user: User?
    var isAuthenticating: Bool = false
    var errorMessage: String?
    
    // Input fields
    var email: String = ""
    var password: String = ""
    
    init() {
        setupFirebase()
        setupAuthListener()
    }
    
    private func setupFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    private func setupAuthListener() {
        self.user = Auth.auth().currentUser
        self.isLoggedIn = self.user != nil
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoggedIn = user != nil
        }
    }
    
    func signIn() async throws {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password cannot be empty"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        do {
            try await FIREBASE_MANAGER.signIn(email: email, password: password)
            self.user = Auth.auth().currentUser
            self.isLoggedIn = true
            self.isAuthenticating = false
            // Clear credentials after successful login
            clearCredentials()
        } catch {
            self.isAuthenticating = false
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        guard validateEmail() else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        do {
            try await FIREBASE_MANAGER.resetPassword(email: email)
            isAuthenticating = false
            errorMessage = "Password reset email sent. Please check your inbox."
        } catch {
            isAuthenticating = false
            errorMessage = "Failed to send password reset: \(error.localizedDescription)"
        }
    }
    
    func signOut() {
        do {
            try FIREBASE_MANAGER.signOut()
            isLoggedIn = false
            user = nil
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
            print(errorMessage ?? "")
        }
    }
    
    private func clearCredentials() {
        email = ""
        password = ""
    }
    
    func validateEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct AuthenticationView: View {
    @State private var showingRegistration = false
    @State private var showingForgotPassword = false
    @State private var viewModel = AuthenticationViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email
        case password
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Logo or App Icon
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color.tmiPrimary)
                    .padding(.top, 40)
                
                // Welcome Text
                Text("Welcome to TMI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.tmiPrimary)
                
                Text("Tangible Modification Intervention")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                
                // Input Fields
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .email)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.tmiSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                    
                    SecureField("Password", text: $viewModel.password)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.tmiSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .submitLabel(.done)
                        .onSubmit {
                            authenticate()
                        }
                }
                
                // Forgot Password
                HStack {
                    Spacer()
                    Button(action: {
                        showingForgotPassword = true
                    }) {
                        Text("Forgot Password?")
                            .font(.footnote)
                            .foregroundColor(Color.tmiPrimary)
                    }
                    .padding(.top, 4)
                }
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Login Button
                Button(action: authenticate) {
                    if viewModel.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .cornerRadius(10)
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(viewModel.isAuthenticating)
                .padding(.top, 10)
                
                // Sign Up Link
                Button(action: {
                    showingRegistration = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(Color.tmiPrimary)
                        .padding(.vertical, 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button("Cancel", role: .cancel) {}
                Button("Reset") {
                    Task {
                        await viewModel.resetPassword()
                    }
                }
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
            .onChange(of: viewModel.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    dismiss()
                }
            }
            .onAppear {
                // Set initial focus to email field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .email
                }
            }
        }
    }
    
    private func authenticate() {
        Task {
            do {
                try await viewModel.signIn()
            } catch {
                // Error is already handled in the ViewModel
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
