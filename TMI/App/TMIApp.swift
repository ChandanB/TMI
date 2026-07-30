//
//  TMIApp.swift
//  TMI
//
//  Created by Chandan Brown on 9/12/24.
//
//  Main application entry point.
//  Configures Firebase and injects all shared state models into the environment.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct TMIApp: App {
    private let dependencies: AppDependencies
#if DEBUG
    private let uiTestingConfiguration: UITestingLaunchConfiguration
#endif

    @State private var authStateModel: AuthStateModel
    @State private var studentContext: StudentContextStateModel
    @State private var appRouter: AppRouter
    @State private var notificationService: NotificationService?
    @State private var scheduleMeetingCoordinator: ScheduleMeetingCoordinator?
    @State private var dashboardStateModel: DashboardStateModel?
    @State private var interestsStateModel: InterestsAndHobbiesStateModel?
    @State private var meetingsStateModel: MeetingsStateModel?
    @State private var districtStateModel: DistrictStateModel?
    @State private var recommendationsStateModel: RecommendationsStateModel?

    init() {
        let dependencies: AppDependencies
        let authStateModel: AuthStateModel

        let isRunningUnitTests = Self.isRunningUnitTests
        let usesInMemoryDependencies: Bool

#if DEBUG
        let uiTestingConfiguration = UITestingLaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments
        )
        self.uiTestingConfiguration = uiTestingConfiguration
        usesInMemoryDependencies = isRunningUnitTests || uiTestingConfiguration.isUITesting
#else
        usesInMemoryDependencies = isRunningUnitTests
#endif

        if usesInMemoryDependencies {
            dependencies = .preview()
            authStateModel = AuthStateModel(
                membershipProvider: dependencies.membership,
                featureFlags: dependencies.flags,
                automaticallyStart: false
            )
        } else {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }

            let firebaseManager = FirebaseManager.shared
            dependencies = .production(firestore: firebaseManager.firestore)
            authStateModel = AuthStateModel(
                firebaseManager: firebaseManager,
                authentication: dependencies.authentication,
                auditService: AuditService(),
                membershipProvider: dependencies.membership,
                authorizationSessionStore: .shared,
                featureFlags: dependencies.flags
            )
        }

        self.dependencies = dependencies

        _authStateModel = State(initialValue: authStateModel)
        _studentContext = State(initialValue: StudentContextStateModel())
        _appRouter = State(initialValue: AppRouter())
        _notificationService = State(
            initialValue: usesInMemoryDependencies ? nil : NotificationService.shared
        )
        _scheduleMeetingCoordinator = State(
            initialValue: usesInMemoryDependencies ? nil : ScheduleMeetingCoordinator()
        )
        _dashboardStateModel = State(
            initialValue: usesInMemoryDependencies ? nil : DashboardStateModel()
        )
        _interestsStateModel = State(
            initialValue: usesInMemoryDependencies ? nil : InterestsAndHobbiesStateModel()
        )
        _meetingsStateModel = State(
            initialValue: usesInMemoryDependencies ? nil : MeetingsStateModel()
        )
        _districtStateModel = State(
            initialValue: usesInMemoryDependencies ? nil : DistrictStateModel()
        )
        _recommendationsStateModel = State(
            initialValue: usesInMemoryDependencies ? nil : RecommendationsStateModel()
        )
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    var body: some Scene {
#if os(macOS)
        WindowGroup {
            rootContent
                .frame(minWidth: 900, minHeight: 700)
        }
        .defaultSize(width: 900, height: 800)
#else
        WindowGroup {
            rootContent
        }
#endif
    }

    @ViewBuilder
    private var rootContent: some View {
#if DEBUG
        if uiTestingConfiguration.isUITesting {
            uiTestingRootContent
        } else {
            standardRootContent
        }
#else
        standardRootContent
#endif
    }

#if DEBUG
    @ViewBuilder
    private var uiTestingRootContent: some View {
        switch uiTestingConfiguration.fixture {
        case .signedOut:
            signedOutUITestingContent
        case .authenticationAcceptance:
            AuthenticationAcceptanceUITestingContent()
        case .rosterPopulated,
             .rosterEmpty,
             .rosterOffline,
             .rosterPermissionDenied,
             .rosterCreateQueued,
             .rosterCreateSaving,
             .rosterArchived,
             .rosterCreateDuplicate,
             .rosterCreateConfirmed,
             .rosterWorkflow,
             .rosterCachePrime,
             .rosterCacheOffline:
            if let fixture = uiTestingConfiguration.fixture {
                rosterUITestingContent(fixture: fixture)
            }
        case .studentDetailPopulated,
             .studentDetailRelease1,
             .studentDetailOffline,
             .studentDetailPermissionDenied:
            if let fixture = uiTestingConfiguration.fixture {
                studentDetailUITestingContent(fixture: fixture)
            }
        case nil:
            ContentUnavailableView(
                "UI Test Fixture Unavailable",
                systemImage: "xmark.shield.fill",
                description: Text("Launch with a recognized fixture.")
            )
            .accessibilityIdentifier("uiTesting.fixtureUnavailable")
        }
    }

    @ViewBuilder
    private func rosterUITestingContent(
        fixture: UITestingLaunchConfiguration.Fixture
    ) -> some View {
        if uiTestingConfiguration.contentSize == .accessibility5 {
#if os(macOS)
            StudentRosterUITestingContent(fixture: fixture.rawValue)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .dynamicTypeSize(.accessibility5)
#else
            StudentRosterUITestingContent(fixture: fixture.rawValue)
                .dynamicTypeSize(.accessibility5)
#endif
        } else {
            StudentRosterUITestingContent(fixture: fixture.rawValue)
        }
    }

    @ViewBuilder
    private func studentDetailUITestingContent(
        fixture: UITestingLaunchConfiguration.Fixture
    ) -> some View {
        if uiTestingConfiguration.contentSize == .accessibility5 {
#if os(macOS)
            StudentDetailUITestingContent(fixture: fixture.rawValue)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .dynamicTypeSize(.accessibility5)
#else
            StudentDetailUITestingContent(fixture: fixture.rawValue)
                .dynamicTypeSize(.accessibility5)
#endif
        } else {
            StudentDetailUITestingContent(fixture: fixture.rawValue)
        }
    }
#endif

    @ViewBuilder
    private var standardRootContent: some View {
        if let notificationService,
           let scheduleMeetingCoordinator,
           let dashboardStateModel,
           let interestsStateModel,
           let meetingsStateModel,
           let districtStateModel,
           let recommendationsStateModel {
            ContentView()
                // Core state models
                .environment(\.appDependencies, dependencies)
                .environment(\.authStateModel, authStateModel)
                .environment(\.studentContext, studentContext)
                .environment(appRouter)
                .environment(scheduleMeetingCoordinator)
                .environment(\.notificationService, notificationService)
                
                // Domain state models
                .environment(\.dashboardStateModel, dashboardStateModel)
                .environment(\.interestsStateModel, interestsStateModel)
                .environment(\.meetingsStateModel, meetingsStateModel)
                .environment(\.districtStateModel, districtStateModel)
                .environment(\.recommendationsStateModel, recommendationsStateModel)

                .tint(TMIColors.teal)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    do {
                        appRouter.updatePolicy(
                            AppNavigationPolicy(membership: authStateModel.currentMembership)
                        )
                        try appRouter.enqueueDeepLink(url)
                    } catch {
                        dependencies.logger.warning("deep_link_rejected")
                    }
                }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }

#if DEBUG
    @ViewBuilder
    private var signedOutUITestingContent: some View {
        if uiTestingConfiguration.contentSize == .accessibility5 {
#if os(macOS)
            signedOutUITestingBase
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .dynamicTypeSize(.accessibility5)
#else
            signedOutUITestingBase
                .dynamicTypeSize(.accessibility5)
#endif
        } else {
            signedOutUITestingBase
        }
    }

    private var signedOutUITestingBase: some View {
        AuthenticationView()
            .environment(\.appDependencies, dependencies)
            .environment(\.authStateModel, authStateModel)
            .tint(TMIColors.teal)
            .preferredColorScheme(.light)
    }
#endif
}

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) var authStateModel
    @Environment(\.studentContext) var studentContext
    @Environment(\.districtStateModel) var districtStateModel
    @Environment(AppRouter.self) private var appRouter
    
    @State private var hasBootstrapped = false

    var body: some View {
        Group {
            if authStateModel.isCheckingAuth {
                LoadingView()
            } else if authStateModel.isLoggedIn {
                authenticatedContent
            } else if authStateModel.requiresStaffAccessSetup {
                StaffAccessSetupView()
            } else if authStateModel.canRetryAuthorization {
                AuthenticationRecoveryView()
            } else {
                AuthenticationView()
            }
        }
        .foregroundColor(Color.tmiTextPrimary)
        .foregroundStyle(Color.tmiTextPrimary)
        .onChange(of: authStateModel.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                Task {
                    await self.performBootstrap(for: self.accountAccess)
                }
            } else {
                // Clear state on logout
                Task {
                    await MainActor.run {
                        studentContext.clearContext()
                        districtStateModel.clearState()
                        appRouter.reset()
                        hasBootstrapped = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        let access = accountAccess

        Group {
            switch access.destination {
            case .student:
                StudentMainView()
                    .environment(\.studentAccessMode, .signedInStudent)
            case .staff:
                MainTabView()
                    .environment(\.studentAccessMode, .staffViewing)
            case .guardian:
                AccountUnavailableView(
                    title: "Guardian Account Unavailable",
                    description: "Guardian accounts are not available in this version of TMI.",
                    signOutAction: authStateModel.signOut
                )
            case .unavailable:
                AccountUnavailableView(
                    title: "Account Unavailable",
                    description: "This account type is not available in this version of TMI.",
                    signOutAction: authStateModel.signOut
                )
            }
        }
        .task(id: access) {
            await self.performBootstrap(for: access)
        }
    }

    private var accountAccess: FeatureFlags.AccountAccess {
        dependencies.flags.authenticatedAccountAccess(
            for: authStateModel.currentMembership
        )
    }

    private func performBootstrap(for access: FeatureFlags.AccountAccess) async {
        guard
            !hasBootstrapped,
            access.canBootstrap,
            let membership = authStateModel.currentMembership,
            dependencies.flags.authenticatedAccountAccess(for: membership) == access
        else {
            return
        }

        hasBootstrapped = true
        
        await AppBootstrapService.shared.warmStart(membership: membership)
        
        // Load district context if applicable
        if membership.role == .districtAdministrator,
           AuthorizationPolicy.canViewAggregate(
            membership,
            districtID: membership.districtID
           ) {
            await districtStateModel.loadDistrict(id: membership.districtID)
        }
        
        dependencies.logger.info(
            "bootstrap_completed",
            metadata: [
                "membershipRole": membership.role.rawValue,
                "districtID": membership.districtID,
            ]
        )
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo or icon
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.tmiPrimary)
                
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(Color.tmiTextPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let dependencies = AppDependencies.preview()

    ContentView()
        .environment(\.appDependencies, dependencies)
        .environment(
            \.authStateModel,
            AuthStateModel(
                membershipProvider: dependencies.membership,
                automaticallyStart: false
            )
        )
        .environment(\.studentContext, StudentContextStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
        .environment(AppRouter())
}
