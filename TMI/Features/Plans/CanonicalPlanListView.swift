import SwiftUI

struct CanonicalPlanListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel

    @State private var state: CanonicalPlanListState?

    var body: some View {
        if embedded {
            content
        } else {
            content.navigationTitle("Plans")
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
            TMIColors.background.ignoresSafeArea()

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
                    .buttonStyle(.tmiPrimary)
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
                    TMISearchBar(text: $state.searchText, placeholder: "Search plans")
                        .accessibilityIdentifier("plans.search")
                    filterBar(state: state, membership: membership)
                    if state.visibleItems.isEmpty {
                        noMatches
                    }
                    ForEach(state.visibleItems) { item in
                        NavigationLink(value: AppRoute.plan(item.id)) {
                            CanonicalPlanRow(item: item, currentMemberID: membership.userID)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tmiSurface(padding: TMISpacing.md)
                        }
                        .buttonStyle(.tmiPressable)
                        .accessibilityIdentifier("plans.row.\(item.id)")
                    }
                }
            } else {
                List {
                    Section {
                        filterBar(state: state, membership: membership)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
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
                TMIFilterChip(label: "Open only", isSelected: state.showOpenOnly) {
                    state.showOpenOnly.toggle()
                }
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
            HStack(spacing: 5) {
                Text(current ?? title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(current == nil ? TMIColors.textPrimary : TMIColors.accent)
            .padding(.horizontal, TMISpacing.ms)
            .padding(.vertical, 7)
            .background(current == nil ? TMIColors.fill : TMIColors.accentSoft, in: Capsule())
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(item.studentDisplayNames.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                        .privacySensitive()
                }
                Spacer(minLength: TMISpacing.md)
                TMIStatusBadge(plan.status.displayName, tone: statusTone)
            }

            HStack(spacing: TMISpacing.sm) {
                Label(plan.model.rawValue, systemImage: "sparkles")
                Text("·")
                Text("Owner: \(ownerLabel)")
            }
            .font(.footnote)
            .foregroundStyle(TMIColors.textTertiary)
            .lineLimit(1)

            progressView

            HStack(spacing: TMISpacing.sm) {
                Label {
                    Text(plan.startDate, format: .dateTime.month(.abbreviated).day().year())
                } icon: {
                    Image(systemName: "calendar")
                }
                if let targetDate = plan.targetDate {
                    Text("→")
                    Text(targetDate, format: .dateTime.month(.abbreviated).day().year())
                }
                Spacer(minLength: 0)
                Text(nextReviewText)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(TMIColors.textTertiary)

            if !item.relationships.isEmpty || !item.attentionReasons.isEmpty {
                FlowLayout(spacing: TMISpacing.xs) { badges }
            }
        }
        .padding(.vertical, TMISpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(plan.title), \(item.studentDisplayNames.joined(separator: ", ")), \(plan.model.rawValue), \(plan.status.displayName), owner \(ownerLabel), \(progressAccessibilityLabel), \(nextReviewText.lowercased())"
        )
    }

    private var nextReviewText: String {
        if let date = item.nextReviewDate {
            return "Review \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "No review date"
    }

    @ViewBuilder
    private var progressView: some View {
        switch item.progress {
        case .percentage(let value):
            HStack(spacing: TMISpacing.sm) {
                TMIProgressBar(value: Double(value) / 100, height: 6)
                Text("\(value)%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TMIColors.textSecondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
        case .unavailable:
            EmptyView()
        }
    }

    private var statusTone: TMITone {
        switch plan.status {
        case .approved, .active: .success
        case .paused, .changesRequested, .pendingApproval: .warning
        case .completed, .archived: .info
        case .draft: .neutral
        }
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
    private var badges: some View {
        ForEach(CanonicalPlanRelationship.allCases.filter(item.relationships.contains), id: \.self) { relationship in
            badge(relationship.displayName, systemImage: "person.2")
        }
        ForEach(CanonicalPlanAttentionReason.allCases.filter(item.attentionReasons.contains), id: \.self) { reason in
            badge(reason.displayName, systemImage: "exclamationmark.circle.fill", attention: true)
        }
    }

    private func badge(_ text: String, systemImage: String, attention: Bool = false) -> some View {
        TMIStatusBadge(text, tone: attention ? .warning : .brand, systemImage: systemImage)
    }
}
