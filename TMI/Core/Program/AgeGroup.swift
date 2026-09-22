import Foundation

/// Early-childhood grouping used in place of a K-12 grade. Stored in the
/// student record's `grade` field as the raw value so the existing canonical
/// schema, validation (≤ 32 characters), and cohort matching keep working.
nonisolated enum AgeGroup: String, Codable, Sendable, CaseIterable, Identifiable, Equatable {
    case infant = "Infant"
    case toddler = "Toddler"
    case twos = "Twos"
    case preschool3 = "Preschool 3s"
    case preK4 = "Pre-K 4s"
    case transitionalK = "Transitional K"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Typical age range shown as guidance, not a rule.
    var typicalAges: String {
        switch self {
        case .infant: "0–12 months"
        case .toddler: "12–24 months"
        case .twos: "2 years"
        case .preschool3: "3 years"
        case .preK4: "4 years"
        case .transitionalK: "4–5 years"
        }
    }

    /// Whether children in this group can take part in a caregiver-held
    /// Picture Choice activity. Younger children are observed, never asked.
    var supportsPictureChoice: Bool {
        switch self {
        case .infant, .toddler, .twos: false
        case .preschool3, .preK4, .transitionalK: true
        }
    }

    /// Suggests an age group from a date of birth on a reference date.
    static func suggested(forDateOfBirth dateOfBirth: Date, on date: Date = .now, calendar: Calendar = .current) -> AgeGroup {
        let months = calendar.dateComponents([.month], from: dateOfBirth, to: date).month ?? 0
        switch months {
        case ..<12: return .infant
        case 12..<24: return .toddler
        case 24..<36: return .twos
        case 36..<48: return .preschool3
        case 48..<57: return .preK4
        default: return .transitionalK
        }
    }
}

/// K-12 grade choices, kept alongside age groups so pickers share one source.
nonisolated enum GradeLevel {
    static let k12: [String] = ["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]

    static func choices(for program: ProgramType) -> [String] {
        switch program {
        case .k12: ["Pre-K"] + k12
        case .earlyChildhood: AgeGroup.allCases.map(\.rawValue)
        }
    }
}
