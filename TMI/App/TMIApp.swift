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
                .environment(\.simpleAuthStateModel, SimpleAuthStateModel())
                .environment(\.dashboardStateModel, DashboardStateModel())
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @Environment(\.simpleAuthStateModel) var authStateModel
    
    var body: some View {
        Group {
            if authStateModel.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .foregroundColor(.white)
        .foregroundStyle(.white)
    }
}


#Preview {
    ContentView()
        .environment(\.simpleAuthStateModel, SimpleAuthStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
}

