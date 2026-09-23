import SwiftUI
import UniformTypeIdentifiers

/// One plan, with the controls the reader is actually allowed to use.
///
/// Controls are shown only where both the lifecycle and the member's
/// authority allow the move. A disabled button a reader cannot explain is
/// worse than no button, and hiding is not the authorization mechanism —
/// the rules refuse anything this misses.
struct CanonicalPlanDetailView: View {
    let planID: String

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @State private var state: CanonicalPlanDetailState?
    @State private var editingGoal: GoalRecord?
    @State private var isAddingGoal = false
    @State private var recordingAgainst: GoalRecord?
    @State private var addingActionTo: GoalRecord?
    @State private var editingAction: ActionRecord?
    @State private var pendingTransition: PlanRecordStatus?
    @State private var transitionNote = ""
    @State private var isEditingPlan = false
    @State private var confirmingArchive = false
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    private var usesWideLayout: Bool {
#if os(macOS)
        true
#else
        horizontalSizeClass == .regular
#endif
    }

    private let memberOverride: MembershipContext?

    init(planID: String, member: MembershipContext? = nil) {
        self.planID = planID
        self.memberOverride = member
    }

    private var member: MembershipContext? {
        memberOverride ?? authStateModel.currentMembership
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .plans).ignoresSafeArea()
            content
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("planDetail.screen")
        .onChange(of: member) { _, newMember in
            self.state?.updateMembership(newMember)
            self.editingGoal = nil
            self.editingAction = nil
            self.pendingTransition = nil
        }
        .sheet(isPresented: Binding(get: { self.pendingTransition != nil }, set: { if !$0 { self.pendingTransition = nil } })) {
            NavigationStack {
                Form {
                    Section(self.pendingTransition == .completed ? "Completion outcome" : "Requested changes") {
                        TextField("Explain the decision", text: $transitionNote, axis: .vertical)
                            .lineLimit(4...10)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Plan decision")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { self.pendingTransition = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            guard let status = self.pendingTransition, let member else { return }
                            let note = self.transitionNote
                            self.pendingTransition = nil
                            Task { await self.state?.transition(to: status, note: note, member: member) }
                        }
                        .disabled(transitionNote.trimmed.isEmpty)
                    }
                }
            }
            .tmiMacSheetFrame(minWidth: 460, idealWidth: 500, minHeight: 320)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isEditingPlan) {
            if let state, let plan = state.plan, let member,
               let studentID = plan.studentIDs.sorted().first,
               let schoolID = plan.schoolIDs.sorted().first {
                CanonicalPlanEditorView(studentID: studentID,
                    studentName: state.studentDisplayName ?? "Selected student", schoolID: schoolID,
                    member: member, existingPlan: plan) { _ in
                    Task { await state.load(member: member) }
                }
            }
        }
        .sheet(item: $editingAction) { action in
            if let state, let plan = state.plan, let member,
               let goal = state.goals.first(where: { $0.id == action.goalID }) {
                ActionEditorView(planID: plan.id, goal: goal, member: member,
                                 existing: action, statusOnly: !plan.status.isEditable) {
                    Task { await state.reloadChildren(member: member) }
                }
            }
        }
        .sheet(isPresented: $isAddingGoal) {
            if let plan = state?.plan, let member {
                GoalEditorView(
                    planID: plan.id,
                    studentID: plan.studentIDs.sorted().first ?? "",
                    member: member,
                    planStartDate: plan.startDate
                ) { _ in
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .sheet(item: $addingActionTo) { goal in
            if let plan = state?.plan, let member {
                ActionEditorView(planID: plan.id, goal: goal, member: member) {
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .sheet(item: $recordingAgainst) { goal in
            if let plan = state?.plan, let member {
                ProgressEntryView(
                    planID: plan.id,
                    studentID: goal.studentID,
                    member: member,
                    source: .goal,
                    sourceID: goal.id,
                    sourceTitle: goal.title
                ) {
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .sheet(item: $editingGoal) { goal in
            if let plan = state?.plan, let member {
                GoalEditorView(
                    planID: plan.id,
                    studentID: goal.studentID,
                    member: member,
                    planStartDate: plan.startDate,
                    existing: goal,
                    statusOnly: !plan.status.isEditable
                ) { _ in
                    Task { await state?.reloadChildren(member: member) }
                }
            }
        }
        .task(id: member) {
            guard let repository = dependencies.planRepository, let member else { return }
            let created = CanonicalPlanDetailState(
                planID: planID,
                repository: repository,
                children: dependencies.planChildRepository,
                auditing: dependencies.planExportAuditing
            )
            state = created
            await created.load(member: member)
            if let studentID = created.plan?.studentIDs.sorted().first,
               let student = try? await dependencies.studentRepository.student(id: studentID, member: member),
               self.member == member, created.hasAccess(member) {
                created.studentDisplayName = student.displayName
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dependencies.planRepository == nil {
            ContentUnavailableView(
                "Plans unavailable",
                systemImage: "doc.text",
                description: Text("Plans are unavailable in this build.")
            )
        } else if let state, let member {
            switch state.phase {
            case .loading:
                ProgressView("Loading plan…")
            case .permissionDenied:
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: "lock",
                    description: Text("You do not have access to this plan.")
                )
                .accessibilityIdentifier("planDetail.permissionDenied")
            case .failed(let message):
                VStack {
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                Button("Retry") { Task { await state.load(member: member) } }
                    .buttonStyle(.tmiPrimary)
                }
            case .loaded(let plan):
                loaded(plan: plan, state: state, member: member)
            }
        } else {
            ProgressView()
        }
    }

    private func loaded(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                header(plan: plan, state: state, member: member)
                if usesWideLayout {
                    HStack(alignment: .top, spacing: TMISpacing.lg) {
                        VStack(alignment: .leading, spacing: TMISpacing.lg) {
                            mainColumn(plan: plan, state: state, member: member)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: TMISpacing.lg) {
                            sideColumn(plan: plan, state: state, member: member)
                        }
                        .frame(width: 340)
                    }
                } else {
                    mainColumn(plan: plan, state: state, member: member)
                    sideColumn(plan: plan, state: state, member: member)
                }
            }
            .frame(maxWidth: usesWideLayout ? TMISizing.maxContentWidth : TMISizing.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.md)
        }
        .tmiScreenBackground()
        .refreshable { await state.load(member: member) }
#if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await state.load(member: member) }
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh this plan (⌘R)")
            }
        }
#endif
        .confirmationDialog(
            "Archive this plan?",
            isPresented: $confirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archive Plan", role: .destructive) {
                Task { await state.transition(to: .archived, member: member) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Archiving is final. The plan leaves active work and can no longer be edited.")
        }
    }

    @ViewBuilder
    private func mainColumn(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        lifecycle(plan: plan, state: state, member: member)
        if let summary = plan.summary, !summary.isEmpty {
            section("Summary") {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(TMIColors.textPrimary)
            }
        }
        if state.childrenPhase == .loaded {
            goalsSection(plan: plan, state: state, member: member)
            progressSection(state: state)
        } else {
            section("Plan details") {
                switch state.childrenPhase {
                case .loading: ProgressView("Loading goals and history…")
                case .failed(let message):
                    Text(message).foregroundStyle(TMIColors.errorText)
                    Button("Retry loading details") { Task { await state.load(member: member) } }
                        .buttonStyle(.tmiSecondary)
                case .loaded: EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func sideColumn(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        section("Dates") {
            TMIKeyValueRow("Starts", value: plan.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            if let targetDate = plan.targetDate {
                TMIKeyValueRow("Target", value: targetDate.formatted(date: .abbreviated, time: .omitted), systemImage: "target")
            }
            if let reviewDate = plan.reviewDate {
                TMIKeyValueRow("Next review", value: reviewDate.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
            }
        }
        if state.childrenPhase == .loaded {
            if let repository = dependencies.resourceRepository {
                section("Resources") {
                    PlanResourceListSection(
                        planID: plan.id,
                        member: member,
                        repository: repository,
                        canLink: plan.status.isEditable
                    )
                }
            }

            if let studentID = plan.studentIDs.sorted().first {
                section("Recommendations") {
                    PlanRecommendationsStrip(studentID: studentID, planID: plan.id)
                }
            }

            if state.canExport(member) {
                section("Export") {
                    // Exporting is a separate permission from reading, and
                    // it is recorded before anything is produced.
                    ForEach(PlanExportKind.allCases, id: \.self) { kind in
                        Button("Export \(kind.title)", systemImage: "arrow.down.doc") {
                            Task { await state.export(kind: kind, member: member) }
                        }
                        .buttonStyle(.tmiSecondary)
                        .disabled(state.isMutating)
                        .accessibilityIdentifier("planDetail.export.\(kind.rawValue)")
                    }
                    if state.exportedPDF != nil {
                        let exportID = state.exportID
                        ShareLink(item: PlanPDFShare {
                            try state.pdfForSharing(id: exportID, member: member)
                        }, preview: SharePreview("TMI plan", image: Image(systemName: "doc.richtext"))) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.tmiPrimary)
                        .accessibilityIdentifier("planDetail.sharePDF")
                    }
                    if let message = state.exportMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(TMIColors.textSecondary)
                            .accessibilityIdentifier("planDetail.exportMessage")
                    }
                }
            }

            section("History") {
                // Revisions freeze at approval, changes requested and
                // completion. Until those are persisted there is nothing
                // to show, and saying so beats an empty box.
                if state.revisions.isEmpty {
                    Text("Revisions appear here once this plan is approved or completed.")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                } else {
                    ForEach(PlanRevisionHistory.ordered(state.revisions)) { revision in
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text("\(revision.reason.displayName) · revision \(revision.sequence)")
                                .font(.subheadline.weight(.semibold))
                            Text(revision.frozenAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                            if let note = revision.note {
                                Text(note).font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }

    private func progressSection(state: CanonicalPlanDetailState) -> some View {
        section("Progress") {
            if state.progress.isEmpty {
                Text("No progress recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                // Completion counts every action on the plan, due or not.
                Text("\(state.completionPercentage)% of actions done")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("planDetail.completion")
                ForEach(state.progress) { entry in
                    HStack(alignment: .top, spacing: TMISpacing.ms) {
                        TMIIconTile(entry.visibility == .sharedWithStudent ? "person.fill.checkmark" : "lock.fill",
                                    tone: entry.visibility == .sharedWithStudent ? .success : .neutral,
                                    size: 28)
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text(entry.note ?? entry.measuredValue ?? "Recorded")
                                .font(.subheadline)
                                .foregroundStyle(TMIColors.textPrimary)
                            Text(entry.visibility == .sharedWithStudent
                                ? "Shared with the student"
                                : "Staff only")
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func header(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        HStack(alignment: .top, spacing: TMISpacing.md) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                planStatusBadge(plan.status)
                Text(plan.title)
                    .font(.tmiEditorial(.largeTitle))
                    .foregroundStyle(TMIColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("planDetail.title")
                // A default plan keeps the model's name as its title; showing
                // the model again underneath would just repeat the heading.
                if plan.model.rawValue != plan.title {
                    Label(plan.model.rawValue, systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(TMIColors.accent)
                }
                if let name = state.studentDisplayName {
                    Label(name, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                        .privacySensitive()
                        .accessibilityIdentifier("planDetail.student")
                }
                if plan.status.isEditable,
                   (plan.effectiveOwnerMemberID == member.userID || plan.assignedMemberIDs.contains(member.userID)),
                   member.capabilities.contains(.studentWriteDetail) {
                    Button("Edit plan", systemImage: "pencil") { self.isEditingPlan = true }
                        .buttonStyle(.tmiSecondary)
                        .keyboardShortcut("e", modifiers: .command)
                        .padding(.top, TMISpacing.xs)
                        .accessibilityIdentifier("planDetail.edit")
                }
            }
            Spacer(minLength: 0)
            if state.childrenPhase == .loaded, !state.actions.isEmpty {
                VStack(spacing: 4) {
                    TMIProgressCircle(progress: Double(state.completionPercentage) / 100, size: 72, lineWidth: 6)
                    Text("of actions done")
                        .font(.caption)
                        .foregroundStyle(TMIColors.textTertiary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .tmiSurface(padding: TMISpacing.ml)
    }

    private func planStatusBadge(_ status: PlanRecordStatus) -> some View {
        TMIStatusBadge(status.displayName, tone: Self.tone(for: status))
            .accessibilityIdentifier("planDetail.status")
    }

    private static func tone(for status: PlanRecordStatus) -> TMITone {
        switch status {
        case .approved, .active: .success
        case .paused, .changesRequested, .pendingApproval: .warning
        case .completed, .archived: .info
        case .draft: .neutral
        }
    }

    /// Forward moves first, pauses and rework next, archive (terminal) last.
    private static func rank(_ status: PlanRecordStatus) -> Int {
        switch status {
        case .pendingApproval: 0
        case .approved: 1
        case .active: 2
        case .completed: 3
        case .changesRequested: 4
        case .paused: 5
        case .draft: 6
        case .archived: 7
        }
    }

    private func goalStatusBadge(_ status: GoalRecordStatus) -> some View {
        let tone: TMITone = switch status {
        case .notStarted: .neutral
        case .inProgress: .info
        case .met: .success
        case .discontinued: .danger
        }
        return TMIStatusBadge(status.displayName, tone: tone)
    }

    private func lifecycle(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        section("Next step") {
            let transitions = state.availableTransitions(for: member)
            if transitions.isEmpty {
                Text(plan.status.isOpen
                    ? "You do not have access to move this plan."
                    : "This plan has ended.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planDetail.noTransitions")
            } else {
                let ordered = transitions.sorted { Self.rank($0) < Self.rank($1) }
                FlowLayout(spacing: TMISpacing.sm) {
                    ForEach(ordered, id: \.self) { status in
                        Button("Move to \(status.displayName.lowercased())") {
                            if status == .changesRequested || status == .completed {
                                self.transitionNote = ""
                                self.pendingTransition = status
                            } else if status == .archived {
                                self.confirmingArchive = true
                            } else {
                                Task { await state.transition(to: status, member: member) }
                            }
                        }
                        .buttonStyle(TMIActionButtonStyle(
                            prominence: status == .archived ? .destructive
                                : (status == ordered.first ? .primary : .secondary)
                        ))
                        .disabled(state.isMutating)
                        .accessibilityIdentifier("planDetail.transition.\(status.rawValue)")
                    }
                }
            }
            if let message = state.actionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planDetail.actionMessage")
            }
        }
    }

    private func goalsSection(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        section("Goals") {
            if state.goals.isEmpty {
                Text("No goals yet. A plan without a goal has nothing to measure.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(state.goals) { goal in
                        goalCard(goal: goal, plan: plan, state: state, member: member)
                    }
                }
            }
            // Writing a goal is editing the plan, so it needs write access.
            if member.capabilities.contains(.studentWriteDetail), plan.status.isEditable {
                Button("Add a goal", systemImage: "plus.circle.fill") {
                    isAddingGoal = true
                }
                .buttonStyle(.tmiPrimary)
                .accessibilityIdentifier("planDetail.addGoal")
            }
        }
    }

    /// One goal, its actions, and the writes allowed against it — as a single
    /// bordered card so adjacent goals never blur together.
    private func goalCard(
        goal: GoalRecord,
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        let canWrite = member.capabilities.contains(.studentWriteDetail)
        let interactive = canWrite && (plan.status.isEditable || plan.status.acceptsProgress)
        let actions = state.actions.filter { $0.goalID == goal.id }
        return VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Button {
                editingGoal = goal
            } label: {
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: TMISpacing.sm) {
                        Text(goal.title)
                            .font(.headline)
                            .foregroundStyle(TMIColors.textPrimary)
                        Spacer(minLength: 0)
                        goalStatusBadge(goal.status)
                    }
                    HStack(spacing: TMISpacing.xs) {
                        Text(goal.baseline).foregroundStyle(TMIColors.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(TMIColors.textSecondary)
                        Text(goal.target).foregroundStyle(TMIColors.textPrimary)
                    }
                    .font(.subheadline)
                    Text("Due \(goal.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!interactive)
            .accessibilityIdentifier("planDetail.goal.\(goal.id)")

            if !actions.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        if index > 0 { Divider() }
                        actionRow(action, enabled: interactive)
                    }
                }
            }

            if canWrite, plan.status.isEditable || plan.status.acceptsProgress {
                HStack(spacing: TMISpacing.sm) {
                    if plan.status.isEditable {
                        Button("Add action", systemImage: "plus") { self.addingActionTo = goal }
                            .accessibilityIdentifier("planDetail.addAction.\(goal.id)")
                    }
                    if plan.status.acceptsProgress {
                        Button("Record progress", systemImage: "chart.line.uptrend.xyaxis") {
                            self.recordingAgainst = goal
                        }
                        .accessibilityIdentifier("planDetail.recordProgress.\(goal.id)")
                    }
                }
                .buttonStyle(.tmiTertiary)
            }
        }
        .padding(TMISpacing.md)
        .background(TMIColors.surfaceSecondary, in: TMIShape.control)
        .overlay(
            TMIShape.control.strokeBorder(TMIColors.separator, lineWidth: 1)
        )
    }

    private func actionRow(_ action: ActionRecord, enabled: Bool) -> some View {
        let symbol = switch action.status {
        case .done: "checkmark.circle.fill"
        case .skipped: "minus.circle"
        case .open: "circle"
        }
        return Button {
            self.editingAction = action
        } label: {
            HStack(spacing: TMISpacing.sm) {
                Image(systemName: symbol)
                    .foregroundStyle(action.status == .done ? TMIColors.successText : TMIColors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                Text(action.title)
                    .strikethrough(action.status == .done, color: TMIColors.textSecondary)
                    .foregroundStyle(action.status == .done ? TMIColors.textSecondary : TMIColors.textPrimary)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("planDetail.action.\(action.id)")
    }

    @ViewBuilder
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(TMIColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmiSurface(padding: TMISpacing.md)
    }
}

private struct PlanPDFShare: Transferable, Sendable {
    let bytes: @MainActor @Sendable () throws -> Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            try await item.bytes()
        }
        .suggestedFileName("TMI-plan.pdf")
    }
}
