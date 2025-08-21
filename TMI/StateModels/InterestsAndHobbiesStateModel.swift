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

// MARK: - Enhanced State Model
@Observable
final class InterestsAndHobbiesStateModel: BaseStateModel<InterestsAndHobbiesData, IdentifiableError> {
    // MARK: - Dependencies
    private let interestService = InterestService()
    private let hobbyService = HobbyService()
    private let studentService = StudentService()
    private let tmiPlanService = TMIPlanService()
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Initialize UI state
        ui.set("searchText", value: "")
        ui.set("showingAddSheet", value: false)
        ui.set("selectedSegment", value: ViewSegment.interests)
        ui.set("selectedSortOption", value: SortOption.alphabetical)
        ui.set("selectedFilter", value: FilterOption.all)
    }
    
    enum ViewSegment: String, CaseIterable, Identifiable {
        case interests = "Interests"
        case hobbies = "Hobbies"
        
        var id: String { self.rawValue }
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
        get { ui.get("selectedSegment") ?? .interests }
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
    
    var filteredHobbies: [Hobby] {
        guard case .loaded(let data) = state else { return [] }
        return filterAndSort(hobbies: data.hobbies)
    }
    
    var interestsByCategory: [InterestCategory: [Interest]] {
        Dictionary(grouping: filteredInterests) { interest in
            interest.category.first ?? .academics
        }
    }
    
    var hobbiesByCategory: [HobbyCategory: [Hobby]] {
        Dictionary(grouping: filteredHobbies) { hobby in
            hobby.category.first ?? .other
        }
    }
    
    var totalItems: Int {
        guard case .loaded(let data) = state else { return 0 }
        return selectedSegment == .interests ? data.interests.count : data.hobbies.count
    }
    
    var categoryCount: Int {
        selectedSegment == .interests ? interestsByCategory.keys.count : hobbiesByCategory.keys.count
    }
    
    var hobbies: [Hobby] {
        guard case .loaded(let data) = state else { return [] }
        return data.hobbies
    }
    
    var interests: [Interest] {
        guard case .loaded(let data) = state else { return [] }
        return data.interests
    }
    
    // MARK: - Data Operations
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            async let interestsTask = interestService.fetchInterests()
            async let hobbiesTask = hobbyService.fetchHobbies()
            
            let (interests, hobbies) = try await (interestsTask, hobbiesTask)
            
            let data = InterestsAndHobbiesData(
                interests: interests,
                hobbies: hobbies
            )
            
            updateState(.loaded(data))
        } catch {
            print("[InterestsAndHobbiesStateModel] Error fetching data: \(error)")
            handleError(error, userFriendlyMessage: "Failed to load interests and hobbies")
        }
    }
    
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
    func addHobby(_ hobby: Hobby) async {
        do {
            let savedHobby = try await hobbyService.saveHobby(hobby)
            
            guard case .loaded(var data) = state else { return }
            data.hobbies.append(savedHobby)
            updateState(.loaded(data))
            
            showingAddSheet = false
        } catch {
            handleError(error, userFriendlyMessage: "Failed to save hobby")
        }
    }
    
    @MainActor
    func deleteInterest(_ interest: Interest) async {
        guard let interestId = interest.id else {
            handleError(InterestHobbyError.invalidData, userFriendlyMessage: "Cannot delete interest: missing ID")
            return
        }
        
        do {
            try await interestService.deleteInterest(interestId)
            
            guard case .loaded(var data) = state else { return }
            data.interests.removeAll { $0.id == interestId }
            updateState(.loaded(data))
        } catch {
            handleError(error, userFriendlyMessage: "Failed to delete interest")
        }
    }
    
    @MainActor
    func updateHobby(_ hobby: Hobby) async {
        do {
            let updatedHobby = try await hobbyService.updateHobby(hobby)
            
            guard case .loaded(var data) = state else { return }
            if let index = data.hobbies.firstIndex(where: { $0.id == hobby.id }) {
                data.hobbies[index] = updatedHobby
                updateState(.loaded(data))
            }
        } catch {
            handleError(error, userFriendlyMessage: "Failed to update hobby")
        }
    }
    
    @MainActor
    func deleteHobby(_ hobby: Hobby) async {
        let hobbyId = hobby.id.uuidString
        
        do {
            try await hobbyService.deleteHobby(hobbyId)
            
            guard case .loaded(var data) = state else { return }
            data.hobbies.removeAll { $0.id == hobby.id }
            updateState(.loaded(data))
        } catch {
            handleError(error, userFriendlyMessage: "Failed to delete hobby")
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
    
    @MainActor
    func fetchAssociatedData(for hobby: Hobby) async -> HobbyAssociatedData {
        do {
            async let studentsTask = studentService.fetchStudentsWithHobby(hobby)
            async let plansTask = tmiPlanService.fetchPlansWithHobby(hobby)
            
            let (students, plans) = try await (studentsTask, plansTask)
            
            return HobbyAssociatedData(
                associatedStudents: students,
                connectedTMIPlans: plans,
                engagementMetrics: nil
            )
        } catch {
            print("[InterestsAndHobbiesStateModel] Error fetching associated data: \(error)")
            return HobbyAssociatedData(associatedStudents: [], connectedTMIPlans: [], engagementMetrics: nil)
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
    
    private func filterAndSort(hobbies: [Hobby]) -> [Hobby] {
        var filtered = hobbies
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Apply category filter
        if selectedFilter != .all {
            filtered = filtered.filter { hobby in
                hobby.category.contains { category in
                    matchesFilter(category: category.rawValue)
                }
            }
        }
        
        // Apply sorting
        return sortHobbies(filtered, by: selectedSortOption)
    }
    
    private func matchesFilter(category: String) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .academics: return category.lowercased().contains("academic")
        case .creative: return category.lowercased().contains("creative") || category.lowercased().contains("art")
        case .technology: return category.lowercased().contains("technology") || category.lowercased().contains("tech")
        case .sports: return category.lowercased().contains("sport") || category.lowercased().contains("physical")
        case .social: return category.lowercased().contains("social")
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
    
    private func sortHobbies(_ hobbies: [Hobby], by option: SortOption) -> [Hobby] {
        switch option {
        case .alphabetical:
            return hobbies.sorted { (a: Hobby, b: Hobby) in a.name < b.name }
        case .category:
            return hobbies.sorted { (a: Hobby, b: Hobby) in (a.category.first?.rawValue ?? "") < (b.category.first?.rawValue ?? "") }
        case .dateCreated:
            return hobbies.sorted { (a: Hobby, b: Hobby) in (a.createdAt) > (b.createdAt) }
        case .popularity:
            return hobbies.sorted { (a: Hobby, b: Hobby) in (a.popularityScore ?? 0) > (b.popularityScore ?? 0) }
        }
    }
}

// MARK: - Data Models

struct InterestsAndHobbiesData: Equatable {
    var interests: [Interest]
    var hobbies: [Hobby]
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
    
    func fetchStudentsWithHobby(_ hobby: Hobby) async throws -> [Student] {
        let students = try await fetchStudents()
        return students.filter { student in
            student.hobbies.contains { $0.name == hobby.name }
        }
    }
}

extension TMIPlanService {
    func fetchPlansWithInterest(_ interest: Interest) async throws -> [TMIPlan] {
        let plans = try await fetchPlans()
        return plans.filter { plan in
            plan.student.interests.contains { $0.name == interest.name }
        }
    }
    
    func fetchPlansWithHobby(_ hobby: Hobby) async throws -> [TMIPlan] {
        let plans = try await fetchPlans()
        return plans.filter { plan in
            plan.student.hobbies.contains { $0.name == hobby.name }
        }
    }
}

// MARK: - Service Classes

class InterestService {
    private let db = Firestore.firestore()
    
    func fetchInterests() async throws -> [Interest] {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[InterestService] No authenticated user, returning sample data")
            return Interest.sampleInterests
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
            
            return interests.isEmpty ? Interest.sampleInterests : interests
        } catch {
            print("[InterestService] Firestore error, returning sample data: \(error)")
            return Interest.sampleInterests
        }
    }
    
    func saveInterest(_ interest: Interest) async throws -> Interest {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("interests")
        let docRef = try await collection.addDocument(data: interest.toFirestoreData())
        
        // Re-fetch the document to get the auto-populated @DocumentID
        let savedInterest = try await docRef.getDocument(as: Interest.self)
        return savedInterest
    }
    
    func deleteInterest(_ interestId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("interests")
        try await collection.document(interestId).delete()
    }
}

class HobbyService {
    private let db = Firestore.firestore()
    
    func fetchHobbies() async throws -> [Hobby] {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[HobbyService] No authenticated user, returning sample data")
            return Hobby.sampleHobbies
        }
        
        do {
            let collection = db.collection("users").document(uid).collection("hobbies")
            let querySnapshot = try await collection.getDocuments()
            
            let hobbies = querySnapshot.documents.compactMap { document -> Hobby? in
                do {
                    // @DocumentID will be automatically populated by Firestore
                    let hobby = try document.data(as: Hobby.self)
                    return hobby
                } catch {
                    print("[HobbyService] Failed to decode hobby: \(error)")
                    return nil
                }
            }
            
            return hobbies.isEmpty ? Hobby.sampleHobbies : hobbies
        } catch {
            print("[HobbyService] Firestore error, returning sample data: \(error)")
            return Hobby.sampleHobbies
        }
    }
    
    func saveHobby(_ hobby: Hobby) async throws -> Hobby {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("hobbies")
        let docRef = try await collection.addDocument(data: hobby.toFirestoreData())
        
        // Re-fetch the document to get the auto-populated @DocumentID
        let savedHobby = try await docRef.getDocument(as: Hobby.self)
        return savedHobby
    }
    
    func updateHobby(_ hobby: Hobby) async throws -> Hobby {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("hobbies")
        let hobbyId = hobby.id.uuidString
        try await collection.document(hobbyId).setData(hobby.toFirestoreData())
        
        return hobby
    }
    
    func deleteHobby(_ hobbyId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("hobbies")
        try await collection.document(hobbyId).delete()
    }
}

// MARK: - Error Types
enum InterestHobbyError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidData:
            return "Invalid interest or hobby data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
