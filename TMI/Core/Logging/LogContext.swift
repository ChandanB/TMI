import Foundation

/// Manages log context for crash reporting and debugging
actor LogContext {
    static let shared = LogContext()
    
    private var recentLogs: [LogEntry] = []
    private let maxLogCount = 200
    private var breadcrumbs: [Breadcrumb] = []
    private let maxBreadcrumbs = 50
    
    private init() {}
    
    // MARK: - Log Management
    
    func addLog(_ entry: LogEntry) {
        recentLogs.append(entry)
        
        // Keep only recent logs
        if recentLogs.count > maxLogCount {
            recentLogs.removeFirst()
        }
    }
    
    func getRecentLogs(level: TMILogger.Level? = nil, category: String? = nil) -> [LogEntry] {
        var filteredLogs = recentLogs
        
        if let level = level {
            filteredLogs = filteredLogs.filter { $0.level == level }
        }
        
        if let category = category {
            filteredLogs = filteredLogs.filter { $0.category == category }
        }
        
        return filteredLogs
    }
    
    func clearLogs() {
        recentLogs.removeAll()
    }
    
    // MARK: - Breadcrumb Management
    
    func addBreadcrumb(_ breadcrumb: Breadcrumb) {
        breadcrumbs.append(breadcrumb)
        
        // Keep only recent breadcrumbs
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst()
        }
    }
    
    func getBreadcrumbs() -> [Breadcrumb] {
        return breadcrumbs
    }
    
    func clearBreadcrumbs() {
        breadcrumbs.removeAll()
    }
    
    // MARK: - Crash Report Generation
    
    func generateCrashReport(error: Error? = nil) -> CrashReport {
        let errorLogs = recentLogs.filter { $0.level == .error || $0.level == .critical }
        let criticalLogs = recentLogs.filter { $0.level == .critical }
        
        return CrashReport(
            error: error,
            timestamp: Date(),
            recentLogs: Array(recentLogs.suffix(50)), // Last 50 logs
            errorLogs: errorLogs,
            criticalLogs: criticalLogs,
            breadcrumbs: breadcrumbs,
            appInfo: AppInfo.current
        )
    }
}

// MARK: - Supporting Types

struct LogEntry: Sendable {
    let level: TMILogger.Level
    let category: String
    let message: String
    let metadata: [String: Any]?
    let timestamp: Date
    let file: String
    let line: Int
    
    init(level: TMILogger.Level, category: String, message: String, metadata: [String: Any]? = nil, file: String = #file, line: Int = #line) {
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.timestamp = Date()
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.line = line
    }
}

struct Breadcrumb: Sendable {
    let timestamp: Date
    let message: String
    let category: String
    let level: Level
    let data: [String: String]?
    
    enum Level: String, Sendable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        case critical = "critical"
    }
    
    init(message: String, category: String = "general", level: Level = .info, data: [String: String]? = nil) {
        self.timestamp = Date()
        self.message = message
        self.category = category
        self.level = level
        self.data = data
    }
}

struct CrashReport: Sendable {
    let error: Error?
    let timestamp: Date
    let recentLogs: [LogEntry]
    let errorLogs: [LogEntry]
    let criticalLogs: [LogEntry]
    let breadcrumbs: [Breadcrumb]
    let appInfo: AppInfo
}

struct AppInfo: Sendable {
    let version: String
    let buildNumber: String
    let bundleIdentifier: String
    let deviceModel: String
    let osVersion: String
    let locale: String
    
    static let current = AppInfo(
        version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
        bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
        deviceModel: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown",
        osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        locale: Locale.current.identifier
    )
}

// MARK: - Breadcrumb Convenience Methods

extension LogContext {
    func userAction(_ action: String, userId: String? = nil) {
        let breadcrumb = Breadcrumb(
            message: "User performed action: \(action)",
            category: "user_action",
            level: .info,
            data: userId.map { ["userId": $0] }
        )
        
        Task {
            addBreadcrumb(breadcrumb)
        }
    }
    
    func navigation(_ screen: String, from: String? = nil) {
        let breadcrumb = Breadcrumb(
            message: "Navigated to \(screen)",
            category: "navigation",
            level: .info,
            data: from.map { ["from": $0] }
        )
        
        Task {
            addBreadcrumb(breadcrumb)
        }
    }
    
    func networkRequest(_ endpoint: String, method: String, statusCode: Int? = nil) {
        let breadcrumb = Breadcrumb(
            message: "\(method) \(endpoint)",
            category: "network",
            level: statusCode != nil && statusCode! >= 400 ? .error : .info,
            data: [
                "method": method,
                "endpoint": endpoint,
                "statusCode": statusCode.map(String.init) ?? "unknown"
            ]
        )
        
        Task {
            addBreadcrumb(breadcrumb)
        }
    }
}
