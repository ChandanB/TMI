//
//  DatabaseService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore

class DatabaseService {
    static let shared = DatabaseService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchDocument<T: Codable>(collection: String, documentID: String, completion: @escaping (Result<T, Error>) -> Void) {
        db.collection(collection).document(documentID).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
            } else if let document = document, document.exists {
                do {
                    let item = try document.data(as: T.self)
                    completion(.success(item))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func saveDocument<T: Encodable>(collection: String, documentID: String, data: T, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection(collection).document(documentID).setData(from: data) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}

