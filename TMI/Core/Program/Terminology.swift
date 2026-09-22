import Foundation

/// Program-appropriate words for the same product concepts. Staff copy stays
/// professional; early-childhood sites talk about children, families, and
/// centers instead of students, grades, and schools.
nonisolated struct Terminology: Sendable, Equatable {
    let learner: String
    let learners: String
    let site: String
    let sites: String
    let organization: String
    let gradeLabel: String
    let learnerRecord: String
    let learnerMode: String
    let discoveryActivity: String

    static let k12 = Terminology(
        learner: "Student",
        learners: "Students",
        site: "School",
        sites: "Schools",
        organization: "District",
        gradeLabel: "Grade",
        learnerRecord: "Student record",
        learnerMode: "Student Mode",
        discoveryActivity: "Interest survey"
    )

    static let earlyChildhood = Terminology(
        learner: "Child",
        learners: "Children",
        site: "Center",
        sites: "Centers",
        organization: "Organization",
        gradeLabel: "Age group",
        learnerRecord: "Child record",
        learnerMode: "Picture Choice",
        discoveryActivity: "Interest observation"
    )

    static func `for`(_ program: ProgramType) -> Terminology {
        switch program {
        case .k12: .k12
        case .earlyChildhood: .earlyChildhood
        }
    }

    /// "Grade 7" for K-12, "Toddler" for early childhood.
    func gradeDescription(_ grade: String) -> String {
        guard !grade.isEmpty else { return "" }
        return self == .earlyChildhood ? grade : "\(gradeLabel) \(grade)"
    }
}
