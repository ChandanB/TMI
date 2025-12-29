//
//  InterestSurveyView.swift
//  TMI
//
//  View for conducting an interest survey within a TMI Plan
//  Uses global interest library and student interest edges
//

import SwiftUI

struct InterestSurveyView: View {
    let plan: TMIPlan
    let studentId: String  // Required for saving student interest edges
    let onComplete: ([Interest]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedInterestLevels: [String: Int] = [:]  // interestId: level
    @State private var allInterests: [Interest] = []
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let interestLibraryService = InterestLibraryService.shared
    private let studentInterestService = StudentInterestService.shared

    // Survey steps with category filters
    private let steps: [(title: String, categories: [InterestCategory])] = [
        ("What subjects do you enjoy most?", [.academics, .mathematics, .science]),
        ("What do you like to do in your free time?", [.arts, .music, .sports, .gaming, .outdoors]),
        ("What kind of careers sound interesting?", [.technology, .leadership, .socialCauses]),
        ("What skills would you like to learn?", [.communication, .learning, .crafts])
    ]
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading interests...")
                    .tint(.tmiPrimary)
                    .foregroundColor(.white)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadInterests()
                        }
                    }
                    .padding()
                    .background(Color.tmiPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            } else {
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
        .task {
            await loadInterests()
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
            Text(steps[currentStep].title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Tap to rate your interest level (1-5)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var optionsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            ForEach(getInterestsForCurrentStep(), id: \.id) { interest in
                InterestRatingCard(
                    interest: interest,
                    currentLevel: selectedInterestLevels[interest.id ?? ""] ?? 0,
                    onTap: { level in
                        if let id = interest.id {
                            if level == selectedInterestLevels[id] {
                                selectedInterestLevels.removeValue(forKey: id)
                            } else {
                                selectedInterestLevels[id] = level
                            }
                        }
                    }
                )
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

    /// Load interests from global library
    @MainActor
    private func loadInterests() async {
        isLoading = true
        errorMessage = nil

        do {
            allInterests = try await interestLibraryService.fetchAllInterests()
            print("[InterestSurveyView] Loaded \(allInterests.count) interests from library")
        } catch {
            errorMessage = "Failed to load interests: \(error.localizedDescription)"
            print("[InterestSurveyView] Error: \(errorMessage ?? "")")
        }

        isLoading = false
    }

    /// Get interests filtered by current step's categories
    private func getInterestsForCurrentStep() -> [Interest] {
        let currentCategories = steps[currentStep].categories
        return allInterests.filter { interest in
            !Set(interest.category).isDisjoint(with: Set(currentCategories))
        }
        .sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }
        .prefix(12)  // Limit to 12 interests per step
        .map { $0 }
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            Task {
                await finishSurvey()
            }
        }
    }

    @MainActor
    private func finishSurvey() async {
        isSaving = true

        do {
            // Save to student interest edges
            try await studentInterestService.saveSurveyResults(
                studentId: studentId,
                results: selectedInterestLevels
            )

            // Resolve selected interests for callback
            let selectedInterests = allInterests.filter { interest in
                guard let id = interest.id else { return false }
                return selectedInterestLevels[id] != nil
            }

            print("[InterestSurveyView] Survey complete: \(selectedInterests.count) interests saved")

            // Call completion handler
            onComplete(selectedInterests)
            dismiss()
        } catch {
            errorMessage = "Failed to save survey results: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

// MARK: - Interest Rating Card

private struct InterestRatingCard: View {
    let interest: Interest
    let currentLevel: Int
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: interest.iconName)
                .font(.system(size: 32))
                .foregroundColor(currentLevel > 0 ? .white : .tmiPrimary)

            Text(interest.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Rating stars
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: { onTap(level) }) {
                        Image(systemName: level <= currentLevel ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(level <= currentLevel ? .yellow : .white.opacity(0.3))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentLevel > 0 ? Color.tmiPrimary.opacity(0.8) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(currentLevel > 0 ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
