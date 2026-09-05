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
            .frame(minWidth: 460, idealWidth: 500, minHeight: 320)
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
                    .buttonStyle(.borderedProminent)
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
                lifecycle(plan: plan, state: state, member: member)
                if let summary = plan.summary, !summary.isEmpty {
                    section("Summary") {
                        Text(summary).font(.body)
                    }
                }
                section("Dates") {
                    LabeledContent(
                        "Starts",
                        value: plan.startDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    if let targetDate = plan.targetDate {
                        LabeledContent(
                            "Target",
                            value: targetDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
                if state.childrenPhase == .loaded {
                goalsSection(plan: plan, state: state, member: member)

                if let repository = dependencies.resourceRepository {
                    section("Resources") {
                        PlanResourceListSection(planID: plan.id, member: member, repository: repository)
                    }
                }

                section("Progress") {
                    if state.progress.isEmpty {
                        Text("No progress recorded yet.")
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                    } else {
                        Text("\(state.completionPercentage)% of due actions done")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("planDetail.completion")
                        ForEach(state.progress) { entry in
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                Text(entry.note ?? entry.measuredValue ?? "Recorded")
                                    .font(.subheadline)
                                Text(entry.visibility == .sharedWithStudent
                                    ? "Shared with the student"
                                    : "Staff only")
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                        }
                    }
                }

                if state.canExport(member) {
                    section("Export") {
                        // Exporting is a separate permission from reading, and
                        // it is recorded before anything is produced.
                        ForEach(PlanExportKind.allCases, id: \.self) { kind in
                            Button("Export \(kind.title)") {
                                Task { await state.export(kind: kind, member: member) }
                            }
                            .buttonStyle(.bordered)
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
                } else {
                    section("Plan details") {
                        switch state.childrenPhase {
                        case .loading: ProgressView("Loading goals and history…")
                        case .failed(let message):
                            Text(message).foregroundStyle(TMIColors.errorText)
                            Button("Retry loading details") { Task { await state.load(member: member) } }
                                .buttonStyle(.bordered)
                        case .loaded: EmptyView()
                        }
                    }
                }
            }
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(TMISpacing.lg)
        }
        .refreshable { await state.load(member: member) }
    }

    private func header(
        plan: PlanRecord,
        state: CanonicalPlanDetailState,
        member: MembershipContext
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack(alignment: .top, spacing: TMISpacing.md) {
                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                    Text(plan.title)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("planDetail.title")
                    // A default plan keeps the model's name as its title; showing
                    // the model again underneath would just repeat the heading.
                    if plan.model.rawValue != plan.title {
                        Text(plan.model.rawValue)
                            .font(.headline)
                            .foregroundStyle(TMIColors.aubergine)
                    }
                }
                Spacer(minLength: 0)
                planStatusBadge(plan.status)
            }
            if let name = state.studentDisplayName {
                Label(name, systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planDetail.student")
            }
            if plan.status.isEditable, plan.metadata.createdBy == member.userID,
               member.capabilities.contains(.studentWriteDetail) {
                Button("Edit plan", systemImage: "pencil") { self.isEditingPlan = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("planDetail.edit")
            }
        }
    }

    private func planStatusBadge(_ status: PlanRecordStatus) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, TMISpacing.sm)
            .padding(.vertical, TMISpacing.xxs)
            .background(TMIColors.aubergineSoft, in: Capsule())
            .foregroundStyle(TMIColors.aubergine)
            .accessibilityIdentifier("planDetail.status")
    }

    private func goalStatusBadge(_ status: GoalRecordStatus) -> some View {
        let palette: (background: Color, foreground: Color) = switch status {
        case .notStarted: (TMIColors.surface, TMIColors.textSecondary)
        case .inProgress: (TMIColors.infoSurface, TMIColors.infoText)
        case .met: (TMIColors.successSurface, TMIColors.successText)
        case .discontinued: (TMIColors.errorSurface, TMIColors.errorText)
        }
        return Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, TMISpacing.sm)
            .padding(.vertical, 2)
            .background(palette.background, in: Capsule())
            .foregroundStyle(palette.foreground)
            .overlay(
                Capsule().stroke(TMIColors.border.opacity(0.5), lineWidth: status == .notStarted ? 1 : 0)
            )
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
                ForEach(transitions, id: \.self) { status in
                    Button("Move to \(status.displayName.lowercased())") {
                        if status == .changesRequested || status == .completed {
                            self.transitionNote = ""
                            self.pendingTransition = status
                        } else {
                            Task { await state.transition(to: status, member: member) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.isMutating)
                    .accessibilityIdentifier("planDetail.transition.\(status.rawValue)")
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
                .buttonStyle(.borderedProminent)
                .tint(TMIColors.aubergine)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(TMISpacing.md)
        .background(TMIColors.background, in: RoundedRectangle(cornerRadius: TMIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .stroke(TMIColors.border.opacity(0.6), lineWidth: 1)
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
                    .foregroundStyle(action.status == .done ? TMIColors.teal : TMIColors.textSecondary)
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
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
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
