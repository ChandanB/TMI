#if DEBUG
import Foundation
import Testing
@testable import TMI

@Suite("Collaboration")
@MainActor
struct CollaborationTests {
    @Test("Tasks deep link routes to My Tasks and needs a signed-in role")
    func tasksDeepLink() throws {
        #expect(DeepLinkRouter.route(for: try #require(URL(string: "tmi://tasks"))) == .tasks)
        #expect(DeepLinkRouter.route(for: try #require(URL(string: "tmi://tasks/extra"))) == nil)
        #expect(AppRoute.tasks.tab == nil)
        let router = AppRouter()
        #expect(throws: NavigationError.self) { try router.open(.tasks) }
    }

    @Test("A task needs a title and an owner")
    func taskDraftValidation() {
        var draft = TaskDraft()
        #expect(!draft.isValid)
        draft.title = "Call family"
        #expect(!draft.isValid)
        draft.assigneeUserID = "me"
        #expect(draft.isValid)
        draft.title = "   "
        #expect(!draft.isValid)
    }

    @Test("Notes: only the author revises, with a version check")
    func noteRevisions() async throws {
        let repository = InMemoryCollaborationRepository()
        let colleagueNote = try #require(repository.storedNotes.first)
        await #expect(throws: CollaborationError.self) {
            try await repository.saveNote(districtID: "d", studentID: "s", noteID: colleagueNote.noteID, category: .general, body: "x", expectedRecordVersion: 1)
        }
        try await repository.saveNote(districtID: "d", studentID: "s", noteID: nil, category: .academic, body: "Mine", expectedRecordVersion: 0)
        let mine = try #require(repository.storedNotes.first { $0.isAuthor })
        await #expect(throws: CollaborationError.conflict) {
            try await repository.saveNote(districtID: "d", studentID: "s", noteID: mine.noteID, category: .academic, body: "Edit", expectedRecordVersion: 9)
        }
        try await repository.saveNote(districtID: "d", studentID: "s", noteID: mine.noteID, category: .academic, body: "Edit", expectedRecordVersion: mine.recordVersion)
        #expect(repository.storedNotes.first { $0.noteID == mine.noteID }?.revisionCount == 1)
    }

    @Test("Completing a task records the outcome and closes it")
    func completeTask() async throws {
        let repository = InMemoryCollaborationRepository()
        let task = try #require(try await repository.tasks(districtID: "d", studentID: nil, includeClosed: false).first)
        try await repository.updateTask(districtID: "d", task: task, status: .done, outcome: "Family agreed", assigneeUserID: nil)
        #expect(try await repository.tasks(districtID: "d", studentID: nil, includeClosed: false).allSatisfy { $0.taskID != task.taskID })
        let closed = try #require(try await repository.tasks(districtID: "d", studentID: nil, includeClosed: true).first { $0.taskID == task.taskID })
        #expect(closed.outcome == "Family agreed")
        #expect(!closed.isOverdue)
    }

    @Test("New server notification types decode")
    func notificationTypes() throws {
        let json = #"{"id":"1","type":"task_assigned","title":"New task assigned to you","message":"Call family","timestamp":0,"isRead":false,"actionUrl":"tmi://tasks","targetId":"t1"}"#
        let decoded = try JSONDecoder().decode(InAppNotification.self, from: Data(json.utf8))
        #expect(decoded.type == .taskAssigned)
        #expect(NotificationPreferences().shouldNotify(for: .formSubmitted))
    }

    @Test("Search results report emptiness per group")
    func searchResults() async throws {
        let repository = InMemoryCollaborationRepository()
        let hits = try await repository.search(districtID: "d", query: "maya", includeCareers: false)
        #expect(hits.students.count == 1)
        #expect(!hits.isEmpty)
        #expect(WorkspaceSearchResults.empty.isEmpty)
    }
}
#endif
