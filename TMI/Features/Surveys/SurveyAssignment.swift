import Foundation

nonisolated enum SurveyAssignmentError: Error, Equatable, Sendable {
    case invalidIdentifier
    case invalidVersion
}

nonisolated enum SurveyAssignmentState: String, Codable, Equatable, Sendable {
    case active
    case revoked
}

nonisolated struct SurveyAssignment: Codable, Equatable, Sendable {
    let assignmentID: String
    let attemptID: String
    let districtID: String
    let studentID: String
    let definitionID: String
    let definitionVersion: Int
    let state: SurveyAssignmentState
    let recordVersion: Int
    let assignedAt: Date
    let revokedAt: Date?

    var attemptKey: SurveyAttemptKey {
        SurveyAttemptKey(
            districtID: districtID,
            studentID: studentID,
            assignmentID: assignmentID,
            attemptID: attemptID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case assignmentID
        case attemptID
        case districtID
        case studentID
        case definitionID
        case definitionVersion
        case state
        case recordVersion
        case assignedAt
        case revokedAt
    }

    init(
        assignmentID: String,
        attemptID: String,
        districtID: String,
        studentID: String,
        definitionID: String,
        definitionVersion: Int,
        state: SurveyAssignmentState,
        recordVersion: Int = 1,
        assignedAt: Date,
        revokedAt: Date? = nil
    ) throws {
        let identifiers = [
            assignmentID,
            attemptID,
            districtID,
            studentID,
            definitionID,
        ]
        guard identifiers.allSatisfy(Self.isValidIdentifier) else {
            throw SurveyAssignmentError.invalidIdentifier
        }
        guard definitionVersion > 0, recordVersion > 0 else {
            throw SurveyAssignmentError.invalidVersion
        }
        self.assignmentID = assignmentID
        self.attemptID = attemptID
        self.districtID = districtID
        self.studentID = studentID
        self.definitionID = definitionID
        self.definitionVersion = definitionVersion
        self.state = state
        self.recordVersion = recordVersion
        self.assignedAt = assignedAt
        self.revokedAt = revokedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            assignmentID: container.decode(
                String.self,
                forKey: .assignmentID
            ),
            attemptID: container.decode(String.self, forKey: .attemptID),
            districtID: container.decode(String.self, forKey: .districtID),
            studentID: container.decode(String.self, forKey: .studentID),
            definitionID: container.decode(
                String.self,
                forKey: .definitionID
            ),
            definitionVersion: container.decode(
                Int.self,
                forKey: .definitionVersion
            ),
            state: container.decode(SurveyAssignmentState.self, forKey: .state),
            recordVersion: container.decodeIfPresent(
                Int.self,
                forKey: .recordVersion
            ) ?? 1,
            assignedAt: container.decode(Date.self, forKey: .assignedAt),
            revokedAt: container.decodeIfPresent(Date.self, forKey: .revokedAt)
        )
    }

    func revoked(at date: Date = Date()) -> SurveyAssignment {
        SurveyAssignment(
            validatedAssignmentID: assignmentID,
            attemptID: attemptID,
            districtID: districtID,
            studentID: studentID,
            definitionID: definitionID,
            definitionVersion: definitionVersion,
            state: .revoked,
            recordVersion: recordVersion + 1,
            assignedAt: assignedAt,
            revokedAt: date
        )
    }

    private init(
        validatedAssignmentID assignmentID: String,
        attemptID: String,
        districtID: String,
        studentID: String,
        definitionID: String,
        definitionVersion: Int,
        state: SurveyAssignmentState,
        recordVersion: Int,
        assignedAt: Date,
        revokedAt: Date?
    ) {
        self.assignmentID = assignmentID
        self.attemptID = attemptID
        self.districtID = districtID
        self.studentID = studentID
        self.definitionID = definitionID
        self.definitionVersion = definitionVersion
        self.state = state
        self.recordVersion = recordVersion
        self.assignedAt = assignedAt
        self.revokedAt = revokedAt
    }

    func reassigned(
        assignmentID: String,
        attemptID: String,
        at date: Date = Date()
    ) throws -> SurveyAssignment {
        guard assignmentID != self.assignmentID, attemptID != self.attemptID else {
            throw SurveyAssignmentError.invalidIdentifier
        }
        return try SurveyAssignment(
            assignmentID: assignmentID,
            attemptID: attemptID,
            districtID: districtID,
            studentID: studentID,
            definitionID: definitionID,
            definitionVersion: definitionVersion,
            state: .active,
            recordVersion: recordVersion + 1,
            assignedAt: date
        )
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}
