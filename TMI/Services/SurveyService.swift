//
//  SurveyService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

class SurveyService {
    static let shared = SurveyService()
    private let databaseService = DatabaseService.shared
    
    private init() {}
    
    func submitSurvey(_ survey: Survey, completion: @escaping (Result<Void, Error>) -> Void) {
        databaseService.saveDocument(collection: "surveys", documentID: survey.id ?? "nil", data: survey, completion: completion)
    }
    
    func fetchSurvey(id: String, completion: @escaping (Result<Survey, Error>) -> Void) {
        databaseService.fetchDocument(collection: "surveys", documentID: id, completion: completion)
    }
    
    // Add more methods for fetching survey results and analytics
}

