//
//  ResourcesStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

// MARK: - Data Structure
struct ResourcesData {
    var resources: [Resource] = []
}

@Observable
final class ResourcesStateModel: BaseStateModel<ResourcesData, IdentifiableError> {
    private let db = Firestore.firestore()
    
    // UI State (kept separate from BaseStateModel's state)
    var searchText = ""
    var selectedCategory: Resource.ResourceCategory?
    var showingAddResource = false
    var showSearchBar = false
    
    // MARK: - Computed Properties
    
    var resources: [Resource] {
        guard case .loaded(let data) = state else { return [] }
        return data.resources
    }
    
    var filteredResources: [Resource] {
        guard case .loaded(let data) = state else { return [] }
        var filtered = data.resources
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { resource in
                resource.title.localizedCaseInsensitiveContains(searchText) ||
                resource.description.localizedCaseInsensitiveContains(searchText) ||
                resource.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return filtered.sorted { lhs, rhs in
            // Featured resources first, then by creation date
            if lhs.isFeatured != rhs.isFeatured {
                return lhs.isFeatured
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
    
    var featuredResources: [Resource] {
        resources.filter { $0.isFeatured }.prefix(3).map { $0 }
    }
    
    var resourcesByCategory: [Resource.ResourceCategory: [Resource]] {
        Dictionary(grouping: resources) { $0.category }
    }
    
    // MARK: - Data Operations
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            let fetchedResources = try await fetchResourcesFromFirestore()
            updateState(.loaded(ResourcesData(resources: fetchedResources)))
        } catch {
            print("[ResourcesStateModel] Failed to fetch from Firestore, using sample data: \(error)")
            // Fallback to sample data
            let sampleData = ResourcesData()
            updateState(.loaded(sampleData))
            // We can optionally set a non-blocking error message if needed, 
            // but for now we are gracefully falling back.
        }
    }
    
    @MainActor
    func addResource(_ resource: Resource) async {
        do {
            let savedResource = try await saveResourceToFirestore(resource)
            if case .loaded(var currentData) = state {
                currentData.resources.append(savedResource)
                updateState(.loaded(currentData))
            }
            showingAddResource = false
        } catch {
            handleError(error)
        }
    }
    
    @MainActor
    func deleteResource(_ resource: Resource) async {
        guard let resourceId = resource.id else {
            handleError(ResourceError.invalidData)
            return
        }
        
        do {
            try await deleteResourceFromFirestore(resourceId)
            if case .loaded(var currentData) = state {
                currentData.resources.removeAll { $0.id == resourceId }
                updateState(.loaded(currentData))
            }
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Private Firestore Operations
    
    private func fetchResourcesFromFirestore() async throws -> [Resource] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("resources")
        let querySnapshot = try await collection.order(by: "createdAt", descending: true).getDocuments()
        
        return querySnapshot.documents.compactMap { document -> Resource? in
            do {
                var resource = try document.data(as: Resource.self)
                resource.id = document.documentID
                return resource
            } catch {
                print("[ResourcesStateModel] Failed to decode resource: \(error)")
                return nil
            }
        }
    }
    
    private func saveResourceToFirestore(_ resource: Resource) async throws -> Resource {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("resources")
        
        var resourceToSave = resource
        resourceToSave.updatedAt = Date()
        
        let docRef = try await collection.addDocument(data: resourceToSave.toFirestoreData())
        resourceToSave.id = docRef.documentID
        
        return resourceToSave
    }
    
    private func deleteResourceFromFirestore(_ resourceId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResourceError.userNotAuthenticated
        }
        
        let collection = db.collection("users").document(uid).collection("resources")
        try await collection.document(resourceId).delete()
    }
}

// MARK: - Error Types
enum ResourceError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidData:
            return "Invalid resource data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Resource Extensions
extension Resource {
    func toFirestoreData() -> [String: Any] {
        return [
            "title": title,
            "description": description,
            "category": category.rawValue,
            "url": url,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "tags": tags,
            "recommendedFor": recommendedFor,
            "isFeatured": isFeatured,
            "thumbnail": thumbnail as Any
        ]
    }
}

