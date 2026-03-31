// StudentCareersSection.swift
// TMI
//
// Career Exploration accordion section for student profile views.
// Shows selected careers, AI recommendations filtered by student interests,
// and a button to open CareerExplorerView as a full exploration sheet.

import SwiftUI
@preconcurrency import FirebaseFirestore

// MARK: - Main Section View

struct StudentCareersSection: View {
    @Binding var selectedCareers: [Career]
    var studentInterests: [Interest]

    @State private var searchText: String = ""
    @State private var showExploreSheet: Bool = false
    @State private var recommendedCareers: [Career] = []
    @State private var isLoadingRecommendations: Bool = false
    @State private var recommendationError: String?

    // Interest names for matching
    private var interestNames: Set<String> {
        Set(studentInterests.map { $0.name.lowercased() })
    }

    // Filter selected careers by search text
    private var filteredSelected: [Career] {
        guard !searchText.isEmpty else { return selectedCareers }
        let query = searchText.lowercased()
        return selectedCareers.filter {
            $0.title.lowercased().contains(query) || $0.field.lowercased().contains(query)
        }
    }

    // Exclude already-selected careers from recommendations
    private var filteredRecommendations: [Career] {
        let selectedIDs = Set(selectedCareers.compactMap { $0.id })
        return recommendedCareers.filter { career in
            guard let id = career.id else { return true }
            return !selectedIDs.contains(id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            searchAndExploreBar
            selectedCareersSection
            recommendationsSection
        }
        .task {
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
            Text("\(selectedCareers.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var searchAndExploreBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search selected careers", text: $searchText)
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
    private var selectedCareersSection: some View {
        if selectedCareers.isEmpty {
            ContentUnavailableView {
                Label("No Careers Selected", systemImage: "briefcase")
            } description: {
                Text("Search above or explore to add careers to this student's profile.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Careers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if filteredSelected.isEmpty {
                    Text("No matches for \"\(searchText)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(filteredSelected) { career in
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
                Label("AI Recommendations", systemImage: "sparkles")
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
                Text(interestNames.isEmpty
                     ? "Add student interests to get career recommendations."
                     : "No additional recommendations based on current interests.")
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
        guard !selectedCareers.contains(career) else { return }
        selectedCareers.append(career)
    }

    private func remove(_ career: Career) {
        selectedCareers.removeAll { $0 == career }
    }

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
            // Filter: career must have at least one relatedInterest matching a student interest name
            recommendedCareers = all.filter { career in
                career.relatedInterests.contains { interestNames.contains($0.lowercased()) }
            }
            // Sort by match count descending
            .sorted { a, b in
                matchingInterests(for: a).count > matchingInterests(for: b).count
            }
        } catch {
            recommendationError = "Could not load recommendations: \(error.localizedDescription)"
        }
    }
}

// MARK: - CareerCard

struct CareerCard: View {
    let career: Career
    let matchingInterests: [String]
    let actionLabel: String
    let actionSystemImage: String
    let actionTint: Color
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(career.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(career.field)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !matchingInterests.isEmpty {
                    interestMatchChips
                }
            }

            Spacer(minLength: 0)

            Button(role: actionTint == .red ? .destructive : nil) {
                onAction()
            } label: {
                Image(systemName: actionSystemImage)
                    .font(.title3)
                    .foregroundStyle(actionTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(actionLabel) \(career.title)")
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var interestMatchChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(matchingInterests, id: \.self) { interest in
                    Text(interest)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

// MARK: - CareerRecommendationRow

struct CareerRecommendationRow: View {
    let career: Career
    let matchingInterests: [String]
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(career.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !matchingInterests.isEmpty {
                        Text("\(matchingInterests.count) match\(matchingInterests.count == 1 ? "" : "es")")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                Text(career.field)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !matchingInterests.isEmpty {
                    Text("Matches: \(matchingInterests.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(career.title)")
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("With Interests") {
    @Previewable @State var selected: [Career] = [Career.sampleCareers[0]]
    let interests: [Interest] = {
        let i1 = Interest(name: "Technology", category: [])
        let i2 = Interest(name: "Mathematics", category: [])
        return [i1, i2]
    }()
    return ScrollView {
        StudentCareersSection(selectedCareers: $selected, studentInterests: interests)
            .padding()
    }
}

#Preview("Empty State") {
    @Previewable @State var selected: [Career] = []
    return ScrollView {
        StudentCareersSection(selectedCareers: $selected, studentInterests: [])
            .padding()
    }
}
