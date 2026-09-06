import SwiftUI

struct CanonicalPlanListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel

    @State private var state: CanonicalPlanListState?

    var body: some View {
        if embedded {
            content
        } else {
            content.navigationTitle("TMI Plans")
        }
    }

    private var content: some View {
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
    }

    private let memberOverride: MembershipContext?
    private let embedded: Bool

    init(
        state: CanonicalPlanListState? = nil,
        member: MembershipContext? = nil,
        embedded: Bool = false
    ) {
        _state = State(initialValue: state)
        memberOverride = member
        self.embedded = embedded
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
                    state = CanonicalPlanListState(
                        repository: repository,
                        studentRepository: dependencies.studentRepository,
                        children: dependencies.planChildRepository
                    )
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
        .task(id: membership) {
            await state.load(member: membership)
        }
    }

    private func planList(
        state: CanonicalPlanListState,
        membership: MembershipContext
    ) -> some View {
        @Bindable var state = state

        return Group {
            if embedded {
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    TextField("Search plans", text: $state.searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("plans.search")
                    filterBar(state: state, membership: membership)
                    if state.visibleItems.isEmpty {
                        noMatches
                    }
                    ForEach(state.visibleItems) { item in
                        NavigationLink(value: AppRoute.plan(item.id)) {
                            CanonicalPlanRow(item: item, currentMemberID: membership.userID)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TMISpacing.md)
                                .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("plans.row.\(item.id)")
                    }
                }
            } else {
                List {
                    Section {
                        filterBar(state: state, membership: membership)
                    }
                    if state.visibleItems.isEmpty {
                        noMatches
                            .listRowBackground(Color.clear)
                    }
                    ForEach(state.visibleItems) { item in
                        NavigationLink(value: AppRoute.plan(item.id)) {
                            CanonicalPlanRow(item: item, currentMemberID: membership.userID)
                        }
                        .listRowBackground(TMIColors.surface)
                        .accessibilityIdentifier("plans.row.\(item.id)")
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $state.searchText, prompt: "Search plans or students")
                .refreshable { await state.load(member: membership) }
                .accessibilityIdentifier("plans.list")
            }
        }
    }

    private func filterBar(
        state: CanonicalPlanListState,
        membership: MembershipContext
    ) -> some View {
        @Bindable var state = state

        return ScrollView(.horizontal) {
            HStack(spacing: TMISpacing.sm) {
                Toggle("Open only", isOn: $state.showOpenOnly)
                    .toggleStyle(.button)
                    .accessibilityIdentifier("plans.openOnly")

                filterMenu(
                    title: "Status",
                    current: state.statusFilter?.displayName,
                    values: PlanRecordStatus.allCases.map { ($0.displayName, $0) },
                    clear: { state.statusFilter = nil },
                    select: { state.statusFilter = $0 }
                )
                filterMenu(
                    title: "Model",
                    current: state.modelFilter?.rawValue,
                    values: TMIPlanModel.allCases.map { ($0.rawValue, $0) },
                    clear: { state.modelFilter = nil },
                    select: { state.modelFilter = $0 }
                )
                filterMenu(
                    title: "Student",
                    current: state.studentFilter.map { state.studentName(for: $0) ?? $0 },
                    values: state.availableStudentIDs.map { (state.studentName(for: $0) ?? $0, $0) },
                    clear: { state.studentFilter = nil },
                    select: { state.studentFilter = $0 }
                )
                filterMenu(
                    title: "Owner",
                    current: state.ownerFilter.map { ownerLabel($0, membership: membership) },
                    values: state.availableOwnerIDs.map { (ownerLabel($0, membership: membership), $0) },
                    clear: { state.ownerFilter = nil },
                    select: { state.ownerFilter = $0 }
                )
                filterMenu(
                    title: "School",
                    current: state.schoolFilter,
                    values: state.availableSchoolIDs.map { ($0, $0) },
                    clear: { state.schoolFilter = nil },
                    select: { state.schoolFilter = $0 }
                )
                filterMenu(
                    title: "Relationship",
                    current: state.relationshipFilter?.displayName,
                    values: CanonicalPlanRelationship.allCases.map { ($0.displayName, $0) },
                    clear: { state.relationshipFilter = nil },
                    select: { state.relationshipFilter = $0 }
                )
                filterMenu(
                    title: "Attention",
                    current: state.attentionFilter?.displayName,
                    values: CanonicalPlanAttentionReason.allCases.map { ($0.displayName, $0) },
                    clear: { state.attentionFilter = nil },
                    select: { state.attentionFilter = $0 }
                )
            }
            .padding(.vertical, TMISpacing.xxs)
        }
        .scrollIndicators(.hidden)
    }

    private func filterMenu<Value>(
        title: String,
        current: String?,
        values: [(String, Value)],
        clear: @escaping () -> Void,
        select: @escaping (Value) -> Void
    ) -> some View {
        Menu {
            Button("Any \(title.lowercased())", action: clear)
            Divider()
            ForEach(Array(values.enumerated()), id: \.offset) { _, option in
                Button(option.0) { select(option.1) }
            }
        } label: {
            Label(current ?? title, systemImage: current == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .lineLimit(1)
        }
        .accessibilityLabel("Filter by \(title)")
        .accessibilityValue(current ?? "Any")
    }

    private func ownerLabel(_ memberID: String, membership: MembershipContext) -> String {
        memberID == membership.userID ? "You" : memberID
    }

    private var noMatches: some View {
        ContentUnavailableView(
            "No Matching Plans",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("Adjust your search or filters to see more plans.")
        )
        .accessibilityIdentifier("plans.noMatches")
    }
}

private struct CanonicalPlanRow: View {
    let item: CanonicalPlanListItem
    let currentMemberID: String

    private var plan: PlanRecord { item.plan }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(item.studentDisplayNames.joined(separator: ", "))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TMIColors.aubergine)
                }
                Spacer(minLength: TMISpacing.md)
                statusPill
            }

            HStack(spacing: TMISpacing.md) {
                Label(plan.model.rawValue, systemImage: "sparkles")
                Label("Owner: \(ownerLabel)", systemImage: "person")
            }
            .font(.caption)
            .foregroundStyle(TMIColors.textSecondary)

            HStack(spacing: TMISpacing.md) {
                Label {
                    Text(plan.startDate, format: .dateTime.month(.abbreviated).day().year())
                } icon: {
                    Image(systemName: "calendar")
                }
                if let targetDate = plan.targetDate {
                    Label {
                        Text(targetDate, format: .dateTime.month(.abbreviated).day().year())
                    } icon: {
                        Image(systemName: "target")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(TMIColors.textSecondary)

            HStack(spacing: TMISpacing.sm) {
                progressLabel
                Text("Next review: not recorded")
                    .foregroundStyle(TMIColors.textSecondary)
            }
            .font(.caption)

            if !item.relationships.isEmpty || !item.attentionReasons.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMISpacing.xs) { badges }
                    VStack(alignment: .leading, spacing: TMISpacing.xs) { badges }
                }
            }
        }
        .padding(.vertical, TMISpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(plan.title), \(item.studentDisplayNames.joined(separator: ", ")), \(plan.model.rawValue), \(plan.status.displayName), owner \(ownerLabel), \(progressAccessibilityLabel), next review not recorded"
        )
    }

    private var ownerLabel: String {
        item.ownerMemberID == currentMemberID ? "You" : item.ownerMemberID
    }

    private var progressAccessibilityLabel: String {
        switch item.progress {
        case .percentage(let value): "progress \(value) percent"
        case .unavailable: "progress unavailable"
        }
    }

    @ViewBuilder
    private var progressLabel: some View {
        switch item.progress {
        case .percentage(let value):
            Label("Progress: \(value)%", systemImage: "chart.bar.fill")
                .foregroundStyle(TMIColors.teal)
        case .unavailable:
            Label("Progress unavailable", systemImage: "chart.bar")
                .foregroundStyle(TMIColors.textSecondary)
        }
    }

    @ViewBuilder
    private var badges: some View {
        ForEach(CanonicalPlanRelationship.allCases.filter(item.relationships.contains), id: \.self) { relationship in
            badge(relationship.displayName, systemImage: "person.2")
        }
        ForEach(CanonicalPlanAttentionReason.allCases.filter(item.attentionReasons.contains), id: \.self) { reason in
            badge(reason.displayName, systemImage: "exclamationmark.circle.fill", attention: true)
        }
    }

    private func badge(_ text: String, systemImage: String, attention: Bool = false) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, TMISpacing.sm)
            .padding(.vertical, TMISpacing.xxs)
            .background(attention ? TMIColors.warningSurface : TMIColors.aubergineSoft, in: Capsule())
            .foregroundStyle(attention ? TMIColors.warningText : TMIColors.aubergine)
    }

    private var statusPill: some View {
        Text(plan.status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, TMISpacing.sm)
            .padding(.vertical, TMISpacing.xxs)
            .background(statusSurface, in: Capsule())
            .foregroundStyle(statusText)
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
