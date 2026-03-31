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
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import FirebaseAuth

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

    // Snapshot interests (Bug Fix #5)
    @State private var snapshotInterests: [Interest] = []
    @State private var isLoadingSnapshotInterests = false

    // All Meetings View
    @State private var showingAllMeetings = false

    // PDF Export
    @State private var isExporting = false
    @State private var exportedPDFURL: URL?
    @State private var showingShareSheet = false
    private let exportService = PlanExportService()

    // Plan-specific inputs
    @State private var planInputs: [String: String] = [:]
    @State private var planInputFields: [PlanInputField] = []

    // Evidence trackers
    @State private var setupChecklist: [ChecklistItem] = []
    @State private var newSetupChecklistItem = ""
    @State private var dailyResetChecklist: [ChecklistItem] = []
    @State private var newDailyResetItem = ""

    @State private var streakCount = 0
    @State private var bestStreak = 0
    @State private var lastStreakDate: Date?

    @State private var questTasks: [ChecklistItem] = []
    @State private var newQuestTask = ""

    @State private var ratingEntries: [RatingEntry] = []
    @State private var pendingRatingValues: [String: Double] = [:]
    @State private var pendingRatingNotes: [String: String] = [:]

    @State private var incidentLogs: [IncidentEntry] = []
    @State private var newIncidentSummary = ""
    @State private var newIncidentDetails = ""
    @State private var newIncidentSeverity: Double = 3

    @State private var thoughtLogs: [ThoughtLogEntry] = []
    @State private var newThoughtTrigger = ""
    @State private var newThought = ""
    @State private var newThoughtReframe = ""
    @State private var newThoughtAction = ""

    @State private var reframeBank: [TextEntry] = []
    @State private var newReframeText = ""

    @State private var ifThenRules: [TextEntry] = []
    @State private var newIfThenRule = ""

    @State private var teacherTallyCount = 0

    @State private var feedbackEntries: [FeedbackEntry] = []
    @State private var newFeedbackFrom = ""
    @State private var newFeedbackNote = ""

    @State private var leadershipTasks: [ChecklistItem] = []
    @State private var newLeadershipTask = ""

    @State private var courageSteps: [ChecklistItem] = []
    @State private var newCourageStep = ""

    @State private var scripts: [TextEntry] = []
    @State private var newScript = ""

    @State private var allies: [AllyEntry] = []
    @State private var newAllyName = ""
    @State private var newAllyRole = ""

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

                    // 2. Plan-specific sections (driven by plan rules)
                    ForEach(planSections, id: \.title) { section in
                        planSectionView(for: section)
                    }

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

                    Button(action: { exportPlanToPDF() }) {
                        if isExporting {
                            Label("Exporting...", systemImage: "arrow.down.doc")
                        } else {
                            Label("Export PDF", systemImage: "doc.fill")
                        }
                    }
                    .disabled(isExporting)
                    
                    Button(action: { exportPlanToMTSS() }) {
                        Label("Export MTSS Report", systemImage: "doc.text.fill")
                    }
                    .disabled(isExporting)

                    Button(action: { exportPlanToIEP() }) {
                        Label("Export IEP Contribution", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(isExporting)

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
                TMIPlanEditorView(existingPlan: plan, onSave: { updatedPlan in
                    plan = updatedPlan
                    Task {
                        await refreshPlan()
                    }
                })
            }
        }
        .alert("Delete TMI Plan", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deletePlan() }
        } message: {
            Text("Are you sure you want to delete this TMI plan? This action cannot be undone.")
        }
        .sheet(item: $selectedStudent) { student in
            if let studentId = student.id {
                NavigationStack {
                    StudentDetailView(studentId: studentId)
                }
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
        .sheet(isPresented: $showingCompleteSurvey, onDismiss: {
            // Refresh plan and interests after survey completion
            Task {
                await refreshPlan()
                await loadSnapshotInterests()
            }
        }) {
            NavigationStack {
                StudentSurveyFlow(
                    studentId: plan.primaryStudent?.id ?? "",
                    context: .planDetail(planId: plan.id ?? "")
                )
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
        .sheet(isPresented: $showingAllMeetings) {
            NavigationStack {
                AllMeetingsView(
                    meetings: scheduledMeetings,
                    title: "All Meetings - \(plan.title)",
                    context: .plan(planId: plan.id ?? "")
                )
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL = exportedPDFURL {
                ActivityShareSheet(activityItems: [pdfURL])
            }
        }
        .refreshable {
            await refreshPlan()
            await loadMeetings()
            await loadSnapshotInterests()
            await loadPlanInputs()
            await loadPlanEvidence()
        }
        .task {
            await loadMeetings()
            await loadSnapshotInterests()
            await loadPlanInputs()
            await loadPlanEvidence()
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

            planIdentitySection

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

    // MARK: - Plan Sections (Rules-driven)

    private var planSections: [PlanSection] {
        plan.model.planRules.sections
    }

    private var firstSectionTitle: String {
        planSections.first?.title ?? ""
    }

    private func planSectionView(for section: PlanSection) -> some View {
        planSectionCard(section: section) {
            sectionContent(for: section)
        }
    }

    private func planSectionCard(
        section: PlanSection,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(modelColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(section.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }

            content()
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

    @ViewBuilder
    private func sectionContent(for section: PlanSection) -> some View {
        switch section.title {
        case "Setup":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                checklistEditor(
                    title: "Space Setup Checklist",
                    items: $setupChecklist,
                    newItem: $newSetupChecklistItem,
                    addButtonTitle: "Add setup item",
                    evidenceType: .checklist,
                    evidenceCategory: "Setup"
                )
            }
        case "Daily Reset":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                checklistEditor(
                    title: "Daily Reset Checklist",
                    items: $dailyResetChecklist,
                    newItem: $newDailyResetItem,
                    addButtonTitle: "Add reset item",
                    evidenceType: .checklist,
                    evidenceCategory: "Daily Reset"
                )
                ratingInputSection(title: "Ready-to-work score")
            }
        case "Streaks":
            streakTrackerSection
        case "Notes":
            notesSectionContent
        case "Interest Map":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                studentInterestsContent
            }
        case "Quests":
            taskListSection(
                title: "Quest Checklist",
                items: $questTasks,
                newItem: $newQuestTask,
                addButtonTitle: "Add quest",
                evidenceType: .quest,
                evidenceCategory: "Quests"
            )
        case "Engagement":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                ratingTrendSection(title: "Engagement")
                ratingInputSection(title: "Engagement")
            }
        case "Triggers":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                incidentLogSection(title: "Trigger log")
            }
        case "Thought Logs":
            thoughtLogSection
        case "Reframes":
            reframeBankSection
        case "Trends":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                ratingTrendSection(title: "Stress")
                ratingInputSection(title: "Stress")
            }
        case "Targets":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                teacherTallySection(title: "Behavior tally")
            }
        case "Playbook":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                ifThenRulesSection
                strategiesListSection
            }
        case "Check-ins":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                teacherTallySection(title: "Daily check-ins")
                ratingInputSection(title: "Check-in rating")
            }
        case "Weekly Review":
            goalsAndProgressContent
        case "Repair":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                incidentLogSection(title: "Repair log")
            }
        case "Leadership Tasks":
            taskListSection(
                title: "Leadership tasks",
                items: $leadershipTasks,
                newItem: $newLeadershipTask,
                addButtonTitle: "Add leadership task",
                evidenceType: .quest,
                evidenceCategory: "Leadership"
            )
        case "Feedback":
            feedbackSection
        case "History":
            incidentHistorySection
        case "Courage Ladder":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                taskListSection(
                    title: "Courage steps",
                    items: $courageSteps,
                    newItem: $newCourageStep,
                    addButtonTitle: "Add step",
                    evidenceType: .quest,
                    evidenceCategory: "Courage Ladder"
                )
                streakTrackerSection
            }
        case "Scripts":
            scriptsSection
        case "Allies":
            alliesSection
        case "Progress":
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                ratingTrendSection(title: "Confidence")
                ratingInputSection(title: "Confidence")
            }
        default:
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                if section.title == firstSectionTitle {
                    uniqueFieldsForm
                }
                Text("Add updates and evidence for this section.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Plan Section Content

    private var uniqueFieldsForm: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("Plan Inputs")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(plan.model.planRules.uniqueFields, id: \.self) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(field)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    if shouldUseMultilineField(field) {
                        TextEditor(text: bindingForInput(field))
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(TMIRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: TMIRadius.sm)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    } else {
                        TextField("Enter response", text: bindingForInput(field))
                            .textInputAutocapitalization(.sentences)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(TMIRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: TMIRadius.sm)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
            }

            Button(action: {
                savePlanInputs()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("Save Plan Inputs")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(modelColor)
            }
            .buttonStyle(.plain)
        }
    }

    private func checklistEditor(
        title: String,
        items: Binding<[ChecklistItem]>,
        newItem: Binding<String>,
        addButtonTitle: String,
        evidenceType: PlanEvidenceKind = .checklist,
        evidenceCategory: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            if items.wrappedValue.isEmpty {
                Text("No items yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            ForEach(items) { item in
                HStack(spacing: 8) {
                    Button(action: {
                        let wasComplete = item.isComplete.wrappedValue
                        item.isComplete.wrappedValue.toggle()
                        if !wasComplete && item.isComplete.wrappedValue {
                            logPlanEvidence(
                                type: evidenceType,
                                title: item.title.wrappedValue,
                                details: "Completed \(title)",
                                numericValue: 1,
                                category: evidenceCategory ?? title,
                                metadata: nil
                            )
                        }
                    }) {
                        Image(systemName: item.isComplete.wrappedValue ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isComplete.wrappedValue ? .tmiSuccess : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    TextField("Item", text: item.title)
                        .textInputAutocapitalization(.sentences)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        let itemId = item.wrappedValue.id
                        items.wrappedValue.removeAll { $0.id == itemId }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(TMIRadius.sm)
            }

            HStack(spacing: 8) {
                TextField(addButtonTitle, text: newItem)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    items.wrappedValue.append(ChecklistItem(title: trimmed))
                    newItem.wrappedValue = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func taskListSection(
        title: String,
        items: Binding<[ChecklistItem]>,
        newItem: Binding<String>,
        addButtonTitle: String,
        evidenceType: PlanEvidenceKind = .quest,
        evidenceCategory: String? = nil
    ) -> some View {
        checklistEditor(
            title: title,
            items: items,
            newItem: newItem,
            addButtonTitle: addButtonTitle,
            evidenceType: evidenceType,
            evidenceCategory: evidenceCategory ?? title
        )
    }

    private var streakTrackerSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current streak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(streakCount) days")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Best streak")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(bestStreak) days")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()
            }

            if let lastStreakDate {
                Text("Last completed: \(formattedDate(lastStreakDate))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                Button(action: {
                    streakCount += 1
                    bestStreak = max(bestStreak, streakCount)
                    lastStreakDate = Date()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("Mark Today Complete")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(modelColor))
                }
                .buttonStyle(.plain)

                Button(action: {
                    streakCount = 0
                }) {
                    Text("Reset")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesSectionContent: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if plan.notes.isEmpty {
                Text("No notes yet. Add key observations for the team.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text(plan.notes)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            Button(action: { showingEditSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add Note")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(modelColor)
            }
            .buttonStyle(.plain)
        }
    }

    private var studentInterestsContent: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if isLoadingSnapshotInterests {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.tmiPrimary)
                    Text("Loading interests...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.vertical, TMISpacing.md)
            } else if !plan.interests.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
                    ForEach(plan.interests) { interest in
                        InterestCard(interest: interest)
                    }
                }
            } else if !snapshotInterests.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
                    ForEach(snapshotInterests) { interest in
                        InterestCard(interest: interest)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Text("No interests captured yet.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Button(action: { showingCompleteSurvey = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                            Text("Complete Interest Survey")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: { showingAddInterest = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add Interest")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tmiPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private func ratingInputSection(title: String) -> some View {
        let valueBinding = Binding<Double>(
            get: { pendingRatingValues[title] ?? 3 },
            set: { pendingRatingValues[title] = $0 }
        )
        let noteBinding = Binding<String>(
            get: { pendingRatingNotes[title] ?? "" },
            set: { pendingRatingNotes[title] = $0 }
        )

        return VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Slider(value: valueBinding, in: 1...5, step: 1)
                    .tint(modelColor)

                Text("\(Int(valueBinding.wrappedValue))/5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46)
            }

            TextField("Add quick note (optional)", text: noteBinding)
                .textInputAutocapitalization(.sentences)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(TMIRadius.sm)

            Button(action: {
                ratingEntries.append(
                    RatingEntry(
                        category: title,
                        value: valueBinding.wrappedValue,
                        date: Date(),
                        note: noteBinding.wrappedValue
                    )
                )
                logPlanEvidence(
                    type: .rating,
                    title: "\(title) rating",
                    details: noteBinding.wrappedValue.isEmpty ? nil : noteBinding.wrappedValue,
                    numericValue: valueBinding.wrappedValue,
                    category: title,
                    metadata: nil
                )
                pendingRatingNotes[title] = ""
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Rating")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(modelColor)
            }
            .buttonStyle(.plain)
        }
    }

    private func ratingTrendSection(title: String) -> some View {
        let entries = ratingEntries.filter { $0.category == title }

        return VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            if entries.isEmpty {
                Text("No ratings logged yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Rating", entry.value)
                    )
                    .foregroundStyle(modelColor)
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Rating", entry.value)
                    )
                    .foregroundStyle(modelColor)
                }
                .frame(height: 140)
            }
        }
    }

    private func incidentLogSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            if incidentLogs.isEmpty {
                Text("No incidents logged yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(incidentLogs) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.summary)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(formattedDate(entry.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text(entry.details)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Severity: \(entry.severity)/5")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.tmiWarning)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(TMIRadius.sm)
                }
            }

            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                TextField("Incident summary", text: $newIncidentSummary)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                TextField("Details", text: $newIncidentDetails)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                HStack {
                    Slider(value: $newIncidentSeverity, in: 1...5, step: 1)
                        .tint(.tmiWarning)
                    Text("\(Int(newIncidentSeverity))/5")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }

                Button(action: {
                    let summary = newIncidentSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !summary.isEmpty else { return }
                    incidentLogs.insert(
                        IncidentEntry(
                            summary: summary,
                            details: newIncidentDetails,
                            severity: Int(newIncidentSeverity),
                            date: Date()
                        ),
                        at: 0
                    )
                    logPlanEvidence(
                        type: .incident,
                        title: summary,
                        details: newIncidentDetails.isEmpty ? nil : newIncidentDetails,
                        numericValue: Double(Int(newIncidentSeverity)),
                        category: title,
                        metadata: nil
                    )
                    newIncidentSummary = ""
                    newIncidentDetails = ""
                    newIncidentSeverity = 3
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Log Incident")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiWarning)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var thoughtLogSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if thoughtLogs.isEmpty {
                Text("No thought logs yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(thoughtLogs) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.trigger)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.tmiWarning)
                        Text(entry.thought)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Reframe: \(entry.reframe)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Action: \(entry.action)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(TMIRadius.sm)
                }
            }

            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                TextField("Trigger", text: $newThoughtTrigger)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)
                TextField("Negative thought", text: $newThought)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)
                TextField("Reframe", text: $newThoughtReframe)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)
                TextField("Replacement action", text: $newThoughtAction)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let trigger = newThoughtTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trigger.isEmpty else { return }
                    thoughtLogs.insert(
                        ThoughtLogEntry(
                            trigger: trigger,
                            thought: newThought,
                            reframe: newThoughtReframe,
                            action: newThoughtAction,
                            date: Date()
                        ),
                        at: 0
                    )
                    logPlanEvidence(
                        type: .thoughtLog,
                        title: trigger,
                        details: newThought,
                        numericValue: nil,
                        category: "Thought Log",
                        metadata: [
                            "trigger": trigger,
                            "thought": newThought,
                            "reframe": newThoughtReframe,
                            "action": newThoughtAction
                        ]
                    )
                    newThoughtTrigger = ""
                    newThought = ""
                    newThoughtReframe = ""
                    newThoughtAction = ""
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Thought Log")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reframeBankSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if reframeBank.isEmpty {
                Text("No replacement thoughts added yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(reframeBank) { entry in
                    Text(entry.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(TMIRadius.sm)
                }
            }

            HStack(spacing: 8) {
                TextField("Add replacement thought", text: $newReframeText)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let trimmed = newReframeText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    reframeBank.append(TextEntry(text: trimmed))
                    newReframeText = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func teacherTallySection(title: String) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Button(action: { teacherTallyCount = max(0, teacherTallyCount - 1) }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.tmiWarning)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)

                Text("\(teacherTallyCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Button(action: { teacherTallyCount += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.tmiSuccess)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ifThenRulesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if ifThenRules.isEmpty {
                Text("No If-Then rules added yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(ifThenRules) { rule in
                    Text(rule.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(TMIRadius.sm)
                }
            }

            HStack(spacing: 8) {
                TextField("If X happens, then...", text: $newIfThenRule)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let trimmed = newIfThenRule.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    ifThenRules.append(TextEntry(text: trimmed))
                    newIfThenRule = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var strategiesListSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("Coach scripts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            ForEach(modelStrategies, id: \.self) { strategy in
                StrategyRow(strategy: strategy, modelColor: modelColor)
            }
        }
    }

    private var goalsAndProgressContent: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Progress")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(plan.progressPercentage)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(modelColor)
            }

            if plan.goals.isEmpty {
                Button(action: { showingAddGoal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add First Goal")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(plan.goals) { goal in
                        Button(action: { selectedGoal = goal }) {
                            GoalCard(goal: goal, modelColor: modelColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if feedbackEntries.isEmpty {
                Text("No feedback yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(feedbackEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.from)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(formattedDate(entry.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text(entry.note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(TMIRadius.sm)
                }
            }

            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                TextField("From (peer/staff)", text: $newFeedbackFrom)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                TextField("Feedback note", text: $newFeedbackNote)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let from = newFeedbackFrom.trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = newFeedbackNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !from.isEmpty, !note.isEmpty else { return }
                    feedbackEntries.insert(FeedbackEntry(from: from, note: note, date: Date()), at: 0)
                    logPlanEvidence(
                        type: .feedback,
                        title: from,
                        details: note,
                        numericValue: nil,
                        category: "Feedback",
                        metadata: nil
                    )
                    newFeedbackFrom = ""
                    newFeedbackNote = ""
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Feedback")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var incidentHistorySection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if incidentLogs.isEmpty {
                Text("No history logged yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(incidentLogs) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.summary)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(formattedDate(entry.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("S\(entry.severity)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.tmiWarning)
                            .padding(6)
                            .background(Color.tmiWarning.opacity(0.2))
                            .cornerRadius(TMIRadius.sm)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(TMIRadius.sm)
                }
            }
        }
    }

    private var scriptsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if scripts.isEmpty {
                Text("No scripts added yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(scripts) { script in
                    Text(script.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(TMIRadius.sm)
                }
            }

            HStack(spacing: 8) {
                TextField("Add assertive script", text: $newScript)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let trimmed = newScript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    scripts.append(TextEntry(text: trimmed))
                    newScript = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var alliesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            if allies.isEmpty {
                Text("No allies added yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(allies) { ally in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ally.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(ally.role)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(TMIRadius.sm)
                }
            }

            HStack(spacing: 8) {
                TextField("Ally name", text: $newAllyName)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                TextField("Role", text: $newAllyRole)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(TMIRadius.sm)

                Button(action: {
                    let name = newAllyName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let role = newAllyRole.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    allies.append(AllyEntry(name: name, role: role))
                    newAllyName = ""
                    newAllyRole = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modelColor)
                }
                .buttonStyle(.plain)
            }
        }
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

            if isLoadingSnapshotInterests {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.tmiPrimary)
                    Text("Loading interests...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(TMISpacing.lg)
            } else if !plan.interests.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
                    ForEach(plan.interests) { interest in
                        InterestCard(interest: interest)
                    }
                }
            } else if !snapshotInterests.isEmpty {
                // Display interests from snapshot when plan.interests is empty
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(.tmiWarning)
                        Text("From latest survey")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.tmiWarning.opacity(0.9))
                    }
                    .padding(.bottom, TMISpacing.xs)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
                        ForEach(snapshotInterests) { interest in
                            InterestCard(interest: interest)
                        }
                    }
                }
            } else {
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
                            showingAllMeetings = true
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

    // MARK: - Local Models

    private struct ChecklistItem: Identifiable, Hashable {
        let id: UUID
        var title: String
        var isComplete: Bool

        init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
            self.id = id
            self.title = title
            self.isComplete = isComplete
        }
    }

    private struct RatingEntry: Identifiable, Hashable {
        let id: UUID
        let category: String
        let value: Double
        let date: Date
        let note: String?

        init(id: UUID = UUID(), category: String, value: Double, date: Date, note: String? = nil) {
            self.id = id
            self.category = category
            self.value = value
            self.date = date
            self.note = note
        }
    }

    private struct IncidentEntry: Identifiable, Hashable {
        let id: UUID
        let summary: String
        let details: String
        let severity: Int
        let date: Date

        init(id: UUID = UUID(), summary: String, details: String, severity: Int, date: Date) {
            self.id = id
            self.summary = summary
            self.details = details
            self.severity = severity
            self.date = date
        }
    }

    private struct ThoughtLogEntry: Identifiable, Hashable {
        let id: UUID
        let trigger: String
        let thought: String
        let reframe: String
        let action: String
        let date: Date

        init(id: UUID = UUID(), trigger: String, thought: String, reframe: String, action: String, date: Date) {
            self.id = id
            self.trigger = trigger
            self.thought = thought
            self.reframe = reframe
            self.action = action
            self.date = date
        }
    }

    private struct TextEntry: Identifiable, Hashable {
        let id: UUID
        let text: String

        init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    private struct FeedbackEntry: Identifiable, Hashable {
        let id: UUID
        let from: String
        let note: String
        let date: Date

        init(id: UUID = UUID(), from: String, note: String, date: Date) {
            self.id = id
            self.from = from
            self.note = note
            self.date = date
        }
    }

    private struct AllyEntry: Identifiable, Hashable {
        let id: UUID
        let name: String
        let role: String

        init(id: UUID = UUID(), name: String, role: String) {
            self.id = id
            self.name = name
            self.role = role
        }
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

    private var planIdentitySection: some View {
        let rules = plan.model.planRules

        return VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.tmiSecondary)
                Text("Plan Identity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
            }

            HStack(spacing: TMISpacing.md) {
                identityPill(title: "Archetype", value: rules.archetype.rawValue)
                identityPill(title: "Lever", value: rules.primaryLever.rawValue)
            }

            HStack(spacing: TMISpacing.md) {
                identityPill(title: "Cadence", value: rules.cadence.rawValue)
                identityPill(title: "Proof", value: rules.proofTypes.map { $0.rawValue }.joined(separator: ", "))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sections")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(rules.sections, id: \.title) { section in
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.tmiSecondary)
                            Text(section.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(TMIRadius.sm)
                    }
                }
            }
        }
        .padding(TMISpacing.md)
        .background(Color.white.opacity(0.06))
        .cornerRadius(TMIRadius.md)
    }

    private func identityPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.sm)
        .background(Color.white.opacity(0.08))
        .cornerRadius(TMIRadius.sm)
    }

    private func bindingForInput(_ key: String) -> Binding<String> {
        Binding(
            get: { planInputs[key] ?? "" },
            set: { planInputs[key] = $0 }
        )
    }

    private func shouldUseMultilineField(_ field: String) -> Bool {
        let lowercased = field.lowercased()
        return lowercased.contains("routine")
            || lowercased.contains("definition")
            || lowercased.contains("inventory")
            || field.count > 32
    }

    private func inputKey(for label: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let mapped = label.lowercased().map { char -> String in
            guard let scalar = char.unicodeScalars.first else { return "_" }
            return allowed.contains(scalar) ? String(char) : "_"
        }
        let joined = mapped.joined()
        return joined
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
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

    private func loadPlanInputs() async {
        guard let planId = plan.id else { return }
        do {
            let fields = try await TMIPlanService.shared.fetchPlanInputs(planId: planId)
            await MainActor.run {
                planInputFields = fields
                planInputs = Dictionary(uniqueKeysWithValues: fields.map { ($0.label, $0.value) })
            }
        } catch {
            print("[TMIPlanDetail] Failed to load plan inputs: \(error)")
        }
    }

    private func savePlanInputs() {
        guard let planId = plan.id else { return }
        let existingByLabel: [String: PlanInputField] = Dictionary(uniqueKeysWithValues: planInputFields.map { ($0.label, $0) })
        let now = Date()

        let fieldsToSave = plan.model.planRules.uniqueFields.map { label -> PlanInputField in
            let key = inputKey(for: label)
            let value = planInputs[label] ?? ""
            let existing = existingByLabel[label]
            return PlanInputField(
                id: existing?.id,
                planId: planId,
                key: key,
                label: label,
                value: value,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
                updatedBy: Auth.auth().currentUser?.uid
            )
        }

        Task {
            do {
                try await TMIPlanService.shared.savePlanInputs(planId: planId, fields: fieldsToSave)
                await MainActor.run {
                    planInputFields = fieldsToSave
                }
            } catch {
                print("[TMIPlanDetail] Failed to save plan inputs: \(error)")
            }
        }
    }

    private func loadPlanEvidence() async {
        guard let planId = plan.id else { return }
        do {
            let entries = try await TMIPlanService.shared.fetchPlanEvidence(planId: planId)
            await MainActor.run {
                applyEvidenceEntries(entries)
            }
        } catch {
            print("[TMIPlanDetail] Failed to load plan evidence: \(error)")
        }
    }

    private func applyEvidenceEntries(_ entries: [PlanEvidenceEntry]) {
        ratingEntries = entries.filter { $0.type == .rating }.map { entry in
            RatingEntry(
                category: entry.category ?? "Rating",
                value: entry.numericValue ?? 0.0,
                date: entry.createdAt,
                note: entry.details
            )
        }

        incidentLogs = entries.filter { $0.type == .incident }.map { entry in
            IncidentEntry(
                summary: entry.title,
                details: entry.details ?? "",
                severity: Int(entry.numericValue ?? 3),
                date: entry.createdAt
            )
        }

        thoughtLogs = entries.filter { $0.type == .thoughtLog }.map { entry in
            ThoughtLogEntry(
                trigger: entry.metadata?["trigger"] ?? entry.title,
                thought: entry.metadata?["thought"] ?? entry.details ?? "",
                reframe: entry.metadata?["reframe"] ?? "",
                action: entry.metadata?["action"] ?? "",
                date: entry.createdAt
            )
        }

        feedbackEntries = entries.filter { $0.type == .feedback }.map { entry in
            FeedbackEntry(
                from: entry.title,
                note: entry.details ?? "",
                date: entry.createdAt
            )
        }

        let streakEntries = entries.filter { $0.type == .streak }
        if let latest = streakEntries.sorted(by: { $0.createdAt > $1.createdAt }).first {
            streakCount = Int(latest.numericValue ?? Double(streakEntries.count))
            lastStreakDate = latest.createdAt
        }
        let bestValue = streakEntries.compactMap { $0.numericValue }.max() ?? Double(streakEntries.count)
        bestStreak = Int(bestValue)
    }

    private func logPlanEvidence(
        type: PlanEvidenceKind,
        title: String,
        details: String?,
        numericValue: Double?,
        category: String?,
        metadata: [String: String]?
    ) {
        guard let planId = plan.id else { return }
        let entry = PlanEvidenceEntry(
            planId: planId,
            type: type,
            category: category,
            title: title,
            details: details,
            numericValue: numericValue,
            createdAt: Date(),
            createdBy: Auth.auth().currentUser?.uid,
            metadata: metadata
        )

        Task {
            do {
                _ = try await TMIPlanService.shared.addPlanEvidence(planId: planId, entry: entry)
            } catch {
                print("[TMIPlanDetail] Failed to log evidence: \(error)")
            }
        }
    }

    private func deletePlan() {
        Task {
            do {
                try await TMIPlanService.shared.deletePlan(plan)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("[TMIPlanDetail] Error deleting plan: \(error)")
            }
        }
    }

    private func exportPlanToPDF() {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let pdfURL = try await exportService.exportPlanToPDF(plan)
                await MainActor.run {
                    exportedPDFURL = pdfURL
                    showingShareSheet = true
                }
                print("[TMIPlanDetail] Exported plan to PDF: \(pdfURL.path)")
            } catch {
                print("[TMIPlanDetail] Error exporting plan: \(error)")
                // TODO: Show error alert to user
            }
        }
    }
    
    private func exportPlanToMTSS() {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let mtssURL = try await exportService.exportPlanToMTSS(plan)
                await MainActor.run {
                    exportedPDFURL = mtssURL
                    showingShareSheet = true
                }
                print("[TMIPlanDetail] Exported MTSS report: \(mtssURL.path)")
            } catch {
                print("[TMIPlanDetail] Error exporting MTSS report: \(error)")
            }
        }
    }

    private func exportPlanToIEP() {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let iepURL = try await exportService.exportPlanToIEPContribution(plan)
                await MainActor.run {
                    exportedPDFURL = iepURL
                    showingShareSheet = true
                }
                print("[TMIPlanDetail] Exported IEP contribution: \(iepURL.path)")
            } catch {
                print("[TMIPlanDetail] Error exporting IEP contribution: \(error)")
            }
        }
    }

    @MainActor
    private func addGoalToPlan(_ newGoal: Goal) async {
        do {
            var goals = plan.goals
            goals.append(newGoal)

            let service = TMIPlanService.shared
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

            let service = TMIPlanService.shared
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

            let service = TMIPlanService.shared
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
            let service = TMIPlanService.shared
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
    private func loadSnapshotInterests() async {
        // Only load if plan.interests is empty but we have snapshot IDs
        guard plan.interests.isEmpty,
              let snapshotIds = plan.interestIdsSnapshot,
              !snapshotIds.isEmpty else {
            snapshotInterests = []
            return
        }

        isLoadingSnapshotInterests = true
        defer { isLoadingSnapshotInterests = false }

        do {
            var interests: [Interest] = []
            for interestId in snapshotIds {
                if let interest = try await InterestLibraryService.shared.fetchInterest(id: interestId) {
                    interests.append(interest)
                }
            }
            snapshotInterests = interests
            print("[TMIPlanDetail] Loaded \(interests.count) interests from snapshot for plan")
        } catch {
            print("[TMIPlanDetail] Error loading snapshot interests: \(error)")
            snapshotInterests = []
        }
    }

    @MainActor
    private func addResourceToPlan(_ resource: Resource) async {
        do {
            var resources = plan.resources
            resources.append(resource)

            let service = TMIPlanService.shared
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

            let service = TMIPlanService.shared
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

#if canImport(UIKit)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
#else
struct ActivityShareSheet: View {
    let activityItems: [Any]

    var body: some View {
        if let url = activityItems.first as? URL {
            ShareLink(item: url) {
                Label("Share Export", systemImage: "square.and.arrow.up")
            }
            .padding()
        } else {
            Text("Sharing is unavailable for this item.")
                .padding()
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        TMIPlanDetailView(plan: TMIPlan.samplePlan)
    }
}

// MARK: - Supporting Views for Edit



// MARK: - All Resources View
