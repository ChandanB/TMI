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
    @State private var isShowingAuthentication = false
    @State private var navigationCoordinator = NavigationCoordinator.shared
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            Group {
                if authStateModel.isAuthenticated {
                    MainTabView()
                } else {
                    AuthenticationView()
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .foregroundColor(.white)
        .foregroundStyle(.white)
        .onAppear {
            // Check authentication status when the app appears
            if !authStateModel.isAuthenticated {
                isShowingAuthentication = true
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .studentDetail(let student):
            StudentDetailView(student: student)
        case .addStudent:
            AddStudentView(onStudentAdded: {
                // Handle student added - could trigger refresh via notification or other means
                NavigationCoordinator.shared.pop()
            })
        case .formDetail(let template):
            FormTemplateDetailView(template: template)
        case .formCreation:
            FormCreationView()
        case .formBuilder:
            FormTemplateBuilderView()
        case .studentFormSubmissions(let studentId):
            FormSubmissionsView(studentId: studentId)
        case .userFormSubmissions(let userId):
            FormSubmissionsView(userId: userId)
        case .dynamicForm(let templateId):
            DynamicFormView(templateId: templateId)
        case .careerDetail(let career):
            CareerDetailView(career: career)
        case .dashboardInsights(let data):
            DashboardInsightsView(dashboardData: data)
        case .userProfile:
            UserProfileView()
        case .changePassword:
            ChangePasswordView()
        case .settings:
            SettingsView()
        case .recommendations(let student):
            RecommendationsView(student: student)
        case .resources:
            ResourcesView()
        case .interestsAndHobbies:
            InterestsAndHobbiesView()
        case .tmiPlanDetail(let tmiPlan):
            TMIPlanDetailView(plan: tmiPlan)
        case .newTMIPlan:
            NewTMIPlanView()
        }
    }
}


#Preview {
    ContentView()
        .environment(\.simpleAuthStateModel, SimpleAuthStateModel())
        .environment(\.dashboardStateModel, DashboardStateModel())
}

