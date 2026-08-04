import Foundation

nonisolated enum SurveyAnswer: Codable, Equatable, Sendable {
    case single(String)
    case multiple(Set<String>)
    case text(String)
    case rating(Int)
    case image(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Kind: String, Codable {
        case single
        case multiple
        case text
        case rating
        case image
    }

    var isMeaningful: Bool {
        switch self {
        case .single(let value), .image(let value):
            return !value.isEmpty
        case .multiple(let values):
            return !values.isEmpty
        case .text(let value):
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .rating:
            return true
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .single(let value):
            try container.encode(Kind.single, forKey: .type)
            try container.encode(value, forKey: .value)
        case .multiple(let value):
            try container.encode(Kind.multiple, forKey: .type)
            try container.encode(value.sorted(), forKey: .value)
        case .text(let value):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .rating(let value):
            try container.encode(Kind.rating, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let value):
            try container.encode(Kind.image, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .single:
            self = .single(try container.decode(String.self, forKey: .value))
        case .multiple:
            let values = try container.decode([String].self, forKey: .value)
            guard Set(values).count == values.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: container,
                    debugDescription: "Multiple-choice answers cannot repeat options."
                )
            }
            self = .multiple(Set(values))
        case .text:
            self = .text(try container.decode(String.self, forKey: .value))
        case .rating:
            self = .rating(try container.decode(Int.self, forKey: .value))
        case .image:
            self = .image(try container.decode(String.self, forKey: .value))
        }
    }
}

nonisolated enum SurveyResponseState: String, Codable, Equatable, Sendable {
    case draft
    case submitted
    case reviewed
}

nonisolated enum SurveyQuarantineReason: String, Codable, Equatable, Sendable {
    case assignmentRevoked
    case authorizationRejected
    case malformedServerResponse
}

nonisolated enum SurveySyncState: Codable, Equatable, Sendable {
    case synced
    case pending
    case quarantined(SurveyQuarantineReason)
}

nonisolated struct SurveyAttemptKey: Codable, Hashable, Sendable {
    let districtID: String
    let studentID: String
    let assignmentID: String
    let attemptID: String
}

nonisolated struct SurveySourceHistory: Codable, Equatable, Sendable {
    let definitionID: String
    let definitionVersion: Int
    let assignmentID: String
    let attemptID: String
    let respondentSessionID: String
}

nonisolated struct SurveyServerMetadata: Codable, Equatable, Sendable {
    let submissionOperationID: String
    let reviewedBy: String?
    let reviewOperationID: String?
}

nonisolated enum SurveyResponseMutationError: Error, Equatable, Sendable {
    case immutable
    case invalidTransition
    case invalidRecordVersion
    case invalidOperationID
    case historyLimitReached
}

nonisolated struct SurveyResponse: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumOperationCount = 128
    static let maximumOperationIDBytes = 128

    let schemaVersion: Int
    let responseID: String
    let districtID: String
    let studentID: String
    let assignmentID: String
    let attemptID: String
    let definitionID: String
    let definitionVersion: Int
    private(set) var state: SurveyResponseState
    private(set) var recordVersion: Int
    private(set) var localRevision: Int
    private(set) var answers: [String: SurveyAnswer]
    private(set) var operationIDs: Set<String>
    private(set) var syncState: SurveySyncState
    private(set) var hasPendingChanges: Bool
    private(set) var submittedAt: Date?
    private(set) var reviewedAt: Date?
    private(set) var frozenDefinition: SurveyDefinition?
    private(set) var sourceHistory: SurveySourceHistory?
    private(set) var serverMetadata: SurveyServerMetadata?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case responseID
        case districtID
        case studentID
        case assignmentID
        case attemptID
        case definitionID
        case definitionVersion
        case state
        case recordVersion
        case answers
        case operationIDs
        case syncState
        case quarantineReason
        case hasPendingChanges
        case submittedAt
        case reviewedAt
        case frozenDefinition
        case sourceHistory
        case serverMetadata
    }

    var attemptKey: SurveyAttemptKey {
        SurveyAttemptKey(
            districtID: districtID,
            studentID: studentID,
            assignmentID: assignmentID,
            attemptID: attemptID
        )
    }

    init(
        assignment: SurveyAssignment,
        definition: SurveyDefinition
    ) {
        schemaVersion = Self.currentSchemaVersion
        responseID = assignment.attemptID
        districtID = assignment.districtID
        studentID = assignment.studentID
        assignmentID = assignment.assignmentID
        attemptID = assignment.attemptID
        definitionID = definition.id
        definitionVersion = definition.version
        state = .draft
        recordVersion = 0
        localRevision = 0
        answers = [:]
        operationIDs = []
        syncState = .synced
        hasPendingChanges = false
        submittedAt = nil
        reviewedAt = nil
        frozenDefinition = nil
        sourceHistory = nil
        serverMetadata = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        responseID = try container.decode(String.self, forKey: .responseID)
        districtID = try container.decode(String.self, forKey: .districtID)
        studentID = try container.decode(String.self, forKey: .studentID)
        assignmentID = try container.decode(String.self, forKey: .assignmentID)
        attemptID = try container.decode(String.self, forKey: .attemptID)
        definitionID = try container.decode(String.self, forKey: .definitionID)
        definitionVersion = try container.decode(Int.self, forKey: .definitionVersion)
        state = try container.decode(SurveyResponseState.self, forKey: .state)
        recordVersion = try container.decode(Int.self, forKey: .recordVersion)
        localRevision = 0
        answers = try container.decode(
            [String: SurveyAnswer].self,
            forKey: .answers
        )
        let decodedOperationIDs = try container.decode(
            [String].self,
            forKey: .operationIDs
        )
        guard schemaVersion == Self.currentSchemaVersion,
              recordVersion >= 0,
              answers.count <= 100,
              decodedOperationIDs.count <= Self.maximumOperationCount,
              Set(decodedOperationIDs).count == decodedOperationIDs.count,
              decodedOperationIDs.allSatisfy(Self.isValidOperationID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .operationIDs,
                in: container,
                debugDescription: "The canonical survey response is malformed."
            )
        }
        operationIDs = Set(decodedOperationIDs)
        let syncValue = try container.decode(String.self, forKey: .syncState)
        switch syncValue {
        case "synced":
            syncState = .synced
        case "pending":
            syncState = .pending
        case "quarantined":
            syncState = .quarantined(
                try container.decode(
                    SurveyQuarantineReason.self,
                    forKey: .quarantineReason
                )
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .syncState,
                in: container,
                debugDescription: "Unknown survey synchronization state."
            )
        }
        hasPendingChanges = try container.decode(
            Bool.self,
            forKey: .hasPendingChanges
        )
        submittedAt = try container.decodeIfPresent(Date.self, forKey: .submittedAt)
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        frozenDefinition = try container.decodeIfPresent(
            SurveyDefinition.self,
            forKey: .frozenDefinition
        )
        sourceHistory = try container.decodeIfPresent(
            SurveySourceHistory.self,
            forKey: .sourceHistory
        )
        serverMetadata = try container.decodeIfPresent(
            SurveyServerMetadata.self,
            forKey: .serverMetadata
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(responseID, forKey: .responseID)
        try container.encode(districtID, forKey: .districtID)
        try container.encode(studentID, forKey: .studentID)
        try container.encode(assignmentID, forKey: .assignmentID)
        try container.encode(attemptID, forKey: .attemptID)
        try container.encode(definitionID, forKey: .definitionID)
        try container.encode(definitionVersion, forKey: .definitionVersion)
        try container.encode(state, forKey: .state)
        try container.encode(recordVersion, forKey: .recordVersion)
        try container.encode(answers, forKey: .answers)
        try container.encode(operationIDs.sorted(), forKey: .operationIDs)
        switch syncState {
        case .synced:
            try container.encode("synced", forKey: .syncState)
        case .pending:
            try container.encode("pending", forKey: .syncState)
        case .quarantined(let reason):
            try container.encode("quarantined", forKey: .syncState)
            try container.encode(reason, forKey: .quarantineReason)
        }
        try container.encode(hasPendingChanges, forKey: .hasPendingChanges)
        try container.encodeIfPresent(submittedAt, forKey: .submittedAt)
        try container.encodeIfPresent(reviewedAt, forKey: .reviewedAt)
        try container.encodeIfPresent(frozenDefinition, forKey: .frozenDefinition)
        try container.encodeIfPresent(sourceHistory, forKey: .sourceHistory)
        try container.encodeIfPresent(serverMetadata, forKey: .serverMetadata)
    }

    mutating func apply(
        answer: SurveyAnswer,
        questionID: String,
        operationID: String
    ) throws -> Bool {
        guard state == .draft else {
            throw SurveyResponseMutationError.immutable
        }
        if operationIDs.contains(operationID) {
            return false
        }
        guard Self.isValidOperationID(operationID) else {
            throw SurveyResponseMutationError.invalidOperationID
        }
        guard operationIDs.count < Self.maximumOperationCount else {
            throw SurveyResponseMutationError.historyLimitReached
        }
        answers[questionID] = answer
        operationIDs.insert(operationID)
        localRevision += 1
        syncState = .pending
        hasPendingChanges = true
        return true
    }

    mutating func markSynchronized(serverRecordVersion: Int) {
        recordVersion = serverRecordVersion
        syncState = .synced
        hasPendingChanges = false
    }

    mutating func restoreLocalRevision(_ revision: Int) {
        localRevision = revision
    }

    mutating func quarantine(_ reason: SurveyQuarantineReason) {
        syncState = .quarantined(reason)
        hasPendingChanges = true
    }

    mutating func markSubmitted(
        operationID: String,
        submittedAt: Date,
        serverRecordVersion: Int,
        definition: SurveyDefinition,
        sessionID: String
    ) throws {
        guard state == .draft else {
            if serverMetadata?.submissionOperationID == operationID {
                return
            }
            throw SurveyResponseMutationError.immutable
        }
        guard serverRecordVersion > recordVersion else {
            throw SurveyResponseMutationError.invalidRecordVersion
        }
        try validateNewOperationID(operationID)
        state = .submitted
        recordVersion = serverRecordVersion
        operationIDs.insert(operationID)
        syncState = .synced
        hasPendingChanges = false
        self.submittedAt = submittedAt
        frozenDefinition = definition
        sourceHistory = SurveySourceHistory(
            definitionID: definitionID,
            definitionVersion: definitionVersion,
            assignmentID: assignmentID,
            attemptID: attemptID,
            respondentSessionID: sessionID
        )
        serverMetadata = SurveyServerMetadata(
            submissionOperationID: operationID,
            reviewedBy: nil,
            reviewOperationID: nil
        )
    }

    mutating func markReviewed(
        operationID: String,
        reviewerID: String,
        reviewedAt: Date,
        serverRecordVersion: Int
    ) throws {
        if state == .reviewed,
           serverMetadata?.reviewOperationID == operationID {
            return
        }
        guard state == .submitted else {
            throw SurveyResponseMutationError.invalidTransition
        }
        guard serverRecordVersion > recordVersion,
              let metadata = serverMetadata else {
            throw SurveyResponseMutationError.invalidRecordVersion
        }
        try validateNewOperationID(operationID)
        state = .reviewed
        recordVersion = serverRecordVersion
        operationIDs.insert(operationID)
        self.reviewedAt = reviewedAt
        serverMetadata = SurveyServerMetadata(
            submissionOperationID: metadata.submissionOperationID,
            reviewedBy: reviewerID,
            reviewOperationID: operationID
        )
    }

    private static func isValidOperationID(_ value: String) -> Bool {
        !value.isEmpty &&
            value != "." &&
            value != ".." &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= maximumOperationIDBytes &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }

    func validateNewOperationID(_ operationID: String) throws {
        guard Self.isValidOperationID(operationID),
              !operationIDs.contains(operationID) else {
            throw SurveyResponseMutationError.invalidOperationID
        }
        guard operationIDs.count < Self.maximumOperationCount else {
            throw SurveyResponseMutationError.historyLimitReached
        }
    }
}

nonisolated struct SurveyStoredOperationResult: Codable, Equatable, Sendable {
    let fingerprint: String
    let userID: String
    let sessionID: String?
    let recordVersion: Int
}

nonisolated struct SurveyStoredResponseDocument: Codable, Equatable, Sendable {
    let response: SurveyResponse
    let operationResults: [String: SurveyStoredOperationResult]
    let respondentUserID: String
    let respondentSessionID: String
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case operationResults
        case respondentUserID
        case respondentSessionID
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        response = try SurveyResponse(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operationResults = try container.decode(
            [String: SurveyStoredOperationResult].self,
            forKey: .operationResults
        )
        respondentUserID = try container.decode(
            String.self,
            forKey: .respondentUserID
        )
        respondentSessionID = try container.decode(
            String.self,
            forKey: .respondentSessionID
        )
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        guard operationResults.count <= SurveyResponse.maximumOperationCount,
              Set(operationResults.keys) == response.operationIDs,
              !respondentUserID.isEmpty,
              !respondentSessionID.isEmpty,
              operationResults.values.allSatisfy({ result in
                  result.fingerprint.count == 64 &&
                      !result.userID.isEmpty &&
                      result.recordVersion > 0 &&
                      result.recordVersion <= response.recordVersion
              }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .operationResults,
                in: container,
                debugDescription: "The stored survey operation envelope is malformed."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        try response.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operationResults, forKey: .operationResults)
        try container.encode(respondentUserID, forKey: .respondentUserID)
        try container.encode(respondentSessionID, forKey: .respondentSessionID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
