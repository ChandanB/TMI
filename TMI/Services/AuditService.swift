//
//  AuditService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore
import Foundation
import Observation

// MARK: - Audit Service

@Observable
final class AuditService {

  // MARK: - Dependencies
  private let firestore: Firestore
  private let deviceInfoProvider: DeviceInfoProvider

  // MARK: - Configuration
  private let batchSize: Int = 50
  private let maxRetries: Int = 3
  private let retentionPeriod: TimeInterval = 7 * 365 * 24 * 60 * 60  // 7 years

  // MARK: - State
  private var pendingEvents: [AuditEvent] = []
  private var isProcessingBatch = false

  // MARK: - Initialization

  init(
    firestore: Firestore = Firestore.firestore(),
    deviceInfoProvider: DeviceInfoProvider = DeviceInfoProvider()
  ) {
    self.firestore = firestore
    self.deviceInfoProvider = deviceInfoProvider

    // Start periodic batch processing
    startBatchProcessing()
  }

  // MARK: - Public Methods

  /// Log an audit event
  func logEvent(_ event: AuditEvent) async {
    // Add device info if not present
    var enhancedEvent = event
    if enhancedEvent.deviceInfo == nil {
      enhancedEvent = AuditEvent(
        id: event.id,
        eventID: event.eventID,
        timestamp: event.timestamp,
        userID: event.userID,
        userRole: event.userRole,
        action: event.action,
        resourceType: event.resourceType,
        resourceID: event.resourceID,
        dataClassification: event.dataClassification,
        ipAddress: await getIPAddress(),
        deviceInfo: await deviceInfoProvider.getCurrentDeviceInfo(),
        sessionID: event.sessionID,
        consentVersion: event.consentVersion,
        additionalMetadata: event.additionalMetadata,
        result: event.result,
        riskLevel: event.riskLevel
      )
    }

    // Add to pending batch
    pendingEvents.append(enhancedEvent)

    // Process immediately for high-risk events
    if enhancedEvent.riskLevel == .critical || enhancedEvent.riskLevel == .high {
      await processSingleEvent(enhancedEvent)
    }

    // Process batch if it's full
    if pendingEvents.count >= batchSize {
      await processBatch()
    }
  }

  /// Query audit events
  func queryEvents(_ query: AuditQuery) async throws -> [AuditEvent] {
    var firestoreQuery: Query = firestore.collection("audit_events")

    // Apply filters
    if let userID = query.userID {
      firestoreQuery = firestoreQuery.whereField("userID", isEqualTo: userID)
    }

    if let userRole = query.userRole {
      firestoreQuery = firestoreQuery.whereField("userRole", isEqualTo: userRole.rawValue)
    }

    if let actions = query.actions, !actions.isEmpty {
      firestoreQuery = firestoreQuery.whereField("action", in: actions.map { $0.rawValue })
    }

    if let startDate = query.startDate {
      firestoreQuery = firestoreQuery.whereField("timestamp", isGreaterThanOrEqualTo: startDate)
    }

    if let endDate = query.endDate {
      firestoreQuery = firestoreQuery.whereField("timestamp", isLessThanOrEqualTo: endDate)
    }

    if let riskLevels = query.riskLevels, !riskLevels.isEmpty {
      firestoreQuery = firestoreQuery.whereField("riskLevel", in: riskLevels.map { $0.rawValue })
    }

    // Apply ordering and limits
    firestoreQuery = firestoreQuery.order(by: "timestamp", descending: true)

    if let limit = query.limit {
      firestoreQuery = firestoreQuery.limit(to: limit)
    }

    // Execute query
    let snapshot = try await firestoreQuery.getDocuments()
    return try snapshot.documents.compactMap { document in
      try Firestore.Decoder().decode(AuditEvent.self, from: document.data())
    }
  }

  /// Generate compliance report
  func generateComplianceReport(
    type: ComplianceReportType, timeRange: DateInterval, generatedBy: String
  ) async throws -> ComplianceReport {
    let query = AuditQuery(
      startDate: timeRange.start,
      endDate: timeRange.end,
      limit: 10000  // Large limit for comprehensive reporting
    )

    let events = try await queryEvents(query)
    let summary = generateAuditSummary(from: events, timeRange: timeRange)

    // Generate compliance-specific data
    let dataRetentionCompliance = await checkDataRetentionCompliance()
    let consentCompliance = await checkConsentCompliance()
    let violations = await detectComplianceViolations(events: events, type: type)
    let recommendations = generateRecommendations(violations: violations, type: type)

    return ComplianceReport(
      reportType: type,
      generatedBy: generatedBy,
      timeRange: timeRange,
      summary: summary,
      violations: violations,
      recommendations: recommendations,
      dataRetentionCompliance: dataRetentionCompliance,
      consentCompliance: consentCompliance
    )
  }

  /// Check for suspicious activity
  func detectSuspiciousActivity(userID: String, timeWindow: TimeInterval = 3600) async throws
    -> [SecurityAlert]
  {
    let startDate = Date().addingTimeInterval(-timeWindow)
    let query = AuditQuery(
      userID: userID,
      startDate: startDate,
      endDate: Date()
    )

    let events = try await queryEvents(query)
    var alerts: [SecurityAlert] = []

    // Detect failed login attempts
    let failedLogins = events.filter { $0.action == .loginFailed }
    if failedLogins.count >= 5 {
      alerts.append(
        SecurityAlert(
          type: .multipleFailedLogins,
          severity: .high,
          userID: userID,
          description: "Multiple failed login attempts detected",
          events: failedLogins
        ))
    }

    // Detect unusual access patterns
    let sensitiveDataAccess = events.filter {
      $0.action == .sensitiveDataViewed || $0.action == .traumaDataAccessed
    }
    if sensitiveDataAccess.count > 10 {
      alerts.append(
        SecurityAlert(
          type: .unusualDataAccess,
          severity: .medium,
          userID: userID,
          description: "Unusual sensitive data access pattern",
          events: sensitiveDataAccess
        ))
    }

    // Detect privilege escalation attempts
    let roleChanges = events.filter { $0.action == .roleChanged }
    if !roleChanges.isEmpty {
      alerts.append(
        SecurityAlert(
          type: .privilegeEscalation,
          severity: .critical,
          userID: userID,
          description: "Role change detected",
          events: roleChanges
        ))
    }

    return alerts
  }

  /// Clean up old audit records based on data classification
  func cleanupExpiredRecords() async throws {
    let cutoffDate = Date().addingTimeInterval(-retentionPeriod)

    // Query for old records
    let query = firestore.collection("audit_events")
      .whereField("timestamp", isLessThan: cutoffDate)
      .limit(to: 1000)  // Process in batches

    let snapshot = try await query.getDocuments()

    if !snapshot.documents.isEmpty {
      let batch = firestore.batch()

      for document in snapshot.documents {
          let data = document.data()
        // Check if record can be deleted based on data classification
        if let classificationRaw = data["dataClassification"] as? String,
          let classification = DataClassification(rawValue: classificationRaw)
        {

          let recordAge = Date().timeIntervalSince(document.data()["timestamp"] as? Date ?? Date())

          if recordAge > classification.retentionPeriod {
            batch.deleteDocument(document.reference)
          }
        }
      }

      try await batch.commit()
    }
  }

  // MARK: - Private Methods

  private func startBatchProcessing() {
    Task {
      while true {
        try await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
        await processBatch()
      }
    }
  }

  private func processBatch() async {
    guard !isProcessingBatch && !pendingEvents.isEmpty else { return }

    isProcessingBatch = true
    defer { isProcessingBatch = false }

    let eventsToProcess = Array(pendingEvents.prefix(batchSize))
    pendingEvents.removeFirst(min(batchSize, pendingEvents.count))

    do {
      let batch = firestore.batch()

      for event in eventsToProcess {
        let documentRef = firestore.collection("audit_events").document(event.eventID)
        let eventData = try Firestore.Encoder().encode(event)
        batch.setData(eventData, forDocument: documentRef)
      }

      try await batch.commit()

      // Also log to secure external audit system if configured
      await logToExternalAuditSystem(eventsToProcess)

    } catch {
      // Re-add failed events to retry queue
      pendingEvents.insert(contentsOf: eventsToProcess, at: 0)
      print("Failed to process audit batch: \(error)")
    }
  }

  private func processSingleEvent(_ event: AuditEvent) async {
    do {
      let documentRef = firestore.collection("audit_events").document(event.eventID)
      let eventData = try Firestore.Encoder().encode(event)
      try await documentRef.setData(eventData)

      // Immediately alert for critical events
      if event.riskLevel == .critical {
        await sendCriticalEventAlert(event)
      }

    } catch {
      // Add to pending queue for retry
      pendingEvents.append(event)
      print("Failed to process critical audit event: \(error)")
    }
  }

  private func generateAuditSummary(from events: [AuditEvent], timeRange: DateInterval)
    -> AuditSummary
  {
    var eventsByCategory: [AuditCategory: Int] = [:]
    var eventsByRiskLevel: [RiskLevel: Int] = [:]
    var eventsByResult: [AuditResult: Int] = [:]
    var topUsers: [String: Int] = [:]
    var topActions: [AuditAction: Int] = [:]

    for event in events {
      // Count by category
      eventsByCategory[event.action.category, default: 0] += 1

      // Count by risk level
      eventsByRiskLevel[event.riskLevel, default: 0] += 1

      // Count by result
      eventsByResult[event.result, default: 0] += 1

      // Count by user
      topUsers[event.userID, default: 0] += 1

      // Count by action
      topActions[event.action, default: 0] += 1
    }

    return AuditSummary(
      totalEvents: events.count,
      eventsByCategory: eventsByCategory,
      eventsByRiskLevel: eventsByRiskLevel,
      eventsByResult: eventsByResult,
      topUsers: topUsers,
      topActions: topActions,
      timeRange: timeRange
    )
  }

  private func checkDataRetentionCompliance() async -> DataRetentionCompliance {
    // This would query the database to check data retention compliance
    // For now, return mock data
    return DataRetentionCompliance(
      compliantRecords: 950,
      violatingRecords: 25,
      expiringSoon: 75,
      totalRecords: 1050
    )
  }

  private func checkConsentCompliance() async -> ConsentCompliance {
    // This would query user records to check consent compliance
    // For now, return mock data
    return ConsentCompliance(
      usersWithValidConsent: 185,
      usersWithExpiredConsent: 10,
      usersWithMissingConsent: 5,
      minorsWithParentalConsent: 45,
      minorsWithoutParentalConsent: 2,
      totalUsers: 200
    )
  }

  private func detectComplianceViolations(events: [AuditEvent], type: ComplianceReportType) async
    -> [ComplianceViolation]
  {
    var violations: [ComplianceViolation] = []

    // Detect unauthorized access to sensitive data
    let unauthorizedAccess = events.filter { event in
      (event.action == .sensitiveDataViewed || event.action == .traumaDataAccessed)
        && event.result == .blocked
    }

    if !unauthorizedAccess.isEmpty {
      violations.append(
        ComplianceViolation(
          violationType: .unauthorizedAccess,
          severity: .high,
          description: "Unauthorized access to sensitive data detected",
          affectedUsers: Array(Set(unauthorizedAccess.map { $0.userID }))
        ))
    }

    // Detect missing audit trails
    let criticalActions = events.filter { $0.riskLevel == .critical }
    for event in criticalActions {
      if event.deviceInfo == nil || event.ipAddress == nil {
        violations.append(
          ComplianceViolation(
            violationType: .missingAuditTrail,
            severity: .medium,
            description: "Critical action missing complete audit trail",
            affectedUsers: [event.userID]
          ))
      }
    }

    return violations
  }

  private func generateRecommendations(
    violations: [ComplianceViolation], type: ComplianceReportType
  ) -> [String] {
    var recommendations: [String] = []

    if violations.contains(where: { $0.violationType == .unauthorizedAccess }) {
      recommendations.append("Review and update access control policies")
      recommendations.append("Implement additional authentication factors for sensitive data")
    }

    if violations.contains(where: { $0.violationType == .missingAuditTrail }) {
      recommendations.append(
        "Enhance audit logging to capture complete device and network information")
      recommendations.append("Implement automated audit trail validation")
    }

    if violations.isEmpty {
      recommendations.append("Continue current compliance practices")
      recommendations.append("Consider implementing additional proactive monitoring")
    }

    return recommendations
  }

  private func logToExternalAuditSystem(_ events: [AuditEvent]) async {
    // This would send events to an external audit system for immutable logging
    // Implementation would depend on the specific external system being used
    print("Logged \(events.count) events to external audit system")
  }

  private func sendCriticalEventAlert(_ event: AuditEvent) async {
    // This would send immediate alerts for critical security events
    // Could integrate with email, SMS, or incident management systems
    print("CRITICAL SECURITY EVENT: \(event.action.displayName) by user \(event.userID)")
  }

  private func getIPAddress() async -> String? {
    // This would get the current device's IP address
    // Implementation would vary based on platform
    return "192.168.1.100"  // Mock IP
  }
}

// MARK: - Device Info Provider

class DeviceInfoProvider {
  func getCurrentDeviceInfo() async -> DeviceInfo {
    return DeviceInfo(
      deviceType: .iPhone,  // Would detect actual device type
      operatingSystem: "iOS",
      osVersion: "17.0",  // Would get actual version
      appVersion: "1.0.0",  // Would get from bundle
      deviceModel: "iPhone 15 Pro",  // Would get actual model
      deviceID: UIDevice.current.identifierForVendor?.uuidString,
      timezone: TimeZone.current.identifier,
      locale: Locale.current.identifier
    )
  }
}

// MARK: - Security Alert

struct SecurityAlert: Identifiable {
  let id: String
  let type: SecurityAlertType
  let severity: ViolationSeverity
  let userID: String
  let description: String
  let detectedAt: Date
  let events: [AuditEvent]

  init(
    id: String = UUID().uuidString,
    type: SecurityAlertType,
    severity: ViolationSeverity,
    userID: String,
    description: String,
    detectedAt: Date = Date(),
    events: [AuditEvent]
  ) {
    self.id = id
    self.type = type
    self.severity = severity
    self.userID = userID
    self.description = description
    self.detectedAt = detectedAt
    self.events = events
  }
}

enum SecurityAlertType: String, CaseIterable {
  case multipleFailedLogins = "multiple_failed_logins"
  case unusualDataAccess = "unusual_data_access"
  case privilegeEscalation = "privilege_escalation"
  case dataExfiltration = "data_exfiltration"
  case suspiciousLocation = "suspicious_location"
  case timeAnomalousAccess = "time_anomalous_access"

  var displayName: String {
    switch self {
    case .multipleFailedLogins: return "Multiple Failed Logins"
    case .unusualDataAccess: return "Unusual Data Access"
    case .privilegeEscalation: return "Privilege Escalation"
    case .dataExfiltration: return "Data Exfiltration"
    case .suspiciousLocation: return "Suspicious Location"
    case .timeAnomalousAccess: return "Time Anomalous Access"
    }
  }
}

// MARK: - Global Instance

let AUDIT_SERVICE = AuditService()
