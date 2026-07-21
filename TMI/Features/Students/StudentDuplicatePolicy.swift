import Foundation

nonisolated enum StudentDuplicatePolicy {
    static func candidates(
        for draft: StudentDraft,
        in records: [StudentRecord],
        districtID: String,
        excludingRecordID: String? = nil
    ) -> [String] {
        guard TrustedIdentifier.isValid(districtID) else { return [] }

        let draft = draft.normalized
        let normalizedDraftName = searchableText(draft.displayName)
        let normalizedDraftGrade = searchableText(draft.grade)

        return records.lazy
            .filter { record in
                guard record.id != excludingRecordID,
                      TrustedIdentifier.isValid(record.id),
                      record.districtID == districtID,
                      record.schoolID == draft.schoolID,
                      searchableText(record.displayName) == normalizedDraftName,
                      searchableText(record.grade) == normalizedDraftGrade else {
                    return false
                }

                guard let identifier = draft.studentIdentifier else {
                    return true
                }

                return record.studentIdentifier?
                    .trimmingCharacters(in: .whitespacesAndNewlines) == identifier
            }
            .map(\.id)
            .sorted()
    }

    private static func searchableText(_ value: String) -> String {
        let stableLocale = Locale(identifier: "en_US_POSIX")

        return value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: stableLocale
            )
    }
}
