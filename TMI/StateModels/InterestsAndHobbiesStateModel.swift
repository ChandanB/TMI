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

@Observable
class InterestsAndHobbiesStateModel {
    private let db = Firestore.firestore()
    
    // MARK: - Published State
    var interests: [Interest] = []
    var hobbies: [Hobby] = []
    var isLoading = false
    var errorMessage: String?
    
    // UI State
    var searchText = ""
    var showingAddSheet = false
    var selectedSegment: ViewSegment = .interests
    
    enum ViewSegment: String, CaseIterable, Identifiable {
        case interests = "Interests"
        case hobbies = "Hobbies"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Computed Properties
    var filteredInterests: [Interest] {
        if searchText.isEmpty {
            return interests
        }
        return interests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredHobbies: [Hobby] {
        if searchText.isEmpty {
            return hobbies
        }
        return hobbies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var interestsByCategory: [InterestCategory: [Interest]] {
        Dictionary(grouping: interests) { interest in
            interest.category.first ?? .academics
        }
    }
    
    var hobbiesByCategory: [HobbyCategory: [Hobby]] {
        Dictionary(grouping: hobbies) { hobby in
            hobby.category.first ?? .other
        }
    }
    
    // MARK: - Data Operations
    
    @MainActor
    func fetch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let interestsTask = fetchInterestsFromFirestore()
            async let hobbiesTask = fetchHobbiesFromFirestore()
            
            interests = try await interestsTask
            hobbies = try await hobbiesTask
        } catch {
            print("[InterestsAndHobbiesStateModel] Failed to fetch from Firestore, using sample data: \(error)")
            // Fallback to sample data
            interests = Interest.sampleInterests
            hobbies = Hobby.sampleHobbies
            errorMessage = "Using offline data. \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    func addInterest(_ interest: Interest) async {
        do {
            let savedInterest = try await saveInterestToFirestore(interest)
            interests.append(savedInterest)
            showingAddSheet = false
        } catch {
            errorMessage = "Failed to save interest: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func addHobby(_ hobby: Hobby) async {
        do {
            let savedHobby = try await saveHobbyToFirestore(hobby)
            hobbies.append(savedHobby)
            showingAddSheet = false
        } catch {
            errorMessage = "Failed to save hobby: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func deleteInterest(_ interest: Interest) async {
        guard let interestId = interest.id else {
            errorMessage = "Cannot delete interest: missing ID"
            return
        }
        
        do {
            try await deleteInterestFromFirestore(interestId)
            interests.removeAll { $0.id == interestId }
        } catch {
            errorMessage = "Failed to delete interest: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func deleteHobby(_ hobby: Hobby) async {
        let hobbyId = hobby.id.uuidString
        
        do {
            try await deleteHobbyFromFirestore(hobbyId)
            hobbies.removeAll { $0.id == hobby.id }
        } catch {
            errorMessage = "Failed to delete hobby: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Firestore Operations
    
    private func fetchInterestsFromFirestore() async throws -> [Interest] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("interests")
        let querySnapshot = try await collection.getDocuments()
        
        return querySnapshot.documents.compactMap { document -> Interest? in
            do {
                let interest = try document.data(as: Interest.self)
                interest.id = document.documentID
                return interest
            } catch {
                print("[InterestsAndHobbiesStateModel] Failed to decode interest: \(error)")
                return nil
            }
        }
    }
    
    private func fetchHobbiesFromFirestore() async throws -> [Hobby] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("hobbies")
        let querySnapshot = try await collection.getDocuments()
        
        return querySnapshot.documents.compactMap { document -> Hobby? in
            do {
                let hobby = try document.data(as: Hobby.self)
                hobby.id = UUID(uuidString: document.documentID) ?? UUID()
                return hobby
            } catch {
                print("[InterestsAndHobbiesStateModel] Failed to decode hobby: \(error)")
                return nil
            }
        }
    }
    
    private func saveInterestToFirestore(_ interest: Interest) async throws -> Interest {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("interests")
        
        let interestToSave = interest
        // Set creation timestamp (handled in toFirestoreData())
        
        let docRef = try await collection.addDocument(data: interestToSave.toFirestoreData())
        interestToSave.id = docRef.documentID
        
        return interestToSave
    }
    
    private func saveHobbyToFirestore(_ hobby: Hobby) async throws -> Hobby {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("hobbies")
        
        let hobbyToSave = hobby
        // Set creation timestamp (handled in toFirestoreData())
        
        let docRef = try await collection.addDocument(data: hobbyToSave.toFirestoreData())
        hobbyToSave.id = UUID(uuidString: docRef.documentID) ?? hobbyToSave.id
        
        return hobbyToSave
    }
    
    private func deleteInterestFromFirestore(_ interestId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw InterestHobbyError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("interests")
        try await collection.document(interestId).delete()
    }
    
    private func deleteHobbyFromFirestore(_ hobbyId: String) async throws {
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
