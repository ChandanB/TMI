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

  /// Generate compliance report
  func generateComplianceReport(
    type: ComplianceReportType, timeRange: DateInterval, generatedBy: String
  ) async throws -> ComplianceReport {
    // This would implement comprehensive compliance reporting
    // For now, return a basic implementation

    let summary = AuditSummary(
      totalEvents: 1000,
      timeRange: timeRange
    )

    let dataRetentionCompliance = DataRetentionCompliance(
      compliantRecords: 950,
      violatingRecords: 25,
      expiringSoon: 75,
      totalRecords: 1050
    )

    let consentCompliance = ConsentCompliance(
      usersWithValidConsent: 185,
      usersWithExpiredConsent: 10,
      usersWithMissingConsent: 5,
      minorsWithParentalConsent: 45,
      minorsWithoutParentalConsent: 2,
      totalUsers: 200
    )

    return ComplianceReport(
      reportType: type,
      generatedBy: generatedBy,
      timeRange: timeRange,
      summary: summary,
      dataRetentionCompliance: dataRetentionCompliance,
      consentCompliance: consentCompliance
    )
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

  private func sendCriticalEventAlert(_ event: AuditEvent) async {
    // This would send immediate alerts for critical security events
    print("CRITICAL SECURITY EVENT: \(event.action.displayName) by user \(event.userID)")
  }

  private func getIPAddress() async -> String? {
    // This would get the current device's IP address
    return "192.168.1.100"  // Mock IP
  }
}

// MARK: - Device Info Provider

class DeviceInfoProvider {
  func getCurrentDeviceInfo() async -> DeviceInfo {
    return DeviceInfo(
      deviceType: .iPhone,
      operatingSystem: "iOS",
      osVersion: "17.0",
      appVersion: "1.0.0",
      deviceModel: "iPhone 15 Pro",
      deviceID: "mock-device-id",
      timezone: TimeZone.current.identifier,
      locale: Locale.current.identifier
    )
  }
}

// MARK: - Global Instance

let AUDIT_SERVICE = AuditService()
