import Foundation

/// Fixed report for previews and UI-test fixtures. Mirrors the server's
/// dictionary so layouts are exercised with real labels and statuses.
@MainActor
final class InMemoryReportingRepository: ReportingRepository {
    private(set) var exports: [ReportExportFormat] = []
    private(set) var attentionRequests = 0

    func report(districtID: String, filter: ReportFilter, refresh: Bool) async throws -> DistrictReportResult {
        Self.result(districtID: districtID, filter: filter)
    }

    func export(districtID: String, filter: ReportFilter, format: ReportExportFormat) async throws -> DistrictReportExport {
        exports.append(format)
        let result = Self.result(districtID: districtID, filter: filter)
        return DistrictReportExport(
            report: result.report,
            definitions: result.definitions,
            minimumSample: result.minimumSample,
            csv: "TMI district report\r\nMetric dictionary version,1\r\n",
            fileName: "tmi-report-\(result.report.scope.from)-to-\(result.report.scope.to).\(format.rawValue)"
        )
    }

    func studentsNeedingAttention(districtID: String, filter: ReportFilter) async throws -> [AttentionStudent] {
        attentionRequests += 1
        return [
            AttentionStudent(studentID: "student-fixture", displayName: "Maya Thompson", schoolID: "school-fixture", grade: "10", reasons: [.noPlan, .overdueFollowUp], overdueFollowUps: 1),
            AttentionStudent(studentID: "student-2", displayName: "Jordan Lee", schoolID: "school-fixture", grade: "9", reasons: [.noSurvey], overdueFollowUps: 0),
        ]
    }

    static let definitions: [MetricDefinition] = [
        MetricDefinition(id: "sites.count", label: "Sites", unit: .count, window: .current, numerator: "Schools or centers in the selected scope.", denominator: nil),
        MetricDefinition(id: "staff.active", label: "Active staff", unit: .count, window: .current, numerator: "Active memberships assigned to a site in scope.", denominator: nil),
        MetricDefinition(id: "students.served", label: "Students served", unit: .count, window: .current, numerator: "Students in scope who are not archived.", denominator: nil),
        MetricDefinition(id: "surveys.coverage", label: "Interest survey coverage", unit: .rate, window: .current, numerator: "Students served with a submitted interest survey.", denominator: "Students served."),
        MetricDefinition(id: "plans.coverage", label: "Students with a plan", unit: .rate, window: .current, numerator: "Students served on an approved or active plan.", denominator: "Students served."),
        MetricDefinition(id: "plans.pendingApproval", label: "Awaiting approval", unit: .count, window: .current, numerator: "Plans waiting for approval.", denominator: nil),
        MetricDefinition(id: "plans.approvalDays", label: "Median days to approval", unit: .days, window: .window, numerator: "Median days from submission to approval.", denominator: nil),
        MetricDefinition(id: "tasks.overdue", label: "Overdue follow-ups", unit: .count, window: .current, numerator: "Open follow-ups past their due date.", denominator: nil),
        MetricDefinition(id: "tasks.onTime", label: "Follow-ups closed on time", unit: .rate, window: .window, numerator: "Follow-ups done on or before their due date.", denominator: "Follow-ups with a due date marked done."),
    ]

    static func result(districtID: String = "district-fixture", filter: ReportFilter = ReportFilter()) -> DistrictReportResult {
        let range = filter.range()
        let metric = { (id: String, value: Double?, numerator: Double?, denominator: Double?, status: ReportMetric.Status) in
            ReportMetric(id: id, value: value, numerator: numerator, denominator: denominator, status: status)
        }
        let sites = [
            ReportSite(
                schoolID: "school-fixture", name: "Lincoln High School", programType: "k12",
                studentsServed: metric("students.served", 124, 124, nil, .ok),
                activePlans: metric("plans.active", 31, 31, nil, .ok),
                planCoverage: metric("plans.coverage", 0.29, 36, 124, .ok),
                surveyCoverage: metric("surveys.coverage", 0.71, 88, 124, .ok),
                overdueTasks: metric("tasks.overdue", 3, 3, nil, .ok)
            ),
            ReportSite(
                schoolID: "school-ec", name: "Sunshine Early Learning", programType: "earlyChildhood",
                studentsServed: metric("students.served", 4, 4, nil, .ok),
                activePlans: metric("plans.active", 1, 1, nil, .ok),
                planCoverage: metric("plans.coverage", nil, nil, nil, .insufficientSample),
                surveyCoverage: metric("surveys.coverage", nil, nil, nil, .insufficientSample),
                overdueTasks: metric("tasks.overdue", 0, 0, nil, .zero)
            ),
        ].filter { filter.schoolID == nil || $0.schoolID == filter.schoolID }
        let report = DistrictReport(
            dictionaryVersion: 1,
            scope: ReportScope(districtID: districtID, schoolIDs: sites.map(\.schoolID), isDistrictWide: filter.schoolID == nil,
                               from: range.from, to: range.to, timeZone: TimeZone.current.identifier, grade: filter.grade, staffUserID: nil),
            computedAt: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-180)),
            isPartial: false,
            includesEarlyChildhood: false,
            metrics: [
                metric("sites.count", Double(sites.count), Double(sites.count), nil, .ok),
                metric("staff.active", 18, 18, nil, .ok),
                metric("students.served", 128, 128, nil, .ok),
                metric("surveys.coverage", 0.69, 88, 128, .ok),
                metric("plans.coverage", 0.28, 36, 128, .ok),
                metric("plans.pendingApproval", 4, 4, nil, .ok),
                metric("plans.approvalDays", 2.5, nil, 9, .ok),
                metric("tasks.overdue", 3, 3, nil, .ok),
                metric("tasks.onTime", nil, nil, nil, .insufficientSample),
            ],
            plansByStatus: ["draft": 6, "pendingApproval": 4, "approved": 5, "active": 32, "completed": 7],
            plansByModel: ["alignYourMind": 14, "chaseYourSpace": 11],
            trend: (0..<8).map { offset in
                let date = Calendar.current.date(byAdding: .weekOfYear, value: offset - 7, to: .now) ?? .now
                return ReportTrendWeek(
                    week: ReportDates.dayFormatter.string(from: date),
                    surveysSubmitted: [4, 7, 5, 9, 12, 8, 10, 6][offset],
                    plansApproved: [1, 0, 2, 3, 1, 2, 4, 2][offset],
                    tasksCompleted: [3, 5, 4, 6, 7, 5, 8, 6][offset],
                    observations: 0
                )
            },
            sites: sites
        )
        return DistrictReportResult(report: report, definitions: definitions, minimumSample: 5)
    }
}
