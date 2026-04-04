//
//  StudentModeView.swift
//  TMI
//
//  Restricted interface for students - only shows their own data.
//  Uses StudentAccessPolicy for consistent access control.
//

import SwiftUI

struct StudentModeView: View {
    let student: Student
    
    @Environment(\.studentModeSession) private var session
    @Environment(\.studentContext) private var studentContext
    @Environment(\.studentAccessMode) private var accessMode
    
    @State private var selectedTab: StudentTab = .myInterests
    @State private var showingExitConfirmation = false
    @State private var isExiting = false
    
    /// Tabs allowed for this mode
    private var allowedTabs: [StudentTab] {
        Array(StudentAccessPolicy.allowedTabs(in: .studentMode))
            .sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header with exit button
                customHeader

                // Student header
                studentHeader

                // Tab view - using StudentAccessPolicy
                TabView(selection: $selectedTab) {
                    ForEach(allowedTabs) { tab in
                        NavigationStack {
                            tabContent(for: tab)
                        }
                            .tag(tab)
                            .tabItem {
                                Label(tab.title, systemImage: tab.icon)
                            }
                    }
                }
                .tint(.tmiPrimary)
            }
        }
        .environment(\.studentAccessMode, .studentMode)
        .alert("Exit Student Mode?", isPresented: $showingExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Exit", role: .destructive) {
                exitStudentMode()
            }
        } message: {
            Text("Staff authentication required to exit student mode.")
        }
        .interactiveDismissDisabled(true)
        .task {
            // Set student context for cross-module access
            await studentContext.setActiveStudent(
                student.id,
                student: student,
                scope: .studentMode,
                prefetchEdges: true
            )
        }
        .onAppear {
            session.updateActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkSessionTimeout()
        }
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private func tabContent(for tab: StudentTab) -> some View {
        switch tab {
        case .myInterests:
            StudentInterestsTab(student: student)
        case .careers:
            StudentCareersTab(student: student)
        case .myProgress:
            StudentProgressTab(student: student)
        default:
            // Other tabs not available in student mode
            RestrictedAccessPlaceholder(mode: .studentMode)
        }
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack {
            Text("Student Mode")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tmiTextPrimary)

            Spacer()

            Button(action: { showingExitConfirmation = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                    Text("Exit")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tmiWarning)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.tmiWarning.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(isExiting)
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.vertical, TMISpacing.md)
        .background(Color.tmiBackground)
    }

    // MARK: - Student Header

    private var studentHeader: some View {
        VStack(spacing: TMISpacing.md) {
            // Avatar
            TMIAvatar(
                initials: student.initials,
                color: .tmiPrimary,
                size: 80
            )

            VStack(spacing: 4) {
                Text("Welcome, \(student.name.split(separator: " ").first ?? "")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)

                Text("Grade \(student.grade)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.tmiTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.lg)
        .padding(.horizontal, TMISpacing.screenPadding)
        .background(
            LinearGradient(
                colors: [
                    Color.tmiPrimary.opacity(0.3),
                    Color.tmiPrimary.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Actions

    private func exitStudentMode() {
        isExiting = true

        session.exitStudentMode { success in
            isExiting = false
            if !success {
                // Show error if authentication failed
                print("[StudentMode] Failed to exit - authentication denied")
            }
            // If successful, MainTabView will automatically switch back to staff mode
        }
    }

    private func checkSessionTimeout() {
        if session.hasSessionTimedOut() {
            session.forceExitDueToTimeout()
        } else {
            session.updateActivity()
        }
    }
}

// MARK: - Student Interests Tab

struct StudentInterestsTab: View {
    let student: Student

    @State private var interests: [Interest] = []
    @State private var isLoading = false
    @State private var showingInterestSurvey = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    if isLoading {
                        ProgressView("Loading your interests...")
                            .tint(.tmiPrimary)
                            .padding(TMISpacing.xl)
                    } else if interests.isEmpty {
                        emptyState
                    } else {
                        interestsGrid
                    }
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .sheet(isPresented: $showingInterestSurvey) {
            if let studentId = student.id {
                StudentSurveyFlow(studentId: studentId)
                    .tmiSheetStyle()
            }
        }
        .task(id: student.id) {
            await loadInterests()
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Interests Yet")
                .font(.tmiTitle2)
                .foregroundColor(Color.tmiTextPrimary)

            Text("Take the interest survey to discover what you love!")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            Button(action: { showingInterestSurvey = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Take Survey")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.tmiTextPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.tmiPrimary)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, TMISpacing.sm)
        }
        .padding(.top, 60)
    }

    private var interestsGrid: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            HStack {
                Text("My Interests")
                    .font(.tmiTitle2)
                    .foregroundColor(Color.tmiTextPrimary)

                Spacer()

                Button(action: { showingInterestSurvey = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.tmiPrimary.opacity(0.2))
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: TMISpacing.md) {
                ForEach(interests) { interest in
                    NavigationLink(destination: StudentInterestDetailView(interest: interest, currentStudent: student)) {
                        StudentModeInterestCard(interest: interest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func loadInterests() async {
        isLoading = true
        defer { isLoading = false }

        // Load interests from edge collection
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
        } catch {
            print("[StudentInterestsTab] Error loading interests: \(error.localizedDescription)")
            interests = []
        }
    }
}

private struct StudentModeInterestCard: View {
    let interest: Interest

    var body: some View {
        HStack(spacing: TMISpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [
                                interest.color.opacity(0.28),
                                interest.color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: interest.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(interest.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(interest.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.tmiTextPrimary)
                    .multilineTextAlignment(.leading)

                Text(interest.category.first?.rawValue ?? "General")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.tmiTextSecondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.tmiTextTertiary)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Student Careers Tab

struct StudentCareersTab: View {
    let student: Student

    @State private var careerMatches: [CareerMatchResult] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    if isLoading {
                        ProgressView("Finding careers for you...")
                            .tint(.tmiPrimary)
                            .padding(TMISpacing.xl)
                    } else if careerMatches.isEmpty {
                        emptyState
                    } else {
                        careersGrid
                    }
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .task(id: student.id) {
            await loadCareerMatches()
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Career Matches Yet")
                .font(.tmiTitle2)
                .foregroundColor(Color.tmiTextPrimary)

            Text("Complete the interest survey to discover careers that match your interests!")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var careersGrid: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Featured top match (if available)
            if let topMatch = careerMatches.first {
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    Text("Top Match")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiTextSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                    
                    NavigationLink(destination: CareerDetailView(career: convertToCareer(topMatch.career), student: student)) {
                        FeaturedCareerCard(match: topMatch)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // All career matches
            Text(careerMatches.count > 1 ? "All Matches" : "Careers For You")
                .font(.tmiTitle2)
                .foregroundColor(Color.tmiTextPrimary)
                .padding(.top, careerMatches.count > 1 ? TMISpacing.md : 0)

            VStack(spacing: TMISpacing.md) {
                ForEach(Array(careerMatches.dropFirst().prefix(9))) { match in
                    NavigationLink(destination: CareerDetailView(career: convertToCareer(match.career), student: student)) {
                        CareerMatchCard(match: match)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func convertToCareer(_ careerPath: CareerPath) -> Career {
        // Convert CareerPath to Career for display in CareerDetailView
        let salaryLower = Double(careerPath.estimatedSalary?.min ?? 30000)
        let salaryUpper = Double(careerPath.estimatedSalary?.max ?? 100000)

        return Career(
            title: careerPath.title,
            field: careerPath.category,
            description: careerPath.description,
            skills: careerPath.requiredInterests,
            education: careerPath.educationLevel.rawValue,
            salaryRange: salaryLower...salaryUpper,
            jobOutlook: "Growing field with opportunities",
            growthRate: 0.05
        )
    }

    @MainActor
    private func loadCareerMatches() async {
        isLoading = true
        defer { isLoading = false }

        // Load student interests from edge collection
        do {
            let interests = try await student.fetchInterestsFromEdgeCollection()

            // Generate career matches from student interests
            if !interests.isEmpty {
                // Convert interests to interest clusters
                let clusters = convertInterestsToClusters(interests)

                let service = CareerMatchingService.shared
                careerMatches = service.matchCareers(from: clusters, dreamJob: nil)
            }
        } catch {
            print("[StudentCareersTab] Error loading interests for career matching: \(error.localizedDescription)")
            careerMatches = []
        }
    }

    private func convertInterestsToClusters(_ interests: [Interest]) -> [InterestCluster] {
        // Group interests by category and create clusters
        var clusterMap: [String: [Interest]] = [:]

        for interest in interests {
            for category in interest.category {
                let categoryName = category.rawValue
                clusterMap[categoryName, default: []].append(interest)
            }
        }

        // Convert to InterestCluster objects
        return clusterMap.map { categoryName, categoryInterests in
            let allClusters = InterestCluster.allCategories
            let baseCluster = allClusters.first(where: { $0.name.lowercased().contains(categoryName.lowercased()) })

            return InterestCluster(
                id: UUID(),
                name: categoryName,
                displayName: baseCluster?.displayName ?? categoryName.capitalized,
                weight: min(1.0, Double(categoryInterests.count) / 3.0), // Weight based on count
                relatedCareers: baseCluster?.relatedCareers ?? [],
                icon: baseCluster?.icon ?? "star.fill",
                color: baseCluster?.color ?? "#3498DB"
            )
        }
    }
}

// MARK: - Student Progress Tab

struct StudentProgressTab: View {
    let student: Student

    @State private var plans: [TMIPlan] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    if isLoading {
                        ProgressView("Loading your progress...")
                            .tint(.tmiPrimary)
                            .padding(TMISpacing.xl)
                    } else if plans.isEmpty {
                        emptyState
                    } else {
                        progressView
                    }
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .task(id: student.id) {
            await loadPlans()
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Plans Yet")
                .font(.tmiTitle2)
                .foregroundColor(Color.tmiTextPrimary)

            Text("Your teacher will create a personalized plan for you!")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            Text("My Plans")
                .font(.tmiTitle2)
                .foregroundColor(Color.tmiTextPrimary)

            VStack(spacing: TMISpacing.md) {
                ForEach(plans) { plan in
                    NavigationLink(destination: StudentTMIPlanDetailView(plan: plan)) {
                        StudentPlanCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadPlans() async {
        guard let studentId = student.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let service = TMIPlanService.shared
            let allPlans = try await service.fetchPlans()

            // Filter to only plans containing this student
            plans = allPlans.filter { plan in
                plan.students.contains(where: { $0.id == studentId })
            }
        } catch {
            print("[StudentMode] Error loading plans: \(error)")
        }
    }
}

// MARK: - Supporting Components

struct StudentPlanCard: View {
    let plan: TMIPlan

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text(plan.model.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)

                Spacer()

                Text("\(plan.progressPercentage)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.tmiSuccess)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.tmiSurface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.tmiSuccess)
                        .frame(width: geometry.size.width * (Double(plan.progressPercentage) / 100), height: 8)
                }
            }
            .frame(height: 8)

            if !plan.goals.isEmpty {
                Text("\(plan.goals.count) goal\(plan.goals.count == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }
}

// MARK: - Featured Career Card

struct FeaturedCareerCard: View {
    let match: CareerMatchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    // Career title
                    Text(match.career.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.tmiTextPrimary)
                    
                    // Category
                    Text(match.career.category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                }
                
                Spacer()
                
                // Match percentage badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text("\(Int(match.score * 100))%")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color.tmiTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.tmiSuccess, Color.tmiSuccess.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            
            // Career stats
            HStack(spacing: TMISpacing.lg) {
                // Salary
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.tmiSuccess)
                        Text("Salary")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tmiTextSecondary)
                    }
                    if let salary = match.career.estimatedSalary {
                        Text("$\(salary.min/1000)k-$\(salary.max/1000)k")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.tmiTextPrimary)
                    } else {
                        Text("Varies")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.tmiTextPrimary)
                    }
                }
                
                Divider()
                    .frame(height: 40)
                
                // Education
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.tmiPrimary)
                        Text("Education")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tmiTextSecondary)
                    }
                    Text(match.career.educationLevel.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.tmiTextPrimary)
                        .lineLimit(1)
                }
            }
            .padding(.top, TMISpacing.sm)
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tmiPrimary.opacity(0.15),
                            Color.tmiSecondary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.lg)
                        .fill(Color.tmiSurface)
                        .opacity(0.6)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Color.tmiPrimary.opacity(0.5), Color.tmiSecondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.tmiPrimary.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct CareerMatchCard: View {
    let match: CareerMatchResult

    var body: some View {
        HStack(spacing: TMISpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.tmiPrimary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "briefcase.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.tmiPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(match.career.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.tmiTextPrimary)

                Text("\(Int(match.score * 100))% match")
                    .font(.system(size: 14))
                    .foregroundColor(.tmiSuccess)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.tmiTextTertiary)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }
}

// MARK: - Preview

#Preview {
    StudentModeView(student: Student.sampleStudent)
        .environment(StudentModeSession())
}
