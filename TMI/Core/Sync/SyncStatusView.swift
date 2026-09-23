import SwiftUI

/// Everything saved on this device that hasn't reached the server yet, with
/// retry and discard for anything the server turned down.
struct SyncStatusView: View {
    @Environment(\.syncCoordinator) private var sync
    @State private var confirmingDiscard: SyncOperation?

    var body: some View {
        List {
            Section {
                LabeledContent("Connection", value: sync.isOnline ? "Online" : "Offline")
                LabeledContent("Waiting to send", value: "\(sync.pendingCount)")
                LabeledContent("Needs attention", value: "\(sync.failedCount)")
                if let last = sync.lastSyncedAt {
                    LabeledContent("Last synced", value: last.formatted(.relative(presentation: .named)))
                }
                if let error = sync.storageError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText)
                }
            } footer: {
                Text("Notes, follow-up tasks, and form answers you save offline are kept on this device and sent automatically when you reconnect. Approvals, submissions, and exports need a connection.")
            }

            if sync.operations.isEmpty {
                ContentUnavailableView("Everything is synced", systemImage: "checkmark.icloud")
            } else {
                Section("Saved on this device") {
                    ForEach(sync.operations) { operation in
                        SyncOperationRow(operation: operation)
                            .swipeActions {
                                Button("Discard", role: .destructive) { confirmingDiscard = operation }
                            }
                            .contextMenu {
                                if !operation.isPending {
                                    Button("Try again", systemImage: "arrow.clockwise") { Task { await sync.retry(operation.id) } }
                                }
                                Button("Discard", systemImage: "trash", role: .destructive) { confirmingDiscard = operation }
                            }
                    }
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Sync now", systemImage: "arrow.triangle.2.circlepath") { Task { await sync.syncNow() } }
                    .disabled(sync.isSyncing || sync.pendingCount == 0)
            }
        }
        .refreshable { await sync.syncNow() }
        .confirmationDialog(
            "Discard this change?",
            isPresented: Binding(get: { confirmingDiscard != nil }, set: { if !$0 { confirmingDiscard = nil } }),
            presenting: confirmingDiscard
        ) { operation in
            Button("Discard", role: .destructive) { sync.discard(operation.id) }
        } message: { _ in
            Text("It was never sent, so it will be lost.")
        }
    }
}

struct SyncOperationRow: View {
    let operation: SyncOperation

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
            HStack {
                Text(operation.kind.displayName).font(.headline)
                Spacer()
                statusBadge
            }
            Text(operation.summary).font(.subheadline).foregroundStyle(TMIColors.textSecondary)
            if case .failed(_, let message) = operation.status {
                Text(message).font(.caption).foregroundStyle(TMIColors.errorText)
            }
            Text("Saved \(operation.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(TMIColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if operation.isPending {
            Label("Waiting", systemImage: "clock").font(.caption).foregroundStyle(TMIColors.textSecondary)
        } else {
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(TMIColors.warningText)
        }
    }
}

/// Inline list of queued work for one place in the app (a student's notes, say).
struct PendingSyncList: View {
    let prefixes: [String]
    @Environment(\.syncCoordinator) private var sync

    private var items: [SyncOperation] {
        sync.operations.filter { operation in prefixes.contains { operation.aggregateKey.hasPrefix($0) } }
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: TMISpacing.xs) {
                ForEach(items) { operation in
                    HStack(alignment: .top, spacing: TMISpacing.sm) {
                        Image(systemName: operation.isPending ? "icloud.slash" : "exclamationmark.triangle.fill")
                            .foregroundStyle(TMIColors.warningText)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(operation.summary).font(.subheadline)
                            if case .failed(_, let message) = operation.status {
                                Text(message).font(.caption).foregroundStyle(TMIColors.errorText)
                            } else {
                                Text("Saved on this device — sends when you're back online.")
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(TMISpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TMIColors.warningSurface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
            .accessibilityIdentifier("pendingSync")
        }
    }
}

/// Toolbar indicator shown only while something is waiting or needs attention.
struct SyncStatusButton: View {
    @Environment(\.syncCoordinator) private var sync
    let action: () -> Void

    var body: some View {
        if sync.hasWork {
            Button(action: action) {
                Label(
                    sync.failedCount > 0 ? "\(sync.failedCount) not synced" : "\(sync.pendingCount) waiting to sync",
                    systemImage: sync.failedCount > 0 ? "exclamationmark.icloud" : "icloud.slash"
                )
            }
            .foregroundStyle(sync.failedCount > 0 ? TMIColors.errorText : TMIColors.warningText)
            .accessibilityIdentifier("syncStatus.button")
        }
    }
}
