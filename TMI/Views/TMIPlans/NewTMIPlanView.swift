//
//  NewTMIPlanView.swift
//  TMI
//
//  Streamlined TMI plan creation with smart suggestions
//

import SwiftUI

struct NewTMIPlanView: View {
    @Environment(\.dismiss) private var dismiss
    let student: Student
    let onPlanCreated: (() -> Void)?

    @State private var selectedModel: TMIPlanModel?
    @State private var planTitle = ""
    @State private var selectedInterests: Set<Interest> = []
    @State private var notes = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var interests: [Interest] = []
    @State private var interestCount: Int = 0

    private let tmiPlanService = TMIPlanService.shared

    init(student: Student, onPlanCreated: (() -> Void)? = nil) {
        self.student = student
        self.onPlanCreated = onPlanCreated
    }

    var suggestedModel: TMIPlanModel {
        // Smart suggestion based on student data
        if interestCount >= 5 {
            return .chaseYourSpace
        } else if interestCount >= 2 {
            return .acknowledgeInterests
        } else {
            return .alignYourMind
        }
    }

    var isValid: Bool {
        selectedModel != nil &&
        !planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .plans)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    // Header
                    headerSection

                    // Student Info
                    studentInfoCard

                    // Smart Model Suggestion
                    suggestedModelCard

                    // Model Selection
                    modelSelectionSection

                    // Plan Title
                    planTitleSection

                    // Interest Selection
                    if !interests.isEmpty {
                        interestSelectionSection
                    }

                    // Notes (Optional)
                    notesSection

                    // Error Message
                    if let errorMessage = errorMessage {
                        errorMessageView(errorMessage)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }

            // Bottom Action Bar
            bottomActionBar
        }
        .navigationTitle("Create TMI Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            await loadInterests()
        }
        .onAppear {
            // Pre-populate with suggested model
            selectedModel = suggestedModel
            planTitle = "\(suggestedModel.rawValue) - \(student.name)"
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInterests() async {
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
            interestCount = try await student.getInterestCount()
        } catch {
            print("[NewTMIPlanView] Error loading interests: \(error.localizedDescription)")
            interests = []
            interestCount = 0
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Create TMI Plan")
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            Text("Design an intervention plan for \(student.name)")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, TMISpacing.lg)
    }

    // MARK: - Student Info Card

    private var studentInfoCard: some View {
        HStack(spacing: TMISpacing.md) {
            TMIAvatar(
                initials: student.initials,
                color: .tmiPrimary,
                size: 48
            )

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

    // MARK: - Suggested Model

    private var suggestedModelCard: some View {
        let suggestedColor = colorForModel(suggestedModel)
        let suggestedIcon = iconForModel(suggestedModel)

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
                Text(suggestedModel.rawValue)
                    .font(.tmiLabelLarge)
                    .foregroundColor(suggestedColor)

                Text(suggestedModel.description)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selectedModel != suggestedModel {
                TMIButton(
                    text: "Use Suggested Model",
                    icon: "checkmark.circle",
                    style: .secondary,
                    action: {
                        selectedModel = suggestedModel
                        planTitle = "\(suggestedModel.rawValue) - \(student.name)"
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

    // MARK: - Model Selection

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
            planTitle = "\(model.rawValue) - \(student.name)"
        }) {
            HStack(spacing: TMISpacing.md) {
                // Model Icon with color
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

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? modelColor : .tmiTextTertiary)
            }
            .padding(TMISpacing.md)
            .background(isSelected ? modelColor.opacity(0.1) : Color.tmiSurface)
            .cornerRadius(TMIRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.sm)
                    .stroke(
                        isSelected ? modelColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Title

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

    // MARK: - Interest Selection

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

    // MARK: - Notes

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

    // MARK: - Error Message

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .font(.tmiCaption)
            .foregroundColor(.tmiError)
            .padding(TMISpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tmiError.opacity(0.1))
            .cornerRadius(TMIRadius.sm)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: TMISpacing.md) {
                TMIButton(
                    text: "Cancel",
                    style: .secondary,
                    action: { dismiss() }
                )

                TMIButton(
                    text: "Create Plan",
                    icon: "checkmark",
                    style: .primary,
                    isLoading: isSaving,
                    isDisabled: !isValid,
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

    // MARK: - Helper Methods

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

    // MARK: - Create Plan

    private func createPlan() {
        guard isValid, let selectedModel = selectedModel else { return }

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
                    createdBy: "current_user" // TODO: Get from auth
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
}

#Preview {
    NavigationStack {
        NewTMIPlanView(student: Student.sampleStudent)
    }
}
