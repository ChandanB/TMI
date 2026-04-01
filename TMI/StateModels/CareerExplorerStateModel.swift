//
//  CareerExplorerStateModel.swift
//  TMI
//
//  Created by Antigravity on 12/26/25.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class CareerExplorerStateModel {
    // Data
    var careers: [Career] = []
    var searchResults: [Career] = []
    var personalizedRecommendations: [Career] = []
    var isLoading = false
    var error: Error?

    // UI State
    var searchText = ""
    var isSearching = false
    var hasSearched = false
    var selectedStudent: Student?
    var selectedField: String?

    private let careerService = CareerService.shared

    // MARK: - Load initial data
    func fetch() {
        isLoading = true
        careers = careerService.allCareers
        isLoading = false
    }

    // MARK: - Search (filter static catalog)
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchResults = careerService.searchCareers(query: searchText)
        hasSearched = true
        isSearching = false
    }

    func clearSearch() {
        searchText = ""
        hasSearched = false
        searchResults = []
    }

    // MARK: - Personalized recommendations
    func loadPersonalizedRecommendations(clusters: [InterestCluster] = []) {
        guard let student = selectedStudent else { return }
        if clusters.isEmpty {
            personalizedRecommendations = careerService.fetchTrendingCareers()
        } else {
            personalizedRecommendations = careerService.getCareerRecommendations(from: clusters)
        }
        _ = student // suppress warning — student presence is required as a guard
    }

    // MARK: - Computed
    var filteredCareers: [Career] {
        var result = hasSearched ? searchResults : careers
        if let field = selectedField {
            result = result.filter { $0.field == field }
        }
        return result
    }

    var hasActiveFilters: Bool {
        selectedField != nil
    }

    var trendingCareers: [Career] {
        careerService.fetchTrendingCareers()
    }

    var showPersonalizedSection: Bool {
        !personalizedRecommendations.isEmpty
    }
}
