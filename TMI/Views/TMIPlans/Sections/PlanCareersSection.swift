// PlanCareersSection.swift
// TMI
//
// Accordion section for linking careers to a TMI Plan.
// Shows selected careers, AI recommendations filtered by linked interests,
// and a button to open CareerExplorerView as an exploration sheet.

import SwiftUI
@preconcurrency import FirebaseFirestore

// MARK: - PlanCareersSection

/// Accordion-style section for viewing and editing the careers linked to a TMI plan.
/// Provides AI-style recommendations based on the plan's linked interests.
struct PlanCareersSection: View {
    @Binding var linkedCareers: [Career]
    var students: [Student]
    var linkedInterests: [Interest]

    // MARK: State

    @State private var searchText: String = ""
    @State private var showExploreSheet: Bool = false
    @State private var recommendedCareers: [Career] = []
    @State private var isLoadingRecommendations: Bool = false
    @State private var recommendationError: String?

    // MARK: Computed

    private var interestNames: Set<String> {
        Set(linkedInterests.map { $0.name.lowercased() })
    }

    private var filteredLinked: [Career] {
        guard !searchText.isEmpty else { return linkedCareers }
        let query = searchText.lowercased()
        return linkedCareers.filter {
            $0.title.lowercased().contains(query) || $0.field.lowercased().contains(query)
        }
    }

    private var filteredRecommendations: [Career] {
        let linkedIDs = Set(linkedCareers.compactMap { $0.id })
        return recommendedCareers.filter { career in
            guard let id = career.id else { return true }
            return !linkedIDs.contains(id)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            searchAndExploreBar
            linkedCareersSection
            recommendationsSection
        }
        .task(id: interestNames.sorted().description) {
            await loadRecommendations()
        }
        .sheet(isPresented: $showExploreSheet) {
            CareerExplorerView()
        }
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack {
            Label("Career Exploration", systemImage: "briefcase.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(linkedCareers.count) linked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var searchAndExploreBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search linked careers", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            Button {
                showExploreSheet = true
            } label: {
                Label("Explore", systemImage: "safari")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var linkedCareersSection: some View {
        if linkedCareers.isEmpty {
            ContentUnavailableView {
                Label("No Careers Linked", systemImage: "briefcase")
            } description: {
                Text("Search above or explore to add careers to this plan.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Linked Careers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if filteredLinked.isEmpty {
                    Text("No matches for \"\(searchText)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(filteredLinked) { career in
                        CareerCard(
                            career: career,
                            matchingInterests: matchingInterests(for: career),
                            actionLabel: "Remove",
                            actionSystemImage: "minus.circle.fill",
                            actionTint: .red
                        ) {
                            remove(career)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recommendations", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoadingRecommendations {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = recommendationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !isLoadingRecommendations && filteredRecommendations.isEmpty {
                Text(
                    interestNames.isEmpty
                        ? "Link interests to this plan to get career recommendations."
                        : "No additional recommendations based on linked interests."
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 4)
            } else {
                ForEach(filteredRecommendations) { career in
                    CareerRecommendationRow(
                        career: career,
                        matchingInterests: matchingInterests(for: career)
                    ) {
                        add(career)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func matchingInterests(for career: Career) -> [String] {
        career.relatedInterests.filter { interestNames.contains($0.lowercased()) }
    }

    private func add(_ career: Career) {
        guard !linkedCareers.contains(career) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            linkedCareers.append(career)
        }
    }

    private func remove(_ career: Career) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            linkedCareers.removeAll { $0 == career }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadRecommendations() async {
        guard !interestNames.isEmpty else {
            recommendedCareers = []
            return
        }
        isLoadingRecommendations = true
        recommendationError = nil
        defer { isLoadingRecommendations = false }

        do {
            let all = try await CareerService.shared.fetchAllCareers()
            recommendedCareers = all
                .filter { career in
                    career.relatedInterests.contains { interestNames.contains($0.lowercased()) }
                }
                .sorted { a, b in
                    matchingInterests(for: a).count > matchingInterests(for: b).count
                }
        } catch {
            recommendationError = "Could not load recommendations: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var linked: [Career] = []
    let interests: [Interest] = [
        Interest(name: "Technology", category: []),
        Interest(name: "Mathematics", category: [])
    ]
    return ScrollView {
        PlanCareersSection(linkedCareers: $linked, students: [], linkedInterests: interests)
            .padding()
    }
}
