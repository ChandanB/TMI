import Foundation
import LocalAuthentication
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions

/// "All About My Child" — the early-childhood family intake. The family
/// completes it on a caregiver's device in a locked hand-off (no family
/// account), or the caregiver records what the family shares. Submitted
/// through the staff member's trusted session to `recordFamilyInput`.
nonisolated struct FamilyInputDraft: Sendable, Equatable {
    enum CompletedBy: String, Sendable, CaseIterable {
        case family
        case staffOnBehalfOfFamily

        var displayName: String {
            switch self {
            case .family: "The family, on this device"
            case .staffOnBehalfOfFamily: "Me, from what the family shared"
            }
        }
    }

    struct Question: Sendable, Identifiable, Equatable {
        let id: String
        let prompt: String
    }

    static let formID = "ec-family-all-about-me"
    static let formVersion = 1

    /// Mirrors `textQuestionIDs` in functions/src/familyInput.ts.
    static let questions: [Question] = [
        Question(id: "favoriteThings", prompt: "What does your child love to do, play with, or talk about?"),
        Question(id: "comfortsWhenUpset", prompt: "What helps your child feel calm or comforted when upset?"),
        Question(id: "routinesAtHome", prompt: "What routines at home (meals, naps, bedtime) help your child's day go well?"),
        Question(id: "languagesAtHome", prompt: "Which languages does your child hear or speak at home?"),
        Question(id: "hopesForThisYear", prompt: "What would you love your child to learn or enjoy this year?"),
        Question(id: "anythingElse", prompt: "Is there anything else you'd like the care team to know?"),
    ]

    var completedBy: CompletedBy = .family
    var relationship: String = ""
    var answers: [String: String] = [:]
    var favoritePlayInterestIDs: [String] = []

    var trimmedAnswers: [String: String] {
        answers.compactMapValues {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    var isValid: Bool {
        (!trimmedAnswers.isEmpty || !favoritePlayInterestIDs.isEmpty)
            && trimmedAnswers.values.allSatisfy { $0.count <= 2_000 }
            && relationship.count <= 80
    }
}

@MainActor
protocol FamilyInputRecording: AnyObject {
    func record(_ draft: FamilyInputDraft, districtID: String, studentID: String, operationID: String) async throws
}

@MainActor
final class FirebaseFamilyInputRecorder: FamilyInputRecording {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func record(_ draft: FamilyInputDraft, districtID: String, studentID: String, operationID: String) async throws {
        let relationship = draft.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = RecordFamilyInputRequest(
            districtID: districtID,
            expectedRecordVersion: 0,
            idempotencyKey: operationID,
            reasonCode: "family-intake",
            studentID: studentID,
            formID: FamilyInputDraft.formID,
            formVersion: FamilyInputDraft.formVersion,
            completedBy: draft.completedBy.rawValue,
            relationship: relationship.isEmpty ? nil : relationship,
            answers: draft.trimmedAnswers,
            favoritePlayInterestIDs: draft.favoritePlayInterestIDs
        )
        do {
            let callable: Callable<RecordFamilyInputRequest, RecordFamilyInputResponse> =
                functions.httpsCallable("recordFamilyInput")
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

/// Exiting the family hand-off requires the device owner (the caregiver).
enum FamilyHandoffLock {
    @MainActor
    static func authenticateStaff() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode on this device: the hand-off can't be locked, so the
            // caller must not offer it.
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to return from the family form"
            )
        } catch {
            return false
        }
    }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

private nonisolated struct RecordFamilyInputRequest: Encodable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
    let formID: String
    let formVersion: Int
    let completedBy: String
    let relationship: String?
    let answers: [String: String]
    let favoritePlayInterestIDs: [String]
}

private nonisolated struct RecordFamilyInputResponse: Decodable, Sendable {
    let operationID: String
    let recordVersion: Int
    let replayed: Bool
}

/// A submitted family input as staff read it.
nonisolated struct FamilyInputSummary: Identifiable, Sendable, Equatable {
    let id: String
    let completedBy: FamilyInputDraft.CompletedBy
    let relationship: String?
    let submittedAt: Date
    let answers: [String: String]
    let favoritePlayInterestIDs: [String]
}

enum FamilyInputReader {
    /// Reads the child's family inputs, newest first. Rules allow this for
    /// staff who can read the child's record.
    @MainActor
    static func load(districtID: String, studentID: String) async throws -> [FamilyInputSummary] {
        let snapshot = try await FirebaseManager.shared.firestore
            .collection("districts").document(districtID)
            .collection("students").document(studentID)
            .collection("familyInputs")
            .order(by: "submittedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let completedBy = (data["completedBy"] as? String).flatMap(FamilyInputDraft.CompletedBy.init(rawValue:)),
                  let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() else {
                return nil
            }
            return FamilyInputSummary(
                id: document.documentID,
                completedBy: completedBy,
                relationship: data["relationship"] as? String,
                submittedAt: submittedAt,
                answers: data["answers"] as? [String: String] ?? [:],
                favoritePlayInterestIDs: data["favoritePlayInterestIDs"] as? [String] ?? []
            )
        }
    }
}
