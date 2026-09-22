import Foundation
@preconcurrency import FirebaseFunctions

/// A caregiver's record of what a young child chose during play. Sent to the
/// `recordInterestObservation` callable, which owns the interest vocabulary,
/// stores the observation immutably, and updates the child's interest edges.
nonisolated struct InterestObservationDraft: Sendable, Equatable {
    var observedInterestIDs: [String] = []
    var longestAttentionInterestID: String?
    var engagement: Int?
    var note: String = ""

    var isValid: Bool {
        !observedInterestIDs.isEmpty
            && (longestAttentionInterestID.map(observedInterestIDs.contains) ?? true)
            && note.count <= 2_000
    }
}

nonisolated enum InterestObservationError: LocalizedError, Equatable, Sendable {
    case notDeployed
    case permissionDenied
    case rejected(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notDeployed: "Observations aren't available on this server yet."
        case .permissionDenied: "Your access doesn't allow recording observations for this child."
        case .rejected(let message): message
        case .unavailable: "The observation wasn't saved. Check the connection and try again."
        }
    }
}

@MainActor
protocol InterestObservationRecording: AnyObject {
    func record(
        _ draft: InterestObservationDraft,
        districtID: String,
        studentID: String,
        operationID: String
    ) async throws
}

@MainActor
final class FirebaseInterestObservationRecorder: InterestObservationRecording {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func record(
        _ draft: InterestObservationDraft,
        districtID: String,
        studentID: String,
        operationID: String
    ) async throws {
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = RecordInterestObservationRequest(
            districtID: districtID,
            expectedRecordVersion: 0,
            idempotencyKey: operationID,
            reasonCode: "caregiver-observation",
            studentID: studentID,
            observedInterestIDs: draft.observedInterestIDs,
            longestAttentionInterestID: draft.longestAttentionInterestID,
            engagement: draft.engagement,
            note: note.isEmpty ? nil : note
        )
        do {
            let callable: Callable<RecordInterestObservationRequest, RecordInterestObservationResponse> =
                functions.httpsCallable("recordInterestObservation")
            _ = try await callable.call(request)
        } catch {
            let nsError = error as NSError
            guard nsError.domain == FunctionsErrorDomain,
                  let code = FunctionsErrorCode(rawValue: nsError.code) else {
                throw InterestObservationError.unavailable
            }
            switch code {
            case .notFound where !nsError.localizedDescription.localizedCaseInsensitiveContains("student"):
                throw InterestObservationError.notDeployed
            case .permissionDenied, .unauthenticated:
                throw InterestObservationError.permissionDenied
            case .invalidArgument, .failedPrecondition, .notFound, .alreadyExists:
                throw InterestObservationError.rejected(nsError.localizedDescription)
            default:
                throw InterestObservationError.unavailable
            }
        }
    }
}

private nonisolated struct RecordInterestObservationRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
    let observedInterestIDs: [String]
    let longestAttentionInterestID: String?
    let engagement: Int?
    let note: String?
}

private nonisolated struct RecordInterestObservationResponse: Decodable, Sendable {
    let operationID: String
    let recordVersion: Int
    let replayed: Bool
}
