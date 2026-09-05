//
//  RecommendationStore.swift
//  TMI
//
//  Testable persistence seam for RecommendationsService. Mirrors the narrow
//  surface RecommendationsService actually needs so paths and payloads can be
//  verified without the Firestore emulator.
//

@preconcurrency import FirebaseFirestore
import Foundation

nonisolated protocol RecommendationStore: Sendable {
    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])]

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: sending [String: Any],
        merge: Bool
    ) async throws

    func updateDocument(atCollectionPath path: String, id: String, data: sending [String: Any]) async throws

    func deleteDocument(atCollectionPath path: String, id: String) async throws
}

/// Firestore-backed implementation of `RecommendationStore`.
nonisolated final class FirebaseRecommendationStore: RecommendationStore, Sendable {
    private let db = Firestore.firestore()

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        let snapshot = try await db.collection(path)
            .whereField(field, isEqualTo: value)
            .getDocuments()
        return snapshot.documents.map { ($0.documentID, $0.data()) }
    }

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: sending [String: Any],
        merge: Bool
    ) async throws {
        try await db.collection(path).document(id).setData(data, merge: merge)
    }

    func updateDocument(atCollectionPath path: String, id: String, data: sending [String: Any]) async throws {
        try await db.collection(path).document(id).updateData(data)
    }

    func deleteDocument(atCollectionPath path: String, id: String) async throws {
        try await db.collection(path).document(id).delete()
    }
}
