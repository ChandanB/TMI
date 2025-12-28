//
//  AuditLogService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  Service for audit logging operations
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class AuditLogService {
    static let shared = AuditLogService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Logging Operations

    /// Log an audit event
    func log(
        action: AuditLog.AuditAction,
        entityType: AuditLog.EntityType,
        entityId: String,
        metadata: [String: String]? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[AuditLogService] ⚠️ Cannot log: User not authenticated")
            return
        }

        // Fetch user info for context
        let userDoc = try? await db.collection("users").document(userId).getDocument()
        let userData = userDoc?.data()
        let userName = userData?["name"] as? String
        let userRole = userData?["role"] as? String
        let districtId = userData?["districtId"] as? String

        // Create audit log entry
        let auditLog = AuditLog(
            action: action,
            entityType: entityType,
            entityId: entityId,
            userId: userId,
            userName: userName,
            userRole: userRole,
            districtId: districtId,
            timestamp: Date(),
            ipAddress: nil, // Could be added via server-side function
            metadata: metadata
        )

        // Store in district-scoped collection if district exists
        if let districtId = districtId {
            try await db.collection("districts")
                .document(districtId)
                .collection("auditLogs")
                .addDocument(data: auditLog.toFirestoreData())

            print("[AuditLogService] ✅ Logged: \(action.displayName) for \(entityType.displayName)")
        } else {
            print("[AuditLogService] ⚠️ No district ID: Audit log not stored")
        }
    }

    /// Log an audit event with custom user context (for admin operations)
    func logWithContext(
        action: AuditLog.AuditAction,
        entityType: AuditLog.EntityType,
        entityId: String,
        userId: String,
        userName: String? = nil,
        userRole: String? = nil,
        districtId: String,
        metadata: [String: String]? = nil
    ) async throws {
        let auditLog = AuditLog(
            action: action,
            entityType: entityType,
            entityId: entityId,
            userId: userId,
            userName: userName,
            userRole: userRole,
            districtId: districtId,
            metadata: metadata
        )

        try await db.collection("districts")
            .document(districtId)
            .collection("auditLogs")
            .addDocument(data: auditLog.toFirestoreData())

        print("[AuditLogService] ✅ Logged with context: \(action.displayName)")
    }

    // MARK: - Fetch Operations

    /// Fetch audit logs for a district
    func fetchLogs(
        districtId: String,
        limit: Int = 100,
        action: AuditLog.AuditAction? = nil,
        entityType: AuditLog.EntityType? = nil,
        userId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [AuditLog] {
        var query: Query = db.collection("districts")
            .document(districtId)
            .collection("auditLogs")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        // Apply filters
        if let action = action {
            query = query.whereField("action", isEqualTo: action.rawValue)
        }

        if let entityType = entityType {
            query = query.whereField("entityType", isEqualTo: entityType.rawValue)
        }

        if let userId = userId {
            query = query.whereField("userId", isEqualTo: userId)
        }

        if let startDate = startDate {
            query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startDate))
        }

        if let endDate = endDate {
            query = query.whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: endDate))
        }

        let snapshot = try await query.getDocuments()

        let logs = snapshot.documents.compactMap { doc -> AuditLog? in
            try? doc.data(as: AuditLog.self)
        }

        print("[AuditLogService] 📖 Fetched \(logs.count) audit logs")
        return logs
    }

    /// Fetch audit logs for a specific entity
    func fetchLogs(for entityId: String, districtId: String) async throws -> [AuditLog] {
        let snapshot = try await db.collection("districts")
            .document(districtId)
            .collection("auditLogs")
            .whereField("entityId", isEqualTo: entityId)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        let logs = snapshot.documents.compactMap { doc -> AuditLog? in
            try? doc.data(as: AuditLog.self)
        }

        print("[AuditLogService] 📖 Fetched \(logs.count) logs for entity: \(entityId)")
        return logs
    }

    /// Fetch recent high-severity logs
    func fetchHighSeverityLogs(districtId: String, limit: Int = 50) async throws -> [AuditLog] {
        let allLogs = try await fetchLogs(districtId: districtId, limit: limit * 3) // Fetch more to filter

        let highSeverityLogs = allLogs.filter { $0.action.severity == .high }
            .prefix(limit)

        return Array(highSeverityLogs)
    }

    // MARK: - Statistics

    /// Get audit log statistics for a district
    func getStatistics(districtId: String, days: Int = 30) async throws -> AuditLogStatistics {
        let startDate = Date().addingTimeInterval(-Double(days * 86400))

        let logs = try await fetchLogs(
            districtId: districtId,
            limit: 10000, // Fetch many for statistics
            startDate: startDate
        )

        let totalLogs = logs.count
        let highSeverityCount = logs.filter { $0.action.severity == .high }.count
        let mediumSeverityCount = logs.filter { $0.action.severity == .medium }.count
        let lowSeverityCount = logs.filter { $0.action.severity == .low }.count

        // Count by action type
        var actionCounts: [String: Int] = [:]
        for log in logs {
            let actionName = log.action.displayName
            actionCounts[actionName, default: 0] += 1
        }

        // Count by entity type
        var entityCounts: [String: Int] = [:]
        for log in logs {
            let entityName = log.entityType.displayName
            entityCounts[entityName, default: 0] += 1
        }

        // Top users by activity
        var userCounts: [String: Int] = [:]
        for log in logs {
            let userName = log.userName ?? log.userId
            userCounts[userName, default: 0] += 1
        }

        return AuditLogStatistics(
            totalLogs: totalLogs,
            highSeverityCount: highSeverityCount,
            mediumSeverityCount: mediumSeverityCount,
            lowSeverityCount: lowSeverityCount,
            actionCounts: actionCounts,
            entityCounts: entityCounts,
            userCounts: userCounts,
            periodDays: days
        )
    }

    // MARK: - Data Retention

    /// Delete audit logs older than retention policy
    func applyRetentionPolicy(districtId: String, retentionDays: Int) async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 86400))

        let snapshot = try await db.collection("districts")
            .document(districtId)
            .collection("auditLogs")
            .whereField("timestamp", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()

        print("[AuditLogService] 🗑️ Found \(snapshot.documents.count) logs to delete")

        // Delete in batches
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()

        print("[AuditLogService] ✅ Deleted \(snapshot.documents.count) old audit logs")
        return snapshot.documents.count
    }

    // MARK: - Export

    /// Export audit logs to CSV format
    func exportToCSV(logs: [AuditLog]) -> String {
        var csv = "Timestamp,Action,Entity Type,Entity ID,User,Role,Severity\n"

        for log in logs {
            let timestamp = log.timestamp.formatted(date: .abbreviated, time: .shortened)
            let action = log.action.displayName
            let entityType = log.entityType.displayName
            let entityId = log.entityId
            let user = log.userName ?? log.userId
            let role = log.userRole ?? "Unknown"
            let severity = log.action.severity.rawValue

            csv += "\"\(timestamp)\",\"\(action)\",\"\(entityType)\",\"\(entityId)\",\"\(user)\",\"\(role)\",\"\(severity)\"\n"
        }

        return csv
    }
}

// MARK: - Supporting Types

struct AuditLogStatistics: Codable, Sendable {
    let totalLogs: Int
    let highSeverityCount: Int
    let mediumSeverityCount: Int
    let lowSeverityCount: Int
    let actionCounts: [String: Int]
    let entityCounts: [String: Int]
    let userCounts: [String: Int]
    let periodDays: Int

    var topActions: [(String, Int)] {
        actionCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    var topEntities: [(String, Int)] {
        entityCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    var topUsers: [(String, Int)] {
        userCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}
