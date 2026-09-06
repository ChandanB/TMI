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
        studentID: String,
        plan: PlanRecord,
        goals: [GoalRecord],
        actions: [ActionRecord],
        progress: [ProgressRecord],
        now: Date = Date()
    ) -> StudentPlanProjection? {
        guard !studentID.isEmpty, plan.studentIDs.contains(studentID),
              plan.status == .active, plan.approvalStatus == .approved else { return nil }

        let visibleGoals = goals.filter {
            $0.planID == plan.id && $0.studentID == studentID
                && $0.status != .discontinued
                && $0.studentFacingTitle?.trimmed.isEmpty == false
        }
        let visibleGoalIDs = Set(visibleGoals.map(\.id))
        let visibleActions = actions.filter {
            $0.planID == plan.id && visibleGoalIDs.contains($0.goalID)
                && $0.audience == .student && $0.status != .skipped
                && $0.dueDate <= now
        }
        let studentGoals = visibleGoals
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
            .map { goal in
                StudentPlanGoal(
                    id: goal.id,
                    // Goals without wording explicitly written for the student
                    // were excluded above. Never substitute professional text.
                    wording: goal.studentFacingTitle?.trimmed ?? "",
                    dueDate: goal.dueDate,
                    actions: visibleActions
                        .filter { $0.goalID == goal.id }
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
             .filter {
                $0.planID == plan.id && $0.studentID == studentID
                    && $0.visibility == .sharedWithStudent
            }
            .sorted {
                $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt
            }
            .compactMap { entry -> StudentPlanNote? in
                guard let text = entry.note, !text.isEmpty else { return nil }
                return StudentPlanNote(id: entry.id, text: text, recordedAt: entry.recordedAt)
            }

        return StudentPlanProjection(
            // Plan titles are staff-authored and may contain professional
            // framing. The brand-fixed model name is the only plan heading
            // currently guaranteed to be student-safe.
            planTitle: plan.model.rawValue,
            goals: studentGoals,
            progress: notes,
            // Count exactly the student's displayed due actions. Staff work
            // and another student's work must not influence this number.
            completionPercentage: PlanCompletion.percentage(of: visibleActions)
        )
    }
}
