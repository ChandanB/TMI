import Foundation

nonisolated enum PlanExportKind: String, Codable, Sendable, CaseIterable, Equatable {
    case professionalPlan
    case mtssSummary
    case progressReport
    case meetingSummary

    var title: String {
        switch self {
        case .professionalPlan: "TMI Plan"
        case .mtssSummary: "MTSS Summary"
        case .progressReport: "Progress Report"
        case .meetingSummary: "Meeting Summary"
        }
    }
}

nonisolated enum PlanExportProjectionError: Error, Equatable, Sendable {
    case notAuthorized
    case restrictedContentRequiresAuthority
}

/// Everything an export could possibly draw on.
///
/// This is the unredacted material. It never leaves the projection.
nonisolated struct PlanExportMaterial: Sendable {
    let planID: String
    let studentID: String
    let studentDisplayName: String
    let model: TMIPlanModel
    let rationale: [String]
    let goals: [GoalRecord]
    let actions: [ActionRecord]
    let progress: [ProgressRecord]
    /// Notes only a restricted-read holder may ever see.
    let restrictedNotes: [String]
}

/// What a specific person is allowed to export.
///
/// Fields absent here were never authorized, rather than hidden later. A
/// renderer cannot leak what it was never given.
nonisolated struct PlanExportDocument: Sendable, Equatable {
    let kind: PlanExportKind
    let planID: String
    let studentDisplayName: String
    let model: TMIPlanModel
    let rationale: [String]
    let goals: [PlanExportGoal]
    let progress: [PlanExportProgressLine]
    let completionPercentage: Int
    /// Printed on every page, so a page separated from the rest still says
    /// what it is and who it was produced for.
    let classification: String
    let auditID: String
}

nonisolated struct PlanExportGoal: Sendable, Equatable {
    let title: String
    let baseline: String
    let target: String
    let dueDate: Date
    let status: GoalRecordStatus
}

nonisolated struct PlanExportProgressLine: Sendable, Equatable {
    let recordedAt: Date
    let summary: String
}

/// Decides what an export may contain, before anything is rendered.
///
/// Redaction happens here and only here. A field the viewer is not entitled
/// to is never placed in the document, so no rendering, layout or UI decision
/// can put it back. Anything that reaches the renderer is already authorized.
nonisolated enum PlanExportProjection {
    static func document(
        kind: PlanExportKind,
        material: PlanExportMaterial,
        capabilities: Set<Capability>,
        auditID: String
    ) throws -> PlanExportDocument {
        // Exporting is its own permission. Being able to read a plan on screen
        // is not the same as being allowed to take it out of the building.
        guard capabilities.contains(.reportExport) else {
            throw PlanExportProjectionError.notAuthorized
        }
        guard capabilities.contains(.studentReadDetail) else {
            throw PlanExportProjectionError.notAuthorized
        }

        let mayReadRestricted = capabilities.contains(.studentRestrictedRead)

        // Student-facing wording is written for the child to read, in a room
        // with an adult who knows them. It is not professional documentation
        // and does not belong in an exported record.
        let goals = material.goals.map { goal in
            PlanExportGoal(
                title: goal.title,
                baseline: goal.baseline,
                target: goal.target,
                dueDate: goal.dueDate,
                status: goal.status
            )
        }

        let progress = material.progress
            .filter { entry in
                // A staff-only observation stays out unless the reader holds
                // restricted read.
                entry.visibility == .sharedWithStudent || mayReadRestricted
            }
            .sorted {
                $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
            }
            .map { entry in
                PlanExportProgressLine(
                    recordedAt: entry.recordedAt,
                    summary: entry.note ?? entry.measuredValue ?? "Recorded"
                )
            }

        return PlanExportDocument(
            kind: kind,
            planID: material.planID,
            studentDisplayName: material.studentDisplayName,
            model: material.model,
            rationale: material.rationale,
            goals: kind == .progressReport ? [] : goals,
            progress: kind == .professionalPlan ? [] : progress,
            completionPercentage: PlanCompletion.percentage(of: material.actions),
            classification: classification(mayReadRestricted: mayReadRestricted),
            auditID: auditID
        )
    }

    static func classification(mayReadRestricted: Bool) -> String {
        mayReadRestricted
            ? "Confidential student record — includes restricted content"
            : "Confidential student record"
    }
}
