//
//  DeepLinkRouter.swift
//  TMI
//
//  Handles deep link routing and navigation coordination.
//  Translates deep links into (tab, path, context) for consistent navigation.
//

import Foundation
import SwiftUI

// MARK: - Deep Link Router

/// Handles deep link routing and navigation coordination
@Observable
final class DeepLinkRouter {
    
    // MARK: - State
    
    /// Pending navigation action
    private(set) var pendingNavigation: NavigationAction?
    
    /// Whether a navigation is currently being processed
    private(set) var isProcessing: Bool = false
    
    // MARK: - Navigation Action
    
    struct NavigationAction: Equatable {
        let targetTab: MainTabView.Tab
        let destination: DeepLinkDestination
        let studentId: String?
        let planId: String?
    }
    
    // MARK: - Route Processing
    
    /// Process a deep link URL and return the navigation action
    func processDeepLink(url: URL) -> NavigationAction? {
        guard let destination = DeepLinkDestination.from(url: url) else {
            print("[DeepLinkRouter] Failed to parse URL: \(url)")
            return nil
        }
        
        return createNavigationAction(for: destination)
    }
    
    /// Create a navigation action for a destination
    func createNavigationAction(for destination: DeepLinkDestination) -> NavigationAction {
        switch destination {
        case .student(let id):
            return NavigationAction(
                targetTab: .students,
                destination: destination,
                studentId: id,
                planId: nil
            )
            
        case .plan(let id):
            return NavigationAction(
                targetTab: .tmiPlans,
                destination: destination,
                studentId: nil,
                planId: id
            )
            
        case .meeting:
            // Meetings are accessed through plans
            return NavigationAction(
                targetTab: .tmiPlans,
                destination: destination,
                studentId: nil,
                planId: nil // Would need to look up the plan for this meeting
            )
            
        case .resource:
            return NavigationAction(
                targetTab: .resources,
                destination: destination,
                studentId: nil,
                planId: nil
            )
            
        case .studentInterests(let studentId):
            return NavigationAction(
                targetTab: .interests,
                destination: destination,
                studentId: studentId,
                planId: nil
            )
            
        case .studentCareers(let studentId):
            return NavigationAction(
                targetTab: .careerExplorer,
                destination: destination,
                studentId: studentId,
                planId: nil
            )
            
        case .planRecommendations(let planId):
            return NavigationAction(
                targetTab: .tmiPlans,
                destination: destination,
                studentId: nil,
                planId: planId
            )
            
        case .districtApprovals(let districtId):
            return NavigationAction(
                targetTab: .districtDashboard,
                destination: destination,
                studentId: nil,
                planId: nil
            )
            
        case .districtCompliance(let districtId):
            return NavigationAction(
                targetTab: .districtDashboard,
                destination: destination,
                studentId: nil,
                planId: nil
            )
            
        case .scheduleMeeting(let planId):
            return NavigationAction(
                targetTab: .tmiPlans,
                destination: destination,
                studentId: nil,
                planId: planId
            )
        }
    }
    
    /// Queue a navigation action for processing
    @MainActor
    func queueNavigation(_ action: NavigationAction) {
        pendingNavigation = action
    }
    
    /// Clear the pending navigation
    @MainActor
    func clearPendingNavigation() {
        pendingNavigation = nil
    }
    
    /// Execute the pending navigation
    @MainActor
    func executePendingNavigation(
        context: StudentContextStateModel,
        tabSelection: Binding<MainTabView.Tab>
    ) async {
        guard let action = pendingNavigation else { return }
        
        isProcessing = true
        defer { 
            isProcessing = false
            clearPendingNavigation()
        }
        
        // Set context if needed
        if let studentId = action.studentId {
            await context.setActiveStudent(studentId, scope: .staff)
        }
        
        if let planId = action.planId {
            context.setActivePlan(planId)
        }
        
        // Navigate to tab
        tabSelection.wrappedValue = action.targetTab
        
        // Queue the deep link destination for the tab to handle
        context.queueDeepLink(action.destination)
        
        print("[DeepLinkRouter] Executed navigation to \(action.targetTab.rawValue)")
    }
}

// MARK: - URL Scheme Handler

extension DeepLinkRouter {
    /// Handle an incoming URL
    @MainActor
    func handleIncomingURL(_ url: URL) async -> Bool {
        guard let action = processDeepLink(url: url) else {
            return false
        }
        
        queueNavigation(action)
        return true
    }
}

// MARK: - Environment Key

private struct DeepLinkRouterKey: EnvironmentKey {
    static let defaultValue = DeepLinkRouter()
}

extension EnvironmentValues {
    var deepLinkRouter: DeepLinkRouter {
        get { self[DeepLinkRouterKey.self] }
        set { self[DeepLinkRouterKey.self] = newValue }
    }
}

