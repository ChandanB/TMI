//
//  TMIPlanEditorView.swift
//  TMI
//
//  Unified TMI plan editor supporting both create and edit modes.
//  - Create mode: existingPlan == nil, optionally pre-select a student via preselectedStudent
//  - Edit mode:   existingPlan != nil
//

import SwiftUI
import FirebaseAuth

struct TMIPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Configuration

    let existingPlan: TMIPlan?
    let preselectedStudent: Student?

    /// Called after a plan is successfully created (create mode only).
    let onPlanCreated: (() -> Void)?

    /// Called after a plan is successfully saved (edit mode only).
    let onSave: ((TMIPlan) -> Void)?

    // MARK: - Computed mode

    private var isEditMode: Bool { existingPlan != nil }

    // MARK: - Shared state

    @State private var planTitle = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // MARK: - Create-mode state

    @State private var selectedModel: TMIPlanModel?
    @State private var selectedInterests: Set<Interest> = []
    @State private var interests: [Interest] = []
    @State private var interestCount: Int = 0

    // MARK: - Edit-mode state

    @State private var description = ""
    @State private var editSelectedInterests: [Interest] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var newNoteEntry: String = ""
    @State private var showError = false

    private let tmiPlanService = TMIPlanService.shared

    // MARK: - Init

    init(
        existingPlan: TMIPlan? = nil,
        preselectedStudent: Student? = nil,
        onPlanCreated: (() -> Void)? = nil,
        onSave: ((TMIPlan) -> Void)? = nil
    ) {
        self.existingPlan = existingPlan
        self.preselectedStudent = preselectedStudent
        self.onPlanCreated = onPlanCreated
        self.onSave = onSave

        if let plan = existingPlan {
            _planTitle = State(initialValue: plan.title)
            _description = State(initialValue: plan.description ?? "")
            _notes = State(initialValue: plan.notes)
            _editSelectedInterests = State(initialValue: plan.interests)
            _startDate = State(initialValue: plan.startDate)
            _endDate = State(initialValue: plan.endDate ?? Date().addingTimeInterval(86400 * 30))
        }
    }

    // MARK: - Body

    var body: some View {
        if isEditMode {
            editBody
        } else {
            createBody
        }
    }

    // MARK: - Create Mode Body

    private var createBody: some View {
        ZStack {
            TMIBackgroundView(variant: .plans)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    createHeaderSection

                    if let student = preselectedStudent {
                        studentInfoCard(student: student)
                        suggestedModelCard(for: student)
                    }

                    modelSelectionSection

                    planTitleSection

                    if !interests.isEmpty {
                        interestSelectionSection
                    }

                    notesSection

                    if let errorMessage {
                        errorMessageView(errorMessage)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }

            bottomActionBar
        }
        .navigationTitle("Create TMI Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            if let student = preselectedStudent {
                await loadInterests(for: student)
            }
        }
        .onAppear {
            if let student = preselectedStudent {
                let suggested = suggestedModel(interestCount: interestCount)
                selectedModel = suggested
                planTitle = "\(suggested.rawValue) - \(student.name)"
            }
        }
    }

    // MARK: - Edit Mode Body

    private var editBody: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    editHeaderSection
                    editBasicDetailsSection
                    if let plan = existingPlan { editPlanInfoSection(plan: plan) }
                    editTimelineSection
                    editNotesSection
                    editInterestsSection
                }
                .padding(20)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Edit Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: savePlan) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save").fontWeight(.semibold)
                    }
                }
                .foregroundColor(.tmiSecondary)
                .disabled(isSaving)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Create Mode Sections

    private var createHeaderSection: some View {
        VStack(spacing: 8) {
            Text("Create TMI Plan")
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let student = preselectedStudent {
                Text("Design an intervention plan for \(student.name)")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, TMISpacing.lg)
    }

    private func studentInfoCard(student: Student) -> some View {
        HStack(spacing: TMISpacing.md) {
            TMIAvatar(initials: student.initials, color: .tmiPrimary, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(student.name)
                    .font(.tmiLabelLarge)
                    .foregroundColor(.tmiTextPrimary)

                Text("Grade \(student.grade) • \(interestCount) interests")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()
        }
        .padding(TMISpacing.md)
        .tmiCard(style: .outlined)
    }

    private func suggestedModelCard(for student: Student) -> some View {
        let suggested = suggestedModel(interestCount: interestCount)
        let suggestedColor = colorForModel(suggested)
        let suggestedIcon = iconForModel(suggested)

        return VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                ZStack {
                    Circle()
                        .fill(suggestedColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: suggestedIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(suggestedColor)
                }

                Text("Suggested Model")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                Image(systemName: "sparkles")
                    .foregroundColor(suggestedColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(suggested.rawValue)
                    .font(.tmiLabelLarge)
                    .foregroundColor(suggestedColor)

                Text(suggested.description)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selectedModel != suggested {
                TMIButton(
                    text: "Use Suggested Model",
                    icon: "checkmark.circle",
                    style: .secondary,
                    action: {
                        selectedModel = suggested
                        planTitle = "\(suggested.rawValue) - \(student.name)"
                    }
                )
            }
        }
        .padding(TMISpacing.md)
        .background(suggestedColor.opacity(0.1))
        .cornerRadius(TMIRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .stroke(suggestedColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Select TMI Model")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            VStack(spacing: TMISpacing.sm) {
                ForEach(TMIPlanModel.allCases, id: \.self) { model in
                    modelOption(model)
                }
            }
        }
    }

    private func modelOption(_ model: TMIPlanModel) -> some View {
        let modelColor = colorForModel(model)
        let modelIcon = iconForModel(model)
        let isSelected = selectedModel == model

        return Button(action: {
            selectedModel = model
            if let student = preselectedStudent {
                planTitle = "\(model.rawValue) - \(student.name)"
            }
        }) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(modelColor.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: modelIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(modelColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.rawValue)
                        .font(.tmiLabelLarge)
                        .foregroundColor(.tmiTextPrimary)

                    Text(model.description)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? modelColor : .tmiTextTertiary)
            }
            .padding(TMISpacing.md)
            .background(isSelected ? modelColor.opacity(0.1) : Color.tmiSurface)
            .cornerRadius(TMIRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.sm)
                    .stroke(isSelected ? modelColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var planTitleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan Title")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)

            TextField("", text: $planTitle, prompt: Text("Enter plan title").foregroundColor(.tmiTextTertiary))
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)
                .padding(TMISpacing.md)
                .background(Color.tmiSurface)
                .cornerRadius(TMIRadius.sm)
        }
    }

    private var interestSelectionSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Related Interests")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Text("Select interests this plan will address")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TMISpacing.sm) {
                    ForEach(interests, id: \.id) { interest in
                        interestChip(interest)
                    }
                }
            }
        }
    }

    private func interestChip(_ interest: Interest) -> some View {
        Button(action: {
            if selectedInterests.contains(interest) {
                selectedInterests.remove(interest)
            } else {
                selectedInterests.insert(interest)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: selectedInterests.contains(interest) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))

                Text(interest.name)
                    .font(.tmiCaption)
            }
            .foregroundColor(selectedInterests.contains(interest) ? .white : .tmiTextPrimary)
            .padding(.horizontal, TMISpacing.md)
            .padding(.vertical, TMISpacing.sm)
            .background(selectedInterests.contains(interest) ? Color.tmiPrimary : Color.tmiSurface)
            .cornerRadius(TMIRadius.pill)
        }
        .buttonStyle(.plain)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)

            TextEditor(text: $notes)
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)
                .frame(height: 100)
                .padding(TMISpacing.sm)
                .background(Color.tmiSurface)
                .cornerRadius(TMIRadius.sm)
        }
    }

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .font(.tmiCaption)
            .foregroundColor(.tmiError)
            .padding(TMISpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tmiError.opacity(0.1))
            .cornerRadius(TMIRadius.sm)
    }

    private var bottomActionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: TMISpacing.md) {
                TMIButton(text: "Cancel", style: .secondary, action: { dismiss() })

                TMIButton(
                    text: "Create Plan",
                    icon: "checkmark",
                    style: .primary,
                    isLoading: isSaving,
                    isDisabled: !isCreateValid,
                    action: createPlan
                )
            }
            .padding(TMISpacing.md)
            .background(
                Color.tmiBackground
                    .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
            )
        }
    }

    private var isCreateValid: Bool {
        selectedModel != nil &&
        !planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        preselectedStudent?.id != nil
    }

    // MARK: - Edit Mode Sections

    private var editHeaderSection: some View {
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
    }

    private var editBasicDetailsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Basic Details")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Title")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Enter plan title", text: $planTitle)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Enter description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func editPlanInfoSection(plan: TMIPlan) -> some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plan Information")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Model:")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(plan.model.rawValue)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Student:")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(plan.primaryStudent?.name ?? "No student assigned")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }

    private var editTimelineSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Timeline")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    HStack {
                        Text("Start Date")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }

                    HStack {
                        Text("Target End Date")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                }
            }
        }
    }

    private var editNotesSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Collaboration Log")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add New Entry")
                        .font(.caption)
                        .foregroundColor(.tmiSecondary)
                        .fontWeight(.semibold)

                    TextEditor(text: $newNoteEntry)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    Text("This will be appended to the log with today's date.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 8) {
                    Text("History")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    ScrollView {
                        Text(notes.isEmpty ? "No notes yet." : notes)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }

    private var editInterestsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Associated Interests")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(Interest.expandedSampleInterests) { interest in
                        InterestToggleCard(
                            interest: interest,
                            isSelected: editSelectedInterests.contains(interest),
                            onToggle: { toggleEditInterest(interest) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInterests(for student: Student) async {
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
            interestCount = try await student.getInterestCount()
            // Update suggested model and title now that we have interest count
            let suggested = suggestedModel(interestCount: interestCount)
            if selectedModel == nil {
                selectedModel = suggested
            }
            if planTitle.isEmpty {
                planTitle = "\(suggested.rawValue) - \(student.name)"
            }
        } catch {
            print("[TMIPlanEditorView] Error loading interests: \(error.localizedDescription)")
            interests = []
            interestCount = 0
        }
    }

    // MARK: - Helpers

    private func suggestedModel(interestCount: Int) -> TMIPlanModel {
        if interestCount >= 5 {
            return .chaseYourSpace
        } else if interestCount >= 2 {
            return .acknowledgeInterests
        } else {
            return .alignYourMind
        }
    }

    private func colorForModel(_ model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }

    private func iconForModel(_ model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: return "airplane.departure"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.lefthalf.filled"
        }
    }

    private func toggleEditInterest(_ interest: Interest) {
        if let index = editSelectedInterests.firstIndex(where: { $0.id == interest.id }) {
            editSelectedInterests.remove(at: index)
        } else {
            editSelectedInterests.append(interest)
        }
    }

    // MARK: - Actions

    private func createPlan() {
        guard isCreateValid, let selectedModel, let student = preselectedStudent else { return }

        Task {
            isSaving = true
            errorMessage = nil

            do {
                let plan = TMIPlan(
                    title: planTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: selectedModel.description,
                    students: [student],
                    model: selectedModel,
                    interests: Array(selectedInterests),
                    startDate: Date(),
                    endDate: nil,
                    creationDate: Date(),
                    lastUpdated: Date(),
                    goals: [],
                    progress: 0.0,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdBy: Auth.auth().currentUser?.uid ?? "",
                    latestInterestSurveyId: student.surveyResults?
                        .filter { $0.isComplete && $0.surveyName.contains("Interest") }
                        .sorted { $0.date > $1.date }
                        .first?.id,
                    interestIdsSnapshot: interests.compactMap { $0.id },
                    snapshotUpdatedAt: Date()
                )

                try await tmiPlanService.addPlan(plan)

                await MainActor.run {
                    onPlanCreated?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create plan: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func savePlan() {
        guard var updatedPlan = existingPlan else { return }
        isSaving = true

        updatedPlan.title = planTitle
        updatedPlan.description = description
        updatedPlan.interests = editSelectedInterests
        updatedPlan.startDate = startDate
        updatedPlan.endDate = endDate
        updatedPlan.lastUpdated = Date()

        if !newNoteEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let timestamp = formatter.string(from: Date())
            updatedPlan.notes = notes + "\n\n--- Entry: \(timestamp) ---\n\(newNoteEntry)"
        } else {
            updatedPlan.notes = notes
        }

        Task {
            do {
                let savedPlan = try await TMIPlanService.shared.updatePlan(updatedPlan)

                await MainActor.run {
                    onSave?(savedPlan)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Create Mode") {
    NavigationStack {
        TMIPlanEditorView(preselectedStudent: Student.sampleStudent)
    }
}

#Preview("Edit Mode") {
    NavigationStack {
        TMIPlanEditorView(existingPlan: TMIPlan.samplePlan)
    }
}
