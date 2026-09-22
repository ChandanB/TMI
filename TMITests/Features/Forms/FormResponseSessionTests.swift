#if DEBUG
import Foundation
import Testing
@testable import TMI

@Suite("Form response session")
@MainActor
struct FormResponseSessionTests {
    private func makeSession(_ repository: InMemoryFormResponseRepository) -> FormResponseSession {
        FormResponseSession(districtID: "d", assignmentID: "assignment-1", studentID: "s", repository: repository, autosaveDelay: .milliseconds(1))
    }

    @Test("Autosave persists a draft with a new version")
    func autosave() async throws {
        let repository = InMemoryFormResponseRepository()
        let session = makeSession(repository)
        await session.load()
        #expect(session.isEditable)
        session.setAnswer(.number(4), for: "s0-f0")
        await session.saveDraftNow()
        #expect(session.saveStatus == .saved)
        #expect(session.recordVersion == 1)
        #expect(repository.stored["assignment-1"]?.state == .draft)
    }

    @Test("Submit requires required answers, then freezes the form")
    func submitFreezes() async {
        let repository = InMemoryFormResponseRepository()
        let session = makeSession(repository)
        await session.load()
        session.setAnswer(.number(3), for: "s0-f0")
        #expect(!session.canSubmit)
        #expect(await session.submit() == false)
        session.setAnswer(.text("Calm"), for: "s0-f2")
        session.respondentType = .family
        #expect(await session.submit())
        #expect(session.document?.state == .submitted)
        #expect(!session.isEditable)
        #expect(repository.stored["assignment-1"]?.respondentType == .family)
        session.setAnswer(.text("Busy"), for: "s0-f2")
        #expect(session.answer(for: "s0-f2") == .text("Calm"))
    }

    @Test("Review records an outcome without changing answers")
    func review() async {
        let repository = InMemoryFormResponseRepository()
        let session = makeSession(repository)
        await session.load()
        session.setAnswer(.number(5), for: "s0-f0")
        session.setAnswer(.text("Busy"), for: "s0-f2")
        _ = await session.submit()
        #expect(await session.review(outcome: .followUpNeeded, comment: "  Call family  "))
        #expect(session.document?.state == .reviewed)
        #expect(session.document?.review?.comment == "Call family")
        #expect(session.answer(for: "s0-f2") == .text("Busy"))
    }

    @Test("A failed autosave is reported and not shown as saved")
    func failedAutosave() async {
        let repository = InMemoryFormResponseRepository()
        repository.failNextSave = .unavailable
        let session = makeSession(repository)
        await session.load()
        session.setAnswer(.number(2), for: "s0-f0")
        await session.saveDraftNow()
        #expect(session.saveStatus == .failed(.unavailable))
        #expect(repository.stored["assignment-1"]?.recordVersion == 0)
    }

    @Test("Answers encode as plain JSON values the server validates")
    func answerEncoding() throws {
        let encoded = try JSONEncoder().encode(["a": FormAnswerValue.number(4), "b": .text("x"), "c": .flag(true)])
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"a\":4"))
        #expect(json.contains("\"c\":true"))
        let decoded = try JSONDecoder().decode([String: FormAnswerValue].self, from: Data(#"{"a":4,"b":"x","c":false}"#.utf8))
        #expect(decoded["a"] == .number(4))
        #expect(decoded["c"] == .flag(false))
    }
}
#endif
