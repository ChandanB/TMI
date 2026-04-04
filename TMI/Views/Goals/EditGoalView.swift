//
//  EditGoalView.swift
//  TMI
//
//  View for editing an existing goal in a TMI Plan
//

import SwiftUI

struct EditGoalView: View {
    let plan: TMIPlan
    let goal: Goal
    let onSave: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss

    // State derived from real Goal model
    @State private var goalDescription: String
    @State private var selectedStatus: GoalStatus
    @State private var goalProgress: Double
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var notes: String

    @State private var isSaving = false

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
            TMIBackgroundView(variant: .plans)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Progress
                    progressSection

                    // Description
                    descriptionSection

                    // Status
                    statusSection

                    // Due date
                    dueDateSection

                    // Notes
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: saveGoal) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(modelColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "target")
                    .font(.system(size: 28))
                    .foregroundColor(modelColor)
            }

            Text("Edit Goal")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Progress")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)

            VStack(spacing: 12) {
                HStack {
                    Text("Progress")
                        .foregroundColor(Color.tmiTextSecondary)
                    Spacer()
                    Text("\(Int(goalProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(modelColor)
                }

                Slider(value: $goalProgress, in: 0...1)
                    .tint(modelColor)

                HStack {
                    Text("0%")
                    Spacer()
                    Text("100%")
                }
                .font(.caption)
                .foregroundColor(Color.tmiTextSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Details")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextSecondary)
                    .padding(.leading, 4)

                TextEditor(text: $goalDescription)
                    .frame(height: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(Color.tmiTextPrimary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)

            HStack(spacing: 12) {
                ForEach(GoalStatus.allCases, id: \.self) { status in
                    Button(action: { selectedStatus = status }) {
                        Text(status.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedStatus == status ? modelColor : Color.tmiTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedStatus == status ? modelColor.opacity(0.1) : Color.tmiInputBackground)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedStatus == status ? modelColor : Color.tmiBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $hasDueDate) {
                Text("Set Due Date")
                    .font(.headline)
                    .foregroundColor(Color.tmiTextPrimary)
            }
            .tint(modelColor)

            if hasDueDate {
                HStack {
                    Text("Target Date")
                        .foregroundColor(Color.tmiTextPrimary)
                    Spacer()
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)

            TextEditor(text: $notes)
                .frame(height: 80)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(Color.tmiTextPrimary)
        }
    }

    // MARK: - Actions

    private func saveGoal() {
        isSaving = true
        let updatedGoal = Goal(
            id: goal.id,
            description: goalDescription,
            dueDate: hasDueDate ? dueDate : nil,
            status: selectedStatus,
            progress: goalProgress,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )

        // Simulate a small delay to match UX elsewhere
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSave(updatedGoal)
            dismiss()
        }
    }

    // MARK: - Helpers

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
}
