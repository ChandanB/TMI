//
//  StudentModeView.swift
//  TMI
//
//  Restricted interface for students - only shows their own data
//

import SwiftUI

struct StudentModeView: View {
    let student: Student

    @Environment(\.studentModeSession) private var session
    @State private var selectedTab = 0
    @State private var showingExitConfirmation = false
    @State private var isExiting = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header with exit button
                customHeader

                // Student header
                studentHeader

                // Tab view
                TabView(selection: $selectedTab) {
                    // My Interests
                    StudentInterestsTab(student: student)
                        .tag(0)
                        .tabItem {
                            Label("My Interests", systemImage: "heart.fill")
                        }

                    // Career Explorer
                    StudentCareersTab(student: student)
                        .tag(1)
                        .tabItem {
                            Label("Careers", systemImage: "briefcase.fill")
                        }

                    // My Progress
                    StudentProgressTab(student: student)
                        .tag(2)
                        .tabItem {
                            Label("My Progress", systemImage: "chart.line.uptrend.xyaxis")
                        }
                }
                .tint(.tmiPrimary)
            }
        }
        .alert("Exit Student Mode?", isPresented: $showingExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Exit", role: .destructive) {
                exitStudentMode()
            }
        } message: {
            Text("Staff authentication required to exit student mode.")
        }
        .interactiveDismissDisabled(true)
        .preferredColorScheme(.dark)
        .onAppear {
            session.updateActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkSessionTimeout()
        }
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack {
            Text("Student Mode")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

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
                    .foregroundColor(.white)

                Text("Grade \(student.grade)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
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
        NavigationStack {
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
                }
            }
            .task {
                await loadInterests()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Interests Yet")
                .font(.tmiTitle2)
                .foregroundColor(.white)

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
                .foregroundColor(.white)
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
                    .foregroundColor(.white)

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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: TMISpacing.md) {
                ForEach(interests) { interest in
                    NavigationLink(destination: StudentInterestDetailView(interest: interest, currentStudent: student)) {
                        InterestCardView(interest: interest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadInterests() async {
        isLoading = true
        defer { isLoading = false }

        // Load interests from student
        interests = student.interests
    }
}

// MARK: - Student Careers Tab

struct StudentCareersTab: View {
    let student: Student

    @State private var careerMatches: [CareerMatchResult] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
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
            .task {
                await loadCareerMatches()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "briefcase.slash")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Career Matches Yet")
                .font(.tmiTitle2)
                .foregroundColor(.white)

            Text("Complete the interest survey to discover careers that match your interests!")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var careersGrid: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            Text("Careers For You")
                .font(.tmiTitle2)
                .foregroundColor(.white)

            VStack(spacing: TMISpacing.md) {
                ForEach(careerMatches.prefix(10)) { match in
                    NavigationLink(destination: CareerDetailView(career: convertToCareer(match.career))) {
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

    private func loadCareerMatches() async {
        isLoading = true
        defer { isLoading = false }

        // Generate career matches from student interests
        if !student.interests.isEmpty {
            // Convert interests to interest clusters
            let clusters = convertInterestsToClusters(student.interests)

            let service = CareerMatchingService.shared
            careerMatches = service.matchCareers(from: clusters, dreamJob: nil)
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
        NavigationStack {
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
            .task {
                await loadPlans()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.tmiTextTertiary)

            Text("No Plans Yet")
                .font(.tmiTitle2)
                .foregroundColor(.white)

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
                .foregroundColor(.white)

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
            let service = TMIPlanService()
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
                    .foregroundColor(.white)

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
                    .foregroundColor(.white)

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
