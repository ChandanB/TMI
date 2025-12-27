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
  let role: UserRole
  var dateOfBirth: Date?
  var institutionID: String?
  var institutionName: String?
  var districtId: String?
  var schoolId: String?
  
  // Verification and compliance
  var verificationStatus: VerificationStatus
  var consentRecords: [ConsentRecord]
  var parentalConsentStatus: ParentalConsentStatus
  var ageVerificationStatus: AgeVerificationStatus
  
  // Privacy and permissions
  var privacySettings: PrivacySettings
  var permissions: Set<Permission>
  var dataClassificationAccess: Set<DataClassification>
  
  // Profile metadata
  let createdAt: Date
  var lastLoginAt: Date?
  var lastActivityAt: Date?
  var isActive: Bool
  var emergencyContacts: [EmergencyContact]
  
  var formTemplates: [String] = []
  
  // Legacy compatibility
  var legacyRole: String {
    return role.rawValue
  }
  
  init(
    id: String? = nil,
    userID: String,
    displayName: String,
    email: String,
    isEmailVerified: Bool = false,
    role: UserRole,
    dateOfBirth: Date? = nil,
    institutionID: String? = nil,
    institutionName: String? = nil,
    districtId: String? = nil,
    schoolId: String? = nil,
    verificationStatus: VerificationStatus = VerificationStatus(),
    consentRecords: [ConsentRecord] = [],
    parentalConsentStatus: ParentalConsentStatus = .notRequired,
    ageVerificationStatus: AgeVerificationStatus = .notRequired,
    privacySettings: PrivacySettings = PrivacySettings(),
    permissions: Set<Permission>? = nil,
    dataClassificationAccess: Set<DataClassification>? = nil,
    createdAt: Date = Date(),
    lastLoginAt: Date? = nil,
    lastActivityAt: Date? = nil,
    isActive: Bool = true,
    emergencyContacts: [EmergencyContact] = [],
    formTemplates: [String] = []
  ) {
    self.id = id
    self.userID = userID
    self.displayName = displayName
    self.email = email
    self.isEmailVerified = isEmailVerified
    self.role = role
    self.dateOfBirth = dateOfBirth
    self.institutionID = institutionID
    self.institutionName = institutionName
    self.districtId = districtId
    self.schoolId = schoolId
    self.verificationStatus = verificationStatus
    self.consentRecords = consentRecords
    self.parentalConsentStatus = parentalConsentStatus
    self.ageVerificationStatus = ageVerificationStatus
    self.privacySettings = privacySettings
    self.permissions = permissions ?? role.defaultPermissions
    self.dataClassificationAccess = dataClassificationAccess ?? role.defaultDataAccess
    self.createdAt = createdAt
    self.lastLoginAt = lastLoginAt
    self.lastActivityAt = lastActivityAt
    self.isActive = isActive
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
    case role
    case dateOfBirth
    case institutionID
    case institutionName
    case districtId
    case schoolId
    case verificationStatus
    case consentRecords
    case parentalConsentStatus
    case ageVerificationStatus
    case privacySettings
    case permissions
    case dataClassificationAccess
    case createdAt
    case lastLoginAt
    case lastActivityAt
    case isActive
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
    // Extract role first to use for defaults
    role = try container.decode(UserRole.self, forKey: .role)
    
    // Basic fields with reasonable defaults
    displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "User"
    email = try container.decode(String.self, forKey: .email)
    isEmailVerified = try container.decodeIfPresent(Bool.self, forKey: .isEmailVerified) ?? false
    dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
    institutionID = try container.decodeIfPresent(String.self, forKey: .institutionID)
    institutionName = try container.decodeIfPresent(String.self, forKey: .institutionName)
    districtId = try container.decodeIfPresent(String.self, forKey: .districtId)
    schoolId = try container.decodeIfPresent(String.self, forKey: .schoolId)
    
    // Complex fields with defaults
    verificationStatus = try container.decodeIfPresent(VerificationStatus.self, forKey: .verificationStatus) ?? VerificationStatus()
    consentRecords = try container.decodeIfPresent([ConsentRecord].self, forKey: .consentRecords) ?? []
    parentalConsentStatus = try container.decodeIfPresent(ParentalConsentStatus.self, forKey: .parentalConsentStatus) ?? .notRequired
    ageVerificationStatus = try container.decodeIfPresent(AgeVerificationStatus.self, forKey: .ageVerificationStatus) ?? .notRequired
    privacySettings = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacySettings) ?? PrivacySettings()
    permissions = try container.decodeIfPresent(Set<Permission>.self, forKey: .permissions) ?? role.defaultPermissions
    dataClassificationAccess = try container.decodeIfPresent(Set<DataClassification>.self, forKey: .dataClassificationAccess) ?? role.defaultDataAccess
    
    // Date fields with defaults
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    lastLoginAt = try container.decodeIfPresent(Date.self, forKey: .lastLoginAt)
    lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
    isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
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
    try container.encode(role, forKey: .role)
    try container.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
    try container.encodeIfPresent(institutionID, forKey: .institutionID)
    try container.encodeIfPresent(institutionName, forKey: .institutionName)
    try container.encodeIfPresent(districtId, forKey: .districtId)
    try container.encodeIfPresent(schoolId, forKey: .schoolId)
    try container.encode(verificationStatus, forKey: .verificationStatus)
    try container.encode(consentRecords, forKey: .consentRecords)
    try container.encode(parentalConsentStatus, forKey: .parentalConsentStatus)
    try container.encode(ageVerificationStatus, forKey: .ageVerificationStatus)
    try container.encode(privacySettings, forKey: .privacySettings)
    try container.encode(permissions, forKey: .permissions)
    try container.encode(dataClassificationAccess, forKey: .dataClassificationAccess)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(lastLoginAt, forKey: .lastLoginAt)
    try container.encodeIfPresent(lastActivityAt, forKey: .lastActivityAt)
    try container.encode(isActive, forKey: .isActive)
    try container.encode(emergencyContacts, forKey: .emergencyContacts)
    try container.encode(formTemplates, forKey: .formTemplates)
  }
  
  // MARK: - Convenience Properties for SimpleAuthStateModel
  
  var profileCreatedDate: Date { createdAt }
  var lastLoginDate: Date? { lastLoginAt }
  
  // Simplified initializer for basic user creation
  init(id: String, email: String, displayName: String, role: UserRole, profileCreatedDate: Date, lastLoginDate: Date? = nil) {
    self.init(
      id: id,
      userID: id,
      displayName: displayName,
      email: email,
      role: role,
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

    // Validate institution information for roles that require it
    if role.requiresInstitutionalAffiliation {
      guard let institutionName = institutionName, !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw TMIUserValidationError.missingInstitutionalAffiliation("Institution name is required for \(role.displayName) role")
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
  
  var defaultPermissions: Set<Permission> {
    switch self {
    case .student:
      return Set([.viewOwnData, .participateInSurveys, .accessSupportResources])
    case .teacher:
      return Set([.viewOwnData, .viewStudentData, .createAssessments, .viewReports, .accessSupportResources])
    case .counselor:
      return Set([.viewOwnData, .viewStudentData, .viewSensitiveData, .createInterventions, .accessCrisisResources, .accessSupportResources])
    case .administrator, .admin, .superintendent, .districtAdmin:
      return Set(Permission.allCases.filter { !$0.isRestrictedPermission })
    case .socialWorker:
      return Set([.viewOwnData, .viewStudentData, .viewSensitiveData, .viewFamilyData, .createInterventions, .accessCrisisResources, .accessSupportResources])
    case .parent, .legalGuardian:
      return Set([.viewOwnData, .viewChildData, .receiveNotifications, .accessSupportResources])
    }
  }
  
  var defaultDataAccess: Set<DataClassification> {
    switch self {
    case .student:
      return Set([.publicData, .internalData, .personal])
    case .teacher:
      return Set([.publicData, .internalData, .personal, .educational])
    case .counselor:
      return Set([.publicData, .internalData, .personal, .educational, .sensitive])
    case .administrator, .admin, .superintendent, .districtAdmin:
      return Set(DataClassification.allCases)
    case .socialWorker:
      return Set([.publicData, .internalData, .personal, .educational, .sensitive, .traumaRelated])
    case .parent, .legalGuardian:
      return Set([.publicData, .internalData, .personal])
    }
  }
}

// MARK: - Permission System

enum Permission: String, CaseIterable, Codable, Identifiable, Sendable {
  // Basic permissions
  case viewOwnData = "view_own_data"
  case editOwnProfile = "edit_own_profile"
  case deleteOwnAccount = "delete_own_account"
  
  // Student data permissions
  case viewStudentData = "view_student_data"
  case editStudentData = "edit_student_data"
  case viewChildData = "view_child_data"
  
  // Sensitive data permissions
  case viewSensitiveData = "view_sensitive_data"
  case viewFamilyData = "view_family_data"
  case viewTraumaData = "view_trauma_data"
  
  // Educational permissions
  case participateInSurveys = "participate_in_surveys"
  case createAssessments = "create_assessments"
  case viewReports = "view_reports"
  case createInterventions = "create_interventions"
  
  // Administrative permissions
  case manageUsers = "manage_users"
  case manageInstitution = "manage_institution"
  case viewAuditLogs = "view_audit_logs"
  case manageSystemSettings = "manage_system_settings"
  
  // Support and crisis permissions
  case accessSupportResources = "access_support_resources"
  case accessCrisisResources = "access_crisis_resources"
  case receiveNotifications = "receive_notifications"
  
  // Data management permissions
  case exportData = "export_data"
  case deleteUserData = "delete_user_data"
  
  var id: String { rawValue }
  
  var displayName: String {
    switch self {
    case .viewOwnData: return "View Own Data"
    case .editOwnProfile: return "Edit Own Profile"
    case .deleteOwnAccount: return "Delete Own Account"
    case .viewStudentData: return "View Student Data"
    case .editStudentData: return "Edit Student Data"
    case .viewChildData: return "View Child Data"
    case .viewSensitiveData: return "View Sensitive Data"
    case .viewFamilyData: return "View Family Data"
    case .viewTraumaData: return "View Trauma Data"
    case .participateInSurveys: return "Participate in Surveys"
    case .createAssessments: return "Create Assessments"
    case .viewReports: return "View Reports"
    case .createInterventions: return "Create Interventions"
    case .manageUsers: return "Manage Users"
    case .manageInstitution: return "Manage Institution"
    case .viewAuditLogs: return "View Audit Logs"
    case .manageSystemSettings: return "Manage System Settings"
    case .accessSupportResources: return "Access Support Resources"
    case .accessCrisisResources: return "Access Crisis Resources"
    case .receiveNotifications: return "Receive Notifications"
    case .exportData: return "Export Data"
    case .deleteUserData: return "Delete User Data"
    }
  }
  
  var isRestrictedPermission: Bool {
    switch self {
    case .viewTraumaData, .deleteUserData, .manageSystemSettings:
      return true
    default:
      return false
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
  
  func isValidForRole(_ role: UserRole) -> Bool {
    // Email verification is always required
    guard isEmailVerified else { return false }
    // Role-specific verification requirements
    switch role {
    case .student:
      return true // Email verification is sufficient for students
    case .teacher, .counselor, .administrator, .admin, .superintendent, .districtAdmin:
      return isInstitutionVerified || isEmailVerified // Institution or email verification
    case .socialWorker:
      return isCredentialsVerified || isEmailVerified // Credentials or email verification
    case .parent, .legalGuardian:
      return isGuardianConsentVerified || isEmailVerified // Guardian consent or email verification
    }
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
  
  func hasPermission(_ permission: Permission) -> Bool {
    return permissions.contains(permission)
  }
  
  func canAccess(_ dataClassification: DataClassification) -> Bool {
    return dataClassificationAccess.contains(dataClassification)
  }
  
  // MARK: - Feature Access Methods
  
  /// Check if user can access advanced features requiring full verification
  func canAccessAdvancedFeatures() -> Bool {
    return verificationStatus.isValidForRole(role)
  }
  
  /// Check if user can access sensitive data features
  func canAccessSensitiveData() -> Bool {
    switch role {
    case .student, .parent, .legalGuardian:
      return verificationStatus.isEmailVerified
    case .teacher, .counselor, .administrator, .admin, .superintendent, .districtAdmin:
      return verificationStatus.isEmailVerified && verificationStatus.isInstitutionVerified
    case .socialWorker:
      return verificationStatus.isEmailVerified && verificationStatus.isCredentialsVerified
    }
  }
  
  /// Check if user can create or manage other users' data
  func canManageUserData() -> Bool {
    guard verificationStatus.isEmailVerified else { return false }
    
    switch role {
    case .student, .parent, .legalGuardian:
      return false // Can only manage their own data
    case .teacher, .counselor, .administrator, .admin, .superintendent, .districtAdmin, .socialWorker:
      return canAccessAdvancedFeatures()
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
  var role: String = "student"
  var newEmail: String = ""
  var currentPassword: String = ""

  init(
    displayName: String,
    email: String = "",
    isEmailVerified: Bool = false,
    role: String = "student",
    newEmail: String = "",
    currentPassword: String = ""
  ) {
    self.displayName = displayName
    self.email = email
    self.isEmailVerified = isEmailVerified
    self.role = role
    self.newEmail = newEmail
    self.currentPassword = currentPassword
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

