import Foundation
import CryptoKit
import LocalAuthentication

/// Central security configuration and utilities for the TMI application
struct SecurityConfig {
    
    // MARK: - Security Constants
    
    struct Encryption {
        static let keySize: Int = 32 // 256 bits
        static let keyRotationInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        static let maxDataSize = 10 * 1024 * 1024 // 10MB limit
    }
    
    struct Session {
        static let tokenLifetime: TimeInterval = 24 * 60 * 60 // 24 hours
        static let refreshTokenLifetime: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        static let maxSessionsPerUser = 5
        static let sessionTimeoutWarning: TimeInterval = 5 * 60 // 5 minutes before expiry
    }
    
    struct Biometric {
        static let isRequired = false // Can be configured per deployment
        static let fallbackToPasscode = true
        static let maxFailedAttempts = 3
        static let lockoutDuration: TimeInterval = 15 * 60 // 15 minutes
    }
    
    struct DataProtection {
        static let studentDataRequiresBiometric = false
        static let credentialsRequireBiometric = true
        static let sensitiveFieldsEncrypted = true
        static let auditLogRetention: TimeInterval = 365 * 24 * 60 * 60 // 1 year
    }
    
    // MARK: - Security Policies
    
    /// Determine if data should be encrypted based on sensitivity
    static func requiresEncryption(for dataType: DataClassification) -> Bool {
        switch dataType {
        case .publicData:
            return false
        case .internalData:
            return true
        case .personal, .educational, .sensitive, .traumaRelated:
            return true
        }
    }
    
    /// Determine if biometric authentication is required
    static func requiresBiometric(for dataType: DataClassification, userRole: UserRole) -> Bool {
        switch dataType {
        case .publicData, .internalData:
            return false
        case .personal, .educational:
            return userRole.requiresBiometricForConfidential
        case .sensitive, .traumaRelated:
            return true
        }
    }
    
    /// Get appropriate access control for data type
    static func accessControl(for dataType: DataClassification) throws -> SecAccessControl {
        let keychain = KeychainManager()
        
        switch dataType {
        case .publicData, .internalData:
            return try keychain.createPasscodeAccessControl()
        case .personal, .educational, .sensitive, .traumaRelated:
            return try keychain.createBiometricAccessControl()
        }
    }
}


// MARK: - Data Classification

enum DataClassification: String, CaseIterable, Codable, Identifiable, Sendable {
  case publicData = "public"
  case internalData = "internal"
  case personal = "personal"
  case educational = "educational"
  case sensitive = "sensitive"
  case traumaRelated = "trauma_related"
  
  var id: String { rawValue }
  
  var displayName: String {
    switch self {
    case .publicData: return "Public"
    case .internalData: return "Internal"
    case .personal: return "Personal"
    case .educational: return "Educational"
    case .sensitive: return "Sensitive"
    case .traumaRelated: return "Trauma-Related"
    }
  }
  
  var description: String {
    switch self {
    case .publicData: return "Information that can be freely shared"
    case .internalData: return "Information for internal organizational use"
    case .personal: return "Personal identifying information"
    case .educational: return "Educational records and assessments"
    case .sensitive: return "Sensitive personal information requiring special protection"
    case .traumaRelated: return "Trauma-informed data requiring highest level of protection"
    }
  }
  
  var retentionPeriod: TimeInterval {
    switch self {
    case .publicData: return 365 * 24 * 60 * 60 // 1 year
    case .internalData: return 3 * 365 * 24 * 60 * 60 // 3 years
    case .personal: return 7 * 365 * 24 * 60 * 60 // 7 years
    case .educational: return 7 * 365 * 24 * 60 * 60 // 7 years (FERPA)
    case .sensitive: return 10 * 365 * 24 * 60 * 60 // 10 years
    case .traumaRelated: return 25 * 365 * 24 * 60 * 60 // 25 years
    }
  }
  
  var encryptionRequired: Bool {
    switch self {
    case .publicData, .internalData: return false
    case .personal, .educational, .sensitive, .traumaRelated: return true
    }
  }
    
  var auditRequired: Bool {
      switch self {
      case .publicData, .internalData: return false
      case .personal, .educational, .sensitive, .traumaRelated: return true
      }
  }
}

// MARK: - User Role Security Extensions
extension UserRole {
    var requiresBiometricForConfidential: Bool {
        switch self {
        case .teacher, .counselor, .administrator, .admin:
            return true
        case .student:
            return false
        case .parent, .legalGuardian:
            return false
        case .socialWorker:
            return true
        }
    }
    
    var canAccessRestrictedData: Bool {
        switch self {
        case .administrator, .admin, .counselor:
            return true
        default:
            return false
        }
    }
    
    var dataRetentionPeriod: TimeInterval {
        switch self {
        case .administrator, .admin:
            return 7 * 365 * 24 * 60 * 60 // 7 years
        case .counselor, .socialWorker:
            return 5 * 365 * 24 * 60 * 60 // 5 years
        default:
            return 3 * 365 * 24 * 60 * 60 // 3 years
        }
    }
}

// MARK: - Security Audit Logger
actor SecurityAuditLogger {
    static let shared = SecurityAuditLogger()
    
    private var auditLog: [SecurityAuditEntry] = []
    private let maxLogEntries = 10000
    let logger = Log.security
    
    func logSecurityEvent(
        _ event: SecurityEvent,
        userId: String?,
        success: Bool,
        details: [String: String]? = nil
    ) {
        let entry = SecurityAuditEntry(
            timestamp: Date(),
            event: event,
            userId: userId,
            success: success,
            details: details
        )
        
        auditLog.append(entry)
        
        // Trim log if it gets too large
        if auditLog.count > maxLogEntries {
            auditLog.removeFirst()
        }
        
        // Log to system logger
        if success {
            logger.info("Security event: \(event.rawValue) userId: \(userId ?? "anonymous") success: \(success) details: \(details ?? [:])")
        } else {
            logger.warning("Security event: \(event.rawValue) userId: \(userId ?? "anonymous") success: \(success) details: \(details ?? [:])")
        }
        
        // Send critical events to external monitoring
        if event.isCritical {
            Task {
                await sendToSecurityMonitoring(entry)
            }
        }
    }
    
    func getAuditLog(for userId: String? = nil, since: Date? = nil) -> [SecurityAuditEntry] {
        var filteredLog = auditLog
        
        if let userId = userId {
            filteredLog = filteredLog.filter { $0.userId == userId }
        }
        
        if let since = since {
            filteredLog = filteredLog.filter { $0.timestamp >= since }
        }
        
        return filteredLog.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func sendToSecurityMonitoring(_ entry: SecurityAuditEntry) async {
        // In production, this would send to external security monitoring
        logger.critical("Critical security event event: \(entry.event.rawValue) userId: \(entry.userId ?? "anonymous") success: \(entry.success)")
    }
}

// MARK: - Security Event Types
enum SecurityEvent: String, Sendable, Codable {
    // Authentication events
    case login = "auth.login"
    case logout = "auth.logout"
    case loginFailed = "auth.login.failed"
    case biometricAuthSuccess = "auth.biometric.success"
    case biometricAuthFailed = "auth.biometric.failed"
    case sessionExpired = "auth.session.expired"
    
    // Data access events
    case dataAccess = "data.access"
    case dataModification = "data.modification"
    case dataExport = "data.export"
    case dataImport = "data.import"
    case unauthorizedAccess = "data.unauthorized.access"
    
    // Security events
    case encryptionKeyRotated = "security.key.rotated"
    case secureStorageCleared = "security.storage.cleared"
    case securityPolicyViolation = "security.policy.violation"
    case suspiciousActivity = "security.suspicious.activity"
    
    // Configuration events
    case securityConfigChanged = "config.security.changed"
    case permissionsModified = "config.permissions.modified"
    
    var isCritical: Bool {
        switch self {
        case .unauthorizedAccess, .securityPolicyViolation, .suspiciousActivity:
            return true
        default:
            return false
        }
    }
    
    var requiresAudit: Bool {
        switch self {
        case .dataAccess, .dataModification, .dataExport, .dataImport,
             .unauthorizedAccess, .securityPolicyViolation:
            return true
        default:
            return false
        }
    }
}

// MARK: - Security Audit Entry
struct SecurityAuditEntry: Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let event: SecurityEvent
    let userId: String?
    let success: Bool
    let details: [String: String]?
    
    init(timestamp: Date, event: SecurityEvent, userId: String?, success: Bool, details: [String: String]?) {
        self.id = UUID()
        self.timestamp = timestamp
        self.event = event
        self.userId = userId
        self.success = success
        self.details = details
    }
    
    // Custom Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case event
        case userId
        case success
        case details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        event = try container.decode(SecurityEvent.self, forKey: .event)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        success = try container.decode(Bool.self, forKey: .success)
        details = try container.decodeIfPresent([String: String].self, forKey: .details)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(event, forKey: .event)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(details, forKey: .details)
    }
    
    var description: String {
        let userInfo = userId ?? "anonymous"
        let statusInfo = success ? "SUCCESS" : "FAILED"
        let detailsInfo = details?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") ?? ""
        
        return "[\(timestamp)] \(event.rawValue) - User: \(userInfo) - Status: \(statusInfo) - Details: \(detailsInfo)"
    }
}

// MARK: - Security Utilities
struct SecurityUtils {
    private static let logger = Log.security
    
    /// Generate cryptographically secure random data
    static func generateSecureRandomData(length: Int) throws -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw SecurityError.randomGenerationFailed
        }
        
        return data
    }
    
    /// Generate secure random string for tokens
    static func generateSecureToken(length: Int = 32) throws -> String {
        let data = try generateSecureRandomData(length: length)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Hash password with salt
    static func hashPassword(_ password: String, salt: String? = nil) throws -> (hash: String, salt: String) {
        let saltToUse = salt ?? (try? generateSecureToken(length: 16)) ?? ""
        let saltedPassword = password + saltToUse
        let passwordData = Data(saltedPassword.utf8)
        let hashedData = SHA256.hash(data: passwordData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return (hash: hashString, salt: saltToUse)
    }
    
    /// Verify password against hash
    static func verifyPassword(_ password: String, hash: String, salt: String) -> Bool {
        do {
            let (computedHash, _) = try hashPassword(password, salt: salt)
            return computedHash == hash
        } catch {
            logger.error("Password verification failed")
            return false
        }
    }
    
    /// Check if device supports biometric authentication
    static func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get biometric authentication type
    static func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    /// Sanitize input to prevent injection attacks
    static func sanitizeInput(_ input: String) -> String {
        let dangerousChars = CharacterSet(charactersIn: "<>\"';&|*?~^()[]{}$\")")
        return input.components(separatedBy: dangerousChars).joined()
    }
    
    /// Validate that data meets security requirements
    static func validateSecurityCompliance(for data: Any, classification: DataClassification) async throws {
        // Check data size limits
        if let data = data as? Data, data.count > SecurityConfig.Encryption.maxDataSize {
            throw SecurityError.dataTooLarge
        }
        
        // Check if encryption is required
        if classification.encryptionRequired {
            logger.debug("Data requires encryption classification: \(classification.rawValue)")
        }
        
        // Check if audit logging is required
        if classification.auditRequired {
            await SecurityAuditLogger.shared.logSecurityEvent(
                .dataAccess,
                userId: nil, // Should be provided by caller
                success: true,
                details: ["classification": classification.rawValue]
            )
        }
    }
}

// MARK: - Security Errors
enum SecurityError: Error, LocalizedError, Sendable {
    case randomGenerationFailed
    case dataTooLarge
    case encryptionRequired
    case biometricNotAvailable
    case unauthorized
    case policyViolation(String)
    
    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return "Failed to generate secure random data"
        case .dataTooLarge:
            return "Data exceeds maximum allowed size for secure storage"
        case .encryptionRequired:
            return "Data classification requires encryption"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .unauthorized:
            return "Unauthorized access attempt"
        case .policyViolation(let details):
            return "Security policy violation: \(details)"
        }
    }
}

// MARK: - Security Manager
@MainActor
final class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    @Published private(set) var isBiometricEnabled = false
    @Published private(set) var securityLevel: SecurityLevel = .standard
    
    private let secureStorage = SecureStorage.shared
    private let auditLogger = SecurityAuditLogger.shared
    private let logger = Log.security
    
    private init() {
        updateSecurityStatus()
    }
    
    func updateSecurityStatus() {
        isBiometricEnabled = SecurityUtils.isBiometricAuthenticationAvailable()
        
        // Determine security level based on device capabilities
        if isBiometricEnabled {
            securityLevel = .enhanced
        } else {
            securityLevel = .standard
        }
        
        logger.info("Security status updated biometricEnabled: \(isBiometricEnabled) securityLevel: \(securityLevel.rawValue) biometricType: \(SecurityUtils.getBiometricType().rawValue)")
    }
    
    func enforceSecurityPolicy(for operation: SecurityOperation, userRole: UserRole) async throws {
        logger.debug("Enforcing security policy operation: \(operation.rawValue) userRole: \(userRole.rawValue)")
        
        // Check if user role has permission for operation
        guard operation.isAllowed(for: userRole) else {
            await auditLogger.logSecurityEvent(
                .securityPolicyViolation,
                userId: nil,
                success: false,
                details: ["operation": operation.rawValue, "role": userRole.rawValue]
            )
            throw SecurityError.unauthorized
        }
        
        // Check if operation requires biometric authentication
        if operation.requiresBiometric && !isBiometricEnabled {
            throw SecurityError.biometricNotAvailable
        }
        
        // Log successful policy enforcement
        await auditLogger.logSecurityEvent(
            .dataAccess,
            userId: nil,
            success: true,
            details: ["operation": operation.rawValue]
        )
    }
}

// MARK: - Security Level
enum SecurityLevel: String, Sendable {
    case minimal = "minimal"
    case standard = "standard"
    case enhanced = "enhanced"
    case maximum = "maximum"
    
    var description: String {
        switch self {
        case .minimal:
            return "Minimal - Basic security measures"
        case .standard:
            return "Standard - Password protection and encryption"
        case .enhanced:
            return "Enhanced - Biometric authentication available"
        case .maximum:
            return "Maximum - All security features enabled"
        }
    }
}


// MARK: - Security Operations
enum SecurityOperation: String, Sendable {
    case viewStudentData = "view.student.data"
    case modifyStudentData = "modify.student.data"
    case exportData = "export.data"
    case manageUsers = "manage.users"
    case systemConfiguration = "system.configuration"
    
    func isAllowed(for role: UserRole) -> Bool {
        switch (self, role) {
        case (.viewStudentData, .teacher), (.viewStudentData, .counselor),
             (.viewStudentData, .administrator), (.viewStudentData, .socialWorker):
            return true
        case (.modifyStudentData, .teacher), (.modifyStudentData, .counselor),
             (.modifyStudentData, .socialWorker):
            return true
        case (.exportData, .administrator), (.exportData, .counselor):
            return true
        case (.manageUsers, .administrator):
            return true
        case (.systemConfiguration, .administrator):
            return true
        default:
            return false
        }
    }
    
    var requiresBiometric: Bool {
        switch self {
        case .exportData, .manageUsers, .systemConfiguration:
            return true
        default:
            return false
        }
    }
}

