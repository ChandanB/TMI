//
//  CareerExplorerStateModel.swift
//  TMI
//
//  Created by Antigravity on 12/26/25.
//

import Foundation
import Observation
import SwiftUI

// MARK: - Data Model

struct CareerExplorerData: Equatable {
    var careers: [Career] = []
    var trendingCareers: [Career] = []
    var personalizedRecommendations: [Career] = []
    var searchInsights: CareerDiscoveryInsights?
    var searchResults: [Career] = []
}

// MARK: - State Model

@Observable
@MainActor
final class CareerExplorerStateModel: BaseStateModel<CareerExplorerData, IdentifiableError> {
    
    // MARK: - Dependencies
    
    private let careerService = CareerService.shared
    // AI service integration will go here, currently accessed via CareerService which uses AIInsightsService
    
    // MARK: - UI State Properties
    
    // Search state
    var searchText: String {
        get { ui.get("searchText") ?? "" }
        set { ui.set("searchText", value: newValue) }
    }
    
    var isSearching: Bool {
        get { ui.get("isSearching") ?? false }
        set { ui.set("isSearching", value: newValue) }
    }
    
    var hasSearched: Bool {
        get { ui.get("hasSearched") ?? false }
        set { ui.set("hasSearched", value: newValue) }
    }
    
    // Filter state
    var selectedStudent: Student? {
        get { ui.get("selectedStudent") }
        set { ui.set("selectedStudent", value: newValue) }
    }
    
    var selectedField: String? {
        get { ui.get("selectedField") }
        set { ui.set("selectedField", value: newValue) }
    }
    
    var showPersonalizedSection: Bool {
        get { ui.get("showPersonalizedSection") ?? false }
        set { ui.set("showPersonalizedSection", value: newValue) }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Initialize UI state
        ui.set("searchText", value: "")
        ui.set("isSearching", value: false)
        ui.set("hasSearched", value: false)
        ui.set("showPersonalizedSection", value: false)
        
        // Initial empty state
        Task { @MainActor in
            self.updateState(.loaded(CareerExplorerData()))
        }
    }
    
    // MARK: - Data Operations
    
    @MainActor
    override func fetch() async {
        // Load initial data (trending, etc)
        // For now, we simulate loading or fetch default trending careers
        // In a real app, you might fetch this from a backend
        
        updateState(.loading)
        
        do {
            // Simulate network delay or fetch real trending careers
            try await Task.sleep(nanoseconds: 500_000_000) 
            
            // For MVP, we might just load sample data if backend isn't ready for trending
            let trending = Array(Career.sampleCareers.prefix(5)) 
            let all = Career.sampleCareers
            
            let data = CareerExplorerData(
                careers: all,
                trendingCareers: trending,
                personalizedRecommendations: [],
                searchInsights: nil,
                searchResults: []
            )
            
            updateState(.loaded(data))
        } catch {
            handleError(error)
        }
    }
    
    @MainActor
    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        // Keep existing results while searching or clear them? 
        // Typically keep until new ones arrive or show loading overlay.
        
        do {
            let response = try await careerService.searchCareersWithAI(query: searchText, student: selectedStudent)
            
            guard case .loaded(var currentData) = state else { return }
            
            currentData.searchResults = response.careers
            currentData.searchInsights = response.insights
            
            hasSearched = true
            isSearching = false
            
            updateState(.loaded(currentData))
            
        } catch {
            isSearching = false
            handleError(error, userFriendlyMessage: "Search failed. Please try again.")
        }
    }
    
    @MainActor
    func clearSearch() {
        searchText = ""
        hasSearched = false
        isSearching = false
        
        guard case .loaded(var currentData) = state else { return }
        currentData.searchResults = []
        currentData.searchInsights = nil
        updateState(.loaded(currentData))
    }
    
    @MainActor
    func loadPersonalizedRecommendations() async {
        guard let student = selectedStudent else { return }
        
        // If we are already loaded, we can just update the recommendations part
        // If not loaded, we should wait or triggering fetch
        
        do {
            let recommendations = try await careerService.getCareerRecommendations(for: student)
            let insights = try await careerService.getCareerDiscoveryInsights(for: student)
            
            if case .loaded(var currentData) = state {
                currentData.personalizedRecommendations = recommendations
                // potentially update a separate insights model or variable if needed, 
                // but for now focus on recommendations list
                updateState(.loaded(currentData))
                showPersonalizedSection = true
            } else {
                // If state isn't loaded yet, create it
                let data = CareerExplorerData(personalizedRecommendations: recommendations)
                updateState(.loaded(data))
                showPersonalizedSection = true
            }
        } catch {
             print("[CareerExplorerStateModel] Failed to load recommendations: \(error)")
             // Fallback to samples if needed, or just show error
        }
    }
    
    // MARK: - Computed Properties
    
    var searchResults: [Career] {
        guard case .loaded(let data) = state else { return [] }
        return data.searchResults
    }
    
    var searchInsights: CareerDiscoveryInsights? {
        guard case .loaded(let data) = state else { return nil }
        return data.searchInsights
    }
    
    var trendingCareers: [Career] {
        guard case .loaded(let data) = state else { return [] }
        return data.trendingCareers
    }
    
    var personalizedRecommendations: [Career] {
        guard case .loaded(let data) = state else { return [] }
        return data.personalizedRecommendations
    }
}

