//
//  AuthStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// Simple Field enum for compatibility with AuthenticationView
enum Field: Hashable {
  case email  
  case password
}

// MARK: - Enhanced Authentication State

enum EnhancedAuthenticationState: Equatable {
  case unauthenticated
  case registering(RegistrationStep)
  case authenticating
  case verifying(VerificationType)
  case awaitingConsent(ConsentType)
  case authenticated(TMIUser)
  case error(AuthenticationError)
  case suspended(SuspensionReason)

  static func == (lhs: EnhancedAuthenticationState, rhs: EnhancedAuthenticationState) -> Bool {
    switch (lhs, rhs) {
    case (.unauthenticated, .unauthenticated):
      return true
    case (.registering(let step1), .registering(let step2)):
      return step1 == step2
    case (.authenticating, .authenticating):
      return true
    case (.verifying(let type1), .verifying(let type2)):
      return type1 == type2
    case (.awaitingConsent(let consent1), .awaitingConsent(let consent2)):
      return consent1 == consent2
    case (.authenticated(let user1), .authenticated(let user2)):
      return user1.id == user2.id
    case (.error(let error1), .error(let error2)):
      return error1.id == error2.id
    case (.suspended(let reason1), .suspended(let reason2)):
      return reason1 == reason2
    default:
      return false
    }
  }
}

// MARK: - Registration Steps

enum RegistrationStep: String, CaseIterable, Equatable {
  case initial = "initial"
  case roleSelection = "role_selection"
  case ageVerification = "age_verification"
  case emailVerification = "email_verification"
  case institutionVerification = "institution_verification"
  case credentialVerification = "credential_verification"
  case guardianConsent = "guardian_consent"
  case parentalConsent = "parental_consent"
  case basicInfo = "basic_info"
  case privacySettings = "privacy_settings"
  case traumaInformedConsent = "trauma_informed_consent"
  case emergencyContacts = "emergency_contacts"
  case mfaSetup = "mfa_setup"
  case completion = "completion"

  var displayName: String {
    switch self {
    case .initial: return "Welcome"
    case .roleSelection: return "Select Role"
    case .ageVerification: return "Age Verification"
    case .emailVerification: return "Email Verification"
    case .institutionVerification: return "Institution Verification"
    case .credentialVerification: return "Credential Verification"
    case .guardianConsent: return "Guardian Consent"
    case .parentalConsent: return "Parental Consent"
    case .basicInfo: return "Basic Information"
    case .privacySettings: return "Privacy Settings"
    case .traumaInformedConsent: return "Consent for Support"
    case .emergencyContacts: return "Emergency Contacts"
    case .mfaSetup: return "Security Setup"
    case .completion: return "Welcome to TMI"
    }
  }

  var description: String {
    switch self {
    case .initial: return "Welcome to TMI's trauma-informed educational platform"
    case .roleSelection: return "Help us understand how you'll be using TMI"
    case .ageVerification: return "We need to verify your age for compliance"
    case .emailVerification: return "Please verify your email address"
    case .institutionVerification: return "Connect with your educational institution"
    case .credentialVerification: return "Verify your professional credentials"
    case .guardianConsent: return "Guardian consent is required for this account"
    case .parentalConsent: return "Parental consent is required for users under 13"
    case .basicInfo: return "Tell us a bit about yourself"
    case .privacySettings: return "Choose your privacy preferences"
    case .traumaInformedConsent: return "Consent for trauma-informed support services"
    case .emergencyContacts: return "Add emergency contact information"
    case .mfaSetup: return "Set up additional security for your account"
    case .completion: return "Your account is ready!"
    }
  }

  var isOptional: Bool {
    switch self {
    case .emergencyContacts, .mfaSetup:
      return true
    default:
      return false
    }
  }

  var requiresNetworkAccess: Bool {
    switch self {
    case .emailVerification, .institutionVerification, .credentialVerification, .guardianConsent,
      .parentalConsent:
      return true
    default:
      return false
    }
  }
}

// MARK: - Authentication Error

struct AuthenticationError: Error, Identifiable, Equatable {
  let id: String
  let type: AuthenticationErrorType
  let message: String
  let traumaInformedMessage: String
  let recoverySuggestions: [String]
  let supportResources: [SupportResource]
  let timestamp: Date

  init(
    id: String = UUID().uuidString,
    type: AuthenticationErrorType,
    message: String,
    traumaInformedMessage: String? = nil,
    recoverySuggestions: [String] = [],
    supportResources: [SupportResource] = [],
    timestamp: Date = Date()
  ) {
    self.id = id
    self.type = type
    self.message = message
    self.traumaInformedMessage = traumaInformedMessage ?? type.defaultTraumaInformedMessage
    self.recoverySuggestions =
      recoverySuggestions.isEmpty ? type.defaultRecoverySuggestions : recoverySuggestions
    self.supportResources =
      supportResources.isEmpty ? type.defaultSupportResources : supportResources
    self.timestamp = timestamp
  }

  static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
    return lhs.id == rhs.id
  }
}

enum AuthenticationErrorType: String, CaseIterable {
  case invalidCredentials = "invalid_credentials"
  case accountNotFound = "account_not_found"
  case accountLocked = "account_locked"
  case accountSuspended = "account_suspended"
  case emailNotVerified = "email_not_verified"
  case ageVerificationFailed = "age_verification_failed"
  case institutionVerificationFailed = "institution_verification_failed"
  case missingConsent = "missing_consent"
  case expiredConsent = "expired_consent"
  case parentalConsentRequired = "parental_consent_required"
  case parentalConsentDenied = "parental_consent_denied"
  case mfaRequired = "mfa_required"
  case mfaFailed = "mfa_failed"
  case networkError = "network_error"
  case serverError = "server_error"
  case unknownError = "unknown_error"

  var defaultTraumaInformedMessage: String {
    switch self {
    case .invalidCredentials:
      return
        "It looks like the email or password isn't quite right. No worries - this happens to everyone!"
    case .accountNotFound:
      return "We don't have an account with that email address yet. Would you like to create one?"
    case .accountLocked:
      return
        "Your account has been temporarily secured for your safety. Let's get this resolved together."
    case .accountSuspended:
      return "Your account needs some attention. We're here to help you get back on track."
    case .emailNotVerified:
      return "We need to verify your email address to keep your account secure."
    case .ageVerificationFailed:
      return "We need to verify your age to ensure we're providing the right protections for you."
    case .institutionVerificationFailed:
      return
        "We're having trouble connecting you with your institution. Let's work through this together."
    case .missingConsent, .expiredConsent:
      return "We need to update your consent preferences to continue protecting your information."
    case .parentalConsentRequired:
      return "For your safety, we need permission from your parent or guardian to continue."
    case .parentalConsentDenied:
      return "Your parent or guardian hasn't given permission yet. They can update this anytime."
    case .mfaRequired:
      return "We need to verify it's really you with an additional security check."
    case .mfaFailed:
      return "The security code didn't match. Let's try again when you're ready."
    case .networkError:
      return
        "We're having trouble connecting right now. Your information is safe - let's try again in a moment."
    case .serverError:
      return
        "Something went wrong on our end. Your information is secure, and we're working to fix this."
    case .unknownError:
      return "Something unexpected happened. You're safe, and we're here to help figure this out."
    }
  }

  var defaultRecoverySuggestions: [String] {
    switch self {
    case .invalidCredentials:
      return [
        "Double-check your email address",
        "Try retyping your password",
        "Use the 'Forgot Password' option if needed",
      ]
    case .accountNotFound:
      return [
        "Check the spelling of your email address",
        "Try a different email if you have multiple accounts",
        "Create a new account if this is your first time",
      ]
    case .accountLocked:
      return [
        "Wait a few minutes and try again",
        "Contact support for immediate assistance",
        "Use the password reset option",
      ]
    case .emailNotVerified:
      return [
        "Check your email inbox for a verification message",
        "Check your spam/junk folder",
        "Request a new verification email",
      ]
    case .networkError:
      return [
        "Check your internet connection",
        "Try again in a few moments",
        "Contact support if the problem continues",
      ]
    default:
      return [
        "Take a deep breath - you're safe",
        "Try again when you feel ready",
        "Contact our support team for personalized help",
      ]
    }
  }

  var defaultSupportResources: [SupportResource] {
    return [
      SupportResource(
        type: .helpCenter,
        title: "Help Center",
        description: "Find answers to common questions",
        url: "https://tmi.help"
      ),
      SupportResource(
        type: .supportChat,
        title: "Chat with Support",
        description: "Get real-time help from our team",
        url: "https://tmi.support/chat"
      ),
    ]
  }
}

// MARK: - Support Resources

struct SupportResource: Identifiable, Equatable {
  let id: String
  let type: SupportResourceType
  let title: String
  let description: String
  let url: String
  let isEmergency: Bool

  init(
    id: String = UUID().uuidString,
    type: SupportResourceType,
    title: String,
    description: String,
    url: String,
    isEmergency: Bool = false
  ) {
    self.id = id
    self.type = type
    self.title = title
    self.description = description
    self.url = url
    self.isEmergency = isEmergency
  }
}

enum SupportResourceType: String, CaseIterable {
  case helpCenter = "help_center"
  case supportChat = "support_chat"
  case emergencySupport = "emergency_support"
  case parentalSupport = "parental_support"
  case institutionalSupport = "institutional_support"
  case traumaSupport = "trauma_support"

  var displayName: String {
    switch self {
    case .helpCenter: return "Help Center"
    case .supportChat: return "Live Support"
    case .emergencySupport: return "Emergency Support"
    case .parentalSupport: return "Parent/Guardian Support"
    case .institutionalSupport: return "Institution Support"
    case .traumaSupport: return "Trauma-Informed Support"
    }
  }
}

// MARK: - Suspension Reason

enum SuspensionReason: String, CaseIterable, Equatable {
  case securityConcern = "security_concern"
  case policyViolation = "policy_violation"
  case complianceIssue = "compliance_issue"
  case parentalRequest = "parental_request"
  case institutionalRequest = "institutional_request"
  case dataProtectionConcern = "data_protection_concern"

  var displayName: String {
    switch self {
    case .securityConcern: return "Security Concern"
    case .policyViolation: return "Policy Violation"
    case .complianceIssue: return "Compliance Issue"
    case .parentalRequest: return "Parental Request"
    case .institutionalRequest: return "Institutional Request"
    case .dataProtectionConcern: return "Data Protection Concern"
    }
  }

  var traumaInformedMessage: String {
    switch self {
    case .securityConcern:
      return
        "We've temporarily secured your account to protect your information. We're here to help resolve this safely."
    case .policyViolation:
      return
        "Your account needs some attention to ensure everyone feels safe. Let's work together to address this."
    case .complianceIssue:
      return
        "We need to make sure we're following all the rules that keep you protected. This is just a precaution."
    case .parentalRequest:
      return
        "Your parent or guardian has requested that we pause your account. They can reactivate it anytime."
    case .institutionalRequest:
      return
        "Your school has asked us to temporarily pause your account. They can provide more information."
    case .dataProtectionConcern:
      return
        "We're taking extra care to protect your information. Your safety and privacy are our top priorities."
    }
  }
}

// MARK: - Environment Key
extension EnvironmentValues {
  @Entry var authStateModel: AuthStateModel = AuthStateModel()
}

// MARK: - Auth State Model

@Observable
final class AuthStateModel: BaseStateModel<EnhancedAuthenticationState, IdentifiableError> {

  // MARK: - Dependencies
  private let firebaseManager: FirebaseManager
  private let auditService: AuditService

  // MARK: - Current User State
  private(set) var currentUser: TMIUser?
  private(set) var userRole: UserRole?
  private(set) var institutionContext: Institution?
  private(set) var privacyLevel: PrivacyLevel = .standard

  // MARK: - Registration Tracking
  private(set) var registrationStep: RegistrationStep = .initial
  private(set) var registrationData: RegistrationData = RegistrationData()
  private(set) var pendingVerifications: [VerificationType] = []

  // MARK: - Consent Management
  private(set) var consentStatus: ConsentStatus = .pending
  private(set) var parentalConsentStatus: ParentalConsentStatus = .notRequired
  private(set) var requiredConsents: [ConsentType] = []
  private(set) var grantedConsents: [ConsentRecord] = []

  // MARK: - Authentication Context
  private(set) var sessionID: String?
  private(set) var deviceInfo: DeviceInfo?
  private(set) var lastActivity: Date = Date()
  private(set) var authenticationMethod: AuthenticationMethod = .emailPassword
  private(set) var mfaEnabled: Bool = false
  private(set) var securityLevel: SecurityLevel = .standard

  // MARK: - Form Fields
  private(set) var email: String = ""
  private(set) var password: String = ""
  private(set) var confirmPassword: String = ""
  private(set) var selectedRole: UserRole?
  private(set) var dateOfBirth: Date?
  private(set) var institutionCode: String = ""
  private(set) var guardianEmail: String = ""

  // MARK: - UI State
  var showingRegistration: Bool {
    get { ui.get("showingRegistration") ?? false }
    set { ui.set("showingRegistration", value: newValue) }
  }

  var showingForgotPassword: Bool {
    get { ui.get("showingForgotPassword") ?? false }
    set { ui.set("showingForgotPassword", value: newValue) }
  }

  var showingSupportResources: Bool {
    get { ui.get("showingSupportResources") ?? false }
    set { ui.set("showingSupportResources", value: newValue) }
  }

  var focusedField: AuthField? {
    get { ui.get("focusedField") }
    set { ui.set("focusedField", value: newValue) }
  }

  var currentError: AuthenticationError? {
    get { ui.get("currentError") }
    set { ui.set("currentError", value: newValue) }
  }

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

  var isRegistering: Bool {
    if case .loaded(.registering) = state {
      return true
    }
    return false
  }

  var requiresVerification: Bool {
    if case .loaded(.verifying) = state {
      return true
    }
    return false
  }

  var awaitingConsent: Bool {
    if case .loaded(.awaitingConsent) = state {
      return true
    }
    return false
  }

  var isSuspended: Bool {
    if case .loaded(.suspended) = state {
      return true
    }
    return false
  }

  override var errorMessage: String? {
    if case .loaded(.error(let error)) = state {
      return error.traumaInformedMessage
    }
    if case .error(let error) = state {
      return error.message
    }
    return nil
  }

  var currentAuthState: EnhancedAuthenticationState? {
    if case .loaded(let authState) = state {
      return authState
    }
    return nil
  }

  // MARK: - Initialization
  init(
    firebaseManager: FirebaseManager = FIREBASE_MANAGER, auditService: AuditService = AUDIT_SERVICE
  ) {
    self.firebaseManager = firebaseManager
    self.auditService = auditService
    super.init()

    Task { await fetch() }
  }

  override func fetch() async {
    await setupInitialState()
    await setupAuthListener()
    await initializeDeviceInfo()
  }

  // MARK: - Setup Methods

  @MainActor
  private func setupInitialState() async {
    // Initialize UI state
    ui.set("showingRegistration", value: false)
    ui.set("showingForgotPassword", value: false)
    ui.set("showingSupportResources", value: false)
    ui.set("focusedField", value: nil as AuthField?)
    ui.set("currentError", value: nil as AuthenticationError?)

    // Initialize session
    sessionID = UUID().uuidString

    // Set initial auth state
    updateState(.loaded(.unauthenticated))
  }

  @MainActor
  private func setupAuthListener() async {
    let currentFirebaseUser = Auth.auth().currentUser

    if let firebaseUser = currentFirebaseUser {
      await loadUserProfile(for: firebaseUser.uid)
    } else {
      updateState(.loaded(.unauthenticated))
    }

    // Set up Firebase auth state listener
    let _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      guard let self = self else { return }

      Task { @MainActor in
        if let user = user {
          await self.loadUserProfile(for: user.uid)
        } else {
          self.updateState(.loaded(.unauthenticated))
          await self.logAuditEvent(.logout, result: .success)
        }
      }
    }
  }

  private func initializeDeviceInfo() async {
    deviceInfo = DeviceInfo(
      deviceType: .iPhone,  // Would detect actual device type
      operatingSystem: "iOS",
      osVersion: "17.0",  // Would get actual version
      appVersion: "1.0.0",  // Would get from bundle
      deviceModel: "iPhone 15 Pro",
      deviceID: "mock-device-id",
      timezone: TimeZone.current.identifier,
      locale: Locale.current.identifier
    )
  }

    @MainActor
    private func loadUserProfile(for userID: String) async {
        // Load user profile from Firestore
        let userDoc: DocumentSnapshot
        do {
                userDoc = try await firebaseManager.firestore
                    .collection("users")
                    .document(userID)
                    .getDocument()
            } catch {
                print("[AuthStateModel] Firestore fetch failed for userID=\(userID):", error, String(describing: type(of: error)))
                updateState(
                    .loaded(
                        .error(
                            AuthenticationError(
                                type: .serverError,
                                message: "Firestore fetch failed: \(error.localizedDescription)"
                            ))))
                return
            }
            
            guard let userData = userDoc.data() else {
                print("[AuthStateModel] No user data found for userID=\(userID). Document exists: \(userDoc.exists)")
                // User authenticated but no profile - start registration
                updateState(.loaded(.registering(.basicInfo)))
                return
            }
            
            var user: TMIUser
            do {
                user = try Firestore.Decoder().decode(TMIUser.self, from: userData)
            } catch {
                print("[AuthStateModel] Decoding TMIUser failed for userID=\(userID):", error, String(describing: type(of: error)), "Raw data:", userData)
                updateState(
                    .loaded(
                        .error(
                            AuthenticationError(
                                type: .serverError,
                                message: "Failed to decode user profile: \(error.localizedDescription)"
                            ))))
                return
            }
            
            // Sync email verification status from Firebase Auth
            if let firebaseUser = Auth.auth().currentUser {
                user.isEmailVerified = firebaseUser.isEmailVerified
                user.verificationStatus.isEmailVerified = firebaseUser.isEmailVerified
                
                print("[AuthStateModel] Synced email verification status for userID=\(userID): \(firebaseUser.isEmailVerified)")
                
                // Update Firestore document if email verification status changed
                if user.isEmailVerified != (userData["isEmailVerified"] as? Bool ?? false) {
                    Task {
                        do {
                            try await firebaseManager.firestore
                                .collection("users")
                                .document(userID)
                                .updateData([
                                    "isEmailVerified": user.isEmailVerified,
                                    "verificationStatus.isEmailVerified": user.isEmailVerified
                                ])
                            print("[AuthStateModel] Updated email verification status in Firestore for userID=\(userID)")
                        } catch {
                            print("[AuthStateModel] Failed to update email verification status in Firestore for userID=\(userID):", error)
                        }
                    }
                }
            }
            
            // Note: We don't block login based on verification status anymore.
            // Verification is checked when accessing specific features within the app.
            // If Firebase Auth allowed them in, they can access the basic app.
            if !user.verificationStatus.isValid {
                print("[AuthStateModel] User has minimal verification for userID=\(userID). Verification status:", user.verificationStatus)
                print("[AuthStateModel] User can access app, but some features may require additional verification")
            }
            
            // Check consent status - only block for critical missing consent
            if user.requiresParentalConsent && !user.hasValidConsent {
                print("[AuthStateModel] Minor user missing parental consent for userID=\(userID)")
                updateState(.loaded(.awaitingConsent(.coppa)))
                return
            }
            
            // Log consent status but don't block access for basic data collection consent
            if !user.hasValidConsent {
                print("[AuthStateModel] User may need additional consent for some features, userID=\(userID)")
            }
            
            // Seed initial data for new educators (sample students, interests, hobbies)
            // This ensures viable educator onboarding.
            do {
                try await firebaseManager.seedInitialEducatorDataIfNeeded()
            } catch {
                print("[AuthStateModel] Seeding initial educator data failed for userID=\(userID):", error)
                // Optional: Log or handle seeding error silently
            }
            
            // All checks passed - user is authenticated
            currentUser = user
            userRole = user.role
            print("[AuthStateModel] Successfully loaded user profile for userID=\(userID). Role: \(user.role)")
            updateState(.loaded(.authenticated(user)))
            
        await logAuditEvent(.login, result: .success)
    }

  // MARK: - Form Field Methods

  func updateEmail(_ newValue: String) {
    email = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func updatePassword(_ newValue: String) {
    password = newValue
  }

  func updateConfirmPassword(_ newValue: String) {
    confirmPassword = newValue
  }

  func updateSelectedRole(_ role: UserRole) {
    selectedRole = role
    registrationData.selectedRole = role

    // Update required verifications and consents based on role
    pendingVerifications = [role.requiredVerification]
    updateRequiredConsents(for: role)
  }

  func updateDateOfBirth(_ date: Date) {
    dateOfBirth = date
    registrationData.dateOfBirth = date

    // Check if parental consent is required
    let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    if age < 13 {
      parentalConsentStatus = .required
      if !requiredConsents.contains(.coppa) {
        requiredConsents.append(.coppa)
      }
    } else {
      parentalConsentStatus = .notRequired
      requiredConsents.removeAll { $0 == .coppa }
    }
  }

  func updateInstitutionCode(_ code: String) {
    // Institution code is optional and NOT required to complete registration.
    // Users may enter it if they wish, but registration proceeds regardless.
    institutionCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    registrationData.institutionCode = code
  }

  func updateGuardianEmail(_ email: String) {
    guardianEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    registrationData.guardianEmail = email
  }

  private func updateRequiredConsents(for role: UserRole) {
    requiredConsents = [.dataCollection]

    if [.teacher, .counselor, .administrator, .admin, .socialWorker].contains(role) {
      requiredConsents.append(.ferpa)
    }

    if role == .counselor || role == .socialWorker {
      requiredConsents.append(.traumaInformedSupport)
    }

    // COPPA consent is added based on age, not role
  }

  func clearCredentials() {
    email = ""
    password = ""
    confirmPassword = ""
  }

  // MARK: - Authentication Methods

  @MainActor
  func signIn() async {
    guard !email.isEmpty, !password.isEmpty else {
      let error = AuthenticationError(
        type: .invalidCredentials,
        message: "Email and password are required"
      )
      updateState(.loaded(.error(error)))
      await logAuditEvent(.loginFailed, result: .failure)
      return
    }

    guard validateEmail() else {
      let error = AuthenticationError(
        type: .invalidCredentials,
        message: "Please enter a valid email address"
      )
      updateState(.loaded(.error(error)))
      await logAuditEvent(.loginFailed, result: .failure)
      return
    }

    updateState(.loaded(.authenticating))

    do {
      try await firebaseManager.signIn(withEmail: email, password: password)
      // Firebase auth listener will handle the rest
      clearCredentials()
    } catch {
      let authError = AuthenticationError(
        type: .invalidCredentials,
        message: error.localizedDescription
      )
      updateState(.loaded(.error(authError)))
      await logAuditEvent(.loginFailed, result: .failure)
    }
  }

  @MainActor
  func signOut() {
    do {
      try firebaseManager.signOut()
      // Clear local state
      currentUser = nil
      userRole = nil
      institutionContext = nil
      sessionID = nil

      updateState(.loaded(.unauthenticated))
    } catch {
      let authError = AuthenticationError(
        type: .serverError,
        message: "Failed to sign out: \(error.localizedDescription)"
      )
      updateState(.loaded(.error(authError)))
    }
  }

  @MainActor
  func resetPassword() async {
    guard !email.isEmpty else {
      let error = AuthenticationError(
        type: .invalidCredentials,
        message: "Please enter your email address"
      )
      updateState(.loaded(.error(error)))
      return
    }

    guard validateEmail() else {
      let error = AuthenticationError(
        type: .invalidCredentials,
        message: "Please enter a valid email address"
      )
      updateState(.loaded(.error(error)))
      return
    }

    updateState(.loaded(.authenticating))

    do {
      try await firebaseManager.resetPassword(email: email)
      // Show success message
      ui.alertMessage = "Password reset email sent. Please check your inbox."
      ui.isShowingAlert = true
      updateState(.loaded(.unauthenticated))

      await logAuditEvent(.loginFailed, result: .success)
    } catch {
      let authError = AuthenticationError(
        type: .serverError,
        message: "Failed to send password reset: \(error.localizedDescription)"
      )
      updateState(.loaded(.error(authError)))
      await logAuditEvent(.loginFailed, result: .failure)
    }
  }

  // MARK: - Registration Methods

  @MainActor
  func startRegistration() {
    registrationStep = .roleSelection
    updateState(.loaded(.registering(.roleSelection)))
  }

  @MainActor
  func nextRegistrationStep() {
    guard let currentRole = selectedRole else { return }

    let nextStep = determineNextStep(from: registrationStep, for: currentRole)
    registrationStep = nextStep
    updateState(.loaded(.registering(nextStep)))
  }

  @MainActor
  func previousRegistrationStep() {
    let previousStep = determinePreviousStep(from: registrationStep)
    registrationStep = previousStep
    updateState(.loaded(.registering(previousStep)))
  }

  private func determineNextStep(from currentStep: RegistrationStep, for role: UserRole)
    -> RegistrationStep
  {
    switch currentStep {
    case .initial, .roleSelection:
      return .ageVerification
    case .ageVerification:
      return .emailVerification
    case .emailVerification:
      if role.requiresInstitutionalAffiliation {
        // Proceed to institutionVerification regardless of institutionCode presence
        return .institutionVerification
      } else if role == .socialWorker {
        return .credentialVerification
      } else {
        return .basicInfo
      }
    case .institutionVerification:
      // Proceed to next step even if institutionCode is empty - institution code is optional.
      if role == .socialWorker {
        return .credentialVerification
      } else {
        return .basicInfo
      }
    case .credentialVerification:
      return .basicInfo
    case .basicInfo:
      if parentalConsentStatus == .required {
        return .parentalConsent
      } else if role.isGuardian {
        return .guardianConsent
      } else {
        return .privacySettings
      }
    case .parentalConsent, .guardianConsent:
      return .privacySettings
    case .privacySettings:
      return .traumaInformedConsent
    case .traumaInformedConsent:
      return .emergencyContacts
    case .emergencyContacts:
      return .mfaSetup
    case .mfaSetup:
      return .completion
    case .completion:
      return .completion
    }
  }

  private func determinePreviousStep(from currentStep: RegistrationStep) -> RegistrationStep {
    switch currentStep {
    case .initial:
      return .initial
    case .roleSelection:
      return .initial
    case .ageVerification:
      return .roleSelection
    case .emailVerification:
      return .ageVerification
    case .institutionVerification:
      return .emailVerification
    case .credentialVerification:
      return .institutionVerification
    case .basicInfo:
      if selectedRole?.requiresInstitutionalAffiliation == true {
        return selectedRole == .socialWorker ? .credentialVerification : .institutionVerification
      } else {
        return .emailVerification
      }
    case .parentalConsent:
      return .basicInfo
    case .guardianConsent:
      return .basicInfo
    case .privacySettings:
      if parentalConsentStatus == .required {
        return .parentalConsent
      } else if selectedRole?.isGuardian == true {
        return .guardianConsent
      } else {
        return .basicInfo
      }
    case .traumaInformedConsent:
      return .privacySettings
    case .emergencyContacts:
      return .traumaInformedConsent
    case .mfaSetup:
      return .emergencyContacts
    case .completion:
      return .mfaSetup
    }
  }

  // MARK: - Validation Methods

  func validateEmail() -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
  }

  func validatePassword() -> Bool {
    return password.count >= 8 && password == confirmPassword
  }

  func validateAge() -> Bool {
    guard let birthDate = dateOfBirth else { return false }
    let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    return age >= 4 && age <= 120  // Reasonable age range
  }

  // Note: Institution code validation not enforced. This is a product decision:
  // users may optionally enter their institution code, but registration does not require it.

  // MARK: - Consent Methods

  func grantConsent(_ consentType: ConsentType, digitalSignature: String? = nil) async {
    guard currentUser?.id != nil else { return }

    let consentRecord = ConsentRecord(
      consentType: consentType,
      version: "1.0",
      digitalSignature: digitalSignature
    )

    grantedConsents.append(consentRecord)

    // Check if all required consents are granted
    let hasAllRequiredConsents = requiredConsents.allSatisfy { requiredConsent in
      grantedConsents.contains { $0.consentType == requiredConsent && $0.isValid }
    }

    if hasAllRequiredConsents {
      consentStatus = .granted
      if case .loaded(.awaitingConsent) = state {
        await updateState(.loaded(.authenticated(currentUser!)))
      }
    }

    await logAuditEvent(.consentGranted, result: .success)
  }

  func revokeConsent(_ consentType: ConsentType) async {
    guard (currentUser?.id) != nil else { return }

    // Mark consent as revoked
    if let index = grantedConsents.firstIndex(where: { $0.consentType == consentType && $0.isValid }
    ) {
      let updatedConsent = grantedConsents[index]
      // Would update the consent record in place or create a revocation record
      grantedConsents[index] = updatedConsent
    }

    await logAuditEvent(.consentRevoked, result: .success)
  }

  // MARK: - Audit Logging

  private func logAuditEvent(_ action: AuditAction, result: AuditResult) async {
    guard let sessionID = sessionID else { return }

    let event = AuditEvent(
      userID: currentUser?.id ?? "anonymous",
      userRole: currentUser?.role ?? .student,
      action: action,
      resourceType: "user",
      resourceID: currentUser?.id,
      dataClassification: .internalData,
      deviceInfo: deviceInfo,
      sessionID: sessionID,
      result: result,
      riskLevel: action.defaultRiskLevel
    )

    await auditService.logEvent(event)
  }
}

// MARK: - Supporting Types

enum AuthField: Hashable {
  case email
  case password
  case confirmPassword
  case institutionCode
  case guardianEmail
}

// MARK: - Simple Field Support for AuthenticationView
extension AuthStateModel {
  // Support simple Field enum used in AuthenticationView
  var simpleFocusedField: Field? {
    get {
      switch focusedField {
      case .email: return .email
      case .password: return .password
      default: return nil
      }
    }
    set {
      switch newValue {
      case .email: focusedField = .email
      case .password: focusedField = .password
      case .none: focusedField = nil
      }
    }
  }
}

enum ConsentStatus {
  case pending
  case granted
  case revoked
  case expired
}

enum ParentalConsentStatus: String, Codable {
  case notRequired = "not_required"
  case required = "required"
  case pending = "pending"
  case granted = "granted"
  case denied = "denied"
}

enum PrivacyLevel {
  case minimal
  case standard
  case enhanced
  case maximum
}

enum AuthenticationMethod {
  case emailPassword
  case institutionalSSO
  case socialLogin
  case mfa
}

enum SecurityLevel {
  case basic
  case standard
  case enhanced
  case maximum
}

struct RegistrationData {
  var selectedRole: UserRole?
  var dateOfBirth: Date?
  /// Institution code is optional; users may enter it, but it is not required to complete registration.
  var institutionCode: String?
  var guardianEmail: String?
  var emergencyContacts: [EmergencyContact] = []
  var privacySettings: PrivacySettings?
  var mfaEnabled: Bool = false
}

// MARK: - UserRole Guardian Helper

extension UserRole {
  /// Returns true if the role is a parent or legal guardian.
  var isGuardian: Bool {
    self == .parent || self == .legalGuardian
  }
}

