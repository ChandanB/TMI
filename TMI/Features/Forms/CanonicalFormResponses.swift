import Foundation
@preconcurrency import FirebaseFirestore

/// Reads canonical responses (`formAssignments/{id}/respondents`) in the
/// legacy `FormSubmission` shape used by assignment analytics and review
/// lists. Rules allow the assigner and staff who can read each student.
@MainActor
enum CanonicalFormResponses {
    static func submissions(
        firestore: Firestore,
        districtID: String,
        assignmentID: String
    ) async throws -> [FormSubmission] {
        let snapshot = try await firestore
            .collection(FirestorePaths.formAssignments(districtID: districtID))
            .document(assignmentID)
            .collection("respondents")
            .getDocuments()
        return snapshot.documents.map { submission(id: $0.documentID, data: $0.data(), assignmentID: assignmentID) }
    }

    static func submission(id: String, data: [String: Any], assignmentID: String) -> FormSubmission {
        let review = data["review"] as? [String: Any]
        let answers = (data["answers"] as? [String: Any] ?? [:]).reduce(into: [String: AnyCodable]()) { result, entry in
            switch entry.value {
            case let flag as Bool: result[entry.key] = AnyCodable(flag)
            case let number as NSNumber: result[entry.key] = AnyCodable(number.doubleValue)
            case let text as String: result[entry.key] = AnyCodable(text)
            default: break
            }
        }
        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        return FormSubmission(
            id: id,
            formId: data["templateID"] as? String ?? "",
            data: answers,
            submissionDate: submittedAt ?? updatedAt ?? .distantPast,
            assignmentId: assignmentID,
            studentId: data["studentID"] as? String ?? id,
            status: data["state"] as? String ?? "draft",
            updatedAt: updatedAt,
            reviewedBy: review?["reviewedBy"] as? String,
            reviewedAt: (review?["reviewedAt"] as? Timestamp)?.dateValue(),
            feedback: review?["comment"] as? String
        )
    }
}
