//
//  SurveyResultsView.swift
//  TMI
//
//  Survey results with interest clustering and career preview
//

import SwiftUI

struct SurveyResultsView: View {
    let studentId: String
    let responses: [String: SurveyResponse.SurveyAnswerValue]
    let surveyDuration: TimeInterval
    var context: SurveyContext = .studentDetail
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = false
    @State private var analyzedClusters: [InterestCluster] = []
    @State private var topInterests: [String] = []
    @State private var careerMatches: [CareerMatchResult] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingCareerExploration = false
    @State private var showingAddInterests = false
    @State private var currentStudent: Student?

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // Header
                    celebrationHeader
                        .padding(.top, TMISpacing.xl)

                    // Interest Clusters
                    if !analyzedClusters.isEmpty {
                        interestClustersSection
                    }

                    // Top Interests
                    if !topInterests.isEmpty {
                        topInterestsSection
                    }

                    // Next Steps
                    nextStepsSection
                        .padding(.bottom, TMISpacing.xl)
                }
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            analyzeSurveyResponses()
            saveSurveyToFirebase()
            // Trigger confetti after slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
                TMIHaptics.mediumImpact()
            }
            // Stop confetti after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
                showConfetti = false
            }
        }
    }

    // MARK: - Header

    private var celebrationHeader: some View {
        VStack(spacing: TMISpacing.lg) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.tmiSuccess.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.tmiSuccess)
                    .symbolEffect(.bounce, value: showConfetti)
            }

            // Title
            Text("You did it!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.tmiTextPrimary)

            // Subtitle
            VStack(spacing: TMISpacing.xs) {
                Text("Survey completed in \(formatDuration(surveyDuration))")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)

                Text("Now let's explore what you could become")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
    }

    // MARK: - Interest Clusters

    private var interestClustersSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Your Interest Profile")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)
                .padding(.horizontal, TMISpacing.screenPadding)

            VStack(spacing: TMISpacing.md) {
                ForEach(analyzedClusters.prefix(3)) { cluster in
                    interestClusterCard(cluster)
                }
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
    }

    private func interestClusterCard(_ cluster: InterestCluster) -> some View {
        HStack(spacing: TMISpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: cluster.color).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: cluster.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: cluster.color))
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.displayName)
                    .font(.tmiBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.tmiTextPrimary)

                Text("\(Int(cluster.weight * 100))% match")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.tmiSurface)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: cluster.color))
                        .frame(width: geometry.size.width * cluster.weight, height: 8)
                }
            }
            .frame(width: 80)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }

    // MARK: - Top Interests

    private var topInterestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("You're interested in")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)
                .padding(.horizontal, TMISpacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TMISpacing.sm) {
                    ForEach(topInterests, id: \.self) { interest in
                        interestChip(interest)
                    }
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }
        }
    }

    private func interestChip(_ interest: String) -> some View {
        Text(interest)
            .font(.tmiCaption)
            .fontWeight(.medium)
            .foregroundColor(.tmiPrimary)
            .padding(.horizontal, TMISpacing.md)
            .padding(.vertical, TMISpacing.sm)
            .background(
                Capsule()
                    .fill(Color.tmiPrimary.opacity(0.1))
            )
    }

    // MARK: - Next Steps

    private var nextStepsSection: some View {
        VStack(spacing: TMISpacing.lg) {
            VStack(spacing: TMISpacing.md) {
                Text("What's Next?")
                    .font(.tmiTitle2)
                    .foregroundColor(.tmiTextPrimary)

                Text("We'll use your responses to suggest careers and create your personalized plan")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TMISpacing.xl)
            }

            // Action buttons
            VStack(spacing: TMISpacing.md) {
                if !careerMatches.isEmpty {
                    Button(action: {
                        showingCareerExploration = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Explore \(careerMatches.count) Career Matches")
                                .fontWeight(.semibold)
                        }
                        .font(.tmiBody)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.md)
                                .fill(Color.tmiPrimary)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingCareerExploration) {
                        NavigationStack {
                            CareerExplorationView(
                                studentId: studentId,
                                careerMatches: careerMatches
                            )
                        }
                    }
                }

                // Add More Interests button
                if let student = currentStudent {
                    Button(action: {
                        showingAddInterests = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add More Interests")
                                .fontWeight(.semibold)
                        }
                        .font(.tmiBody)
                        .foregroundColor(.tmiPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.md)
                                .fill(Color.tmiPrimary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: TMIRadius.md)
                                        .stroke(Color.tmiPrimary, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingAddInterests) {
                        NavigationStack {
                            AddInterestToStudentView(student: student) { updatedStudent in
                                currentStudent = updatedStudent
                                showingAddInterests = false
                            }
                        }
                    }
                }

                Button(action: {
                    // Call dismiss callback if provided, otherwise use environment dismiss
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    Text("Return to Dashboard")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.md)
                                .fill(Color.tmiSurface)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
    }

    // MARK: - Analysis Logic

    private func analyzeSurveyResponses() {
        // Extract selected interests from multiSelect step
        var selectedInterestIds: [String] = []
        if case .options(let options) = responses["interests"] {
            selectedInterestIds = options
        }

        // Extract dream job
        var dreamJob: String?
        if case .text(let text) = responses["dream_job"] {
            dreamJob = text
        }

        // Extract passion scale
        var passionScale: Int?
        if case .scale(let value) = responses["career_passion"] {
            passionScale = value
        }

        // Calculate weights for each interest cluster
        var clusterWeights: [String: Double] = [:]

        // Base weight from selected interests (primary signal)
        for interestId in selectedInterestIds {
            clusterWeights[interestId] = 1.0
        }

        // Boost weight if passion scale is high
        if let passion = passionScale, passion >= 4 {
            for key in clusterWeights.keys {
                clusterWeights[key]? *= 1.2
            }
        }

        // Normalize weights to 0-1 range
        let maxWeight = clusterWeights.values.max() ?? 1.0
        for key in clusterWeights.keys {
            clusterWeights[key]? /= maxWeight
        }

        // Create interest clusters from selected interests
        let allClusters = InterestCluster.allCategories
        var results: [InterestCluster] = []

        for clusterId in selectedInterestIds {
            if let baseCluster = allClusters.first(where: { $0.name == clusterId }) {
                let weight = clusterWeights[clusterId] ?? 0.5
                let weightedCluster = InterestCluster(
                    id: baseCluster.id,
                    name: baseCluster.name,
                    displayName: baseCluster.displayName,
                    weight: weight,
                    relatedCareers: baseCluster.relatedCareers,
                    icon: baseCluster.icon,
                    color: baseCluster.color
                )
                results.append(weightedCluster)
            }
        }

        // Sort by weight
        results.sort { $0.weight > $1.weight }

        analyzedClusters = results

        // Extract top interests from display names
        topInterests = results.prefix(3).map { $0.displayName }

        // Add dream job if provided
        if let dream = dreamJob, !dream.isEmpty {
            topInterests.append(dream)
        }
    }

    // MARK: - Firebase Integration

    private func saveSurveyToFirebase() {
        isSaving = true

        Task {
            do {
                // Save survey response
                let surveyResponse = try await SurveyService.shared.saveStudentSurveyResponse(
                    responses,
                    for: studentId,
                    duration: surveyDuration
                )

                // Update plan snapshot if launched from plan context
                if case .planDetail(let planId) = context {
                    try await updatePlanSnapshot(
                        planId: planId,
                        surveyId: surveyResponse.id.uuidString,
                        interestIds: surveyResponse.topInterests
                    )
                }

                // Get career matches
                let matches = CareerMatchingService.shared.matchCareers(
                    from: surveyResponse.interestClusters,
                    dreamJob: extractDreamJob()
                )

                // Fetch the updated student to enable "Add More Interests" button
                let studentService = StudentService()
                let student = try await studentService.getStudent(by: studentId)

                await MainActor.run {
                    careerMatches = matches
                    currentStudent = student
                    isSaving = false
                }

                print("[DATA] Survey saved and careers matched for student: \(studentId)")

            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
                print("[ERROR] Failed to save survey: \(error.localizedDescription)")
            }
        }
    }

    private func extractDreamJob() -> String? {
        if case .text(let text) = responses["dream_job"] {
            return text.isEmpty ? nil : text
        }
        return nil
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Update TMI Plan with survey snapshot data
    private func updatePlanSnapshot(planId: String, surveyId: String, interestIds: [String]) async throws {
        let service = TMIPlanService.shared
        try await service.updateSurveySnapshot(
            planId: planId,
            surveyId: surveyId,
            interestIds: interestIds
        )
        print("[DATA] Updated plan \(planId) with survey snapshot: \(surveyId)")
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    struct ConfettiPiece: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
        let scale: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: 10, height: 10)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
    }

    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.tmiPrimary, .tmiSuccess, .tmiWarning, .red, .purple, .orange]

        for _ in 0..<50 {
            let piece = ConfettiPiece(
                color: colors.randomElement() ?? .tmiPrimary,
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...size.height),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            )
            confettiPieces.append(piece)
        }

        // Animate confetti falling
        withAnimation(.linear(duration: 3.0)) {
            for index in confettiPieces.indices {
                confettiPieces[index] = ConfettiPiece(
                    color: confettiPieces[index].color,
                    x: confettiPieces[index].x + CGFloat.random(in: -50...50),
                    y: size.height + 100,
                    rotation: confettiPieces[index].rotation + Double.random(in: 0...720),
                    scale: confettiPieces[index].scale
                )
            }
        }
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        SurveyResultsView(
            studentId: "preview-student-id",
            responses: [
                "interests": .options(["audio_media", "technology", "creative_arts"]),
                "dream_job": .text("Podcaster"),
                "career_passion": .scale(5)
            ],
            surveyDuration: 125.0
        )
    }
}
