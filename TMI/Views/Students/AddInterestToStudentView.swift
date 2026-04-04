//
//  AddInterestToStudentView.swift
//  TMI
//
//  View for adding interests to a specific student
//

import SwiftUI

struct AddInterestToStudentView: View {
    let student: Student
    let onStudentUpdated: (Student) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.interestsStateModel) var interestsStateModel

    @State private var studentService = StudentService()
    @State private var searchText = ""
    @State private var selectedCategory: InterestCategory?
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""

    @State private var studentInterests: [Interest] = []
    @State private var interestCount: Int = 0

    // Separate survey-based interests from manually added
    private var surveyBasedInterests: [Interest] {
        // If student has survey results, consider interests that came from survey
        // For now, we'll need to add metadata to track this, but as a starting point
        // we can show existing interests
        guard let surveyResults = student.surveyResults, !surveyResults.isEmpty else {
            return []
        }
        return studentInterests
    }

    // Filter interests that the student doesn't already have
    private var availableInterests: [Interest] {
        let studentInterestNames = Set(studentInterests.map { $0.name.lowercased() })
        var interests = PredefinedInterestsData.allPredefinedInterests.filter { interest in
            !studentInterestNames.contains(interest.name.lowercased())
        }

        // Filter by category
        if let category = selectedCategory {
            interests = interests.filter { $0.category.contains(category) }
        }

        // Filter by search
        if !searchText.isEmpty {
            interests = interests.filter { interest in
                interest.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return interests.sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }
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

                // Survey-based interests section (if any)
                if !surveyBasedInterests.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            surveyInterestsSection

                            Divider()
                                .background(Color.white.opacity(0.3))
                                .padding(.horizontal, 20)

                            addMoreInterestsSection
                        }
                        .padding(.bottom, 100)
                    }
                } else {
                    // Interests list (no survey results)
                    if availableInterests.isEmpty {
                        emptyStateView
                    } else {
                        interestsList
                    }
                }
            }
        }
        .navigationTitle("Add Interests")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInterests()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInterests() async {
        do {
            studentInterests = try await student.fetchInterestsFromEdgeCollection()
            interestCount = try await student.getInterestCount()
        } catch {
            print("[AddInterestToStudentView] Error loading interests: \(error.localizedDescription)")
            studentInterests = []
            interestCount = 0
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(student.avatarColor.gradient)
                        .frame(width: 50, height: 50)

                    Text(student.initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding interests for")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(student.name)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()
            }

            if !studentInterests.isEmpty {
                Text("Current interests: \(interestCount)")
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

    // MARK: - Survey Interests Section

    private var surveyInterestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                Text("From Your Survey")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)

            Text("These interests were discovered through the student's survey responses")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(surveyBasedInterests) { interest in
                    SurveyInterestRow(interest: interest)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Add More Interests Section

    private var addMoreInterestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)

                Text("Add More Interests")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)

            if availableInterests.isEmpty {
                Text("All available interests have been added!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(availableInterests) { interest in
                        StudentInterestRow(
                            interest: interest,
                            isAdding: isAdding,
                            onAdd: {
                                addInterest(interest)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Interests List

    private var interestsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(availableInterests) { interest in
                    StudentInterestRow(
                        interest: interest,
                        isAdding: isAdding,
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
                     ? "\(student.name) has all available interests!"
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

    // MARK: - Actions

    private func addInterest(_ interest: Interest) {
        guard !isAdding else { return }

        isAdding = true

        Task {
            do {
                // Use new deduplication method from StudentService
                let savedStudent = try await studentService.addInterests([interest], to: student)

                // Add to global interests collection
                await interestsStateModel.addInterest(interest)

                // Update parent view and dismiss
                await MainActor.run {
                    onStudentUpdated(savedStudent)
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

// MARK: - Survey Interest Row

struct SurveyInterestRow: View {
    let interest: Interest

    var body: some View {
        TMIGlassCard(style: .default) {
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
                    Text(interest.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                        Text(interest.category.first?.rawValue ?? "General")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Survey badge
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                    Text("Survey")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.2))
                )
            }
            .padding(16)
        }
    }
}

// MARK: - Student Interest Row

struct StudentInterestRow: View {
    let interest: Interest
    let isAdding: Bool
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

// MARK: - Avatar Color Extension

extension AvatarColor {
    var gradient: LinearGradient {
        switch self {
        case .blue:
            return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange:
            return LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal:
            return LinearGradient(colors: [.teal, .teal.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink:
            return LinearGradient(colors: [.pink, .pink.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigo:
            return LinearGradient(colors: [.indigo, .indigo.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        AddInterestToStudentView(student: Student.sampleStudent) { _ in }
            .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
    }
}
#endif
