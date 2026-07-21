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

    @State private var authStateModel: AuthStateModel
    @State private var studentContext: StudentContextStateModel
    @State private var deepLinkRouter: DeepLinkRouter
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

        if isRunningUnitTests {
            dependencies = .preview()
            authStateModel = AuthStateModel(
                membershipProvider: dependencies.membership,
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
                auditService: AuditService(),
                membershipProvider: dependencies.membership,
                authorizationSessionStore: .shared
            )
        }

        self.dependencies = dependencies

        _authStateModel = State(initialValue: authStateModel)
        _studentContext = State(initialValue: StudentContextStateModel())
        _deepLinkRouter = State(initialValue: DeepLinkRouter())
        _notificationService = State(
            initialValue: isRunningUnitTests ? nil : NotificationService.shared
        )
        _scheduleMeetingCoordinator = State(
            initialValue: isRunningUnitTests ? nil : ScheduleMeetingCoordinator()
        )
        _dashboardStateModel = State(
            initialValue: isRunningUnitTests ? nil : DashboardStateModel()
        )
        _interestsStateModel = State(
            initialValue: isRunningUnitTests ? nil : InterestsAndHobbiesStateModel()
        )
        _meetingsStateModel = State(
            initialValue: isRunningUnitTests ? nil : MeetingsStateModel()
        )
        _districtStateModel = State(
            initialValue: isRunningUnitTests ? nil : DistrictStateModel()
        )
        _recommendationsStateModel = State(
            initialValue: isRunningUnitTests ? nil : RecommendationsStateModel()
        )
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    @ViewBuilder
    private var rootContent: some View {
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
                .environment(deepLinkRouter)
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
                    // Handle deep links
                    Task {
                        await deepLinkRouter.handleIncomingURL(url)
                    }
                }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }
}

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) var authStateModel
    @Environment(\.studentContext) var studentContext
    @Environment(\.districtStateModel) var districtStateModel
    
    @State private var hasBootstrapped = false

    var body: some View {
        Group {
            if authStateModel.isCheckingAuth {
                LoadingView()
            } else if authStateModel.isLoggedIn {
                authenticatedContent
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
}
