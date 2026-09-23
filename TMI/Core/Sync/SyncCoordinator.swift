import Foundation
import Network
import Observation
import SwiftUI

/// Replays work saved on this device once a connection is available.
///
/// - Operations for the same record replay in the order they were made; a
///   record whose operation fails waits, while other records continue.
/// - Network failures stay queued. Conflicts, rejections, and revoked access
///   become visible failures that a person can retry or discard; nothing is
///   silently dropped or overwritten.
/// - Queues are kept per account. Signing out or switching accounts stops
///   replay and hides that account's queue without deleting it; work queued
///   in another organization is never sent under the current one.
/// - The server re-checks access on every replay.
@Observable
@MainActor
final class SyncCoordinator {
    typealias Handler = @MainActor (SyncOperation) async throws -> Void

    private let store: any SyncOutboxStore
    private var handlers: [SyncOperation.Kind: Handler] = [:]
    private let classify: @MainActor (any Error) -> SyncReplayError
    private let now: () -> Date

    private(set) var operations: [SyncOperation] = []
    private(set) var isSyncing = false
    private(set) var isOnline = true
    private(set) var lastSyncedAt: Date?
    private(set) var storageError: String?
    private(set) var accountID: String?
    private(set) var districtID: String?

    private var monitor: NWPathMonitor?
    private var syncAgain = false

    init(
        store: any SyncOutboxStore,
        classify: @escaping @MainActor (any Error) -> SyncReplayError = SyncCoordinator.defaultClassification,
        now: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.classify = classify
        self.now = now
    }

    var pendingCount: Int { operations.filter(\.isPending).count }
    var failedCount: Int { operations.count - pendingCount }
    var hasWork: Bool { !operations.isEmpty }

    func register(_ kind: SyncOperation.Kind, handler: @escaping Handler) {
        handlers[kind] = handler
    }

    /// Switches to the signed-in account's queue (nil when signed out).
    func activate(accountID: String?, districtID: String?) {
        guard accountID != self.accountID || districtID != self.districtID else { return }
        self.accountID = accountID
        self.districtID = districtID
        guard let accountID else {
            operations = []
            return
        }
        do {
            operations = try store.load(accountID: accountID)
            storageError = nil
        } catch {
            operations = []
            storageError = "Work saved on this device couldn't be read."
        }
        markOtherOrganizationWork()
    }

    /// Watches connectivity and syncs whenever a connection appears.
    func startMonitoring() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let cameOnline = online && !self.isOnline
                self.isOnline = online
                if cameOnline { await self.syncNow() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "tmi.sync.path"))
        self.monitor = monitor
    }

    // MARK: Queueing

    /// Saves an operation on this device. Form drafts for the same response
    /// replace the older pending draft rather than piling up.
    func enqueue(_ operation: SyncOperation) throws {
        guard operation.accountID == accountID else {
            throw SyncReplayError.rejected("You're signed in to a different account.")
        }
        var next = operations
        if operation.kind == .saveFormDraft,
           let index = next.lastIndex(where: { $0.kind == .saveFormDraft && $0.aggregateKey == operation.aggregateKey && $0.isPending }) {
            var existing = next[index]
            existing.payload = operation.payload
            existing.updatedAt = now()
            next[index] = existing
        } else {
            next.append(operation)
        }
        try persist(next)
    }

    func operations(forAggregate key: String) -> [SyncOperation] {
        operations.filter { $0.aggregateKey == key }
    }

    func operations(withPrefix prefix: String) -> [SyncOperation] {
        operations.filter { $0.aggregateKey.hasPrefix(prefix) }
    }

    func discard(_ id: SyncOperation.ID) {
        try? persist(operations.filter { $0.id != id })
    }

    func retry(_ id: SyncOperation.ID) async {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        var next = operations
        next[index].status = .pending
        try? persist(next)
        await syncNow()
    }

    // MARK: Replay

    func syncNow() async {
        guard !isSyncing else {
            syncAgain = true
            return
        }
        guard accountID != nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            syncAgain = false
            await replayPending()
        } while syncAgain
        if operations.allSatisfy({ !$0.isPending }) { lastSyncedAt = now() }
    }

    private func replayPending() async {
        var blockedAggregates = Set(operations.filter { !$0.isPending }.map(\.aggregateKey))
        let queue = operations.filter(\.isPending).sorted { $0.enqueuedAt < $1.enqueuedAt }
        for operation in queue {
            guard !blockedAggregates.contains(operation.aggregateKey) else { continue }
            guard operation.accountID == accountID else { return }
            guard let handler = handlers[operation.kind] else {
                blockedAggregates.insert(operation.aggregateKey)
                continue
            }
            // Re-read in case the user discarded or edited it meanwhile.
            guard let current = operations.first(where: { $0.id == operation.id }), current.isPending else { continue }
            do {
                try await handler(current)
                try? persist(operations.filter { $0.id != current.id })
            } catch {
                let outcome = (error as? SyncReplayError) ?? classify(error)
                blockedAggregates.insert(current.aggregateKey)
                update(current.id) { item in
                    item.attempts += 1
                    item.lastAttemptAt = now()
                    switch outcome {
                    case .retryable:
                        break
                    case .conflict(let message):
                        item.status = .failed(reason: .conflict, message: message)
                    case .rejected(let message):
                        item.status = .failed(reason: .rejected, message: message)
                    case .accessRevoked(let message):
                        item.status = .failed(reason: .accessRevoked, message: message)
                    }
                }
                if outcome == .retryable {
                    // The connection is probably gone; try again when it returns.
                    return
                }
            }
        }
    }

    // MARK: Helpers

    private func markOtherOrganizationWork() {
        guard let districtID else { return }
        var changed = false
        var next = operations
        for index in next.indices where next[index].districtID != districtID && next[index].isPending {
            next[index].status = .failed(
                reason: .otherOrganization,
                message: "This was saved while you were signed in to another organization, so it won't be sent here."
            )
            changed = true
        }
        if changed { try? persist(next) }
    }

    private func update(_ id: SyncOperation.ID, _ change: (inout SyncOperation) -> Void) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        var next = operations
        change(&next[index])
        try? persist(next)
    }

    private func persist(_ next: [SyncOperation]) throws {
        guard let accountID else { throw SyncReplayError.rejected("Sign in to save work on this device.") }
        do {
            try store.save(next, accountID: accountID)
            operations = next
            storageError = nil
        } catch {
            storageError = "Work couldn't be saved on this device."
            throw error
        }
    }

    /// Maps the app's server errors onto replay outcomes.
    static func defaultClassification(_ error: any Error) -> SyncReplayError {
        if let error = error as? CollaborationError {
            switch error {
            case .unavailable: return .retryable
            case .conflict: return .conflict("Someone changed this while you were offline.")
            case .permissionDenied(let message): return .accessRevoked(message)
            case .rejected(let message): return .rejected(message)
            case .notDeployed: return .rejected(error.localizedDescription)
            }
        }
        if let error = error as? FormResponseError {
            switch error {
            case .unavailable: return .retryable
            case .conflict: return .conflict("These answers changed on another device while you were offline.")
            case .permissionDenied: return .accessRevoked(error.localizedDescription)
            default: return .rejected(error.localizedDescription)
            }
        }
        return .retryable
    }
}

private struct SyncCoordinatorKey: EnvironmentKey {
    static let defaultValue = SyncCoordinator(store: InMemorySyncOutboxStore())
}

extension EnvironmentValues {
    var syncCoordinator: SyncCoordinator {
        get { self[SyncCoordinatorKey.self] }
        set { self[SyncCoordinatorKey.self] = newValue }
    }
}
