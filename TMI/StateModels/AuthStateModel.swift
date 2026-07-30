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
nonisolated enum Field: Hashable {
  case email  
  case password
}

// MARK: - Authentication State

nonisolated enum AuthenticationState: Equatable {
  case unauthenticated
  case registering(RegistrationStep)
  case authenticating
  case verifying(VerificationType)
  case awaitingConsent(ConsentType)
  case authenticated(AuthenticatedSession)
  case error(AuthenticationError)
  case suspended(SuspensionReason)

  static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
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
    case (.authenticated(let session1), .authenticated(let session2)):
      return session1 == session2
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

nonisolated enum RegistrationStep: String, CaseIterable, Equatable {
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

nonisolated struct AuthenticationError: Error, Identifiable, Equatable {
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

nonisolated enum AuthenticationErrorType: String, CaseIterable {
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
        "It looks like the email or password isn't quite right."
    case .accountNotFound:
      return "We don't have an account with that email address yet. Would you like to create one?"
    case .accountLocked:
      return
        "Your account has been temporarily secured for your safety."
    case .accountSuspended:
      return "Your account needs some attention"
    case .emailNotVerified:
      return "We need to verify your email address to keep your account secure."
    case .ageVerificationFailed:
      return "We need to verify your age to ensure we're providing the right protections for you."
    case .institutionVerificationFailed:
      return
        "We're having trouble connecting you with your institution."
    case .missingConsent, .expiredConsent:
      return "We need to update your consent preferences to continue protecting your information."
    case .parentalConsentRequired:
      return "For your safety, we need permission from your parent or guardian to continue."
    case .parentalConsentDenied:
      return "Your parent or guardian hasn't given permission yet. They can update this anytime."
    case .mfaRequired:
      return "We need to verify it's really you with an additional security check."
    case .mfaFailed:
      return "The security code didn't match."
    case .networkError:
      return
        "We're having trouble connecting right now. Try again in a moment."
    case .serverError:
      return
        "Something went wrong on our end. We're working to fix this."
    case .unknownError:
      return "Something unexpected happened."
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

nonisolated struct SupportResource: Identifiable, Equatable {
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

nonisolated enum SupportResourceType: String, CaseIterable {
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

nonisolated enum SuspensionReason: String, CaseIterable, Equatable {
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
        "We've temporarily secured your account to protect your information."
    case .policyViolation:
      return
        "Your account needs some attention to ensure everyone feels safe."
    case .complianceIssue:
      return
        "We need to make sure we're following all the rules that keep you protected."
    case .parentalRequest:
      return
        "Your parent or guardian has requested that we pause your account."
    case .institutionalRequest:
      return
        "Your school has asked us to temporarily pause your account."
    case .dataProtectionConcern:
      return
        "We're taking extra care to protect your information."
    }
  }
}

// MARK: - Trusted Authentication Adapters

nonisolated struct AuthenticatedIdentity: Sendable, Equatable {
  let userID: String
  let isEmailVerified: Bool
}

@MainActor
final class AuthStateListenerHandle {
  private var removalOperation: (@MainActor () -> Void)?

  init(removalOperation: @MainActor @escaping () -> Void) {
    self.removalOperation = removalOperation
  }

  func remove() {
    let operation = removalOperation
    removalOperation = nil
    operation?()
  }

  isolated deinit {
    remove()
  }
}

protocol AuthenticationIdentityProviding: AnyObject {
  @MainActor
  var currentIdentity: AuthenticatedIdentity? { get }

  @MainActor
  func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim

  @MainActor
  func addStateDidChangeListener(
    _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
  ) -> AuthStateListenerHandle
}

final class FirebaseAuthenticationIdentityProvider: AuthenticationIdentityProviding {
  private let auth: Auth

  init(auth: Auth = Auth.auth()) {
    self.auth = auth
  }

  @MainActor
  var currentIdentity: AuthenticatedIdentity? {
    guard let user = auth.currentUser else {
      return nil
    }
    return AuthenticatedIdentity(
      userID: user.uid,
      isEmailVerified: user.isEmailVerified
    )
  }

  @MainActor
  func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim {
    guard let user = auth.currentUser, user.uid == identity.userID else {
      throw TrustedTenantClaimError.malformed
    }

    let result = try await user.getIDTokenResult(forcingRefresh: true)
    guard auth.currentUser?.uid == identity.userID else {
      throw CancellationError()
    }
    return try TrustedTenantClaim(
      userID: identity.userID,
      tokenClaims: result.claims
    )
  }

  @MainActor
  func addStateDidChangeListener(
    _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
  ) -> AuthStateListenerHandle {
    let handle = auth.addStateDidChangeListener { _, user in
      let identity = user.map {
        AuthenticatedIdentity(
          userID: $0.uid,
          isEmailVerified: $0.isEmailVerified
        )
      }
      Task { @MainActor in
        listener(identity)
      }
    }

    return AuthStateListenerHandle { [auth] in
      auth.removeStateDidChangeListener(handle)
    }
  }
}

protocol UserProfileProviding: Sendable {
  func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser?
}

struct FirebaseUserProfileProvider: UserProfileProviding, @unchecked Sendable {
  private let firestore: Firestore

  init(firestore: Firestore) {
    self.firestore = firestore
  }

  func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
    let reference = firestore.document(
      FirestorePaths.privateProfile(userID: identity.userID)
    )
    let snapshot = try await reference.getDocument()
    guard snapshot.exists else {
      return nil
    }

    var profile = try snapshot.decodedModel(
      as: TMIUser.self,
      assigningDocumentIDTo: \.id
    )
    guard profile.userID == identity.userID else {
      throw UserProfileLoadingError.identityMismatch
    }

    let storedVerification = snapshot.data()?["isEmailVerified"] as? Bool ?? false
    profile.isEmailVerified = identity.isEmailVerified
    profile.verificationStatus.isEmailVerified = identity.isEmailVerified

    if storedVerification != identity.isEmailVerified {
      try? await reference.updateData([
        "isEmailVerified": identity.isEmailVerified,
        "verificationStatus.isEmailVerified": identity.isEmailVerified,
      ])
    }

    return profile
  }
}

private enum UserProfileLoadingError: Error {
  case identityMismatch
}

private enum UnconfiguredAuthenticationDependencyError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "Authentication dependencies are unavailable in this runtime."
  }
}

private final class UnavailableAuthenticationIdentityProvider: AuthenticationIdentityProviding {
  @MainActor
  var currentIdentity: AuthenticatedIdentity? { nil }

  @MainActor
  func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim {
    throw UnconfiguredAuthenticationDependencyError.unavailable
  }

  @MainActor
  func addStateDidChangeListener(
    _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
  ) -> AuthStateListenerHandle {
    AuthStateListenerHandle(removalOperation: {})
  }
}

private struct UnavailableUserProfileProvider: UserProfileProviding {
  func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
    throw UnconfiguredAuthenticationDependencyError.unavailable
  }
}

private struct UnavailableAuthMembershipProvider: MembershipProviding {
  func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
    throw MembershipRepositoryError.unavailable
  }
}

// MARK: - Environment Key
extension EnvironmentValues {
  @Entry var authStateModel: AuthStateModel = AuthStateModel(automaticallyStart: false)
}

// MARK: - Auth State Model

@Observable
@MainActor
final class AuthStateModel: BaseStateModel<AuthenticationState, IdentifiableError> {

  // MARK: - Dependencies
  private let auditService: any AuditEventRecording
  private let signInOperation: @MainActor (String, String) async throws -> Void
  private let signOutOperation: @MainActor () throws -> Void
  private let resetPasswordOperation: @MainActor (String) async throws -> Void
  private let identityProvider: any AuthenticationIdentityProviding
  private let profileProvider: any UserProfileProviding
  private let membershipProvider: any MembershipProviding
  private let authorizationSessionStore: TrustedAuthorizationSessionStore
  private let featureFlags: FeatureFlags
  private let authorizationDeadline: Duration

  @ObservationIgnored
  private var authStateListenerHandle: AuthStateListenerHandle?
  @ObservationIgnored
  private var authorizationTask: Task<Void, Never>?
  @ObservationIgnored
  private var authorizationDeadlineTask: Task<Void, Never>?
  @ObservationIgnored
  private var authorizationGeneration: UInt64 = 0
  @ObservationIgnored
  private var authorizationSessionUpdateTask: Task<Void, Never>?

  // MARK: - Current User State
  private(set) var authenticatedSession: AuthenticatedSession?
  private var pendingAuthenticatedSession: AuthenticatedSession?
  private(set) var currentUser: TMIUser?
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

  /// True during the initial auth check — covers both `.idle` (before fetch runs) and `.loading`.
  /// Use this in ContentView instead of `isLoading` to prevent flashing the auth screen.
  var isCheckingAuth: Bool {
    if case .idle = state { return true }
    if case .loading = state { return true }
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
      return error.message
    }
    if case .error(let error) = state {
      return error.message
    }
    return nil
  }

  var currentAuthState: AuthenticationState? {
    if case .loaded(let authState) = state {
      return authState
    }
    return nil
  }

  var currentMembership: MembershipContext? {
    authenticatedSession?.membership
  }

  var currentClaim: TrustedTenantClaim? {
    authenticatedSession?.claim
  }

  var canRetryAuthorization: Bool {
    guard identityProvider.currentIdentity != nil,
          case .loaded(.error(let error)) = state else {
      return false
    }
    return error.type == .institutionVerificationFailed
  }

  // MARK: - Initialization
  init(
    firebaseManager: FirebaseManager? = nil,
    authentication: (any AuthenticationProviding)? = nil,
    auditService: any AuditEventRecording = NoOpAuditEventRecorder(),
    signOutOperation: (@MainActor () throws -> Void)? = nil,
    identityProvider: (any AuthenticationIdentityProviding)? = nil,
    profileProvider: (any UserProfileProviding)? = nil,
    membershipProvider: (any MembershipProviding)? = nil,
    authorizationSessionStore: TrustedAuthorizationSessionStore = TrustedAuthorizationSessionStore(),
    featureFlags: FeatureFlags = .production,
    authorizationDeadline: Duration = .seconds(10),
    automaticallyStart: Bool = true
  ) {
    let resolvedFirebaseManager = firebaseManager ?? (
      automaticallyStart ? FirebaseManager.shared : nil
    )

    self.auditService = auditService
    self.signOutOperation = signOutOperation ?? {
      guard let resolvedFirebaseManager else {
        throw UnconfiguredAuthenticationDependencyError.unavailable
      }
      try resolvedFirebaseManager.signOut()
    }
    self.signInOperation = { email, password in
      if let authentication {
        _ = try await authentication.signIn(email: email, password: password)
        return
      }
      guard let resolvedFirebaseManager else {
        throw UnconfiguredAuthenticationDependencyError.unavailable
      }
      try await resolvedFirebaseManager.signIn(withEmail: email, password: password)
    }
    self.resetPasswordOperation = { email in
      if let authentication {
        try await authentication.sendPasswordReset(email: email)
        return
      }
      guard let resolvedFirebaseManager else {
        throw UnconfiguredAuthenticationDependencyError.unavailable
      }
      try await resolvedFirebaseManager.resetPassword(email: email)
    }
    self.identityProvider = identityProvider ?? resolvedFirebaseManager.map {
      FirebaseAuthenticationIdentityProvider(auth: $0.auth)
    } ?? UnavailableAuthenticationIdentityProvider()
    self.profileProvider = profileProvider ?? resolvedFirebaseManager.map {
      FirebaseUserProfileProvider(firestore: $0.firestore)
    } ?? UnavailableUserProfileProvider()
    self.membershipProvider = membershipProvider ?? resolvedFirebaseManager.map {
      MembershipRepository(store: FirebaseMembershipStore(firestore: $0.firestore))
    } ?? UnavailableAuthMembershipProvider()
    self.authorizationSessionStore = authorizationSessionStore
    self.featureFlags = featureFlags
    self.authorizationDeadline = authorizationDeadline
    let authorizationSessionUpdates = authorizationSessionStore.sessionUpdates()
    super.init()

    authorizationSessionUpdateTask = Task { @MainActor [weak self] in
      for await session in authorizationSessionUpdates {
        guard let self, !Task.isCancelled else {
          return
        }
        self.acceptAuthorizationSessionUpdate(session)
      }
    }

    if automaticallyStart {
      Task { @MainActor [weak self] in
        await self?.fetch()
      }
    }
  }

  isolated deinit {
    authorizationTask?.cancel()
    authorizationDeadlineTask?.cancel()
    authorizationSessionUpdateTask?.cancel()
    authStateListenerHandle?.remove()
  }

  @MainActor
  override func fetch() async {
    setupInitialState()
    setupAuthListenerIfNeeded()

    if let identity = identityProvider.currentIdentity {
      let task = startAuthorization(for: identity)
      await task.value
    } else {
      transitionToUnauthenticated(logLogout: false)
    }

    await initializeDeviceInfo()
  }

  // MARK: - Setup Methods

  @MainActor
  private func setupInitialState() {
    ui.set("showingRegistration", value: false)
    ui.set("showingForgotPassword", value: false)
    ui.set("focusedField", value: nil as AuthField?)
    ui.set("currentError", value: nil as AuthenticationError?)
    sessionID = sessionID ?? UUID().uuidString
    updateState(.loading)
  }

  @MainActor
  private func setupAuthListenerIfNeeded() {
    guard authStateListenerHandle == nil else {
      return
    }

    authStateListenerHandle = identityProvider.addStateDidChangeListener { [weak self] identity in
      guard let self else {
        return
      }

      if let identity {
        self.startAuthorization(for: identity)
      } else {
        self.transitionToUnauthenticated(logLogout: true)
      }
    }
  }

  @MainActor
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

  @discardableResult
  @MainActor
  private func startAuthorization(
    for identity: AuthenticatedIdentity
  ) -> Task<Void, Never> {
    invalidateAuthorization()
    let generation = authorizationGeneration
    clearPublishedSession()
    pendingAuthenticatedSession = nil
    currentError = nil
    sessionID = sessionID ?? UUID().uuidString
    updateState(.loading)
    startAuthorizationDeadline(for: identity, generation: generation)

    let task = Task { @MainActor [weak self] in
      guard let self else {
        return
      }
      await self.authorize(identity, generation: generation)
    }
    authorizationTask = task
    return task
  }

  @MainActor
  private func authorize(
    _ identity: AuthenticatedIdentity,
    generation: UInt64
  ) async {
    guard !featureFlags.staffEmailVerificationRequired || identity.isEmailVerified else {
      guard isCurrentAuthorization(identity, generation: generation) else {
        return
      }
      updateState(.loaded(.verifying(.institutionalEmail)))
      completeAuthorization(generation: generation)
      return
    }

    do {
      guard let profile = try await profileProvider.profile(for: identity) else {
        guard isCurrentAuthorization(identity, generation: generation) else {
          return
        }
        updateState(.loaded(.registering(.basicInfo)))
        completeAuthorization(generation: generation)
        return
      }
      guard profile.userID == identity.userID,
            isCurrentAuthorization(identity, generation: generation) else {
        throw UserProfileLoadingError.identityMismatch
      }

      let claim = try await identityProvider.trustedClaim(for: identity)
      guard isCurrentAuthorization(identity, generation: generation) else {
        return
      }

      let membership = try await membershipProvider.membership(for: claim)
      guard isCurrentAuthorization(identity, generation: generation) else {
        return
      }

      let session = AuthenticatedSession(
        profile: profile,
        claim: claim,
        membership: membership
      )
      guard isValidTrustedSession(session, identity: identity) else {
        throw MembershipRepositoryError.malformed
      }

      completeAuthorization(generation: generation)

      if profile.requiresParentalConsent && !profile.hasValidConsent {
        pendingAuthenticatedSession = session
        updateState(.loaded(.awaitingConsent(.coppa)))
      } else {
        publishAuthenticatedSession(session)
        await logAuditEvent(.login, result: .success)
      }
    } catch {
      guard isCurrentAuthorization(identity, generation: generation) else {
        return
      }
      failOrganizationAccessVerification()
      completeAuthorization(generation: generation)
    }
  }

  @MainActor
  private func startAuthorizationDeadline(
    for identity: AuthenticatedIdentity,
    generation: UInt64
  ) {
    authorizationDeadlineTask?.cancel()
    authorizationDeadlineTask = Task { @MainActor [weak self] in
      guard let self else {
        return
      }

      do {
        try await Task.sleep(for: self.authorizationDeadline)
      } catch {
        return
      }

      guard self.authorizationGeneration == generation,
            self.identityProvider.currentIdentity?.userID == identity.userID else {
        return
      }

      self.authorizationGeneration &+= 1
      self.authorizationTask?.cancel()
      self.authorizationTask = nil
      self.authorizationDeadlineTask = nil
      self.failOrganizationAccessVerification()
    }
  }

  @MainActor
  private func completeAuthorization(generation: UInt64) {
    guard authorizationGeneration == generation else {
      return
    }
    authorizationDeadlineTask?.cancel()
    authorizationDeadlineTask = nil
    authorizationTask = nil
  }

  @MainActor
  private func isCurrentAuthorization(
    _ identity: AuthenticatedIdentity,
    generation: UInt64
  ) -> Bool {
    !Task.isCancelled
      && authorizationGeneration == generation
      && identityProvider.currentIdentity?.userID == identity.userID
  }

  private func isValidTrustedSession(
    _ session: AuthenticatedSession,
    identity: AuthenticatedIdentity
  ) -> Bool {
    let claim = session.claim
    let membership = session.membership

    return session.profile.userID == identity.userID
      && claim.userID == identity.userID
      && claim.accessClass == .staff
      && TrustedIdentifier.isValid(claim.userID)
      && TrustedIdentifier.isValid(claim.districtID)
      && claim.membershipVersion > 0
      && membership.userID == claim.userID
      && membership.districtID == claim.districtID
      && membership.version == claim.membershipVersion
      && membership.isActive
      && membership.schoolIDs.allSatisfy(TrustedIdentifier.isValid)
      && membership.assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid)
  }

  @MainActor
  private func publishAuthenticatedSession(_ session: AuthenticatedSession) {
    pendingAuthenticatedSession = nil
    authenticatedSession = session
    currentUser = session.profile
    authorizationSessionStore.publish(session)
    currentError = nil
    updateState(.loaded(.authenticated(session)))
  }

  @MainActor
  private func acceptAuthorizationSessionUpdate(_ session: AuthenticatedSession) {
    guard let currentSession = authenticatedSession,
          case .loaded(.authenticated(let displayedSession)) = state,
          displayedSession == currentSession,
          let identity = identityProvider.currentIdentity,
          identity.userID == currentSession.profile.userID,
          session.claim.districtID == currentSession.claim.districtID,
          session.membership.districtID == currentSession.membership.districtID,
          session.membership.version > currentSession.membership.version,
          isValidTrustedSession(session, identity: identity) else {
      return
    }

    authenticatedSession = session
    currentUser = session.profile
    currentError = nil
    updateState(.loaded(.authenticated(session)))
  }

  @MainActor
  private func failOrganizationAccessVerification() {
    clearPublishedSession()
    pendingAuthenticatedSession = nil
    let error = AuthenticationError(
      type: .institutionVerificationFailed,
      message: Self.organizationAccessErrorMessage,
      traumaInformedMessage: Self.organizationAccessErrorMessage
    )
    currentError = error
    updateState(.loaded(.error(error)))
  }

  @MainActor
  private func transitionToUnauthenticated(logLogout: Bool) {
    invalidateAuthorization()
    clearPublishedSession()
    pendingAuthenticatedSession = nil
    sessionID = nil
    currentError = nil
    updateState(.loaded(.unauthenticated))

    if logLogout {
      Task { @MainActor [weak self] in
        await self?.logAuditEvent(.logout, result: .success)
      }
    }
  }

  @MainActor
  private func clearPublishedSession() {
    authenticatedSession = nil
    currentUser = nil
    authorizationSessionStore.clear()
    institutionContext = nil
  }

  @MainActor
  private func invalidateAuthorization() {
    authorizationGeneration &+= 1
    authorizationTask?.cancel()
    authorizationTask = nil
    authorizationDeadlineTask?.cancel()
    authorizationDeadlineTask = nil
  }

  static let organizationAccessErrorMessage =
    "We couldn’t verify your organization access. Check your connection and try again."

  @MainActor
  func retryAuthorization() async {
    guard canRetryAuthorization,
          let identity = identityProvider.currentIdentity else {
      return
    }

    let task = startAuthorization(for: identity)
    await task.value
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
    institutionCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    registrationData.institutionCode = institutionCode
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
      try await signInOperation(email, password)
      // Firebase auth listener will handle the rest
      clearCredentials()
    } catch {
      let authError = AuthenticationError(
        type: .invalidCredentials,
        message: AuthenticationPresentationPolicy.signInFailureMessage
      )
      updateState(.loaded(.error(authError)))
      await logAuditEvent(.loginFailed, result: .failure)
    }
  }

  @MainActor
  func signOut() -> Bool {
    let previousState = state

    do {
      try signOutOperation()
      invalidateAuthorization()
      clearPublishedSession()
      pendingAuthenticatedSession = nil
      sessionID = nil
      currentError = nil
      updateState(.loaded(.unauthenticated))
      return true
    } catch {
      let authError = AuthenticationError(
        type: .serverError,
        message: "Failed to sign out: \(error.localizedDescription)"
      )
      currentError = authError
      updateState(previousState)
      return false
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
      try await resetPasswordOperation(email)
      ui.alertMessage = AuthenticationPresentationPolicy.passwordResetConfirmation
      ui.isShowingAlert = true
      updateState(.loaded(.unauthenticated))

      await logAuditEvent(.loginFailed, result: .success)
    } catch {
      let authError = AuthenticationError(
        type: .serverError,
        message: "We couldn't request a password reset. Check your connection and try again."
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
      // Registration UI handles institution-code validation for institutional roles.
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

  // MARK: - Consent Methods

  @MainActor
  func grantConsent(_ consentType: ConsentType, digitalSignature: String? = nil) async {
    guard let session = authenticatedSession ?? pendingAuthenticatedSession else {
      return
    }

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
        guard identityProvider.currentIdentity?.userID == session.claim.userID,
              isValidTrustedSession(
                session,
                identity: AuthenticatedIdentity(
                  userID: session.claim.userID,
                  isEmailVerified: session.profile.isEmailVerified
                )
              ) else {
          failOrganizationAccessVerification()
          return
        }
        publishAuthenticatedSession(session)
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
      userRole: currentMembership?.role,
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

nonisolated enum AuthField: Hashable {
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

nonisolated enum ConsentStatus {
  case pending
  case granted
  case revoked
  case expired
}

nonisolated enum ParentalConsentStatus: String, Codable {
  case notRequired = "not_required"
  case required = "required"
  case pending = "pending"
  case granted = "granted"
  case denied = "denied"
}

nonisolated enum PrivacyLevel {
  case minimal
  case standard
  case enhanced
  case maximum
}

nonisolated enum AuthenticationMethod {
  case emailPassword
  case institutionalSSO
  case socialLogin
  case mfa
}

nonisolated struct RegistrationData {
  var selectedRole: UserRole?
  var dateOfBirth: Date?
  /// Institution code is required for roles with institutional affiliation.
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
