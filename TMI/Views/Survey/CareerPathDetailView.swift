//
//  CareerPathDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CareerPathDetailView: View {
    let career: CareerPath
    let studentId: String? // Optional, as we might just be browsing

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLevel: SkillLevel = .beginner
    @State private var isCreatingPlan = false
    @State private var showingPlanCreated = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TMISpacing.xl) {
                    // Header
                    careerHeader

                    // Description
                    descriptionSection

                    // Pathway
                    pathwaySection

                    // TMI Modules
                    tmiModulesSection

                    // Action Button (only if studentId is provided)
                    if studentId != nil {
                        actionButton
                            .padding(.bottom, TMISpacing.xl)
                    }
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }
        }
        .navigationTitle(career.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var careerHeader: some View {
        VStack(spacing: TMISpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: career.color).opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: career.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: career.color))
            }

            VStack(spacing: TMISpacing.xs) {
                if let salary = career.estimatedSalary {
                    Text(salary.displayRange)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiSuccess)
                }

                Text(career.educationLevel.rawValue)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, TMISpacing.lg)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("About This Career")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Text(career.description)
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
    }

    private var pathwaySection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Learning Pathway")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            // Level Picker
            Picker("Level", selection: $selectedLevel) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)

            // Goals for selected level
            let goals = goalsForLevel(selectedLevel)
            if goals.isEmpty {
                Text("Pathway coming soon!")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .italic()
            } else {
                ForEach(goals) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: CEPGoal) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(goal.title)
                .font(.tmiBody)
                .fontWeight(.semibold)
                .foregroundColor(.tmiTextPrimary)

            if !goal.strategies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(goal.strategies, id: \.self) { strategy in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.tmiTextTertiary)
                            Text(strategy)
                                .font(.tmiCaption)
                                .foregroundColor(.tmiTextSecondary)
                        }
                    }
                }
            }

            if let duration = goal.estimatedDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("\(Int(duration))min")
                        .font(.tmiCaption)
                }
                .foregroundColor(.tmiTextTertiary)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }

    private var tmiModulesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Recommended TMI Modules")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            ForEach(career.pathway.tmiModules, id: \.self) { module in
                HStack(spacing: TMISpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.tmiSuccess)
                    Text(module.rawValue)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextPrimary)
                }
            }
        }
    }

    private var actionButton: some View {
        Button(action: {
            Task {
                await createPlanFromCareer()
            }
        }) {
            HStack {
                if isCreatingPlan {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                    Text("Create My Plan")
                        .fontWeight(.semibold)
                }
            }
            .font(.tmiBody)
            .foregroundColor(Color.tmiTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(Color(hex: career.color))
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingPlan)
        .alert("Plan Created!", isPresented: $showingPlanCreated) {
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your TMI Plan for \(career.title) has been created successfully! Go to the TMI Plans tab to view and edit your new plan.")
        }
        .alert("Error Creating Plan", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Plan Creation

    @MainActor
    private func createPlanFromCareer() async {
        guard let studentId = studentId else { return }
        isCreatingPlan = true
        defer { isCreatingPlan = false }

        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                errorMessage = "You must be signed in to create a plan"
                showingError = true
                print("[CareerPlan] No authenticated user")
                return
            }

            // Get user's district ID for district-scoped plan
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let districtId = userDoc.data()?["districtId"] as? String

            // Try to fetch the student
            print("[CareerPlan] Attempting to fetch student with ID: \(studentId)")
            var students: [Student] = []

            let studentDoc = try await db.collection("users")
                .document(userId)
                .collection("students")
                .document(studentId)
                .getDocument()

            if let student = try? studentDoc.data(as: Student.self) {
                students = [student]
                print("[CareerPlan] Found student: \(student.name)")
            } else {
                print("[CareerPlan] ⚠️ Student not found, creating plan without student")
            }

            // Create TMI Plan from career with Phase 1 fields
            let now = Date()
            let newPlan = TMIPlan(
                title: "\(career.title) Career Plan",
                description: "Career exploration plan for \(career.title)",
                students: students,
                model: career.pathway.tmiModules.first ?? .chaseYourSpace,
                interests: [],
                startDate: now,
                endDate: nil,
                creationDate: now,
                lastUpdated: now,
                goals: createGoalsFromCareer(),
                progress: 0.0,
                notes: "",
                strategies: createStrategiesFromCareer(),
                createdBy: userId,
                resources: [],
                districtId: districtId,
                assignedCounselorId: userId // Creator is initially assigned
            )

            // Save via TMIPlanService (handles both user-scoped for backwards compatibility)
            print("[CareerPlan] Saving plan via TMIPlanService...")
            let savedPlan = try await TMIPlanService.shared.addPlan(newPlan)
            
            print("[CareerPlan] ✅ Successfully saved plan with ID: \(savedPlan.id ?? "unknown")")
            
            // Save student's career interest state
            try await StudentCareerService.shared.addCareer(
                studentId: studentId,
                careerId: career.id.uuidString,
                status: .exploring,
                progress: 0.0,
                isFavorite: true
            )
            print("[CareerPlan] ✅ Saved student career state for \(career.title)")

            // Notify other views that a new plan was created
            NotificationCenter.default.post(name: NSNotification.Name("TMIPlanCreated"), object: nil)

            // Success feedback
            showingPlanCreated = true

        } catch {
            errorMessage = "Failed to create plan: \(error.localizedDescription)"
            showingError = true
            print("[CareerPlan] ❌ Error creating plan: \(error)")
        }
    }

    private func createGoalsFromCareer() -> [Goal] {
        // Convert career pathway goals to TMI goals
        var goals: [Goal] = []

        // Add beginner goals
        for cepGoal in career.pathway.beginnerGoals.prefix(3) {
            goals.append(Goal(
                description: cepGoal.title,
                dueDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                status: .notStarted,
                progress: 0.0,
                notes: cepGoal.strategies.first
            ))
        }

        return goals
    }

    private func createStrategiesFromCareer() -> [String] {
        // Extract strategies from all levels
        var strategies: [String] = []

        for goal in career.pathway.beginnerGoals.prefix(2) {
            strategies.append(contentsOf: goal.strategies.prefix(2))
        }

        return Array(strategies.prefix(5))
    }

    // MARK: - Helpers

    private func goalsForLevel(_ level: SkillLevel) -> [CEPGoal] {
        switch level {
        case .beginner:
            return career.pathway.beginnerGoals
        case .intermediate:
            return career.pathway.intermediateGoals
        case .advanced:
            return career.pathway.advancedGoals
        }
    }
}

