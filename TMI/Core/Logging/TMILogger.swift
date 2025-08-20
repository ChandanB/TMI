//
//  TMILogger.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import OSLog
import Foundation

final class TMILogger: Sendable {
    private let subsystem = "com.tmi.education"
    private let logger: Logger
    private let category: String
    
    // Log levels
    enum Level: String, Sendable {
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
                metadata.merge(contextMeta) { _, new in new }
            }
        }
        
        log(level: .error, message: message, metadata: metadata, file: file, line: line)
        
        // Send to analytics in production
        #if !DEBUG
        Task {
            await Analytics.shared.trackError(message, error: error, metadata: metadata)
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
        Task {
            await CrashReporter.shared.logCritical(message, error: error)
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
        Task {
            await Analytics.shared.trackUserAction(action, userId: userId, metadata: actionMetadata)
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
        let fullMessage = "[\(category)] \(level.rawValue) \(message)\(metadataString.isEmpty ? "" : " | \(metadataString)")"
        
        // Log to OS logging system
        switch level {
        case .debug:
            logger.debug("\(fullMessage)")
        case .info:
            logger.info("\(fullMessage)")
        case .warning:
            logger.warning("\(fullMessage)")
        case .error:
            logger.error("\(fullMessage)")
        case .critical:
            logger.critical("\(fullMessage)")
        }
        
        // Store for crash reporting context
        let logEntry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
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
                data: metadata?.compactMapValues { String(describing: $0) }
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
}

// MARK: - Global Logger Factory
struct Log {
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
    
    private var events: [AnalyticsEvent] = []
    
    func trackError(_ message: String, error: Error?, metadata: [String: Any]) async {
        let event = AnalyticsEvent(
            type: .error,
            name: "error_occurred",
            properties: [
                "message": message,
                "error": error?.localizedDescription ?? "unknown",
                "metadata": metadata
            ]
        )
        
        events.append(event)
        await flush()
    }
    
    func trackUserAction(_ action: String, userId: String?, metadata: [String: Any]) async {
        let event = AnalyticsEvent(
            type: .userAction,
            name: action,
            properties: [
                "userId": userId ?? "anonymous",
                "timestamp": Date().timeIntervalSince1970,
                "metadata": metadata
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
                "duration": duration,
                "timestamp": Date().timeIntervalSince1970
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
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        
        events.append(analyticsEvent)
        await flush()
    }
    
    func getEventCount() async -> Int {
        return events.count
    }
    
    private func flush() async {
        // In a real implementation, this would send events to your analytics service
        // For now, we'll just log them
        #if DEBUG
        if !events.isEmpty {
            print("📊 Analytics: \(events.count) events queued")
        }
        #endif
    }
}

// MARK: - Crash Reporter
actor CrashReporter {
    static let shared = CrashReporter()
    
    func logCritical(_ message: String, error: Error?) async {
        // In a real implementation, this would integrate with crash reporting services
        // like Firebase Crashlytics or Bugsnag
        
        #if DEBUG
        print("🔥 CRITICAL: \(message) - \(error?.localizedDescription ?? "No error")")
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
struct AnalyticsEvent: Sendable {
    enum EventType: String, Sendable {
        case error = "error"
        case userAction = "user_action"
        case performance = "performance"
        case accessibility = "accessibility"
        case security = "security"
        case validation = "validation"
    }
    
    let type: EventType
    let name: String
    let properties: [String: Any]
    let timestamp: Date = Date()
}