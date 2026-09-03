import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import Observation

/// A submitted survey waiting for a reviewer, with the proposals derived from it.
///
/// The analysis here is a preview: the approval callable re-derives it from the
/// stored submission, so what the reviewer sees is what the server will write.
nonisolated struct StudentInterestReview: Sendable, Identifiable {
    var id: String { response.responseID }
    let definition: SurveyDefinition
    let response: SurveyResponse
    let analysis: InterestAnalysisResult
}

nonisolated struct StudentInterestApproval: Sendable {
    let districtID: String
    let studentID: String
    let response: SurveyResponse
    let analysis: InterestAnalysisResult
    let interestIDs: Set<String>
    let operationID: String
}

@MainActor
@Observable
final class StudentInterestService {
    static let shared = StudentInterestService()

    enum StudentInterestError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case userNotAuthenticated
        case invalidStudentId
        case invalidInterestId
        case featureUnavailable
        /// Approval has no client-authorized path: an interest edge is derived
        /// from the immutable submission by the Admin SDK, and Firestore rules
        /// refuse a direct write. Raised when that callable is not deployed.
        case approvalUnavailable

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message): "Failed to fetch student interests: \(message)"
            case .saveFailed(let message): "Failed to approve student interests: \(message)"
            case .userNotAuthenticated: "User not authenticated"
            case .invalidStudentId: "Invalid student ID"
            case .invalidInterestId: "Invalid interest ID"
            case .featureUnavailable: "A district-scoped student context is required."
            case .approvalUnavailable:
                "This build cannot approve interests on its own. Ask your "
                    + "administrator to deploy the approval function, then try again."

            }
        }
    }

    private let db: Firestore
    private let functions: Functions

    private init(
        db: Firestore = .firestore(),
        functions: Functions = .functions(region: "us-central1")
    ) {
        self.db = db
        self.functions = functions
    }

    func getStudentInterests(districtID: String, studentID: String) async throws -> [StudentInterest] {
        guard !districtID.isEmpty, !studentID.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }
        guard Auth.auth().currentUser != nil else {
            throw StudentInterestError.userNotAuthenticated
        }
        do {
            let snapshot = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await self.db.collection("districts")
                    .document(districtID)
                    .collection("students")
                    .document(studentID)
                    .collection("interests")
                    .getDocuments()
            }
            return snapshot.documents.compactMap {
                StudentInterest.fromFirestore(id: $0.documentID, data: $0.data())
            }.sorted {
                $0.rank == $1.rank ? $0.interestId < $1.interestId : $0.rank < $1.rank
            }
        } catch let error as StudentInterestError {
            throw error
        } catch {
            throw StudentInterestError.fetchFailed(error.localizedDescription)
        }
    }

    /// Submissions that have been handed in but whose interests nobody has
    /// approved yet.
    func pendingInterestReviews(
        districtID: String,
        studentID: String
    ) async throws -> [StudentInterestReview] {
        guard !districtID.isEmpty, !studentID.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }
        guard Auth.auth().currentUser != nil else {
            throw StudentInterestError.userNotAuthenticated
        }
        do {
            let snapshot = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await self.db.collection(
                    FirestorePaths.studentResponses(districtID: districtID, studentID: studentID)
                )
                .whereField("state", in: [
                    SurveyResponseState.submitted.rawValue,
                    SurveyResponseState.reviewed.rawValue,
                ])
                .getDocuments()
            }
            let responses = snapshot.documents.compactMap { document in
                try? document.data(as: SurveyResponse.self)
            }
            var reviews: [StudentInterestReview] = []
            for response in responses {
                guard let definition = try await definition(
                    id: response.definitionID,
                    version: response.definitionVersion
                ), !definition.interestRules.isEmpty else {
                    continue
                }
                guard let analysis = try? InterestAnalysis.analyze(
                    response: response,
                    catalog: definition.interestRules
                ), !analysis.proposedInterests.isEmpty else {
                    continue
                }
                reviews.append(
                    StudentInterestReview(
                        definition: definition,
                        response: response,
                        analysis: analysis
                    )
                )
            }
            return reviews.sorted { $0.response.responseID < $1.response.responseID }
        } catch let error as StudentInterestError {
            throw error
        } catch {
            throw StudentInterestError.fetchFailed(error.localizedDescription)
        }
    }

    private func definition(id: String, version: Int) async throws -> SurveyDefinition? {
        let snapshot = try await withTimeout(seconds: 10) { @MainActor @Sendable in
            try await self.db.document(
                FirestorePaths.catalogItem(.surveyDefinitions, itemID: "\(id)__v\(version)")
            ).getDocument()
        }
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: SurveyDefinition.self)
    }

    func approve(_ approval: StudentInterestApproval) async throws -> [StudentInterest] {
        guard approval.response.state == .submitted || approval.response.state == .reviewed,
              approval.response.responseID == approval.analysis.responseID,
              approval.response.definitionID == approval.analysis.definitionID,
              approval.response.definitionVersion == approval.analysis.definitionVersion else {
            throw StudentInterestError.saveFailed("The immutable survey source does not match this analysis.")
        }
        let selected = approval.analysis.proposedInterests.filter {
            approval.interestIDs.contains($0.interestID)
        }
        guard !selected.isEmpty else {
            throw StudentInterestError.saveFailed("Select at least one proposed interest.")
        }
        do {
            let result = try await self.functions.httpsCallable("approveSurveyInterests").call([
                "districtID": approval.districtID,
                "studentID": approval.studentID,
                "responseID": approval.response.responseID,
                "expectedRecordVersion": approval.response.recordVersion,
                "idempotencyKey": approval.operationID,
                "reasonCode": "educator-interest-approval",
                "algorithmVersion": approval.analysis.algorithmVersion,
                "definitionID": approval.analysis.definitionID,
                "definitionVersion": approval.analysis.definitionVersion,
                // Only the selection travels. The server derives each interest's
                // name, category, strength and rank from the stored submission,
                // so this client cannot author district data by hand.
                "interestIDs": selected.map(\.interestID).sorted(),
            ])
            guard let payload = result.data as? [String: Any],
                  payload["approvedCount"] as? Int == selected.count else {
                throw StudentInterestError.saveFailed("The server returned an incomplete approval result.")
            }
            return try await getStudentInterests(
                districtID: approval.districtID,
                studentID: approval.studentID
            )
        } catch let error as StudentInterestError {
            throw error
        } catch {
            // An undeployed callable answers NOT_FOUND. Say so plainly: the
            // reviewer cannot act on a generic save failure, and there is no
            // client-authorized path to fall back to.
            let functionsError = error as NSError
            if functionsError.domain == FunctionsErrorDomain,
               functionsError.code == FunctionsErrorCode.notFound.rawValue {
                throw StudentInterestError.approvalUnavailable
            }
            throw StudentInterestError.saveFailed(error.localizedDescription)
        }
    }

    // Legacy callers never fall back to user-scoped or client-write paths.
    func getStudentInterests(studentId: String) async throws -> [StudentInterest] {
        _ = studentId
        throw StudentInterestError.featureUnavailable
    }

    func getHighAffinityInterests(studentId: String) async throws -> [StudentInterest] {
        let interests = try await getStudentInterests(studentId: studentId)
        return interests.filter(\.isHighAffinity)
    }

    func getStudentIdsWithInterest(interestId: String) async throws -> [String] {
        _ = interestId
        throw StudentInterestError.featureUnavailable
    }

    func saveSurveyResults(studentId: String, results: [String: Int]) async throws {
        _ = studentId
        _ = results
        throw StudentInterestError.featureUnavailable
    }

    func addInterest(
        studentId: String,
        interestId: String,
        level: Int,
        source: StudentInterest.StudentInterestSource
    ) async throws {
        _ = studentId
        _ = interestId
        _ = level
        _ = source
        throw StudentInterestError.featureUnavailable
    }

    func updateInterestLevel(studentId: String, interestId: String, level: Int) async throws {
        _ = studentId
        _ = interestId
        _ = level
        throw StudentInterestError.featureUnavailable
    }

    func removeInterest(studentId: String, interestId: String) async throws {
        _ = studentId
        _ = interestId
        throw StudentInterestError.featureUnavailable
    }

    func clearSurveyInterests(studentId: String) async throws {
        _ = studentId
        throw StudentInterestError.featureUnavailable
    }
}
