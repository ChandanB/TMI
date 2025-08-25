//
//  TMIPlanListStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Observation

enum PlanFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inProgress = "In Progress"
    case completed = "Completed"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .all:
            return "View all TMI plans"
        case .inProgress:
            return "Plans that are currently in progress"
        case .completed:
            return "Plans that have been fully completed"
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "doc.text.fill"
        case .inProgress:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        }
    }
}

@Observable
final class TMIPlanListStateModel: BaseStateModel<[TMIPlan], IdentifiableError> {
    
    // Form and UI state
    var searchText = ""
    var selectedFilter: PlanFilter = .all
    var showingNewPlan = false
    var selectedPlan: TMIPlan?
    
    // Dependencies
    private let planService: TMIPlanService
    
    init(planService: TMIPlanService = TMIPlanService()) {
        self.planService = planService
        super.init()
    }
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            let plans = try await planService.fetchPlans()
            updateState(.loaded(plans))
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to load TMI plans"
            )
            updateState(.error(identifiableError))
        }
    }
    
    @MainActor
    func addPlan(_ plan: TMIPlan) async -> Bool {
        do {
            let savedPlan = try await planService.addPlan(plan)
            
            // Update the current state to include the new plan
            if case .loaded(var plans) = state {
                plans.append(savedPlan)
                updateState(.loaded(plans))
            }
            
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to add TMI plan"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    @MainActor
    func addExistingPlan(_ plan: TMIPlan) {
        // Add a plan that's already saved to Firebase to the current state
        if case .loaded(var plans) = state {
            plans.append(plan)
            updateState(.loaded(plans))
        }
    }
    
    @MainActor
    func updatePlan(_ plan: TMIPlan) async -> Bool {
        do {
            let updatedPlan = try await planService.updatePlan(plan)
            
            // Update the current state
            if case .loaded(var plans) = state {
                if let index = plans.firstIndex(where: { $0.id == updatedPlan.id }) {
                    plans[index] = updatedPlan
                    updateState(.loaded(plans))
                }
            }
            
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to update TMI plan"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    @MainActor
    func deletePlan(_ plan: TMIPlan) async -> Bool {
        do {
            try await planService.deletePlan(plan)
            
            // Update the current state to remove the plan
            if case .loaded(var plans) = state {
                plans.removeAll { $0.id == plan.id }
                updateState(.loaded(plans))
            }
            
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to delete TMI plan"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    // MARK: - Computed Properties
    
    var plans: [TMIPlan] {
        if case .loaded(let plans) = state {
            return plans
        }
        return []
    }
    
    var filteredPlans: [TMIPlan] {
        plans.filter { plan in
            (searchText.isEmpty || matchesSearch(plan: plan, searchText: searchText))
                && (selectedFilter == .all || matchesFilter(plan: plan, filter: selectedFilter))
        }
    }
    
    private func matchesSearch(plan: TMIPlan, searchText: String) -> Bool {
        plan.model.rawValue.localizedCaseInsensitiveContains(searchText) ||
        plan.notes.localizedCaseInsensitiveContains(searchText) ||
        plan.students.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func matchesFilter(plan: TMIPlan, filter: PlanFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .inProgress:
            return plan.progress < 1.0
        case .completed:
            return plan.progress >= 1.0
        }
    }
    
    // MARK: - UI Helpers
    
    func showNewPlan() {
        showingNewPlan = true
    }
    
    func hideNewPlan() {
        showingNewPlan = false
    }
    
    func selectPlan(_ plan: TMIPlan) {
        selectedPlan = plan
    }
    
    func clearSelectedPlan() {
        selectedPlan = nil
    }
    
    // MARK: - Statistics
    
    var totalPlans: Int { filteredPlans.count }
    var inProgressPlans: Int { filteredPlans.filter { $0.progress < 1.0 }.count }
    var completedPlans: Int { filteredPlans.filter { $0.progress >= 1.0 }.count }
    
    
    // MARK: - Alert State Management
    
    override var hasError: Bool {
        if case .error = state { return true }
        return false
    }
    
    var currentError: IdentifiableError? {
        if case .error(let error) = state { return error }
        return nil
    }
    
    @MainActor
    func clearError() {
        switch state {
        case .error:
            // If plans previously loaded, revert to loaded state with last known plans
            if !plans.isEmpty {
                updateState(.loaded(plans))
            } else {
                updateState(.loading)
            }
        default:
            break
        }
    }
}
