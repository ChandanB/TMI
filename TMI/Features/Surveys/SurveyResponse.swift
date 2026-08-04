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
}

nonisolated struct SurveyResponse: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

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
    private(set) var serverRecordVersion: Int
    private(set) var answers: [String: SurveyAnswer]
    private(set) var operationIDs: Set<String>
    private(set) var syncState: SurveySyncState
    private(set) var hasPendingChanges: Bool
    private(set) var submittedAt: Date?
    private(set) var reviewedAt: Date?
    private(set) var frozenDefinition: SurveyDefinition?
    private(set) var sourceHistory: SurveySourceHistory?
    private(set) var serverMetadata: SurveyServerMetadata?

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
        serverRecordVersion = 0
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
        answers[questionID] = answer
        operationIDs.insert(operationID)
        recordVersion += 1
        syncState = .pending
        hasPendingChanges = true
        return true
    }

    mutating func markSynchronized(serverRecordVersion: Int) {
        recordVersion = serverRecordVersion
        self.serverRecordVersion = serverRecordVersion
        syncState = .synced
        hasPendingChanges = false
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
        guard serverRecordVersion > self.serverRecordVersion else {
            throw SurveyResponseMutationError.invalidRecordVersion
        }
        state = .submitted
        recordVersion = serverRecordVersion
        self.serverRecordVersion = serverRecordVersion
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
        guard serverRecordVersion > self.serverRecordVersion,
              let metadata = serverMetadata else {
            throw SurveyResponseMutationError.invalidRecordVersion
        }
        state = .reviewed
        recordVersion = serverRecordVersion
        self.serverRecordVersion = serverRecordVersion
        operationIDs.insert(operationID)
        self.reviewedAt = reviewedAt
        serverMetadata = SurveyServerMetadata(
            submissionOperationID: metadata.submissionOperationID,
            reviewedBy: reviewerID,
            reviewOperationID: operationID
        )
    }
}
