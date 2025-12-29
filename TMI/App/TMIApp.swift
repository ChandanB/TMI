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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct TMIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // MARK: - Shared State Models
    
    // Core authentication state
    @State private var authStateModel = AuthStateModel()
    
    // Shared student context (the key new addition)
    @State private var studentContext = StudentContextStateModel()
    
    // Deep link router
    @State private var deepLinkRouter = DeepLinkRouter()
    
    // Domain state models
    @State private var dashboardStateModel = DashboardStateModel()
    @State private var interestsStateModel = InterestsAndHobbiesStateModel()
    @State private var meetingsStateModel = MeetingsStateModel()
    @State private var districtStateModel = DistrictStateModel()
    @State private var recommendationsStateModel = RecommendationsStateModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Core state models
                .environment(\.authStateModel, authStateModel)
                .environment(\.studentContext, studentContext)
                .environment(\.deepLinkRouter, deepLinkRouter)
                
                // Domain state models
                .environment(\.dashboardStateModel, dashboardStateModel)
                .environment(\.interestsStateModel, interestsStateModel)
                .environment(\.meetingsStateModel, meetingsStateModel)
                .environment(\.districtStateModel, districtStateModel)
                .environment(\.recommendationsStateModel, recommendationsStateModel)
                
                .preferredColorScheme(.dark)
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
    @Environment(\.authStateModel) var authStateModel
    @Environment(\.studentContext) var studentContext
    @Environment(\.districtStateModel) var districtStateModel
    
    @State private var hasBootstrapped = false

    var body: some View {
        Group {
            if authStateModel.isLoading {
                LoadingView()
            } else if authStateModel.isLoggedIn {
                authenticatedContent
            } else {
                AuthenticationView()
            }
        }
        .foregroundColor(.white)
        .foregroundStyle(.white)
        .onChange(of: authStateModel.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                Task {
                    await performBootstrap()
                }
            } else {
                // Clear state on logout
                Task {
                    studentContext.clearContext()
                    districtStateModel.clearState()
                    hasBootstrapped = false
                }
            }
        }
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        Group {
            // Route based on user role
            if authStateModel.currentUser?.role == .student {
                StudentMainView()
                    .environment(\.studentAccessMode, .signedInStudent)
            } else {
                // Staff/parent view
                MainTabView()
                    .environment(\.studentAccessMode, .staffViewing)
            }
        }
        .task {
            if !hasBootstrapped {
                await performBootstrap()
            }
        }
    }
    
    private func performBootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        
        // Bootstrap the app with user's context
        let districtId = authStateModel.currentUser?.districtId
        let role = authStateModel.currentUser?.role ?? .student
        
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
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.authStateModel, AuthStateModel())
        .environment(\.studentContext, StudentContextStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
}

