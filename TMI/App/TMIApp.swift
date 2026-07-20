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
    private let dependencies: AppDependencies = .production

    @State private var authStateModel: AuthStateModel
    @State private var studentContext: StudentContextStateModel
    @State private var deepLinkRouter: DeepLinkRouter
    @State private var dashboardStateModel: DashboardStateModel
    @State private var interestsStateModel: InterestsAndHobbiesStateModel
    @State private var meetingsStateModel: MeetingsStateModel
    @State private var districtStateModel: DistrictStateModel
    @State private var recommendationsStateModel: RecommendationsStateModel

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        _authStateModel = State(initialValue: AuthStateModel())
        _studentContext = State(initialValue: StudentContextStateModel())
        _deepLinkRouter = State(initialValue: DeepLinkRouter())
        _dashboardStateModel = State(initialValue: DashboardStateModel())
        _interestsStateModel = State(initialValue: InterestsAndHobbiesStateModel())
        _meetingsStateModel = State(initialValue: MeetingsStateModel())
        _districtStateModel = State(initialValue: DistrictStateModel())
        _recommendationsStateModel = State(initialValue: RecommendationsStateModel())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Core state models
                .environment(\.appDependencies, dependencies)
                .environment(\.authStateModel, authStateModel)
                .environment(\.studentContext, studentContext)
                .environment(\.deepLinkRouter, deepLinkRouter)
                
                // Domain state models
                .environment(\.dashboardStateModel, dashboardStateModel)
                .environment(\.interestsStateModel, interestsStateModel)
                .environment(\.meetingsStateModel, meetingsStateModel)
                .environment(\.districtStateModel, districtStateModel)
                .environment(\.recommendationsStateModel, recommendationsStateModel)
                
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Handle deep links
                    Task {
                        await deepLinkRouter.handleIncomingURL(url)
                    }
                }
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
        dependencies.flags.accountAccess(for: authStateModel.currentUser?.role)
    }

    private func performBootstrap(for access: FeatureFlags.AccountAccess) async {
        guard
            !hasBootstrapped,
            access.canBootstrap,
            let role = authStateModel.currentUser?.role,
            dependencies.flags.accountAccess(for: role) == access
        else {
            return
        }

        hasBootstrapped = true
        
        // Bootstrap the app with user's context
        let districtId = authStateModel.currentUser?.districtId
        
        await AppBootstrapService.shared.warmStart(
            districtId: districtId,
            role: role
        )
        
        // Load district context if applicable
        if let districtId = districtId, role.isDistrictRole {
            await districtStateModel.loadDistrict(id: districtId)
        }
        
        print("[TMIApp] Bootstrap complete for role: \(role.rawValue)")
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
    ContentView()
        .environment(\.appDependencies, .production)
        .environment(\.authStateModel, AuthStateModel())
        .environment(\.studentContext, StudentContextStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
}
