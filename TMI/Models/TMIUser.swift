//
//  TMIUser.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore
import Foundation

// MARK: - TMI User Model

struct TMIUser: Codable, Identifiable, Equatable, @unchecked Sendable {
  @DocumentID var id: String?
  let userID: String
  var displayName: String
  var email: String
  var isEmailVerified: Bool
  /// Non-authoritative account type requested during registration.
  /// Trusted role and tenant scope live only in `MembershipContext`.
  var requestedRole: UserRole?
  var dateOfBirth: Date?
  var institutionCode: String?
  var institutionName: String?
  var photoURL: String?
  var organization: String?

  // Verification and compliance
  var verificationStatus: VerificationStatus
  var consentRecords: [ConsentRecord]
  var parentalConsentStatus: ParentalConsentStatus
  var ageVerificationStatus: AgeVerificationStatus
  
  // Personal privacy preferences
  var privacySettings: PrivacySettings
  
  // Profile metadata
  let createdAt: Date
  var lastLoginAt: Date?
  var lastActivityAt: Date?
  var emergencyContacts: [EmergencyContact]
  
  var formTemplates: [String] = []
  
  init(
    id: String? = nil,
    userID: String,
    displayName: String,
    email: String,
    isEmailVerified: Bool = false,
    requestedRole: UserRole? = nil,
    dateOfBirth: Date? = nil,
    institutionCode: String? = nil,
    institutionName: String? = nil,
    photoURL: String? = nil,
    organization: String? = nil,
    verificationStatus: VerificationStatus = VerificationStatus(),
    consentRecords: [ConsentRecord] = [],
    parentalConsentStatus: ParentalConsentStatus = .notRequired,
    ageVerificationStatus: AgeVerificationStatus = .notRequired,
    privacySettings: PrivacySettings = PrivacySettings(),
    createdAt: Date = Date(),
    lastLoginAt: Date? = nil,
    lastActivityAt: Date? = nil,
    emergencyContacts: [EmergencyContact] = [],
    formTemplates: [String] = []
  ) {
    self.id = id
    self.userID = userID
    self.displayName = displayName
    self.email = email
    self.isEmailVerified = isEmailVerified
    self.requestedRole = requestedRole
    self.dateOfBirth = dateOfBirth
    self.institutionCode = institutionCode
    self.institutionName = institutionName
    self.photoURL = photoURL
    self.organization = organization
    self.verificationStatus = verificationStatus
    self.consentRecords = consentRecords
    self.parentalConsentStatus = parentalConsentStatus
    self.ageVerificationStatus = ageVerificationStatus
    self.privacySettings = privacySettings
    self.createdAt = createdAt
    self.lastLoginAt = lastLoginAt
    self.lastActivityAt = lastActivityAt
    self.emergencyContacts = emergencyContacts
    self.formTemplates = formTemplates
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userID
    case uid // Legacy field name support
    case displayName
    case email
    case isEmailVerified
    case requestedRole
    case dateOfBirth
    case institutionCode
    case institutionName
    case photoURL
    case organization
    case verificationStatus
    case consentRecords
    case parentalConsentStatus
    case ageVerificationStatus
    case privacySettings
    case createdAt
    case lastLoginAt
    case lastActivityAt
    case emergencyContacts
    case formTemplates
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    
    // Try both userID and uid fields for backward compatibility
    if let userIDValue = try container.decodeIfPresent(String.self, forKey: .userID) {
      userID = userIDValue
    } else if let uidValue = try container.decodeIfPresent(String.self, forKey: .uid) {
      userID = uidValue
    } else {
      throw DecodingError.keyNotFound(
        CodingKeys.userID,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Missing both 'userID' and 'uid' fields"
        )
      )
    }
    // Basic fields with reasonable defaults
    displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "User"
    email = try container.decode(String.self, forKey: .email)
    isEmailVerified = try container.decodeIfPresent(Bool.self, forKey: .isEmailVerified) ?? false
    requestedRole = try container.decodeIfPresent(UserRole.self, forKey: .requestedRole)
    dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
    institutionCode = try container.decodeIfPresent(String.self, forKey: .institutionCode)
    institutionName = try container.decodeIfPresent(String.self, forKey: .institutionName)
    photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
    organization = try container.decodeIfPresent(String.self, forKey: .organization)
    
    // Complex fields with defaults
    verificationStatus = try container.decodeIfPresent(VerificationStatus.self, forKey: .verificationStatus) ?? VerificationStatus()
    consentRecords = try container.decodeIfPresent([ConsentRecord].self, forKey: .consentRecords) ?? []
    parentalConsentStatus = try container.decodeIfPresent(ParentalConsentStatus.self, forKey: .parentalConsentStatus) ?? .notRequired
    ageVerificationStatus = try container.decodeIfPresent(AgeVerificationStatus.self, forKey: .ageVerificationStatus) ?? .notRequired
    privacySettings = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacySettings) ?? PrivacySettings()
    
    // Date fields with defaults
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    lastLoginAt = try container.decodeIfPresent(Date.self, forKey: .lastLoginAt)
    lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
    emergencyContacts = try container.decodeIfPresent([EmergencyContact].self, forKey: .emergencyContacts) ?? []
    formTemplates = try container.decodeIfPresent([String].self, forKey: .formTemplates) ?? []
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encode(userID, forKey: .userID)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(email, forKey: .email)
    try container.encode(isEmailVerified, forKey: .isEmailVerified)
    try container.encodeIfPresent(requestedRole, forKey: .requestedRole)
    try container.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
    try container.encodeIfPresent(institutionCode, forKey: .institutionCode)
    try container.encodeIfPresent(institutionName, forKey: .institutionName)
    try container.encodeIfPresent(photoURL, forKey: .photoURL)
    try container.encodeIfPresent(organization, forKey: .organization)
    try container.encode(verificationStatus, forKey: .verificationStatus)
    try container.encode(consentRecords, forKey: .consentRecords)
    try container.encode(parentalConsentStatus, forKey: .parentalConsentStatus)
    try container.encode(ageVerificationStatus, forKey: .ageVerificationStatus)
    try container.encode(privacySettings, forKey: .privacySettings)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(lastLoginAt, forKey: .lastLoginAt)
    try container.encodeIfPresent(lastActivityAt, forKey: .lastActivityAt)
    try container.encode(emergencyContacts, forKey: .emergencyContacts)
    try container.encode(formTemplates, forKey: .formTemplates)
  }
  
  // MARK: - Convenience Properties for SimpleAuthStateModel
  
  var profileCreatedDate: Date { createdAt }
  var lastLoginDate: Date? { lastLoginAt }
  
  // Simplified initializer for basic user creation
  init(id: String, email: String, displayName: String, requestedRole: UserRole? = nil, profileCreatedDate: Date, lastLoginDate: Date? = nil) {
    self.init(
      id: id,
      userID: id,
      displayName: displayName,
      email: email,
      requestedRole: requestedRole,
      createdAt: profileCreatedDate,
      lastLoginAt: lastLoginDate
    )
  }
  
  // MARK: - Validation

  /// Validates the TMI user data and throws validation errors if any issues are found
  func validate() throws {
    // Validate display name
    guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw TMIUserValidationError.invalidDisplayName("Display name cannot be empty")
    }

    guard displayName.count <= 100 else {
      throw TMIUserValidationError.invalidDisplayName("Display name cannot exceed 100 characters")
    }

    // Validate email format
    guard isValidEmail(email) else {
      throw TMIUserValidationError.invalidEmail("Please enter a valid email address")
    }

    // Validate age if date of birth is provided
    if let dateOfBirth = dateOfBirth {
      guard dateOfBirth <= Date() else {
        throw TMIUserValidationError.invalidDateOfBirth("Date of birth cannot be in the future")
      }

      let currentAge = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
      guard currentAge >= 13 && currentAge <= 120 else {
        throw TMIUserValidationError.invalidAge("User age must be between 13 and 120")
      }
    }

    // Validate institution information for a requested account type. This is
    // registration validation only and never grants application access.
    if let requestedRole, requestedRole.requiresInstitutionalAffiliation {
      guard let institutionName = institutionName, !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw TMIUserValidationError.missingInstitutionalAffiliation("Institution name is required for \(requestedRole.displayName) registration")
      }
    }

    // Validate emergency contacts
    if emergencyContacts.count > 5 {
      throw TMIUserValidationError.tooManyEmergencyContacts("Cannot have more than 5 emergency contacts")
    }

    // Validate consent for minors
    if isMinor && !hasValidConsent {
      throw TMIUserValidationError.missingParentalConsent("Parental consent is required for users under 18")
    }
  }

  /// Quick validation for UI feedback (non-throwing)
  var isValid: Bool {
    do {
      try validate()
      return true
    } catch {
      return false
    }
  }

  /// Get validation errors as an array for UI display
  var validationErrors: [TMIUserValidationError] {
    var errors: [TMIUserValidationError] = []

    do {
      try validate()
    } catch let error as TMIUserValidationError {
      errors.append(error)
    } catch {
      errors.append(.unknown(error.localizedDescription))
    }

    return errors
  }

  /// Helper method to validate email format
  private func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
  }

  // MARK: - Equatable

  static func == (lhs: TMIUser, rhs: TMIUser) -> Bool {
    return lhs.id == rhs.id && lhs.userID == rhs.userID
  }
}

// MARK: - User Role

enum UserRole: String, CaseIterable, Codable, Identifiable, Sendable {
  case student = "student"
  case teacher = "teacher"
  case counselor = "counselor"
  case administrator = "administrator"
  case admin = "admin" // Legacy compatibility
  case socialWorker = "social_worker"
  case parent = "parent"
  case legalGuardian = "legal_guardian"
  case superintendent = "superintendent"
  case districtAdmin = "district_admin"
  
  var id: String { rawValue }
  
  var displayName: String {
    switch self {
    case .student: return "Student"
    case .teacher: return "Teacher"
    case .counselor: return "Counselor"
    case .administrator, .admin: return "Administrator"
    case .socialWorker: return "Social Worker"
    case .parent: return "Parent"
    case .legalGuardian: return "Legal Guardian"
    case .superintendent: return "Superintendent"
    case .districtAdmin: return "District Administrator"
    }
  }
  
  var requiresInstitutionalAffiliation: Bool {
    switch self {
    case .teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin:
      return true
    case .student, .parent, .legalGuardian:
      return false
    }
  }
  
  var requiredVerification: VerificationType {
    switch self {
    case .student:
      return .ageVerification
    case .teacher, .counselor, .administrator, .admin, .superintendent, .districtAdmin:
      return .institutionalEmail
    case .socialWorker:
      return .professionalCredentials
    case .parent, .legalGuardian:
      return .guardianConsent
    }
  }
  
}

// MARK: - Verification Types and Status

enum VerificationType: String, CaseIterable, Codable, Sendable {
  case none = "none"
  case ageVerification = "age_verification"
  case institutionalEmail = "institutional_email"
  case professionalCredentials = "professional_credentials"
  case guardianConsent = "guardian_consent"
}

struct VerificationStatus: Codable, Sendable {
  var isEmailVerified: Bool = false
  var isAgeVerified: Bool = false
  var isInstitutionVerified: Bool = false
  var isCredentialsVerified: Bool = false
  var isGuardianConsentVerified: Bool = false
  
  var isValid: Bool {
    return isEmailVerified // Minimum requirement for all users
  }
  
}

enum AgeVerificationStatus: String, Codable, Sendable {
  case notRequired = "not_required"
  case required = "required"
  case verified = "verified"
  case failed = "failed"
}

// MARK: - Consent Management

struct ConsentRecord: Codable, Identifiable, Sendable {
  let id: String
  let consentType: ConsentType
  let grantedAt: Date
  var expiresAt: Date?
  let version: String
  let digitalSignature: String?
  let ipAddress: String?
  let userAgent: String?
  
  var isValid: Bool {
    guard let expiresAt = expiresAt else { return true }
    return Date() < expiresAt
  }
  
  init(
    id: String = UUID().uuidString,
    consentType: ConsentType,
    grantedAt: Date = Date(),
    expiresAt: Date? = nil,
    version: String,
    digitalSignature: String? = nil,
    ipAddress: String? = nil,
    userAgent: String? = nil
  ) {
    self.id = id
    self.consentType = consentType
    self.grantedAt = grantedAt
    self.expiresAt = expiresAt
    self.version = version
    self.digitalSignature = digitalSignature
    self.ipAddress = ipAddress
    self.userAgent = userAgent
  }
}

enum ConsentType: String, CaseIterable, Codable, Sendable {
  case coppa = "coppa"
  case ferpa = "ferpa"
  case dataCollection = "data_collection"
  case dataProcessing = "data_processing"
  case traumaInformedSupport = "trauma_informed_support"
  case emergencyContact = "emergency_contact"
  case parentalConsent = "parental_consent"
  
  var displayName: String {
    switch self {
    case .coppa: return "COPPA Consent"
    case .ferpa: return "FERPA Consent"
    case .dataCollection: return "Data Collection Consent"
    case .dataProcessing: return "Data Processing Consent"
    case .traumaInformedSupport: return "Trauma-Informed Support Consent"
    case .emergencyContact: return "Emergency Contact Consent"
    case .parentalConsent: return "Parental Consent"
    }
  }
  
  var isRequired: Bool {
    switch self {
    case .coppa, .ferpa, .dataCollection:
      return true
    case .dataProcessing, .traumaInformedSupport, .emergencyContact, .parentalConsent:
      return false
    }
  }
}

// MARK: - Privacy Settings

struct PrivacySettings: Codable, Sendable {
  var dataRetentionPreference: DataRetentionPeriod
  var parentalControls: ParentalControls?
  var sensitiveDataAccess: SensitiveDataAccess
  var emergencyContactPermissions: EmergencyContactPermissions
  var communicationPreferences: CommunicationPreferences
  
  init(
    dataRetentionPreference: DataRetentionPeriod = .standard,
    parentalControls: ParentalControls? = nil,
    sensitiveDataAccess: SensitiveDataAccess = .restricted,
    emergencyContactPermissions: EmergencyContactPermissions = EmergencyContactPermissions(),
    communicationPreferences: CommunicationPreferences = CommunicationPreferences()
  ) {
    self.dataRetentionPreference = dataRetentionPreference
    self.parentalControls = parentalControls
    self.sensitiveDataAccess = sensitiveDataAccess
    self.emergencyContactPermissions = emergencyContactPermissions
    self.communicationPreferences = communicationPreferences
  }
}

enum DataRetentionPeriod: String, CaseIterable, Codable, Sendable {
  case minimal = "minimal" // 1 year
  case standard = "standard" // 3 years
  case extended = "extended" // 7 years
  case maximum = "maximum" // 25 years
  
  var displayName: String {
    switch self {
    case .minimal: return "Minimal (1 year)"
    case .standard: return "Standard (3 years)"
    case .extended: return "Extended (7 years)"
    case .maximum: return "Maximum (25 years)"
    }
  }
  
  var timeInterval: TimeInterval {
    switch self {
    case .minimal: return 365 * 24 * 60 * 60
    case .standard: return 3 * 365 * 24 * 60 * 60
    case .extended: return 7 * 365 * 24 * 60 * 60
    case .maximum: return 25 * 365 * 24 * 60 * 60
    }
  }
}

struct ParentalControls: Codable, Sendable {
  var allowDataSharing: Bool
  var requireConsentForNewFeatures: Bool
  var restrictSensitiveDataAccess: Bool
  var emergencyContactOverride: Bool
  
  init(
    allowDataSharing: Bool = false,
    requireConsentForNewFeatures: Bool = true,
    restrictSensitiveDataAccess: Bool = true,
    emergencyContactOverride: Bool = true
  ) {
    self.allowDataSharing = allowDataSharing
    self.requireConsentForNewFeatures = requireConsentForNewFeatures
    self.restrictSensitiveDataAccess = restrictSensitiveDataAccess
    self.emergencyContactOverride = emergencyContactOverride
  }
}

enum SensitiveDataAccess: String, CaseIterable, Codable, Sendable {
  case restricted = "restricted"
  case controlled = "controlled"
  case standard = "standard"
  
  var displayName: String {
    switch self {
    case .restricted: return "Restricted"
    case .controlled: return "Controlled"
    case .standard: return "Standard"
    }
  }
}

struct EmergencyContactPermissions: Codable, Sendable {
  var allowCrisisIntervention: Bool
  var allowDataSharing: Bool
  var allowNotifications: Bool
  
  init(
    allowCrisisIntervention: Bool = true,
    allowDataSharing: Bool = false,
    allowNotifications: Bool = true
  ) {
    self.allowCrisisIntervention = allowCrisisIntervention
    self.allowDataSharing = allowDataSharing
    self.allowNotifications = allowNotifications
  }
}

struct CommunicationPreferences: Codable, Sendable {
  var allowEmailNotifications: Bool
  var allowPushNotifications: Bool
  var allowSMSNotifications: Bool
  var emergencyContactOverride: Bool
  
  init(
    allowEmailNotifications: Bool = true,
    allowPushNotifications: Bool = true,
    allowSMSNotifications: Bool = false,
    emergencyContactOverride: Bool = true
  ) {
    self.allowEmailNotifications = allowEmailNotifications
    self.allowPushNotifications = allowPushNotifications
    self.allowSMSNotifications = allowSMSNotifications
    self.emergencyContactOverride = emergencyContactOverride
  }
}

// MARK: - Emergency Contact

struct EmergencyContact: Codable, Identifiable, Sendable {
  let id: String
  var name: String
  var relationship: String
  var phone: String
  var email: String?
  var isPrimary: Bool
  var canAuthorizeEmergencyActions: Bool
  
  init(
    id: String = UUID().uuidString,
    name: String,
    relationship: String,
    phone: String,
    email: String? = nil,
    isPrimary: Bool = false,
    canAuthorizeEmergencyActions: Bool = false
  ) {
    self.id = id
    self.name = name
    self.relationship = relationship
    self.phone = phone
    self.email = email
    self.isPrimary = isPrimary
    self.canAuthorizeEmergencyActions = canAuthorizeEmergencyActions
  }
}

// MARK: - TMIUser Extensions

extension TMIUser {
  var age: Int? {
    guard let dateOfBirth = dateOfBirth else { return nil }
    return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
  }
  
  var isMinor: Bool {
    guard let age = age else { return false }
    return age < 18
  }
  
  var requiresParentalConsent: Bool {
    guard let age = age else { return false }
    return age < 13 // COPPA requirement
  }
  
  var hasValidConsent: Bool {
    let requiredConsents: [ConsentType] = requiresParentalConsent ?
      [.coppa, .dataCollection] : [.dataCollection]
    
    return requiredConsents.allSatisfy { consentType in
      consentRecords.contains { $0.consentType == consentType && $0.isValid }
    }
  }
  
  mutating func grantConsent(_ consentType: ConsentType, version: String, digitalSignature: String? = nil, ipAddress: String? = nil) {
    let newConsent = ConsentRecord(
      consentType: consentType,
      version: version,
      digitalSignature: digitalSignature,
      ipAddress: ipAddress
    )
    
    // Remove any existing consent of the same type
    consentRecords.removeAll { $0.consentType == consentType }
    consentRecords.append(newConsent)
  }
  
  mutating func revokeConsent(_ consentType: ConsentType) {
    consentRecords.removeAll { $0.consentType == consentType }
  }
}

// MARK: - Legacy Compatibility

struct UserProfileData: Codable, Sendable {
  var displayName: String
  var email: String = ""
  var isEmailVerified: Bool = false
  var newEmail: String = ""
  var currentPassword: String = ""
  var photoURL: String?
  var organization: String?

  init(
    displayName: String,
    email: String = "",
    isEmailVerified: Bool = false,
    newEmail: String = "",
    currentPassword: String = "",
    photoURL: String? = nil,
    organization: String? = nil
  ) {
    self.displayName = displayName
    self.email = email
    self.isEmailVerified = isEmailVerified
    self.newEmail = newEmail
    self.currentPassword = currentPassword
    self.photoURL = photoURL
    self.organization = organization
  }
}

// MARK: - TMI User Validation Errors

enum TMIUserValidationError: LocalizedError, Equatable {
  case invalidDisplayName(String)
  case invalidEmail(String)
  case invalidAge(String)
  case invalidDateOfBirth(String)
  case missingInstitutionalAffiliation(String)
  case tooManyEmergencyContacts(String)
  case missingParentalConsent(String)
  case unknown(String)

  var errorDescription: String? {
    switch self {
    case .invalidDisplayName(let message),
         .invalidEmail(let message),
         .invalidAge(let message),
         .invalidDateOfBirth(let message),
         .missingInstitutionalAffiliation(let message),
         .tooManyEmergencyContacts(let message),
         .missingParentalConsent(let message),
         .unknown(let message):
      return message
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .invalidDisplayName:
      return "Please enter a valid display name (1-100 characters)."
    case .invalidEmail:
      return "Please enter a valid email address (e.g., user@example.com)."
    case .invalidAge:
      return "Please enter a valid date of birth for someone aged 13-120."
    case .invalidDateOfBirth:
      return "Please select a date of birth that is not in the future."
    case .missingInstitutionalAffiliation:
      return "Please provide your institution name for verification."
    case .tooManyEmergencyContacts:
      return "Please limit emergency contacts to 5 or fewer."
    case .missingParentalConsent:
      return "Parental consent is required for users under 18. Please have a parent or guardian complete the consent process."
    case .unknown:
      return "Please check your input and try again."
    }
  }
}
