//
//  EditTMIPlanView.swift
//  TMI
//
//  View for editing an existing TMI Plan
//

import SwiftUI

struct EditTMIPlanView: View {
    let plan: TMIPlan
    let onSave: (TMIPlan) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Form Fields
    @State private var title: String
    @State private var description: String
    @State private var notes: String
    @State private var newNoteEntry: String = ""
    @State private var selectedInterests: [Interest]
    @State private var startDate: Date
    @State private var endDate: Date
    
    // UI State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    init(plan: TMIPlan, onSave: @escaping (TMIPlan) -> Void) {
        self.plan = plan
        self.onSave = onSave
        
        _title = State(initialValue: plan.title)
        _description = State(initialValue: plan.description ?? "")
        _notes = State(initialValue: plan.notes)
        _selectedInterests = State(initialValue: plan.interests)
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate ?? Date().addingTimeInterval(86400 * 30)) // Default to 30 days if nil
    }
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Basic Details
                    basicDetailsSection
                    
                    // Plan Info (Read-only)
                    planInfoSection
                    
                    // Timeline
                    timelineSection
                    
                    // Notes
                    notesSection
                    
                    // Interests
                    interestsSection
                }
                .padding(20)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Edit Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: savePlan) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.tmiSecondary)
                .disabled(isSaving)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
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
    
    private var basicDetailsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Basic Details")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Title")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Enter plan title", text: $title)
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
    
    private var planInfoSection: some View {
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
    
    private var timelineSection: some View {
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
    
    private var notesSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Collaboration Log")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                
                // New Entry
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
                
                // Existing Log
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
    
    private var interestsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Associated Interests")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
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
    
    // MARK: - Actions
    
    private func toggleInterest(_ interest: Interest) {
        if let index = selectedInterests.firstIndex(where: { $0.id == interest.id }) {
            selectedInterests.remove(at: index)
        } else {
            selectedInterests.append(interest)
        }
    }
    
    private func savePlan() {
        isSaving = true
        
        var updatedPlan = plan
        updatedPlan.title = title
        updatedPlan.description = description
        updatedPlan.interests = selectedInterests
        updatedPlan.startDate = startDate
        updatedPlan.endDate = endDate
        updatedPlan.lastUpdated = Date()
        
        // Append new note if present
        if !newNoteEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            let timestamp = dateFormatter.string(from: Date())
            
            let newEntry = "\n\n--- Entry: \(timestamp) ---\n\(newNoteEntry)"
            updatedPlan.notes = notes + newEntry
        } else {
            updatedPlan.notes = notes
        }
        
        Task {
            do {
                let savedPlan = try await TMIPlanService.shared.updatePlan(updatedPlan)
                
                await MainActor.run {
                    onSave(savedPlan)
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
