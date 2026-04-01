//
//  AuditLogListView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  View for displaying audit logs to administrators
//

import SwiftUI

struct AuditLogListView: View {
    let districtId: String

    @Environment(\.authStateModel) private var authState

    @State private var logs: [AuditLog] = []
    @State private var statistics: AuditLogStatistics?
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedAction: AuditLog.AuditAction?
    @State private var selectedEntityType: AuditLog.EntityType?
    @State private var selectedSeverity: AuditLog.AuditSeverity?
    @State private var showingExport = false
    @State private var exportURL: URL?

    private let auditLogService = AuditLogService.shared

    var filteredLogs: [AuditLog] {
        var result = logs

        if !searchText.isEmpty {
            result = result.filter { log in
                log.action.displayName.localizedCaseInsensitiveContains(searchText) ||
                log.entityType.displayName.localizedCaseInsensitiveContains(searchText) ||
                (log.userName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                log.entityId.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let selectedAction = selectedAction {
            result = result.filter { $0.action == selectedAction }
        }

        if let selectedEntityType = selectedEntityType {
            result = result.filter { $0.entityType == selectedEntityType }
        }

        if let selectedSeverity = selectedSeverity {
            result = result.filter { $0.action.severity == selectedSeverity }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Filters
            filtersSection

            // Statistics
            if let statistics = statistics {
                statisticsSection(statistics)
            }

            // Logs list
            if isLoading {
                loadingView
            } else if filteredLogs.isEmpty {
                emptyView
            } else {
                logsList
            }
        }
        .background(TMIBackgroundView(variant: .default).ignoresSafeArea())
        .navigationTitle("Audit Logs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { Task { await exportLogs() } }) {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { Task { await loadLogs() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadLogs()
            await loadStatistics()
        }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL {
                ShareSheet(url: url.path())
                    .tmiSheetStyle()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))

            TextField("Search logs...", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Filters

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Severity filter
                Menu {
                    Button("All Severities") { selectedSeverity = nil }
                    Divider()
                    ForEach([AuditLog.AuditSeverity.high, .medium, .low], id: \.self) { severity in
                        Button(severity.rawValue.capitalized) {
                            selectedSeverity = severity
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedSeverity?.rawValue.capitalized ?? "Severity",
                        icon: "exclamationmark.triangle.fill",
                        isSelected: selectedSeverity != nil
                    )
                }

                // Action filter
                Menu {
                    Button("All Actions") { selectedAction = nil }
                    Divider()
                    ForEach(AuditLog.AuditAction.allCases.prefix(10), id: \.self) { action in
                        Button(action.displayName) {
                            selectedAction = action
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedAction?.displayName ?? "Action",
                        icon: "bolt.fill",
                        isSelected: selectedAction != nil
                    )
                }

                // Entity type filter
                Menu {
                    Button("All Entities") { selectedEntityType = nil }
                    Divider()
                    ForEach(AuditLog.EntityType.allCases, id: \.self) { entityType in
                        Button(entityType.displayName) {
                            selectedEntityType = entityType
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedEntityType?.displayName ?? "Entity",
                        icon: "folder.fill",
                        isSelected: selectedEntityType != nil
                    )
                }

                // Clear filters
                if selectedAction != nil || selectedEntityType != nil || selectedSeverity != nil {
                    Button(action: clearFilters) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Statistics

    private func statisticsSection(_ stats: AuditLogStatistics) -> some View {
        TMIGlassCard(style: .elevated) {
            VStack(spacing: 12) {
                HStack {
                    Text("Last \(stats.periodDays) Days")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(stats.totalLogs) total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                HStack(spacing: 20) {
                    StatBox(
                        title: "High",
                        value: "\(stats.highSeverityCount)",
                        color: Color(hex: AuditLog.AuditSeverity.high.color)
                    )

                    Divider().frame(height: 40)

                    StatBox(
                        title: "Medium",
                        value: "\(stats.mediumSeverityCount)",
                        color: Color(hex: AuditLog.AuditSeverity.medium.color)
                    )

                    Divider().frame(height: 40)

                    StatBox(
                        title: "Low",
                        value: "\(stats.lowSeverityCount)",
                        color: Color(hex: AuditLog.AuditSeverity.low.color)
                    )
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Logs List

    private var logsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLogs) { log in
                    AuditLogCard(log: log)
                }
            }
            .padding()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))

            Text(searchText.isEmpty ? "No audit logs" : "No results")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(searchText.isEmpty ? "Audit logs will appear here" : "Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading audit logs...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Actions

    @MainActor
    private func loadLogs() async {
        isLoading = true

        do {
            logs = try await auditLogService.fetchLogs(districtId: districtId, limit: 500)
        } catch {
            print("[AuditLogListView] Failed to load logs: \(error)")
        }

        isLoading = false
    }

    @MainActor
    private func loadStatistics() async {
        do {
            statistics = try await auditLogService.getStatistics(districtId: districtId)
        } catch {
            print("[AuditLogListView] Failed to load statistics: \(error)")
        }
    }

    private func clearFilters() {
        selectedAction = nil
        selectedEntityType = nil
        selectedSeverity = nil
    }

    @MainActor
    private func exportLogs() async {
        let csv = auditLogService.exportToCSV(logs: filteredLogs)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_logs_\(Date().ISO8601Format()).csv")

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingExport = true
        } catch {
            print("[AuditLogListView] Failed to export: \(error)")
        }
    }
}

// MARK: - Supporting Views

private struct AuditLogCard: View {
    let log: AuditLog

    var body: some View {
        TMIGlassCard(style: .default) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: log.action.severity.color).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: log.action.icon)
                        .foregroundColor(Color(hex: log.action.severity.color))
                        .font(.caption)
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(log.action.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(log.entityType.displayName)
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))

                    if let userName = log.userName {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                            Text(userName)
                            if let role = log.userRole {
                                Text("•")
                                Text(role)
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    }

                    Text(log.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Severity badge
                Text(log.action.severity.rawValue.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: log.action.severity.color))
                    .cornerRadius(8)
            }
            .padding()
        }
    }
}

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.bold())
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.cyan : Color.white.opacity(0.1))
        .cornerRadius(20)
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AuditLogListView(districtId: "sample-district")
    }
}
