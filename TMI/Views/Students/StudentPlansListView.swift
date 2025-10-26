//
//  StudentPlansListView.swift
//  TMI
//
//  Focused view showing all TMI plans for a specific student
//

import SwiftUI

struct StudentPlansListView: View {
    let student: Student
    let plans: [TMIPlan]

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            if plans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: TMISpacing.md) {
                        // Header
                        headerSection

                        // Plans
                        ForEach(plans) { plan in
                            NavigationLink(destination: TMIPlanDetailView(plan: plan)) {
                                planCard(plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, TMISpacing.screenPadding)
                    .padding(.vertical, TMISpacing.md)
                }
            }
        }
        .navigationTitle("TMI Plans")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: TMISpacing.md) {
                TMIAvatar(
                    initials: student.initials,
                    color: avatarColor,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.tmiTitle2)
                        .foregroundColor(.tmiTextPrimary)

                    Text("\(plans.count) Active Plan\(plans.count == 1 ? "" : "s")")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()
            }
        }
        .tmiCard()
    }

    // MARK: - Plan Card

    private func planCard(_ plan: TMIPlan) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            // Header with icon and model
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(planModelColor(for: plan.model).opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: planModelIcon(for: plan.model))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(planModelColor(for: plan.model))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Text(plan.model.rawValue)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiTextTertiary)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)

                    Spacer()

                    Text("\(Int(plan.progress * 100))%")
                        .font(.tmiCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(planModelColor(for: plan.model))
                }

                ProgressView(value: plan.progress)
                    .tmiProgressStyle(color: planModelColor(for: plan.model))
            }

            // Stats
            HStack(spacing: TMISpacing.md) {
                statItem(icon: "heart.fill", count: plan.interests.count, label: "Interests", color: .pink)
                statItem(icon: "person.fill", count: plan.students.count, label: "Students", color: .blue)

                if let endDate = plan.endDate {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target Date")
                            .font(.tmiFootnote)
                            .foregroundColor(.tmiTextTertiary)
                        Text(endDate, style: .date)
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                    }
                }
            }
        }
        .padding(TMISpacing.md)
        .tmiCard()
    }

    private func statItem(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.tmiLabelLarge)
                    .foregroundColor(.tmiTextPrimary)
                Text(label)
                    .font(.tmiFootnote)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.tmiTextTertiary)

            Text("No TMI Plans")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)

            Text("This student doesn't have any intervention plans yet")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TMISpacing.xl)
        }
    }

    // MARK: - Helpers

    private var avatarColor: Color {
        switch student.avatarColor {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }

    private func planModelIcon(for model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: return "airplane.departure"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.lefthalf.filled"
        }
    }

    private func planModelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }
}

#Preview {
    NavigationStack {
        StudentPlansListView(
            student: Student.sampleStudent,
            plans: TMIPlan.samplePlans
        )
    }
}
