//
//  TMIPlanService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

class TMIPlanService {
    static let shared = TMIPlanService()
    private let databaseService = DatabaseService.shared
    
    private init() {}
    
    func createTMIPlan(_ plan: TMIPlan, completion: @escaping (Result<Void, Error>) -> Void) {
        databaseService.saveDocument(collection: "tmiPlans", documentID: plan.id ?? "nil", data: plan, completion: completion)
    }
    
    func fetchTMIPlan(id: String, completion: @escaping (Result<TMIPlan, Error>) -> Void) {
        databaseService.fetchDocument(collection: "tmiPlans", documentID: id, completion: completion)
    }
    
    // Add more methods for updating and deleting TMI plans
}

