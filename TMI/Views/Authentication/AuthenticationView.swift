// AuthenticationView.swift

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showingRegistration = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Welcome to TMI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.tmiSecondary.opacity(0.1))
                        .cornerRadius(10)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    authViewModel.signIn(email: email, password: password) { error in
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Log In")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.tmiPrimary)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingRegistration = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.tmiSecondary)
                }
                .sheet(isPresented: $showingRegistration) {
                    RegistrationView()
                        .environment(authViewModel)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    AuthenticationView()
}
