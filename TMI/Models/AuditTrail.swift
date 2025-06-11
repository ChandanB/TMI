//
//  AuditTrail.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore
import Foundation

// MARK: - Audit Event

struct AuditEvent: Codable, Identifiable {
  @DocumentID var id: String?
  let eventID: String
  let timestamp: Date
  let userID: String
  let userRole: UserRole
  let action: AuditAction
  let resourceType: ResourceType
  let resourceID: String?
  let dataClassification: DataClassification
  let ipAddress: String?
  let deviceInfo: DeviceInfo?
  let sessionID: String?
  let consentVersion: String?
  let additionalMetadata: [String: String]
  let result: AuditResult
  let riskLevel: RiskLevel

  init(
    id: String? = nil,
    eventID: String = UUID().uuidString,
    timestamp: Date = Date(),
    userID: String,
    userRole: UserRole,
    action: AuditAction,
    resourceType: ResourceType,
    resourceID: String? = nil,
    dataClassification: DataClassification,
    ipAddress: String? = nil,
    deviceInfo: DeviceInfo? = nil,
    sessionID: String? = nil,
    consentVersion: String? = nil,
    additionalMetadata: [String: String] = [:],
    result: AuditResult = .success,
    riskLevel: RiskLevel = .low
  ) {
    self.id = id
    self.eventID = eventID
    self.timestamp = timestamp
    self.userID = userID
    self.userRole = userRole
    self.action = action
    self.resourceType = resourceType
    self.resourceID = resourceID
    self.dataClassification = dataClassification
    self.ipAddress = ipAddress
    self.deviceInfo = deviceInfo
    self.sessionID = sessionID
    self.consentVersion = consentVersion
    self.additionalMetadata = additionalMetadata
    self.result = result
    self.riskLevel = riskLevel
  }
}

// MARK: - Audit Action

enum AuditAction: String, CaseIterable, Codable {
  // Authentication actions
  case login = "login"
  case logout = "logout"
  case loginFailed = "login_failed"
  case accountLocked = "account_locked"
  case passwordReset = "password_reset"
  case emailVerification = "email_verification"
  case mfaVerification = "mfa_verification"
  case mfaFailed = "mfa_failed"

  // Data access actions
  case dataAccess = "data_access"
  case dataModification = "data_modification"
  case dataCreation = "data_creation"
  case dataDeletion = "data_deletion"
  case dataExport = "data_export"
  case sensitiveDataViewed = "sensitive_data_viewed"
  case traumaDataAccessed = "trauma_data_accessed"
  case familyDataAccessed = "family_data_accessed"

  // Consent actions
  case consentGranted = "consent_granted"
  case consentRevoked = "consent_revoked"
  case consentExpired = "consent_expired"
  case parentalConsentRequested = "parental_consent_requested"
  case parentalConsentGranted = "parental_consent_granted"
  case parentalConsentDenied = "parental_consent_denied"

  // User management actions
  case userCreated = "user_created"
  case userModified = "user_modified"
  case userDeactivated = "user_deactivated"
  case userDeleted = "user_deleted"
  case roleChanged = "role_changed"
  case permissionsModified = "permissions_modified"

  // System actions
  case systemConfiguration = "system_configuration"
  case securityPolicyChanged = "security_policy_changed"
  case dataRetentionPolicyChanged = "data_retention_policy_changed"
  case privacySettingsChanged = "privacy_settings_changed"

  // Educational actions
  case surveyAccessed = "survey_accessed"
  case assessmentCreated = "assessment_created"
  case interventionPlanCreated = "intervention_plan_created"
  case progressReportGenerated = "progress_report_generated"
  case analyticsAccessed = "analytics_accessed"

  var displayName: String {
    switch self {
    case .login: return "Login"
    case .logout: return "Logout"
    case .loginFailed: return "Login Failed"
    case .accountLocked: return "Account Locked"
    case .passwordReset: return "Password Reset"
    case .emailVerification: return "Email Verification"
    case .mfaVerification: return "MFA Verification"
    case .mfaFailed: return "MFA Failed"
    case .dataAccess: return "Data Access"
    case .dataModification: return "Data Modification"
    case .dataCreation: return "Data Creation"
    case .dataDeletion: return "Data Deletion"
    case .dataExport: return "Data Export"
    case .sensitiveDataViewed: return "Sensitive Data Viewed"
    case .traumaDataAccessed: return "Trauma Data Accessed"
    case .familyDataAccessed: return "Family Data Accessed"
    case .consentGranted: return "Consent Granted"
    case .consentRevoked: return "Consent Revoked"
    case .consentExpired: return "Consent Expired"
    case .parentalConsentRequested: return "Parental Consent Requested"
    case .parentalConsentGranted: return "Parental Consent Granted"
    case .parentalConsentDenied: return "Parental Consent Denied"
    case .userCreated: return "User Created"
    case .userModified: return "User Modified"
    case .userDeactivated: return "User Deactivated"
    case .userDeleted: return "User Deleted"
    case .roleChanged: return "Role Changed"
    case .permissionsModified: return "Permissions Modified"
    case .systemConfiguration: return "System Configuration"
    case .securityPolicyChanged: return "Security Policy Changed"
    case .dataRetentionPolicyChanged: return "Data Retention Policy Changed"
    case .privacySettingsChanged: return "Privacy Settings Changed"
    case .surveyAccessed: return "Survey Accessed"
    case .assessmentCreated: return "Assessment Created"
    case .interventionPlanCreated: return "Intervention Plan Created"
    case .progressReportGenerated: return "Progress Report Generated"
    case .analyticsAccessed: return "Analytics Accessed"
    }
  }

  var category: AuditCategory {
    switch self {
    case .login, .logout, .loginFailed, .accountLocked, .passwordReset, .emailVerification,
      .mfaVerification, .mfaFailed:
      return .authentication
    case .dataAccess, .dataModification, .dataCreation, .dataDeletion, .dataExport,
      .sensitiveDataViewed, .traumaDataAccessed, .familyDataAccessed:
      return .dataAccess
    case .consentGranted, .consentRevoked, .consentExpired, .parentalConsentRequested,
      .parentalConsentGranted, .parentalConsentDenied:
      return .consent
    case .userCreated, .userModified, .userDeactivated, .userDeleted, .roleChanged,
      .permissionsModified:
      return .userManagement
    case .systemConfiguration, .securityPolicyChanged, .dataRetentionPolicyChanged,
      .privacySettingsChanged:
      return .systemAdministration
    case .surveyAccessed, .assessmentCreated, .interventionPlanCreated, .progressReportGenerated,
      .analyticsAccessed:
      return .educational
    }
  }

  var defaultRiskLevel: RiskLevel {
    switch self {
    case .login, .logout, .emailVerification, .mfaVerification, .dataAccess, .surveyAccessed:
      return .low
    case .passwordReset, .dataModification, .dataCreation, .consentGranted, .assessmentCreated,
      .interventionPlanCreated:
      return .medium
    case .loginFailed, .mfaFailed, .dataDeletion, .sensitiveDataViewed, .consentRevoked,
      .roleChanged, .permissionsModified:
      return .high
    case .accountLocked, .dataExport, .traumaDataAccessed, .familyDataAccessed, .userDeleted,
      .systemConfiguration, .securityPolicyChanged:
      return .critical
    default:
      return .medium
    }
  }
}

// MARK: - Resource Type

enum ResourceType: String, CaseIterable, Codable {
  case user = "user"
  case student = "student"
  case survey = "survey"
  case assessment = "assessment"
  case interventionPlan = "intervention_plan"
  case progressReport = "progress_report"
  case traumaData = "trauma_data"
  case familyData = "family_data"
  case analytics = "analytics"
  case consent = "consent"
  case system = "system"
  case institution = "institution"

  var displayName: String {
    switch self {
    case .user: return "User"
    case .student: return "Student"
    case .survey: return "Survey"
    case .assessment: return "Assessment"
    case .interventionPlan: return "Intervention Plan"
    case .progressReport: return "Progress Report"
    case .traumaData: return "Trauma Data"
    case .familyData: return "Family Data"
    case .analytics: return "Analytics"
    case .consent: return "Consent"
    case .system: return "System"
    case .institution: return "Institution"
    }
  }
}

// MARK: - Audit Result

enum AuditResult: String, Codable {
  case success = "success"
  case failure = "failure"
  case partialSuccess = "partial_success"
  case blocked = "blocked"
  case error = "error"

  var displayName: String {
    switch self {
    case .success: return "Success"
    case .failure: return "Failure"
    case .partialSuccess: return "Partial Success"
    case .blocked: return "Blocked"
    case .error: return "Error"
    }
  }
}

// MARK: - Risk Level

enum RiskLevel: String, CaseIterable, Codable {
  case low = "low"
  case medium = "medium"
  case high = "high"
  case critical = "critical"

  var displayName: String {
    switch self {
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    case .critical: return "Critical"
    }
  }

  var color: String {
    switch self {
    case .low: return "green"
    case .medium: return "yellow"
    case .high: return "orange"
    case .critical: return "red"
    }
  }

  var priority: Int {
    switch self {
    case .low: return 1
    case .medium: return 2
    case .high: return 3
    case .critical: return 4
    }
  }
}

// MARK: - Audit Category

enum AuditCategory: String, CaseIterable, Codable {
  case authentication = "authentication"
  case dataAccess = "data_access"
  case consent = "consent"
  case userManagement = "user_management"
  case systemAdministration = "system_administration"
  case educational = "educational"

  var displayName: String {
    switch self {
    case .authentication: return "Authentication"
    case .dataAccess: return "Data Access"
    case .consent: return "Consent"
    case .userManagement: return "User Management"
    case .systemAdministration: return "System Administration"
    case .educational: return "Educational"
    }
  }
}

// MARK: - Device Info

struct DeviceInfo: Codable {
  let deviceType: DeviceType
  let operatingSystem: String
  let osVersion: String
  let appVersion: String
  let deviceModel: String?
  let deviceID: String?
  let userAgent: String?
  let screenResolution: String?
  let timezone: String
  let locale: String

  init(
    deviceType: DeviceType,
    operatingSystem: String,
    osVersion: String,
    appVersion: String,
    deviceModel: String? = nil,
    deviceID: String? = nil,
    userAgent: String? = nil,
    screenResolution: String? = nil,
    timezone: String = TimeZone.current.identifier,
    locale: String = Locale.current.identifier
  ) {
    self.deviceType = deviceType
    self.operatingSystem = operatingSystem
    self.osVersion = osVersion
    self.appVersion = appVersion
    self.deviceModel = deviceModel
    self.deviceID = deviceID
    self.userAgent = userAgent
    self.screenResolution = screenResolution
    self.timezone = timezone
    self.locale = locale
  }
}

enum DeviceType: String, Codable {
  case iPhone = "iPhone"
  case iPad = "iPad"
  case mac = "Mac"
  case web = "Web"
  case android = "Android"
  case unknown = "Unknown"

  var displayName: String {
    return self.rawValue
  }
}

// MARK: - Audit Query

struct AuditQuery {
  let userID: String?
  let userRole: UserRole?
  let actions: [AuditAction]?
  let categories: [AuditCategory]?
  let resourceTypes: [ResourceType]?
  let riskLevels: [RiskLevel]?
  let results: [AuditResult]?
  let startDate: Date?
  let endDate: Date?
  let limit: Int?
  let offset: Int?

  init(
    userID: String? = nil,
    userRole: UserRole? = nil,
    actions: [AuditAction]? = nil,
    categories: [AuditCategory]? = nil,
    resourceTypes: [ResourceType]? = nil,
    riskLevels: [RiskLevel]? = nil,
    results: [AuditResult]? = nil,
    startDate: Date? = nil,
    endDate: Date? = nil,
    limit: Int? = nil,
    offset: Int? = nil
  ) {
    self.userID = userID
    self.userRole = userRole
    self.actions = actions
    self.categories = categories
    self.resourceTypes = resourceTypes
    self.riskLevels = riskLevels
    self.results = results
    self.startDate = startDate
    self.endDate = endDate
    self.limit = limit
    self.offset = offset
  }
}

// MARK: - Audit Summary

struct AuditSummary: Codable {
  let totalEvents: Int
  let eventsByCategory: [AuditCategory: Int]
  let eventsByRiskLevel: [RiskLevel: Int]
  let eventsByResult: [AuditResult: Int]
  let topUsers: [String: Int]
  let topActions: [AuditAction: Int]
  let timeRange: DateInterval
  let generatedAt: Date

  init(
    totalEvents: Int,
    eventsByCategory: [AuditCategory: Int] = [:],
    eventsByRiskLevel: [RiskLevel: Int] = [:],
    eventsByResult: [AuditResult: Int] = [:],
    topUsers: [String: Int] = [:],
    topActions: [AuditAction: Int] = [:],
    timeRange: DateInterval,
    generatedAt: Date = Date()
  ) {
    self.totalEvents = totalEvents
    self.eventsByCategory = eventsByCategory
    self.eventsByRiskLevel = eventsByRiskLevel
    self.eventsByResult = eventsByResult
    self.topUsers = topUsers
    self.topActions = topActions
    self.timeRange = timeRange
    self.generatedAt = generatedAt
  }
}

// MARK: - Compliance Report

struct ComplianceReport: Codable {
  let reportID: String
  let reportType: ComplianceReportType
  let generatedBy: String
  let generatedAt: Date
  let timeRange: DateInterval
  let summary: AuditSummary
  let violations: [ComplianceViolation]
  let recommendations: [String]
  let dataRetentionCompliance: DataRetentionCompliance
  let consentCompliance: ConsentCompliance

  init(
    reportID: String = UUID().uuidString,
    reportType: ComplianceReportType,
    generatedBy: String,
    generatedAt: Date = Date(),
    timeRange: DateInterval,
    summary: AuditSummary,
    violations: [ComplianceViolation] = [],
    recommendations: [String] = [],
    dataRetentionCompliance: DataRetentionCompliance,
    consentCompliance: ConsentCompliance
  ) {
    self.reportID = reportID
    self.reportType = reportType
    self.generatedBy = generatedBy
    self.generatedAt = generatedAt
    self.timeRange = timeRange
    self.summary = summary
    self.violations = violations
    self.recommendations = recommendations
    self.dataRetentionCompliance = dataRetentionCompliance
    self.consentCompliance = consentCompliance
  }
}

enum ComplianceReportType: String, CaseIterable, Codable {
  case coppa = "coppa"
  case ferpa = "ferpa"
  case privacy = "privacy"
  case security = "security"
  case dataRetention = "data_retention"
  case comprehensive = "comprehensive"

  var displayName: String {
    switch self {
    case .coppa: return "COPPA Compliance"
    case .ferpa: return "FERPA Compliance"
    case .privacy: return "Privacy Compliance"
    case .security: return "Security Compliance"
    case .dataRetention: return "Data Retention Compliance"
    case .comprehensive: return "Comprehensive Compliance"
    }
  }
}

struct ComplianceViolation: Codable, Identifiable {
  let id: String
  let violationType: ViolationType
  let severity: ViolationSeverity
  let description: String
  let affectedUsers: [String]
  let detectedAt: Date
  let resolvedAt: Date?
  let resolutionNotes: String?

  init(
    id: String = UUID().uuidString,
    violationType: ViolationType,
    severity: ViolationSeverity,
    description: String,
    affectedUsers: [String] = [],
    detectedAt: Date = Date(),
    resolvedAt: Date? = nil,
    resolutionNotes: String? = nil
  ) {
    self.id = id
    self.violationType = violationType
    self.severity = severity
    self.description = description
    self.affectedUsers = affectedUsers
    self.detectedAt = detectedAt
    self.resolvedAt = resolvedAt
    self.resolutionNotes = resolutionNotes
  }
}

enum ViolationType: String, CaseIterable, Codable {
  case unauthorizedAccess = "unauthorized_access"
  case missingConsent = "missing_consent"
  case expiredConsent = "expired_consent"
  case dataRetentionViolation = "data_retention_violation"
  case unauthorizedDataSharing = "unauthorized_data_sharing"
  case inadequateEncryption = "inadequate_encryption"
  case missingAuditTrail = "missing_audit_trail"
  case accessWithoutPermission = "access_without_permission"

  var displayName: String {
    switch self {
    case .unauthorizedAccess: return "Unauthorized Access"
    case .missingConsent: return "Missing Consent"
    case .expiredConsent: return "Expired Consent"
    case .dataRetentionViolation: return "Data Retention Violation"
    case .unauthorizedDataSharing: return "Unauthorized Data Sharing"
    case .inadequateEncryption: return "Inadequate Encryption"
    case .missingAuditTrail: return "Missing Audit Trail"
    case .accessWithoutPermission: return "Access Without Permission"
    }
  }
}

enum ViolationSeverity: String, CaseIterable, Codable {
  case low = "low"
  case medium = "medium"
  case high = "high"
  case critical = "critical"

  var displayName: String {
    switch self {
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    case .critical: return "Critical"
    }
  }
}

struct DataRetentionCompliance: Codable {
  let compliantRecords: Int
  let violatingRecords: Int
  let expiringSoon: Int
  let totalRecords: Int
  let compliancePercentage: Double
  let lastChecked: Date

  init(
    compliantRecords: Int,
    violatingRecords: Int,
    expiringSoon: Int,
    totalRecords: Int,
    lastChecked: Date = Date()
  ) {
    self.compliantRecords = compliantRecords
    self.violatingRecords = violatingRecords
    self.expiringSoon = expiringSoon
    self.totalRecords = totalRecords
    self.compliancePercentage =
      totalRecords > 0 ? Double(compliantRecords) / Double(totalRecords) * 100 : 0
    self.lastChecked = lastChecked
  }
}

struct ConsentCompliance: Codable {
  let usersWithValidConsent: Int
  let usersWithExpiredConsent: Int
  let usersWithMissingConsent: Int
  let minorsWithParentalConsent: Int
  let minorsWithoutParentalConsent: Int
  let totalUsers: Int
  let compliancePercentage: Double
  let lastChecked: Date

  init(
    usersWithValidConsent: Int,
    usersWithExpiredConsent: Int,
    usersWithMissingConsent: Int,
    minorsWithParentalConsent: Int,
    minorsWithoutParentalConsent: Int,
    totalUsers: Int,
    lastChecked: Date = Date()
  ) {
    self.usersWithValidConsent = usersWithValidConsent
    self.usersWithExpiredConsent = usersWithExpiredConsent
    self.usersWithMissingConsent = usersWithMissingConsent
    self.minorsWithParentalConsent = minorsWithParentalConsent
    self.minorsWithoutParentalConsent = minorsWithoutParentalConsent
    self.totalUsers = totalUsers
    self.compliancePercentage =
      totalUsers > 0 ? Double(usersWithValidConsent) / Double(totalUsers) * 100 : 0
    self.lastChecked = lastChecked
  }
}
