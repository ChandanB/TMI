import Foundation
@preconcurrency import FirebaseFunctions

nonisolated enum FormResponseState: String, Codable, Sendable {
    case notStarted, draft, submitted, reviewed

    var displayName: String {
        switch self {
        case .notStarted: "Not started"
        case .draft: "In progress"
        case .submitted: "Submitted"
        case .reviewed: "Reviewed"
        }
    }

    var isFrozen: Bool { self == .submitted || self == .reviewed }
}

nonisolated enum FormRespondentType: String, Codable, Sendable, CaseIterable {
    case staff, family, student

    var displayName: String {
        switch self {
        case .staff: "Me (staff)"
        case .family: "The family, on this device"
        case .student: "The student, on this device"
        }
    }
}

nonisolated struct StudentFormSummary: Codable, Sendable, Equatable, Identifiable {
    let assignmentID: String
    let templateID: String
    let templateName: String
    let instructions: String?
    let dueDate: String?
    let isActive: Bool
    let requiresReview: Bool
    let state: FormResponseState
    let submittedAt: String?
    let reviewedAt: String?
    let recordVersion: Int

    var id: String { assignmentID }

    var due: Date? { dueDate.flatMap(FormDates.parse) }

    func isOverdue(now: Date = .now) -> Bool {
        guard let due, !state.isFrozen else { return false }
        return due < now
    }
}

nonisolated struct FormFieldDescriptor: Codable, Sendable, Equatable, Identifiable {
    let key: String
    let sectionTitle: String
    let label: String
    let type: String
    let isRequired: Bool
    let options: [String]
    let isAnswerable: Bool

    var id: String { key }
}

/// A single answer: text, number, or yes/no.
nonisolated enum FormAnswerValue: Codable, Sendable, Equatable {
    case text(String)
    case number(Double)
    case flag(Bool)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .number(let value):
            if value.rounded() == value, abs(value) < 1e15 {
                try container.encode(Int(value))
            } else {
                try container.encode(value)
            }
        case .flag(let value): try container.encode(value)
        }
    }

    var isBlank: Bool {
        if case .text(let value) = self { return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return false
    }
}

nonisolated struct FormReview: Codable, Sendable, Equatable {
    let outcome: String
    let comment: String?
    let reviewedBy: String?
    let reviewedAt: String?
}

nonisolated struct FormResponseDocument: Codable, Sendable, Equatable {
    let templateName: String
    let instructions: String?
    let fields: [FormFieldDescriptor]
    let answers: [String: FormAnswerValue]
    let state: FormResponseState
    let respondentType: FormRespondentType?
    let recordVersion: Int
    let submittedAt: String?
    let review: FormReview?
    let canEdit: Bool

    /// Required, answerable fields that are still blank.
    func missingRequiredFields(in answers: [String: FormAnswerValue]) -> [FormFieldDescriptor] {
        fields.filter { field in
            field.isRequired && field.isAnswerable && (answers[field.key].map(\.isBlank) ?? true)
        }
    }
}

nonisolated enum FormReviewOutcome: String, Codable, Sendable, CaseIterable {
    case accepted, followUpNeeded

    var displayName: String {
        switch self {
        case .accepted: "Reviewed — no follow-up"
        case .followUpNeeded: "Follow-up needed"
        }
    }
}

nonisolated enum FormResponseError: LocalizedError, Equatable, Sendable {
    case notDeployed
    case permissionDenied
    case conflict
    case incomplete(String)
    case rejected(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notDeployed: "Forms aren't available on this server yet."
        case .permissionDenied: "Your access doesn't include this form for this student."
        case .conflict: "Someone else changed this form. Reload to see the latest version."
        case .incomplete(let message), .rejected(let message): message
        case .unavailable: "The form couldn't be saved. Check the connection and try again."
        }
    }

    static func map(_ error: any Error) -> FormResponseError {
        if let error = error as? FormResponseError { return error }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        let message = nsError.localizedDescription
        let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        switch code {
        case .notFound where message.localizedCaseInsensitiveContains("not found"):
            return .rejected(message)
        case .notFound: return .notDeployed
        case .permissionDenied, .unauthenticated: return .permissionDenied
        case .aborted: return .conflict
        case .failedPrecondition where details?["kind"] as? String == "form-incomplete":
            return .incomplete(message)
        case .invalidArgument, .failedPrecondition, .alreadyExists: return .rejected(message)
        default: return .unavailable
        }
    }
}

@MainActor
protocol FormResponseRepository: AnyObject {
    func forms(districtID: String, studentID: String) async throws -> [StudentFormSummary]
    func load(districtID: String, assignmentID: String, studentID: String) async throws -> FormResponseDocument
    func saveDraft(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], expectedRecordVersion: Int) async throws -> Int
    func submit(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], respondentType: FormRespondentType, expectedRecordVersion: Int, operationID: String) async throws -> Int
    func review(districtID: String, assignmentID: String, studentID: String, outcome: FormReviewOutcome, comment: String?, expectedRecordVersion: Int, operationID: String) async throws -> Int
}

@MainActor
final class FirebaseFormResponseRepository: FormResponseRepository {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func forms(districtID: String, studentID: String) async throws -> [StudentFormSummary] {
        let response: FormsResponse = try await call("listStudentForms", StudentRequest(districtID: districtID, studentID: studentID))
        return response.forms
    }

    func load(districtID: String, assignmentID: String, studentID: String) async throws -> FormResponseDocument {
        try await call("loadFormResponse", LocatorRequest(districtID: districtID, assignmentID: assignmentID, studentID: studentID))
    }

    func saveDraft(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], expectedRecordVersion: Int) async throws -> Int {
        let response: VersionResponse = try await call("saveFormDraft", DraftRequest(
            districtID: districtID, assignmentID: assignmentID, studentID: studentID,
            answers: answers, expectedRecordVersion: expectedRecordVersion
        ))
        return response.recordVersion
    }

    func submit(districtID: String, assignmentID: String, studentID: String, answers: [String: FormAnswerValue], respondentType: FormRespondentType, expectedRecordVersion: Int, operationID: String) async throws -> Int {
        let response: VersionResponse = try await call("submitFormResponse", SubmitRequest(
            districtID: districtID, expectedRecordVersion: expectedRecordVersion, idempotencyKey: operationID,
            reasonCode: "form-completion", assignmentID: assignmentID, studentID: studentID,
            respondentType: respondentType, answers: answers
        ))
        return response.recordVersion
    }

    func review(districtID: String, assignmentID: String, studentID: String, outcome: FormReviewOutcome, comment: String?, expectedRecordVersion: Int, operationID: String) async throws -> Int {
        let response: VersionResponse = try await call("reviewFormResponse", ReviewRequest(
            districtID: districtID, expectedRecordVersion: expectedRecordVersion, idempotencyKey: operationID,
            reasonCode: "form-review", assignmentID: assignmentID, studentID: studentID,
            outcome: outcome, comment: comment
        ))
        return response.recordVersion
    }

    private func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(
        _ name: String, _ request: Request
    ) async throws -> Response {
        do {
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch is DecodingError {
            throw FormResponseError.unavailable
        } catch {
            throw FormResponseError.map(error)
        }
    }
}

nonisolated enum FormDates {
    static func parse(_ iso: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

private nonisolated struct StudentRequest: Encodable, Sendable { let districtID: String; let studentID: String }
private nonisolated struct LocatorRequest: Encodable, Sendable { let districtID: String; let assignmentID: String; let studentID: String }
private nonisolated struct FormsResponse: Decodable, Sendable { let forms: [StudentFormSummary] }
private nonisolated struct VersionResponse: Decodable, Sendable { let recordVersion: Int }

private nonisolated struct DraftRequest: Encodable, Sendable {
    let districtID: String
    let assignmentID: String
    let studentID: String
    let answers: [String: FormAnswerValue]
    let expectedRecordVersion: Int
}

private nonisolated struct SubmitRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let assignmentID: String
    let studentID: String
    let respondentType: FormRespondentType
    let answers: [String: FormAnswerValue]
}

private nonisolated struct ReviewRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let assignmentID: String
    let studentID: String
    let outcome: FormReviewOutcome
    let comment: String?
}
