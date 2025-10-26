//
//  InterestsAndHobbiesStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// MARK: - Environment Key (defined in InterestsAndHobbiesHelpers.swift)

// MARK: - State Model
@Observable
final class InterestsAndHobbiesStateModel: BaseStateModel<InterestsAndHobbiesData, IdentifiableError> {
    // MARK: - Dependencies
    private let interestService = InterestService()
    private let studentService = StudentService()
    private let tmiPlanService = TMIPlanService()

    // MARK: - Fetch Guard
    private var isFetching = false

    // MARK: - Initialization
    override init() {
        super.init()
        
        // Initialize UI state
        ui.set("searchText", value: "")
        ui.set("showingAddSheet", value: false)
        ui.set("selectedSegment", value: ViewSegment.all)
        ui.set("selectedSortOption", value: SortOption.alphabetical)
        ui.set("selectedFilter", value: FilterOption.all)
    }
    
    enum ViewSegment: String, CaseIterable, Identifiable {
        case all = "Interests"
        case academic = "Academic Interests"
        case creative = "Creative Interests"
        case physical = "Physical Interests"
        case social = "Social Interests"
        case entertainment = "Entertainment Interests"

        var id: String { self.rawValue }

        var iconName: String {
            switch self {
            case .all: return "heart.fill"
            case .academic: return "book.fill"
            case .creative: return "paintpalette.fill"
            case .physical: return "figure.run"
            case .social: return "person.3.fill"
            case .entertainment: return "tv.fill"
            }
        }

        var categories: [InterestCategory] {
            switch self {
            case .all:
                return []
            case .academic:
                return [.academics, .science, .technology, .mathematics, .learning]
            case .creative:
                return [.arts, .music, .literature, .crafts, .photography]
            case .physical:
                return [.sports, .outdoors, .wellness, .cooking]
            case .social:
                return [.leadership, .socialCauses, .social, .communication, .languages]
            case .entertainment:
                return [.entertainment, .gaming, .collecting]
            }
        }
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case alphabetical = "Alphabetical"
        case category = "Category"
        case dateCreated = "Date Created"
        case popularity = "Popularity"
        
        var id: String { self.rawValue }
    }
    
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case academics = "Academics"
        case creative = "Creative"
        case technology = "Technology"
        case sports = "Sports"
        case social = "Social"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - UI State Accessors
    var searchText: String {
        get { ui.get("searchText") ?? "" }
        set { ui.set("searchText", value: newValue) }
    }
    
    var showingAddSheet: Bool {
        get { ui.get("showingAddSheet") ?? false }
        set { ui.set("showingAddSheet", value: newValue) }
    }
    
    var selectedSegment: ViewSegment {
        get { ui.get("selectedSegment") ?? .all }
        set { ui.set("selectedSegment", value: newValue) }
    }
    
    var selectedSortOption: SortOption {
        get { ui.get("selectedSortOption") ?? .alphabetical }
        set { ui.set("selectedSortOption", value: newValue) }
    }
    
    var selectedFilter: FilterOption {
        get { ui.get("selectedFilter") ?? .all }
        set { ui.set("selectedFilter", value: newValue) }
    }
    
    // MARK: - Computed Properties
    var filteredInterests: [Interest] {
        guard case .loaded(let data) = state else { return [] }
        return filterAndSort(interests: data.interests)
    }
    
    var interestsByCategory: [InterestCategory: [Interest]] {
        Dictionary(grouping: filteredInterests) { interest in
            interest.category.first ?? .academics
        }
    }

    var interestsBySegment: [Interest] {
        guard selectedSegment != .all else { return filteredInterests }

        let targetCategories = selectedSegment.categories
        return filteredInterests.filter { interest in
            !Set(interest.category).isDisjoint(with: Set(targetCategories))
        }
    }
    
    var totalItems: Int {
        guard case .loaded(let data) = state else { return 0 }
        return data.interests.count
    }
    
    var categoryCount: Int {
        interestsByCategory.keys.count
    }
    
    var interests: [Interest] {
        guard case .loaded(let data) = state else { return [] }
        return data.interests
    }
    
    // MARK: - Data Operations
    
    @MainActor
    override func fetch() async {
        // Prevent duplicate fetches
        guard !isFetching else {
            print("[InterestsAndHobbiesStateModel] Fetch already in progress, skipping")
            return
        }

        isFetching = true
        defer { isFetching = false }

        updateState(.loading)

        do {
            // Add timeout protection
            let interests = try await withTimeout(seconds: 10) {
                try await self.interestService.fetchInterests()
            }

            let data = InterestsAndHobbiesData(interests: interests)
            updateState(.loaded(data))
        } catch is TimeoutError {
            print("[InterestsAndHobbiesStateModel] Fetch timed out, using offline data")
            // Use sample data as fallback when timeout occurs
            let data = InterestsAndHobbiesData(interests: Interest.expandedSampleInterests)
            updateState(.loaded(data))
        } catch {
            print("[InterestsAndHobbiesStateModel] Error fetching data: \(error)")
            // Use sample data as fallback on any error
            let data = InterestsAndHobbiesData(interests: Interest.expandedSampleInterests)
            updateState(.loaded(data))
        }
    }

    // Timeout helper
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {}
    
    @MainActor
    func addInterest(_ interest: Interest) async {
        do {
            let savedInterest = try await interestService.saveInterest(interest)
            
            guard case .loaded(var data) = state else { return }
            data.interests.append(savedInterest)
            updateState(.loaded(data))
            
            showingAddSheet = false
        } catch {
            handleError(error, userFriendlyMessage: "Failed to save interest")
        }
    }
    
    
    @MainActor
    func updateInterest(_ interest: Interest) async {
        guard let interestId = interest.id else {
            handleError(InterestError.invalidData, userFriendlyMessage: "Cannot update interest: missing ID")
            return
        }

        do {
            let updatedInterest = try await interestService.updateInterest(interest)

            guard case .loaded(var data) = state else { return }
            if let index = data.interests.firstIndex(where: { $0.id == interestId }) {
                data.interests[index] = updatedInterest
                updateState(.loaded(data))
            }
        } catch {
            handleError(error, userFriendlyMessage: "Failed to update interest")
        }
    }

    @MainActor
    func deleteInterest(_ interest: Interest) async {
        guard let interestId = interest.id else {
            handleError(InterestError.invalidData, userFriendlyMessage: "Cannot delete interest: missing ID")
            return
        }

        do {
            // First, update UI immediately for better UX
            if case .loaded(var data) = state {
                data.interests.removeAll { $0.id == interestId }
                updateState(.loaded(data))
            }

            // Then delete from Firestore
            try await interestService.deleteInterest(interestId)
        } catch {
            // If deletion fails, refresh to restore the correct state
            await refresh()
            handleError(error, userFriendlyMessage: "Failed to delete interest")
        }
    }


    @MainActor
    override func refresh() async {
        await fetch()
    }
    
    @MainActor
    func fetchAssociatedData(for interest: Interest) async -> InterestAssociatedData {
        do {
            async let studentsTask = studentService.fetchStudentsWithInterest(interest)
            async let plansTask = tmiPlanService.fetchPlansWithInterest(interest)
            
            let (students, plans) = try await (studentsTask, plansTask)
            
            return InterestAssociatedData(
                associatedStudents: students,
                connectedTMIPlans: plans,
                engagementMetrics: nil
            )
        } catch {
            print("[InterestsAndHobbiesStateModel] Error fetching associated data: \(error)")
            return InterestAssociatedData(associatedStudents: [], connectedTMIPlans: [], engagementMetrics: nil)
        }
    }
    
    
    // MARK: - Private Helper Methods
    
    private func filterAndSort(interests: [Interest]) -> [Interest] {
        var filtered = interests
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Apply category filter
        if selectedFilter != .all {
            filtered = filtered.filter { interest in
                interest.category.contains { category in
                    matchesFilter(category: category.rawValue)
                }
            }
        }
        
        // Apply sorting
        return sortInterests(filtered, by: selectedSortOption)
    }
    
    // Note: Hobby filtering removed - now using unified Interest filtering
    
    private func matchesFilter(category: String) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .academics: 
            return category.lowercased().contains("academic") || 
                   category.lowercased().contains("science") ||
                   category.lowercased().contains("discovery") ||
                   category.lowercased().contains("literature") ||
                   category.lowercased().contains("reading") ||
                   category.lowercased().contains("writing")
        case .creative: 
            return category.lowercased().contains("creative") || 
                   category.lowercased().contains("art") ||
                   category.lowercased().contains("creativity") ||
                   category.lowercased().contains("music") ||
                   category.lowercased().contains("literature")
        case .technology: 
            return category.lowercased().contains("technology") || 
                   category.lowercased().contains("tech")
        case .sports: 
            return category.lowercased().contains("sport") || 
                   category.lowercased().contains("athletic") ||
                   category.lowercased().contains("physical") ||
                   category.lowercased().contains("wellness")
        case .social: 
            return category.lowercased().contains("social") ||
                   category.lowercased().contains("causes") ||
                   category.lowercased().contains("leadership") ||
                   category.lowercased().contains("entertainment")
        }
    }
    
    private func sortInterests(_ interests: [Interest], by option: SortOption) -> [Interest] {
        switch option {
        case .alphabetical:
            return interests.sorted { (a: Interest, b: Interest) in a.name < b.name }
        case .category:
            return interests.sorted { (a: Interest, b: Interest) in (a.category.first?.rawValue ?? "") < (b.category.first?.rawValue ?? "") }
        case .dateCreated:
            return interests.sorted { (a: Interest, b: Interest) in (a.createdAt) > (b.createdAt) }
        case .popularity:
            return interests.sorted { (a: Interest, b: Interest) in (a.popularityScore ?? 0) > (b.popularityScore ?? 0) }
        }
    }
    
    // Note: Hobby sorting removed - now using unified Interest sorting
}

// MARK: - Data Models

struct InterestsAndHobbiesData: Equatable {
    var interests: [Interest] // Now includes everything (former interests + hobbies)
}

// InterestAssociatedData and HobbyAssociatedData are defined in InterestsAndHobbiesHelpers.swift

// MARK: - Service Extensions

extension StudentService {
    func fetchStudentsWithInterest(_ interest: Interest) async throws -> [Student] {
        let students = try await fetchStudents()
        return students.filter { student in
            student.interests.contains { $0.name == interest.name }
        }
    }
    
}

extension TMIPlanService {
    func fetchPlansWithInterest(_ interest: Interest) async throws -> [TMIPlan] {
        let plans = try await fetchPlans()
        return plans.filter { plan in
            plan.interests.contains { $0.name == interest.name }
        }
    }
    
}

// MARK: - Service Classes

class InterestService {
    private let db = Firestore.firestore()
    
    func fetchInterests() async throws -> [Interest] {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[InterestService] No authenticated user, returning sample data")
            return Interest.expandedSampleInterests
        }
        
        do {
            let collection = db.collection("users").document(uid).collection("interests")
            let querySnapshot = try await collection.getDocuments()
            
            let interests = querySnapshot.documents.compactMap { document -> Interest? in
                do {
                    // @DocumentID will be automatically populated by Firestore
                    let interest = try document.data(as: Interest.self)
                    return interest
                } catch {
                    print("[InterestService] Failed to decode interest: \(error)")
                    return nil
                }
            }

            // Deduplicate interests by ID and name
            let uniqueInterests = Array(Dictionary(grouping: interests) { $0.id ?? $0.name }
                .compactMap { $0.value.first })

            print("[InterestService] Fetched \(interests.count) documents, \(uniqueInterests.count) unique interests")

            // Return sample data if no user data exists
            return uniqueInterests.isEmpty ? Interest.expandedSampleInterests : uniqueInterests
        } catch {
            print("[InterestService] Firestore error: \(error)")
            // Return sample data as fallback, but still throw the error for proper error handling
            throw error
        }
    }
    
    func saveInterest(_ interest: Interest) async throws -> Interest {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestError.userNotAuthenticated
        }

        let collection = db.collection("users").document(uid).collection("interests")
        let docRef = try await collection.addDocument(data: interest.toFirestoreData())

        // Re-fetch the document to get the auto-populated @DocumentID
        let savedInterest = try await docRef.getDocument(as: Interest.self)
        return savedInterest
    }

    func updateInterest(_ interest: Interest) async throws -> Interest {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestError.userNotAuthenticated
        }

        guard let interestId = interest.id else {
            throw InterestError.invalidData
        }

        let collection = db.collection("users").document(uid).collection("interests")

        // Use updateData instead of setData to avoid creating duplicates
        // But first convert to Firestore data
        let data = interest.toFirestoreData()

        // Use setData with merge: false to completely replace the document
        try await collection.document(interestId).setData(data, merge: false)

        // Re-fetch the document to ensure consistency
        let updatedInterest = try await collection.document(interestId).getDocument(as: Interest.self)
        return updatedInterest
    }

    func deleteInterest(_ interestId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestError.userNotAuthenticated
        }

        let collection = db.collection("users").document(uid).collection("interests")
        try await collection.document(interestId).delete()
    }
}

// Note: HobbyService removed - now using unified InterestService

// MARK: - Error Types
enum InterestError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidData:
            return "Invalid interest data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
