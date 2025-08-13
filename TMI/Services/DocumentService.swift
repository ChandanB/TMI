//
//  DocumentService.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore
import Foundation

// MARK: - Document Operations
extension FirebaseManager {
  // MARK: Create Document
  func createDocument<T: Codable & Identifiable>(
    inCollection collection: FirestoreCollection, document: T
  ) async throws {
    try collection.reference().addDocument(from: document)
  }

  // MARK: Update Document
  func updateDocument<T: Codable & Identifiable>(
    inCollection collection: FirestoreCollection, document: T
  ) async throws where T.ID == String? {
    guard let documentID = document.id else { return }
    try collection.reference().document(documentID).setData(from: document)
  }

  // MARK: Delete Document
  func deleteDocument(inCollection collection: FirestoreCollection, withId id: String) async throws
  {
    try await collection.reference().document(id).delete()
  }

  // MARK: Fetch Document In Collection
  func fetchDocument<T: Codable & Identifiable>(
    inCollection collection: FirestoreCollection, withId id: String
  ) async throws -> T {
    let documentRef = collection.reference().document(id)
    let documentSnapshot = try await documentRef.getDocument()

    do {
      let fetchedDocument = try documentSnapshot.data(as: T.self)
      return fetchedDocument
    } catch {
      throw FirebaseError.dataFetchFailed(
        "ERROR: \(error). Failed to fetch document in \(collection) with ID \(id)")
    }
  }

  func fetchDocuments<T: Codable & Identifiable>(
    inCollection collection: FirestoreCollection, withIDs ids: [String]? = nil,
    fieldName: String? = nil, fieldValue: Any? = nil, includeCurrentDocument: Bool = true,
    limit: Int = 100, excludeDocumentIds: [String]? = nil
  ) async throws -> [T] where T.ID == String? {

    var query: Query = collection.reference()

    if let fieldName = fieldName, let fieldValue = fieldValue {
      query = query.whereField(fieldName, isEqualTo: fieldValue)
    }

    if let currentDocumentId = FirestoreConstants.currentUser?.uid, !includeCurrentDocument {
      query = query.whereField("uid", isNotEqualTo: currentDocumentId)
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
}