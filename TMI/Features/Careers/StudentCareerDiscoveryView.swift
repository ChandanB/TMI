import SwiftUI

/// Career discovery for one student.
///
/// The student whose interests drive the matching is named at the top and
/// stays visible, because every match on this screen is a claim about them
/// specifically and it must never be ambiguous whose screen this is.
struct StudentCareerDiscoveryView: View {
    let studentID: String
    let studentName: String
    let approvedInterests: [StudentInterest]
    let clusters: [InterestClusterScore]
    let member: MembershipContext?
    let relationshipRepository: (any CareerRelationshipProviding)?
    var repository: CareerRepository = CareerRepository()

    @State private var state = CareerDiscoveryState()
    @State private var comparisonShown = false
    @State private var limitMessage: String?
    @State private var careers: [CareerRecord] = []
    @State private var matches: [CareerMatch] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var relationshipError: String?
    @State private var relationships: [String: CareerRelationship] = [:]
    @State private var mutatingCareerIDs: Set<String> = []

    private var matchesByID: [String: CareerMatch] {
        Dictionary(matches.map { ($0.careerID, $0) }, uniquingKeysWith: { left, _ in left })
    }

    private var results: [CareerRecord] {
        state.results(
            careers: careers,
            matches: matches,
            dismissedIDs: Set(
                relationships.values.filter(\.isDismissed).map(\.careerID)
            ),
            recentlyViewedIDs: Set(
                relationships.values.compactMap { relationship in
                    relationship.lastViewedAt == nil ? nil : relationship.careerID
                }
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            header
            filters

            if let limitMessage {
                Text(limitMessage)
                    .font(.footnote)
                    .foregroundStyle(TMIColors.errorText)
                    .accessibilityIdentifier("careerDiscovery.limit")
            }

            if let relationshipError {
                Text(relationshipError)
                    .font(.footnote)
                    .foregroundStyle(TMIColors.errorText)
                    .accessibilityIdentifier("careerDiscovery.relationshipError")
            }

            // Exactly one primary state shows at a time. A failed catalog
            // supersedes everything else — it is the one thing the reader can
            // act on, and stacking it under "no interests" only muddled which
            // problem was real.
            if isLoading {
                ProgressView("Loading careers…")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("careerDiscovery.loading")
            } else if let loadError {
                ContentUnavailableView {
                    Label("Career catalog unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Try again") { Task { await loadCatalog() } }
                        .buttonStyle(.borderedProminent)
                        .tint(TMIColors.aubergine)
                }
                .accessibilityIdentifier("careerDiscovery.error")
            } else if results.isEmpty {
                if approvedInterests.isEmpty {
                    ContentUnavailableView(
                        "No approved interests yet",
                        systemImage: "star",
                        description: Text(
                            "Careers are matched from interests a staff member has approved. Search to browse in the meantime."
                        )
                    )
                    .accessibilityIdentifier("careerDiscovery.noInterests")
                } else {
                    ContentUnavailableView(
                        "No careers match",
                        systemImage: "magnifyingglass",
                        description: Text("Try fewer words or clear the filters.")
                    )
                    .accessibilityIdentifier("careerDiscovery.empty")
                }
            } else {
                if approvedInterests.isEmpty {
                    // Browsable results exist, but nothing is matched to this
                    // student yet — say so inline rather than hijacking the view.
                    Text("No approved interests yet — showing all careers to browse.")
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                        .accessibilityIdentifier("careerDiscovery.noInterests")
                }
                ForEach(results) { career in
                    careerRow(career)
                }
            }
        }
        .padding(.vertical, TMISpacing.xs)
        .searchable(text: $state.query, prompt: "Search careers")
        .accessibilityIdentifier("careerDiscovery.screen")
        .task(id: studentID) { await loadCatalog() }
        .sheet(isPresented: $comparisonShown) {
            CareerComparisonView(
                careers: state.comparisonIDs.compactMap { id in careers.first { $0.id == id } },
                matches: matchesByID
            ) {
                comparisonShown = false
            }
        }
    }

    @MainActor
    private func loadCatalog() async {
        isLoading = true
        loadError = nil
        do {
            careers = try await repository.careers()
            matches = CareerMatcher.match(
                careers: careers,
                approvedInterests: approvedInterests,
                clusters: clusters
            )
            if let member, let relationshipRepository {
                let loaded = try await relationshipRepository.relationships(
                    studentID: studentID,
                    member: member
                )
                relationships = Dictionary(
                    loaded.map { ($0.careerID, $0) },
                    uniquingKeysWith: { newest, _ in newest }
                )
                state.restoreComparisonIDs(
                    loaded.filter(\.isCompared).map(\.careerID)
                )
            }
        } catch {
            careers = []
            matches = []
            loadError = "Check your connection and try again."
        }
        isLoading = false
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                Text("Careers for \(studentName)")
                    .font(.headline)
                    .accessibilityIdentifier("careerDiscovery.student")
                Text("\(results.count) shown")
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
            }
            Spacer()
            Button("Compare \(state.comparisonIDs.count)") {
                comparisonShown = true
            }
            .buttonStyle(.borderedProminent)
            .tint(TMIColors.aubergine)
            .disabled(!state.canCompare)
            .accessibilityIdentifier("careerDiscovery.compare")
        }
    }

    private var filters: some View {
        // A single scrolling row of chips that each hug their label. The old
        // adaptive grid capped every cell at 100pt, which truncated the longer
        // education levels ("Certificate o…", "Associate d…").
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.xs) {
                ForEach(CareerEducationLevel.allCases, id: \.self) { level in
                    let isOn = state.educationLevels.contains(level)
                    Button(level.displayName) {
                        if isOn {
                            state.educationLevels.remove(level)
                        } else {
                            state.educationLevels.insert(level)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(isOn ? TMIColors.aubergine : nil)
                    .fixedSize()
                    .accessibilityIdentifier("careerDiscovery.filter.\(level.rawValue)")
                }
                Button("Recently viewed") {
                    state.showRecentlyViewed.toggle()
                }
                .buttonStyle(.bordered)
                .tint(state.showRecentlyViewed ? TMIColors.aubergine : nil)
                .fixedSize()
                .accessibilityAddTraits(state.showRecentlyViewed ? .isSelected : [])
                .accessibilityIdentifier("careerDiscovery.filter.recent")
                if state.hasActiveFilters {
                    Button("Clear") { state.clearFilters() }
                        .buttonStyle(.borderless)
                        .fixedSize()
                        .accessibilityIdentifier("careerDiscovery.filter.clear")
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func careerRow(_ career: CareerRecord) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            NavigationLink {
                CanonicalCareerDetailView(
                    career: career,
                    match: matchesByID[career.id],
                    onViewed: {
                        await persist(careerID: career.id, action: .view)
                    }
                )
            } label: {
                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                    Text(career.title)
                        .font(.headline)
                    Text(CanonicalCareerDetailView.readable(career.category))
                        .font(.caption)
                        .foregroundStyle(TMIColors.textSecondary)
                    if let reason = matchesByID[career.id]?.reasons.first {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(TMIColors.aubergine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("careerDiscovery.career.\(career.id)")

            HStack(spacing: TMISpacing.xs) {
                Button(relationships[career.id]?.isSaved == true ? "Remove saved" : "Save") {
                    Task { @MainActor in
                        await persist(careerID: career.id, action: .save)
                    }
                }
                .disabled(mutatingCareerIDs.contains(career.id))
                .accessibilityIdentifier("careerDiscovery.save.\(career.id)")

                Button("Dismiss") {
                    Task { @MainActor in
                        await persist(careerID: career.id, action: .dismiss)
                    }
                }
                .disabled(mutatingCareerIDs.contains(career.id))
                .accessibilityIdentifier("careerDiscovery.dismiss.\(career.id)")

                Button(state.isSelectedForComparison(career.id) ? "Selected" : "Compare") {
                    Task { @MainActor in
                        if !state.isSelectedForComparison(career.id),
                           state.comparisonIDs.count >= CareerDiscoveryState.maximumComparisons {
                            limitMessage = "You can compare up to \(CareerDiscoveryState.maximumComparisons) careers at once."
                            return
                        }
                        await persist(careerID: career.id, action: .compare)
                    }
                }
                .disabled(mutatingCareerIDs.contains(career.id))
                .accessibilityIdentifier("careerDiscovery.compareToggle.\(career.id)")
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
    }

    private enum RelationshipAction {
        case save
        case dismiss
        case compare
        case view
    }

    @MainActor
    private func persist(careerID: String, action: RelationshipAction) async {
        guard let member, let relationshipRepository else {
            relationshipError = "Career choices are unavailable until staff access is verified."
            return
        }
        mutatingCareerIDs.insert(careerID)
        defer { mutatingCareerIDs.remove(careerID) }
        relationshipError = nil

        let timestamp = Date.now
        let existing = relationships[careerID]
        let base = existing ?? CareerRelationship(
            studentID: studentID,
            careerID: careerID,
            updatedAt: timestamp,
            updatedBy: member.userID
        )
        let updated: CareerRelationship
        if existing == nil {
            updated = CareerRelationship(
                studentID: studentID,
                careerID: careerID,
                isSaved: action == .save,
                isDismissed: action == .dismiss,
                isCompared: action == .compare,
                lastViewedAt: action == .view ? timestamp : nil,
                updatedAt: timestamp,
                updatedBy: member.userID
            )
        } else {
            updated = switch action {
            case .save:
                base.settingSaved(!base.isSaved, at: timestamp, by: member.userID)
            case .dismiss:
                base.settingDismissed(true, at: timestamp, by: member.userID)
            case .compare:
                base.settingCompared(!base.isCompared, at: timestamp, by: member.userID)
            case .view:
                base.markingViewed(at: timestamp, by: member.userID)
            }
        }

        do {
            try await relationshipRepository.save(updated, member: member)
            relationships[careerID] = updated
            if action == .compare {
                _ = state.toggleComparison(careerID)
                limitMessage = nil
            }
        } catch {
            relationshipError = "That career choice was not confirmed. Try again."
        }
    }
}
