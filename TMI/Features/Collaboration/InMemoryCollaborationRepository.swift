#if DEBUG
import Foundation

/// Deterministic collaboration data for previews, unit tests, and the
/// `collaboration` UI-test fixture.
@MainActor
final class InMemoryCollaborationRepository: CollaborationRepository {
    private(set) var storedNotes: [TeamNote] = [
        TeamNote(noteID: "n1", category: .family, body: "Mom shared that reading at bedtime is going well.", authorUserID: "colleague", createdAt: "2026-09-20T15:00:00Z", updatedAt: nil, revisionCount: 0, recordVersion: 1, isAuthor: false),
    ]
    private(set) var storedRestricted: [RestrictedRecord] = []
    private(set) var storedTasks: [FollowUpTask] = [
        FollowUpTask(taskID: "t1", title: "Call family about reading log", details: nil, status: .open, assigneeUserID: "me", createdBy: "me", dueDate: "2026-09-18T15:00:00Z", studentID: "student-fixture", planID: nil, meetingID: nil, outcome: nil, completedAt: nil, recordVersion: 1, isOverdue: true),
        FollowUpTask(taskID: "t2", title: "Share calm-down strategies with PE", details: "After Tuesday's meeting", status: .open, assigneeUserID: "me", createdBy: "colleague", dueDate: "2026-10-02T15:00:00Z", studentID: "student-fixture", planID: nil, meetingID: nil, outcome: nil, completedAt: nil, recordVersion: 1, isOverdue: false),
    ]
    private(set) var restrictedReads = 0

    func notes(districtID: String, studentID: String) async throws -> (notes: [TeamNote], canWrite: Bool) {
        (storedNotes, true)
    }

    func saveNote(districtID: String, studentID: String, noteID: String?, category: NoteCategory, body: String, expectedRecordVersion: Int) async throws {
        if let noteID, let index = storedNotes.firstIndex(where: { $0.noteID == noteID }) {
            let note = storedNotes[index]
            guard note.isAuthor else { throw CollaborationError.permissionDenied("Only the author can revise a note.") }
            guard note.recordVersion == expectedRecordVersion else { throw CollaborationError.conflict }
            storedNotes[index] = TeamNote(noteID: note.noteID, category: category, body: body, authorUserID: note.authorUserID, createdAt: note.createdAt, updatedAt: "2026-09-22T16:00:00Z", revisionCount: note.revisionCount + 1, recordVersion: note.recordVersion + 1, isAuthor: true)
        } else {
            storedNotes.insert(TeamNote(noteID: "n\(storedNotes.count + 1)", category: category, body: body, authorUserID: "me", createdAt: "2026-09-22T15:00:00Z", updatedAt: nil, revisionCount: 0, recordVersion: 1, isAuthor: true), at: 0)
        }
    }

    func restrictedRecords(districtID: String, studentID: String) async throws -> [RestrictedRecord] {
        restrictedReads += 1
        return storedRestricted
    }

    func createRestrictedRecord(districtID: String, studentID: String, category: String, body: String) async throws {
        storedRestricted.insert(RestrictedRecord(recordID: "r\(storedRestricted.count + 1)", category: category, body: body, authorUserID: "me", createdAt: "2026-09-22T15:00:00Z"), at: 0)
    }

    func tasks(districtID: String, studentID: String?, includeClosed: Bool) async throws -> [FollowUpTask] {
        storedTasks.filter { (studentID == nil || $0.studentID == studentID) && (includeClosed || $0.status == .open) }
    }

    func createTask(districtID: String, draft: TaskDraft) async throws {
        guard draft.isValid else { throw CollaborationError.rejected("A task needs a title and an owner.") }
        storedTasks.append(FollowUpTask(taskID: "t\(storedTasks.count + 1)", title: draft.title, details: draft.details.isEmpty ? nil : draft.details, status: .open, assigneeUserID: draft.assigneeUserID, createdBy: "me", dueDate: draft.hasDueDate ? ISO8601DateFormatter().string(from: draft.dueDate) : nil, studentID: draft.studentID, planID: draft.planID, meetingID: draft.meetingID, outcome: nil, completedAt: nil, recordVersion: 1, isOverdue: false))
    }

    func updateTask(districtID: String, task: FollowUpTask, status: TaskStatus, outcome: String?, assigneeUserID: String?) async throws {
        guard let index = storedTasks.firstIndex(where: { $0.taskID == task.taskID }) else { throw CollaborationError.rejected("Task was not found.") }
        let current = storedTasks[index]
        guard current.recordVersion == task.recordVersion else { throw CollaborationError.conflict }
        storedTasks[index] = FollowUpTask(taskID: current.taskID, title: current.title, details: current.details, status: status, assigneeUserID: assigneeUserID ?? current.assigneeUserID, createdBy: current.createdBy, dueDate: current.dueDate, studentID: current.studentID, planID: current.planID, meetingID: current.meetingID, outcome: outcome ?? current.outcome, completedAt: status == .open ? nil : "2026-09-22T17:00:00Z", recordVersion: current.recordVersion + 1, isOverdue: status == .open && current.isOverdue)
    }

    func colleagues(districtID: String, studentID: String?) async throws -> [Colleague] {
        [Colleague(userID: "me", displayName: "Jordan Rivera", role: "teacher", isSelf: true),
         Colleague(userID: "colleague", displayName: "Sam Counselor", role: "counselor", isSelf: false)]
    }

    func search(districtID: String, query: String, includeCareers: Bool) async throws -> WorkspaceSearchResults {
        let needle = query.lowercased()
        let students = [SearchHit(id: "student-fixture", title: "Maya Thompson", subtitle: "10", schoolID: "school-fixture")]
            .filter { $0.title.lowercased().contains(needle) }
        let careers = includeCareers
            ? [SearchHit(id: "marine-biologist", title: "Marine Biologist", subtitle: "Science")].filter { $0.title.lowercased().contains(needle) }
            : []
        return WorkspaceSearchResults(students: students, plans: [], resources: [], careers: careers)
    }
}
#endif
