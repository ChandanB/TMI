import CryptoKit
import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions
@preconcurrency import Network

nonisolated enum SurveyRepositoryError: Error, Equatable, Sendable {
    case validation
    case conflict
    case revoked
    case expired
    case historyLimitReached
    case authorization
    case offline
    case unavailable
    case cancelled
    case immutableResponse
    case malformedResponse
}

nonisolated struct SurveyDraftSyncRequest: Sendable, Equatable {
    let response: SurveyResponse
    let definition: SurveyDefinition
    let sessionID: String
}

nonisolated struct SurveySubmissionRequest: Sendable, Equatable {
    let response: SurveyResponse
    let definition: SurveyDefinition
    let sessionID: String
    let operationID: String
}

nonisolated struct SurveyReviewRequest: Sendable, Equatable {
    let response: SurveyResponse
    let operationID: String
    let staffIdentity: StudentModeStaffIdentity
}

nonisolated struct SurveyActivity: Sendable, Equatable {
    let assignment: SurveyAssignment
    let definition: SurveyDefinition
}

nonisolated struct SurveyHelpRequest: Sendable, Equatable {
    let operationID: String
    let districtID: String
    let studentID: String
    let assignmentID: String
    let sessionID: String
}

nonisolated enum SurveyAssignmentMutationAction: String, Sendable {
    case create
    case reassign
    case revoke
}

nonisolated struct SurveyAssignmentMutationRequest: Sendable, Equatable {
    let action: SurveyAssignmentMutationAction
    let assignmentID: String
    let studentID: String
    let definitionID: String
    let definitionVersion: Int
    let expectedRecordVersion: Int
    let operationID: String
    let reasonCode: String
}

nonisolated enum SurveyDraftLoad: Equatable, Sendable {
    case missing
    case draft(SurveyResponse)
    case quarantined(SurveyQuarantineReason)
    case corrupt
    case scopeMismatch
}

nonisolated struct SurveyDraftStore: Sendable {
    typealias Load = @Sendable (SurveyAttemptKey) async -> SurveyDraftLoad
    typealias Save = @Sendable (SurveyResponse) async throws -> Void
    typealias Purge = @Sendable (SurveyAttemptKey) async throws -> Void

    let load: Load
    let save: Save
    let quarantine: Save
    let purge: Purge

    static let memory = SurveyDraftStore(
        load: { _ in .missing },
        save: { _ in },
        quarantine: { _ in },
        purge: { _ in }
    )

    static func localFiles(
        directory: URL? = nil
    ) -> SurveyDraftStore {
        let backend = SurveyLocalDraftFiles(directory: directory)
        return SurveyDraftStore(
            load: { key in
                await backend.load(key)
            },
            save: { response in
                try await backend.save(response)
            },
            quarantine: { response in
                try await backend.quarantine(response)
            },
            purge: { key in
                try await backend.purge(key)
            }
        )
    }
}

private actor SurveyLocalDraftFiles {
    private struct Envelope: Codable {
        let response: SurveyResponse
        let localRevision: Int
    }

    private let directory: URL?

    init(directory: URL?) {
        self.directory = directory
    }

    func load(_ key: SurveyAttemptKey) -> SurveyDraftLoad {
        guard let activeURL = fileURL(for: key, namespace: "active"),
              let quarantineURL = fileURL(for: key, namespace: "quarantine") else {
            return .corrupt
        }
        if FileManager.default.fileExists(atPath: quarantineURL.path) {
            guard let data = try? Data(contentsOf: quarantineURL),
                  let envelope = try? JSONDecoder().decode(
                    Envelope.self,
                    from: data
                  ),
                  envelope.response.attemptKey == key,
                  case .quarantined(let reason) =
                    envelope.response.syncState else {
                return .corrupt
            }
            return .quarantined(reason)
        }
        guard FileManager.default.fileExists(atPath: activeURL.path) else {
            return .missing
        }
        let data: Data
        do {
            data = try Data(contentsOf: activeURL)
        } catch {
            try? quarantineFile(at: activeURL, as: quarantineURL)
            return .corrupt
        }
        guard let envelope = try? JSONDecoder().decode(
            Envelope.self,
            from: data
        ) else {
            try? quarantineFile(at: activeURL, as: quarantineURL)
            return .corrupt
        }
        var response = envelope.response
        response.restoreLocalRevision(envelope.localRevision)
        guard response.attemptKey == key else {
            try? quarantineFile(at: activeURL, as: quarantineURL)
            return .scopeMismatch
        }
        return .draft(response)
    }

    func save(_ response: SurveyResponse) throws {
        guard let fileURL = fileURL(
            for: response.attemptKey,
            namespace: "active"
        ) else {
            throw SurveyRepositoryError.unavailable
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(
            Envelope(response: response, localRevision: response.localRevision)
        )
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func quarantine(_ response: SurveyResponse) throws {
        guard let activeURL = fileURL(
            for: response.attemptKey,
            namespace: "active"
        ), let quarantineURL = fileURL(
            for: response.attemptKey,
            namespace: "quarantine"
        ) else {
            throw SurveyRepositoryError.unavailable
        }
        try FileManager.default.createDirectory(
            at: quarantineURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(
            Envelope(response: response, localRevision: response.localRevision)
        )
        try data.write(
            to: quarantineURL,
            options: [.atomic, .completeFileProtection]
        )
        try? FileManager.default.removeItem(at: activeURL)
    }

    func purge(_ key: SurveyAttemptKey) throws {
        for namespace in ["active", "quarantine"] {
            guard let url = fileURL(for: key, namespace: namespace) else {
                continue
            }
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func quarantineFile(at activeURL: URL, as quarantineURL: URL) throws {
        try FileManager.default.createDirectory(
            at: quarantineURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: quarantineURL.path) {
            try FileManager.default.removeItem(at: quarantineURL)
        }
        try FileManager.default.moveItem(at: activeURL, to: quarantineURL)
    }

    private func fileURL(
        for key: SurveyAttemptKey,
        namespace: String
    ) -> URL? {
        let baseDirectory: URL?
        if let directory {
            baseDirectory = directory
        } else {
            baseDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent(
                "SurveyDrafts/v1",
                isDirectory: true
            )
        }
        let canonical = [
            key.districtID,
            key.studentID,
            key.assignmentID,
            key.attemptID,
        ].map { value in
            "\(value.utf8.count):\(value)"
        }.joined(separator: "|")
        let name = SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return baseDirectory?
            .appendingPathComponent(namespace, isDirectory: true)
            .appendingPathComponent("\(name).json")
    }
}

actor SurveyRepository {
    typealias LoadActivity = @Sendable (String, StudentModeGrant) async throws -> SurveyActivity
    typealias SendHelpRequest = @Sendable (SurveyHelpRequest, StudentModeGrant) async throws -> Void
    typealias LegacyLoadDraft = @Sendable (SurveyAttemptKey) async -> SurveyResponse?
    typealias LoadDraft = @Sendable (SurveyAttemptKey) async -> SurveyDraftLoad
    typealias SaveDraft = @Sendable (SurveyResponse) async throws -> Void
    typealias PurgeDraft = @Sendable (SurveyAttemptKey) async throws -> Void
    typealias SynchronizeDraft = @Sendable (
        SurveyDraftSyncRequest
    ) async throws -> SurveyResponse
    typealias SubmitResponse = @Sendable (
        SurveySubmissionRequest
    ) async throws -> SurveyResponse
    typealias ReviewResponse = @Sendable (
        SurveyReviewRequest
    ) async throws -> SurveyResponse
    typealias MutateAssignment = @Sendable (
        SurveyAssignmentMutationRequest,
        String
    ) async throws -> SurveyAssignment
    typealias IsOnline = @Sendable () async -> Bool

    private let loadDraft: LoadDraft
    private let loadSurveyActivity: LoadActivity
    private let sendHelpRequest: SendHelpRequest
    private let saveDraft: SaveDraft
    private let quarantineDraft: SaveDraft
    private let purgeDraft: PurgeDraft
    private let synchronizeDraft: SynchronizeDraft
    private let submitResponse: SubmitResponse
    private let reviewResponse: ReviewResponse
    private let performAssignmentMutation: MutateAssignment
    private let isOnline: IsOnline
    private var activeDraftCache: [SurveyAttemptKey: SurveyResponse] = [:]
    private var loadedDraftKeys: Set<SurveyAttemptKey> = []
    private var pendingDraftSaves: [SurveyAttemptKey: Task<Void, Error>] = [:]
    private var terminalDraftErrors: [SurveyAttemptKey: SurveyRepositoryError] = [:]

    init(
        loadActivity: @escaping LoadActivity = { _, _ in throw SurveyRepositoryError.unavailable },
        requestHelp: @escaping SendHelpRequest = { _, _ in throw SurveyRepositoryError.unavailable },
        loadDraft: @escaping LegacyLoadDraft,
        saveDraft: @escaping SaveDraft,
        quarantineDraft: @escaping SaveDraft,
        synchronizeDraft: @escaping SynchronizeDraft,
        submitResponse: @escaping SubmitResponse,
        reviewResponse: @escaping ReviewResponse,
        mutateAssignment: @escaping MutateAssignment = { _, _ in
            throw SurveyRepositoryError.unavailable
        },
        isOnline: @escaping IsOnline
    ) {
        self.loadSurveyActivity = loadActivity
        self.sendHelpRequest = requestHelp
        self.loadDraft = { key in
            if let response = await loadDraft(key) {
                return .draft(response)
            }
            return .missing
        }
        self.saveDraft = saveDraft
        self.quarantineDraft = quarantineDraft
        self.purgeDraft = { _ in }
        self.synchronizeDraft = synchronizeDraft
        self.submitResponse = submitResponse
        self.reviewResponse = reviewResponse
        self.performAssignmentMutation = mutateAssignment
        self.isOnline = isOnline
    }

    init(
        loadActivity: @escaping LoadActivity = { _, _ in throw SurveyRepositoryError.unavailable },
        requestHelp: @escaping SendHelpRequest = { _, _ in throw SurveyRepositoryError.unavailable },
        draftStore: SurveyDraftStore,
        synchronizeDraft: @escaping SynchronizeDraft,
        submitResponse: @escaping SubmitResponse,
        reviewResponse: @escaping ReviewResponse,
        mutateAssignment: @escaping MutateAssignment = { _, _ in
            throw SurveyRepositoryError.unavailable
        },
        isOnline: @escaping IsOnline
    ) {
        self.loadSurveyActivity = loadActivity
        self.sendHelpRequest = requestHelp
        self.loadDraft = draftStore.load
        self.saveDraft = draftStore.save
        self.quarantineDraft = draftStore.quarantine
        self.purgeDraft = draftStore.purge
        self.synchronizeDraft = synchronizeDraft
        self.submitResponse = submitResponse
        self.reviewResponse = reviewResponse
        self.performAssignmentMutation = mutateAssignment
        self.isOnline = isOnline
    }

    func activity(grant: StudentModeGrant) async throws -> SurveyActivity {
        guard grant.scope.allowedOperations.contains(.readAssignment),
              let assignmentID = grant.scope.assignmentIDs.first,
              grant.expiresAt > Date() else {
            throw SurveyRepositoryError.authorization
        }
        let activity = try await loadSurveyActivity(assignmentID, grant)
        guard activity.assignment.assignmentID == assignmentID,
              activity.assignment.districtID == grant.scope.districtID,
              activity.assignment.studentID == grant.scope.studentID,
              activity.assignment.state == .active,
              activity.definition.id == activity.assignment.definitionID,
              activity.definition.version == activity.assignment.definitionVersion else {
            throw SurveyRepositoryError.malformedResponse
        }
        return activity
    }

    func requestHelp(operationID: String, grant: StudentModeGrant) async throws {
        guard Self.isValidIdentifier(operationID),
              grant.scope.allowedOperations.contains(.requestHelp),
              let assignmentID = grant.scope.assignmentIDs.first,
              grant.expiresAt > Date() else {
            throw SurveyRepositoryError.authorization
        }
        try await sendHelpRequest(
            SurveyHelpRequest(
                operationID: operationID,
                districtID: grant.scope.districtID,
                studentID: grant.scope.studentID,
                assignmentID: assignmentID,
                sessionID: grant.sessionID
            ),
            grant
        )
    }

    func autosave(
        answer: SurveyAnswer,
        for questionID: String,
        operationID: String,
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant
    ) async throws -> SurveyResponse {
        try await quarantineIfExpired(
            assignment: assignment,
            grant: grant
        )
        try validate(
            assignment: assignment,
            definition: definition,
            grant: grant,
            operation: .writeDraft
        )
        guard assignment.state == .active else {
            try await quarantineExisting(assignment: assignment)
            throw SurveyRepositoryError.revoked
        }
        guard Self.isValidIdentifier(questionID),
              Self.isValidIdentifier(operationID) else {
            throw SurveyRepositoryError.validation
        }
        let key = attemptKey(for: assignment)
        try ensureAttemptIsMutable(key)
        var response = try await activeDraft(for: key) ?? SurveyResponse(
            assignment: assignment,
            definition: definition
        )
        do {
            try definition.validate(
                answers: [questionID: answer],
                requireVisibleAnswers: false
            )
            let changed = try response.apply(
                answer: answer,
                questionID: questionID,
                operationID: operationID
            )
            if changed {
                try await persistDraftInOrder(response)
            }
            return activeDraftCache[key] ?? response
        } catch SurveyResponseMutationError.immutable {
            throw SurveyRepositoryError.immutableResponse
        } catch is SurveyDefinitionError {
            throw SurveyRepositoryError.validation
        } catch {
            throw map(error)
        }
    }

    func resume(
        assignment: SurveyAssignment,
        grant: StudentModeGrant
    ) async throws -> SurveyResponse? {
        try await quarantineIfExpired(
            assignment: assignment,
            grant: grant
        )
        try validateScope(
            assignment: assignment,
            grant: grant,
            operation: .writeDraft
        )
        guard assignment.state == .active else {
            try await quarantineExisting(assignment: assignment)
            throw SurveyRepositoryError.revoked
        }
        return try await activeDraft(for: assignment.attemptKey)
    }

    func synchronize(
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant
    ) async throws -> SurveyResponse {
        try await quarantineIfExpired(
            assignment: assignment,
            grant: grant
        )
        try validate(
            assignment: assignment,
            definition: definition,
            grant: grant,
            operation: .writeDraft
        )
        guard assignment.state == .active else {
            try await quarantineExisting(assignment: assignment)
            throw SurveyRepositoryError.revoked
        }
        guard await isOnline() else {
            throw SurveyRepositoryError.offline
        }
        guard let draft = try await activeDraft(for: assignment.attemptKey) else {
            throw SurveyRepositoryError.validation
        }
        do {
            try definition.validate(
                answers: draft.answers,
                requireVisibleAnswers: false
            )
            let synchronized = try await synchronizeDraft(
                SurveyDraftSyncRequest(
                    response: draft,
                    definition: definition,
                    sessionID: grant.sessionID
                )
            )
            try validateServerResponse(
                synchronized,
                prior: draft,
                allowsState: .draft
            )
            try await persistDraftInOrder(synchronized)
            return synchronized
        } catch {
            let mapped = map(error)
            if mapped == .revoked || mapped == .expired {
                var quarantined = draft
                quarantined.quarantine(
                    mapped == .revoked
                        ? .assignmentRevoked
                        : .authorizationRejected
                )
                try await persistQuarantineInOrder(quarantined)
            }
            throw mapped
        }
    }

    func submit(
        operationID: String,
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant
    ) async throws -> SurveyResponse {
        try await quarantineIfExpired(
            assignment: assignment,
            grant: grant
        )
        try validate(
            assignment: assignment,
            definition: definition,
            grant: grant,
            operation: .submitAssignment
        )
        guard assignment.state == .active else {
            try await quarantineExisting(assignment: assignment)
            throw SurveyRepositoryError.revoked
        }
        guard Self.isValidIdentifier(operationID),
              var draft = try await activeDraft(for: assignment.attemptKey) else {
            throw SurveyRepositoryError.validation
        }
        if draft.state != .draft {
            if draft.serverMetadata?.submissionOperationID == operationID {
                return draft
            }
            throw SurveyRepositoryError.immutableResponse
        }
        do {
            try draft.validateNewOperationID(operationID)
        } catch {
            throw map(error)
        }
        guard await isOnline() else {
            throw SurveyRepositoryError.offline
        }
        do {
            if draft.hasPendingChanges {
                draft = try await synchronize(
                    assignment: assignment,
                    definition: definition,
                    grant: grant
                )
            }
            try definition.validate(
                answers: draft.answers,
                requireVisibleAnswers: true
            )
            let submitted = try await submitResponse(
                SurveySubmissionRequest(
                    response: draft,
                    definition: definition,
                    sessionID: grant.sessionID,
                    operationID: operationID
                )
            )
            try validateServerResponse(
                submitted,
                prior: draft,
                allowsState: .submitted
            )
            guard submitted.answers == draft.answers,
                  submitted.frozenDefinition == definition,
                  submitted.submittedAt != nil else {
                throw SurveyRepositoryError.malformedResponse
            }
            try await persistDraftInOrder(submitted)
            return submitted
        } catch is SurveyDefinitionError {
            throw SurveyRepositoryError.validation
        } catch {
            let mapped = map(error)
            if mapped == .revoked || mapped == .expired {
                var quarantined = draft
                quarantined.quarantine(
                    mapped == .revoked
                        ? .assignmentRevoked
                        : .authorizationRejected
                )
                try await persistQuarantineInOrder(quarantined)
            }
            throw mapped
        }
    }

    func review(
        response: SurveyResponse,
        operationID: String,
        staffIdentity: StudentModeStaffIdentity
    ) async throws -> SurveyResponse {
        guard response.districtID == staffIdentity.districtID,
              staffIdentity.membershipVersion > 0,
              Self.isValidIdentifier(staffIdentity.userID),
              Self.isValidIdentifier(operationID) else {
            throw SurveyRepositoryError.authorization
        }
        guard response.state == .submitted else {
            if response.state == .reviewed,
               response.serverMetadata?.reviewOperationID == operationID {
                return response
            }
            throw SurveyRepositoryError.immutableResponse
        }
        do {
            try response.validateNewOperationID(operationID)
        } catch {
            throw map(error)
        }
        guard await isOnline() else {
            throw SurveyRepositoryError.offline
        }
        do {
            let reviewed = try await reviewResponse(
                SurveyReviewRequest(
                    response: response,
                    operationID: operationID,
                    staffIdentity: staffIdentity
                )
            )
            try validateServerResponse(
                reviewed,
                prior: response,
                allowsState: .reviewed
            )
            guard reviewed.answers == response.answers,
                  reviewed.frozenDefinition == response.frozenDefinition else {
                throw SurveyRepositoryError.malformedResponse
            }
            try await persistDraftInOrder(reviewed)
            return reviewed
        } catch {
            throw map(error)
        }
    }

    func mutateAssignment(
        _ request: SurveyAssignmentMutationRequest,
        districtID: String
    ) async throws -> SurveyAssignment {
        guard Self.isValidIdentifier(districtID),
              Self.isValidIdentifier(request.assignmentID),
              Self.isValidIdentifier(request.studentID),
              Self.isValidIdentifier(request.definitionID),
              Self.isValidIdentifier(request.operationID),
              !request.reasonCode.isEmpty,
              request.definitionVersion > 0,
              (request.action == .create
                ? request.expectedRecordVersion == 0
                : request.expectedRecordVersion > 0) else {
            throw SurveyRepositoryError.validation
        }
        guard await isOnline() else {
            throw SurveyRepositoryError.offline
        }
        do {
            let assignment = try await performAssignmentMutation(
                request,
                districtID
            )
            guard assignment.assignmentID == request.assignmentID,
                  assignment.districtID == districtID,
                  assignment.studentID == request.studentID,
                  assignment.definitionID == request.definitionID,
                  assignment.definitionVersion == request.definitionVersion,
                  assignment.recordVersion == request.expectedRecordVersion + 1,
                  assignment.state == (request.action == .revoke
                    ? .revoked
                    : .active) else {
                throw SurveyRepositoryError.malformedResponse
            }
            return assignment
        } catch {
            throw map(error)
        }
    }

    private func validate(
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant,
        operation: StudentModeOperation
    ) throws {
        try validateScope(
            assignment: assignment,
            grant: grant,
            operation: operation
        )
        guard assignment.definitionID == definition.id,
              assignment.definitionVersion == definition.version else {
            throw SurveyRepositoryError.conflict
        }
    }

    private func validateScope(
        assignment: SurveyAssignment,
        grant: StudentModeGrant,
        operation: StudentModeOperation
    ) throws {
        guard grant.scope.districtID == assignment.districtID,
              grant.scope.studentID == assignment.studentID,
              grant.scope.assignmentIDs == [assignment.assignmentID],
              grant.scope.allowedOperations.contains(operation),
              grant.expiresAt > Date(),
              Self.isValidIdentifier(grant.sessionID) else {
            throw SurveyRepositoryError.authorization
        }
    }

    private func validateServerResponse(
        _ response: SurveyResponse,
        prior: SurveyResponse,
        allowsState state: SurveyResponseState
    ) throws {
        guard response.attemptKey == prior.attemptKey,
              response.definitionID == prior.definitionID,
              response.definitionVersion == prior.definitionVersion,
              response.state == state,
              response.recordVersion >= prior.recordVersion else {
            throw SurveyRepositoryError.malformedResponse
        }
    }

    private func quarantineExisting(
        assignment: SurveyAssignment,
        reason: SurveyQuarantineReason = .assignmentRevoked
    ) async throws {
        let key = assignment.attemptKey
        terminalDraftErrors[key] = reason == .assignmentRevoked ? .revoked : .expired
        let existingResponse: SurveyResponse?
        if let cached = activeDraftCache[key] {
            existingResponse = cached
        } else if case .draft(let loaded) = await loadDraft(key) {
            existingResponse = loaded
        } else {
            existingResponse = nil
        }
        guard var existing = existingResponse else {
            return
        }
        existing.quarantine(reason)
        do {
            try await persistQuarantineInOrder(existing)
        } catch {
            throw map(error)
        }
    }

    private func quarantineIfExpired(
        assignment: SurveyAssignment,
        grant: StudentModeGrant
    ) async throws {
        guard grant.expiresAt <= Date() else { return }
        if grant.scope.districtID == assignment.districtID,
           grant.scope.studentID == assignment.studentID,
           grant.scope.assignmentIDs == [assignment.assignmentID] {
            try await quarantineExisting(
                assignment: assignment,
                reason: .authorizationRejected
            )
        }
        throw SurveyRepositoryError.expired
    }

    func purge(assignment: SurveyAssignment) async throws {
        do {
            let key = assignment.attemptKey
            terminalDraftErrors[key] = .revoked
            _ = try? await pendingDraftSaves[key]?.value
            try await purgeDraft(key)
            activeDraftCache[key] = nil
            loadedDraftKeys.remove(key)
            pendingDraftSaves[key] = nil
        } catch {
            throw map(error)
        }
    }

    private func activeDraft(
        for key: SurveyAttemptKey
    ) async throws -> SurveyResponse? {
        try ensureAttemptIsMutable(key)
        if let cached = activeDraftCache[key] {
            return cached
        }
        if loadedDraftKeys.contains(key) {
            return nil
        }
        let loaded = await loadDraft(key)
        try ensureAttemptIsMutable(key)
        if let cached = activeDraftCache[key] {
            return cached
        }
        if loadedDraftKeys.contains(key) {
            return nil
        }
        loadedDraftKeys.insert(key)
        switch loaded {
        case .missing:
            return nil
        case .draft(let response):
            activeDraftCache[key] = response
            return response
        case .quarantined(let reason):
            switch reason {
            case .assignmentRevoked:
                throw SurveyRepositoryError.revoked
            case .authorizationRejected:
                throw SurveyRepositoryError.expired
            case .malformedServerResponse:
                throw SurveyRepositoryError.malformedResponse
            }
        case .scopeMismatch:
            throw SurveyRepositoryError.authorization
        case .corrupt:
            throw SurveyRepositoryError.malformedResponse
        }
    }

    private func persistDraftInOrder(_ response: SurveyResponse) async throws {
        let key = response.attemptKey
        try ensureAttemptIsMutable(key)
        activeDraftCache[key] = response
        let previousSave = pendingDraftSaves[key]
        let saveDraft = self.saveDraft
        let task = Task {
            if let previousSave {
                _ = try? await previousSave.value
            }
            try await saveDraft(response)
        }
        pendingDraftSaves[key] = task
        try await task.value
        try ensureAttemptIsMutable(key)
    }

    private func persistQuarantineInOrder(_ response: SurveyResponse) async throws {
        let key = response.attemptKey
        let reason: SurveyQuarantineReason
        if case .quarantined(let storedReason) = response.syncState {
            reason = storedReason
        } else {
            reason = .assignmentRevoked
        }
        terminalDraftErrors[key] = reason == .assignmentRevoked ? .revoked : .expired
        _ = try? await pendingDraftSaves[key]?.value
        var terminalResponse = activeDraftCache[key] ?? response
        terminalResponse.quarantine(reason)
        try await quarantineDraft(terminalResponse)
        activeDraftCache[key] = nil
        loadedDraftKeys.remove(key)
        pendingDraftSaves[key] = nil
    }

    private func ensureAttemptIsMutable(_ key: SurveyAttemptKey) throws {
        if let terminalError = terminalDraftErrors[key] {
            throw terminalError
        }
    }

    private func attemptKey(for assignment: SurveyAssignment) -> SurveyAttemptKey {
        SurveyAttemptKey(
            districtID: assignment.districtID,
            studentID: assignment.studentID,
            assignmentID: assignment.assignmentID,
            attemptID: assignment.attemptID
        )
    }

    private func map(_ error: Error) -> SurveyRepositoryError {
        if let repositoryError = error as? SurveyRepositoryError {
            return repositoryError
        }
        if error is CancellationError {
            return .cancelled
        }
        if error is SurveyDefinitionError {
            return .validation
        }
        if let mutationError = error as? SurveyResponseMutationError,
           mutationError == .historyLimitReached {
            return .historyLimitReached
        }
        if error is SurveyResponseMutationError {
            return .immutableResponse
        }
        return .unavailable
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= SurveyResponse.maximumOperationIDBytes &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

extension SurveyRepository {
    @MainActor
    static func firebase(
        draftStore: SurveyDraftStore = .localFiles(),
        staffFunctions: Functions = Functions.functions(region: "us-central1")
    ) -> SurveyRepository {
        guard FeatureFlags.production.usesTrustedMutationCallables else {
            return .firestoreDirect(draftStore: draftStore)
        }
        guard let respondentApp = FirebaseApp.app(
            name: "TMIStudentModeRespondent"
        ) else {
            preconditionFailure(
                "An active Student Mode respondent session is required."
            )
        }
        let respondentFunctions = Functions.functions(
            app: respondentApp,
            region: "us-central1"
        )
        let runtime = FirebaseSurveyRuntime(
            respondentFunctions: respondentFunctions,
            staffFunctions: staffFunctions
        )
        let connectivity = SurveyConnectivity()
        return SurveyRepository(
            loadActivity: { assignmentID, grant in
                try await runtime.loadActivity(assignmentID: assignmentID, grant: grant)
            },
            requestHelp: { request, grant in
                try await runtime.requestHelp(request, grant: grant)
            },
            draftStore: draftStore,
            synchronizeDraft: { request in
                try await runtime.synchronize(request)
            },
            submitResponse: { request in
                try await runtime.submit(request)
            },
            reviewResponse: { request in
                try await runtime.review(request)
            },
            mutateAssignment: { request, districtID in
                try await runtime.mutateAssignment(
                    request,
                    districtID: districtID
                )
            },
            isOnline: {
                connectivity.isOnline
            }
        )
    }
}

extension SurveyRepository {
    /// Survey persistence without the Cloud Functions callables. Draft sync and
    /// submission go straight to Firestore under the acting educator's session;
    /// staff review and assignment mutation stay unavailable because they have
    /// no client-authorized path.
    @MainActor
    static func firestoreDirect(
        draftStore: SurveyDraftStore = .localFiles(),
        firestore: Firestore = Firestore.firestore()
    ) -> SurveyRepository {
        let runtime = FirestoreDirectSurveyRuntime(firestore: firestore)
        let connectivity = SurveyConnectivity()
        return SurveyRepository(
            requestHelp: { request, grant in
                try await runtime.requestHelp(request, grant: grant)
            },
            draftStore: draftStore,
            synchronizeDraft: { request in
                try await runtime.synchronize(request)
            },
            submitResponse: { request in
                try await runtime.submit(request)
            },
            reviewResponse: { _ in
                throw SurveyRepositoryError.unavailable
            },
            isOnline: {
                connectivity.isOnline
            }
        )
    }
}

private nonisolated final class SurveyConnectivity: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tmi.surveys.connectivity")
    private let lock = NSLock()
    private var currentIsOnline = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.currentIsOnline = path.status == .satisfied
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentIsOnline
    }
}

nonisolated enum SurveyFirebaseErrorMapper {
    static func map(_ error: Error) -> SurveyRepositoryError {
        if let repositoryError = error as? SurveyRepositoryError {
            return repositoryError
        }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return error is CancellationError ? .cancelled : .unavailable
        }
        let details = nsError.userInfo[FunctionsErrorDetailsKey]
            as? [String: Any]
        let kind = details?["kind"] as? String
        let message = nsError.localizedDescription.lowercased()
        switch code {
        case .cancelled:
            return .cancelled
        case .invalidArgument, .outOfRange:
            return .validation
        case .permissionDenied, .unauthenticated:
            return .authorization
        case .aborted, .alreadyExists:
            return .conflict
        case .resourceExhausted:
            return .historyLimitReached
        case .failedPrecondition:
            if kind == "survey-session-expired" {
                return .expired
            }
            if kind == "survey-session-revoked" ||
                kind == "survey-assignment-revoked" {
                return .revoked
            }
            if message.contains("expired") {
                return .expired
            }
            if message.contains("revoked") || message.contains("assignment") {
                return .revoked
            }
            if message.contains("required") || message.contains("malformed") {
                return .validation
            }
            if message.contains("edited") || message.contains("state") {
                return .immutableResponse
            }
            return .conflict
        case .unavailable, .deadlineExceeded:
            return .unavailable
        case .dataLoss, .internal:
            return .malformedResponse
        default:
            return .unavailable
        }
    }
}

nonisolated enum SurveyAssignmentMutationResultDecoder {
    static func decode(
        _ data: [String: Any],
        request: SurveyAssignmentMutationRequest,
        districtID: String
    ) throws -> SurveyAssignment {
        let expectedResultKeys: Set<String> = [
            "operationID", "recordVersion", "replayed", "assignment",
        ]
        let expectedAssignmentKeys: Set<String> = [
            "schemaVersion", "recordVersion", "assignmentID", "attemptID",
            "districtID", "studentID", "definitionID", "definitionVersion",
            "state", "assignedAt", "revokedAt",
        ]
        guard Set(data.keys) == expectedResultKeys,
              data["operationID"] as? String == request.operationID,
              data["replayed"] is Bool,
              let resultVersion = integer(data["recordVersion"]),
              let assignment = data["assignment"] as? [String: Any],
              Set(assignment.keys) == expectedAssignmentKeys,
              integer(assignment["schemaVersion"]) == 1,
              let recordVersion = integer(assignment["recordVersion"]),
              resultVersion == recordVersion,
              recordVersion == request.expectedRecordVersion + 1,
              assignment["assignmentID"] as? String == request.assignmentID,
              let attemptID = assignment["attemptID"] as? String,
              assignment["districtID"] as? String == districtID,
              assignment["studentID"] as? String == request.studentID,
              assignment["definitionID"] as? String == request.definitionID,
              integer(assignment["definitionVersion"]) == request.definitionVersion,
              let stateValue = assignment["state"] as? String,
              let state = SurveyAssignmentState(rawValue: stateValue),
              state == expectedState(for: request.action),
              let assignedAt = date(assignment["assignedAt"]) else {
            throw SurveyRepositoryError.malformedResponse
        }

        let revokedAt: Date?
        switch state {
        case .active:
            guard assignment["revokedAt"] is NSNull else {
                throw SurveyRepositoryError.malformedResponse
            }
            revokedAt = nil
        case .revoked:
            guard let parsed = date(assignment["revokedAt"]),
                  parsed >= assignedAt else {
                throw SurveyRepositoryError.malformedResponse
            }
            revokedAt = parsed
        }

        do {
            return try SurveyAssignment(
                assignmentID: request.assignmentID,
                attemptID: attemptID,
                districtID: districtID,
                studentID: request.studentID,
                definitionID: request.definitionID,
                definitionVersion: request.definitionVersion,
                state: state,
                recordVersion: recordVersion,
                assignedAt: assignedAt,
                revokedAt: revokedAt
            )
        } catch {
            throw SurveyRepositoryError.malformedResponse
        }
    }

    private static func expectedState(
        for action: SurveyAssignmentMutationAction
    ) -> SurveyAssignmentState {
        action == .revoke ? .revoked : .active
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber, !(value is Bool) {
            return value.intValue
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

nonisolated enum SurveyReviewCallableResultDecoder {
    static func decode(
        _ data: [String: Any],
        request: SurveyReviewRequest
    ) throws -> SurveyResponse {
        let expectedKeys: Set<String> = [
            "operationID", "recordVersion", "replayed", "reviewedAt",
            "reviewerUserID",
        ]
        guard Set(data.keys) == expectedKeys,
              data["operationID"] as? String == request.operationID,
              data["replayed"] is Bool,
              let recordVersion = integer(data["recordVersion"]),
              recordVersion == request.response.recordVersion + 1,
              let reviewedAt = date(data["reviewedAt"]),
              let reviewerUserID = data["reviewerUserID"] as? String,
              isValidIdentifier(reviewerUserID) else {
            throw SurveyRepositoryError.malformedResponse
        }
        var response = request.response
        do {
            try response.markReviewed(
                operationID: request.operationID,
                reviewerID: reviewerUserID,
                reviewedAt: reviewedAt,
                serverRecordVersion: recordVersion
            )
            return response
        } catch {
            throw SurveyRepositoryError.malformedResponse
        }
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value != "." &&
            value != ".." &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= 1_500 &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber, !(value is Bool) {
            return value.intValue
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

@MainActor
private final class FirebaseSurveyRuntime: @unchecked Sendable {
    private let respondentFunctions: Functions
    private let staffFunctions: Functions

    init(respondentFunctions: Functions, staffFunctions: Functions) {
        self.respondentFunctions = respondentFunctions
        self.staffFunctions = staffFunctions
    }

    func loadActivity(assignmentID: String, grant: StudentModeGrant) async throws -> SurveyActivity {
        do {
            let result = try await respondentFunctions
                .httpsCallable("loadSurveyActivity")
                .call(["assignmentID": assignmentID, "sessionID": grant.sessionID])
            guard let object = result.data as? [String: Any],
                  let assignmentObject = object["assignment"],
                  let definitionObject = object["definition"] else {
                throw SurveyRepositoryError.malformedResponse
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let assignment = try decoder.decode(
                SurveyAssignment.self,
                from: JSONSerialization.data(withJSONObject: assignmentObject)
            )
            let definition = try decoder.decode(
                SurveyDefinition.self,
                from: JSONSerialization.data(withJSONObject: definitionObject)
            )
            return SurveyActivity(assignment: assignment, definition: definition)
        } catch {
            throw SurveyFirebaseErrorMapper.map(error)
        }
    }

    func requestHelp(_ request: SurveyHelpRequest, grant: StudentModeGrant) async throws {
        do {
            let result = try await respondentFunctions
                .httpsCallable("requestStudentModeHelp")
                .call([
                    "districtID": request.districtID,
                    "studentID": request.studentID,
                    "assignmentID": request.assignmentID,
                    "sessionID": request.sessionID,
                    "operationID": request.operationID,
                ])
            guard let data = result.data as? [String: Any], data["accepted"] as? Bool == true else {
                throw SurveyRepositoryError.malformedResponse
            }
        } catch {
            throw SurveyFirebaseErrorMapper.map(error)
        }
    }

    func synchronize(
        _ request: SurveyDraftSyncRequest
    ) async throws -> SurveyResponse {
        let operationID = "sync-\(request.response.attemptID)-\(request.response.recordVersion)"
        let result = try await call(
            functions: respondentFunctions,
            name: "saveSurveyDraft",
            payload: payload(
                response: request.response,
                operationID: operationID
            )
        )
        var response = request.response
        response.markSynchronized(serverRecordVersion: result.recordVersion)
        return response
    }

    func submit(
        _ request: SurveySubmissionRequest
    ) async throws -> SurveyResponse {
        let result = try await call(
            functions: respondentFunctions,
            name: "submitSurveyResponse",
            payload: payload(
                response: request.response,
                operationID: request.operationID
            )
        )
        guard let submittedAt = result.timestamp else {
            throw SurveyRepositoryError.malformedResponse
        }
        var response = request.response
        do {
            try response.markSubmitted(
                operationID: request.operationID,
                submittedAt: submittedAt,
                serverRecordVersion: result.recordVersion,
                definition: request.definition,
                sessionID: request.sessionID
            )
        } catch {
            throw SurveyRepositoryError.malformedResponse
        }
        return response
    }

    func review(
        _ request: SurveyReviewRequest
    ) async throws -> SurveyResponse {
        do {
            let result = try await staffFunctions
                .httpsCallable("reviewSurveyResponse")
                .call([
                "districtID": request.response.districtID,
                "studentID": request.response.studentID,
                "responseID": request.response.responseID,
                "expectedRecordVersion": request.response.recordVersion,
                "idempotencyKey": request.operationID,
                "reasonCode": "educator-survey-review",
                ])
            guard let data = result.data as? [String: Any] else {
                throw SurveyRepositoryError.malformedResponse
            }
            return try SurveyReviewCallableResultDecoder.decode(
                data,
                request: request
            )
        } catch {
            throw SurveyFirebaseErrorMapper.map(error)
        }
    }

    func mutateAssignment(
        _ request: SurveyAssignmentMutationRequest,
        districtID: String
    ) async throws -> SurveyAssignment {
        do {
            let result = try await staffFunctions
                .httpsCallable("mutateSurveyAssignment")
                .call([
                    "districtID": districtID,
                    "action": request.action.rawValue,
                    "assignmentID": request.assignmentID,
                    "studentID": request.studentID,
                    "definitionID": request.definitionID,
                    "definitionVersion": request.definitionVersion,
                    "expectedRecordVersion": request.expectedRecordVersion,
                    "idempotencyKey": request.operationID,
                    "reasonCode": request.reasonCode,
                ])
            guard let data = result.data as? [String: Any] else {
                throw SurveyRepositoryError.malformedResponse
            }
            return try SurveyAssignmentMutationResultDecoder.decode(
                data,
                request: request,
                districtID: districtID
            )
        } catch {
            throw SurveyFirebaseErrorMapper.map(error)
        }
    }

    private func payload(
        response: SurveyResponse,
        operationID: String
    ) -> [String: Any] {
        [
            "districtID": response.districtID,
            "studentID": response.studentID,
            "assignmentID": response.assignmentID,
            "attemptID": response.attemptID,
            "definitionID": response.definitionID,
            "definitionVersion": response.definitionVersion,
            "expectedRecordVersion": response.recordVersion,
            "operationID": operationID,
            "answers": response.answers.mapValues { answer in
                Self.payload(answer: answer)
            },
        ]
    }

    private static func payload(answer: SurveyAnswer) -> [String: Any] {
        switch answer {
        case .single(let value):
            return ["type": "single", "value": value]
        case .multiple(let values):
            return ["type": "multiple", "value": values.sorted()]
        case .text(let value):
            return ["type": "text", "value": value]
        case .rating(let value):
            return ["type": "rating", "value": value]
        case .image(let value):
            return ["type": "image", "value": value]
        }
    }

    private func call(
        functions: Functions,
        name: String,
        payload: sending [String: Any]
    ) async throws -> SurveyCallableResult {
        do {
            let result = try await functions
                .httpsCallable(name)
                .call(payload)
            guard let data = result.data as? [String: Any],
                  let recordVersion = Self.integer(data["recordVersion"]),
                  recordVersion > 0,
                  data["replayed"] is Bool else {
                throw SurveyRepositoryError.malformedResponse
            }
            let timestamp = Self.date(
                data["submittedAt"] ?? data["reviewedAt"]
            )
            return SurveyCallableResult(
                recordVersion: recordVersion,
                timestamp: timestamp
            )
        } catch {
            throw SurveyFirebaseErrorMapper.map(error)
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber, !(value is Bool) {
            return value.intValue
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

}

private nonisolated struct SurveyCallableResult: Sendable {
    let recordVersion: Int
    let timestamp: Date?
}
