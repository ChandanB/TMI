import SwiftUI

/// Career discovery for one student.
///
/// The student whose interests drive the matching is named at the top and
/// stays visible, because every match on this screen is a claim about them
/// specifically and it must never be ambiguous whose screen this is.
struct StudentCareerDiscoveryView: View {
    @Environment(\.appDependencies) private var dependencies

    let studentID: String
    let studentName: String
    let approvedInterests: [StudentInterest]
    let clusters: [InterestClusterScore]
    let member: MembershipContext?
    let relationshipRepository: (any CareerRelationshipProviding)?
    var planRepository: (any PlanRecordRepository)? = nil
    var planAttacher: (any CareerPlanAttaching)? = nil
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
                        .buttonStyle(.tmiPrimary)
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
            .buttonStyle(.tmiChip(isSelected: state.canCompare))
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
                    .buttonStyle(.tmiChip(isSelected: isOn))
                    .fixedSize()
                    .accessibilityIdentifier("careerDiscovery.filter.\(level.rawValue)")
                }
                Button("Recently viewed") {
                    state.showRecentlyViewed.toggle()
                }
                .buttonStyle(.tmiChip(isSelected: state.showRecentlyViewed))
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
        let isSaved = relationships[career.id]?.isSaved == true
        let isCompared = state.isSelectedForComparison(career.id)
        let isMutating = mutatingCareerIDs.contains(career.id)
        return HStack(alignment: .center, spacing: TMISpacing.ms) {
            NavigationLink {
                CanonicalCareerDetailView(
                    career: career,
                    match: matchesByID[career.id],
                    studentContext: attachmentContext,
                    onViewed: {
                        await persist(careerID: career.id, action: .view)
                    }
                )
            } label: {
                HStack(spacing: TMISpacing.ms) {
                    TMIIconTile(Self.symbol(for: career.category), tone: Self.tone(for: career.category), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(career.title)
                            .font(.headline)
                            .foregroundStyle(TMIColors.textPrimary)
                        Text(CanonicalCareerDetailView.readable(career.category))
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                        if let reason = matchesByID[career.id]?.reasons.first {
                            Label(reason, systemImage: "sparkles")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TMIColors.accent)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.tmiPressable)
            .accessibilityIdentifier("careerDiscovery.career.\(career.id)")

            HStack(spacing: 2) {
                iconToggle(
                    isSaved ? "bookmark.fill" : "bookmark",
                    label: isSaved ? "Remove saved" : "Save",
                    isOn: isSaved,
                    identifier: "careerDiscovery.save.\(career.id)"
                ) {
                    Task { @MainActor in await persist(careerID: career.id, action: .save) }
                }
                iconToggle(
                    isCompared ? "checkmark.circle.fill" : "plus.circle",
                    label: isCompared ? "Selected" : "Compare",
                    isOn: isCompared,
                    identifier: "careerDiscovery.compareToggle.\(career.id)"
                ) {
                    Task { @MainActor in
                        if !isCompared,
                           state.comparisonIDs.count >= CareerDiscoveryState.maximumComparisons {
                            limitMessage = "You can compare up to \(CareerDiscoveryState.maximumComparisons) careers at once."
                            return
                        }
                        await persist(careerID: career.id, action: .compare)
                    }
                }
                iconToggle(
                    "hand.thumbsdown",
                    label: "Dismiss",
                    isOn: false,
                    identifier: "careerDiscovery.dismiss.\(career.id)"
                ) {
                    Task { @MainActor in await persist(careerID: career.id, action: .dismiss) }
                }
            }
            .disabled(isMutating)
        }
        .tmiSurface(padding: TMISpacing.ms)
        .contextMenu {
            Button(isSaved ? "Remove Saved" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark") {
                Task { @MainActor in await persist(careerID: career.id, action: .save) }
            }
            Button(isCompared ? "Remove from Comparison" : "Add to Comparison", systemImage: "square.split.2x1") {
                Task { @MainActor in await persist(careerID: career.id, action: .compare) }
            }
            Divider()
            Button("Not for Me", systemImage: "hand.thumbsdown") {
                Task { @MainActor in await persist(careerID: career.id, action: .dismiss) }
            }
        }
        .sensoryFeedback(.selection, trigger: isSaved)
        .sensoryFeedback(.selection, trigger: isCompared)
    }

    private func iconToggle(
        _ symbol: String,
        label: String,
        isOn: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? TMIColors.accent : TMIColors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    /// A glyph and tint per career cluster, so the list reads at a glance.
    static func symbol(for category: String) -> String {
        let key = category.lowercased()
        return switch true {
        case key.contains("tech") || key.contains("computer"): "laptopcomputer"
        case key.contains("health") || key.contains("medic"): "cross.case"
        case key.contains("art") || key.contains("design") || key.contains("entertain"): "paintpalette"
        case key.contains("engineer"): "gearshape.2"
        case key.contains("science"): "flask"
        case key.contains("educat"): "graduationcap"
        case key.contains("business") || key.contains("finance"): "briefcase"
        case key.contains("sport") || key.contains("fitness"): "figure.run"
        case key.contains("trade") || key.contains("construct"): "hammer"
        case key.contains("communic") || key.contains("media"): "megaphone"
        case key.contains("social") || key.contains("community"): "person.2.wave.2"
        default: "sparkles"
        }
    }

    static func tone(for category: String) -> TMITone {
        let key = category.lowercased()
        return switch true {
        case key.contains("health") || key.contains("social"): .success
        case key.contains("tech") || key.contains("engineer") || key.contains("science"): .info
        case key.contains("art") || key.contains("design") || key.contains("entertain"): .warning
        default: .brand
        }
    }

    private var attachmentContext: CareerPlanAttachmentContext? {
        guard let member,
              member.isActive,
              member.capabilities.contains(.studentWriteDetail),
              member.assignedStudentIDs.contains(studentID),
              let planRepository = planRepository ?? dependencies.planRepository else {
            return nil
        }
        return CareerPlanAttachmentContext(
            studentID: studentID,
            studentName: studentName,
            member: member,
            planRepository: planRepository,
            planAttacher: planAttacher,
            onAttached: { await self.reloadRelationships() }
        )
    }

    @MainActor
    private func reloadRelationships() async {
        guard let member, let relationshipRepository else { return }
        do {
            let loaded = try await relationshipRepository.relationships(
                studentID: studentID,
                member: member
            )
            relationships = Dictionary(
                loaded.map { ($0.careerID, $0) },
                uniquingKeysWith: { newest, _ in newest }
            )
            relationshipError = nil
        } catch {
            relationshipError = "The career was attached, but career choices could not be refreshed."
        }
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
