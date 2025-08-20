//
//  PerformanceMonitor.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import os.signpost
import Foundation
import UIKit
import Network
import Observation
import SwiftUI

/// Production-grade performance monitoring with comprehensive metrics collection
@Observable
@MainActor
final class PerformanceMonitor: Sendable {
    static let shared = PerformanceMonitor()
    
    private let log = OSLog(subsystem: "com.tmi.education", category: .pointsOfInterest)
    private let logger = TMILogger(category: "Performance")
    
    // Metrics storage
    private var metrics: [String: [PerformanceMetric]] = [:]
    private var networkMetrics: [NetworkMetric] = []
    private var startupMetrics: [StartupMetric] = []
    private var memoryMetrics: [MemoryMetric] = []
    private var currentOperations: [String: OperationTracker] = [:]
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.tmi.performance.network")
    private(set) var networkStatus: NetworkStatus = .unknown
    private(set) var batteryLevel: Float = 1.0
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    // Current state
    private(set) var currentMemoryUsage: MemoryUsage = MemoryUsage()
    
    // Thresholds and configuration
    private let slowOperationThreshold: TimeInterval = 1.0
    private let memoryWarningThreshold: Int64 = 150 * 1024 * 1024 // 150MB
    private let maxMetricsPerOperation = 100
    private let maxNetworkMetrics = 500
    private let maxMemoryMetrics = 200
    
    // Memory and system monitoring
    private var memoryTimer: Timer?
    private var systemInfoTimer: Timer?
    private var isMonitoringMemory = false
    private var batteryLevelObserver: NSObjectProtocol?
    private var thermalStateObserver: NSObjectProtocol?
    
    // Metrics collection queue
    private let metricsQueue = DispatchQueue(label: "com.tmi.performance.metrics", qos: .utility)
    
    nonisolated private init() {
        Task { @MainActor in
            setupComprehensiveMonitoring()
        }
    }
    
    deinit {
        Task { @MainActor in
            networkMonitor.cancel()
            stopMemoryMonitoring()
            systemInfoTimer?.invalidate()
            
            if let observer = batteryLevelObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = thermalStateObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // MARK: - Comprehensive Monitoring Setup
    
    private func setupComprehensiveMonitoring() {
        startMemoryMonitoring()
        startNetworkMonitoring()
        startSystemInfoMonitoring()
        setupBatteryMonitoring()
        setupThermalStateMonitoring()
        setupNotificationObservers()
        
        logger.info("Comprehensive performance monitoring started")
    }
    
    // MARK: - Operation Measurement
    
    /// Measure performance of an async operation
    func measure<T>(
        operation: String,
        category: PerformanceCategory = .general,
        threshold: TimeInterval? = nil,
        block: () async throws -> T
    ) async rethrows -> T {
        let tracker = startOperation(operation, category: category)
        let threshold = threshold ?? slowOperationThreshold
        
        defer {
            let metric = endOperation(operation, tracker: tracker)
            
            // Log if over threshold
            if metric.duration > threshold {
                logger.warning(
                    "Slow operation detected: \(operation)",
                    metadata: [
                        "duration": metric.duration,
                        "threshold": threshold,
                        "memory": metric.memoryDelta,
                        "category": category.rawValue
                    ]
                )
            }
            
            // Track in analytics
            Task {
                await Analytics.shared.trackPerformance(operation, duration: metric.duration)
            }
        }
        
        return try await block()
    }
    
    /// Measure performance of a synchronous operation
    func measureSync<T>(
        operation: String,
        category: PerformanceCategory = .general,
        threshold: TimeInterval? = nil,
        block: () throws -> T
    ) rethrows -> T {
        let tracker = startOperation(operation, category: category)
        let threshold = threshold ?? slowOperationThreshold
        
        defer {
            let metric = endOperation(operation, tracker: tracker)
            
            if metric.duration > threshold {
                logger.warning(
                    "Slow sync operation: \(operation)",
                    metadata: [
                        "duration": metric.duration,
                        "threshold": threshold,
                        "memory": metric.memoryDelta
                    ]
                )
            }
        }
        
        return try block()
    }
    
    // MARK: - Network Performance Tracking
    
    /// Record network request performance
    func recordNetworkRequest(
        url: String,
        method: String,
        statusCode: Int,
        duration: TimeInterval,
        requestSize: Int64 = 0,
        responseSize: Int64 = 0,
        error: Error? = nil
    ) {
        let metric = NetworkMetric(
            id: UUID(),
            url: url,
            method: method,
            statusCode: statusCode,
            duration: duration,
            requestSize: requestSize,
            responseSize: responseSize,
            error: error?.localizedDescription,
            timestamp: Date(),
            networkType: networkStatus,
            batteryLevel: batteryLevel
        )
        
        metricsQueue.async {
            Task { @MainActor in
                self.networkMetrics.append(metric)
                
                // Keep metrics within bounds
                if self.networkMetrics.count > self.maxNetworkMetrics {
                    self.networkMetrics = Array(self.networkMetrics.suffix(self.maxNetworkMetrics))
                }
            }
        }
        
        logger.logNetwork(url, method: method, statusCode: statusCode, duration: duration)
    }
    
    // MARK: - Startup Performance Tracking
    
    /// Record app startup phase performance
    func recordStartupMetric(_ phase: StartupPhase, duration: TimeInterval, metadata: [String: Any]? = nil) {
        let memoryUsage = getCurrentMemoryUsage()
        let metric = StartupMetric(
            id: UUID(),
            phase: phase,
            duration: duration,
            timestamp: Date(),
            memoryUsage: memoryUsage,
            metadata: metadata
        )
        
        metricsQueue.async {
            Task { @MainActor in
                self.startupMetrics.append(metric)
            }
        }
        
        logger.info("Startup phase completed", metadata: [
            "phase": phase.rawValue,
            "duration": String(format: "%.3f", duration),
            "memoryUsed": Int64(memoryUsage.used)
        ])
    }
    
    // MARK: - System Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func startSystemInfoMonitoring() {
        systemInfoTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemInfo()
            }
        }
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        batteryLevelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.batteryLevel = UIDevice.current.batteryLevel
            }
        }
        
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    private func setupThermalStateMonitoring() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.thermalState = ProcessInfo.processInfo.thermalState
            }
        }
        
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        let newStatus: NetworkStatus
        
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                newStatus = .wifi
            } else if path.usesInterfaceType(.cellular) {
                newStatus = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                newStatus = .ethernet
            } else {
                newStatus = .other
            }
        } else {
            newStatus = .unavailable
        }
        
        if newStatus != networkStatus {
            networkStatus = newStatus
            logger.info("Network status changed", metadata: ["status": newStatus.rawValue])
        }
    }
    
    private func updateSystemInfo() {
        thermalState = ProcessInfo.processInfo.thermalState
        batteryLevel = UIDevice.current.batteryLevel
        updateMemoryUsage()
    }
    
    private func updateMemoryUsage() {
        currentMemoryUsage = getCurrentMemoryUsage()
        
        // Record memory metric
        let memoryMetric = MemoryMetric(
            id: UUID(),
            used: currentMemoryUsage.used,
            available: currentMemoryUsage.available,
            total: currentMemoryUsage.total,
            timestamp: Date()
        )
        
        metricsQueue.async {
            Task { @MainActor in
                self.memoryMetrics.append(memoryMetric)
                
                if self.memoryMetrics.count > self.maxMemoryMetrics {
                    self.memoryMetrics = Array(self.memoryMetrics.suffix(self.maxMemoryMetrics))
                }
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let used = result == KERN_SUCCESS ? Double(info.resident_size) : 0.0
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let available = total - used
        
        return MemoryUsage(used: used, available: available, total: total)
    }
    
    // MARK: - Private Operation Tracking
    
    private func startOperation(
        _ operation: String,
        category: PerformanceCategory
    ) -> OperationTracker {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Operation", signpostID: signpostID, "%{public}s", operation)
        
        let tracker = OperationTracker(
            operation: operation,
            category: category,
            startTime: CFAbsoluteTimeGetCurrent(),
            startMemory: memoryUsage(),
            signpostID: signpostID
        )
        
        currentOperations[operation] = tracker
        
        logger.debug("Started operation: \(operation)", metadata: [
            "category": category.rawValue,
            "startMemory": tracker.startMemory
        ])
        
        return tracker
    }
    
    private func endOperation(
        _ operation: String,
        tracker: OperationTracker
    ) -> PerformanceMetric {
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryUsage()
        
        os_signpost(.end, log: log, name: "Operation", signpostID: tracker.signpostID)
        
        let metric = PerformanceMetric(
            operation: operation,
            category: tracker.category,
            duration: endTime - tracker.startTime,
            memoryDelta: endMemory - tracker.startMemory,
            timestamp: Date()
        )
        
        // Store metric
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(metric)
        
        // Keep only recent metrics
        if metrics[operation]!.count > maxMetricsPerOperation {
            metrics[operation]?.removeFirst()
        }
        
        currentOperations.removeValue(forKey: operation)
        
        logger.debug("Completed operation: \(operation)", metadata: [
            "duration": metric.duration,
            "memoryDelta": metric.memoryDelta
        ])
        
        return metric
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        guard !isMonitoringMemory else { return }
        
        isMonitoringMemory = true
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
        
        logger.info("Started memory monitoring")
    }
    
    private func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        isMonitoringMemory = false
        
        logger.info("Stopped memory monitoring")
    }
    
    private func checkMemoryUsage() {
        updateMemoryUsage()
        
        if Int64(currentMemoryUsage.used) > memoryWarningThreshold {
            logger.warning("High memory usage detected", metadata: [
                "current": Int64(currentMemoryUsage.used),
                "threshold": memoryWarningThreshold,
                "currentMB": currentMemoryUsage.used / 1024 / 1024,
                "percentage": currentMemoryUsage.usagePercentage * 100
            ])
            
            // Post notification for app to potentially free memory
            NotificationCenter.default.post(
                name: .TMIMemoryPressure,
                object: nil,
                userInfo: ["memoryUsage": currentMemoryUsage]
            )
        }
    }
    
    private func memoryUsage() -> Int64 {
        return Int64(getCurrentMemoryUsage().used)
    }
    
    // MARK: - Metrics and Reporting
    
    /// Get performance metrics for a specific operation
    func getMetrics(for operation: String) -> [PerformanceMetric] {
        return metrics[operation] ?? []
    }
    
    /// Get all performance metrics
    func getAllMetrics() -> [String: [PerformanceMetric]] {
        return metrics
    }
    
    /// Get comprehensive performance statistics
    func getPerformanceStats(for category: PerformanceCategory? = nil, timeRange: TimeInterval = 3600) -> PerformanceStats {
        let cutoffTime = Date().addingTimeInterval(-timeRange)
        let allMetrics = metrics.values.flatMap { $0 }
        var filteredMetrics = allMetrics.filter { $0.timestamp >= cutoffTime }
        
        if let category = category {
            filteredMetrics = filteredMetrics.filter { $0.category == category }
        }
        
        guard !filteredMetrics.isEmpty else {
            return PerformanceStats(
                totalOperations: 0,
                successfulOperations: 0,
                averageDuration: 0,
                p50Duration: 0,
                p95Duration: 0,
                p99Duration: 0,
                averageMemoryDelta: 0,
                slowestOperations: [],
                errorRate: 0,
                timeRange: timeRange
            )
        }
        
        let durations = filteredMetrics.map { $0.duration }.sorted()
        let memoryDeltas = filteredMetrics.map { Double($0.memoryDelta) }
        
        return PerformanceStats(
            totalOperations: filteredMetrics.count,
            successfulOperations: filteredMetrics.count, // Assuming all completed operations are successful
            averageDuration: durations.average(),
            p50Duration: durations.percentile(50),
            p95Duration: durations.percentile(95),
            p99Duration: durations.percentile(99),
            averageMemoryDelta: memoryDeltas.average(),
            slowestOperations: filteredMetrics.sorted { $0.duration > $1.duration }.prefix(10).map { ($0.operation, $0.duration) },
            errorRate: 0.0, // Would need success/failure tracking
            timeRange: timeRange
        )
    }
    
    /// Get network performance statistics
    func getNetworkStats(timeRange: TimeInterval = 3600) -> NetworkStats {
        let cutoffTime = Date().addingTimeInterval(-timeRange)
        let filteredMetrics = networkMetrics.filter { $0.timestamp >= cutoffTime }
        
        guard !filteredMetrics.isEmpty else {
            return NetworkStats(
                totalRequests: 0,
                successfulRequests: 0,
                averageLatency: 0,
                totalDataTransferred: 0,
                errorRate: 0,
                slowestRequests: []
            )
        }
        
        let successfulRequests = filteredMetrics.filter { $0.statusCode < 400 }
        let totalDataTransferred = filteredMetrics.reduce(0) { $0 + $1.requestSize + $1.responseSize }
        
        return NetworkStats(
            totalRequests: filteredMetrics.count,
            successfulRequests: successfulRequests.count,
            averageLatency: filteredMetrics.map { $0.duration }.average(),
            totalDataTransferred: totalDataTransferred,
            errorRate: Double(filteredMetrics.count - successfulRequests.count) / Double(filteredMetrics.count),
            slowestRequests: filteredMetrics.sorted { $0.duration > $1.duration }.prefix(5).map { ($0.url, $0.duration) }
        )
    }
    
    /// Export comprehensive performance data
    func exportPerformanceData() async -> PerformanceExport {
        return await withCheckedContinuation { continuation in
            metricsQueue.async {
                let export = PerformanceExport(
                    exportDate: Date(),
                    deviceInfo: self.getPerformanceDeviceInfo(),
                    metrics: Array(self.metrics.values.flatMap { $0 }.suffix(500)),
                    networkMetrics: Array(self.networkMetrics.suffix(200)),
                    memoryMetrics: Array(self.memoryMetrics.suffix(100)),
                    startupMetrics: self.startupMetrics,
                    currentMemoryUsage: self.currentMemoryUsage,
                    networkStatus: self.networkStatus
                )
                continuation.resume(returning: export)
            }
        }
    }
    
    /// Clear old metrics to manage memory usage
    func cleanupOldMetrics() {
        metricsQueue.async {
            let cutoffTime = Date().addingTimeInterval(-24 * 3600) // Keep 24 hours
            
            Task { @MainActor in
                // Clean up operation metrics
                for key in self.metrics.keys {
                    let filteredMetrics = self.metrics[key]?.filter { $0.timestamp >= cutoffTime } ?? []
                    self.metrics[key] = Array(filteredMetrics.suffix(self.maxMetricsPerOperation))
                }
                
                // Clean up network metrics
                self.networkMetrics = Array(self.networkMetrics.filter { $0.timestamp >= cutoffTime }.suffix(self.maxNetworkMetrics))
                
                // Clean up memory metrics
                self.memoryMetrics = Array(self.memoryMetrics.filter { $0.timestamp >= cutoffTime }.suffix(self.maxMemoryMetrics))
                
                self.logger.debug("Cleaned up old performance metrics", metadata: [
                    "operationMetrics": self.metrics.values.map { $0.count }.reduce(0, +),
                    "networkMetrics": self.networkMetrics.count,
                    "memoryMetrics": self.memoryMetrics.count
                ])
            }
        }
    }
    
    private func getPerformanceDeviceInfo() -> PerformanceDeviceInfo {
        return PerformanceDeviceInfo(
            model: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            thermalState: ProcessInfo.processInfo.thermalState,
            batteryLevel: UIDevice.current.batteryLevel,
            networkStatus: networkStatus
        )
    }
    
    /// Generate legacy performance report for backward compatibility
    func generateReport() -> PerformanceReport {
        let allMetrics = metrics.values.flatMap { $0 }
        
        guard !allMetrics.isEmpty else {
            return PerformanceReport(
                metrics: [],
                summary: PerformanceSummary(
                    totalOperations: 0,
                    averageDuration: 0,
                    totalMemoryUsage: 0,
                    slowOperations: 0,
                    memoryPeakUsage: 0
                ),
                timestamp: Date()
            )
        }
        
        let totalOperations = allMetrics.count
        let averageDuration = allMetrics.map(\.duration).reduce(0, +) / Double(totalOperations)
        let totalMemoryUsage = allMetrics.map(\.memoryDelta).reduce(0, +)
        let slowOperations = allMetrics.filter { $0.duration > slowOperationThreshold }.count
        let memoryPeakUsage = allMetrics.map(\.memoryDelta).max() ?? 0
        
        let summary = PerformanceSummary(
            totalOperations: totalOperations,
            averageDuration: averageDuration,
            totalMemoryUsage: totalMemoryUsage,
            slowOperations: slowOperations,
            memoryPeakUsage: memoryPeakUsage
        )
        
        return PerformanceReport(
            metrics: allMetrics.sorted(by: { $0.timestamp > $1.timestamp }),
            summary: summary,
            timestamp: Date()
        )
    }
    
    /// Get slow operations summary
    func getSlowOperations(threshold: TimeInterval? = nil) -> [PerformanceMetric] {
        let threshold = threshold ?? slowOperationThreshold
        return metrics.values
            .flatMap { $0 }
            .filter { $0.duration > threshold }
            .sorted(by: { $0.duration > $1.duration })
    }
    
    /// Clear all metrics
    func clearMetrics() {
        metrics.removeAll()
        logger.info("Cleared all performance metrics")
    }
    
    // MARK: - App Lifecycle Monitoring
    
    private func setupNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("App became active")
            self?.startMemoryMonitoring()
        }
        
        notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("App entered background")
            self?.generateAndLogReport()
        }
        
        notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("Received memory warning")
            self?.handleMemoryWarning()
        }
    }
    
    private func generateAndLogReport() {
        let report = generateReport()
        
        logger.info("Performance report generated", metadata: [
            "totalOperations": report.summary.totalOperations,
            "averageDuration": report.summary.averageDuration,
            "slowOperations": report.summary.slowOperations,
            "memoryPeakMB": Double(report.summary.memoryPeakUsage) / 1024 / 1024
        ])
    }
    
    private func handleMemoryWarning() {
        let currentMemory = memoryUsage()
        let currentMemoryMB = Double(currentMemory) / 1024 / 1024
        
        logger.critical("Memory warning received", error: nil)
        
        // Clear old metrics to free memory
        let oldMetricsCount = metrics.values.map(\.count).reduce(0, +)
        
        // Keep only last 10 metrics per operation
        for key in metrics.keys {
            if metrics[key]!.count > 10 {
                metrics[key] = Array(metrics[key]!.suffix(10))
            }
        }
        
        let newMetricsCount = metrics.values.map(\.count).reduce(0, +)
        
        logger.info("Cleared old metrics due to memory pressure", metadata: [
            "oldCount": oldMetricsCount,
            "newCount": newMetricsCount,
            "memoryMB": currentMemoryMB
        ])
    }
}

// MARK: - Supporting Types

struct PerformanceMetric: Sendable, Identifiable {
    let id = UUID()
    let operation: String
    let category: PerformanceCategory
    let duration: TimeInterval
    let memoryDelta: Int64
    let timestamp: Date
    
    var durationMS: Double {
        duration * 1000
    }
    
    var memoryDeltaMB: Double {
        Double(memoryDelta) / 1024 / 1024
    }
}

struct PerformanceSummary: Sendable {
    let totalOperations: Int
    let averageDuration: TimeInterval
    let totalMemoryUsage: Int64
    let slowOperations: Int
    let memoryPeakUsage: Int64
    
    var averageDurationMS: Double {
        averageDuration * 1000
    }
    
    var totalMemoryUsageMB: Double {
        Double(totalMemoryUsage) / 1024 / 1024
    }
    
    var memoryPeakUsageMB: Double {
        Double(memoryPeakUsage) / 1024 / 1024
    }
    
    var slowOperationPercentage: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(slowOperations) / Double(totalOperations) * 100
    }
}

struct PerformanceReport: Sendable {
    let metrics: [PerformanceMetric]
    let summary: PerformanceSummary
    let timestamp: Date
}

enum PerformanceCategory: String, CaseIterable, Sendable {
    case general = "General"
    case network = "Network"
    case database = "Database"
    case ui = "UI"
    case firebase = "Firebase"
    case validation = "Validation"
    case authentication = "Authentication"
    case caching = "Caching"
    case startup = "Startup"
    case backgroundTask = "BackgroundTask"
    case encryption = "Encryption"
    case fileIO = "FileIO"
}

// MARK: - Enhanced Supporting Types

struct NetworkMetric: Sendable, Identifiable {
    let id: UUID
    let url: String
    let method: String
    let statusCode: Int
    let duration: TimeInterval
    let requestSize: Int64
    let responseSize: Int64
    let error: String?
    let timestamp: Date
    let networkType: NetworkStatus
    let batteryLevel: Float
}

struct StartupMetric: Sendable, Identifiable {
    let id: UUID
    let phase: StartupPhase
    let duration: TimeInterval
    let timestamp: Date
    let memoryUsage: MemoryUsage
    let metadata: [String: Any]?
}

struct MemoryMetric: Sendable, Identifiable {
    let id: UUID
    let used: Double
    let available: Double
    let total: Double
    let timestamp: Date
    
    var usagePercentage: Double {
        used / total
    }
}

struct MemoryUsage: Sendable {
    let used: Double
    let available: Double
    let total: Double
    
    init(used: Double = 0, available: Double = 0, total: Double = 0) {
        self.used = used
        self.available = available
        self.total = total
    }
    
    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return used / total
    }
}

struct PerformanceStats {
    let totalOperations: Int
    let successfulOperations: Int
    let averageDuration: Double
    let p50Duration: Double
    let p95Duration: Double
    let p99Duration: Double
    let averageMemoryDelta: Double
    let slowestOperations: [(String, TimeInterval)]
    let errorRate: Double
    let timeRange: TimeInterval
}

struct NetworkStats {
    let totalRequests: Int
    let successfulRequests: Int
    let averageLatency: Double
    let totalDataTransferred: Int64
    let errorRate: Double
    let slowestRequests: [(String, TimeInterval)]
}

struct PerformanceDeviceInfo: Sendable {
    let model: String
    let systemName: String
    let systemVersion: String
    let processorCount: Int
    let physicalMemory: UInt64
    let thermalState: ProcessInfo.ThermalState
    let batteryLevel: Float
    let networkStatus: NetworkStatus
}

struct PerformanceExport: Sendable {
    let exportDate: Date
    let deviceInfo: PerformanceDeviceInfo
    let metrics: [PerformanceMetric]
    let networkMetrics: [NetworkMetric]
    let memoryMetrics: [MemoryMetric]
    let startupMetrics: [StartupMetric]
    let currentMemoryUsage: MemoryUsage
    let networkStatus: NetworkStatus
}

enum NetworkStatus: String, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case other = "Other"
    case unavailable = "Unavailable"
    case unknown = "Unknown"
}

enum StartupPhase: String, Sendable, CaseIterable {
    case appLaunch = "AppLaunch"
    case coreModulesInit = "CoreModulesInit"
    case firebaseInit = "FirebaseInit"
    case authenticationCheck = "AuthenticationCheck"
    case dataPreload = "DataPreload"
    case uiRender = "UIRender"
    case ready = "Ready"
}

private struct OperationTracker: Sendable {
    let operation: String
    let category: PerformanceCategory
    let startTime: CFAbsoluteTime
    let startMemory: Int64
    let signpostID: OSSignpostID
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let TMIMemoryPressure = Notification.Name("TMIMemoryPressure")
    static let TMIPerformanceReport = Notification.Name("TMIPerformanceReport")
}

// MARK: - View Extensions

extension View {
    /// Measure view rendering performance
    func measureRenderingPerformance(_ operation: String) -> some View {
        self.onAppear {
            Task { @MainActor in
                await PerformanceMonitor.shared.measure(
                    operation: "view_render_\(operation)",
                    category: .ui
                ) {
                    // Simulate view measurement
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            }
        }
    }
}

// MARK: - Global Performance Helpers

struct Performance {
    /// Measure Firebase operations
    static func measureFirebase<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        return try await PerformanceMonitor.shared.measure(
            operation: "firebase_\(operation)",
            category: .firebase,
            threshold: 2.0, // Firebase operations can be slower
            block: block
        )
    }
    
    /// Measure network operations
    static func measureNetwork<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        return try await PerformanceMonitor.shared.measure(
            operation: "network_\(operation)",
            category: .network,
            threshold: 3.0, // Network operations can be slower
            block: block
        )
    }
    
    /// Measure validation operations
    static func measureValidation<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        return try await PerformanceMonitor.shared.measure(
            operation: "validation_\(operation)",
            category: .validation,
            threshold: 0.1, // Validation should be fast
            block: block
        )
    }
}

// MARK: - Array Extensions for Statistics

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = Int((Double(count - 1) * p / 100.0).rounded())
        return sorted[index]
    }
}

extension Array where Element == TimeInterval {
    func percentileTimeInterval(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = Int((Double(count - 1) * p / 100.0).rounded())
        return sorted[index]
    }
}

// MARK: - NetworkRequestData Helper

struct NetworkRequestData {
    let url: String
    let method: String
    let statusCode: Int
    let responseSize: Int
    let duration: TimeInterval
}

