//
//  AddInterestToPlanView.swift
//  TMI
//
//  View for adding interests to a TMI Plan
//

import SwiftUI

struct AddInterestToPlanView: View {
    let plan: TMIPlan
    let onInterestAdded: ((TMIPlan) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.interestsStateModel) var interestsStateModel

    @State private var planService = TMIPlanService()
    @State private var searchText = ""
    @State private var selectedCategory: InterestCategory?
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var loadedStudentInterests: [Interest] = []
    @State private var isLoadingInterests = true

    init(plan: TMIPlan, onInterestAdded: ((TMIPlan) -> Void)? = nil) {
        self.plan = plan
        self.onInterestAdded = onInterestAdded
    }

    // Check if an interest belongs to any student in the plan
    private func isStudentInterest(_ interest: Interest) -> Bool {
        let studentInterestNames = Set(loadedStudentInterests.map { $0.name.lowercased() })
        return studentInterestNames.contains(interest.name.lowercased())
    }

    // Filter interests that the plan doesn't already have
    // Prioritize student interests, then show other predefined interests
    private var availableInterests: [Interest] {
        let planInterestNames = Set(plan.interests.map { $0.name.lowercased() })

        // Get student interests first (from the plan's students)
        // Use loaded interests instead of synchronous mapping
        let uniqueStudentInterests = Array(Set(loadedStudentInterests)).filter { interest in
            !planInterestNames.contains(interest.name.lowercased())
        }

        // Then add other predefined interests not already in student interests
        let studentInterestNames = Set(loadedStudentInterests.map { $0.name.lowercased() })
        let otherInterests = PredefinedInterestsData.allPredefinedInterests.filter { interest in
            !planInterestNames.contains(interest.name.lowercased()) &&
            !studentInterestNames.contains(interest.name.lowercased())
        }

        // Combine: student interests first, then others
        var allInterests = uniqueStudentInterests + otherInterests

        // Filter by category
        if let category = selectedCategory {
            allInterests = allInterests.filter { $0.category.contains(category) }
        }

        // Filter by search
        if !searchText.isEmpty {
            allInterests = allInterests.filter { interest in
                interest.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: student interests first (by keeping order), others by popularity
        return allInterests
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Search bar
                TMITextField(
                    icon: "magnifyingglass",
                    placeholder: "Search interests...",
                    text: $searchText
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryFilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(InterestCategory.allCases, id: \.self) { category in
                            CategoryFilterChip(
                                title: category.rawValue,
                                icon: category.iconName,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                // Results count
                HStack {
                    Text("\(availableInterests.count) available interests")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Interests list
                if availableInterests.isEmpty {
                    emptyStateView
                } else {
                    interestsList
                }
            }
        }
        .navigationTitle("Add Interests to Plan")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadStudentInterests()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(modelColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: modelIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(modelColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding interests to")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(plan.model.shortDisplayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()
            }

            if !plan.interests.isEmpty {
                Text("Current interests: \(plan.interests.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            if !plan.students.isEmpty {
                let studentInterestCount = Set(loadedStudentInterests).count
                HStack(spacing: 4) {
                    Text("For \(plan.students.count) student\(plan.students.count == 1 ? "" : "s")")
                    if studentInterestCount > 0 {
                        Text("•")
                        Text("\(studentInterestCount) student interest\(studentInterestCount == 1 ? "" : "s") available")
                            .foregroundColor(.tmiPrimary.opacity(0.9))
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Interests List

    private var interestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(availableInterests) { interest in
                    PlanInterestRow(
                        interest: interest,
                        isAdding: isAdding,
                        isStudentInterest: isStudentInterest(interest),
                        onAdd: {
                            addInterest(interest)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "checkmark.circle.fill" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.4))

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "All Set!" : "No Results")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(searchText.isEmpty
                     ? "This plan has all available interests!"
                     : "No interests match '\(searchText)'"
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Properties

    private var modelIcon: String {
        switch plan.model {
        case .chaseYourSpace: return "rocket.fill"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile.fill"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "person.fill.turn.up"
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

    private func loadStudentInterests() async {
        isLoadingInterests = true
        defer { isLoadingInterests = false }

        var allInterests: [Interest] = []
        
        // Parallel fetch for all students
        await withTaskGroup(of: [Interest].self) { group in
            for student in plan.students {
                group.addTask {
                    do {
                        return try await student.fetchInterestsFromEdgeCollection()
                    } catch {
                        print("Error fetching interests for student \(student.id ?? "unknown"): \(error)")
                        return []
                    }
                }
            }
            
            for await interests in group {
                allInterests.append(contentsOf: interests)
            }
        }
        
        self.loadedStudentInterests = allInterests
    }

    // MARK: - Actions

    private func addInterest(_ interest: Interest) {
        guard !isAdding else { return }

        isAdding = true

        Task {
            do {
                // Create updated plan with new interest
                var updatedInterests = plan.interests
                updatedInterests.append(interest)

                let updatedPlan = TMIPlan(
                    id: plan.id,
                    title: plan.title,
                    description: plan.description,
                    students: plan.students,
                    model: plan.model,
                    interests: updatedInterests,
                    startDate: plan.startDate,
                    endDate: plan.endDate,
                    creationDate: plan.creationDate,
                    lastUpdated: Date(),
                    goals: plan.goals,
                    progress: plan.progress,
                    notes: plan.notes,
                    strategies: plan.strategies,
                    progressTracking: plan.progressTracking,
                    createdBy: plan.createdBy
                )

                // Update in Firestore
                let savedPlan = try await planService.updatePlan(updatedPlan)

                // Add to global interests collection
                await interestsStateModel.addInterest(interest)

                // Notify parent and dismiss on success
                await MainActor.run {
                    onInterestAdded?(savedPlan)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add interest: \(error.localizedDescription)"
                    showError = true
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Plan Interest Row

struct PlanInterestRow: View {
    let interest: Interest
    let isAdding: Bool
    let isStudentInterest: Bool
    let onAdd: () -> Void

    @State private var isExpanded = false

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(interest.color.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: interest.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(interest.color)
                    }

                    // Name and category
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(interest.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            if isStudentInterest {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9))
                                    Text("Student")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.tmiPrimary)
                                .cornerRadius(4)
                            }

                            if interest.isFeatured {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9))
                            Text(interest.category.first?.rawValue ?? "General")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.6))

                        if let score = interest.popularityScore {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 9))
                                Text("\(score)% popular")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Add button
                    Button(action: onAdd) {
                        if isAdding {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdding)
                }
                .padding(16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }

                // Expanded details
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if let description = interest.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        if !interest.academicRelevance.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Academic Relevance")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(interest.academicRelevance, id: \.self) { subject in
                                            Text(subject.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.2))
                                                )
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }

                        if let skills = interest.skillsDeveloped, !skills.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Skills Developed")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(skills, id: \.self) { skill in
                                            Text(skill.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.purple.opacity(0.2))
                                                )
                                                .foregroundColor(.purple)
                                        }
                                    }
                                }
                            }
                        }

                        if let pathways = interest.careerPathways, !pathways.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Career Pathways")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(pathways, id: \.self) { pathway in
                                            Text(pathway.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.orange.opacity(0.2))
                                                )
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        AddInterestToPlanView(plan: TMIPlan.samplePlan)
            .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
    }
}
#endif
