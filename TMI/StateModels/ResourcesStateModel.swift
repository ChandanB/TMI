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

@Observable
class ResourcesStateModel {
    private let db = Firestore.firestore()
    
    // MARK: - Published State
    var resources: [Resource] = []
    var isLoading = false
    var errorMessage: String?
    
    // UI State
    var searchText = ""
    var selectedCategory: Resource.ResourceCategory?
    var showingAddResource = false
    var showSearchBar = false
    
    // MARK: - Computed Properties
    var filteredResources: [Resource] {
        var filtered = resources
        
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
    func fetch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            resources = try await fetchResourcesFromFirestore()
        } catch {
            print("[ResourcesStateModel] Failed to fetch from Firestore, using sample data: \(error)")
            // Fallback to sample data
            resources = Resource.sampleResources
            errorMessage = "Using offline data. \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    func addResource(_ resource: Resource) async {
        do {
            let savedResource = try await saveResourceToFirestore(resource)
            resources.append(savedResource)
            showingAddResource = false
        } catch {
            errorMessage = "Failed to save resource: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func deleteResource(_ resource: Resource) async {
        guard let resourceId = resource.id else {
            errorMessage = "Cannot delete resource: missing ID"
            return
        }
        
        do {
            try await deleteResourceFromFirestore(resourceId)
            resources.removeAll { $0.id == resourceId }
        } catch {
            errorMessage = "Failed to delete resource: \(error.localizedDescription)"
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