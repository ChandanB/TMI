import Foundation
@preconcurrency import FirebaseFunctions

// MARK: - Models

/// Server-computed metric value. `value` is nil when the server withheld it
/// (fewer than the minimum sample) or had nothing to measure.
nonisolated struct ReportMetric: Codable, Equatable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable {
        case ok
        case zero
        case insufficientSample
        case noData
    }

    let id: String
    let value: Double?
    let numerator: Double?
    let denominator: Double?
    let status: Status
}

nonisolated struct MetricDefinition: Codable, Equatable, Sendable, Identifiable {
    enum Unit: String, Codable, Sendable { case count, rate, days }
    enum Window: String, Codable, Sendable { case current, window }

    let id: String
    let label: String
    let unit: Unit
    let window: Window
    let numerator: String
    let denominator: String?
    var earlyChildhoodOnly: Bool? = nil

    /// Plain-language formula shown under "About these numbers".
    var formula: String {
        guard let denominator else { return numerator }
        return "\(numerator) ÷ \(denominator)"
    }
}

nonisolated struct ReportScope: Codable, Equatable, Sendable {
    let districtID: String
    let schoolIDs: [String]
    let isDistrictWide: Bool
    let from: String
    let to: String
    let timeZone: String
    let grade: String?
    let staffUserID: String?
}

nonisolated struct ReportSite: Codable, Equatable, Sendable, Identifiable {
    let schoolID: String
    let name: String
    let programType: String
    let studentsServed: ReportMetric
    let activePlans: ReportMetric
    let planCoverage: ReportMetric
    let surveyCoverage: ReportMetric
    let overdueTasks: ReportMetric

    var id: String { schoolID }
}

nonisolated struct ReportTrendWeek: Codable, Equatable, Sendable, Identifiable {
    let week: String
    let surveysSubmitted: Int
    let plansApproved: Int
    let tasksCompleted: Int
    let observations: Int

    var id: String { week }
    var date: Date { ReportDates.dayFormatter.date(from: week) ?? .distantPast }
}

nonisolated struct DistrictReport: Codable, Equatable, Sendable {
    let dictionaryVersion: Int
    let scope: ReportScope
    let computedAt: String
    let isPartial: Bool
    let includesEarlyChildhood: Bool
    let metrics: [ReportMetric]
    let plansByStatus: [String: Int]
    let plansByModel: [String: Int]
    let trend: [ReportTrendWeek]
    let sites: [ReportSite]

    func metric(_ id: String) -> ReportMetric? { metrics.first { $0.id == id } }
    var computedDate: Date? { FormDates.parse(computedAt) }
}

/// A report plus the dictionary that defines every number in it.
nonisolated struct DistrictReportResult: Codable, Equatable, Sendable {
    let report: DistrictReport
    let definitions: [MetricDefinition]
    let minimumSample: Int

    func definition(_ id: String) -> MetricDefinition? { definitions.first { $0.id == id } }
}

nonisolated struct DistrictReportExport: Decodable, Sendable {
    let report: DistrictReport
    let definitions: [MetricDefinition]
    let minimumSample: Int
    let csv: String
    let fileName: String
}

nonisolated struct AttentionStudent: Codable, Equatable, Sendable, Identifiable {
    enum Reason: String, Codable, Sendable, CaseIterable {
        case noSurvey
        case noPlan
        case overdueFollowUp
        case approvalWaiting

        var displayName: String {
            switch self {
            case .noSurvey: "No interest survey"
            case .noPlan: "No approved plan"
            case .overdueFollowUp: "Overdue follow-up"
            case .approvalWaiting: "Plan waiting over 7 days"
            }
        }
    }

    let studentID: String
    let displayName: String
    let schoolID: String
    let grade: String
    let reasons: [Reason]
    let overdueFollowUps: Int

    var id: String { studentID }
}

/// Filters the report is computed for. Dates are local calendar days.
nonisolated struct ReportFilter: Equatable, Sendable {
    enum Window: String, CaseIterable, Identifiable, Sendable {
        case last30 = "Last 30 days"
        case last90 = "Last 90 days"
        case schoolYear = "School year"
        case custom = "Custom"

        var id: String { rawValue }
    }

    var schoolID: String?
    var grade: String?
    var window: Window = .last90
    var customStart = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    var customEnd = Date.now

    /// The inclusive local-date range for `window`, relative to `today`.
    func range(today: Date = .now, calendar: Calendar = .current) -> (from: String, to: String) {
        let end = window == .custom ? customEnd : today
        let start: Date
        switch window {
        case .last30:
            start = calendar.date(byAdding: .day, value: -29, to: end) ?? end
        case .last90:
            start = calendar.date(byAdding: .day, value: -89, to: end) ?? end
        case .schoolYear:
            // School years start August 1.
            let year = calendar.component(.year, from: end)
            let month = calendar.component(.month, from: end)
            start = calendar.date(from: DateComponents(year: month >= 8 ? year : year - 1, month: 8, day: 1)) ?? end
        case .custom:
            start = min(customStart, customEnd)
        }
        let formatter = ReportDates.day(calendar: calendar)
        return (formatter.string(from: start), formatter.string(from: end))
    }
}

nonisolated enum ReportDates {
    static let dayFormatter = day(calendar: .current)

    static func day(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

// MARK: - Repository

@MainActor
protocol ReportingRepository: AnyObject {
    func report(districtID: String, filter: ReportFilter, refresh: Bool) async throws -> DistrictReportResult
    func export(districtID: String, filter: ReportFilter, format: ReportExportFormat) async throws -> DistrictReportExport
    func studentsNeedingAttention(districtID: String, filter: ReportFilter) async throws -> [AttentionStudent]
}

nonisolated enum ReportExportFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }
    var displayName: String { self == .csv ? "Spreadsheet (CSV)" : "Board-ready PDF" }
    var systemImage: String { self == .csv ? "tablecells" : "doc.richtext" }
}

@MainActor
final class FirebaseReportingRepository: ReportingRepository {
    // Resolved on use: `Functions.functions()` traps without a configured
    // FirebaseApp (UI-test fixtures and previews construct this type).
    private let makeFunctions: @Sendable () -> Functions
    private var functions: Functions { makeFunctions() }
    private let timeZone: TimeZone

    init(functions: @autoclosure @escaping @Sendable () -> Functions = Functions.functions(region: "us-central1"), timeZone: TimeZone = .current) {
        self.makeFunctions = functions
        self.timeZone = timeZone
    }

    func report(districtID: String, filter: ReportFilter, refresh: Bool) async throws -> DistrictReportResult {
        try await call("getDistrictReport", request(districtID: districtID, filter: filter, refresh: refresh))
    }

    func export(districtID: String, filter: ReportFilter, format: ReportExportFormat) async throws -> DistrictReportExport {
        try await call("exportDistrictReport", request(districtID: districtID, filter: filter, format: format))
    }

    func studentsNeedingAttention(districtID: String, filter: ReportFilter) async throws -> [AttentionStudent] {
        let response: AttentionResponse = try await call(
            "listStudentsNeedingAttention",
            request(districtID: districtID, filter: filter, reasonCode: "reportDrilldown")
        )
        return response.students
    }

    private func request(
        districtID: String,
        filter: ReportFilter,
        refresh: Bool? = nil,
        format: ReportExportFormat? = nil,
        reasonCode: String? = nil
    ) -> ReportRequest {
        let range = filter.range()
        return ReportRequest(
            districtID: districtID,
            schoolID: filter.schoolID,
            from: range.from,
            to: range.to,
            timeZone: timeZone.identifier,
            grade: filter.grade,
            refresh: refresh,
            format: format,
            reasonCode: reasonCode
        )
    }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String, _ request: Request
    ) async throws -> Response {
        do {
            try FirebaseSession.requireApp()
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch is DecodingError {
            throw CollaborationError.unavailable
        } catch {
            throw CollaborationError.map(error)
        }
    }
}

private nonisolated struct ReportRequest: Encodable, Sendable {
    let districtID: String
    let schoolID: String?
    let from: String
    let to: String
    let timeZone: String
    let grade: String?
    let refresh: Bool?
    let format: ReportExportFormat?
    let reasonCode: String?

    // Omit absent optionals: the callable rejects unexpected nulls for flags.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(districtID, forKey: .districtID)
        try container.encodeIfPresent(schoolID, forKey: .schoolID)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encodeIfPresent(grade, forKey: .grade)
        try container.encodeIfPresent(refresh, forKey: .refresh)
        try container.encodeIfPresent(format, forKey: .format)
        try container.encodeIfPresent(reasonCode, forKey: .reasonCode)
    }

    private enum CodingKeys: String, CodingKey {
        case districtID, schoolID, from, to, timeZone, grade, refresh, format, reasonCode
    }
}

private nonisolated struct AttentionResponse: Decodable, Sendable { let students: [AttentionStudent] }
