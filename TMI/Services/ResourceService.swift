//
//  ResourceService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ResourceService: @unchecked Sendable {
    static let shared = ResourceService()
    private let firestore = FIRESTORE_DATABASE
    
  private init() {}
  
  // MARK: - Add Resource
  func addResource(_ resource: Resource) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    // Don't manually set @DocumentID - let Firestore manage it
    let resourceToSave = resource
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let docRef = try collection.addDocument(from: resourceToSave)
    return docRef.documentID
  }
  
  // MARK: - Fetch Resource
  func fetchResource(id: String) async throws -> Resource {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
      .document(id)
    
    let snapshot = try await document.getDocument()
    
    guard snapshot.exists else {
      throw ResourceServiceError.resourceNotFound
    }
    
    return try snapshot.data(as: Resource.self)
  }
  
  // MARK: - Fetch All Resources
  func fetchAllResources() async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let snapshot = try await collection
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
  }
  
  // MARK: - Fetch Resources by Category
  func fetchResources(category: Resource.ResourceCategory) async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let snapshot = try await collection
      .whereField("category", isEqualTo: category.rawValue)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
  }
  
  // MARK: - Fetch Featured Resources
  func fetchFeaturedResources() async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let snapshot = try await collection
      .whereField("isFeatured", isEqualTo: true)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
  }
  
  // MARK: - Search Resources
  func searchResources(query: String) async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    // Firestore doesn't support full-text search, so we'll fetch all and filter locally
    let snapshot = try await collection.getDocuments()
    
    let allResources = try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
    
    let lowercaseQuery = query.lowercased()
    return allResources.filter { resource in
      resource.title.lowercased().contains(lowercaseQuery) ||
      resource.description.lowercased().contains(lowercaseQuery) ||
      resource.tags.contains { $0.lowercased().contains(lowercaseQuery) }
    }
  }
  
  // MARK: - Fetch Resources by Tags
  func fetchResources(withTags tags: [String]) async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let snapshot = try await collection
      .whereField("tags", arrayContainsAny: tags)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
  }
  
  // MARK: - Fetch Resources Recommended For Role
  func fetchResources(recommendedFor role: String) async throws -> [Resource] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    let snapshot = try await collection
      .whereField("recommendedFor", arrayContains: role)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Resource.self)
    }
  }
  
  // MARK: - Update Resource
  func updateResource(_ resource: Resource) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    guard let resourceID = resource.id else {
      throw ResourceServiceError.invalidResourceID
    }
    
    var updatedResource = resource
    updatedResource.updatedAt = Date()
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
      .document(resourceID)
    
    try document.setData(from: updatedResource, merge: true)
  }
  
  // MARK: - Toggle Resource Featured Status
  func toggleResourceFeatured(resourceID: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
      .document(resourceID)
    
    // First fetch the current status
    let snapshot = try await document.getDocument()
    guard var resource = try? snapshot.data(as: Resource.self) else {
      throw ResourceServiceError.resourceNotFound
    }
    
    // Toggle the featured status
    resource.isFeatured.toggle()
    resource.updatedAt = Date()
    
    try document.setData(from: resource)
  }
  
  // MARK: - Delete Resource
  func deleteResource(id: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
      .document(id)
    
    try await document.delete()
  }
  
  // MARK: - Resource Analytics
  func fetchResourceAnalytics() async throws -> ResourceAnalytics {
    let allResources = try await fetchAllResources()
    let featuredResources = allResources.filter { $0.isFeatured }
    
    // Count resources by category
    var categoryCount: [Resource.ResourceCategory: Int] = [:]
    for category in Resource.ResourceCategory.allCases {
      categoryCount[category] = allResources.filter { $0.category == category }.count
    }
    
    return ResourceAnalytics(
      totalResources: allResources.count,
      featuredResources: featuredResources.count,
      resourcesByCategory: categoryCount,
      mostRecentResource: allResources.first
    )
  }
  
  // MARK: - Listen to Resource Changes
  func listenToResources(completion: @escaping @Sendable (Result<[Resource], Error>) -> Void) -> ListenerRegistration? {
    guard let currentUser = Auth.auth().currentUser else {
      completion(.failure(ResourceServiceError.userNotAuthenticated))
      return nil
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    return collection
      .order(by: "createdAt", descending: true)
      .addSnapshotListener { snapshot, error in
        if let error = error {
          completion(.failure(error))
          return
        }
        
        guard let documents = snapshot?.documents else {
          completion(.success([]))
          return
        }
        
        do {
          let resources = try documents.compactMap { document in
            try document.data(as: Resource.self)
          }
          completion(.success(resources))
        } catch {
          completion(.failure(error))
        }
      }
  }
  
  // MARK: - Bulk Operations
  func bulkAddResources(_ resources: [Resource]) async throws -> [String] {
    guard let currentUser = Auth.auth().currentUser else {
      throw ResourceServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.resources.rawValue)
    
    var resourceIDs: [String] = []
    
    // Use sequential addDocument calls since batch doesn't support addDocument
    for resource in resources {
      // Don't manually set @DocumentID - let Firestore manage it
      let resourceToSave = resource
      
      do {
        let docRef = try collection.addDocument(from: resourceToSave)
        resourceIDs.append(docRef.documentID)
      } catch {
        throw ResourceServiceError.saveFailed("Failed to save resource: \(error.localizedDescription)")
      }
    }
    
    return resourceIDs
  }
  
  // MARK: - Completion-based methods for backward compatibility
  func fetchResources(category: String, completion: @escaping @Sendable (Result<[Resource], Error>) -> Void) {
    Task { @Sendable in
      do {
        // Convert string to ResourceCategory
        guard let resourceCategory = Resource.ResourceCategory(rawValue: category.lowercased()) else {
          completion(.failure(ResourceServiceError.invalidCategory))
          return
        }
        
        let resources = try await fetchResources(category: resourceCategory)
        completion(.success(resources))
      } catch {
        completion(.failure(error))
      }
    }
  }
  
  func addResource(_ resource: Resource, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
    Task {
      do {
        _ = try await addResource(resource)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }
}

// MARK: - Resource Analytics Model
struct ResourceAnalytics: Codable, Sendable {
  let totalResources: Int
  let featuredResources: Int
  let resourcesByCategory: [Resource.ResourceCategory: Int]
  let mostRecentResource: Resource?
}

// MARK: - Error Handling
extension ResourceService {
  enum ResourceServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case resourceNotFound
    case invalidResourceID
    case invalidCategory
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
      switch self {
      case .userNotAuthenticated:
        return "User must be authenticated to access resources"
      case .resourceNotFound:
        return "Resource not found"
      case .invalidResourceID:
        return "Invalid resource ID provided"
      case .invalidCategory:
        return "Invalid resource category provided"
      case .saveFailed(let message):
        return "Failed to save resource: \(message)"
      case .fetchFailed(let message):
        return "Failed to fetch resource: \(message)"
      case .updateFailed(let message):
        return "Failed to update resource: \(message)"
      case .deleteFailed(let message):
        return "Failed to delete resource: \(message)"
      }
    }
  }
}
