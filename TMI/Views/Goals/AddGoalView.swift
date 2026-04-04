//
//  AddGoalView.swift
//  TMI
//
//  View for adding a new goal to a TMI Plan
//

import SwiftUI

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
            TMIBackgroundView(variant: .base)
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
                            .foregroundColor(Color.tmiTextPrimary)

                        Text("Set a specific, measurable goal for this TMI plan")
                            .font(.system(size: 16))
                            .foregroundColor(Color.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Goal Description
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goal Description *")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            TextEditor(text: $goalDescription)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(Color.tmiTextPrimary)
                                .font(.system(size: 16))
                                .cornerRadius(8)
                                .overlay(
                                    goalDescription.isEmpty ?
                                    VStack {
                                        HStack {
                                            Text("e.g., Increase on-task behavior to 80% during independent work")
                                                .foregroundColor(Color.tmiTextTertiary)
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
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Status")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            HStack(spacing: 12) {
                                ForEach(GoalStatus.allCases, id: \.self) { status in
                                    Button(action: {
                                        selectedStatus = status
                                    }) {
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

                    // Due Date
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $hasDueDate) {
                                Text("Set Due Date")
                                    .font(.headline)
                                    .foregroundColor(Color.tmiTextPrimary)
                            }
                            .tint(modelColor)

                            if hasDueDate {
                                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                                    .foregroundColor(Color.tmiTextPrimary)
                                    .tint(modelColor)
                            }
                        }
                    }

                    // Notes
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notes (Optional)")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(Color.tmiTextPrimary)
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
                        .fill(Color.tmiSurface)
                        .opacity(0.5)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
                )
            }
        }
        .padding(.horizontal)
        .navigationTitle("Add Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color.tmiTextPrimary)
            }
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
