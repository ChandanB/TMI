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
                .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @Environment(\.authStateModel) var authStateModel

    var body: some View {
        if authStateModel.isLoading {
            VStack {
                Spacer()
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
        } else {
            Group {
                if authStateModel.isLoggedIn {
                    // Route based on user role
                    if authStateModel.currentUser?.role == .student {
                        StudentMainView()
                    } else {
                        // Staff/parent view
                        MainTabView()
                    }
                } else {
                    AuthenticationView()
                }
            }
            .foregroundColor(.white)
            .foregroundStyle(.white)
        }
    }
}


#Preview {
    ContentView()
        .environment(\.authStateModel, AuthStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
}

