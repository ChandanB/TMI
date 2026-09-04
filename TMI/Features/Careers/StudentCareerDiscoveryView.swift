import SwiftUI

/// Career discovery for one student.
///
/// The student whose interests drive the matching is named at the top and
/// stays visible, because every match on this screen is a claim about them
/// specifically and it must never be ambiguous whose screen this is.
struct StudentCareerDiscoveryView: View {
    let studentName: String
    let approvedInterests: [StudentInterest]
    let clusters: [InterestClusterScore]
    var repository: CareerRepository = CareerRepository()

    @State private var state = CareerDiscoveryState()
    @State private var comparisonShown = false
    @State private var limitMessage: String?
    @State private var careers: [CareerRecord] = []
    @State private var matches: [CareerMatch] = []
    @State private var isLoading = true
    @State private var loadError: String?

    private var matchesByID: [String: CareerMatch] {
        Dictionary(matches.map { ($0.careerID, $0) }, uniquingKeysWith: { left, _ in left })
    }

    private var results: [CareerRecord] {
        state.results(careers: careers, matches: matches)
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

            if approvedInterests.isEmpty {
                ContentUnavailableView(
                    "No approved interests yet",
                    systemImage: "star",
                    description: Text(
                        "Careers are matched from interests a staff member has approved. Search to browse in the meantime."
                    )
                )
                .accessibilityIdentifier("careerDiscovery.noInterests")
            }

            if isLoading {
                ProgressView("Loading careers…")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("careerDiscovery.loading")
            } else if let loadError {
                ContentUnavailableView(
                    "Career catalog unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
                .accessibilityIdentifier("careerDiscovery.error")
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No careers match",
                    systemImage: "magnifyingglass",
                    description: Text("Try fewer words or clear the filters.")
                )
                .accessibilityIdentifier("careerDiscovery.empty")
            } else {
                ForEach(results) { career in
                    careerRow(career)
                }
            }
        }
        .padding(.vertical, TMISpacing.xs)
        .searchable(text: $state.query, prompt: "Search careers")
        .accessibilityIdentifier("careerDiscovery.screen")
        .task { await loadCatalog() }
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
            matches = try await repository.matches(
                approvedInterests: approvedInterests,
                clusters: clusters
            )
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
                    .accessibilityIdentifier("careerDiscovery.filter.\(level.rawValue)")
                }
                if state.hasActiveFilters {
                    Button("Clear") { state.clearFilters() }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("careerDiscovery.filter.clear")
                }
            }
        }
    }

    private func careerRow(_ career: CareerRecord) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            NavigationLink {
                CanonicalCareerDetailView(career: career, match: matchesByID[career.id])
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

            Button(state.isSelectedForComparison(career.id) ? "Selected to compare" : "Compare") {
                if !state.toggleComparison(career.id) {
                    limitMessage = "You can compare up to \(CareerDiscoveryState.maximumComparisons) careers at once."
                } else {
                    limitMessage = nil
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("careerDiscovery.compareToggle.\(career.id)")
        }
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
    }
}
