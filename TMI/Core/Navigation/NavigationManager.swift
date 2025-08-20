//
//  NavigationManager.swift
//  TMI
//
//  Created by Claude Code on 8/19/25.
//

import Foundation
import SwiftUI
import Observation

// MARK: - App Routes

/// Type-safe routing system for the TMI app
enum AppRoute: Hashable, Sendable {
    // Student routes
    case studentList
    case studentDetail(Student.ID)
    case addStudent
    case editStudent(Student.ID)
    case studentInterests(Student.ID)
    
    // TMI Plan routes
    case planList
    case planDetail(TMIPlan.ID)
    case addPlan
    case editPlan(TMIPlan.ID)
    case planProgress(TMIPlan.ID)
    
    // Career routes
    case careerExplorer
    case careerDetail(String) // Career ID
    case careerResources
    
    // Settings routes
    case settings
    case profile
    case preferences
    case about
    case help
    
    // Forms routes
    case formsList
    case formBuilder
    case formDetail(String) // Form ID
    case formSubmissions
    
    // Resources routes
    case resourcesList
    case resourceDetail(String) // Resource ID
    case resourceCategories
    
    var title: String {
        switch self {
        case .studentList: return "Students"
        case .studentDetail: return "Student Details"
        case .addStudent: return "Add Student"
        case .editStudent: return "Edit Student"
        case .studentInterests: return "Student Interests"
            
        case .planList: return "TMI Plans"
        case .planDetail: return "Plan Details"
        case .addPlan: return "Create Plan"
        case .editPlan: return "Edit Plan"
        case .planProgress: return "Plan Progress"
            
        case .careerExplorer: return "Career Explorer"
        case .careerDetail: return "Career Details"
        case .careerResources: return "Career Resources"
            
        case .settings: return "Settings"
        case .profile: return "Profile"
        case .preferences: return "Preferences"
        case .about: return "About"
        case .help: return "Help"
            
        case .formsList: return "Forms"
        case .formBuilder: return "Form Builder"
        case .formDetail: return "Form Details"
        case .formSubmissions: return "Submissions"
            
        case .resourcesList: return "Resources"
        case .resourceDetail: return "Resource Details"
        case .resourceCategories: return "Categories"
        }
    }
    
    var icon: String {
        switch self {
        case .studentList, .studentDetail, .addStudent, .editStudent, .studentInterests:
            return "person.2.fill"
        case .planList, .planDetail, .addPlan, .editPlan, .planProgress:
            return "doc.text.fill"
        case .careerExplorer, .careerDetail, .careerResources:
            return "graduationcap.fill"
        case .settings, .profile, .preferences:
            return "gear"
        case .about, .help:
            return "info.circle"
        case .formsList, .formBuilder, .formDetail, .formSubmissions:
            return "list.clipboard"
        case .resourcesList, .resourceDetail, .resourceCategories:
            return "books.vertical"
        }
    }
}

// MARK: - Tab Selection

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case students = "Students"
    case plans = "TMI Plans"
    case career = "Career"
    case forms = "Forms"
    case resources = "Resources"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .students: return "person.2.fill"
        case .plans: return "doc.text.fill"
        case .career: return "graduationcap.fill"
        case .forms: return "list.clipboard"
        case .resources: return "books.vertical"
        case .settings: return "gear"
        }
    }
    
    var iconSelected: String {
        switch self {
        case .students: return "person.2.fill"
        case .plans: return "doc.text.fill"
        case .career: return "graduationcap.fill"
        case .forms: return "list.clipboard.fill"
        case .resources: return "books.vertical.fill"
        case .settings: return "gear.fill"
        }
    }
}

// MARK: - Navigation Manager

/// Modern navigation manager using iOS 26 NavigationPath and type-safe routing
@Observable
@MainActor
final class NavigationManager: Sendable {
    
    // MARK: - Properties
    
    // Tab selection
    private(set) var selectedTab: AppTab = .students
    
    // Navigation paths for each tab
    private(set) var studentsPath = NavigationPath()
    private(set) var plansPath = NavigationPath()
    private(set) var careerPath = NavigationPath()
    private(set) var formsPath = NavigationPath()
    private(set) var resourcesPath = NavigationPath()
    private(set) var settingsPath = NavigationPath()
    
    // Current route tracking
    private(set) var currentRoute: AppRoute?
    
    // Navigation history
    private var navigationHistory: [AppRoute] = []
    private let maxHistorySize = 50
    
    // Deep link handling
    private var pendingDeepLink: AppRoute?
    
    // MARK: - Tab Navigation
    
    /// Switch to a specific tab
    func selectTab(_ tab: AppTab) {
        selectedTab = tab
        updateCurrentRoute()
    }
    
    /// Get the current navigation path for the selected tab
    var currentPath: NavigationPath {
        switch selectedTab {
        case .students: return studentsPath
        case .plans: return plansPath
        case .career: return careerPath
        case .forms: return formsPath
        case .resources: return resourcesPath
        case .settings: return settingsPath
        }
    }
    
    // MARK: - Route Navigation
    
    /// Navigate to a specific route
    func navigate(to route: AppRoute) {
        // Switch to appropriate tab if needed
        let targetTab = getTab(for: route)
        if selectedTab != targetTab {
            selectTab(targetTab)
        }
        
        // Navigate within the tab
        switch targetTab {
        case .students:
            navigateInStudentsTab(to: route)
        case .plans:
            navigateInPlansTab(to: route)
        case .career:
            navigateInCareerTab(to: route)
        case .forms:
            navigateInFormsTab(to: route)
        case .resources:
            navigateInResourcesTab(to: route)
        case .settings:
            navigateInSettingsTab(to: route)
        }
        
        addToHistory(route)
        currentRoute = route
    }
    
    /// Pop to root for current tab
    func popToRoot() {
        popToRoot(for: selectedTab)
    }
    
    /// Pop to root for specific tab
    func popToRoot(for tab: AppTab) {
        switch tab {
        case .students:
            studentsPath = NavigationPath()
            currentRoute = .studentList
        case .plans:
            plansPath = NavigationPath()
            currentRoute = .planList
        case .career:
            careerPath = NavigationPath()
            currentRoute = .careerExplorer
        case .forms:
            formsPath = NavigationPath()
            currentRoute = .formsList
        case .resources:
            resourcesPath = NavigationPath()
            currentRoute = .resourcesList
        case .settings:
            settingsPath = NavigationPath()
            currentRoute = .settings
        }
    }
    
    /// Pop the last route from current tab
    func pop() {
        switch selectedTab {
        case .students:
            if !studentsPath.isEmpty {
                studentsPath.removeLast()
            }
        case .plans:
            if !plansPath.isEmpty {
                plansPath.removeLast()
            }
        case .career:
            if !careerPath.isEmpty {
                careerPath.removeLast()
            }
        case .forms:
            if !formsPath.isEmpty {
                formsPath.removeLast()
            }
        case .resources:
            if !resourcesPath.isEmpty {
                resourcesPath.removeLast()
            }
        case .settings:
            if !settingsPath.isEmpty {
                settingsPath.removeLast()
            }
        }
        updateCurrentRoute()
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep link navigation
    func handleDeepLink(_ url: URL) {
        guard let route = parseDeepLink(url) else { return }
        
        // If the app is ready, navigate immediately
        // Otherwise, store for later
        if isReadyForNavigation() {
            navigate(to: route)
        } else {
            pendingDeepLink = route
        }
    }
    
    /// Process any pending deep links
    func processPendingDeepLink() {
        if let pendingRoute = pendingDeepLink {
            pendingDeepLink = nil
            navigate(to: pendingRoute)
        }
    }
    
    /// Generate deep link URL for a route
    func generateDeepLink(for route: AppRoute) -> URL? {
        let baseURL = "tmi://"
        
        switch route {
        case .studentDetail(let id):
            return URL(string: "\(baseURL)students/\(id ?? "")")
        case .planDetail(let id):
            return URL(string: "\(baseURL)plans/\(id ?? "")")
        case .careerDetail(let id):
            return URL(string: "\(baseURL)career/\(id)")
        case .formDetail(let id):
            return URL(string: "\(baseURL)forms/\(id)")
        case .resourceDetail(let id):
            return URL(string: "\(baseURL)resources/\(id)")
        default:
            return URL(string: "\(baseURL)\(route.title.lowercased())")
        }
    }
    
    // MARK: - Navigation History
    
    /// Get navigation history
    var history: [AppRoute] {
        navigationHistory
    }
    
    /// Check if can go back
    var canGoBack: Bool {
        !navigationHistory.isEmpty
    }
    
    /// Navigate back to previous route
    func goBack() {
        guard let previousRoute = navigationHistory.popLast() else { return }
        navigate(to: previousRoute)
    }
    
    /// Clear navigation history
    func clearHistory() {
        navigationHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func getTab(for route: AppRoute) -> AppTab {
        switch route {
        case .studentList, .studentDetail, .addStudent, .editStudent, .studentInterests:
            return .students
        case .planList, .planDetail, .addPlan, .editPlan, .planProgress:
            return .plans
        case .careerExplorer, .careerDetail, .careerResources:
            return .career
        case .formsList, .formBuilder, .formDetail, .formSubmissions:
            return .forms
        case .resourcesList, .resourceDetail, .resourceCategories:
            return .resources
        case .settings, .profile, .preferences, .about, .help:
            return .settings
        }
    }
    
    private func navigateInStudentsTab(to route: AppRoute) {
        switch route {
        case .studentDetail(let id):
            studentsPath.append(id ?? "")
        case .addStudent:
            studentsPath.append("add")
        case .editStudent(let id):
            studentsPath.append("edit/\(id ?? "")")
        case .studentInterests(let id):
            studentsPath.append("interests/\(id ?? "")")
        default:
            break
        }
    }
    
    private func navigateInPlansTab(to route: AppRoute) {
        switch route {
        case .planDetail(let id):
            plansPath.append(id ?? "")
        case .addPlan:
            plansPath.append("add")
        case .editPlan(let id):
            plansPath.append("edit/\(id ?? "")")
        case .planProgress(let id):
            plansPath.append("progress/\(id ?? "")")
        default:
            break
        }
    }
    
    private func navigateInCareerTab(to route: AppRoute) {
        switch route {
        case .careerDetail(let id):
            careerPath.append(id)
        case .careerResources:
            careerPath.append("resources")
        default:
            break
        }
    }
    
    private func navigateInFormsTab(to route: AppRoute) {
        switch route {
        case .formBuilder:
            formsPath.append("builder")
        case .formDetail(let id):
            formsPath.append(id)
        case .formSubmissions:
            formsPath.append("submissions")
        default:
            break
        }
    }
    
    private func navigateInResourcesTab(to route: AppRoute) {
        switch route {
        case .resourceDetail(let id):
            resourcesPath.append(id)
        case .resourceCategories:
            resourcesPath.append("categories")
        default:
            break
        }
    }
    
    private func navigateInSettingsTab(to route: AppRoute) {
        switch route {
        case .profile:
            settingsPath.append("profile")
        case .preferences:
            settingsPath.append("preferences")
        case .about:
            settingsPath.append("about")
        case .help:
            settingsPath.append("help")
        default:
            break
        }
    }
    
    private func updateCurrentRoute() {
        // This would be more sophisticated in a real implementation
        // For now, just set based on current tab
        switch selectedTab {
        case .students:
            currentRoute = studentsPath.isEmpty ? .studentList : nil
        case .plans:
            currentRoute = plansPath.isEmpty ? .planList : nil
        case .career:
            currentRoute = careerPath.isEmpty ? .careerExplorer : nil
        case .forms:
            currentRoute = formsPath.isEmpty ? .formsList : nil
        case .resources:
            currentRoute = resourcesPath.isEmpty ? .resourcesList : nil
        case .settings:
            currentRoute = settingsPath.isEmpty ? .settings : nil
        }
    }
    
    private func addToHistory(_ route: AppRoute) {
        // Don't add if it's the same as current route
        if currentRoute == route { return }
        
        if let current = currentRoute {
            navigationHistory.append(current)
        }
        
        // Limit history size
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
        }
    }
    
    private func isReadyForNavigation() -> Bool {
        // Check if the app is ready for navigation
        // This could check authentication state, data loading, etc.
        return true
    }
    
    private func parseDeepLink(_ url: URL) -> AppRoute? {
        guard url.scheme == "tmi" else { return nil }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard !pathComponents.isEmpty else { return nil }
        
        switch pathComponents[0] {
        case "students":
            if pathComponents.count > 1 {
                return .studentDetail(pathComponents[1])
            }
            return .studentList
            
        case "plans":
            if pathComponents.count > 1 {
                return .planDetail(pathComponents[1])
            }
            return .planList
            
        case "career":
            if pathComponents.count > 1 {
                return .careerDetail(pathComponents[1])
            }
            return .careerExplorer
            
        case "forms":
            if pathComponents.count > 1 {
                return .formDetail(pathComponents[1])
            }
            return .formsList
            
        case "resources":
            if pathComponents.count > 1 {
                return .resourceDetail(pathComponents[1])
            }
            return .resourcesList
            
        case "settings":
            return .settings
            
        default:
            return nil
        }
    }
}

// MARK: - Navigation Utilities

extension NavigationManager {
    /// Quick navigation methods for common actions
    
    func showStudentDetail(_ student: Student) {
        guard let id = student.id else { return }
        navigate(to: .studentDetail(id))
    }
    
    func showPlanDetail(_ plan: TMIPlan) {
        guard let id = plan.id else { return }
        navigate(to: .planDetail(id))
    }
    
    func showAddStudent() {
        navigate(to: .addStudent)
    }
    
    func showAddPlan() {
        navigate(to: .addPlan)
    }
    
    func showSettings() {
        navigate(to: .settings)
    }
    
    func showHelp() {
        navigate(to: .help)
    }
}

