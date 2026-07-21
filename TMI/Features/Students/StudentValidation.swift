import Foundation

nonisolated struct StudentValidationPolicy: Sendable, Equatable {
    let requiresStudentIdentifier: Bool

    static let standard = StudentValidationPolicy(requiresStudentIdentifier: false)
}

nonisolated enum StudentValidation {
    static let maximumDisplayNameLength = 120
    static let maximumDisplayNameUTF8Length = 512
    static let maximumGradeLength = 32
    static let maximumGradeUTF8Length = 128
    static let maximumStudentIdentifierLength = 128
    static let maximumStudentIdentifierUTF8Length = 512
    static let maximumPronounLength = 80
    static let maximumPronounUTF8Length = 320

    enum Field: String, Sendable, Hashable {
        case districtID
        case schoolID
        case displayName
        case grade
        case studentIdentifier
        case dateOfBirth
        case pronouns
        case assignedMemberIDs
    }

    struct Issue: Sendable, Equatable {
        let field: Field
        let message: String
    }

    static func issues(
        for draft: StudentDraft,
        districtID: String,
        policy: StudentValidationPolicy,
        now: Date = Date()
    ) -> [Issue] {
        let draft = draft.normalized
        var issues: [Issue] = []

        if !TrustedIdentifier.isValid(districtID) {
            issues.append(Issue(field: .districtID, message: "A valid district is required."))
        }

        if draft.schoolID.isEmpty {
            issues.append(Issue(field: .schoolID, message: "School is required."))
        } else if !TrustedIdentifier.isValid(draft.schoolID) {
            issues.append(Issue(field: .schoolID, message: "Select a valid school."))
        }

        if draft.displayName.isEmpty {
            issues.append(Issue(field: .displayName, message: "Student name is required."))
        } else if exceedsSafeTextLimits(
            draft.displayName,
            maximumCharacters: maximumDisplayNameLength,
            maximumUTF8Length: maximumDisplayNameUTF8Length
        ) {
            issues.append(
                Issue(
                    field: .displayName,
                    message: "Student name must be \(maximumDisplayNameLength) characters or fewer."
                )
            )
        }

        if draft.grade.isEmpty {
            issues.append(Issue(field: .grade, message: "Grade is required."))
        } else if exceedsSafeTextLimits(
            draft.grade,
            maximumCharacters: maximumGradeLength,
            maximumUTF8Length: maximumGradeUTF8Length
        ) {
            issues.append(
                Issue(
                    field: .grade,
                    message: "Grade must be \(maximumGradeLength) characters or fewer."
                )
            )
        }

        if policy.requiresStudentIdentifier, draft.studentIdentifier == nil {
            issues.append(
                Issue(
                    field: .studentIdentifier,
                    message: "Student identifier is required by district policy."
                )
            )
        } else if let identifier = draft.studentIdentifier {
            if exceedsSafeTextLimits(
                identifier,
                maximumCharacters: maximumStudentIdentifierLength,
                maximumUTF8Length: maximumStudentIdentifierUTF8Length
            ) || identifier.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            {
                issues.append(
                    Issue(
                        field: .studentIdentifier,
                        message: "Student identifier must be \(maximumStudentIdentifierLength) valid characters or fewer."
                    )
                )
            }
        }

        if let dateOfBirth = draft.dateOfBirth, dateOfBirth > now {
            issues.append(
                Issue(field: .dateOfBirth, message: "Date of birth cannot be in the future.")
            )
        }

        if let pronouns = draft.pronouns,
           exceedsSafeTextLimits(
            pronouns,
            maximumCharacters: maximumPronounLength,
            maximumUTF8Length: maximumPronounUTF8Length
           ) {
            issues.append(
                Issue(
                    field: .pronouns,
                    message: "Pronouns must be \(maximumPronounLength) characters or fewer."
                )
            )
        }

        if !draft.assignedMemberIDs.allSatisfy(TrustedIdentifier.isValid) {
            issues.append(
                Issue(field: .assignedMemberIDs, message: "One or more staff assignments are invalid.")
            )
        }

        return issues
    }

    private static func exceedsSafeTextLimits(
        _ value: String,
        maximumCharacters: Int,
        maximumUTF8Length: Int
    ) -> Bool {
        value.count > maximumCharacters
            || value.utf8.count > maximumUTF8Length
            || value.unicodeScalars.contains { scalar in
                CharacterSet.controlCharacters.contains(scalar)
                    && !CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
    }
}
