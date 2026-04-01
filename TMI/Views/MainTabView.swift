//
//  MainTabView.swift
//  TMI
//
//  Created by Chandan Brown on 9/10/24.
//
//  Main navigation hub for staff users.
//  Manages tab-based navigation with role gating and student context.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(\.deepLinkRouter) private var deepLinkRouter
    @Environment(\.notificationService) private var notificationService
    
    // Student Mode
    @State private var studentModeSession = StudentModeSession()
    
    // Sheet state
    @State private var showingUserProfile = false
    @State private var showingSignOutConfirmation = false
    @State private var showingWorkspacePanel = false
    
    // State models
    @State private var meetingsStateModel = MeetingsStateModel()
    @State private var recommendationsStateModel = RecommendationsStateModel()

    // Navigation paths per tab
    @State private var dashboardPath = NavigationPath()
    @State private var studentsPath = NavigationPath()
    @State private var plansPath = NavigationPath()
    
    enum Tab: String, CaseIterable, Identifiable {
        case dashboard, students, tmiPlans
        var id: Self { self }

        // Define which roles can access each tab
        var allowedRoles: Set<UserRole> {
            switch self {
            case .dashboard:
                return [.teacher, .counselor, .administrator, .admin, .socialWorker, .parent, .legalGuardian, .superintendent, .districtAdmin]
            case .students:
                return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin]
            case .tmiPlans:
                return [.teacher, .counselor, .administrator, .admin, .socialWorker, .superintendent, .districtAdmin]
            }
        }

        func isAccessible(for role: UserRole?) -> Bool {
            guard let role = role else { return false }
            return allowedRoles.contains(role)
        }

        var label: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .students: return "Students"
            case .tmiPlans: return "TMI Plans"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .students: return "person.3.fill"
            case .tmiPlans: return "doc.text.fill"
            }
        }
    }
    
    // Computed property to get tabs accessible to current user
    var availableTabs: [Tab] {
        let currentRole = authStateModel.currentUser?.role
        return Tab.allCases.filter { $0.isAccessible(for: currentRole) }
    }
    
    // Default tab - use first available or dashboard
    var defaultTab: Tab {
        availableTabs.first ?? .dashboard
    }
    
    var body: some View {
        Group {
            if let activeStudent = studentModeSession.activeStudent {
                // Student Mode - Restricted Interface
                StudentModeView(student: activeStudent)
                    .environment(\.studentModeSession, studentModeSession)
                    .environment(\.studentAccessMode, .studentMode)
                    .onAppear {
                        print("[MainTabView] 🎓 Switched to Student Mode for: \(activeStudent.name)")
                    }
            } else {
                // Staff Mode - Full Interface
                staffTabView
                    .environment(\.studentModeSession, studentModeSession)
                    .environment(\.meetingsStateModel, meetingsStateModel)
                    .environment(\.recommendationsStateModel, recommendationsStateModel)
                    .onAppear {
                        print("[MainTabView] 👨‍💼 In Staff Mode")
                    }
            }
        }
        .task {
            // Process pending deep links
            if deepLinkRouter.pendingNavigation != nil {
                await deepLinkRouter.executePendingNavigation(
                    context: studentContext,
                    tabSelection: $selectedTab
                )
            }
        }
    }
    
    // MARK: - Staff Tab View

    private var staffTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(availableTabs, id: \.self) { tab in
                NavigationStack {
                    destinationView(for: tab)
                        .navigationTitle(tab.label)
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                if studentContext.hasActiveStudent {
                                    workspaceButton
                                }
                            }
                            ToolbarItemGroup(placement: .automatic) {
                                NotificationBellButton()
                                profileMenu
                            }
                        }
                }
                .tabItem {
                    Label(tab.label, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .accentColor(.tmiSecondary)
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView()
                .tmiSheetStyle()
        }
        .sheet(isPresented: $showingWorkspacePanel) {
            WorkspacePanelView()
                .tmiSheetStyle()
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    // Clear context on sign out
                    studentContext.clearContext()
                    authStateModel.signOut()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            // Set appropriate default tab for user role
            if !availableTabs.contains(selectedTab) {
                selectedTab = defaultTab
            }
            notificationService.startListening()
            Task { try? await notificationService.fetchNotifications() }
        }
        .onDisappear {
            notificationService.stopListening()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Clear deep link when manually changing tabs
            studentContext.clearPendingDeepLink()
        }
    }
    
    // MARK: - Workspace Button
    
    private var workspaceButton: some View {
        Button {
            showingWorkspacePanel = true
        } label: {
            HStack(spacing: 6) {
                if let student = studentContext.cachedStudent {
                    TMIAvatar(
                        initials: student.initials,
                        color: .tmiPrimary,
                        size: 28
                    )
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                }
                
                Text(studentContext.contextDisplayName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.tmiPrimary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Profile Menu
    
    private var profileMenu: some View {
        Menu {
            Button {
                showingUserProfile = true
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Destination Views
    
    @ViewBuilder
    func destinationView(for tab: Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .students:
            StudentListView()
        case .tmiPlans:
            TMIPlanListView()
        }
    }
}

// MARK: - Workspace Panel View

struct WorkspacePanelView: View {
    @Environment(\.studentContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tmiBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TMISpacing.lg) {
                        // Active Student Section
                        if let student = context.cachedStudent {
                            activeStudentSection(student)
                        } else {
                            noStudentSection
                        }
                        
                        // Active Plan Section
                        if let plan = context.cachedPlan {
                            activePlanSection(plan)
                        }
                        
                        // Quick Stats
                        if context.hasActiveStudent {
                            quickStatsSection
                        }
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func activeStudentSection(_ student: Student) -> some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                HStack {
                    TMIAvatar(
                        initials: student.initials,
                        color: .tmiPrimary,
                        size: 60
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Grade \(student.grade)")
                            .font(.subheadline)
                            .foregroundColor(.tmiTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task {
                            context.clearContext()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.tmiTextSecondary)
                    }
                }
                
                // Prefetched data indicators
                HStack(spacing: TMISpacing.md) {
                    DataIndicator(
                        icon: "heart.fill",
                        label: "Interests",
                        count: context.prefetchedInterests.count
                    )
                    
                    DataIndicator(
                        icon: "doc.text.fill",
                        label: "Plans",
                        count: context.prefetchedPlans.count
                    )
                }
            }
            .padding()
        }
    }
    
    private var noStudentSection: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiTextSecondary)
                
                Text("No Student Selected")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Select a student from the Students tab to start working")
                    .font(.caption)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private func activePlanSection(_ plan: TMIPlan) -> some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                HStack {
                    Text("Active Plan")
                        .font(.caption)
                        .foregroundColor(.tmiTextSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(plan.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.tmiSuccess)
                }
                
                Text(plan.title.isEmpty ? plan.model.rawValue : plan.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: plan.progress)
                    .tint(.tmiSuccess)
            }
            .padding()
        }
    }
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("Quick Stats")
                .font(.caption)
                .foregroundColor(.tmiTextSecondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.sm) {
                QuickStatCard(
                    icon: "heart.fill",
                    value: "\(context.prefetchedInterests.count)",
                    label: "Interests"
                )
                
                QuickStatCard(
                    icon: "briefcase.fill",
                    value: context.prefetchedCareerState != nil ? "Active" : "None",
                    label: "Career State"
                )
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: TMISpacing.sm) {
            if context.hasActiveStudent {
                Button {
                    // Would navigate to plan creation
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Plan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.tmiPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(TMIRadius.md)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Supporting Components

private struct DataIndicator: View {
    let icon: String
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.tmiPrimary)
            
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundColor(.tmiTextSecondary)
        }
    }
}

private struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.tmiPrimary)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.sm)
    }
}

// MARK: - Preview

#Preview("iPhone") {
  MainTabView()
}

#Preview("iPad") {
  MainTabView()
}
