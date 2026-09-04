import Foundation

/// What a student sees of their own plan.
///
/// A plan is written about a child by adults, and most of it is professional
/// documentation: the need someone identified, staff observations, approval
/// discussion. None of that is withheld to be secretive — it is written in a
/// register that is not addressed to the child, and putting it in front of
/// them unmediated would do harm rather than good.
///
/// Redaction happens here, not in the view. A field a student is not meant to
/// read is never placed in the projection, so no layout or navigation
/// decision can surface it.
nonisolated struct StudentPlanProjection: Sendable, Equatable {
    let planTitle: String
    let goals: [StudentPlanGoal]
    let progress: [StudentPlanNote]
    let completionPercentage: Int
}

nonisolated struct StudentPlanGoal: Identifiable, Sendable, Equatable {
    let id: String
    /// The wording written for the student, never the professional title.
    let wording: String
    let dueDate: Date
    let actions: [StudentPlanAction]
}

nonisolated struct StudentPlanAction: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let dueDate: Date
    let isDone: Bool
}

nonisolated struct StudentPlanNote: Identifiable, Sendable, Equatable {
    let id: String
    let text: String
    let recordedAt: Date
}

nonisolated enum StudentPlanProjectionBuilder {
    /// Builds the student's view, or nothing at all.
    ///
    /// A plan that is not active has not been agreed yet, or has ended. Either
    /// way it is not something to show a child as their current work.
    static func projection(
        plan: PlanRecord,
        goals: [GoalRecord],
        actions: [ActionRecord],
        progress: [ProgressRecord]
    ) -> StudentPlanProjection? {
        guard plan.status == .active else { return nil }

        let studentGoals = goals
            .filter { $0.status != .discontinued }
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
            .map { goal in
                StudentPlanGoal(
                    id: goal.id,
                    // Falls back to the staff title only when nobody wrote
                    // student wording, so a student is never shown a blank.
                    wording: goal.studentWording,
                    dueDate: goal.dueDate,
                    actions: actions
                        .filter { $0.goalID == goal.id && $0.audience == .student }
                        .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
                        .map {
                            StudentPlanAction(
                                id: $0.id,
                                title: $0.title,
                                dueDate: $0.dueDate,
                                isDone: $0.status.isComplete
                            )
                        }
                )
            }

        let notes = progress
            .filter { $0.visibility == .sharedWithStudent }
            .sorted {
                $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
            }
            .compactMap { entry -> StudentPlanNote? in
                guard let text = entry.note, !text.isEmpty else { return nil }
                return StudentPlanNote(id: entry.id, text: text, recordedAt: entry.recordedAt)
            }

        return StudentPlanProjection(
            planTitle: plan.title,
            goals: studentGoals,
            progress: notes,
            // The same count staff see, so nobody is working from a different
            // number than the student is looking at.
            completionPercentage: PlanCompletion.percentage(of: actions)
        )
    }
}
