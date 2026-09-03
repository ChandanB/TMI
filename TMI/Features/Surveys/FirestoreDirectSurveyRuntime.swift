import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Persists survey attempts straight to Firestore.
///
/// `saveSurveyDraft` and `submitSurveyResponse` are the authoritative path
/// wherever Cloud Functions are deployed. With Functions unavailable this
/// writes the same documents from the client; `firestore.rules` restates the
/// invariants those callables enforced, so an attempt still cannot start at
/// the wrong version, change identity, or be reopened after submission.
///
/// Staff review (`reviewSurveyResponse`) and assignment mutation remain
/// server-only and stay unavailable in this mode.
nonisolated struct FirestoreDirectSurveyRuntime: Sendable {
    private let firestore: Firestore
    private let currentUserID: @Sendable () -> String?
    private let now: @Sendable () -> Date

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.firestore = firestore
        self.currentUserID = currentUserID
        self.now = now
    }

    func synchronize(
        _ request: SurveyDraftSyncRequest
    ) async throws -> SurveyResponse {
        let userID = try requireUserID()
        let reference = responseReference(for: request.response)
        let snapshot = try await getDocument(reference)
        let nextVersion: Int

        if snapshot.exists {
            let current = (snapshot.data()?["recordVersion"] as? Int) ?? 0
            guard current == request.response.recordVersion else {
                throw SurveyRepositoryError.conflict
            }
            nextVersion = current + 1
            try await update(
                [
                    "answers": Self.answerPayload(request.response.answers),
                    "recordVersion": nextVersion,
                    "syncState": "synced",
                    "hasPendingChanges": false,
                    "updatedAt": Timestamp(date: now())
                ],
                on: reference
            )
        } else {
            guard request.response.recordVersion == 0 else {
                throw SurveyRepositoryError.conflict
            }
            nextVersion = 1
            try await create(request.response, userID: userID, on: reference)
        }

        var response = request.response
        response.markSynchronized(serverRecordVersion: nextVersion)
        return response
    }

    func submit(
        _ request: SurveySubmissionRequest
    ) async throws -> SurveyResponse {
        let userID = try requireUserID()
        let reference = responseReference(for: request.response)
        let snapshot = try await getDocument(reference)
        let submittedAt = now()
        let nextVersion: Int

        if snapshot.exists {
            let current = (snapshot.data()?["recordVersion"] as? Int) ?? 0
            guard current == request.response.recordVersion else {
                throw SurveyRepositoryError.conflict
            }
            nextVersion = current + 1
            try await update(
                [
                    "answers": Self.answerPayload(request.response.answers),
                    "state": "submitted",
                    "recordVersion": nextVersion,
                    "syncState": "synced",
                    "hasPendingChanges": false,
                    "submittedAt": Timestamp(date: submittedAt),
                    "submissionOperationID": request.operationID,
                    "updatedAt": Timestamp(date: submittedAt)
                ],
                on: reference
            )
        } else {
            // An attempt that was never synchronized still has to land as a
            // draft first; rules reject a document created as submitted.
            guard request.response.recordVersion == 0 else {
                throw SurveyRepositoryError.conflict
            }
            try await create(request.response, userID: userID, on: reference)
            nextVersion = 2
            try await update(
                [
                    "state": "submitted",
                    "recordVersion": nextVersion,
                    "submittedAt": Timestamp(date: submittedAt),
                    "submissionOperationID": request.operationID,
                    "updatedAt": Timestamp(date: submittedAt)
                ],
                on: reference
            )
        }

        var response = request.response
        do {
            try response.markSubmitted(
                operationID: request.operationID,
                submittedAt: submittedAt,
                serverRecordVersion: nextVersion,
                definition: request.definition,
                sessionID: request.sessionID
            )
        } catch {
            throw SurveyRepositoryError.malformedResponse
        }
        return response
    }

    /// A help request is a follow-up task for the supervising educator. Without
    /// Functions there is no trusted writer, and the educator is present in the
    /// room by construction, so the request is surfaced in-session rather than
    /// persisted as a task.
    func requestHelp(
        _ request: SurveyHelpRequest,
        grant: StudentModeGrant
    ) async throws {
        guard grant.scope.allowedOperations.contains(.requestHelp),
              grant.scope.studentID == request.studentID else {
            throw SurveyRepositoryError.authorization
        }
    }

    // MARK: - Firestore access

    private func responseReference(for response: SurveyResponse) -> DocumentReference {
        firestore
            .collection("districts")
            .document(response.districtID)
            .collection("students")
            .document(response.studentID)
            .collection("responses")
            .document(response.attemptID)
    }

    private func create(
        _ response: SurveyResponse,
        userID: String,
        on reference: DocumentReference
    ) async throws {
        let timestamp = Timestamp(date: now())
        try await set(
            [
                "schemaVersion": SurveyResponse.currentSchemaVersion,
                "responseID": response.attemptID,
                "districtID": response.districtID,
                "studentID": response.studentID,
                "assignmentID": response.assignmentID,
                "attemptID": response.attemptID,
                "definitionID": response.definitionID,
                "definitionVersion": response.definitionVersion,
                "state": "draft",
                "recordVersion": 1,
                "answers": Self.answerPayload(response.answers),
                "respondentUserID": userID,
                "syncState": "synced",
                "hasPendingChanges": false,
                "createdAt": timestamp,
                "updatedAt": timestamp
            ],
            on: reference
        )
    }

    static func answerPayload(_ answers: [String: SurveyAnswer]) -> [String: Any] {
        answers.mapValues { answer -> [String: Any] in
            switch answer {
            case .single(let value): ["type": "single", "value": value]
            case .multiple(let values): ["type": "multiple", "value": values.sorted()]
            case .text(let value): ["type": "text", "value": value]
            case .rating(let value): ["type": "rating", "value": value]
            case .image(let value): ["type": "image", "value": value]
            }
        }
    }

    private func requireUserID() throws -> String {
        guard let userID = currentUserID(), !userID.isEmpty else {
            throw SurveyRepositoryError.authorization
        }
        return userID
    }

    private func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot {
        do {
            return try await reference.getDocument()
        } catch {
            throw Self.mapped(error)
        }
    }

    private func set(_ fields: [String: Any], on reference: DocumentReference) async throws {
        do {
            try await reference.setData(fields)
        } catch {
            throw Self.mapped(error)
        }
    }

    private func update(_ fields: [String: Any], on reference: DocumentReference) async throws {
        do {
            try await reference.updateData(fields)
        } catch {
            throw Self.mapped(error)
        }
    }

    private static func mapped(_ error: Error) -> SurveyRepositoryError {
        if let surveyError = error as? SurveyRepositoryError {
            return surveyError
        }
        switch FirestoreErrorCode.Code(rawValue: (error as NSError).code) {
        case .permissionDenied: return .authorization
        case .unavailable, .deadlineExceeded: return .offline
        case .aborted, .failedPrecondition: return .conflict
        default: return .malformedResponse
        }
    }
}
