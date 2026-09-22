import Foundation
import Observation

/// Drives one student's response to one form: load, autosave, submit, review.
/// Nothing is shown as saved until the server confirms it.
@Observable
@MainActor
final class FormResponseSession {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(FormResponseError)
    }

    enum SaveStatus: Equatable {
        case idle
        case saving
        case saved
        case failed(FormResponseError)
    }

    let districtID: String
    let assignmentID: String
    let studentID: String
    private let repository: any FormResponseRepository
    private let autosaveDelay: Duration

    private(set) var phase: Phase = .loading
    private(set) var document: FormResponseDocument?
    private(set) var answers: [String: FormAnswerValue] = [:]
    private(set) var recordVersion = 0
    private(set) var saveStatus: SaveStatus = .idle
    private(set) var isSubmitting = false
    private(set) var isReviewing = false
    var respondentType: FormRespondentType = .staff
    var actionError: FormResponseError?

    /// Stable for this attempt, so a retried submit can't double-submit.
    private let submitOperationID = UUID().uuidString
    private var reviewOperationID = UUID().uuidString
    private var autosaveTask: Task<Void, Never>?
    private var hasUnsavedChanges = false

    init(
        districtID: String,
        assignmentID: String,
        studentID: String,
        repository: any FormResponseRepository,
        autosaveDelay: Duration = .milliseconds(1_200)
    ) {
        self.districtID = districtID
        self.assignmentID = assignmentID
        self.studentID = studentID
        self.repository = repository
        self.autosaveDelay = autosaveDelay
    }

    var isEditable: Bool { document?.canEdit == true && document?.state.isFrozen == false }

    var missingRequired: [FormFieldDescriptor] {
        document?.missingRequiredFields(in: answers) ?? []
    }

    var canSubmit: Bool {
        isEditable && missingRequired.isEmpty && !isSubmitting && saveStatus != .saving
    }

    func load() async {
        phase = .loading
        do {
            let loaded = try await repository.load(districtID: districtID, assignmentID: assignmentID, studentID: studentID)
            document = loaded
            answers = loaded.answers
            recordVersion = loaded.recordVersion
            if let type = loaded.respondentType { respondentType = type }
            hasUnsavedChanges = false
            saveStatus = .idle
            phase = .ready
        } catch {
            phase = .failed(FormResponseError.map(error))
        }
    }

    func setAnswer(_ value: FormAnswerValue?, for key: String) {
        guard isEditable else { return }
        answers[key] = value
        hasUnsavedChanges = true
        scheduleAutosave()
    }

    func answer(for key: String) -> FormAnswerValue? { answers[key] }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let delay = autosaveDelay
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.saveDraftNow()
        }
    }

    /// Saves pending changes immediately (also used before submitting).
    func saveDraftNow() async {
        guard hasUnsavedChanges, isEditable else { return }
        saveStatus = .saving
        let snapshot = answers
        do {
            recordVersion = try await repository.saveDraft(
                districtID: districtID, assignmentID: assignmentID, studentID: studentID,
                answers: snapshot, expectedRecordVersion: recordVersion
            )
            if snapshot == answers { hasUnsavedChanges = false }
            saveStatus = .saved
        } catch {
            saveStatus = .failed(FormResponseError.map(error))
        }
    }

    @discardableResult
    func submit() async -> Bool {
        autosaveTask?.cancel()
        // Let an in-flight autosave finish so the version we send is current.
        while saveStatus == .saving {
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard isEditable, missingRequired.isEmpty, !isSubmitting else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            recordVersion = try await repository.submit(
                districtID: districtID, assignmentID: assignmentID, studentID: studentID,
                answers: answers, respondentType: respondentType,
                expectedRecordVersion: recordVersion, operationID: submitOperationID
            )
            hasUnsavedChanges = false
            await load()
            return true
        } catch {
            actionError = FormResponseError.map(error)
            return false
        }
    }

    @discardableResult
    func review(outcome: FormReviewOutcome, comment: String) async -> Bool {
        isReviewing = true
        defer { isReviewing = false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            recordVersion = try await repository.review(
                districtID: districtID, assignmentID: assignmentID, studentID: studentID,
                outcome: outcome, comment: trimmed.isEmpty ? nil : trimmed,
                expectedRecordVersion: recordVersion, operationID: reviewOperationID
            )
            reviewOperationID = UUID().uuidString
            await load()
            return true
        } catch {
            actionError = FormResponseError.map(error)
            return false
        }
    }
}
