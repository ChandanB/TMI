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
    
    // Animation states
    @State private var appearAnimation = false
    @State private var animateFields = false
    @State private var animateButton = false
    
    enum Field: Hashable {
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        ZStack {
            // Dynamic background
            DynamicBackgroundView()
            
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
                                .foregroundColor(.white)
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
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        
                        Text("Join the TMI community")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 30)
                    .opacity(appearAnimation ? 1.0 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .animation(
                        Animation.spring(response: 0.6, dampingFraction: 0.8)
                            .delay(0.2),
                        value: appearAnimation
                    )
                    
                    // Registration Form
                    GlassCard {
                        VStack(spacing: 24) {
                            // Email field
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
                                    .delay(0.3),
                                value: animateFields
                            )
                            
                            // Password field
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
                            
                            // Confirm Password field
                            TMITextField(
                                icon: "lock.shield.fill",
                                placeholder: "Confirm Password",
                                text: $confirmPassword,
                                isSecure: true,
                                onSubmit: {
                                    register()
                                }
                            )
                            .focused($focusedField, equals: .confirmPassword)
                            .offset(x: animateFields ? 0 : -30)
                            .opacity(animateFields ? 1.0 : 0)
                            .animation(
                                Animation.spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(0.5),
                                value: animateFields
                            )
                            
                            // Error Message
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.red.opacity(0.9))
                                    .padding(.horizontal)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            
                            // Register Button
                            TMIButton(
                                text: "Create Account",
                                icon: "checkmark.circle",
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
                        .foregroundColor(Color.white.opacity(0.8))
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
                .padding(.bottom, 100) // Extra padding at bottom for keyboard
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .medium))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
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
