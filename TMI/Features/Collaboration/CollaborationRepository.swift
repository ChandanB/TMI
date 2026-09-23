import Foundation
@preconcurrency import FirebaseFunctions

nonisolated enum NoteCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case general, academic, socialEmotional, behavior, family, attendance, meetingFollowUp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: "General"
        case .academic: "Academic"
        case .socialEmotional: "Social & emotional"
        case .behavior: "Behavior"
        case .family: "Family"
        case .attendance: "Attendance"
        case .meetingFollowUp: "Meeting follow-up"
        }
    }
}

nonisolated struct TeamNote: Codable, Sendable, Equatable, Identifiable {
    let noteID: String
    let category: NoteCategory
    let body: String
    let authorUserID: String
    let createdAt: String?
    let updatedAt: String?
    let revisionCount: Int
    let recordVersion: Int
    let isAuthor: Bool

    var id: String { noteID }
}

nonisolated struct RestrictedRecord: Codable, Sendable, Equatable, Identifiable {
    let recordID: String
    let category: String
    let body: String
    let authorUserID: String
    let createdAt: String?

    var id: String { recordID }
}

nonisolated enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case open, done, cancelled

    var displayName: String {
        switch self {
        case .open: "Open"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }
}

nonisolated struct FollowUpTask: Codable, Sendable, Equatable, Identifiable {
    let taskID: String
    let title: String
    let details: String?
    let status: TaskStatus
    let assigneeUserID: String
    let createdBy: String
    let dueDate: String?
    let studentID: String?
    let planID: String?
    let meetingID: String?
    let outcome: String?
    let completedAt: String?
    let recordVersion: Int
    let isOverdue: Bool

    var id: String { taskID }
    var due: Date? { dueDate.flatMap(FormDates.parse) }
}

nonisolated struct TaskDraft: Sendable, Equatable {
    var title = ""
    var details = ""
    var assigneeUserID = ""
    var hasDueDate = true
    var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var studentID: String?
    var planID: String?
    var meetingID: String?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !assigneeUserID.isEmpty && title.count <= 300
    }
}

nonisolated struct Colleague: Codable, Sendable, Equatable, Identifiable, Hashable {
    let userID: String
    let displayName: String
    let role: String
    let isSelf: Bool

    var id: String { userID }
}

nonisolated struct SearchHit: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    var schoolID: String?
    var studentID: String?
    var url: String?
}

nonisolated struct WorkspaceSearchResults: Codable, Sendable, Equatable {
    let students: [SearchHit]
    let plans: [SearchHit]
    let resources: [SearchHit]
    let careers: [SearchHit]

    static let empty = WorkspaceSearchResults(students: [], plans: [], resources: [], careers: [])

    var isEmpty: Bool { students.isEmpty && plans.isEmpty && resources.isEmpty && careers.isEmpty }
}

nonisolated enum CollaborationError: LocalizedError, Equatable, Sendable {
    case notDeployed
    case permissionDenied(String)
    case conflict
    case rejected(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notDeployed: "This feature isn't available on this server yet."
        case .permissionDenied(let message): message
        case .conflict: "This changed since you opened it. Refresh and try again."
        case .rejected(let message): message
        case .unavailable: "The server couldn't be reached. Check the connection and try again."
        }
    }

    static func map(_ error: any Error) -> CollaborationError {
        if let error = error as? CollaborationError { return error }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        let message = nsError.localizedDescription
        switch code {
        case .notFound where message.localizedCaseInsensitiveContains("not found"): return .rejected(message)
        case .notFound: return .notDeployed
        case .permissionDenied, .unauthenticated: return .permissionDenied(message)
        case .aborted: return .conflict
        case .invalidArgument, .failedPrecondition, .alreadyExists: return .rejected(message)
        default: return .unavailable
        }
    }
}

@MainActor
protocol CollaborationRepository: AnyObject {
    func notes(districtID: String, studentID: String) async throws -> (notes: [TeamNote], canWrite: Bool)
    func saveNote(districtID: String, studentID: String, noteID: String?, category: NoteCategory, body: String, expectedRecordVersion: Int) async throws
    func restrictedRecords(districtID: String, studentID: String) async throws -> [RestrictedRecord]
    func createRestrictedRecord(districtID: String, studentID: String, category: String, body: String) async throws
    func tasks(districtID: String, studentID: String?, includeClosed: Bool) async throws -> [FollowUpTask]
    func createTask(districtID: String, draft: TaskDraft) async throws
    func updateTask(districtID: String, task: FollowUpTask, status: TaskStatus, outcome: String?, assigneeUserID: String?) async throws
    func colleagues(districtID: String, studentID: String?) async throws -> [Colleague]
    func search(districtID: String, query: String, includeCareers: Bool) async throws -> WorkspaceSearchResults
}

@MainActor
final class FirebaseCollaborationRepository: CollaborationRepository {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func notes(districtID: String, studentID: String) async throws -> (notes: [TeamNote], canWrite: Bool) {
        let response: NotesResponse = try await call("listStudentNotes", StudentRequest(districtID: districtID, studentID: studentID))
        return (response.notes, response.canWrite)
    }

    func saveNote(districtID: String, studentID: String, noteID: String?, category: NoteCategory, body: String, expectedRecordVersion: Int) async throws {
        let _: OperationResponse = try await call("saveStudentNote", SaveNoteRequest(
            districtID: districtID, expectedRecordVersion: expectedRecordVersion, idempotencyKey: Self.operationID(),
            reasonCode: "student-note", studentID: studentID, noteID: noteID, category: category,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    func restrictedRecords(districtID: String, studentID: String) async throws -> [RestrictedRecord] {
        let response: RestrictedResponse = try await call("listRestrictedRecords", RestrictedReadRequest(
            districtID: districtID, expectedRecordVersion: 0, idempotencyKey: Self.operationID(),
            reasonCode: "restricted-record-review", studentID: studentID
        ))
        return response.records
    }

    func createRestrictedRecord(districtID: String, studentID: String, category: String, body: String) async throws {
        let _: OperationResponse = try await call("createRestrictedRecord", RestrictedCreateRequest(
            districtID: districtID, expectedRecordVersion: 0, idempotencyKey: Self.operationID(),
            reasonCode: "restricted-record", studentID: studentID, category: category,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    func tasks(districtID: String, studentID: String?, includeClosed: Bool) async throws -> [FollowUpTask] {
        let response: TasksResponse = try await call("listTasks", TasksRequest(districtID: districtID, studentID: studentID, includeClosed: includeClosed))
        return response.tasks
    }

    func createTask(districtID: String, draft: TaskDraft) async throws {
        let details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OperationResponse = try await call("createTask", CreateTaskRequest(
            districtID: districtID, expectedRecordVersion: 0, idempotencyKey: Self.operationID(),
            reasonCode: "follow-up-task", title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.isEmpty ? nil : details, assigneeUserID: draft.assigneeUserID,
            dueDate: draft.hasDueDate ? ISO8601DateFormatter().string(from: draft.dueDate) : nil,
            studentID: draft.studentID, planID: draft.planID, meetingID: draft.meetingID
        ))
    }

    func updateTask(districtID: String, task: FollowUpTask, status: TaskStatus, outcome: String?, assigneeUserID: String?) async throws {
        let trimmed = outcome?.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OperationResponse = try await call("updateTask", UpdateTaskRequest(
            districtID: districtID, expectedRecordVersion: task.recordVersion, idempotencyKey: Self.operationID(),
            reasonCode: "follow-up-task", taskID: task.taskID, status: status,
            outcome: (trimmed?.isEmpty ?? true) ? nil : trimmed, assigneeUserID: assigneeUserID
        ))
    }

    func colleagues(districtID: String, studentID: String?) async throws -> [Colleague] {
        let response: ColleaguesResponse = try await call("listColleagues", ColleaguesRequest(districtID: districtID, studentID: studentID))
        return response.colleagues
    }

    func search(districtID: String, query: String, includeCareers: Bool) async throws -> WorkspaceSearchResults {
        try await call("searchWorkspace", SearchRequest(districtID: districtID, query: query, includeCareers: includeCareers))
    }

    private static func operationID() -> String { UUID().uuidString }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String, _ request: Request
    ) async throws -> Response {
        do {
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch is DecodingError {
            throw CollaborationError.unavailable
        } catch {
            throw CollaborationError.map(error)
        }
    }
}

private nonisolated struct StudentRequest: Encodable, Sendable { let districtID: String; let studentID: String }
private nonisolated struct NotesResponse: Decodable, Sendable { let notes: [TeamNote]; let canWrite: Bool }
private nonisolated struct RestrictedResponse: Decodable, Sendable { let records: [RestrictedRecord] }
private nonisolated struct TasksResponse: Decodable, Sendable { let tasks: [FollowUpTask] }
private nonisolated struct ColleaguesResponse: Decodable, Sendable { let colleagues: [Colleague] }
private nonisolated struct OperationResponse: Decodable, Sendable { let operationID: String; let recordVersion: Int }
private nonisolated struct TasksRequest: Encodable, Sendable { let districtID: String; let studentID: String?; let includeClosed: Bool }
private nonisolated struct ColleaguesRequest: Encodable, Sendable { let districtID: String; let studentID: String? }
private nonisolated struct SearchRequest: Encodable, Sendable { let districtID: String; let query: String; let includeCareers: Bool }

private nonisolated struct SaveNoteRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
    let noteID: String?
    let category: NoteCategory
    let body: String
}

private nonisolated struct RestrictedReadRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
}

private nonisolated struct RestrictedCreateRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
    let category: String
    let body: String
}

private nonisolated struct CreateTaskRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let title: String
    let details: String?
    let assigneeUserID: String
    let dueDate: String?
    let studentID: String?
    let planID: String?
    let meetingID: String?
}

private nonisolated struct UpdateTaskRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let taskID: String
    let status: TaskStatus
    let outcome: String?
    let assigneeUserID: String?
}
