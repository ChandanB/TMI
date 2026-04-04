//
//  StudentSurveyFlow.swift
//  TMI
//
//  Main survey flow - the foundation of the TMI experience
//

import SwiftUI

/// Context for survey completion - determines post-survey actions
enum SurveyContext {
    case studentDetail
    case planDetail(planId: String)
}

struct StudentSurveyFlow: View {
    let studentId: String
    var context: SurveyContext = .studentDetail
    var showCancelButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var currentStepIndex = 0
    @State private var responses: [String: SurveyResponse.SurveyAnswerValue] = [:]
    @State private var showingResults = false
    @State private var surveyStartTime = Date()

    // Response tracking for each step type
    @State private var selectedMultiOptions: Set<String> = []
    @State private var selectedSingleOption: String? = nil
    @State private var selectedScale: Int? = nil
    @State private var openEndedText = ""
    @State private var dreamJobText = ""

    let steps = SurveyConfiguration.steps

    var currentStep: SurveyStep {
        steps[currentStepIndex]
    }

    var canProceed: Bool {
        guard currentStep.isRequired else { return true }

        switch currentStep.type {
        case .intro:
            return true
        case .multiSelect:
            return !selectedMultiOptions.isEmpty
        case .singleSelect:
            return selectedSingleOption != nil
        case .scale:
            return selectedScale != nil
        case .openEnded:
            return !openEndedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dreamJob:
            return !dreamJobText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var progressPercentage: Double {
        Double(currentStepIndex) / Double(steps.count)
    }

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            if showingResults {
                SurveyResultsView(
                    studentId: studentId,
                    responses: responses,
                    surveyDuration: Date().timeIntervalSince(surveyStartTime),
                    context: context,
                    onDismiss: {
                        // Dismiss the entire survey modal
                        dismiss()
                    }
                )
            } else {
                VStack(spacing: 0) {
                    // Progress bar
                    progressBar

                    // Content
                    ScrollView {
                        VStack {
                            currentStepView
                                .padding(.top, TMISpacing.lg)
                                .padding(.bottom, 100) // Space for nav buttons
                        }
                    }

                    // Navigation buttons
                    navigationButtons
                }
            }
        }
        .navigationTitle("Interest Survey")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(currentStepIndex > 0)
        .toolbar {
            if showCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 0) {
            // Progress percentage text
            HStack {
                Text("Question \(currentStepIndex + 1) of \(steps.count)")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                Spacer()
                Text("\(Int(progressPercentage * 100))%")
                    .font(.tmiCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.tmiPrimary)
            }
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.top, TMISpacing.sm)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.tmiSurface)
                        .frame(height: 4)

                    // Progress
                    Rectangle()
                        .fill(Color.tmiPrimary)
                        .frame(width: geometry.size.width * progressPercentage, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, TMISpacing.sm)
        }
    }

    // MARK: - Current Step View

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep.type {
        case .intro:
            IntroStepView(step: currentStep)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        case .multiSelect:
            MultiSelectStepView(step: currentStep, selectedOptions: $selectedMultiOptions)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        case .singleSelect:
            SingleSelectStepView(step: currentStep, selectedOption: $selectedSingleOption)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        case .scale:
            ScaleStepView(step: currentStep, selectedScale: $selectedScale)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        case .openEnded:
            OpenEndedStepView(step: currentStep, text: $openEndedText)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        case .dreamJob:
            DreamJobStepView(step: currentStep, dreamJob: $dreamJobText)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: TMISpacing.md) {
            // Back button
            if currentStepIndex > 0 {
                Button(action: goBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.tmiBody)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.tmiTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TMISpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TMIRadius.md)
                            .fill(Color.tmiSurface)
                    )
                }
                .buttonStyle(.plain)
            }

            // Next/Finish button
            Button(action: goNext) {
                HStack {
                    Text(currentStepIndex == steps.count - 1 ? "Finish" : "Next")
                        .font(.tmiBody)
                        .fontWeight(.semibold)
                    if currentStepIndex < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(Color.tmiTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .fill(canProceed ? Color.tmiPrimary : Color.tmiTextTertiary)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canProceed)
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.vertical, TMISpacing.md)
        .background(
            Color.tmiBackground
                .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        )
    }

    // MARK: - Navigation Logic

    private func goBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // Save current response before going back
            saveCurrentResponse()

            currentStepIndex -= 1

            // Load previous step's response
            loadResponseForCurrentStep()
        }
        TMIHaptics.lightImpact()
    }

    private func goNext() {
        // Save current response
        saveCurrentResponse()

        if currentStepIndex == steps.count - 1 {
            // Finish survey
            finishSurvey()
        } else {
            // Go to next step
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentStepIndex += 1

                // Clear selections for new step
                clearSelectionsForCurrentStep()

                // Load saved response if exists
                loadResponseForCurrentStep()
            }
            TMIHaptics.lightImpact()
        }
    }

    private func saveCurrentResponse() {
        let stepId = currentStep.id

        switch currentStep.type {
        case .intro:
            break // No response to save
        case .multiSelect:
            responses[stepId] = .options(Array(selectedMultiOptions))
        case .singleSelect:
            if let option = selectedSingleOption {
                responses[stepId] = .options([option])
            }
        case .scale:
            if let scale = selectedScale {
                responses[stepId] = .scale(scale)
            }
        case .openEnded:
            responses[stepId] = .text(openEndedText)
        case .dreamJob:
            responses[stepId] = .text(dreamJobText)
        }
    }

    private func loadResponseForCurrentStep() {
        let stepId = currentStep.id

        guard let response = responses[stepId] else { return }

        switch response {
        case .options(let options):
            if currentStep.type == .multiSelect {
                selectedMultiOptions = Set(options)
            } else if currentStep.type == .singleSelect {
                selectedSingleOption = options.first
            }
        case .scale(let value):
            selectedScale = value
        case .text(let text):
            if currentStep.type == .openEnded {
                openEndedText = text
            } else if currentStep.type == .dreamJob {
                dreamJobText = text
            }
        }
    }

    private func clearSelectionsForCurrentStep() {
        selectedMultiOptions.removeAll()
        selectedSingleOption = nil
        selectedScale = nil
        openEndedText = ""
        dreamJobText = ""
    }

    private func finishSurvey() {
        TMIHaptics.mediumImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingResults = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StudentSurveyFlow(studentId: "preview-student-id")
    }
}
