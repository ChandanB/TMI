import Charts
import SwiftUI

/// District and site reporting for administrators. Every number comes from the
/// server's metric dictionary; this view only formats and filters.
struct DistrictReportView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.programContext) private var programContext
    @Environment(AppRouter.self) private var router
    var repository: (any ReportingRepository)? = nil
    var memberOverride: MembershipContext? = nil

    @State private var filter = ReportFilter()
    @State private var result: DistrictReportResult?
    @State private var knownSites: [ReportSite] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var attention: [AttentionStudent]?
    @State private var attentionError: String?
    @State private var isLoadingAttention = false
    @State private var exported: ExportedReport?
    @State private var isExporting = false
    @State private var exportError: String?

    private var resolved: any ReportingRepository { repository ?? FirebaseReportingRepository() }
    private var member: MembershipContext? { memberOverride ?? authStateModel.currentMembership }
    private var terminology: Terminology { programContext.shell.terminology }
    private var canExport: Bool { member?.capabilities.contains(.reportExport) == true }
    private var canView: Bool { member?.role == .districtAdministrator || member?.role == .schoolAdministrator }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                if !canView {
                    ContentUnavailableView(
                        "Reports aren't available",
                        systemImage: "lock",
                        description: Text("Reports are available to school and district administrators.")
                    )
                } else {
                    ReportFilterBar(filter: $filter, sites: knownSites, siteNoun: terminology.site, sitesNoun: terminology.sites)
                    if let errorMessage {
                        errorCard(errorMessage)
                    }
                    if let result {
                        content(result)
                    } else if isLoading {
                        ProgressView("Calculating…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
            }
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.md)
            .frame(maxWidth: TMISizing.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .tmiScreenBackground()
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load(refresh: true) } }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Recalculate the report (⌘R)")
                    .disabled(isLoading || !canView)
                if canExport {
                    Menu {
                        ForEach(ReportExportFormat.allCases) { format in
                            Button(format.displayName, systemImage: format.systemImage) {
                                Task { await export(format) }
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(result == nil || isExporting)
                    .accessibilityIdentifier("report.export")
                }
            }
        }
        .task(id: filter) {
            attention = nil
            await load(refresh: false)
        }
        .refreshable { await load(refresh: true) }
        .sheet(item: $exported) { file in
            ExportReadySheet(file: file)
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .overlay {
            if isExporting {
                ProgressView("Preparing export…")
                    .padding(TMISpacing.lg)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: TMIRadius.card, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func content(_ result: DistrictReportResult) -> some View {
        let report = result.report
        freshness(result)
        if report.isPartial {
            Label("This scope is larger than the report limits, so some records weren't counted. Narrow the filters for complete figures.",
                  systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(TMIColors.warningText)
                .padding(TMISpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TMIColors.warningSurface, in: TMIShape.control)
        }
        MetricGrid(result: result)
        ReportTrendChart(trend: report.trend, includesObservations: report.includesEarlyChildhood)
        PlanStatusChart(plansByStatus: report.plansByStatus)
        if report.sites.count > 1 || report.scope.isDistrictWide {
            SiteBreakdown(sites: report.sites, siteNoun: terminology.site)
        }
        attentionSection
        MetricDefinitionsList(result: result)
    }

    private func freshness(_ result: DistrictReportResult) -> some View {
        HStack(spacing: TMISpacing.sm) {
            if isLoading { ProgressView().controlSize(.small) }
            Text(freshnessText(result))
                .font(.caption)
                .foregroundStyle(TMIColors.textSecondary)
        }
    }

    private func freshnessText(_ result: DistrictReportResult) -> String {
        let scope = result.report.scope
        let updated = result.report.computedDate.map { "Updated \($0.formatted(.relative(presentation: .named)))" } ?? "Updated just now"
        return "\(updated) · \(scope.from) to \(scope.to) · Metric dictionary v\(result.report.dictionaryVersion)"
    }

    private var attentionSection: some View {
        ReportCard(title: "\(terminology.learners) needing attention", systemImage: "person.crop.circle.badge.exclamationmark") {
            if let attention {
                if attention.isEmpty {
                    Text("No \(terminology.learners.lowercased()) you can open need attention right now.")
                        .foregroundStyle(TMIColors.textSecondary)
                }
                ForEach(attention) { student in
                    Button {
                        // Admins reach attention students through a server-
                        // filtered list, so the ID-only policy set can't vouch
                        // for them; the record re-authorizes on load. Stay on
                        // this tab so Back returns to the report.
                        try? router.openListed(.student(student.studentID), staysOnCurrentTab: true)
                    } label: {
                        AttentionRow(student: student, siteName: siteName(student.schoolID), gradeText: terminology.gradeDescription(student.grade))
                    }
                    .buttonStyle(.tmiPressable)
                    if student.id != attention.last?.id { TMIDivider() }
                }
            } else {
                Text("Lists the \(terminology.learners.lowercased()) you already have access to who have no survey, no approved plan, an overdue follow-up, or a plan waiting for approval. Opening this list is recorded in the audit log.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                if let attentionError {
                    Label(attentionError, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText)
                }
                Button {
                    Task { await loadAttention() }
                } label: {
                    if isLoadingAttention { ProgressView() } else { Text("Show \(terminology.learners.lowercased())") }
                }
                .buttonStyle(.tmiSecondary)
                .disabled(isLoadingAttention)
                .accessibilityIdentifier("report.showAttention")
            }
        }
    }

    private func siteName(_ schoolID: String) -> String {
        knownSites.first { $0.schoolID == schoolID }?.name ?? programContext.siteName(schoolID)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(TMIColors.errorText)
            Button("Try again") { Task { await load(refresh: false) } }
                .buttonStyle(.bordered)
        }
        .padding(TMISpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TMIColors.errorSurface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
    }

    // MARK: Loading

    private func load(refresh: Bool) async {
        guard canView, let member else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await resolved.report(districtID: member.districtID, filter: filter, refresh: refresh)
            guard !Task.isCancelled else { return }
            result = loaded
            if filter.schoolID == nil { knownSites = loaded.report.sites }
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = CollaborationError.map(error).localizedDescription
        }
    }

    private func loadAttention() async {
        guard let member else { return }
        isLoadingAttention = true
        defer { isLoadingAttention = false }
        do {
            attention = try await resolved.studentsNeedingAttention(districtID: member.districtID, filter: filter)
            attentionError = nil
        } catch {
            attentionError = CollaborationError.map(error).localizedDescription
        }
    }

    private func export(_ format: ReportExportFormat) async {
        guard let member else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let response = try await resolved.export(districtID: member.districtID, filter: filter, format: format)
            let result = DistrictReportResult(report: response.report, definitions: response.definitions, minimumSample: response.minimumSample)
            let url = FileManager.default.temporaryDirectory.appending(path: response.fileName)
            switch format {
            case .csv:
                try Data(response.csv.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            case .pdf:
                try ReportPDFRenderer.render(result: result, organizationName: programContext.organization?.name ?? terminology.organization, to: url)
            }
            exported = ExportedReport(url: url, format: format)
        } catch {
            exportError = (error as? CollaborationError)?.localizedDescription
                ?? CollaborationError.map(error).localizedDescription
        }
    }
}

struct ExportedReport: Identifiable {
    let url: URL
    let format: ReportExportFormat
    var id: URL { url }
}

// MARK: - Filter bar

struct ReportFilterBar: View {
    @Binding var filter: ReportFilter
    let sites: [ReportSite]
    let siteNoun: String
    let sitesNoun: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TMISpacing.md) { controls }
            VStack(alignment: .leading, spacing: TMISpacing.sm) { controls }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if sites.count > 1 {
            Picker(siteNoun, selection: $filter.schoolID) {
                Text("All \(sitesNoun.lowercased())").tag(String?.none)
                ForEach(sites) { site in
                    Text(site.name).tag(Optional(site.schoolID))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("report.site")
        }
        Picker("Window", selection: $filter.window) {
            ForEach(ReportFilter.Window.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("report.window")
        if filter.window == .custom {
            DatePicker("From", selection: $filter.customStart, in: ...filter.customEnd, displayedComponents: .date)
                .fixedSize()
            DatePicker("To", selection: $filter.customEnd, in: filter.customStart...Date.now, displayedComponents: .date)
                .fixedSize()
        }
    }
}

// MARK: - Metrics

struct MetricGrid: View {
    let result: DistrictReportResult

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: TMISpacing.ms)], spacing: TMISpacing.ms) {
            ForEach(result.definitions.filter { result.report.metric($0.id) != nil }) { definition in
                if let metric = result.report.metric(definition.id) {
                    MetricTile(definition: definition, metric: metric, minimumSample: result.minimumSample)
                }
            }
        }
    }
}

struct MetricTile: View {
    let definition: MetricDefinition
    let metric: ReportMetric
    let minimumSample: Int

    private var isWithheld: Bool { metric.status == .insufficientSample }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(definition.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TMIColors.textSecondary)
                .lineLimit(2, reservesSpace: true)
            if isWithheld {
                Label("Withheld", systemImage: "eye.slash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TMIColors.textTertiary)
            } else {
                Text(MetricFormatting.value(metric, unit: definition.unit))
                    .font(.tmiMetric)
                    .foregroundStyle(metric.value == nil ? TMIColors.textTertiary : TMIColors.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(MetricFormatting.caption(metric, definition: definition, minimumSample: minimumSample))
                .font(.caption)
                .foregroundStyle(TMIColors.textTertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmiSurface(padding: 14)
        .accessibilityElement(children: .combine)
        .help(definition.formula)
    }
}

nonisolated enum MetricFormatting {
    static func value(_ metric: ReportMetric, unit: MetricDefinition.Unit) -> String {
        guard let value = metric.value else {
            return metric.status == .insufficientSample ? "Withheld" : "—"
        }
        switch unit {
        case .count: return value.formatted(.number.precision(.fractionLength(0)))
        case .rate: return value.formatted(.percent.precision(.fractionLength(0)))
        case .days: return "\(value.formatted(.number.precision(.fractionLength(0...1)))) days"
        }
    }

    static func caption(_ metric: ReportMetric, definition: MetricDefinition, minimumSample: Int) -> String {
        switch metric.status {
        case .insufficientSample:
            return "Fewer than \(minimumSample) in the group"
        case .noData:
            return "Nothing to measure in this window"
        case .ok, .zero:
            if definition.unit == .rate, let numerator = metric.numerator, let denominator = metric.denominator {
                return "\(Int(numerator)) of \(Int(denominator))"
            }
            return definition.window == .window ? "In this window" : "Right now"
        }
    }

    static func statusName(_ status: String) -> String {
        switch status {
        case "draft": "Draft"
        case "pendingApproval": "Awaiting approval"
        case "changesRequested": "Changes requested"
        case "approved": "Approved"
        case "active": "Active"
        case "paused": "Paused"
        case "completed": "Completed"
        default: status.capitalized
        }
    }
}

// MARK: - Charts

struct ReportTrendChart: View {
    let trend: [ReportTrendWeek]
    let includesObservations: Bool

    @State private var selectedWeek: Date?

    private func selectionCallout(for date: Date) -> some View {
        let calendar = Calendar.current
        let week = trend.first { calendar.isDate($0.date, equalTo: date, toGranularity: .weekOfYear) }
        return VStack(alignment: .leading, spacing: 2) {
            Text("Week of \((week?.date ?? date).formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption.weight(.semibold))
            if let week {
                Text("\(week.surveysSubmitted) surveys · \(week.plansApproved) plans · \(week.tasksCompleted) follow-ups")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(TMIColors.textSecondary)
            }
        }
        .padding(8)
        .background(TMIColors.surfaceRaised, in: TMIShape.chip)
        .overlay { TMIShape.chip.strokeBorder(TMIColors.separator, lineWidth: 1) }
    }

    private struct Point: Identifiable {
        let date: Date
        let series: String
        let count: Int
        var id: String { "\(series)-\(date.timeIntervalSince1970)" }
    }

    private var points: [Point] {
        trend.flatMap { week in
            var points = [
                Point(date: week.date, series: "Surveys submitted", count: week.surveysSubmitted),
                Point(date: week.date, series: "Plans approved", count: week.plansApproved),
                Point(date: week.date, series: "Follow-ups completed", count: week.tasksCompleted),
            ]
            if includesObservations {
                points.append(Point(date: week.date, series: "Observations", count: week.observations))
            }
            return points
        }
    }

    var body: some View {
        ReportCard(title: "Weekly activity", systemImage: "chart.xyaxis.line") {
            if trend.allSatisfy({ $0.surveysSubmitted + $0.plansApproved + $0.tasksCompleted + $0.observations == 0 }) {
                Text("No activity recorded in this window.")
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Week", point.date, unit: .weekOfYear), y: .value("Count", point.count))
                            .foregroundStyle(by: .value("Activity", point.series))
                            .symbol(by: .value("Activity", point.series))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    if let selectedWeek {
                        RuleMark(x: .value("Week", selectedWeek, unit: .weekOfYear))
                            .foregroundStyle(TMIColors.separator)
                            .annotation(position: .top, alignment: .leading, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                selectionCallout(for: selectedWeek)
                            }
                    }
                }
                .chartForegroundStyleScale(range: TMIColors.chartSeries)
                .chartXSelection(value: $selectedWeek)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 240)
                .sensoryFeedback(.selection, trigger: selectedWeek)
            }
        }
    }
}

struct PlanStatusChart: View {
    let plansByStatus: [String: Int]

    private var rows: [(status: String, count: Int)] {
        let order = ["draft", "pendingApproval", "changesRequested", "approved", "active", "paused", "completed"]
        return plansByStatus
            .map { (status: $0.key, count: $0.value) }
            .sorted { (order.firstIndex(of: $0.status) ?? 99) < (order.firstIndex(of: $1.status) ?? 99) }
    }

    var body: some View {
        ReportCard(title: "Plans by status", systemImage: "doc.text") {
            if rows.isEmpty {
                Text("No plans in this scope yet.").foregroundStyle(TMIColors.textSecondary)
            } else {
                Chart(rows, id: \.status) { row in
                    BarMark(x: .value("Plans", row.count), y: .value("Status", MetricFormatting.statusName(row.status)))
                        .foregroundStyle(TMIColors.chartPrimary)
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text("\(row.count)").font(.caption).foregroundStyle(TMIColors.textSecondary)
                        }
                }
                .frame(height: CGFloat(rows.count) * 34 + 20)
            }
        }
    }
}

// MARK: - Sites

struct SiteBreakdown: View {
    let sites: [ReportSite]
    let siteNoun: String

    var body: some View {
        ReportCard(title: "By \(siteNoun.lowercased())", systemImage: "building.2") {
            ForEach(sites) { site in
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    HStack {
                        Text(site.name).font(.headline)
                        if site.programType == "earlyChildhood" {
                            TMIStatusBadge("Early childhood", tone: .info)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TMISpacing.lg) { siteFigures(site) }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) { siteFigures(site) }
                    }
                }
                .padding(.vertical, TMISpacing.xs)
                if site.id != sites.last?.id { TMIDivider() }
            }
        }
    }

    @ViewBuilder
    private func siteFigures(_ site: ReportSite) -> some View {
        figure("Served", MetricFormatting.value(site.studentsServed, unit: .count))
        figure("Active plans", MetricFormatting.value(site.activePlans, unit: .count))
        figure("With a plan", MetricFormatting.value(site.planCoverage, unit: .rate))
        figure("Surveyed", MetricFormatting.value(site.surveyCoverage, unit: .rate))
        figure("Overdue follow-ups", MetricFormatting.value(site.overdueTasks, unit: .count))
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.body.weight(.semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(TMIColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AttentionRow: View {
    let student: AttentionStudent
    let siteName: String
    let gradeText: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(student.displayName).font(.headline).foregroundStyle(TMIColors.textPrimary)
                Text([gradeText, siteName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
                FlowLayout(spacing: 4) {
                    ForEach(student.reasons, id: \.self) { reason in
                        TMIStatusBadge(reason.displayName, tone: .warning)
                    }
                }
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(TMIColors.textSecondary).accessibilityHidden(true)
        }
        .padding(.vertical, TMISpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the record")
    }
}

struct MetricDefinitionsList: View {
    let result: DistrictReportResult

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Text("Rates are withheld when fewer than \(result.minimumSample) people are in the group, so no one can be singled out. “Right now” figures describe the current state; “in this window” figures count activity between the selected dates, in this device's time zone.")
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
                ForEach(result.definitions) { definition in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(definition.label).font(.subheadline.weight(.semibold))
                        Text(definition.formula).font(.caption).foregroundStyle(TMIColors.textSecondary)
                    }
                }
            }
            .padding(.top, TMISpacing.sm)
        } label: {
            Label("About these numbers", systemImage: "info.circle")
        }
        .tmiSurface(padding: TMISpacing.md)
    }
}

struct ReportCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: TMISpacing.sm) {
                TMIIconTile(systemImage, tone: .brand, size: 28)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(TMIColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmiSurface(padding: TMISpacing.md)
    }
}

struct ExportReadySheet: View {
    let file: ExportedReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: TMISpacing.lg) {
                Image(systemName: file.format.systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(TMIColors.aubergine)
                    .accessibilityHidden(true)
                Text(file.url.lastPathComponent).font(.headline)
                Text("The export was recorded in the audit log. Share it only with people allowed to see these figures.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TMIColors.textSecondary)
                ShareLink(item: file.url) {
                    Label("Share or save", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("report.share")
            }
            .padding(TMISpacing.xl)
            .navigationTitle("Report ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tmiSheetStyle()
        .onDisappear { try? FileManager.default.removeItem(at: file.url) }
    }
}
