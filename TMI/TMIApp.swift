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
    @State private var authViewModel = AuthenticationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var isShowingAuthentication = false
    
    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            // Check authentication status when the app appears
            if !authViewModel.isLoggedIn {
                isShowingAuthentication = true
            }
        }
    }
}
