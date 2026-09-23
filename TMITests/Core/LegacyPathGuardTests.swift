import Foundation
import Testing

/// CI guard for the legacy data cutover. Production code must not read or
/// write the retired per-user institutional collections, and the retired
/// services must not come back. Migration inputs live under `TMI/Migration`.
struct LegacyPathGuardTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Collections that only ever existed under `users/{uid}` for institutional data.
    private static let retiredCollections = [
        "tmiPlans", "formSubmissions", "resourceAssignments", "planApprovals",
        "hobbies", "auditLogs", "evidence", "inputs",
    ]

    private static let retiredServices = [
        "TMIPlanService", "FormSubmissionService", "ResourceAssignmentService",
        "PlanApprovalService", "InterestLibraryService", "ResourceLibraryService",
        "AuditLogService", "DistrictAnalyticsService", "DistrictExportService",
        "GoalsRepository", "PlanRepository", "DistrictStateModel",
    ]

    private static func productionSources() throws -> [(path: String, source: String)] {
        let appRoot = root.appending(path: "TMI")
        let enumerator = FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)
        var sources: [(String, String)] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = url.path(percentEncoded: false).replacingOccurrences(of: root.path(percentEncoded: false), with: "")
            if path.contains("/Migration/") { continue }
            sources.append((path, try String(contentsOf: url, encoding: .utf8)))
        }
        return sources
    }

    @Test func productionCodeAvoidsRetiredCollections() throws {
        for (path, source) in try Self.productionSources() {
            for collection in Self.retiredCollections {
                #expect(!source.contains("collection(\"\(collection)\")"), "\(path) uses retired collection \(collection)")
            }
        }
    }

    @Test func retiredServicesStayDeleted() throws {
        let sources = try Self.productionSources()
        for service in Self.retiredServices {
            let pattern = try Regex("\\b(class|struct|enum|actor)\\s+\(service)\\b")
            let definitions = sources.filter { $0.source.contains(pattern) }.map(\.path)
            #expect(definitions.isEmpty, "\(service) was reintroduced in \(definitions)")
        }
    }
}
