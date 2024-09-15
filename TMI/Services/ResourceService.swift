//
//  ResourceService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

class ResourceService {
    static let shared = ResourceService()
    private let databaseService = DatabaseService.shared
    
    private init() {}
    
    func fetchResources(category: String, completion: @escaping (Result<[Resource], Error>) -> Void) {
        // Implement fetching resources based on category
    }
    
    func addResource(_ resource: Resource, completion: @escaping (Result<Void, Error>) -> Void) {
        databaseService.saveDocument(collection: "resources", documentID: resource.id ?? "nil", data: resource, completion: completion)
    }
    
    // Add more methods for updating and deleting resources
}
