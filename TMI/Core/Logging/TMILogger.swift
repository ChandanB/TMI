//
//  TMILogger.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import OSLog
import Foundation

nonisolated final class TMILogger: Sendable {
    private let subsystem = "com.tmi.education"
    private let logger: Logger
    private let category: String

    static let production = TMILogger(category: "Application")
    
    // Log levels
    nonisolated enum Level: String, Sendable {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case critical = "🔥"
    }
    
    init(category: String) {
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, metadata: [String: Any]? = nil, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(level: .debug, message: message, metadata: metadata, file: file, line: line)
        #endif
    }
    
    func info(_ message: String, metadata: [String: Any]? = nil, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, metadata: metadata, file: file, line: line)
    }
    
    func warning(_ message: String, metadata: [String: Any]? = nil, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, metadata: metadata, file: file, line: line)
    }
    
    func error(_ message: String, error: Error? = nil, context: ErrorContext? = nil, file: String = #file, line: Int = #line) {
        var metadata: [String: Any] = [:]
        
        if let error = error {
            metadata["error"] = error.localizedDescription
            metadata["errorType"] = String(describing: type(of: error))
        }
        
        if let context = context {
            metadata["operation"] = context.operation
            metadata["userId"] = context.userId ?? "anonymous"
            if let contextMeta = context.metadata {
                for (key, value) in contextMeta {
                    metadata[key] = value
                }
            }
        }
        
        log(level: .error, message: message, metadata: metadata, file: file, line: line)
        
        // Send to analytics in production
        #if !DEBUG
        let analyticsMetadata = stringifyMetadata(metadata)
        let errorDescription = error?.localizedDescription
        Task {
            await Analytics.shared.trackError(
                message,
                errorDescription: errorDescription,
                metadata: analyticsMetadata
            )
        }
        #endif
    }
    
    func critical(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        var metadata: [String: Any] = [:]
        if let error = error {
            metadata["error"] = error.localizedDescription
            metadata["errorType"] = String(describing: type(of: error))
        }
        
        log(level: .critical, message: message, metadata: metadata, file: file, line: line)
        
        // Immediately send to crash reporting
        let errorDescription = error?.localizedDescription
        Task {
            await CrashReporter.shared.logCritical(message, errorDescription: errorDescription)
        }
    }
    
    // MARK: - Performance Logging
    
    func logPerformance(_ operation: String, duration: TimeInterval, metadata: [String: Any]? = nil) {
        var perfMetadata = metadata ?? [:]
        perfMetadata["duration"] = duration
        perfMetadata["operation"] = operation
        
        if duration > 1.0 {
            warning("Slow operation detected: \(operation)", metadata: perfMetadata)
        } else {
            debug("Performance: \(operation)", metadata: perfMetadata)
        }
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Log user interactions with enhanced tracking
    func logUserAction(_ action: String, userId: String?, metadata: [String: Any]? = nil) {
        var actionMetadata = metadata ?? [:]
        actionMetadata["userId"] = userId ?? "anonymous"
        actionMetadata["timestamp"] = Date().timeIntervalSince1970
        actionMetadata["actionType"] = "user_interaction"
        
        info("User action: \(action)", metadata: actionMetadata)
        
        #if !DEBUG
        let analyticsMetadata = stringifyMetadata(actionMetadata)
        Task {
            await Analytics.shared.trackUserAction(
                action,
                userId: userId,
                metadata: analyticsMetadata
            )
        }
        #endif
    }
    
    /// Log network requests with detailed information
    func logNetwork(_ request: String, method: String, statusCode: Int? = nil, duration: TimeInterval? = nil) {
        var networkMetadata: [String: Any] = [
            "method": method,
            "requestType": "network"
        ]
        
        if let statusCode = statusCode {
            networkMetadata["statusCode"] = statusCode
        }
        
        if let duration = duration {
            networkMetadata["duration"] = String(format: "%.3f", duration)
        }
        
        let level: Level = {
            if let code = statusCode {
                return code >= 400 ? .error : .info
            }
            return .info
        }()
        
        log(level: level, message: "Network: \(request)", metadata: networkMetadata)
    }
    
    /// Log Firebase operations with collection and document tracking
    func logFirebase(_ operation: String, collection: String? = nil, documentId: String? = nil, success: Bool = true) {
        var firebaseMetadata: [String: Any] = [
            "success": success,
            "operationType": "firebase"
        ]
        
        if let collection = collection {
            firebaseMetadata["collection"] = collection
        }
        
        if let documentId = documentId {
            firebaseMetadata["documentId"] = documentId
        }
        
        let level: Level = success ? .info : .error
        log(level: level, message: "Firebase: \(operation)", metadata: firebaseMetadata)
    }
    
    /// Log accessibility events for compliance tracking
    func logAccessibility(_ event: String, element: String? = nil, metadata: [String: Any]? = nil) {
        var accessibilityMetadata = metadata ?? [:]
        accessibilityMetadata["eventType"] = "accessibility"
        
        if let element = element {
            accessibilityMetadata["element"] = element
        }
        
        info("Accessibility: \(event)", metadata: accessibilityMetadata)
    }
    
    // MARK: - Private Methods
    
    private func log(level: Level, message: String, metadata: [String: Any]?, file: String = #file, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let metadataString = formatMetadata(metadata)
        let sendableMetadata = stringifyMetadata(metadata)
        let metadataSuffix = metadataString.isEmpty ? "" : " | \(metadataString)"

        // Runtime messages and metadata are private by default. Categories and
        // levels are stable operational labels and are safe to expose.
        switch level {
        case .debug:
            logger.debug(
                "[\(self.category, privacy: .public)] \(level.rawValue, privacy: .public) \(message, privacy: .private)\(metadataSuffix, privacy: .private)"
            )
        case .info:
            logger.info(
                "[\(self.category, privacy: .public)] \(level.rawValue, privacy: .public) \(message, privacy: .private)\(metadataSuffix, privacy: .private)"
            )
        case .warning:
            logger.warning(
                "[\(self.category, privacy: .public)] \(level.rawValue, privacy: .public) \(message, privacy: .private)\(metadataSuffix, privacy: .private)"
            )
        case .error:
            logger.error(
                "[\(self.category, privacy: .public)] \(level.rawValue, privacy: .public) \(message, privacy: .private)\(metadataSuffix, privacy: .private)"
            )
        case .critical:
            logger.critical(
                "[\(self.category, privacy: .public)] \(level.rawValue, privacy: .public) \(message, privacy: .private)\(metadataSuffix, privacy: .private)"
            )
        }
        
        // Store for crash reporting context
        let logEntry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: sendableMetadata,
            file: fileName,
            line: line
        )
        
        Task {
            await LogContext.shared.addLog(logEntry)
        }
        
        // Add breadcrumb for significant events
        if level == .error || level == .critical {
            let breadcrumbLevel: Breadcrumb.Level = level == .critical ? .critical : .error
            let breadcrumb = Breadcrumb(
                message: message,
                category: category,
                level: breadcrumbLevel,
                data: sendableMetadata
            )
            
            Task {
                await LogContext.shared.addBreadcrumb(breadcrumb)
            }
        }
    }
    
    private func formatMetadata(_ metadata: [String: Any]?) -> String {
        guard let metadata = metadata else { return "" }
        
        return metadata.compactMap { key, value in
            "\(key)=\(String(describing: value))"
        }.joined(separator: ", ")
    }

    private func stringifyMetadata(_ metadata: [String: Any]?) -> [String: String] {
        metadata?.mapValues { String(describing: $0) } ?? [:]
    }
}

// MARK: - Global Logger Factory
nonisolated struct Log {
    static func category(_ category: String) -> TMILogger {
        TMILogger(category: category)
    }
    
    // Predefined loggers for major app components
    static let auth = TMILogger(category: "Authentication")
    static let firebase = TMILogger(category: "Firebase")
    static let ui = TMILogger(category: "UI")
    static let network = TMILogger(category: "Network")
    static let data = TMILogger(category: "Data")
    static let performance = TMILogger(category: "Performance")
    static let security = TMILogger(category: "Security")
    static let validation = TMILogger(category: "Validation")
    static let accessibility = TMILogger(category: "Accessibility")
    static let tmiPlan = TMILogger(category: "TMIPlan")
    static let student = TMILogger(category: "Student")
    static let cache = TMILogger(category: "Cache")
    static let storage = TMILogger(category: "Storage")
}

// MARK: - Analytics Integration
actor Analytics {
    static let shared = Analytics()

    private let logger = Logger(subsystem: "com.tmi.education", category: "Analytics")
    private var events: [AnalyticsEvent] = []
    
    func trackError(
        _ message: String,
        errorDescription: String?,
        metadata: [String: String]
    ) async {
        let event = AnalyticsEvent(
            type: .error,
            name: "error_occurred",
            properties: [
                "message": message,
                "error": errorDescription ?? "unknown",
                "metadata": metadata.description
            ]
        )
        
        events.append(event)
        await flush()
    }
    
    func trackUserAction(
        _ action: String,
        userId: String?,
        metadata: [String: String]
    ) async {
        let event = AnalyticsEvent(
            type: .userAction,
            name: action,
            properties: [
                "userId": userId ?? "anonymous",
                "timestamp": String(Date().timeIntervalSince1970),
                "metadata": metadata.description
            ]
        )
        
        events.append(event)
        
        // Flush user actions immediately in production
        #if !DEBUG
        await flush()
        #endif
    }
    
    func trackPerformance(_ operation: String, duration: TimeInterval) async {
        let event = AnalyticsEvent(
            type: .performance,
            name: "performance_metric",
            properties: [
                "operation": operation,
                "duration": String(duration),
                "timestamp": String(Date().timeIntervalSince1970)
            ]
        )
        
        events.append(event)
        await flush()
    }
    
    func trackAccessibility(_ event: String, element: String? = nil) async {
        let analyticsEvent = AnalyticsEvent(
            type: .accessibility,
            name: "accessibility_event",
            properties: [
                "event": event,
                "element": element ?? "unknown",
                "timestamp": String(Date().timeIntervalSince1970)
            ]
        )
        
        events.append(analyticsEvent)
        await flush()
    }
    
    func getEventCount() async -> Int {
        return events.count
    }
    
    private func flush() async {
        #if DEBUG
        if !events.isEmpty {
            logger.debug("analytics_events_queued count=\(self.events.count, privacy: .public)")
        }
        #endif
    }
}

// MARK: - Crash Reporter
actor CrashReporter {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: "com.tmi.education", category: "CrashReporter")

    func logCritical(_ message: String, errorDescription: String?) async {
        // In a real implementation, this would integrate with crash reporting services
        // like Firebase Crashlytics or Bugsnag
        
        #if DEBUG
        logger.critical(
            "critical_event message=\(message, privacy: .private) error=\(errorDescription ?? "none", privacy: .private)"
        )
        #else
        // Send to crash reporting service
        // FirebaseCrashlytics.crashlytics().log(message)
        // if let error = error {
        //     FirebaseCrashlytics.crashlytics().record(error: error)
        // }
        #endif
    }
}

// MARK: - Supporting Types
nonisolated struct AnalyticsEvent: Sendable {
    nonisolated enum EventType: String, Sendable {
        case error = "error"
        case userAction = "user_action"
        case performance = "performance"
        case accessibility = "accessibility"
        case security = "security"
        case validation = "validation"
    }
    
    let type: EventType
    let name: String
    let properties: [String: String]
    let timestamp: Date = Date()
}
