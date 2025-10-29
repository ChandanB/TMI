//
//  StudentTMIPlanDetailView.swift
//  TMI
//
//  Student-friendly view of TMI Plan with only relevant information
//

import SwiftUI

struct StudentTMIPlanDetailView: View {
    let plan: TMIPlan

    @State private var scheduledMeetings: [Meeting] = []
    @State private var isLoadingMeetings = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // Header Card
                    headerCard

                    // Progress Section
                    progressSection

                    // My Goals Section
                    if !plan.goals.isEmpty {
                        goalsSection
                    }

                    // Upcoming Meetings Section
                    upcomingMeetingsSection

                    // Interests Section
                    if !plan.interests.isEmpty {
                        interestsSection
                    }

                    // Note: Resources section removed - TMIPlan doesn't have resources property
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .navigationTitle("My Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMeetings()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.tmiPrimary.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: "target")
                            .font(.system(size: 28))
                            .foregroundColor(.tmiPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.model.rawValue)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Your personalized plan")
                            .font(.system(size: 14))
                            .foregroundColor(.tmiTextSecondary)
                    }

                    Spacer()
                }

                if let description = planDescription {
                    Text(description)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                        .padding(.top, TMISpacing.sm)
                }
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                Text("My Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: TMISpacing.sm) {
                    HStack {
                        Text("\(plan.progressPercentage)%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.tmiSuccess)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(completedGoalsCount) of \(plan.goals.count)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("goals completed")
                                .font(.system(size: 14))
                                .foregroundColor(.tmiTextSecondary)
                        }
                    }

                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.tmiSurface)
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.tmiSuccess, Color.tmiSuccess.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * (Double(plan.progressPercentage) / 100), height: 12)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("My Goals")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, TMISpacing.xs)

            VStack(spacing: TMISpacing.sm) {
                ForEach(plan.goals) { goal in
                    StudentGoalCard(goal: goal)
                }
            }
        }
    }

    // MARK: - Upcoming Meetings Section

    private var upcomingMeetingsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Upcoming Meetings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, TMISpacing.xs)

            if isLoadingMeetings {
                ProgressView()
                    .tint(.tmiPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(TMISpacing.lg)
            } else if scheduledMeetings.isEmpty {
                TMIGlassCard(style: .default) {
                    VStack(spacing: TMISpacing.md) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundColor(.tmiTextTertiary)

                        Text("No upcoming meetings")
                            .font(.tmiBody)
                            .foregroundColor(.tmiTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(TMISpacing.lg)
                }
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(scheduledMeetings.prefix(3)) { meeting in
                        StudentMeetingCard(meeting: meeting)
                    }
                }
            }
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("My Interests")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, TMISpacing.xs)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: TMISpacing.sm) {
                ForEach(plan.interests) { interest in
                    StudentInterestChip(interest: interest)
                }
            }
        }
    }


    // MARK: - Helpers

    private var planDescription: String? {
        switch plan.model {
        case .chaseYourSpace:
            return "A plan focused on exploring your interests and finding what excites you."
        case .acknowledgeInterests:
            return "Recognizing and developing your unique interests and talents."
        case .alignYourMind:
            return "Helping you stay focused and on track with your goals."
        case .directAndCorrect:
            return "Building positive behaviors and making good choices."
        case .bullyToBoss:
            return "Transforming leadership skills in a positive direction."
        case .meekToProtector:
            return "Building confidence and protective skills."
        }
    }

    private var completedGoalsCount: Int {
        plan.goals.filter { $0.status == .completed }.count
    }

    private func loadMeetings() async {
        guard let planId = plan.id else { return }

        isLoadingMeetings = true
        defer { isLoadingMeetings = false }

        do {
            let service = MeetingService.shared
            let allMeetings = try await service.fetchMeetings(for: planId)

            // Filter to upcoming meetings only
            let now = Date()
            scheduledMeetings = allMeetings.filter { $0.startTime > now }
                .sorted { $0.startTime < $1.startTime }
        } catch {
            print("[StudentTMIPlanDetail] Error loading meetings: \(error)")
        }
    }
}

// MARK: - Supporting Components

struct StudentGoalCard: View {
    let goal: Goal

    var body: some View {
        TMIGlassCard(style: .default) {
            HStack(spacing: TMISpacing.md) {
                // Completion Circle
                ZStack {
                    Circle()
                        .stroke(Color.tmiTextTertiary.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if goal.status == .completed {
                        Circle()
                            .fill(Color.tmiSuccess)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.description)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if let dueDate = goal.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text("Due \(dueDate, style: .date)")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.tmiTextSecondary)
                    }
                }

                Spacer()

                // Status Badge
                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch goal.status {
            case .notStarted:
                Text("Not Started")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tmiTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.tmiSurface)
                    )
            case .inProgress:
                Text("In Progress")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tmiPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.tmiPrimary.opacity(0.2))
                    )
            case .completed:
                Text("Completed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tmiSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.tmiSuccess.opacity(0.2))
                    )
            }
        }
    }
}

struct StudentMeetingCard: View {
    let meeting: Meeting

    var body: some View {
        TMIGlassCard(style: .default) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.tmiSecondary.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundColor(.tmiSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(meeting.startTime, style: .time)
                                .font(.system(size: 14))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(meeting.startTime, style: .date)
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(.tmiTextSecondary)
                }

                Spacer()
            }
        }
    }
}

struct StudentInterestChip: View {
    let interest: Interest

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: interest.iconName)
                .font(.system(size: 16))
                .foregroundColor(interest.color)

            Text(interest.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm)
                .fill(Color.tmiSurface)
        )
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        StudentTMIPlanDetailView(plan: TMIPlan.samplePlans[0])
    }
}
