//
//  CareerExplorationView.swift
//  TMI
//
//  Career exploration view showing matched careers based on student interests
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CareerExplorationView: View {
    let studentId: String
    let careerMatches: [CareerMatchResult]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCareer: CareerPath?
    @State private var showingCareerDetail = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // Header
                    headerSection
                        .padding(.top, TMISpacing.lg)

                    // Top 3 Matches
                    if careerMatches.count >= 3 {
                        topMatchesSection
                    }

                    // All Career Matches
                    allMatchesSection
                        .padding(.bottom, TMISpacing.xl)
                }
            }
        }
        .navigationTitle("Career Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedCareer) { career in
            NavigationStack {
                CareerPathDetailView(career: career, studentId: studentId)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: TMISpacing.md) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.tmiPrimary)
                .symbolEffect(.pulse)

            Text("Your Career Matches")
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            Text("We found \(careerMatches.count) careers that match your interests")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TMISpacing.xl)
        }
    }

    // MARK: - Top 3 Matches

    private var topMatchesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Top Matches")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)
                .padding(.horizontal, TMISpacing.screenPadding)

            ForEach(careerMatches.prefix(3)) { match in
                topMatchCard(match)
                    .padding(.horizontal, TMISpacing.screenPadding)
            }
        }
    }

    private func topMatchCard(_ match: CareerMatchResult) -> some View {
        Button(action: {
            selectedCareer = match.career
            TMIHaptics.lightImpact()
        }) {
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                HStack(spacing: TMISpacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: match.career.color).opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: match.career.icon)
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: match.career.color))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.career.title)
                            .font(.tmiTitle3)
                            .foregroundColor(.tmiTextPrimary)

                        Text("\(match.matchPercentage)% match")
                            .font(.tmiCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.tmiSuccess)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiTextTertiary)
                }

                // Description
                Text(match.career.description)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(2)

                // Matching Interests
                if !match.matchingInterests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TMISpacing.sm) {
                            ForEach(match.matchingInterests.prefix(3), id: \.self) { interest in
                                interestTag(interest)
                            }
                        }
                    }
                }

                // Salary & Education
                HStack(spacing: TMISpacing.lg) {
                    if let salary = match.career.estimatedSalary {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.tmiTextTertiary)
                            Text(salary.displayRange)
                                .font(.tmiCaption)
                                .foregroundColor(.tmiTextSecondary)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap")
                            .foregroundColor(.tmiTextTertiary)
                        Text(match.career.educationLevel.rawValue)
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                    }
                }
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.lg)
                    .fill(Color.tmiSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.lg)
                    .strokeBorder(Color(hex: match.career.color).opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - All Matches

    private var allMatchesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("All Matches")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)
                .padding(.horizontal, TMISpacing.screenPadding)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.md) {
                ForEach(careerMatches) { match in
                    careerGridCard(match)
                }
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
    }

    private func careerGridCard(_ match: CareerMatchResult) -> some View {
        Button(action: {
            selectedCareer = match.career
            TMIHaptics.lightImpact()
        }) {
            VStack(spacing: TMISpacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: match.career.color).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: match.career.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: match.career.color))
                }

                // Title
                Text(match.career.title)
                    .font(.tmiCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.tmiTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Match percentage
                Text("\(match.matchPercentage)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tmiSuccess)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(Color.tmiSurface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func interestTag(_ interest: String) -> some View {
        let cluster = InterestCluster.allCategories.first { $0.name == interest }

        return HStack(spacing: 4) {
            if let cluster = cluster {
                Image(systemName: cluster.icon)
                    .font(.system(size: 10))
                Text(cluster.displayName)
                    .font(.system(size: 11))
            } else {
                Text(interest)
                    .font(.system(size: 11))
            }
        }
        .foregroundColor(.tmiPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.tmiPrimary.opacity(0.1))
        )
    }
}

// MARK: - Career Path Detail View



// MARK: - Preview

#Preview {
    NavigationStack {
        CareerExplorationView(
            studentId: "preview-student-id",
            careerMatches: [
                CareerMatchResult(
                    career: .podcaster,
                    score: 0.95,
                    matchingInterests: ["audio_media"],
                    suggestedTMIModules: [.chaseYourSpace, .acknowledgeInterests]
                ),
                CareerMatchResult(
                    career: .gameDeveloper,
                    score: 0.82,
                    matchingInterests: ["technology"],
                    suggestedTMIModules: [.chaseYourSpace, .alignYourMind]
                )
            ]
        )
    }
}
