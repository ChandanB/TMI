import SwiftUI

/// The canonical 12-step educator workflow for creating and revising a TMI plan.
struct CanonicalPlanEditorView: View {
    let studentID: String
    let studentName: String
    let schoolID: String
    let member: MembershipContext
    var existingPlan: PlanRecord? = nil
    var onCreated: (PlanRecord) -> Void = { _ in }

    @Environment(\.appDependencies) private var dependencies
    @State private var state: PlanEditorState?
    @State private var setupError: String?

    var body: some View {
        Group {
            if let state {
                PlanEditorWorkflowView(state: state, onFinished: onCreated)
            } else if let setupError {
                ContentUnavailableView(
                    "Plans unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(setupError)
                )
            } else {
                ProgressView("Preparing plan…")
                    .task { configureState() }
            }
        }
    }

    @MainActor
    private func configureState() {
        guard state == nil, setupError == nil else { return }
        guard let repository = dependencies.planRepository,
              let children = dependencies.planChildRepository else {
            setupError = "Canonical plan services are not configured in this build."
            return
        }
        state = PlanEditorState(
            studentID: studentID,
            studentName: studentName,
            schoolID: schoolID,
            member: member,
            repository: repository,
            children: children,
            existingPlan: existingPlan
        )
    }
}

private struct PlanEditorWorkflowView: View {
    @Bindable var state: PlanEditorState
    let onFinished: (PlanRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: PlanEditorState.Step = .student

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: TMISpacing.lg) {
                        stepContent
                        saveFeedback
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(TMISpacing.xl)
                    .frame(maxWidth: .infinity)
                }

                navigationFooter
            }
            .background(TMIColors.background)
            .navigationTitle(state.currentRecord == nil ? "New TMI Plan" : "Edit TMI Plan")
            .navigationBarTitleDisplayMode(.inline)
#if os(macOS)
            .frame(minWidth: 480, idealWidth: 640, minHeight: 560, idealHeight: 700)
#endif
            .interactiveDismissDisabled(state.savePhase == .saving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(state.savePhase == .saving)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Draft") { Task { await state.autosave() } }
                        .disabled(!state.canEdit || state.selectedModel == nil || state.savePhase == .saving)
                        .accessibilityIdentifier("planEditor.saveDraft")
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack {
                Text("Step \(step.rawValue + 1) of \(PlanEditorState.Step.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TMIColors.teal)
                Spacer()
                Text(step.title)
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
            }
            ProgressView(value: Double(step.rawValue + 1), total: Double(PlanEditorState.Step.allCases.count))
                .tint(TMIColors.teal)
        }
        .padding(.horizontal, TMISpacing.xl)
        .padding(.vertical, TMISpacing.md)
        .background(TMIColors.surface)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityIdentifier("planEditor.progress")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .student:
            editorCard(title: "Student", icon: "person.crop.circle") {
                LabeledContent("Student", value: state.studentName)
                LabeledContent("School record", value: state.schoolID)
                TextField("Plan title", text: savingBinding(\.title))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.title")
                TextField("Summary (optional)", text: savingBinding(\.summary), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.summary")
            }

        case .signals:
            editorCard(title: "Signals & data sources", icon: "chart.xyaxis.line") {
                Text("Review current student records and the approved evidence that informs this intervention before selecting a model.")
                    .foregroundStyle(TMIColors.textSecondary)
                Toggle("I reviewed the current signals and approved data sources", isOn: savingBinding(\.signalsReviewed))
                    .accessibilityIdentifier("planEditor.signalsReviewed")
            }

        case .model:
            editorCard(title: "Choose an intervention model", icon: "point.3.connected.trianglepath.dotted") {
                Text("Select professional need tags to get deterministic, explainable recommendations. You can always choose a model manually.")
                    .foregroundStyle(TMIColors.textSecondary)

                FlowLayout(spacing: TMISpacing.sm) {
                    ForEach(PlanNeedTag.allCases, id: \.self) { tag in
                        TMIButton(
                            text: tag.displayName,
                            style: .filter(isSelected: state.selectedNeedTags.contains(tag))
                        ) {
                            toggleNeedTag(tag)
                        }
                    }
                }

                if !state.recommendations.isEmpty {
                    Divider()
                    Text("Recommended")
                        .font(.headline)
                    ForEach(state.recommendations.prefix(3)) { recommendation in
                        Button {
                            state.chooseRecommendation(recommendation)
                            state.scheduleAutosave()
                        } label: {
                            VStack(alignment: .leading, spacing: TMISpacing.xs) {
                                HStack {
                                    Text(recommendation.model.rawValue).font(.headline)
                                    Spacer()
                                    if state.modelSelection == .recommendation(recommendation.model) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(TMIColors.teal)
                                    }
                                }
                                ForEach(recommendation.reasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.footnote)
                                        .foregroundStyle(TMIColors.textSecondary)
                                }
                            }
                            .padding(TMISpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TMIColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: TMIRadius.md)
                                    .stroke(TMIColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                Picker("Manual model choice", selection: manualModelBinding) {
                    Text("Choose a model").tag(TMIPlanModel?.none)
                    ForEach(TMIPlanModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(Optional(model))
                    }
                }
                .accessibilityIdentifier("planEditor.model")
                if let selectedModel = state.selectedModel {
                    Text(selectedModel.description)
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                }
            }

        case .professionalNeed:
            editorCard(title: "Professional need", icon: "text.badge.checkmark") {
                Text("State the observable educational or developmental need this plan is intended to address.")
                    .foregroundStyle(TMIColors.textSecondary)
                TextField("Professional need", text: savingBinding(\.professionalNeed), axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.professionalNeed")
            }

        case .interestsAndCareers:
            editorCard(title: "Interests & careers", icon: "sparkles") {
                Text("Use the student's approved interests, hobbies, strengths, and saved career exploration to shape the intervention activities.")
                    .foregroundStyle(TMIColors.textSecondary)
                Toggle("I reviewed the student's current interests and career connections", isOn: savingBinding(\.interestsAndCareersReviewed))
                    .accessibilityIdentifier("planEditor.interestsReviewed")
            }

        case .immediateAction:
            editorCard(title: "Immediate next action", icon: "figure.walk.motion") {
                Text("Define one concrete action that can begin immediately after the plan is approved.")
                    .foregroundStyle(TMIColors.textSecondary)
                TextField("Action", text: immediateActionTitleBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.action.title")
                Picker("Audience", selection: immediateActionAudienceBinding) {
                    ForEach(ActionAudience.allCases, id: \.self) { audience in
                        Text(audience.displayName).tag(audience)
                    }
                }
                Picker("Cadence", selection: immediateActionCadenceBinding) {
                    Text("Choose cadence").tag(ActionCadence?.none)
                    ForEach(ActionCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(Optional(cadence))
                    }
                }
                DatePicker("First due date", selection: immediateActionDueDateBinding, in: state.startDate..., displayedComponents: .date)
                    .accessibilityIdentifier("planEditor.action.dueDate")
            }

        case .goalsAndMeasures:
            editorCard(title: "Goal, baseline, target & measure", icon: "target") {
                TextField("Goal", text: goalTitleBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.goal.title")
                TextField("Student-facing wording (optional)", text: goalStudentTitleBinding)
                    .textFieldStyle(.roundedBorder)
                Picker("Measure", selection: goalMeasureBinding) {
                    Text("Choose measure").tag(GoalMeasure?.none)
                    ForEach(GoalMeasure.allCases, id: \.self) { measure in
                        Text(measure.displayName).tag(Optional(measure))
                    }
                }
                TextField("Baseline", text: goalBaselineBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.goal.baseline")
                TextField("Target", text: goalTargetBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.goal.target")
                DatePicker("Goal due date", selection: goalDueDateBinding, in: state.startDate..., displayedComponents: .date)
            }

        case .responsibleStaff:
            editorCard(title: "Responsible staff", icon: "person.2.badge.gearshape") {
                Text("Assign the staff member responsible for the plan itself, then the owners of its action and goal. Your own member ID is shown for quick assignment.")
                    .foregroundStyle(TMIColors.textSecondary)
                LabeledContent("Your member ID", value: state.member.userID)
                HStack {
                    TextField("Plan owner", text: planOwnerBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("planEditor.plan.owner")
                    Button("Assign me") { setPlanOwnerToCurrentMember() }
                }
                HStack {
                    TextField("Immediate action owner", text: immediateActionOwnerBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("planEditor.action.owner")
                    Button("Assign me") { setActionOwnerToCurrentMember() }
                }
                HStack {
                    TextField("Goal owner", text: goalOwnerBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("planEditor.goal.owner")
                    Button("Assign me") { setGoalOwnerToCurrentMember() }
                }
            }

        case .supportMaterials:
            editorCard(title: "Resources, activities, forms & surveys", icon: "tray.full") {
                Text("Review the support materials connected to this student and decide what the team will use during the intervention.")
                    .foregroundStyle(TMIColors.textSecondary)
                Toggle("I reviewed the resources, activities, forms, and surveys for this plan", isOn: savingBinding(\.supportMaterialsReviewed))
                    .accessibilityIdentifier("planEditor.supportReviewed")
            }

        case .datesAndCadence:
            editorCard(title: "Dates & meeting cadence", icon: "calendar.badge.clock") {
                DatePicker("Start date", selection: savingBinding(\.startDate), displayedComponents: .date)
                    .accessibilityIdentifier("planEditor.startDate")
                DatePicker("Review date", selection: reviewDateBinding, in: state.startDate..., displayedComponents: .date)
                    .accessibilityIdentifier("planEditor.reviewDate")
                DatePicker("End date", selection: targetDateBinding, in: state.startDate..., displayedComponents: .date)
                    .accessibilityIdentifier("planEditor.targetDate")
                Picker("Team review cadence", selection: savingBinding(\.meetingCadence)) {
                    Text("Choose cadence").tag(ActionCadence?.none)
                    ForEach(ActionCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(Optional(cadence))
                    }
                }
                .accessibilityIdentifier("planEditor.meetingCadence")
            }

        case .studentVoiceAndFamily:
            editorCard(title: "Student voice & family collaboration", icon: "quote.bubble") {
                TextField("Student voice — in the student's own words", text: savingBinding(\.studentVoice), axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("planEditor.studentVoice")
                Picker("Family collaboration", selection: savingBinding(\.familyCollaborationPermission)) {
                    ForEach(PlanFamilyCollaborationPermission.allCases, id: \.self) { permission in
                        Text(permission.displayName).tag(permission)
                    }
                }
                .accessibilityIdentifier("planEditor.familyPermission")
                if state.familyCollaborationPermission == .authorized {
                    TextField("Authorizing consent record ID", text: savingBinding(\.familyConsentID))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("planEditor.familyConsentID")
                }
            }

        case .reviewAndSubmit:
            reviewStep
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            editorCard(title: "Review the plan", icon: "checklist") {
                reviewRow("Student", state.studentName)
                reviewRow("Model", state.selectedModel?.rawValue ?? "Not selected")
                reviewRow("Professional need", state.professionalNeed.trimmed.isEmpty ? "Not recorded" : state.professionalNeed.trimmed)
                reviewRow("Plan owner", state.planOwnerMemberID.trimmed.isEmpty ? "Not assigned" : state.planOwnerMemberID.trimmed)
                reviewRow("Immediate action", state.immediateAction.title.trimmed.isEmpty ? "Not recorded" : state.immediateAction.title.trimmed)
                reviewRow("Goal", state.goal.title.trimmed.isEmpty ? "Not recorded" : state.goal.title.trimmed)
                reviewRow("Student voice", state.studentVoice.trimmed.isEmpty ? "Not recorded" : state.studentVoice.trimmed)
                Toggle("I reviewed this plan and it is ready for approval", isOn: savingBinding(\.reviewedForSubmission))
                    .accessibilityIdentifier("planEditor.reviewedForSubmission")
            }

            if !state.submissionIssues.isEmpty {
                editorCard(title: "Still needed", icon: "exclamationmark.circle") {
                    ForEach(state.submissionIssues, id: \.self) { issue in
                        Label(issue.message, systemImage: "circle")
                            .font(.footnote)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                }
            }

            TMIButton(
                text: "Submit for Approval",
                icon: "paperplane.fill",
                style: .primary,
                isLoading: state.savePhase == .saving,
                isDisabled: !state.submissionIssues.isEmpty || !state.canEdit
            ) {
                Task {
                    await state.submit()
                    if state.savePhase == .submitted, let record = state.currentRecord {
                        onFinished(record)
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("planEditor.submit")
        }
    }

    @ViewBuilder
    private var saveFeedback: some View {
        switch state.savePhase {
        case .idle:
            EmptyView()
        case .saving:
            Label("Saving draft…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(TMIColors.textSecondary)
        case .saved:
            Label("Draft saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(TMIColors.successText)
                .accessibilityIdentifier("planEditor.saved")
        case .submitted:
            Label("Submitted for approval", systemImage: "checkmark.seal.fill")
                .foregroundStyle(TMIColors.successText)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(TMIColors.errorText)
                .accessibilityIdentifier("planEditor.error")
        case .versionConflict:
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Label("This plan changed elsewhere. Your local draft is preserved.", systemImage: "arrow.triangle.branch")
                    .foregroundStyle(TMIColors.warningText)
                if state.conflict?.serverRecord != nil {
                    Button("Use latest server version") { state.resolveConflictUsingServer() }
                        .accessibilityIdentifier("planEditor.useServerVersion")
                }
            }
        }
    }

    private var navigationFooter: some View {
        HStack(spacing: TMISpacing.md) {
            Button("Back", systemImage: "chevron.left") { move(by: -1) }
                .disabled(step == .student)
                .accessibilityIdentifier("planEditor.back")
            Spacer()
            Text(step.title)
                .font(.footnote)
                .foregroundStyle(TMIColors.textSecondary)
            Spacer()
            if step != .reviewAndSubmit {
                Button("Next", systemImage: "chevron.right") { move(by: 1) }
                    .accessibilityIdentifier("planEditor.next")
            }
        }
        .padding(.horizontal, TMISpacing.xl)
        .padding(.vertical, TMISpacing.md)
        .background(TMIColors.surface)
        .overlay(alignment: .top) { Divider() }
    }

    private func editorCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TMICard(style: .outlined, accentColor: TMIColors.teal) {
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                Label(title, systemImage: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TMIColors.aubergine)
                content()
            }
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TMIColors.textSecondary)
            Text(value)
                .foregroundStyle(TMIColors.textPrimary)
        }
    }

    private func move(by offset: Int) {
        let next = min(max(step.rawValue + offset, 0), PlanEditorState.Step.allCases.count - 1)
        guard let newStep = PlanEditorState.Step(rawValue: next) else { return }
        state.scheduleAutosave()
        step = newStep
    }

    private func toggleNeedTag(_ tag: PlanNeedTag) {
        if let index = state.selectedNeedTags.firstIndex(of: tag) {
            state.selectedNeedTags.remove(at: index)
        } else {
            state.selectedNeedTags.append(tag)
        }
        state.scheduleAutosave()
    }

    private func setActionOwnerToCurrentMember() {
        state.immediateAction.ownerMemberID = state.member.userID
        state.scheduleAutosave()
    }

    private func setPlanOwnerToCurrentMember() {
        state.planOwnerMemberID = state.member.userID
        state.scheduleAutosave()
    }

    private func setGoalOwnerToCurrentMember() {
        state.goal.responsibleMemberID = state.member.userID
        state.scheduleAutosave()
    }

    private func savingBinding<Value>(_ keyPath: ReferenceWritableKeyPath<PlanEditorState, Value>) -> Binding<Value> {
        Binding(
            get: { state[keyPath: keyPath] },
            set: {
                state[keyPath: keyPath] = $0
                state.scheduleAutosave()
            }
        )
    }

    private var manualModelBinding: Binding<TMIPlanModel?> {
        Binding(
            get: {
                guard case .manual(let model) = state.modelSelection else { return nil }
                return model
            },
            set: { model in
                guard let model else { return }
                state.chooseManualModel(model)
                state.scheduleAutosave()
            }
        )
    }

    private var immediateActionTitleBinding: Binding<String> {
        Binding(get: { state.immediateAction.title }, set: { state.immediateAction.title = $0; state.scheduleAutosave() })
    }
    private var planOwnerBinding: Binding<String> {
        Binding(get: { state.planOwnerMemberID }, set: { state.planOwnerMemberID = $0; state.scheduleAutosave() })
    }
    private var immediateActionOwnerBinding: Binding<String> {
        Binding(get: { state.immediateAction.ownerMemberID }, set: { state.immediateAction.ownerMemberID = $0; state.scheduleAutosave() })
    }
    private var immediateActionAudienceBinding: Binding<ActionAudience> {
        Binding(get: { state.immediateAction.audience }, set: { state.immediateAction.audience = $0; state.scheduleAutosave() })
    }
    private var immediateActionCadenceBinding: Binding<ActionCadence?> {
        Binding(get: { state.immediateAction.cadence }, set: { state.immediateAction.cadence = $0; state.scheduleAutosave() })
    }
    private var immediateActionDueDateBinding: Binding<Date> {
        Binding(
            get: { state.immediateAction.dueDate ?? state.startDate },
            set: { state.immediateAction.dueDate = $0; state.scheduleAutosave() }
        )
    }
    private var goalTitleBinding: Binding<String> {
        Binding(get: { state.goal.title }, set: { state.goal.title = $0; state.scheduleAutosave() })
    }
    private var goalStudentTitleBinding: Binding<String> {
        Binding(get: { state.goal.studentFacingTitle }, set: { state.goal.studentFacingTitle = $0; state.scheduleAutosave() })
    }
    private var goalMeasureBinding: Binding<GoalMeasure?> {
        Binding(get: { state.goal.measure }, set: { state.goal.measure = $0; state.scheduleAutosave() })
    }
    private var goalBaselineBinding: Binding<String> {
        Binding(get: { state.goal.baseline }, set: { state.goal.baseline = $0; state.scheduleAutosave() })
    }
    private var goalTargetBinding: Binding<String> {
        Binding(get: { state.goal.target }, set: { state.goal.target = $0; state.scheduleAutosave() })
    }
    private var goalDueDateBinding: Binding<Date> {
        Binding(get: { state.goal.dueDate ?? state.startDate }, set: { state.goal.dueDate = $0; state.scheduleAutosave() })
    }
    private var goalOwnerBinding: Binding<String> {
        Binding(get: { state.goal.responsibleMemberID }, set: { state.goal.responsibleMemberID = $0; state.scheduleAutosave() })
    }
    private var reviewDateBinding: Binding<Date> {
        Binding(
            get: { state.reviewDate ?? state.startDate.addingTimeInterval(86_400 * 7) },
            set: { state.reviewDate = $0; state.scheduleAutosave() }
        )
    }
    private var targetDateBinding: Binding<Date> {
        Binding(
            get: { state.targetDate ?? state.startDate.addingTimeInterval(86_400 * 30) },
            set: { state.targetDate = $0; state.scheduleAutosave() }
        )
    }
}
