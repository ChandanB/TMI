import Foundation

/// A career as the canonical catalog holds it.
///
/// Named `CareerRecord` rather than `Career` because the legacy
/// `Models/Career/Career.swift` still exists; the two cannot share a name in
/// one module. The legacy type retires with the rest of the duplicate career
/// models.
nonisolated struct CareerRecord: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let title: String
    let category: String
    let subcategory: String?
    let summary: String
    /// Canonical interest identifiers this career draws on.
    let interestIDs: [String]
    /// Published survey clusters this career sits in.
    let clusterIDs: [String]
    let educationLevel: CareerEducationLevel
    /// Absent until the figure carries a source and a date. A salary shown to a
    /// student is a claim about their future, so it is not presented on the
    /// strength of an unattributed number.
    let salary: CareerSalary?
    let outlook: CareerOutlook?
    /// Historical identifiers accepted only while migrating saved links.
    let aliases: [String]

    init(
        id: String, title: String, category: String, subcategory: String?,
        summary: String, interestIDs: [String], clusterIDs: [String],
        educationLevel: CareerEducationLevel, salary: CareerSalary?,
        outlook: CareerOutlook?, aliases: [String] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.subcategory = subcategory
        self.summary = summary
        self.interestIDs = interestIDs
        self.clusterIDs = clusterIDs
        self.educationLevel = educationLevel
        self.salary = salary
        self.outlook = outlook
        self.aliases = aliases
    }

    /// Case, spacing and punctuation are presentation, not identity.
    static func canonicalID(category: String, title: String) -> String {
        "\(normalized(category))--\(normalized(title))"
    }

    static func normalized(_ value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: nil
        )
        var words: [String] = []
        var current = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words.joined(separator: "-")
    }
}

nonisolated enum CareerEducationLevel: String, Codable, Sendable, CaseIterable {
    case highSchool
    case certificate
    case associates
    case bachelors
    case masters
    case doctorate
    case varies
}

/// A salary figure that can say where it came from and when.
nonisolated struct CareerSalary: Codable, Sendable, Equatable {
    let minimum: Int
    let maximum: Int
    let currency: String
    let source: String
    let asOf: Date
}

/// An outlook that can say where it came from and when.
nonisolated struct CareerOutlook: Codable, Sendable, Equatable {
    let summary: String
    let source: String
    let asOf: Date
}
