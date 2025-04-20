// RegistrationView.swift

import SwiftUI
import FirebaseAuth

struct RegistrationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.tmiPrimary)
                
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
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
                    
                    SecureField("Password", text: $password)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.tmiSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.tmiSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .submitLabel(.done)
                        .onSubmit {
                            register()
                        }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: register) {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .cornerRadius(10)
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isRegistering)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .email
                }
            }
        }
    }
    
    private func register() {
        // Validate input
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
        
        isRegistering = true
        errorMessage = nil
        
        Task {
            do {
                try await FIREBASE_MANAGER.signUp(email: email, password: password)
                isRegistering = false
                dismiss()
            } catch {
                isRegistering = false
                errorMessage = error.localizedDescription
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
