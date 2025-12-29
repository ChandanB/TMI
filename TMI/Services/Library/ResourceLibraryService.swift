//
//  ResourceLibraryService.swift
//  TMI
//
//  Global Resource Library Service
//  Manages the canonical resource library collection with scope-based filtering
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class ResourceLibraryService {
    static let shared = ResourceLibraryService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum ResourceLibraryError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case userNotAuthenticated
        case invalidResource

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch resources: \(message)"
            case .saveFailed(let message):
                return "Failed to save resource: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete resource: \(message)"
            case .userNotAuthenticated:
                return "User not authenticated"
            case .invalidResource:
                return "Invalid resource data"
            }
        }
    }

    // MARK: - Global Collection Access

    private var globalCollection: CollectionReference {
        db.collection("resources")
    }

    // MARK: - Fetch Operations

    /// Fetch resources filtered by scope and optional district ID
    func fetchResources(scope: Resource.ResourceScope? = nil, districtId: String? = nil) async throws -> [Resource] {
        do {
            let querySnapshot = try await withTimeout(seconds: 10) {
                try await self.globalCollection.getDocuments()
            }

            var resources = querySnapshot.documents.compactMap { document -> Resource? in
                try? document.data(as: Resource.self)
            }

            // Filter by scope
            if let scope = scope {
                resources = resources.filter { $0.scope == scope }
            }

            // Filter by district
            if let districtId = districtId {
                resources = resources.filter { resource in
                    (resource.scope == .district && resource.districtId == districtId) ||
                    resource.scope == .global
                }
            }

            print("[ResourceLibraryService] Fetched \(resources.count) resources from global library")
            return resources
        } catch {
            print("[ResourceLibraryService] Error fetching resources: \(error.localizedDescription)")
            throw ResourceLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch resources for a student context (global + district-enabled + optional personal)
    func fetchResourcesForStudentContext(studentId: String, districtId: String? = nil) async throws -> [Resource] {
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw ResourceLibraryError.userNotAuthenticated
            }

            var resources = try await fetchResources()

            // Filter to appropriate scopes
            resources = resources.filter { resource in
                // Global resources always included
                if resource.scope == .global {
                    return true
                }

                // District resources if districtId matches
                if resource.scope == .district, let resourceDistrictId = resource.districtId, let districtId = districtId {
                    return resourceDistrictId == districtId
                }

                // Personal resources if owned by current user
                if resource.scope == .personal, let ownerUid = resource.ownerUid {
                    return ownerUid == uid
                }

                return false
            }

            print("[ResourceLibraryService] Fetched \(resources.count) resources for student context")
            return resources
        } catch {
            print("[ResourceLibraryService] Error fetching student context resources: \(error.localizedDescription)")
            throw ResourceLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch a single resource by ID
    func fetchResource(id: String) async throws -> Resource? {
        do {
            let document = try await withTimeout(seconds: 10) {
                try await self.globalCollection.document(id).getDocument()
            }

            guard document.exists else {
                return nil
            }

            return try? document.data(as: Resource.self)
        } catch {
            print("[ResourceLibraryService] Error fetching resource \(id): \(error.localizedDescription)")
            throw ResourceLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Search resources by title, description, or tags
    func searchResources(query: String, scope: Resource.ResourceScope? = nil) async throws -> [Resource] {
        let resources = try await fetchResources(scope: scope)
        let lowercasedQuery = query.lowercased()

        return resources.filter { resource in
            resource.title.lowercased().contains(lowercasedQuery) ||
            resource.description.lowercased().contains(lowercasedQuery) ||
            resource.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }
    }

    /// Fetch resources by category
    func fetchResources(category: Resource.ResourceCategory, scope: Resource.ResourceScope? = nil) async throws -> [Resource] {
        let resources = try await fetchResources(scope: scope)
        return resources.filter { $0.category == category }
    }

    /// Fetch featured resources
    func fetchFeaturedResources(districtId: String? = nil) async throws -> [Resource] {
        let resources = try await fetchResources(districtId: districtId)
        return resources.filter { $0.isFeatured }
    }

    // MARK: - Write Operations

    /// Save or update a resource in the global library
    func saveResource(_ resource: Resource) async throws -> Resource {
        do {
            var updatedResource = resource

            if let id = resource.id {
                // Update existing
                try await globalCollection.document(id).setData(from: resource, merge: true)
                updatedResource.id = id
            } else {
                // Create new
                let docRef = try await globalCollection.addDocument(from: resource)
                updatedResource.id = docRef.documentID
            }

            print("[ResourceLibraryService] Saved resource: \(updatedResource.title)")
            return updatedResource
        } catch {
            print("[ResourceLibraryService] Error saving resource: \(error.localizedDescription)")
            throw ResourceLibraryError.saveFailed(error.localizedDescription)
        }
    }

    /// Delete a resource from the global library
    func deleteResource(id: String) async throws {
        do {
            try await globalCollection.document(id).delete()
            print("[ResourceLibraryService] Deleted resource: \(id)")
        } catch {
            print("[ResourceLibraryService] Error deleting resource: \(error.localizedDescription)")
            throw ResourceLibraryError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Timeout wrapper for async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ResourceLibraryError.fetchFailed("Operation timed out after \(seconds) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
