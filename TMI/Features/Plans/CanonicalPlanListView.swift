import SwiftUI

struct CanonicalPlanListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel

    @State private var state: CanonicalPlanListState?

    var body: some View {
        Group {
            if let membership {
                content(membership: membership)
            } else {
                ContentUnavailableView(
                    "Workspace Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Sign in again to reach your plans.")
                )
            }
        }
        .navigationTitle("TMI Plans")
    }

    private let memberOverride: MembershipContext?

    init(
        state: CanonicalPlanListState? = nil,
        member: MembershipContext? = nil
    ) {
        _state = State(initialValue: state)
        memberOverride = member
    }

    private var membership: MembershipContext? {
        memberOverride ?? authStateModel.currentMembership
    }

    @ViewBuilder
    private func content(membership: MembershipContext) -> some View {
        if let state {
            loaded(state: state, membership: membership)
        } else {
            ProgressView("Loading plans…")
                .tint(TMIColors.teal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("plans.loading")
                .task {
                    let repository = dependencies.planRepository
                        ?? CanonicalPlanRepository(firestore: .firestore())
                    state = CanonicalPlanListState(repository: repository)
                }
        }
    }

    @ViewBuilder
    private func loaded(
        state: CanonicalPlanListState,
        membership: MembershipContext
    ) -> some View {
        ZStack {
            TMIBackgroundView(variant: .plans).ignoresSafeArea()

            switch state.phase {
            case .idle, .loading:
                ProgressView("Loading plans…")
                    .accessibilityIdentifier("plans.loading")
            case .empty:
                ContentUnavailableView(
                    "No Plans Yet",
                    systemImage: "doc.text",
                    description: Text(
                        "Open a student and start a TMI plan to see it here."
                    )
                )
                .accessibilityIdentifier("plans.empty")
            case .permissionDenied:
                ContentUnavailableView(
                    "Not Available",
                    systemImage: "lock",
                    description: Text(
                        "Your account does not have access to these plans."
                    )
                )
                .accessibilityIdentifier("plans.permissionDenied")
            case .failed(let message):
                ContentUnavailableView {
                    Label("Plans Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await state.load(member: membership) }
                    }
                }
                .accessibilityIdentifier("plans.failed")
            case .loaded:
                planList(state: state, membership: membership)
            }
        }
        .task(id: membership.userID) {
            await state.load(member: membership)
        }
    }

    private func planList(
        state: CanonicalPlanListState,
        membership: MembershipContext
    ) -> some View {
        @Bindable var state = state

        return List {
            Section {
                Toggle("Open plans only", isOn: $state.showOpenOnly)
                    .accessibilityIdentifier("plans.openOnly")
            }
            ForEach(state.visiblePlans) { plan in
                NavigationLink(value: AppRoute.plan(plan.id)) {
                    CanonicalPlanRow(plan: plan)
                }
                .listRowBackground(TMIColors.surface)
                .accessibilityIdentifier("plans.row.\(plan.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await state.load(member: membership) }
        .accessibilityIdentifier("plans.list")
    }

}

private struct CanonicalPlanRow: View {
    let plan: PlanRecord

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
            Text(plan.title)
                .font(.headline)
                .foregroundStyle(TMIColors.textPrimary)
            Text(plan.model.rawValue)
                .font(.subheadline)
                .foregroundStyle(TMIColors.textSecondary)
            HStack(spacing: TMISpacing.xs) {
                Text(plan.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, TMISpacing.sm)
                    .padding(.vertical, TMISpacing.xxs)
                    .background(
                        statusSurface,
                        in: Capsule()
                    )
                    .foregroundStyle(statusText)
                Text(
                    "\(plan.studentIDs.count) student"
                        + (plan.studentIDs.count == 1 ? "" : "s")
                )
                .font(.caption)
                .foregroundStyle(TMIColors.textSecondary)
            }
        }
        .padding(.vertical, TMISpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(plan.title), \(plan.model.rawValue), \(plan.status.displayName)"
        )
    }

    private var statusSurface: Color {
        switch plan.status {
        case .approved, .active: TMIColors.successSurface
        case .paused, .changesRequested, .pendingApproval: TMIColors.warningSurface
        case .completed, .archived: TMIColors.infoSurface
        case .draft: TMIColors.aubergineSoft
        }
    }

    private var statusText: Color {
        switch plan.status {
        case .approved, .active: TMIColors.successText
        case .paused, .changesRequested, .pendingApproval: TMIColors.warningText
        case .completed, .archived: TMIColors.infoText
        case .draft: TMIColors.aubergine
        }
    }
}
