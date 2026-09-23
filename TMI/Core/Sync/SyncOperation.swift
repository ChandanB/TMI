import CryptoKit
import Foundation

/// Work saved on this device while offline, replayed when a connection returns.
///
/// Only drafts and additive collaboration records are queued: team notes,
/// follow-up tasks, and form draft answers. Approvals, access changes,
/// submissions, deletions, and exports stay online-only.
nonisolated struct SyncOperation: Codable, Sendable, Identifiable, Equatable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case saveNote
        case createTask
        case updateTask
        case saveFormDraft

        var displayName: String {
            switch self {
            case .saveNote: "Team note"
            case .createTask: "New follow-up task"
            case .updateTask: "Follow-up task update"
            case .saveFormDraft: "Form answers"
            }
        }
    }

    enum Status: Codable, Sendable, Equatable {
        case pending
        /// Needs a person: the server refused it or it conflicts with newer data.
        case failed(reason: FailureReason, message: String)
    }

    enum FailureReason: String, Codable, Sendable {
        case conflict
        case rejected
        case accessRevoked
        case otherOrganization
    }

    /// Also sent as the server idempotency key, so a replay can't apply twice.
    let id: UUID
    let kind: Kind
    let accountID: String
    let districtID: String
    /// Operations on the same record replay in order; others are independent.
    let aggregateKey: String
    /// Plain description for the sync screen, e.g. "Note for Maya Thompson".
    let summary: String
    var payload: Data
    let enqueuedAt: Date
    var updatedAt: Date
    var attempts: Int
    var status: Status
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        kind: Kind,
        accountID: String,
        districtID: String,
        aggregateKey: String,
        summary: String,
        payload: Data,
        enqueuedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.accountID = accountID
        self.districtID = districtID
        self.aggregateKey = aggregateKey
        self.summary = summary
        self.payload = payload
        self.enqueuedAt = enqueuedAt
        self.updatedAt = enqueuedAt
        self.attempts = 0
        self.status = .pending
    }

    var isPending: Bool { status == .pending }

    func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: payload)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }
}

/// How a replay attempt ended, as classified from the server's answer.
nonisolated enum SyncReplayError: Error, Equatable, Sendable {
    /// No connection or a transient server problem: keep it queued.
    case retryable
    case conflict(String)
    case rejected(String)
    case accessRevoked(String)
}

// MARK: - Storage

/// Durable, per-account storage for queued operations.
@MainActor
protocol SyncOutboxStore: AnyObject {
    func load(accountID: String) throws -> [SyncOperation]
    func save(_ operations: [SyncOperation], accountID: String) throws
}

/// Stores each account's queue as a protected file in Application Support.
/// File names are hashed so account IDs never appear on disk.
@MainActor
final class FileSyncOutboxStore: SyncOutboxStore {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appending(path: "TMI", directoryHint: .isDirectory)
            .appending(path: "SyncOutbox", directoryHint: .isDirectory)
    }

    private func fileURL(for accountID: String) -> URL {
        let digest = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(digest.prefix(32)).json")
    }

    func load(accountID: String) throws -> [SyncOperation] {
        let url = fileURL(for: accountID)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode([SyncOperation].self, from: Data(contentsOf: url))
    }

    func save(_ operations: [SyncOperation], accountID: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = fileURL(for: accountID)
        if operations.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try JSONEncoder().encode(operations).write(to: url, options: [.atomic, .completeFileProtection])
    }
}

@MainActor
final class InMemorySyncOutboxStore: SyncOutboxStore {
    private(set) var byAccount: [String: [SyncOperation]] = [:]

    func load(accountID: String) throws -> [SyncOperation] { byAccount[accountID] ?? [] }
    func save(_ operations: [SyncOperation], accountID: String) throws { byAccount[accountID] = operations }
}
