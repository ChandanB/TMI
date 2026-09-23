import Foundation

// MARK: - Payloads

nonisolated struct NoteSyncPayload: Codable, Sendable, Equatable {
    let districtID: String
    let studentID: String
    let noteID: String?
    let category: NoteCategory
    let body: String
    let expectedRecordVersion: Int
}

nonisolated struct CreateTaskSyncPayload: Codable, Sendable, Equatable {
    let districtID: String
    let draft: TaskDraft
}

nonisolated struct UpdateTaskSyncPayload: Codable, Sendable, Equatable {
    let districtID: String
    let task: FollowUpTask
    let status: TaskStatus
    let outcome: String?
    let assigneeUserID: String?
}

nonisolated struct FormDraftSyncPayload: Codable, Sendable, Equatable {
    let districtID: String
    let assignmentID: String
    let studentID: String
    let answers: [String: FormAnswerValue]
    let expectedRecordVersion: Int
}

/// Aggregate keys: operations on the same record replay in order.
nonisolated enum SyncAggregate {
    static func notes(studentID: String) -> String { "note:\(studentID)" }
    static func note(studentID: String, noteID: String?) -> String {
        noteID.map { "note:\(studentID):\($0)" } ?? "note:\(studentID)"
    }
    static func task(_ taskID: String) -> String { "task:\(taskID)" }
    static func newTask(studentID: String?) -> String { "task-new:\(studentID ?? "none")" }
    static func formDraft(assignmentID: String, studentID: String) -> String { "form:\(assignmentID)/\(studentID)" }
}

nonisolated enum SyncedWriteResult: Equatable, Sendable {
    /// The server accepted it now.
    case sent
    /// Saved on this device; it will be sent when a connection returns.
    case savedOnDevice
}

// MARK: - Registration and offline-aware writes

extension SyncCoordinator {
    /// Connects each queued kind to the repository call that replays it.
    func registerDefaultHandlers(
        collaboration: @escaping @MainActor () -> any CollaborationRepository,
        forms: @escaping @MainActor () -> any FormResponseRepository
    ) {
        register(.saveNote) { operation in
            let payload = try operation.decodePayload(NoteSyncPayload.self)
            try await collaboration().saveNote(
                districtID: payload.districtID, studentID: payload.studentID, noteID: payload.noteID,
                category: payload.category, body: payload.body,
                expectedRecordVersion: payload.expectedRecordVersion, operationID: operation.id.uuidString
            )
        }
        register(.createTask) { operation in
            let payload = try operation.decodePayload(CreateTaskSyncPayload.self)
            try await collaboration().createTask(districtID: payload.districtID, draft: payload.draft, operationID: operation.id.uuidString)
        }
        register(.updateTask) { operation in
            let payload = try operation.decodePayload(UpdateTaskSyncPayload.self)
            try await collaboration().updateTask(
                districtID: payload.districtID, task: payload.task, status: payload.status,
                outcome: payload.outcome, assigneeUserID: payload.assigneeUserID, operationID: operation.id.uuidString
            )
        }
        register(.saveFormDraft) { operation in
            let payload = try operation.decodePayload(FormDraftSyncPayload.self)
            let repository = forms()
            do {
                _ = try await repository.saveDraft(
                    districtID: payload.districtID, assignmentID: payload.assignmentID, studentID: payload.studentID,
                    answers: payload.answers, expectedRecordVersion: payload.expectedRecordVersion
                )
            } catch FormResponseError.conflict {
                // A lost response to an earlier attempt that did save looks like a
                // conflict; if the server already has exactly these answers, it's done.
                let current = try await repository.load(
                    districtID: payload.districtID, assignmentID: payload.assignmentID, studentID: payload.studentID
                )
                guard current.answers == payload.answers else { throw FormResponseError.conflict }
            }
        }
    }

    /// Sends now when possible; when the connection is the only problem,
    /// saves the operation on this device to replay later. Operations for a
    /// record with queued work wait their turn instead of jumping ahead.
    func perform<Payload: Encodable>(
        _ kind: SyncOperation.Kind,
        aggregateKey: String,
        summary: String,
        districtID: String,
        payload: Payload,
        operationID: UUID = UUID(),
        send: @MainActor (String) async throws -> Void
    ) async throws -> SyncedWriteResult {
        guard let accountID else {
            try await send(operationID.uuidString)
            return .sent
        }
        let operation = SyncOperation(
            id: operationID, kind: kind, accountID: accountID, districtID: districtID,
            aggregateKey: aggregateKey, summary: summary, payload: try SyncOperation.encode(payload)
        )
        if !operations(forAggregate: aggregateKey).isEmpty {
            try enqueue(operation)
            Task { await syncNow() }
            return .savedOnDevice
        }
        do {
            try await send(operationID.uuidString)
            return .sent
        } catch {
            guard SyncCoordinator.defaultClassification(error) == .retryable else { throw error }
            try enqueue(operation)
            return .savedOnDevice
        }
    }
}

extension SyncCoordinator {
    func updateTask(
        _ task: FollowUpTask,
        districtID: String,
        status: TaskStatus,
        outcome: String?,
        repository: any CollaborationRepository
    ) async throws -> SyncedWriteResult {
        let payload = UpdateTaskSyncPayload(districtID: districtID, task: task, status: status, outcome: outcome, assigneeUserID: nil)
        return try await perform(
            .updateTask,
            aggregateKey: SyncAggregate.task(task.taskID),
            summary: "\(status.displayName): \(task.title.prefix(60))",
            districtID: districtID,
            payload: payload
        ) { operationID in
            try await repository.updateTask(
                districtID: payload.districtID, task: payload.task, status: payload.status,
                outcome: payload.outcome, assigneeUserID: payload.assigneeUserID, operationID: operationID
            )
        }
    }
}
