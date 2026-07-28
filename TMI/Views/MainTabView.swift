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
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(AppRouter.self) private var router
    @Environment(\.notificationService) private var notificationService
    
    // Student Mode
    @State private var studentModeSession = StudentModeSession()
    
    // Sheet state
    @State private var showingSignOutConfirmation = false
    @State private var showingSignOutFailure = false
    @SceneStorage("tmi.staff.selectedTab") private var restoredTab = AppTab.dashboard.rawValue
    
    // State models
    @State private var meetingsStateModel = MeetingsStateModel()
    @State private var recommendationsStateModel = RecommendationsStateModel()

    var body: some View {
        Group {
            if let activeStudent = studentModeSession.activeStudent {
                // Student Mode - Restricted Interface
                StudentModeView(student: activeStudent)
                    .environment(\.studentModeSession, studentModeSession)
                    .environment(\.studentAccessMode, .studentMode)
                    .onAppear {
                        dependencies.logger.info(
                            "student_mode_entered",
                            metadata: ["studentID": activeStudent.id ?? "missing"]
                        )
                    }
            } else {
                // Staff Mode - Full Interface
                staffTabView
                    .environment(\.studentModeSession, studentModeSession)
                    .environment(\.meetingsStateModel, meetingsStateModel)
                    .environment(\.recommendationsStateModel, recommendationsStateModel)
                    .onAppear {
                        dependencies.logger.info("staff_mode_entered")
                    }
            }
        }
        .task {
            updateNavigationPolicy()
            restoreSelectedTab()
            try? router.resumePendingDeepLink()
            syncStudentContext()
        }
        .onChange(of: authStateModel.currentMembership) { _, _ in
            updateNavigationPolicy()
            try? router.resumePendingDeepLink()
        }
        .onChange(of: studentContext.selectedStudentId) { _, _ in
            syncStudentContext()
        }
        .onChange(of: studentContext.cachedStudent) { _, _ in
            syncStudentContext()
        }
        .onChange(of: studentContext.selectedPlanId) { _, planID in
            router.setActivePlan(id: planID)
        }
        .onChange(of: router.selectedTab) { _, tab in
            // Persist only the non-sensitive tab. Record IDs are reloaded and
            // reauthorized after every scene or process reconstruction.
            restoredTab = tab.rawValue
        }
    }
    
    // MARK: - Staff Tab View

    @ViewBuilder
    private var staffTabView: some View {
#if os(macOS)
        macStaffNavigation
            .modifier(StaffShellModifier(
                notificationService: notificationService,
                showingSignOutConfirmation: $showingSignOutConfirmation,
                showingSignOutFailure: $showingSignOutFailure,
                attemptSignOut: attemptSignOut
            ))
#else
        mobileStaffNavigation
            .modifier(StaffShellModifier(
                notificationService: notificationService,
                showingSignOutConfirmation: $showingSignOutConfirmation,
                showingSignOutFailure: $showingSignOutFailure,
                attemptSignOut: attemptSignOut
            ))
#endif
    }

    private var mobileStaffNavigation: some View {
        @Bindable var router = router

        return NavigationStack(path: $router.path) {
            TabView(selection: $router.selectedTab) {
                ForEach(router.availableTabs) { tab in
                    destinationView(for: tab)
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .tag(tab)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .navigationTitle(router.selectedTab.title)
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(route)
            }
            .toolbar { staffToolbar }
        }
    }

#if os(macOS)
    private var macStaffNavigation: some View {
        @Bindable var router = router

        return NavigationSplitView {
            List {
                ForEach(Array(router.availableTabs.enumerated()), id: \.element) { index, tab in
                    Button {
                        try? router.select(tab)
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        router.selectedTab == tab
                            ? Color.tmiPrimary.opacity(0.18)
                            : Color.clear
                    )
                    .keyboardShortcut(
                        KeyEquivalent(Character(String(index + 1))),
                        modifiers: .command
                    )
                    .accessibilityAddTraits(
                        router.selectedTab == tab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("TMI")
        } detail: {
            NavigationStack(path: $router.path) {
                destinationView(for: router.selectedTab)
                    .navigationTitle(router.selectedTab.title)
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(route)
                    }
                    .toolbar { staffToolbar }
            }
        }
    }
#endif

    @ToolbarContentBuilder
    private var staffToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            if router.activeStudent != nil {
                workspaceButton
            }
        }
        ToolbarItemGroup(placement: .automatic) {
            if notificationService != nil {
                NotificationBellButton()
            }
            profileMenu
        }
    }

    @MainActor
    private func attemptSignOut() {
        guard authStateModel.signOut() else {
            showingSignOutFailure = true
            return
        }

        studentContext.clearContext()
        router.reset()
    }

    private func updateNavigationPolicy() {
        router.updatePolicy(AppNavigationPolicy(membership: authStateModel.currentMembership))
        guard let studentID = studentContext.selectedStudentId else {
            return
        }

        let isAuthorized = if let student = studentContext.cachedStudent,
                              student.id == studentID {
            router.setActiveStudent(student)
        } else {
            router.setActiveStudent(id: studentID, displayName: "")
        }
        if !isAuthorized {
            studentContext.clearContext()
        }
    }

    private func restoreSelectedTab() {
        guard let tab = AppTab(rawValue: restoredTab) else {
            restoredTab = AppTab.dashboard.rawValue
            return
        }
        try? router.select(tab)
    }

    private func syncStudentContext() {
        guard let studentID = studentContext.selectedStudentId else {
            router.clearActiveStudent()
            return
        }

        let isAuthorized = if let student = studentContext.cachedStudent,
                              student.id == studentID {
            router.setActiveStudent(student)
        } else {
            router.setActiveStudent(id: studentID, displayName: "")
        }
        guard isAuthorized else {
            studentContext.clearContext()
            return
        }
        router.setActivePlan(id: studentContext.selectedPlanId)
    }

    private var workspaceButton: some View {
        Button {
            try? router.present(.workspace)
        } label: {
            HStack(spacing: 6) {
                if let student = router.activeStudent {
                    TMIAvatar(
                        initials: student.initials,
                        color: .tmiPrimary,
                        size: 28
                    )
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 20))
                }

                Text(router.activeStudentName ?? "Selected Student")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Color.tmiTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.tmiPrimary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open workspace for \(router.activeStudentName ?? "selected student")")
    }

    private var profileMenu: some View {
        Menu {
            Button {
                try? router.open(.profile)
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }

            Button {
                try? router.open(.settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
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
                .foregroundColor(Color.tmiTextPrimary)
        }
        .accessibilityLabel("Account")
    }

    @ViewBuilder
    private func destinationView(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .students:
            StudentListView()
        case .plans:
            ContentUnavailableView(
                "TMI Plans Arrive in Release 3",
                systemImage: "doc.text.fill",
                description: Text(
                    "Release 1 keeps the roster secure and available. "
                        + "Canonical plan creation, review, and approval ship with the intervention workflow."
                )
            )
        case .district:
            DistrictDashboardView()
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: AppRoute) -> some View {
        switch route {
        case .student(let studentID):
            StudentDetailView(studentID: studentID)
        case .editStudent(let studentID):
            if let record = router.activeStudentRecord,
               record.id == studentID {
                CanonicalStudentEditRoute(record: record)
            } else {
                ContentUnavailableView(
                    "Student Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Return to the student record and try again.")
                )
            }
        case .plan(let planID):
            if let plan = router.activePlan, plan.id == planID {
                TMIPlanDetailView(plan: plan)
            } else {
                ContentUnavailableView(
                    "Plan Unavailable",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Return to the TMI Plans list and try again.")
                )
            }
        case .profile:
            UserProfileView()
        case .settings:
            SettingsView()
        }
    }
}

private struct CanonicalStudentEditRoute: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @Environment(AppRouter.self) private var router

    @State private var record: StudentRecord
    @State private var isSubmitting = false
    @State private var mutationError: StudentRepositoryError?

    init(record: StudentRecord) {
        _record = State(initialValue: record)
    }

    var body: some View {
        if let member = authStateModel.currentMembership {
            StudentEditorView(
                mode: .edit(record),
                member: member,
                isSubmitting: isSubmitting,
                duplicateCandidateIDs: duplicateCandidateIDs,
                submissionError: errorMessage
            ) { draft in
                await self.save(draft, member: member)
            }
        } else {
            ContentUnavailableView(
                "Student Access Unavailable",
                systemImage: "lock.fill",
                description: Text(
                    "A verified staff membership is required to edit this student."
                )
            )
        }
    }

    private var duplicateCandidateIDs: [String] {
        guard case .duplicate(let candidateIDs) = mutationError else {
            return []
        }
        return candidateIDs
    }

    private var errorMessage: String? {
        guard let mutationError else { return nil }
        return switch mutationError {
        case .duplicate:
            "A possible duplicate needs review before this update can be saved."
        case .versionConflict:
            "This record changed on the server. Return to the student and refresh before editing."
        case .onlineRequired, .unavailable:
            "This update requires a connection. No confirmed student data was changed."
        case .permissionDenied, .staleMembership:
            "Your current staff access does not allow this update."
        default:
            "The update was not confirmed. Review the fields and try again."
        }
    }

    @MainActor
    private func save(
        _ draft: StudentDraft,
        member: MembershipContext
    ) async -> StudentEditorView.SaveOutcome {
        guard !isSubmitting else { return .failed }

        isSubmitting = true
        mutationError = nil
        defer { isSubmitting = false }

        do {
            let confirmed = try await dependencies.studentDetailRepository.update(
                id: record.id,
                draft: draft,
                expectedVersion: record.metadata.recordVersion,
                operationID: UUID(),
                member: member
            )
            guard confirmed.id == record.id,
                  confirmed.districtID == member.districtID,
                  confirmed.metadata.recordVersion > record.metadata.recordVersion,
                  router.setActiveStudent(confirmed) else {
                mutationError = .invalidResponse
                return .failed
            }
            record = confirmed
            return .confirmed
        } catch let error as StudentRepositoryError {
            mutationError = error
            if case .duplicate = error {
                return .duplicate
            }
            return .failed
        } catch {
            mutationError = .invalidResponse
            return .failed
        }
    }
}

private struct StaffShellModifier: ViewModifier {
    @Environment(AppRouter.self) private var router
    let notificationService: NotificationService?
    @Binding var showingSignOutConfirmation: Bool
    @Binding var showingSignOutFailure: Bool
    let attemptSignOut: @MainActor () -> Void

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .tint(.tmiPrimary)
            .sheet(item: $router.presentedSheet) { sheet in
                switch sheet {
                case .workspace:
                    WorkspacePanelView()
                        .tmiSheetStyle()
                }
            }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                attemptSignOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Couldn’t Sign Out", isPresented: $showingSignOutFailure) {
            Button("Retry", action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your account is still signed in. Check your connection and try again.")
        }
        .onAppear {
            guard let notificationService else {
                return
            }
            notificationService.startListening()
            Task { try? await notificationService.fetchNotifications() }
        }
        .onDisappear {
            notificationService?.stopListening()
        }
    }
}

// MARK: - Workspace Panel View

struct WorkspacePanelView: View {
    @Environment(\.studentContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    private var contextMatchesRouter: Bool {
        guard let activeStudentID = router.activeStudentID else { return false }
        return context.selectedStudentId == activeStudentID
            && context.cachedStudent?.id == activeStudentID
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tmiBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: TMISpacing.lg) {
                        // Active Student Section
                        if let student = router.activeStudent {
                            activeStudentSection(student)
                        } else {
                            noStudentSection
                        }

                        // Active Plan Section
                        if let plan = router.activePlan {
                            activePlanSection(plan)
                        }
                        
                        // Quick Stats
                        if contextMatchesRouter {
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
        TMICard(style: .default) {
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
                            .foregroundColor(Color.tmiTextPrimary)
                        
                        Text("Grade \(student.grade)")
                            .font(.subheadline)
                            .foregroundColor(.tmiTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        context.clearContext()
                        router.clearActiveStudent()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.tmiTextSecondary)
                    }
                }
                
                // Prefetched data indicators
                if contextMatchesRouter {
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
            }
            .padding()
        }
    }
    
    private var noStudentSection: some View {
        TMICard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiTextSecondary)
                
                Text("No Student Selected")
                    .font(.headline)
                    .foregroundColor(Color.tmiTextPrimary)
                
                Text("Select a student from the Students tab to start working")
                    .font(.caption)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private func activePlanSection(_ plan: TMIPlan) -> some View {
        TMICard(style: .default) {
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
                    .foregroundColor(Color.tmiTextPrimary)
                
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
            if router.activeStudent != nil {
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
                    .foregroundColor(Color.tmiTextOnPrimary)
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
                    .foregroundColor(Color.tmiTextPrimary)
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
    .environment(AppRouter())
}

#Preview("iPad") {
  MainTabView()
    .environment(AppRouter())
}
