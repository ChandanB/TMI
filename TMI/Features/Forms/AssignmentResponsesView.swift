import Charts
import SwiftUI

/// Progress on one form assignment across the students the signed-in staff
/// member can open: completion counts, scores for scored forms, per-student
/// status, review, and an audited CSV export of submitted answers.
struct AssignmentResponsesView: View {
    let assignmentID: String
    let fallbackTitle: String
    var repository: (any FormResponseRepository)? = nil
    var memberOverride: MembershipContext? = nil

    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.programContext) private var programContext
    @State private var summary: AssignmentResponses?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var opened: AssignmentResponses.Row?
    @State private var exported: ExportedReport?
    @State private var isExporting = false
    @State private var exportError: String?

    private var resolved: any FormResponseRepository { repository ?? FirebaseFormResponseRepository() }
    private var member: MembershipContext? { memberOverride ?? authStateModel.currentMembership }
    private var canExport: Bool { member?.capabilities.contains(.reportExport) == true }

    var body: some View {
        List {
            if let errorMessage {
                ContentUnavailableView("Responses unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
            if let summary {
                Section { progress(summary) }
                if summary.isScored, summary.rows.contains(where: { $0.score != nil }) {
                    Section("Scores") { scores(summary) }
                }
                Section(programContext.shell.terminology.learners) {
                    ForEach(summary.rows) { row in
                        Button { opened = row } label: { AssignmentResponseRow(row: row) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("assignmentResponses.row.\(row.studentID)")
                    }
                }
            }
        }
        .overlay { if isLoading && summary == nil { ProgressView() } }
        .navigationTitle(summary?.templateName ?? fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canExport {
                ToolbarItem(placement: .primaryAction) {
                    Button("Export responses", systemImage: "square.and.arrow.up") { Task { await export() } }
                        .disabled(isExporting || summary == nil)
                        .accessibilityIdentifier("assignmentResponses.export")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $opened, onDismiss: { Task { await load() } }) { row in
            if let member, let summary {
                FormResponseView(
                    districtID: member.districtID,
                    studentID: row.studentID,
                    studentName: row.displayName,
                    summary: StudentFormSummary(
                        assignmentID: assignmentID, templateID: "", templateName: summary.templateName,
                        instructions: nil, dueDate: summary.dueDate, isActive: true, requiresReview: summary.requiresReview,
                        state: row.state, submittedAt: row.submittedAt, reviewedAt: nil, recordVersion: 0,
                        score: row.score, maxScore: row.maxScore
                    ),
                    repository: resolved
                )
            }
        }
        .sheet(item: $exported) { ExportReadySheet(file: $0) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func progress(_ summary: AssignmentResponses) -> some View {
        let counts = summary.counts
        let done = counts.submitted + counts.reviewed
        return VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(done) of \(counts.assigned)").font(.title2.weight(.semibold).monospacedDigit())
                Text("completed").foregroundStyle(TMIColors.textSecondary)
                Spacer()
                if let due = summary.dueDate.flatMap(FormDates.parse) {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(TMIColors.textSecondary)
                }
            }
            ProgressView(value: Double(done), total: Double(max(counts.assigned, 1)))
                .tint(TMIColors.teal)
            Text([
                "\(counts.notStarted) not started",
                "\(counts.draft) in progress",
                "\(counts.submitted) \(summary.requiresReview ? "awaiting review" : "submitted")",
                "\(counts.reviewed) reviewed",
            ].joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(TMIColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func scores(_ summary: AssignmentResponses) -> some View {
        let scored = summary.rows.filter { $0.score != nil }
        if let average = summary.averageScore {
            LabeledContent("Average score", value: average.formatted(.number.precision(.fractionLength(0...1))))
        }
        let bands = Dictionary(grouping: scored.compactMap(\.band), by: { $0 }).mapValues(\.count)
        if !bands.isEmpty {
            Chart(bands.sorted { $0.key < $1.key }, id: \.key) { band in
                BarMark(x: .value("Students", band.value), y: .value("Band", band.key))
                    .foregroundStyle(TMIColors.aubergine)
                    .annotation(position: .trailing) { Text("\(band.value)").font(.caption) }
            }
            .frame(height: CGFloat(bands.count) * 32 + 16)
            .accessibilityLabel("Students by score band")
        }
    }

    private func load() async {
        guard let member else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await resolved.assignmentResponses(districtID: member.districtID, assignmentID: assignmentID)
            errorMessage = nil
        } catch {
            errorMessage = FormResponseError.map(error).localizedDescription
        }
    }

    private func export() async {
        guard let member else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let result = try await resolved.exportAssignmentResponses(districtID: member.districtID, assignmentID: assignmentID)
            let url = FileManager.default.temporaryDirectory.appending(path: result.fileName)
            try Data(result.csv.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            exported = ExportedReport(url: url, format: .csv)
        } catch {
            exportError = FormResponseError.map(error).localizedDescription
        }
    }
}

struct AssignmentResponseRow: View {
    let row: AssignmentResponses.Row

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName).font(.headline).foregroundStyle(TMIColors.textPrimary)
                Text(detail).font(.caption).foregroundStyle(TMIColors.textSecondary)
            }
            Spacer()
            if let score = row.score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(row.maxScore.map { "\(score.formatted())/\($0.formatted())" } ?? score.formatted())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if let band = row.band {
                        Text(band).font(.caption2).foregroundStyle(TMIColors.textSecondary)
                    }
                }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(TMIColors.textSecondary).accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch row.state {
        case .notStarted: "Not started"
        case .draft: "In progress"
        case .submitted:
            "Submitted" + (row.submittedAt.flatMap(FormDates.parse).map { " \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")
        case .reviewed:
            row.reviewOutcome.flatMap(FormReviewOutcome.init(rawValue:))?.displayName ?? "Reviewed"
        }
    }
}
