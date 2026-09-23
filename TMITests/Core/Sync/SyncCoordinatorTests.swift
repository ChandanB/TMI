import Foundation
import Testing
@testable import TMI

@MainActor
struct SyncCoordinatorTests {
    private struct Payload: Codable, Equatable { let value: String }

    private func operation(_ value: String, kind: SyncOperation.Kind = .saveNote, key: String = "note:s1", account: String = "u1", district: String = "d1", at offset: TimeInterval = 0) throws -> SyncOperation {
        SyncOperation(kind: kind, accountID: account, districtID: district, aggregateKey: key, summary: value,
                      payload: try SyncOperation.encode(Payload(value: value)), enqueuedAt: Date(timeIntervalSince1970: 1_000 + offset))
    }

    private func coordinator(store: InMemorySyncOutboxStore = InMemorySyncOutboxStore()) -> SyncCoordinator {
        let coordinator = SyncCoordinator(store: store)
        coordinator.activate(accountID: "u1", districtID: "d1")
        return coordinator
    }

    @Test func replaysInOrderAndClearsTheQueue() async throws {
        let sync = coordinator()
        var sent: [String] = []
        sync.register(.saveNote) { sent.append(try $0.decodePayload(Payload.self).value) }
        try sync.enqueue(try operation("first", at: 0))
        try sync.enqueue(try operation("second", at: 1))
        await sync.syncNow()
        #expect(sent == ["first", "second"])
        #expect(!sync.hasWork)
        #expect(sync.lastSyncedAt != nil)
    }

    @Test func networkFailureKeepsWorkQueuedAndStops() async throws {
        let sync = coordinator()
        var attempts = 0
        sync.register(.saveNote) { _ in attempts += 1; throw SyncReplayError.retryable }
        sync.register(.createTask) { _ in attempts += 1 }
        try sync.enqueue(try operation("note", at: 0))
        try sync.enqueue(try operation("task", kind: .createTask, key: "task-new:s1", at: 1))
        await sync.syncNow()
        #expect(attempts == 1)
        #expect(sync.pendingCount == 2)
        #expect(sync.operations.first?.attempts == 1)
    }

    @Test func conflictsBlockOnlyTheirOwnRecord() async throws {
        let sync = coordinator()
        var sent: [String] = []
        sync.register(.saveNote) { operation in
            let value = try operation.decodePayload(Payload.self).value
            if value == "stale" { throw SyncReplayError.conflict("Changed elsewhere.") }
            sent.append(value)
        }
        try sync.enqueue(try operation("stale", key: "note:s1:n1", at: 0))
        try sync.enqueue(try operation("after-stale", key: "note:s1:n1", at: 1))
        try sync.enqueue(try operation("other-record", key: "note:s2", at: 2))
        await sync.syncNow()
        #expect(sent == ["other-record"])
        #expect(sync.failedCount == 1)
        #expect(sync.pendingCount == 1)
        #expect(sync.operations.first?.status == .failed(reason: .conflict, message: "Changed elsewhere."))
    }

    @Test func retryAndDiscardResolveFailures() async throws {
        let sync = coordinator()
        var shouldFail = true
        sync.register(.saveNote) { _ in if shouldFail { throw SyncReplayError.rejected("No.") } }
        let failing = try operation("x")
        try sync.enqueue(failing)
        await sync.syncNow()
        #expect(sync.failedCount == 1)
        shouldFail = false
        await sync.retry(failing.id)
        #expect(!sync.hasWork)

        shouldFail = true
        let another = try operation("y")
        try sync.enqueue(another)
        await sync.syncNow()
        sync.discard(another.id)
        #expect(!sync.hasWork)
    }

    @Test func survivesRestartAndIsolatesAccounts() async throws {
        let store = InMemorySyncOutboxStore()
        let first = coordinator(store: store)
        try first.enqueue(try operation("mine"))

        let restarted = SyncCoordinator(store: store)
        restarted.activate(accountID: "u1", districtID: "d1")
        #expect(restarted.pendingCount == 1)

        restarted.activate(accountID: "u2", districtID: "d1")
        #expect(!restarted.hasWork)
        await restarted.syncNow()
        #expect(store.byAccount["u1"]?.count == 1)
        #expect(throws: SyncReplayError.self) { try restarted.enqueue(try operation("wrong-account")) }

        restarted.activate(accountID: nil, districtID: nil)
        #expect(!restarted.hasWork)
    }

    @Test func workFromAnotherOrganizationIsNeverSent() async throws {
        let store = InMemorySyncOutboxStore()
        let sync = coordinator(store: store)
        try sync.enqueue(try operation("old-district"))
        var sent = 0
        sync.register(.saveNote) { _ in sent += 1 }
        sync.activate(accountID: "u1", districtID: "d2")
        await sync.syncNow()
        #expect(sent == 0)
        if case .failed(let reason, _) = sync.operations.first?.status {
            #expect(reason == .otherOrganization)
        } else {
            Issue.record("Expected a failed operation")
        }
    }

    @Test func formDraftsCoalesceIntoOneOperation() throws {
        let sync = coordinator()
        try sync.enqueue(try operation("v1", kind: .saveFormDraft, key: "form:a1/s1"))
        try sync.enqueue(try operation("v2", kind: .saveFormDraft, key: "form:a1/s1"))
        #expect(sync.operations.count == 1)
        #expect(try sync.operations.first?.decodePayload(Payload.self).value == "v2")
    }

    @Test func performSendsOnlineAndQueuesOffline() async throws {
        let sync = coordinator()
        var online = true
        let payload = Payload(value: "note")
        let sent = try await sync.perform(.saveNote, aggregateKey: "note:s1", summary: "n", districtID: "d1", payload: payload) { _ in
            if !online { throw CollaborationError.unavailable }
        }
        #expect(sent == .sent)
        online = false
        let queued = try await sync.perform(.saveNote, aggregateKey: "note:s1", summary: "n", districtID: "d1", payload: payload) { _ in
            if !online { throw CollaborationError.unavailable }
        }
        #expect(queued == .savedOnDevice)
        #expect(sync.pendingCount == 1)
        await #expect(throws: CollaborationError.self) {
            _ = try await sync.perform(.saveNote, aggregateKey: "note:s9", summary: "n", districtID: "d1", payload: payload) { _ in
                throw CollaborationError.permissionDenied("No access.")
            }
        }
        #expect(sync.pendingCount == 1)
    }

    @Test func fileStorePersistsProtectedQueues() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "sync-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSyncOutboxStore(directory: directory)
        let item = try operation("persisted")
        try store.save([item], accountID: "user@example.org")
        #expect(try store.load(accountID: "user@example.org") == [item])
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        #expect(names.allSatisfy { !$0.contains("example") })
        try store.save([], accountID: "user@example.org")
        #expect(try store.load(accountID: "user@example.org").isEmpty)
    }

    @Test func formSessionQueuesDraftsOfflineAndBlocksSubmitUntilSynced() async throws {
        let repository = OfflineFormRepository()
        let sync = coordinator()
        sync.registerDefaultHandlers(collaboration: { InMemoryCollaborationRepository() }, forms: { repository })
        let session = FormResponseSession(districtID: "d1", assignmentID: "assignment-1", studentID: "s1", repository: repository, autosaveDelay: .milliseconds(1))
        session.sync = sync
        await session.load()
        repository.isOffline = true
        session.setAnswer(.number(4), for: "s0-f0")
        session.setAnswer(.text("Calm"), for: "s0-f2")
        await session.saveDraftNow()
        #expect(session.saveStatus == .savedOnDevice)
        #expect(sync.pendingCount == 1)
        #expect(await session.submit() == false)

        // Back online, a fresh screen shows the answers saved on this device
        // before they have been sent, and submitting sends them first.
        repository.isOffline = false
        let reopened = FormResponseSession(districtID: "d1", assignmentID: "assignment-1", studentID: "s1", repository: repository)
        reopened.sync = sync
        await reopened.load()
        #expect(reopened.answer(for: "s0-f2") == .text("Calm"))
        #expect(reopened.saveStatus == .savedOnDevice)
        #expect(await reopened.submit())
        #expect(!sync.hasWork)
        #expect(repository.stored["assignment-1"]?.state == .submitted)
    }
}

/// Wraps the in-memory form repository with a switchable network failure.
@MainActor
private final class OfflineFormRepository: FormResponseRepository {
    private let base = InMemoryFormResponseRepository()
    var isOffline = false
    var stored: [String: InMemoryFormResponseRepository.Stored] { base.stored }

    private func check() throws { if isOffline { throw FormResponseError.unavailable } }

    func forms(districtID: String, studentID: String) async throws -> [StudentFormSummary] { try check(); return try await base.forms(districtID: districtID, studentID: studentID) }
    func load(districtID: String, assignmentID: String, studentID: String) async throws -> FormResponseDocument { try check(); return try await base.load(districtID: districtID, assignmentID: assignmentID, studentID: studentID) }
    func saveDraft(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], expectedRecordVersion: Int) async throws -> Int { try check(); return try await base.saveDraft(districtID: districtID, assignmentID: assignmentID, studentID: studentID, answers: answers, expectedRecordVersion: expectedRecordVersion) }
    func submit(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], respondentType: FormRespondentType, expectedRecordVersion: Int, operationID: String) async throws -> Int { try check(); return try await base.submit(districtID: districtID, assignmentID: assignmentID, studentID: studentID, answers: answers, respondentType: respondentType, expectedRecordVersion: expectedRecordVersion, operationID: operationID) }
    func review(districtID: String, assignmentID: String, studentID: String, outcome: FormReviewOutcome, comment: String?, expectedRecordVersion: Int, operationID: String) async throws -> Int { try check(); return try await base.review(districtID: districtID, assignmentID: assignmentID, studentID: studentID, outcome: outcome, comment: comment, expectedRecordVersion: expectedRecordVersion, operationID: operationID) }
    func assignmentResponses(districtID: String, assignmentID: String) async throws -> AssignmentResponses { try check(); return try await base.assignmentResponses(districtID: districtID, assignmentID: assignmentID) }
    func exportAssignmentResponses(districtID: String, assignmentID: String) async throws -> AssignmentResponsesExport { try check(); return try await base.exportAssignmentResponses(districtID: districtID, assignmentID: assignmentID) }
}
