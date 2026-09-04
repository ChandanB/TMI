import SwiftUI

/// Renders an already-redacted Student Mode plan value. This view cannot
/// inspect the underlying plan aggregate or staff-only child collections.
struct StudentPlanProjectionView: View {
    let projections: [StudentPlanProjection]

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            if projections.isEmpty {
                ContentUnavailableView(
                    "No current plan steps",
                    systemImage: "checkmark.circle",
                    description: Text(
                        "Your educator will let you know when there is something to work on here."
                    )
                )
            } else {
                ForEach(Array(projections.enumerated()), id: \.offset) { _, projection in
                    planCard(projection)
                }
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.bottom, TMISpacing.xl)
        .accessibilityIdentifier("studentMode.plans")
    }

    private func planCard(_ projection: StudentPlanProjection) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(projection.planTitle)
                    .font(.title3.bold())
                    .foregroundStyle(Color.tmiTextPrimary)
                Spacer()
                Text("\(projection.completionPercentage)%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.tmiPrimary)
                    .accessibilityLabel("\(projection.completionPercentage) percent complete")
            }

            ForEach(projection.goals) { goal in
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Text(goal.wording)
                        .font(.headline)
                        .foregroundStyle(Color.tmiTextPrimary)

                    if goal.actions.isEmpty {
                        Text("No steps are due right now.")
                            .font(.subheadline)
                            .foregroundStyle(Color.tmiTextSecondary)
                    } else {
                        ForEach(goal.actions) { action in
                            Label {
                                Text(action.title)
                            } icon: {
                                Image(systemName: action.isDone ? "checkmark.circle.fill" : "circle")
                            }
                            .font(.body)
                            .foregroundStyle(action.isDone ? Color.tmiSuccess : Color.tmiTextPrimary)
                            .accessibilityLabel(
                                "\(action.title), \(action.isDone ? "done" : "due")"
                            )
                        }
                    }
                }
            }

            if !projection.progress.isEmpty {
                Divider()
                Text("Check-ins")
                    .font(.headline)
                    .foregroundStyle(Color.tmiTextPrimary)
                ForEach(projection.progress) { note in
                    Text(note.text)
                        .font(.body)
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(Color.tmiSurface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.tmiBorder, lineWidth: 1)
        }
    }
}
