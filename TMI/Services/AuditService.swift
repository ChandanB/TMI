//
//  AuditService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation
import Observation

// Note: Commented out Firestore import for now to fix compilation
// import FirebaseFirestore

// MARK: - TEMPORARY TYPE STUBS FOR AUDIT & COMPLIANCE MODELS
// These are minimal definitions to unblock compilation. Please refine and move to dedicated files.

enum RiskLevel: String, Codable, Sendable {
    case low, medium, high, critical
}

enum AuditResult: String, Codable, Sendable {
    case success, failure
}

struct DeviceInfo: Codable, Sendable {
    let deviceType: DeviceType
    let operatingSystem: String
    let osVersion: String
    let appVersion: String
    let deviceModel: String
    let deviceID: String
    let timezone: String
    let locale: String
    // Add more fields as needed
}

enum DeviceType: String, Codable, Sendable {
    case iPhone, iPad, Mac, unknown
}

struct AuditEvent: Codable, Sendable {
    var id: String = UUID().uuidString
    var eventID: String = UUID().uuidString
    var timestamp: Date = Date()
    var userID: String
    var userRole: StaffRole?
    var action: AuditAction
    var resourceType: String
    var resourceID: String?
    var dataClassification: DataClassification
    var ipAddress: String?
    var deviceInfo: DeviceInfo?
    var sessionID: String?
    var consentVersion: String?
    var additionalMetadata: [String: String]?
    var result: AuditResult
    var riskLevel: RiskLevel
}

enum AuditAction: String, Codable, Sendable {
    case login, logout, loginFailed, consentGranted, consentRevoked
    // Add more actions as appropriate
    var displayName: String {
        switch self {
        case .login: return "Login"
        case .logout: return "Logout"
        case .loginFailed: return "Login Failed"
        case .consentGranted: return "Consent Granted"
        case .consentRevoked: return "Consent Revoked"
        }
    }
    var defaultRiskLevel: RiskLevel {
        switch self {
        case .loginFailed: return .high
        case .logout: return .low
        default: return .medium
        }
    }
}

enum ComplianceReportType: String, Codable, Sendable {
    case coppa, ferpa, general
}

struct ComplianceReport: Codable, Sendable {
    var reportType: ComplianceReportType
    var generatedBy: String
    var timeRange: DateInterval
    var summary: AuditSummary
    var dataRetentionCompliance: DataRetentionCompliance
    var consentCompliance: ConsentCompliance
}

struct AuditSummary: Codable, Sendable {
    var totalEvents: Int
    var timeRange: DateInterval
}

struct DataRetentionCompliance: Codable, Sendable {
    var compliantRecords: Int
    var violatingRecords: Int
    var expiringSoon: Int
    var totalRecords: Int
}

struct ConsentCompliance: Codable, Sendable {
    var usersWithValidConsent: Int
    var usersWithExpiredConsent: Int
    var usersWithMissingConsent: Int
    var minorsWithParentalConsent: Int
    var minorsWithoutParentalConsent: Int
    var totalUsers: Int
}

// End of temporary stubs.

// MARK: - Audit Event Queue

actor AuditEventQueue {
  private var pendingEvents: [AuditEvent] = []
  private var retryCount: [String: Int] = [:]
  private let batchSize: Int
  private let maxRetries: Int
  private let maxQueueSize: Int

  init(batchSize: Int = 50, maxRetries: Int = 3, maxQueueSize: Int = 1000) {
    self.batchSize = batchSize
    self.maxRetries = maxRetries
    self.maxQueueSize = maxQueueSize
  }

  func addEvent(_ event: AuditEvent) {
    // Prevent memory issues by limiting queue size
    if pendingEvents.count >= maxQueueSize {
      // Drop oldest events if queue is full
      pendingEvents.removeFirst()
    }

    pendingEvents.append(event)
  }

  func getEventsForBatch() -> [AuditEvent] {
    let eventsToProcess = Array(pendingEvents.prefix(batchSize))
    pendingEvents.removeFirst(min(batchSize, pendingEvents.count))
    return eventsToProcess
  }

  func readdFailedEvents(_ events: [AuditEvent]) {
    for event in events {
      let currentRetries = retryCount[event.eventID, default: 0]

      // Only re-add if we haven't exceeded max retries
      if currentRetries < maxRetries {
        pendingEvents.insert(event, at: 0)
        retryCount[event.eventID] = currentRetries + 1
      } else {
        // Remove from retry tracking once max retries exceeded
        retryCount.removeValue(forKey: event.eventID)
        print("Audit event \(event.eventID) dropped after \(maxRetries) retries")
      }
    }
  }

  func hasPendingEvents() -> Bool {
    return !pendingEvents.isEmpty
  }

  func pendingEventCount() -> Int {
    return pendingEvents.count
  }

  func getRetryCount(for eventID: String) -> Int {
    return retryCount[eventID, default: 0]
  }

  func clearExpiredRetries() {
    // Clean up retry tracking for completed events
    let pendingEventIDs = Set(pendingEvents.map { $0.eventID })
    retryCount = retryCount.filter { pendingEventIDs.contains($0.key) }
  }
}

// MARK: - Audit Service

@MainActor
@Observable
final class AuditService {

  // MARK: - Dependencies
  private let deviceInfoProvider: DeviceInfoProvider
  private let eventQueue: AuditEventQueue

  // MARK: - Configuration
  private let batchSize: Int = 50
  private let maxRetries: Int = 3
  private let retentionPeriod: TimeInterval = 7 * 365 * 24 * 60 * 60  // 7 years
  private let batchProcessingInterval: TimeInterval = 30.0

  // MARK: - State
  private var isProcessingBatch = false
    private nonisolated(unsafe) var batchProcessingTask: Task<Void, Never>?

  // MARK: - Initialization

  init(
    deviceInfoProvider: DeviceInfoProvider = DeviceInfoProvider()
  ) {
    self.deviceInfoProvider = deviceInfoProvider
    self.eventQueue = AuditEventQueue(batchSize: batchSize, maxRetries: maxRetries)

    // Start periodic batch processing
    startBatchProcessing()
  }

  deinit {
    // Cancel background processing when service is deallocated
    batchProcessingTask?.cancel()
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

    // Add to thread-safe pending batch
    await eventQueue.addEvent(enhancedEvent)

    // Process immediately for high-risk events
    if enhancedEvent.riskLevel == .critical || enhancedEvent.riskLevel == .high {
      await processSingleEvent(enhancedEvent)
    }

    // Process batch if it's full
    let pendingCount = await eventQueue.pendingEventCount()
    if pendingCount >= batchSize {
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
    batchProcessingTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self = self else { break }

        do {
          try await Task.sleep(nanoseconds: UInt64(batchProcessingInterval * 1_000_000_000))
          await self.processBatch()

          // Periodically clean up expired retry tracking
          await self.eventQueue.clearExpiredRetries()

        } catch {
          // Task was cancelled, exit gracefully
          break
        }
      }
    }
  }

  private func processBatch() async {
    let hasPendingEvents = await eventQueue.hasPendingEvents()
    guard !isProcessingBatch && hasPendingEvents else { return }

    isProcessingBatch = true
    defer { isProcessingBatch = false }

    let eventsToProcess = await eventQueue.getEventsForBatch()
    guard !eventsToProcess.isEmpty else { return }

    do {
      // Mock implementation - replace with actual Firestore implementation later
      // Simulate processing delay
      try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

      // For now, just log successful processing
      print("Successfully processed batch of \(eventsToProcess.count) audit events")

    } catch {
      // Re-add failed events to retry queue with exponential backoff
      await eventQueue.readdFailedEvents(eventsToProcess)

      // Calculate delay based on retry count for exponential backoff
      if let firstEvent = eventsToProcess.first {
        let retryCount = await eventQueue.getRetryCount(for: firstEvent.eventID)
        let delay = min(pow(2.0, Double(retryCount)), 60.0) // Max 60 seconds delay

        print("Failed to process audit batch (retry \(retryCount)): \(error). Will retry in \(delay) seconds")

        // Add exponential backoff delay before next retry
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }
  }

  private func processSingleEvent(_ event: AuditEvent) async {
    do {
      // Mock implementation - replace with actual Firestore implementation later
      // Simulate processing delay
      try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

      print("Successfully processed \(event.riskLevel.rawValue) priority audit event: \(event.action.displayName)")

      // Immediately alert for critical events
      if event.riskLevel == .critical {
        await sendCriticalEventAlert(event)
      }

    } catch {
      // Add to pending queue for retry with exponential backoff
      let retryCount = await eventQueue.getRetryCount(for: event.eventID)
      let delay = min(pow(2.0, Double(retryCount)), 30.0) // Max 30 seconds for single events

      print("Failed to process \(event.riskLevel.rawValue) audit event (retry \(retryCount)): \(error). Will retry in \(delay) seconds")

      // Add exponential backoff delay before re-queuing
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      await eventQueue.addEvent(event)
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

final class DeviceInfoProvider: Sendable {
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

@MainActor
let AUDIT_SERVICE = AuditService()
