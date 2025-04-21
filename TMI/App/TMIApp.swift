//
//  TMIApp.swift
//  TMI
//
//  Created by Chandan Brown on 9/12/24.
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authStateModel, AuthStateModel())
                .environment(\.dashboardStateModel, DashboardStateModel())
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @Environment(\.authStateModel) var authStateModel
    @State private var isShowingAuthentication = false
    
    var body: some View {
        Group {
            if authStateModel.isLoggedIn {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            // Check authentication status when the app appears
            if !authStateModel.isLoggedIn {
                isShowingAuthentication = true
            }
        }
    }
}
