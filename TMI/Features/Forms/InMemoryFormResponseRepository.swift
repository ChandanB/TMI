#if DEBUG
import Foundation
import SwiftUI

/// Mirrors the server's form rules (versions, required fields, frozen
/// submissions) for previews, unit tests, and the `student-forms` fixture.
@MainActor
final class InMemoryFormResponseRepository: FormResponseRepository {
    struct Stored {
        var answers: [String: FormAnswerValue] = [:]
        var state: FormResponseState = .notStarted
        var respondentType: FormRespondentType?
        var recordVersion = 0
        var submittedAt: String?
        var review: FormReview?
    }

    let fields: [FormFieldDescriptor] = [
        FormFieldDescriptor(key: "s0-f0", sectionTitle: "About this week", label: "How did the week go?", type: "Rating", isRequired: true, options: [], isAnswerable: true),
        FormFieldDescriptor(key: "s0-f1", sectionTitle: "About this week", label: "Best moment", type: "longText", isRequired: false, options: [], isAnswerable: true),
        FormFieldDescriptor(key: "s0-f2", sectionTitle: "About this week", label: "Mood most days", type: "dropdown", isRequired: true, options: ["Calm", "Busy", "Tired"], isAnswerable: true),
        FormFieldDescriptor(key: "s1-f0", sectionTitle: "Consent", label: "OK to share with the care team?", type: "checkbox", isRequired: false, options: [], isAnswerable: true),
    ]
    private(set) var stored: [String: Stored] = ["assignment-1": Stored()]
    var failNextSave: FormResponseError?

    func forms(districtID: String, studentID: String) async throws -> [StudentFormSummary] {
        stored.keys.sorted().map { id in
            let value = stored[id] ?? Stored()
            return StudentFormSummary(assignmentID: id, templateID: "template-1", templateName: "Weekly family check-in", instructions: "Share how the week went.", dueDate: "2026-10-01T15:00:00Z", isActive: true, requiresReview: true, state: value.state, submittedAt: value.submittedAt, reviewedAt: value.review?.reviewedAt, recordVersion: value.recordVersion)
        }
    }

    func load(districtID: String, assignmentID: String, studentID: String) async throws -> FormResponseDocument {
        let value = stored[assignmentID] ?? Stored()
        return FormResponseDocument(templateName: "Weekly family check-in", instructions: "Share how the week went.", fields: fields, answers: value.answers, state: value.state, respondentType: value.respondentType, recordVersion: value.recordVersion, submittedAt: value.submittedAt, review: value.review, canEdit: !value.state.isFrozen)
    }

    func saveDraft(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], expectedRecordVersion: Int) async throws -> Int {
        if let error = failNextSave { failNextSave = nil; throw error }
        var value = stored[assignmentID] ?? Stored()
        guard !value.state.isFrozen else { throw FormResponseError.rejected("Already submitted.") }
        guard value.recordVersion == expectedRecordVersion else { throw FormResponseError.conflict }
        value.answers = answers
        value.state = .draft
        value.recordVersion += 1
        stored[assignmentID] = value
        return value.recordVersion
    }

    func submit(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], respondentType: FormRespondentType, expectedRecordVersion: Int, operationID: String) async throws -> Int {
        var value = stored[assignmentID] ?? Stored()
        guard value.recordVersion == expectedRecordVersion else { throw FormResponseError.conflict }
        let document = try await load(districtID: districtID, assignmentID: assignmentID, studentID: studentID)
        guard document.missingRequiredFields(in: answers).isEmpty else { throw FormResponseError.incomplete("Answer the required questions.") }
        value.answers = answers
        value.state = .submitted
        value.respondentType = respondentType
        value.recordVersion += 1
        value.submittedAt = "2026-09-22T15:00:00Z"
        stored[assignmentID] = value
        return value.recordVersion
    }

    func review(districtID: String, assignmentID: String, studentID: String, outcome: FormReviewOutcome, comment: String?, expectedRecordVersion: Int, operationID: String) async throws -> Int {
        var value = stored[assignmentID] ?? Stored()
        guard value.state.isFrozen else { throw FormResponseError.rejected("Only submitted forms can be reviewed.") }
        guard value.recordVersion == expectedRecordVersion else { throw FormResponseError.conflict }
        value.state = .reviewed
        value.review = FormReview(outcome: outcome.rawValue, comment: comment, reviewedBy: "staff", reviewedAt: "2026-09-22T16:00:00Z")
        value.recordVersion += 1
        stored[assignmentID] = value
        return value.recordVersion
    }

    private(set) var exportCount = 0

    func assignmentResponses(districtID: String, assignmentID: String) async throws -> AssignmentResponses {
        let value = stored[assignmentID] ?? Stored()
        let rows = [
            AssignmentResponses.Row(studentID: "student-fixture", displayName: "Kai Rivera", schoolID: "school-fixture", state: value.state, submittedAt: value.submittedAt, score: value.state.isFrozen ? 7 : nil, maxScore: value.state.isFrozen ? 10 : nil, band: value.state.isFrozen ? "Moderate" : nil, reviewOutcome: value.review?.outcome),
            AssignmentResponses.Row(studentID: "student-2", displayName: "Maya Thompson", schoolID: "school-fixture", state: .reviewed, submittedAt: "2026-09-20T15:00:00Z", score: 3, maxScore: 10, band: "Low", reviewOutcome: "accepted"),
            AssignmentResponses.Row(studentID: "student-3", displayName: "Jordan Lee", schoolID: "school-fixture", state: .notStarted, submittedAt: nil, score: nil, maxScore: nil, band: nil, reviewOutcome: nil),
        ]
        func count(_ state: FormResponseState) -> Int { rows.filter { $0.state == state }.count }
        let scores = rows.compactMap(\.score)
        return AssignmentResponses(
            templateName: "Weekly family check-in", requiresReview: true, dueDate: "2026-10-01T15:00:00Z", isScored: true,
            counts: .init(assigned: rows.count, notStarted: count(.notStarted), draft: count(.draft), submitted: count(.submitted), reviewed: count(.reviewed)),
            averageScore: scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count),
            rows: rows
        )
    }

    func exportAssignmentResponses(districtID: String, assignmentID: String) async throws -> AssignmentResponsesExport {
        exportCount += 1
        return AssignmentResponsesExport(csv: "Student,State\r\nMaya Thompson,reviewed\r\n", fileName: "Weekly-family-check-in-responses.csv")
    }
}

#Preview("Student forms") {
    ScrollView {
        StudentFormsSection(districtID: "d", studentID: "s", studentName: "Kai Rivera", repository: InMemoryFormResponseRepository())
            .padding()
    }
}
#endif
