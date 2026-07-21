import Foundation

/// Editable student fields. Tenant identity is intentionally supplied by the
/// trusted membership context rather than accepted as user-editable input.
nonisolated struct StudentDraft: Codable, Sendable, Equatable {
    var displayName: String
    var schoolID: String
    var grade: String
    var studentIdentifier: String?
    var dateOfBirth: Date?
    var pronouns: String?
    var assignedMemberIDs: Set<String>

    var normalized: StudentDraft {
        StudentDraft(
            displayName: Self.collapsedWhitespace(displayName),
            schoolID: Self.trimmedIdentifier(schoolID),
            grade: Self.collapsedWhitespace(grade),
            studentIdentifier: Self.normalizedOptionalIdentifier(studentIdentifier),
            dateOfBirth: dateOfBirth,
            pronouns: Self.normalizedOptionalText(pronouns),
            assignedMemberIDs: Set(
                assignedMemberIDs.lazy
                    .map(Self.trimmedIdentifier)
                    .filter { !$0.isEmpty }
            )
        )
    }

    private static func collapsedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func trimmedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedOptionalIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = trimmedIdentifier(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = collapsedWhitespace(value)
        return normalized.isEmpty ? nil : normalized
    }
}
