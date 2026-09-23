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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(AppRouter.self) private var router
    @Environment(\.notificationService) private var notificationService
    @Environment(\.programContext) private var programContext
    @State private var showingSearch = false
    /// iPhone/iPad only: the Search tab is shell-local, not an `AppTab`, so
    /// the router's tab policy and path semantics stay unchanged.
    @State private var isSearchTabSelected = false
    
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
            switch studentModeSession.rootPresentation {
            case .student(let studentProfile):
                // Student Mode - Restricted Interface
                StudentModeView(profile: studentProfile)
                    .environment(\.studentModeSession, studentModeSession)
                    .environment(\.studentAccessMode, .studentMode)
                    .onAppear {
                        dependencies.logger.info(
                            "student_mode_entered",
                            metadata: ["studentID": studentProfile.studentID]
                        )
                    }
            case .staff:
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
        .task(id: studentModeStartupIdentity) {
            await restoreStudentModeStartup()
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
            studentModeSession.handleSceneTransition(
                from: oldPhase,
                to: newPhase
            )
        }
    }

    private var studentModeStartupIdentity: String? {
        authStateModel.currentMembership.map {
            "\($0.districtID):\($0.userID):\($0.version)"
        }
    }

    private func restoreStudentModeStartup() async {
        if let repository = dependencies.studentModeRepository,
           let membership = authStateModel.currentMembership {
            studentModeSession.configureSecureExit(repository: repository)
            await studentModeSession.restorePersistedContainment(
                repository: repository,
                staffIdentity: StudentModeStaffIdentity(
                    userID: membership.userID,
                    districtID: membership.districtID,
                    membershipVersion: membership.version
                )
            )
        } else if dependencies.runtime != .production {
            studentModeSession.completeNonProductionStartup()
        }
    }
    
    // MARK: - Staff Tab View

    @ViewBuilder
    private var staffTabView: some View {
#if os(macOS)
        macStaffNavigation
            .modifier(StaffShellModifier(
                notificationService: notificationService,
                member: authStateModel.currentMembership,
                showingSignOutConfirmation: $showingSignOutConfirmation,
                showingSignOutFailure: $showingSignOutFailure,
                attemptSignOut: attemptSignOut
            ))
#else
        mobileStaffNavigation
            .modifier(StaffShellModifier(
                notificationService: notificationService,
                member: authStateModel.currentMembership,
                showingSignOutConfirmation: $showingSignOutConfirmation,
                showingSignOutFailure: $showingSignOutFailure,
                attemptSignOut: attemptSignOut
            ))
#endif
    }

    private var terminology: Terminology { programContext.shell.terminology }

    /// Each tab owns its own `NavigationStack`, so the Liquid Glass tab bar
    /// stays visible while pushing. Only the selected tab's stack is bound to
    /// `router.path`; the router clears the path on every tab switch, so an
    /// unselected tab is always at its root.
    private var mobileStaffNavigation: some View {
        TabView(selection: tabSelection) {
            ForEach(router.availableTabs) { tab in
                Tab(tab.title(for: terminology), systemImage: tab.systemImage, value: ShellTab.app(tab)) {
                    tabStack(for: tab)
                }
            }
            Tab(value: ShellTab.search, role: .search) {
                GlobalSearchView(onOpen: { isSearchTabSelected = false })
            }
        }
        .tabViewStyle(.sidebarAdaptable)
#if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
#endif
    }

    private var tabSelection: Binding<ShellTab> {
        Binding(
            get: { isSearchTabSelected ? .search : .app(router.selectedTab) },
            set: { selection in
                switch selection {
                case .search:
                    isSearchTabSelected = true
                case .app(let tab):
                    isSearchTabSelected = false
                    if tab != router.selectedTab {
                        try? router.select(tab)
                    }
                }
            }
        )
    }

    private func tabStack(for tab: AppTab) -> some View {
        NavigationStack(path: path(for: tab)) {
            destinationView(for: tab)
                .navigationTitle(tab.title(for: terminology))
                .navigationDestination(for: AppRoute.self) { route in
                    routeDestination(route)
                }
                .toolbar { staffToolbar }
        }
    }

    private func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { router.selectedTab == tab ? router.path : [] },
            set: { newPath in
                if router.selectedTab == tab {
                    router.path = newPath
                }
            }
        )
    }

#if os(macOS)
    /// A native source-list sidebar. Tab shortcuts (⌘1–⌘4), Back (⌘[) and
    /// Settings (⌘,) live in `StaffCommands` so they appear in the menu bar.
    private var macStaffNavigation: some View {
        @Bindable var router = router

        return NavigationSplitView {
            List(selection: sidebarSelection) {
                Section {
                    ForEach(router.availableTabs) { tab in
                        Label(tab.title(for: terminology), systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                Section("Forms & meetings") {
                    Button {
                        try? router.open(.formAssignments)
                    } label: {
                        Label("Form Assignments", systemImage: "list.bullet.rectangle")
                    }
                    Button {
                        try? router.open(.meetings)
                    } label: {
                        Label("Meetings", systemImage: "calendar")
                    }
                    Button {
                        try? router.open(.formTemplates)
                    } label: {
                        Label("Form Templates", systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(.plain)
                Section("You") {
                    Button {
                        try? router.open(.tasks)
                    } label: {
                        Label("My Tasks", systemImage: "checklist")
                    }
                    Button {
                        try? router.open(.profile)
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
            .safeAreaInset(edge: .bottom) {
                sidebarAccountFooter
            }
        } detail: {
            NavigationStack(path: $router.path) {
                destinationView(for: router.selectedTab)
                    .navigationTitle(router.selectedTab.title(for: terminology))
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(route)
                    }
                    .toolbar { staffToolbar }
            }
            .sheet(isPresented: $showingSearch) { GlobalSearchView() }
        }
        .focusedSceneValue(\.staffRouter, router)
    }

    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { router.selectedTab },
            set: { tab in
                if let tab, tab != router.selectedTab {
                    try? router.select(tab)
                }
            }
        )
    }

    private var sidebarAccountFooter: some View {
        Menu {
            accountMenuItems
        } label: {
            HStack(spacing: TMISpacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(TMIColors.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Account")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TMIColors.textPrimary)
                    if let role = authStateModel.currentMembership?.role {
                        Text(role.displayName)
                            .font(.caption)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TMIColors.textTertiary)
            }
            .padding(.horizontal, TMISpacing.ms)
            .padding(.vertical, TMISpacing.sm)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .padding(TMISpacing.sm)
        .accessibilityLabel("Account")
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
            SyncStatusButton { try? router.open(.sync) }
#if os(macOS)
            Button {
                showingSearch = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: [.command])
            .help("Search students, plans and resources (⌘F)")
            .accessibilityIdentifier("main.search")
#endif
            if notificationService != nil {
                NotificationBellButton()
            }
#if !os(macOS)
            profileMenu
#endif
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
                    TMIAvatar(initials: student.initials, size: 24)
                } else {
                    Image(systemName: "person.crop.circle")
                }
                Text(router.activeStudentName ?? "Selected Student")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .help("Open the workspace for the selected student")
        .accessibilityLabel("Open workspace for \(router.activeStudentName ?? "selected student")")
    }

    @ViewBuilder
    private var accountMenuItems: some View {
        Button {
            try? router.open(.profile)
        } label: {
            Label("Profile", systemImage: "person.crop.circle")
        }

        Button {
            try? router.open(.tasks)
        } label: {
            Label("My Tasks", systemImage: "checklist")
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
    }

    private var profileMenu: some View {
        Menu {
            accountMenuItems
        } label: {
            Label("Account", systemImage: "person.crop.circle")
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
            CanonicalPlanListView()
        case .district:
            DistrictReportView()
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
            CanonicalPlanDetailView(planID: planID)
        case .profile:
            UserProfileView()
        case .settings:
            SettingsView()
        case .tasks:
            TaskListView()
        case .sync:
            SyncStatusView()
        case .formAssignments:
            StaffAssignmentListView()
        case .formTemplates:
            FormTemplateLibraryView()
        case .meetings:
            MeetingsHubView()
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
            if case .duplicate(let candidateIDs) = error {
                return .duplicate(candidateIDs: candidateIDs)
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
    let member: MembershipContext?
    @Binding var showingSignOutConfirmation: Bool
    @Binding var showingSignOutFailure: Bool
    let attemptSignOut: @MainActor () -> Void

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
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
        .task(id: member) {
            guard let notificationService else {
                return
            }
            guard let member else {
                notificationService.stopListening()
                return
            }
            notificationService.startListening(member: member)
            try? await notificationService.fetchNotifications(member: member)
        }
        .onDisappear {
            notificationService?.stopListening()
        }
    }
}

// MARK: - Shell selection

/// iPhone/iPad tab selection: an app tab or the shell-local Search tab.
private enum ShellTab: Hashable {
    case app(AppTab)
    case search
}

extension FocusedValues {
    /// The router of the focused staff window (drives menu-bar commands).
    @Entry var staffRouter: AppRouter?
}

/// Menu-bar commands for the staff shell on Mac (and iPad keyboards).
struct StaffCommands: Commands {
    @FocusedValue(\.staffRouter) private var router

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                Button(tab.title) {
                    try? router?.select(tab)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                .disabled(!(router?.availableTabs.contains(tab) ?? false))
            }

            Divider()

            Button("Back") {
                router?.pop()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(router?.path.isEmpty ?? true)

            Divider()

            Button("My Tasks") {
                try? router?.open(.tasks)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(router == nil)

            Button("Sync Status") {
                try? router?.open(.sync)
            }
            .disabled(router == nil)
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                try? router?.open(.settings)
            }
            .keyboardShortcut(",", modifiers: .command)
            .disabled(router == nil)
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
                            .font(.title2)
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
                    .font(.largeTitle)
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
                    value: "\(context.prefetchedPlans.count)",
                    label: "Plans"
                )
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
                .font(.subheadline)
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
                    .font(.caption)
                    .foregroundColor(.tmiPrimary)
                
                Text(value)
                    .font(.body.weight(.bold))
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
