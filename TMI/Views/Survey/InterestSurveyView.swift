//
//  InterestSurveyView.swift
//  TMI
//
//  View for conducting an interest survey within a TMI Plan
//

import SwiftUI

struct InterestSurveyView: View {
    let plan: TMIPlan
    let onComplete: ([Interest]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedInterests: [Interest] = []
    @State private var isSaving = false
    
    // Mock data for survey steps
    private let steps = [
        "What subjects do you enjoy most?",
        "What do you like to do in your free time?",
        "What kind of careers sound interesting?",
        "What skills would you like to learn?"
    ]
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                progressBar
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        
                        optionsGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
                
                // Footer
                footerSection
            }
        }
        .navigationTitle("Interest Survey")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    
    private var progressBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Step \(currentStep + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int((Double(currentStep + 1) / Double(steps.count)) * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.tmiPrimary)
                        .frame(width: geometry.size.width * (Double(currentStep + 1) / Double(steps.count)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .background(Color.black.opacity(0.2))
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(steps[currentStep])
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var optionsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            // Mock options based on step
            ForEach(getOptionsForStep(currentStep), id: \.self) { option in
                Button(action: { toggleSelection(option) }) {
                    VStack(spacing: 12) {
                        Image(systemName: getIconForOption(option))
                            .font(.system(size: 32))
                            .foregroundColor(isSelected(option) ? .white : .tmiPrimary)
                        
                        Text(option)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected(option) ? .white : .white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected(option) ? Color.tmiPrimary : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected(option) ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button(action: { withAnimation { currentStep -= 1 } }) {
                        Text("Back")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                Button(action: nextStep) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .cornerRadius(12)
                    } else {
                        Text(currentStep == steps.count - 1 ? "Complete" : "Next")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tmiPrimary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.tmiBackground)
    }
    
    // MARK: - Logic
    
    private func getOptionsForStep(_ step: Int) -> [String] {
        switch step {
        case 0: return ["Math", "Science", "Art", "History", "Music", "PE"]
        case 1: return ["Video Games", "Sports", "Reading", "Drawing", "Coding", "Cooking"]
        case 2: return ["Engineer", "Artist", "Doctor", "Teacher", "Athlete", "Developer"]
        case 3: return ["Leadership", "Creativity", "Teamwork", "Problem Solving", "Communication"]
        default: return []
        }
    }
    
    private func getIconForOption(_ option: String) -> String {
        // Simple mapping for demo
        switch option {
        case "Math": return "x.squareroot"
        case "Science": return "flask.fill"
        case "Art": return "paintbrush.fill"
        case "Video Games": return "gamecontroller.fill"
        case "Sports": return "sportscourt.fill"
        case "Coding": return "laptopcomputer"
        default: return "star.fill"
        }
    }
    
    private func isSelected(_ option: String) -> Bool {
        // In a real app, we'd track selection per step.
        // For this mock, we'll just check if we've created an interest with this name
        return selectedInterests.contains { $0.name == option }
    }
    
    private func toggleSelection(_ option: String) {
        if let index = selectedInterests.firstIndex(where: { $0.name == option }) {
            selectedInterests.remove(at: index)
        } else {
            // Create a mock interest object
            let interest = Interest(
                id: UUID().uuidString,
                name: option,
                category: categoriesForOption(option),
                description: "Selected from survey",
                academicRelevance: [],
                interventionModels: [],
                popularityScore: 80,
                isFeatured: false,
                createdAt: Date()
            )
            selectedInterests.append(interest)
        }
    }
    
    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            finishSurvey()
        }
    }
    
    private func categoriesForOption(_ option: String) -> [InterestCategory] {
        switch option {
        // Step 0: Subjects
        case "Math": return [.mathematics]
        case "Science": return [.science]
        case "Art": return [.arts]
        case "History": return [.academics]
        case "Music": return [.music]
        case "PE": return [.sports]
        
        // Step 1: Free time
        case "Video Games": return [.gaming]
        case "Sports": return [.sports]
        case "Reading": return [.literature]
        case "Drawing": return [.arts]
        case "Coding": return [.technology]
        case "Cooking": return [.cooking]
        
        // Step 2: Careers
        case "Engineer": return [.technology, .science]
        case "Artist": return [.arts]
        case "Doctor": return [.science]
        case "Teacher": return [.academics]
        case "Athlete": return [.sports]
        case "Developer": return [.technology]
        
        // Step 3: Skills to learn
        case "Leadership": return [.leadership]
        case "Creativity": return [.arts]
        case "Teamwork": return [.social]
        case "Problem Solving": return [.academics]
        case "Communication": return [.communication]
        
        default: return [.other]
        }
    }
    
    private func finishSurvey() {
        isSaving = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete(selectedInterests)
            dismiss()
        }
    }
}
