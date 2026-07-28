//
//  CareerPathDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct CareerPathDetailView: View {
    let career: CareerPath
    let studentId: String? // Optional, as we might just be browsing

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLevel: SkillLevel = .beginner

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TMISpacing.xl) {
                    // Header
                    careerHeader

                    // Description
                    descriptionSection

                    // Pathway
                    pathwaySection

                    // TMI Modules
                    tmiModulesSection

                    // Action Button (only if studentId is provided)
                    if studentId != nil {
                        actionButton
                            .padding(.bottom, TMISpacing.xl)
                    }
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }
        }
        .navigationTitle(career.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var careerHeader: some View {
        VStack(spacing: TMISpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: career.color).opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: career.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: career.color))
            }

            VStack(spacing: TMISpacing.xs) {
                if let salary = career.estimatedSalary {
                    Text(salary.displayRange)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiSuccess)
                }

                Text(career.educationLevel.rawValue)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, TMISpacing.lg)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("About This Career")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Text(career.description)
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
    }

    private var pathwaySection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Learning Pathway")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            // Level Picker
            Picker("Level", selection: $selectedLevel) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)

            // Goals for selected level
            let goals = goalsForLevel(selectedLevel)
            if goals.isEmpty {
                Text("Pathway coming soon!")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .italic()
            } else {
                ForEach(goals) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: CEPGoal) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(goal.title)
                .font(.tmiBody)
                .fontWeight(.semibold)
                .foregroundColor(.tmiTextPrimary)

            if !goal.strategies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(goal.strategies, id: \.self) { strategy in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.tmiTextTertiary)
                            Text(strategy)
                                .font(.tmiCaption)
                                .foregroundColor(.tmiTextSecondary)
                        }
                    }
                }
            }

            if let duration = goal.estimatedDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("\(Int(duration))min")
                        .font(.tmiCaption)
                }
                .foregroundColor(.tmiTextTertiary)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }

    private var tmiModulesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Recommended TMI Modules")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            ForEach(career.pathway?.tmiModules ?? [], id: \.self) { module in
                HStack(spacing: TMISpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.tmiSuccess)
                    Text(module.rawValue)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextPrimary)
                }
            }
        }
    }

    private var actionButton: some View {
        HStack(alignment: .top, spacing: TMISpacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.tmiSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Plan creation arrives in Release 3")
                    .font(.tmiBody.bold())
                    .foregroundColor(.tmiTextPrimary)

                Text("You can explore this career now. Linking it to a canonical student plan will be available in the plan release.")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .padding(TMISpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tmiSurface)
        .clipShape(RoundedRectangle(cornerRadius: TMIRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .stroke(Color.tmiSecondary.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func createGoalsFromCareer() -> [Goal] {
        // Convert career pathway goals to TMI goals
        var goals: [Goal] = []

        // Add beginner goals
        for cepGoal in (career.pathway?.beginnerGoals ?? []).prefix(3) {
            goals.append(Goal(
                description: cepGoal.title,
                dueDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                status: .notStarted,
                progress: 0.0,
                notes: cepGoal.strategies.first
            ))
        }

        return goals
    }

    private func createStrategiesFromCareer() -> [String] {
        // Extract strategies from all levels
        var strategies: [String] = []

        for goal in (career.pathway?.beginnerGoals ?? []).prefix(2) {
            strategies.append(contentsOf: goal.strategies.prefix(2))
        }

        return Array(strategies.prefix(5))
    }

    // MARK: - Helpers

    private func goalsForLevel(_ level: SkillLevel) -> [CEPGoal] {
        switch level {
        case .beginner:
            return career.pathway?.beginnerGoals ?? []
        case .intermediate:
            return career.pathway?.intermediateGoals ?? []
        case .advanced:
            return career.pathway?.advancedGoals ?? []
        }
    }
}
