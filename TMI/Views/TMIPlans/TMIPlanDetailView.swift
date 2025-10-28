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
    @State private var generatedResources: [Interest: [Resource]] = [:]
    @State private var isGeneratingResources = false
    @State private var showingAllResources = false
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

                    // 3. Personalized Resources - What are they getting?
                    personalizedResourcesSection

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
        .sheet(isPresented: $showingAllResources) {
            NavigationStack {
                AllResourcesView(
                    interests: plan.interests,
                    generatedResources: generatedResources,
                    modelColor: modelColor
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingAllResources = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddResource) {
            NavigationStack {
                Text("Add Custom Resource")
                    .font(.tmiTitle2)
                    .foregroundColor(.tmiTextPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tmiBackground)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddResource = false
                            }
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
            await generateResourcesForInterests()
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

    private var personalizedResourcesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.tmiSuccess)

                Text("Personalized Resources")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showingAddResource = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.tmiSuccess)
                }
                .buttonStyle(.plain)
            }

            if plan.interests.isEmpty {
                Text("Add student interests to generate personalized resources")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(TMISpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if isGeneratingResources {
                VStack(spacing: TMISpacing.md) {
                    ProgressView()
                        .tint(.tmiSuccess)
                    Text("Generating personalized resources...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(TMISpacing.lg)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: TMISpacing.md) {
                    ForEach(plan.interests.prefix(3)) { interest in
                        AIGeneratedResourceCard(
                            interest: interest,
                            resources: generatedResources[interest] ?? [],
                            modelColor: modelColor
                        )
                    }

                    if plan.interests.count > 3 {
                        Button(action: { showingAllResources = true }) {
                            HStack {
                                Text("View all \(plan.interests.count) interest resources")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.tmiSuccess)
                            .padding(TMISpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: TMIRadius.md)
                                    .fill(Color.tmiSuccess.opacity(0.1))
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
        } else if plan.calculatedProgress < 0.3 {
            return "Schedule check-in to review initial progress and adjust strategies"
        } else if plan.calculatedProgress < 0.7 {
            return "Continue current strategies and document student improvements"
        } else {
            return "Prepare for transition planning and celebrate achievements"
        }
    }

    private var shouldShowScheduleMeetingButton: Bool {
        !plan.interests.isEmpty && !plan.goals.isEmpty && plan.calculatedProgress < 0.3
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

    // MARK: - AI Resource Generation

    @MainActor
    private func generateResourcesForInterests() async {
        guard !plan.interests.isEmpty else { return }

        isGeneratingResources = true
        defer { isGeneratingResources = false }

        if #available(iOS 26.0, *) {
            let service = ResourceGenerationService.shared

            // Check availability first
            guard await service.checkAvailability() else {
                print("[TMIPlanDetail] Foundation Models not available, using fallback")
                generateFallbackResources()
                return
            }

            // Generate resources for each interest
            for interest in plan.interests {
                // Skip if already generated
                if generatedResources[interest] != nil {
                    continue
                }

                do {
                    let resources = try await service.generateResources(for: interest, plan: plan)
                    generatedResources[interest] = resources
                    print("[TMIPlanDetail] Generated \(resources.count) resources for \(interest.name)")
                } catch {
                    print("[TMIPlanDetail] Error generating resources for \(interest.name): \(error)")
                    // Use fallback for this interest
                    generatedResources[interest] = createFallbackResources(for: interest)
                }
            }
        } else {
            // iOS < 26: Use fallback resources
            generateFallbackResources()
        }
    }

    private func generateFallbackResources() {
        for interest in plan.interests {
            generatedResources[interest] = createFallbackResources(for: interest)
        }
    }

    private func createFallbackResources(for interest: Interest) -> [Resource] {
        return [
            Resource(
                title: "Exploring \(interest.name): Beginner's Guide",
                description: "A comprehensive introduction to \(interest.name) designed for students.",
                category: .article,
                url: "https://www.khanacademy.org",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "beginner", "guide"],
                recommendedFor: ["Students"],
                isFeatured: false
            ),
            Resource(
                title: "Career Paths in \(interest.name)",
                description: "Explore career opportunities related to \(interest.name).",
                category: .video,
                url: "https://www.pbs.org/education",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "career", "exploration"],
                recommendedFor: ["Students", "Counselors"],
                isFeatured: false
            ),
            Resource(
                title: "\(interest.name) Interactive Activities",
                description: "Hands-on activities and projects to deepen understanding of \(interest.name).",
                category: .interactiveContent,
                url: "https://www.nationalgeographic.org/education",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "interactive", "activities"],
                recommendedFor: ["Students", "Teachers"],
                isFeatured: false
            )
        ]
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

// MARK: - AI Generated Resource Card

struct AIGeneratedResourceCard: View {
    let interest: Interest
    let resources: [Resource]
    let modelColor: Color

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

                // AI badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("AI")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.tmiPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.tmiPrimary.opacity(0.2))
                )

                Text("\(resources.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(interest.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(interest.color.opacity(0.2))
                    )
            }

            if resources.isEmpty {
                Text("No resources available")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                // Resources list
                VStack(spacing: 6) {
                    ForEach(resources) { resource in
                        HStack(spacing: 8) {
                            Image(systemName: resource.category.icon)
                                .font(.system(size: 12))
                                .foregroundColor(resource.category.color.opacity(0.8))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(resource.category.rawValue.capitalized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            // Link indicator
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(modelColor.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: resource.url) {
                                UIApplication.shared.open(url)
                            }
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
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            interest.color.opacity(0.3),
                            Color.tmiPrimary.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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

// MARK: - Add Goal View

struct AddGoalView: View {
    let plan: TMIPlan
    let onSave: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goalDescription = ""
    @State private var selectedStatus: GoalStatus = .notStarted
    @State private var goalProgress: Double = 0.0
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 50))
                            .foregroundColor(modelColor)

                        Text("Add Goal")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Set a specific, measurable goal for this TMI plan")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Goal Description
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goal Description *")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextEditor(text: $goalDescription)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .cornerRadius(8)
                                .overlay(
                                    goalDescription.isEmpty ?
                                    VStack {
                                        HStack {
                                            Text("e.g., Increase on-task behavior to 80% during independent work")
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.system(size: 16))
                                                .allowsHitTesting(false)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    : nil
                                )
                        }
                    }

                    // Status
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Status")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(GoalStatus.allCases, id: \.self) { status in
                                    Button(action: {
                                        selectedStatus = status
                                    }) {
                                        Text(status.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedStatus == status ? .white : .white.opacity(0.7))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(selectedStatus == status ? modelColor.opacity(0.3) : Color.white.opacity(0.1))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedStatus == status ? modelColor : Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Due Date
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $hasDueDate) {
                                Text("Set Due Date")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .tint(modelColor)

                            if hasDueDate {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                                    .foregroundColor(.white)
                                    .tint(modelColor)
                            }
                        }
                    }

                    // Notes
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notes (Optional)")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            // Save button
            VStack {
                Spacer()

                TMIButton(
                    text: "Save Goal",
                    style: .primary,
                    action: saveGoal
                )
                .disabled(goalDescription.isEmpty)
                .padding(20)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
                )
            }
        }
        .navigationTitle("Add Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
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

    private func saveGoal() {
        let newGoal = Goal(
            description: goalDescription,
            dueDate: hasDueDate ? dueDate : nil,
            status: selectedStatus,
            progress: goalProgress,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(newGoal)
        // Parent view will dismiss after async save completes
    }
}

// MARK: - Edit Goal View

struct EditGoalView: View {
    let plan: TMIPlan
    let goal: Goal
    let onSave: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goalDescription: String
    @State private var selectedStatus: GoalStatus
    @State private var goalProgress: Double
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var notes: String

    init(plan: TMIPlan, goal: Goal, onSave: @escaping (Goal) -> Void) {
        self.plan = plan
        self.goal = goal
        self.onSave = onSave
        _goalDescription = State(initialValue: goal.description)
        _selectedStatus = State(initialValue: goal.status)
        _goalProgress = State(initialValue: goal.progress)
        _hasDueDate = State(initialValue: goal.dueDate != nil)
        _dueDate = State(initialValue: goal.dueDate ?? Date())
        _notes = State(initialValue: goal.notes ?? "")
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(modelColor)

                        Text("Edit Goal")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Update goal details and track progress")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Goal Description
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goal Description *")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextEditor(text: $goalDescription)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .cornerRadius(8)
                        }
                    }

                    // Status
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Status")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(GoalStatus.allCases, id: \.self) { status in
                                    Button(action: {
                                        selectedStatus = status
                                        // Auto-update progress based on status
                                        if status == .notStarted {
                                            goalProgress = 0.0
                                        } else if status == .completed {
                                            goalProgress = 1.0
                                        }
                                    }) {
                                        Text(status.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedStatus == status ? .white : .white.opacity(0.7))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(selectedStatus == status ? modelColor.opacity(0.3) : Color.white.opacity(0.1))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedStatus == status ? modelColor : Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Progress
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Progress")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(Int(goalProgress * 100))%")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(modelColor)
                            }

                            Slider(value: $goalProgress, in: 0...1)
                                .tint(modelColor)
                        }
                    }

                    // Due Date
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $hasDueDate) {
                                Text("Set Due Date")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .tint(modelColor)

                            if hasDueDate {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                                    .foregroundColor(.white)
                                    .tint(modelColor)
                            }
                        }
                    }

                    // Notes
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notes (Optional)")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            // Save button
            VStack {
                Spacer()

                HStack(spacing: 16) {
                    TMIButton(
                        text: "Delete Goal",
                        style: .destructive,
                        action: {
                            // TODO: Implement delete functionality
                            dismiss()
                        }
                    )

                    TMIButton(
                        text: "Save Changes",
                        style: .primary,
                        action: saveGoal
                    )
                    .disabled(goalDescription.isEmpty)
                }
                .padding(20)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
                )
            }
        }
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
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

    private func saveGoal() {
        let updatedGoal = Goal(
            id: goal.id,
            description: goalDescription,
            dueDate: hasDueDate ? dueDate : nil,
            status: selectedStatus,
            progress: goalProgress,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(updatedGoal)
        // Parent view will dismiss after async save completes
    }
}

// MARK: - Interest Survey View

struct InterestSurveyView: View {
    let plan: TMIPlan
    let onComplete: ([Interest]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var selectedInterests: Set<Interest> = []
    @State private var careerGoal = ""
    @State private var favoriteSubjects: Set<String> = []
    @State private var activities: Set<String> = []

    // Survey pages
    private let totalPages = 4

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    interestsPage.tag(1)
                    careerPage.tag(2)
                    reviewPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Navigation buttons
                navigationButtons
            }
        }
        .navigationTitle("Interest Survey")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<totalPages, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= currentPage ? Color.tmiPrimary : Color.white.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)

            Text("Step \(currentPage + 1) of \(totalPages)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.tmiPrimary)

                    Text("Let's Discover Your Interests!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("This survey helps us understand what you love and create a personalized plan for \(plan.primaryStudent?.name ?? "you").")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)

                TMIGlassCard(style: .default) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What to Expect")
                            .font(.headline)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(icon: "clock", text: "Takes 10-15 minutes", color: .tmiPrimary)
                            InfoRow(icon: "list.bullet", text: "4 simple sections", color: .tmiPrimary)
                            InfoRow(icon: "hand.raised", text: "No wrong answers!", color: .tmiPrimary)
                            InfoRow(icon: "lock.shield", text: "Your info stays private", color: .tmiPrimary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Interests Page

    private var interestsPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("What Do You Love?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Select all the interests and hobbies that excite you")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Group interests by category
                ForEach(InterestCategory.allCases.filter { $0 != .other }, id: \.self) { category in
                    interestCategorySection(category)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private func interestCategorySection(_ category: InterestCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(PredefinedInterestsData.allPredefinedInterests.filter { $0.category.contains(category) }.prefix(6)) { interest in
                    Button(action: {
                        if selectedInterests.contains(interest) {
                            selectedInterests.remove(interest)
                        } else {
                            selectedInterests.insert(interest)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: interest.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(interest.color)

                            Text(interest.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            if selectedInterests.contains(interest) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.tmiSuccess)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedInterests.contains(interest) ? interest.color.opacity(0.2) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedInterests.contains(interest) ? interest.color.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Career Page

    private var careerPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("What's Your Dream?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Tell us about what you want to be when you grow up")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TMIGlassCard(style: .default) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Career Goal")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextEditor(text: $careerGoal)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.05))
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .cornerRadius(8)
                            .overlay(
                                careerGoal.isEmpty ?
                                VStack {
                                    HStack {
                                        Text("e.g., Doctor, Artist, Engineer, Teacher...")
                                            .foregroundColor(.white.opacity(0.5))
                                            .font(.system(size: 16))
                                            .allowsHitTesting(false)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                : nil
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Review Page

    private var reviewPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.tmiSuccess)

                    Text("Review Your Answers")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Everything look good? You can always update later!")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TMIGlassCard(style: .default) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Selected Interests")
                            .font(.headline)
                            .foregroundColor(.white)

                        if selectedInterests.isEmpty {
                            Text("No interests selected yet")
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(Array(selectedInterests), id: \.id) { interest in
                                    HStack(spacing: 6) {
                                        Image(systemName: interest.iconName)
                                            .font(.system(size: 12))
                                        Text(interest.name)
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(interest.color.opacity(0.2))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                if !careerGoal.isEmpty {
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Career Goal")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(careerGoal)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentPage > 0 {
                TMIButton(
                    text: "Back",
                    icon: "chevron.left",
                    style: .secondary,
                    action: { currentPage -= 1 }
                )
            }

            Spacer()

            if currentPage < totalPages - 1 {
                TMIButton(
                    text: "Next",
                    icon: "chevron.right",
                    style: .primary,
                    action: { currentPage += 1 }
                )
            } else {
                TMIButton(
                    text: "Complete Survey",
                    icon: "checkmark",
                    style: .primary,
                    action: completeSurvey
                )
                .disabled(selectedInterests.isEmpty)
            }
        }
        .padding(20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
        )
    }

    private func completeSurvey() {
        onComplete(Array(selectedInterests))
        dismiss()
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TMIPlanDetailView(plan: TMIPlan.samplePlan)
    }
}

// MARK: - Edit TMI Plan View

struct EditTMIPlanView: View {
    let plan: TMIPlan
    let onPlanUpdated: (TMIPlan) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var notes: String
    @State private var selectedInterests: [Interest]
    @State private var isUpdating = false

    init(plan: TMIPlan, onPlanUpdated: @escaping (TMIPlan) -> Void) {
        self.plan = plan
        self.onPlanUpdated = onPlanUpdated
        _notes = State(initialValue: plan.notes)
        _selectedInterests = State(initialValue: plan.interests)
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.tmiSecondary)

                        Text("Edit TMI Plan")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Update the plan details")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)

                    // Plan Info (Read-only)
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Plan Information")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Model:")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(plan.model.rawValue)
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("Primary Student:")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(plan.primaryStudent?.name ?? "No student assigned")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("Progress:")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("\(plan.progressPercentage)%")
                                        .foregroundColor(.tmiSecondary)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }

                    // Notes Section
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notes")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)

                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                    }

                    // Interests Section
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Associated Interests")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                                ForEach(Interest.expandedSampleInterests) { interest in
                                    InterestToggleCard(
                                        interest: interest,
                                        isSelected: selectedInterests.contains(interest),
                                        onToggle: { toggleInterest(interest) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Edit Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    updatePlan()
                }
                .foregroundColor(.tmiSecondary)
                .disabled(isUpdating)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggleInterest(_ interest: Interest) {
        if selectedInterests.contains(interest) {
            selectedInterests.removeAll { $0.id == interest.id }
        } else {
            selectedInterests.append(interest)
        }
    }

    private func updatePlan() {
        isUpdating = true

        Task {
            do {
                var updatedPlan = plan
                updatedPlan.notes = notes
                updatedPlan.interests = selectedInterests
                updatedPlan.lastUpdated = Date()

                let savedPlan = try await TMIPlanService().updatePlan(updatedPlan)

                await MainActor.run {
                    onPlanUpdated(savedPlan) // Pass the saved plan from Firestore
                    dismiss()
                }
            } catch {
                print("Error updating TMI plan: \(error)")
            }

            await MainActor.run {
                isUpdating = false
            }
        }
    }
}

// MARK: - Supporting Views for Edit

struct InterestToggleCard: View {
    let interest: Interest
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(interest.color)

                Text(interest.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? interest.color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? interest.color.opacity(0.5) : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Resources View

struct AllResourcesView: View {
    let interests: [Interest]
    let generatedResources: [Interest: [Resource]]
    let modelColor: Color

    var body: some View {
        ScrollView {
            VStack(spacing: TMISpacing.lg) {
                ForEach(interests) { interest in
                    AIGeneratedResourceCard(
                        interest: interest,
                        resources: generatedResources[interest] ?? [],
                        modelColor: modelColor
                    )
                }
            }
            .padding(TMISpacing.screenPadding)
        }
        .background(Color.tmiBackground)
        .navigationTitle("All Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}
