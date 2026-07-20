//
//  AuthenticationService.swift
//  TMI
//
//  Centralized authentication service for unified signup/signin flows
//

import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Centralized authentication service that consolidates all signup/signin logic
final class AuthenticationService {
    static let shared = AuthenticationService()

    private let firebaseManager = FirebaseManager.shared
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Authentication Errors

    enum AuthError: LocalizedError {
        case institutionCodeRequired
        case invalidRole
        case ageVerificationRequired
        case parentalConsentRequired
        case institutionNotFound
        case districtNotFound
        case emailAlreadyInUse
        case weakPassword
        case invalidEmail
        case userCreationFailed(String)

        var errorDescription: String? {
            switch self {
            case .institutionCodeRequired:
                return "An institution code is required for this role"
            case .invalidRole:
                return "Invalid user role selected"
            case .ageVerificationRequired:
                return "Age verification is required for student accounts"
            case .parentalConsentRequired:
                return "Parental consent is required for students under 13"
            case .institutionNotFound:
                return "Institution not found. Please verify your institution code"
            case .districtNotFound:
                return "District not found. Please contact your administrator"
            case .emailAlreadyInUse:
                return "This email address is already in use"
            case .weakPassword:
                return "Password must be at least 8 characters with uppercase, lowercase, and numbers"
            case .invalidEmail:
                return "Please enter a valid email address"
            case .userCreationFailed(let message):
                return "Failed to create user account: \(message)"
            }
        }
    }

    // MARK: - Unified Sign Up

    /// Unified signup method that validates role requirements and creates properly structured user
    func signUp(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        institutionCode: String? = nil,
        dateOfBirth: Date? = nil
    ) async throws -> TMIUser {
        let normalizedInstitutionCode = institutionCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate inputs
        try validateSignupInputs(
            email: email,
            password: password,
            role: role,
            institutionCode: normalizedInstitutionCode,
            dateOfBirth: dateOfBirth
        )

        // Verify institution if code provided
        var verifiedInstitutionName: String?

        if let code = normalizedInstitutionCode, !code.isEmpty {
            let institutionData = try await verifyInstitution(code: code)
            verifiedInstitutionName = institutionData.name
        }

        // Create Firebase auth user
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = authResult.user.uid

        // Determine verification statuses
        let ageVerificationStatus: AgeVerificationStatus = determineAgeVerificationStatus(
            role: role,
            dateOfBirth: dateOfBirth
        )

        let parentalConsentStatus: ParentalConsentStatus = determineParentalConsentStatus(
            role: role,
            dateOfBirth: dateOfBirth
        )

        // Create TMIUser with validated data
        let user = TMIUser(
            userID: uid,
            displayName: "\(firstName) \(lastName)",
            email: email,
            isEmailVerified: false,
            requestedRole: role,
            dateOfBirth: dateOfBirth,
            institutionCode: normalizedInstitutionCode,
            institutionName: verifiedInstitutionName,
            verificationStatus: VerificationStatus(
                isEmailVerified: false,
                isAgeVerified: ageVerificationStatus == .verified,
                isInstitutionVerified: verifiedInstitutionName != nil
            ),
            consentRecords: [],
            parentalConsentStatus: parentalConsentStatus,
            ageVerificationStatus: ageVerificationStatus,
            privacySettings: PrivacySettings(),
            createdAt: Date(),
            lastLoginAt: Date(),
            lastActivityAt: Date(),
            emergencyContacts: []
        )

        // Save to Firestore
        try await saveUserToFirestore(user)

        Log.auth.info(
            "account_created",
            metadata: [
                "userID": uid,
                "requestedRole": role.rawValue,
            ]
        )

        return user
    }

    // MARK: - Validation Helpers

    private func validateSignupInputs(
        email: String,
        password: String,
        role: UserRole,
        institutionCode: String?,
        dateOfBirth: Date?
    ) throws {
        // Validate email format
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        // Validate password strength
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        // Students require date of birth for age verification
        if role == .student {
            guard dateOfBirth != nil else {
                throw AuthError.ageVerificationRequired
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func determineAgeVerificationStatus(role: UserRole, dateOfBirth: Date?) -> AgeVerificationStatus {
        guard role == .student, let dob = dateOfBirth else {
            return .notRequired
        }

        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0

        if age >= 13 {
            return .verified
        } else {
            return .required
        }
    }

    private func determineParentalConsentStatus(role: UserRole, dateOfBirth: Date?) -> ParentalConsentStatus {
        guard role == .student, let dob = dateOfBirth else {
            return .notRequired
        }

        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0

        if age < 13 {
            return .required
        } else {
            return .notRequired
        }
    }

    // MARK: - Institution Verification

    private struct InstitutionData {
        let name: String
    }

    private func verifyInstitution(code: String) async throws -> InstitutionData {
        // Query institutions collection by code
        let query = db.collection("institutions").whereField("code", isEqualTo: code)
        let snapshot = try await query.getDocuments()

        guard let document = snapshot.documents.first else {
            throw AuthError.institutionNotFound
        }

        let data = document.data()
        return InstitutionData(
            name: data["name"] as? String ?? "Unknown Institution"
        )
    }

    // MARK: - Firestore Operations

    private func saveUserToFirestore(_ user: TMIUser) async throws {
        do {
            try db.collection("users")
                .document(user.userID)
                .setData(from: user)
        } catch {
            throw AuthError.userCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Sign In

    /// Sign in existing user
    func signIn(email: String, password: String) async throws {
        try await firebaseManager.signIn(withEmail: email, password: password)
    }

    // MARK: - Password Reset

    /// Send password reset email
    func resetPassword(email: String) async throws {
        try await firebaseManager.resetPassword(email: email)
    }

    // MARK: - Sign Out

    /// Sign out current user
    func signOut() throws {
        try firebaseManager.signOut()
    }

}
