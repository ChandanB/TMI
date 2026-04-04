//
//  StudentInterestProfileView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #5
//  Connects student interests to career recommendations and resources
//

import SwiftUI

/// A comprehensive view showing a student's interest profile with career and resource connections
struct StudentInterestProfileView: View {
    let student: Student

    @State private var careerRecommendations: [Career] = []
    @State private var recommendedResources: [Resource] = []
    // careerInsights removed — no longer using AI-based discovery insights
    @State private var isLoading = false
    @State private var selectedCareer: Career?
    @State private var showingCareerDetail = false
    @State private var showingResourceAssignment = false
    @State private var selectedResource: Resource?

    @State private var interests: [Interest] = []
    @State private var interestCount: Int = 0

    private let careerService = CareerService.shared
    private let assignmentService = ResourceAssignmentService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                if isLoading {
                    loadingView
                } else {
                    // Student's Interests
                    interestsSection

                    // Career Recommendations
                    if !careerRecommendations.isEmpty {
                        careerRecommendationsSection
                    }

                    // Recommended Resources
                    if !recommendedResources.isEmpty {
                        resourcesSection
                    }
                }
            }
            .padding()
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Interest Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showingCareerDetail) {
            if let career = selectedCareer {
                NavigationStack {
                    CareerDetailView(career: career, student: student)
                }
                .tmiSheetStyle()
            }
        }
        .sheet(isPresented: $showingResourceAssignment) {
            if let resource = selectedResource {
                ResourceAssignmentSheet(
                    resource: resource,
                    student: student,
                    assignmentService: assignmentService
                )
                .tmiSheetStyle()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("\(interestCount) Interests")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()
                }
            }
            .padding()
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Interests")
                .font(.title3.bold())
                .foregroundColor(.white)

            if interests.isEmpty {
                TMIGlassCard(style: .default) {
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.7))

                        Text("No interests added yet")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Add interests to get personalized career recommendations")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(interests) { interest in
                        StudentInterestCard(interest: interest)
                    }
                }
            }
        }
    }

    // MARK: - Career Recommendations

    private var careerRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Careers")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Spacer()

                Text("\(careerRecommendations.count) matches")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("Based on your interests and strengths")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            ForEach(Array(careerRecommendations.prefix(5).enumerated()), id: \.element.title) { index, career in
                CareerRecommendationCard(
                    career: career,
                    rank: index + 1,
                    student: student,
                    interests: interests,
                    onTap: {
                        selectedCareer = career
                        showingCareerDetail = true
                    }
                )
            }
        }
    }

    // MARK: - Insights Section

    // insightsSection removed — CareerDiscoveryInsights no longer used

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Resources")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Spacer()

                Text("\(recommendedResources.count) resources")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("Resources to help you explore these career paths")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            ForEach(recommendedResources.prefix(6)) { resource in
                ResourceRecommendationCard(
                    resource: resource,
                    onAssign: {
                        selectedResource = resource
                        showingResourceAssignment = true
                    }
                )
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Analyzing your interests...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadProfile() async {
        isLoading = true

        do {
            // Load student interests from edge collection
            interests = try await student.fetchInterestsFromEdgeCollection()
            interestCount = try await student.getInterestCount()

            // Load career recommendations
            careerRecommendations = try await careerService.getCareerRecommendations(for: student)

            // Load recommended resources (stub for now)
            recommendedResources = []

        } catch {
            print("[StudentInterestProfileView] Failed to load profile: \(error)")
            interests = []
            interestCount = 0
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

private struct StudentInterestCard: View {
    let interest: Interest

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(interest.color.gradient)

                Text(interest.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CareerRecommendationCard: View {
    let career: Career
    let rank: Int
    let student: Student
    let interests: [Interest]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(rankColor.gradient)
                                .frame(width: 32, height: 32)

                            Text("#\(rank)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(career.title)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(career.field)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Match explanation
                    MatchExplanationView(career: career, student: student, interests: interests)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .orange
        case 3: return .green
        default: return .blue
        }
    }
}

private struct MatchExplanationView: View {
    let career: Career
    let student: Student
    let interests: [Interest]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why this matches:")
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.8))

            // Show matching interests
            let matchingInterests = interests.filter { interest in
                career.title.lowercased().contains(interest.name.lowercased()) ||
                career.field.lowercased().contains(interest.name.lowercased()) ||
                career.skills.contains { skill in
                    interest.name.lowercased().contains(skill.lowercased())
                }
            }

            if !matchingInterests.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)

                    Text("Matches your interests: \(matchingInterests.map { $0.name }.prefix(2).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            // Show growth potential
            if career.growthRate > 0.1 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(.green)

                    Text("High growth field (\(Int(career.growthRate * 100))% growth)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}

private struct ResourceRecommendationCard: View {
    let resource: Resource
    let onAssign: () -> Void

    var body: some View {
        TMIGlassCard(style: .default) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: resource.category.icon)
                    .font(.title2)
                    .foregroundStyle(resource.category.color.gradient)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(resource.category.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                TMIButton(
                    text: "Assign",
                    style: .secondary,
                    action: onAssign
                )
                .frame(width: 80)
            }
            .padding()
        }
    }
}

private struct InsightRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            Spacer()
        }
    }
}

// MARK: - Resource Assignment Sheet

private struct ResourceAssignmentSheet: View {
    let resource: Resource
    let student: Student
    let assignmentService: ResourceAssignmentService

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var isAssigning = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Resource preview
                VStack(alignment: .leading, spacing: 12) {
                    Text(resource.title)
                        .font(.title2.bold())

                    Text(resource.description)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Label(resource.category.rawValue, systemImage: resource.category.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Reason field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assignment Reason (Optional)")
                        .font(.headline)

                    TextField("Why is this resource helpful for this student?", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                Spacer()

                // Action buttons
                if showSuccess {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)

                        Text("Resource assigned successfully!")
                            .font(.headline)
                    }
                    .padding()
                } else {
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button(action: assignResource) {
                            if isAssigning {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Assign to \(student.firstName)")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAssigning)
                    }
                }
            }
            .padding()
            .navigationTitle("Assign Resource")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func assignResource() {
        guard let studentId = student.id,
              let resourceId = resource.id else { return }

        isAssigning = true

        Task {
            do {
                try await assignmentService.assignResource(
                    resourceId: resourceId,
                    studentId: studentId,
                    planId: nil,
                    resourceTitle: resource.title,
                    resourceCategory: resource.category.rawValue,
                    resourceURL: resource.url
                )

                await MainActor.run {
                    isAssigning = false
                    showSuccess = true

                    // Auto-dismiss after showing success
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isAssigning = false
                }
                print("[ResourceAssignmentSheet] Failed to assign resource: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StudentInterestProfileView(student: .sampleStudents[0])
    }
}

