//
//  DocumentService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation
import FirebaseFirestore

// MARK: - Document Operations
extension FirebaseManager {
    // MARK: Create Document
    func createDocument<T: Codable & Identifiable>(inCollection collection: FirestoreCollection, document: T) async throws {
        try collection.reference().addDocument(from: document)
    }
    
    // MARK: Update Document
    func updateDocument<T: Codable & Identifiable>(inCollection collection: FirestoreCollection, document: T) async throws where T.ID == String? {
        guard let documentID = document.id else { return }
        try collection.reference().document(documentID).setData(from: document)
    }
    
    // MARK: Delete Document
    func deleteDocument(inCollection collection: FirestoreCollection, withId id: String) async throws {
        try await collection.reference().document(id).delete()
    }
    
    // MARK: Fetch Document In Collection
    func fetchDocument<T: Codable & Identifiable>(inCollection collection: FirestoreCollection, withId id: String) async throws -> T {
        let documentRef = collection.reference().document(id)
        let documentSnapshot = try await documentRef.getDocument()
        
        do {
            let fetchedDocument = try documentSnapshot.data(as: T.self)
            return fetchedDocument
        } catch {
            throw FirebaseManagerError.dataFetchFailed("ERROR: \(error). Failed to fetch document in \(collection) with ID \(id)")
        }
    }
    
    // MARK: Fetch All Documents In Collection
    func fetchEveryDocument<T: Codable & Identifiable>(inCollection collection: FirestoreCollection) async throws -> [T] {
        do {
            let snapshot = try await collection.reference().getDocuments()
            let documents = snapshot.documents.compactMap { document -> T? in
                try? document.data(as: T.self)
            }
            return documents
        } catch {
            print("ERROR: \(error). Failed to fetch documents in collection \(collection)")
            throw error
        }
    }
    
    func fetchDocuments<T: Codable & Identifiable>(inCollection collection: FirestoreCollection, withIDs ids: [String]? = nil, fieldName: String? = nil, fieldValue: Any? = nil, includeCurrentDocument: Bool = true, limit: Int = 100, excludeDocumentIds: [String]? = nil) async throws -> [T] where T.ID == String? {
                
        var query: Query = collection.reference()
        
        if let fieldName = fieldName, let fieldValue = fieldValue {
            query = query.whereField(fieldName, isEqualTo: fieldValue)
        }
//        
//        if let currentDocumentId = FirestoreConstants.currentUser?.uid, !includeCurrentDocument {
//            query = query.whereField("uid", isNotEqualTo: currentDocumentId)
//        }
//        
        if let excludeDocumentIds = excludeDocumentIds, !excludeDocumentIds.isEmpty {
            query = query.whereField("uid", notIn: excludeDocumentIds)
        }
        
        if let ids = ids, !ids.isEmpty {
            query = query.whereField("id", in: ids)
        }
        
        if limit > 0 {
            query = query.limit(to: limit)
        }
        
        do {
            let snapshot = try await query.getDocuments()
            let documents = snapshot.documents.compactMap { document -> T? in
                try? document.data(as: T.self)
            }
            return documents
        } catch {
            print("Failed to fetch \(collection) documents: \(error)")
            throw error
        }
    }
    
    
    // MARK: Increment Field For Document In Collection
    func incrementField(forDocumentId documentId: String, inCollection collection: FirestoreCollection, field: String, incrementValue: Int = 1, completion: @escaping (Result<Void, Error>) -> Void) {
        let documentRef = collection.reference().document(documentId)
        
        firestore.runTransaction({ (transaction, errorPointer) -> Any? in
            let documentSnapshot: DocumentSnapshot
            do {
                documentSnapshot = try transaction.getDocument(documentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let currentValue = documentSnapshot.data()?[field] as? Int else {
                let error = NSError(domain: "App", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve \(field) from Firestore"])
                errorPointer?.pointee = error
                return nil
            }
            
            transaction.updateData([field: currentValue + incrementValue], forDocument: documentRef)
            return nil
        }) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
