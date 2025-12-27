//
//  TMIPlanDetailView.swift
//  TMI
//
//  Redesigned to focus on delivering actual intervention content,
//  not just tracking metadata. Shows what students care about,
//  what resources they're receiving, and concrete next steps.
//

import Charts
import SwiftUI

struct TMIPlanDetailView: View {
    let initialPlan: TMIPlan
    @Environment(\.dismiss) private var dismiss

    // Reactive plan state
    @State private var plan: TMIPlan

    // UI States
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var selectedStudent: Student?
    @State private var showingAddInterest = false
    @State private var showingAddGoal = false
    @State private var showingCompleteSurvey = false
    @State private var selectedGoal: Goal?
    @State private var interestsStateModel = InterestsAndHobbiesStateModel()

    // Generated Resources
    @State private var showingAddResource = false

    // Meetings
    @State private var showingScheduleMeeting = false
    @State private var scheduledMeetings: [Meeting] = []
    @State private var isLoadingMeetings = false

    init(plan: TMIPlan) {
        self.initialPlan = plan
        _plan = State(initialValue: plan)
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .plans)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // 1. Plan Overview - What is this plan about?
                    planOverviewSection

                    // 2. Student Interests - What do they care about?
                    studentInterestsSection

                    // 3. Resources - What are they getting?
                    resourcesSection

                    // 4. Intervention Strategies - How do teachers help?
                    interventionStrategiesSection

                    // 5. Goals & Progress - What are we achieving?
                    goalsAndProgressSection

                    // 6. Scheduled Meetings - Check-ins and progress reviews
                    scheduledMeetingsSection

                    // 7. Collaboration Notes - Teacher/counselor communication
                    collaborationNotesSection

                    Spacer(minLength: TMISpacing.xxl)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
                .padding(.top, TMISpacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(plan.model.shortDisplayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(plan.students.count) student\(plan.students.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit Plan", systemImage: "pencil")
                    }

                    Button(action: { /* Export action */ }) {
                        Label("Export Plan", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditTMIPlanView(plan: plan) { updatedPlan in
                    plan = updatedPlan
                    Task {
                        await refreshPlan()
                    }
                }
            }
        }
        .alert("Delete TMI Plan", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deletePlan() }
        } message: {
            Text("Are you sure you want to delete this TMI plan? This action cannot be undone.")
        }
        .sheet(item: $selectedStudent) { student in
            NavigationStack {
                StudentDetailView(student: student)
            }
        }
        .sheet(isPresented: $showingAddInterest) {
            NavigationStack {
                AddInterestToPlanView(plan: plan) { updatedPlan in
                    plan = updatedPlan
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddInterest = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            NavigationStack {
                AddGoalView(plan: plan) { newGoal in
                    Task {
                        await addGoalToPlan(newGoal)
                    }
                }
            }
        }
        .sheet(item: $selectedGoal) { goal in
            NavigationStack {
                EditGoalView(plan: plan, goal: goal) { updatedGoal in
                    Task {
                        await updateGoal(updatedGoal)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCompleteSurvey) {
            NavigationStack {
                InterestSurveyView(plan: plan, onComplete: { interests in
                    Task {
                        await addInterestsFromSurvey(interests)
                    }
                })
            }
        }
        .sheet(isPresented: $showingAddResource) {
            NavigationStack {
                AddResourceView { newResource in
                    Task {
                        await addResourceToPlan(newResource)
                    }
                }
            }
        }
        .sheet(isPresented: $showingScheduleMeeting) {
            NavigationStack {
                ScheduleMeetingView(
                    planId: plan.id ?? "",
                    relatedStudentIds: plan.students.compactMap { $0.id },
                    onComplete: {
                        Task {
                            await loadMeetings()
                        }
                    }
                )
            }
        }
        .refreshable {
            await refreshPlan()
            await loadMeetings()
        }
        .task {
            await loadMeetings()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Plan Overview Section

    private var planOverviewSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Model badge and status
            HStack(alignment: .center, spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(modelColor.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Circle()
                        .stroke(modelColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 64, height: 64)

                    Image(systemName: modelIcon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(modelColor)
                }
                .shadow(color: modelColor.opacity(0.3), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.model.rawValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text(plan.model.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            TMIDivider()

            // Next Action - Make it prominent
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiWarning)
                    Text("Next Action")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Text(nextActionText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Show action button if relevant
                    if shouldShowScheduleMeetingButton {
                        Button(action: { showingScheduleMeeting = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 14))
                                Text("Schedule Check-In")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, TMISpacing.md)
                            .padding(.vertical, TMISpacing.sm)
                            .background(
                                Capsule()
                                    .fill(modelColor)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(TMISpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .fill(modelColor.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .strokeBorder(modelColor.opacity(0.3), lineWidth: 1)
                )
            }

            // Associated students
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Text("Students in this plan")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TMISpacing.sm) {
                        ForEach(plan.students) { student in
                            Button(action: { selectedStudent = student }) {
                                StudentMiniCard(student: student, modelColor: modelColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [modelColor.opacity(0.3), .clear, modelColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Student Interests Section

    private var studentInterestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.tmiPrimary)

                Text("What They Care About")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !plan.interests.isEmpty {
                    Text("\(plan.interests.count) interest\(plan.interests.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tmiPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.tmiPrimary.opacity(0.2))
                        )
                }

                Button(action: { showingAddInterest = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.tmiPrimary)
                }
                .buttonStyle(.plain)
            }

            if plan.interests.isEmpty {
                VStack(spacing: TMISpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.tmiWarning)

                    Text("No Interests Identified")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("This plan needs student interests to be effective. Complete the interest survey with \(plan.primaryStudent?.name ?? "the student") to personalize their pathway.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { showingCompleteSurvey = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                            Text("Complete Interest Survey")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, TMISpacing.lg)
                        .padding(.vertical, TMISpacing.md)
                        .background(
                            Capsule()
                                .fill(Color.tmiPrimary)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(TMISpacing.xl)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
                    ForEach(plan.interests) { interest in
                        InterestCard(interest: interest)
                    }
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Personalized Resources Section

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.tmiSuccess)

                Text("Resources")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !plan.resources.isEmpty {
                    Text("\(plan.resources.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tmiSuccess)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.tmiSuccess.opacity(0.2))
                        )
                }

                Button(action: { showingAddResource = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.tmiSuccess)
                }
                .buttonStyle(.plain)
            }

            if plan.resources.isEmpty {
                VStack(spacing: TMISpacing.md) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32))
                        .foregroundColor(.tmiSuccess.opacity(0.5))

                    Text("No Resources Added")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Add resources to support this plan.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: { showingAddResource = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Resource")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiSuccess)
                        .padding(.horizontal, TMISpacing.lg)
                        .padding(.vertical, TMISpacing.md)
                        .background(
                            Capsule()
                                .fill(Color.tmiSuccess.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.tmiSuccess.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(TMISpacing.lg)
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(plan.resources) { resource in
                        ResourceCard(resource: resource)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await deleteResource(resource)
                                    }
                                } label: {
                                    Label("Delete Resource", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Intervention Strategies Section

    private var interventionStrategiesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.tmiSecondary)

                Text("Intervention Strategies")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text("For Educators")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: TMISpacing.sm) {
                ForEach(modelStrategies, id: \.self) { strategy in
                    StrategyRow(strategy: strategy, modelColor: modelColor)
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Goals & Progress Section

    private var goalsAndProgressSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(modelColor)

                Text("Goals & Milestones")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Progress indicator
                HStack(spacing: 6) {
                    Text("\(plan.progressPercentage)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(modelColor)

                    Text("Complete")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(modelColor.opacity(0.2))
                )
            }

            // What we're measuring
            VStack(alignment: .leading, spacing: 8) {
                Text("Measuring: Behavioral Engagement & Academic Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text("Tracking on-task behavior, assignment completion, and positive peer interactions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.sm)
                    .fill(Color.white.opacity(0.05))
            )

            // Goals list
            if plan.goals.isEmpty {
                VStack(spacing: TMISpacing.sm) {
                    Text("No goals set for this plan")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: { showingAddGoal = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Add First Goal")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(modelColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(TMISpacing.lg)
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(plan.goals) { goal in
                        Button(action: {
                            selectedGoal = goal
                        }) {
                            GoalCard(goal: goal, modelColor: modelColor)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { showingAddGoal = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Add Another Goal")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(modelColor)
                        .padding(TMISpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.md)
                                .fill(modelColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TMIRadius.md)
                                .strokeBorder(modelColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Scheduled Meetings Section

    private var scheduledMeetingsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.tmiSecondary)

                Text("Scheduled Meetings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !scheduledMeetings.isEmpty {
                    Text("\(scheduledMeetings.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tmiSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.tmiSecondary.opacity(0.2))
                        )
                }

                Button(action: { showingScheduleMeeting = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.tmiSecondary)
                }
                .buttonStyle(.plain)
            }

            if isLoadingMeetings {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading meetings...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(TMISpacing.lg)
                .frame(maxWidth: .infinity, alignment: .center)
            } else if scheduledMeetings.isEmpty {
                VStack(spacing: TMISpacing.sm) {
                    Text("No meetings scheduled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: { showingScheduleMeeting = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Schedule First Meeting")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(TMISpacing.lg)
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(scheduledMeetings.prefix(5)) { meeting in
                        MeetingCard(meeting: meeting, modelColor: modelColor)
                    }

                    if scheduledMeetings.count > 5 {
                        Button(action: {
                            // TODO: Show all meetings view
                        }) {
                            HStack {
                                Text("View all \(scheduledMeetings.count) meetings")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.tmiSecondary)
                            .padding(TMISpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: TMIRadius.md)
                                    .fill(Color.tmiSecondary.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Collaboration Notes Section

    private var collaborationNotesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)

                Text("Team Collaboration")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            if plan.notes.isEmpty {
                Text("No collaboration notes yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(TMISpacing.lg)
            } else {
                Text(plan.notes)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .padding(TMISpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TMIRadius.md)
                            .fill(Color.white.opacity(0.05))
                    )
            }

            Button(action: { showingEditSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add Note")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helper Properties

    private var modelIcon: String {
        switch plan.model {
        case .chaseYourSpace: return "airplane.departure"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.lefthalf.filled"
        }
    }

    private var modelColor: Color {
        switch plan.model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }

    private var nextActionText: String {
        if plan.interests.isEmpty {
            return "Complete interest survey with \(plan.primaryStudent?.name ?? "student") to personalize this plan"
        } else if plan.goals.isEmpty {
            return "Set specific, measurable goals for this intervention"
        } else if !scheduledMeetings.isEmpty {
             // If a meeting is already scheduled, the next action is to prepare for it
             if let nextMeeting = scheduledMeetings.first(where: { $0.startTime > Date() }) {
                 return "Prepare for \(nextMeeting.title) on \(formattedDate(nextMeeting.startTime))"
             } else {
                 return "Review outcomes from recent meetings and adjust strategies"
             }
        } else if plan.calculatedProgress < 0.3 {
            return "Schedule check-in to review initial progress and adjust strategies"
        } else if plan.calculatedProgress < 0.7 {
            return "Continue current strategies and document student improvements"
        } else {
            return "Prepare for transition planning and celebrate achievements"
        }
    }

    private var shouldShowScheduleMeetingButton: Bool {
        // Only show if no future meetings are scheduled and we're in early/mid stages
        let hasFutureMeetings = scheduledMeetings.contains { $0.startTime > Date() }
        return !plan.interests.isEmpty && !plan.goals.isEmpty && !hasFutureMeetings && plan.calculatedProgress < 0.9
    }

    private var modelStrategies: [String] {
        switch plan.model {
        case .chaseYourSpace:
            return [
                "Connect classroom lessons to their chosen career pathway",
                "Invite guest speakers from their field of interest",
                "Assign projects that build skills for their career goal",
                "Celebrate progress toward their dream career"
            ]
        case .acknowledgeInterests:
            return [
                "Reference their interests when giving examples in class",
                "Create assignments that incorporate their hobbies",
                "Display their interests in their workspace",
                "Connect with them through their passions"
            ]
        case .alignYourMind:
            return [
                "Use their interests as focus tools during independent work",
                "Create organization systems themed around their hobbies",
                "Provide breaks that involve their interests",
                "Check in using interest-based conversation starters"
            ]
        case .directAndCorrect:
            return [
                "Relate behavioral scenarios to their interests",
                "Use interest-based rewards for positive behavior",
                "Partner with social worker to develop coping skills",
                "Frame redirections using examples from their hobbies"
            ]
        case .bullyToBoss:
            return [
                "Channel leadership energy into positive roles",
                "Assign peer mentoring opportunities",
                "Connect their interests to leadership examples",
                "Teach conflict resolution through interest-based scenarios"
            ]
        case .meekToProtector:
            return [
                "Build confidence through interest-based presentations",
                "Create safe spaces to share their passions",
                "Use their hobbies to practice assertiveness",
                "Celebrate small wins related to their interests"
            ]
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func deletePlan() {
        Task {
            do {
                try await TMIPlanService().deletePlan(plan)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("[TMIPlanDetail] Error deleting plan: \(error)")
            }
        }
    }

    @MainActor
    private func addGoalToPlan(_ newGoal: Goal) async {
        do {
            var goals = plan.goals
            goals.append(newGoal)

            let service = TMIPlanService()
            let planWithNewGoals = TMIPlan(
                id: plan.id,
                title: plan.title,
                description: plan.description,
                students: plan.students,
                model: plan.model,
                interests: plan.interests,
                startDate: plan.startDate,
                endDate: plan.endDate,
                creationDate: plan.creationDate,
                lastUpdated: Date(),
                goals: goals,
                progress: plan.progress,
                notes: plan.notes,
                strategies: plan.strategies,
                progressTracking: plan.progressTracking,
                createdBy: plan.createdBy
            )

            let savedPlan = try await service.updatePlan(planWithNewGoals)
            plan = savedPlan // Update local state immediately
            showingAddGoal = false
        } catch {
            print("[TMIPlanDetail] Error adding goal: \(error)")
        }
    }

    @MainActor
    private func updateGoal(_ updatedGoal: Goal) async {
        do {
            var goals = plan.goals

            if let index = goals.firstIndex(where: { $0.id == updatedGoal.id }) {
                goals[index] = updatedGoal
            }

            let service = TMIPlanService()
            let planWithUpdatedGoals = TMIPlan(
                id: plan.id,
                title: plan.title,
                description: plan.description,
                students: plan.students,
                model: plan.model,
                interests: plan.interests,
                startDate: plan.startDate,
                endDate: plan.endDate,
                creationDate: plan.creationDate,
                lastUpdated: Date(),
                goals: goals,
                progress: plan.progress,
                notes: plan.notes,
                strategies: plan.strategies,
                progressTracking: plan.progressTracking,
                createdBy: plan.createdBy
            )

            let savedPlan = try await service.updatePlan(planWithUpdatedGoals)
            plan = savedPlan // Update local state immediately
            selectedGoal = nil
        } catch {
            print("[TMIPlanDetail] Error updating goal: \(error)")
        }
    }

    @MainActor
    private func addInterestsFromSurvey(_ interests: [Interest]) async {
        do {
            let newInterests = interests.filter { newInterest in
                !plan.interests.contains(where: { $0.id == newInterest.id })
            }

            let service = TMIPlanService()
            let planWithNewInterests = TMIPlan(
                id: plan.id,
                title: plan.title,
                description: plan.description,
                students: plan.students,
                model: plan.model,
                interests: plan.interests + newInterests,
                startDate: plan.startDate,
                endDate: plan.endDate,
                creationDate: plan.creationDate,
                lastUpdated: Date(),
                goals: plan.goals,
                progress: plan.progress,
                notes: plan.notes,
                strategies: plan.strategies,
                progressTracking: plan.progressTracking,
                createdBy: plan.createdBy
            )

            let savedPlan = try await service.updatePlan(planWithNewInterests)
            plan = savedPlan // Update local state immediately
            showingCompleteSurvey = false
        } catch {
            print("[TMIPlanDetail] Error adding interests from survey: \(error)")
        }
    }

    @MainActor
    private func refreshPlan() async {
        guard let planId = plan.id else { return }

        do {
            let service = TMIPlanService()
            if let refreshedPlan = try await service.fetchPlan(byId: planId) {
                plan = refreshedPlan
            }
        } catch {
            print("[TMIPlanDetail] Error refreshing plan: \(error)")
        }
    }

    @MainActor
    private func loadMeetings() async {
        guard let planId = plan.id else { return }

        isLoadingMeetings = true
        defer { isLoadingMeetings = false }

        do {
            let meetings = try await MeetingService.shared.fetchMeetings(for: planId)
            scheduledMeetings = meetings.sorted { $0.startTime < $1.startTime }
            print("[TMIPlanDetail] Loaded \(meetings.count) meetings for plan")
        } catch {
            print("[TMIPlanDetail] Error loading meetings: \(error)")
            scheduledMeetings = []
        }
    }

    @MainActor
    private func addResourceToPlan(_ resource: Resource) async {
        do {
            var resources = plan.resources
            resources.append(resource)

            let service = TMIPlanService()
            let planWithNewResources = TMIPlan(
                id: plan.id,
                title: plan.title,
                description: plan.description,
                students: plan.students,
                model: plan.model,
                interests: plan.interests,
                startDate: plan.startDate,
                endDate: plan.endDate,
                creationDate: plan.creationDate,
                lastUpdated: Date(),
                goals: plan.goals,
                progress: plan.progress,
                notes: plan.notes,
                strategies: plan.strategies,
                progressTracking: plan.progressTracking,
                createdBy: plan.createdBy,
                resources: resources
            )

            let savedPlan = try await service.updatePlan(planWithNewResources)
            plan = savedPlan
            showingAddResource = false
        } catch {
            print("[TMIPlanDetail] Error adding resource: \(error)")
        }
    }

    @MainActor
    private func deleteResource(_ resource: Resource) async {
        do {
            var resources = plan.resources
            resources.removeAll { $0.id == resource.id }

            let service = TMIPlanService()
            let planWithUpdatedResources = TMIPlan(
                id: plan.id,
                title: plan.title,
                description: plan.description,
                students: plan.students,
                model: plan.model,
                interests: plan.interests,
                startDate: plan.startDate,
                endDate: plan.endDate,
                creationDate: plan.creationDate,
                lastUpdated: Date(),
                goals: plan.goals,
                progress: plan.progress,
                notes: plan.notes,
                strategies: plan.strategies,
                progressTracking: plan.progressTracking,
                createdBy: plan.createdBy,
                resources: resources
            )

            let savedPlan = try await service.updatePlan(planWithUpdatedResources)
            plan = savedPlan
        } catch {
            print("[TMIPlanDetail] Error deleting resource: \(error)")
        }
    }
}

// MARK: - Supporting Components

struct MeetingCard: View {
    let meeting: Meeting
    let modelColor: Color

    private var statusColor: Color {
        switch meeting.status {
        case .scheduled, .confirmed: return .tmiPrimary
        case .completed: return .tmiSuccess
        case .cancelled: return .tmiTextTertiary
        case .rescheduled: return .tmiWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Meeting type icon
                ZStack {
                    Circle()
                        .fill(Color(hex: meeting.meetingType.color).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: meeting.meetingType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: meeting.meetingType.color))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(meeting.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(formattedDate(meeting.startTime))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(formattedTime(meeting.startTime)) - \(formattedTime(meeting.endTime))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))

                    if let location = meeting.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.system(size: 11))
                            Text(location)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Status badge
                Text(meeting.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.2))
                    )
            }

            // Participants
            if !meeting.participants.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Participants:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 6) {
                        ForEach(meeting.participants.prefix(3)) { participant in
                            HStack(spacing: 4) {
                                Image(systemName: participant.role.icon)
                                    .font(.system(size: 10))
                                Text(participant.name)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }

                        if meeting.participants.count > 3 {
                            Text("+\(meeting.participants.count - 3)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(modelColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StudentMiniCard: View {
    let student: Student
    let modelColor: Color

    var body: some View {
        HStack(spacing: 10) {
            TMIAvatar(
                initials: student.initials,
                color: modelColor,
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(student.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Grade \(student.grade)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(modelColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InterestCard: View {
    let interest: Interest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(interest.color)

                Spacer()

                if let firstCategory = interest.category.first {
                    Text(firstCategory.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(interest.color.opacity(0.8))
                        .tracking(0.5)
                }
            }

            Text(interest.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(interest.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(interest.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct TMIPlanResourceCard: View {
    let interest: Interest
    let modelColor: Color

    // Mock resources - in production, these would come from a resource service
    private var mockResources: [(title: String, type: String)] {
        [
            ("Exploring \(interest.name): Beginner's Guide", "Article"),
            ("Career Paths in \(interest.name)", "Video"),
            ("\(interest.name) Workshop Opportunities", "Activity")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            // Interest header
            HStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(interest.color)

                Text(interest.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(mockResources.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(interest.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(interest.color.opacity(0.2))
                    )
            }

            // Resources list
            VStack(spacing: 6) {
                ForEach(mockResources.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Image(systemName: resourceIcon(for: mockResources[index].type))
                            .font(.system(size: 12))
                            .foregroundColor(modelColor.opacity(0.7))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mockResources[index].title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(mockResources[index].type)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func resourceIcon(for type: String) -> String {
        switch type {
        case "Article": return "doc.text"
        case "Video": return "play.rectangle"
        case "Activity": return "figure.walk"
        default: return "link"
        }
    }
}



struct StrategyRow: View {
    let strategy: String
    let modelColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(modelColor)

            Text(strategy)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm)
                .fill(Color.white.opacity(0.03))
        )
    }
}

struct GoalCard: View {
    let goal: Goal
    let modelColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.description)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let dueDate = goal.dueDate {
                        Text("Due: \(formattedDate(dueDate))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                StatusBadge(status: goal.status)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(modelColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(modelColor)
                            .frame(width: geometry.size.width * goal.progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(modelColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: GoalStatus

    private var statusColor: Color {
        switch status {
        case .completed: return .tmiSuccess
        case .inProgress: return .tmiWarning
        case .notStarted: return .tmiTextSecondary
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.2))
            )
    }
}

//struct StatusBadge: View {
//    let status: String
//    
//    var color: Color {
//        switch status {
//        case "submitted": return .green
//        case "reviewed": return .blue
//        case "draft": return .orange
//        default: return .gray
//        }
//    }
//    
//    var body: some View {
//        Text(status.capitalized)
//            .font(.caption2)
//            .fontWeight(.bold)
//            .padding(.horizontal, 8)
//            .padding(.vertical, 4)
//            .background(color.opacity(0.1))
//            .foregroundColor(color)
//            .cornerRadius(4)
//    }
//}

// MARK: - TMIPlanModel Extension

extension TMIPlanModel {
    var shortDisplayName: String {
        switch self {
        case .chaseYourSpace: return "Chase Your Space"
        case .acknowledgeInterests: return "Acknowledge Interests"
        case .alignYourMind: return "Align Your Mind"
        case .directAndCorrect: return "Direct & Correct"
        case .bullyToBoss: return "Bully to Boss"
        case .meekToProtector: return "Meek to Protector"
        }
    }
}

// MARK: - Edit Goal View



// MARK: - Interest Survey View



// MARK: - Supporting Views



// MARK: - Preview

#Preview {
    NavigationStack {
        TMIPlanDetailView(plan: TMIPlan.samplePlan)
    }
}

// MARK: - Supporting Views for Edit



// MARK: - All Resources View



