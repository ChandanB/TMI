import SwiftUI

/// One plan, with the controls the reader is actually allowed to use.
///
/// Controls are shown only where both the lifecycle and the member's
/// authority allow the move. A disabled button a reader cannot explain is
/// worse than no button, and hiding is not the authorization mechanism —
/// the rules refuse anything this misses.
struct CanonicalPlanDetailView: View {
    let planID: String

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @State private var state: CanonicalPlanDetailState?
    @State private var editingGoal: GoalRecord?
    @State private var isAddingGoal = false

    private let memberOverride: MembershipContext?

    init(planID: String, member: MembershipContext? = nil) {
        self.planID = planID
        self.memberOverride = member
    }

    private var member: MembershipContext? {
        memberOverride ?? authStateModel.currentMembership
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .plans).ignoresSafeArea()
            content
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("planDetail.screen")
        .sheet(isPresented: $isAddingGoal) {
            if let plan = state?.plan, let member {
                GoalEditorView(
                    planID: plan.id,
                    studentID: plan.studentIDs.sorted().first ?? "",
                    member: member,
                    planStartDate: plan.startDate
                ) { _ in
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .sheet(item: $editingGoal) { goal in
            if let plan = state?.plan, let member {
                GoalEditorView(
                    planID: plan.id,
                    studentID: goal.studentID,
                    member: member,
                    planStartDate: plan.startDate,
                    existing: goal
                ) { _ in
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .task(id: planID) {
            guard let repository = dependencies.planRepository, let member else { return }
            let created = CanonicalPlanDetailState(
                planID: planID,
                repository: repository,
                children: dependencies.planChildRepository
            )
            state = created
            await created.load(member: member)
        }
    }

    @ViewBuilder
    private var content: some View {
        if dependencies.planRepository == nil {
            ContentUnavailableView(
                "Plans unavailable",
                systemImage: "doc.text",
                description: Text("Plans are unavailable in this build.")
            )
        } else if let state, let member {
            switch state.phase {
            case .loading:
                ProgressView("Loading plan…")
            case .permissionDenied:
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: "lock",
                    description: Text("You do not have access to this plan.")
                )
                .accessibilityIdentifier("planDetail.permissionDenied")
            case .failed(let message):
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let plan):
                loaded(plan: plan, state: state, member: member)
            }
        } else {
            ProgressView()
        }
    }

    private func loaded(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                header(plan)
                lifecycle(plan: plan, state: state, member: member)
                if let summary = plan.summary, !summary.isEmpty {
                    section("Summary") {
                        Text(summary).font(.body)
                    }
                }
                section("Dates") {
                    LabeledContent(
                        "Starts",
                        value: plan.startDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    if let targetDate = plan.targetDate {
                        LabeledContent(
                            "Target",
                            value: targetDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
                goalsSection(plan: plan, state: state, member: member)

                section("Progress") {
                    if state.progress.isEmpty {
                        Text("No progress recorded yet.")
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                    } else {
                        Text("\(state.completionPercentage)% of due actions done")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("planDetail.completion")
                        ForEach(state.progress) { entry in
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                Text(entry.note ?? entry.measuredValue ?? "Recorded")
                                    .font(.subheadline)
                                Text(entry.visibility == .sharedWithStudent
                                    ? "Shared with the student"
                                    : "Staff only")
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                        }
                    }
                }

                section("History") {
                    // Revisions freeze at approval, changes requested and
                    // completion. Until those are persisted there is nothing
                    // to show, and saying so beats an empty box.
                    if state.revisions.isEmpty {
                        Text("Revisions appear here once this plan is approved or completed.")
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                    } else {
                        ForEach(PlanRevisionHistory.ordered(state.revisions)) { revision in
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                Text("\(revision.reason.displayName) · revision \(revision.sequence)")
                                    .font(.subheadline.weight(.semibold))
                                Text(revision.frozenAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                                if let note = revision.note {
                                    Text(note).font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TMISpacing.lg)
        }
    }

    private func header(_ plan: PlanRecord) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
            Text(plan.title)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("planDetail.title")
            Text(plan.model.rawValue)
                .font(.headline)
                .foregroundStyle(TMIColors.aubergine)
            Text(plan.status.displayName)
                .font(.subheadline)
                .foregroundStyle(TMIColors.textSecondary)
                .accessibilityIdentifier("planDetail.status")
        }
    }

    private func lifecycle(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        section("Next step") {
            let transitions = state.availableTransitions(for: member)
            if transitions.isEmpty {
                Text(plan.status.isOpen
                    ? "You do not have access to move this plan."
                    : "This plan has ended.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planDetail.noTransitions")
            } else {
                ForEach(transitions, id: \.self) { status in
                    Button("Move to \(status.displayName.lowercased())") {
                        Task { await state.transition(to: status, member: member) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.isMutating)
                    .accessibilityIdentifier("planDetail.transition.\(status.rawValue)")
                }
            }
            if let message = state.actionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planDetail.actionMessage")
            }
        }
    }

    private func goalsSection(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        section("Goals") {
            if state.goals.isEmpty {
                Text("No goals yet. A plan without a goal has nothing to measure.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                ForEach(state.goals) { goal in
                    Button {
                        editingGoal = goal
                    } label: {
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text(goal.title).font(.subheadline.weight(.semibold))
                            Text("From: \(goal.baseline)")
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                            Text("To: \(goal.target)")
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                            Text("\(goal.status.displayName) · due \(goal.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planDetail.goal.\(goal.id)")
                }
            }
            // Writing a goal is editing the plan, so it needs write access.
            if member.capabilities.contains(.studentWriteDetail), plan.status.isOpen {
                Button("Add a goal", systemImage: "plus.circle") {
                    isAddingGoal = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("planDetail.addGoal")
            }
        }
    }

    @ViewBuilder
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
    }
}
