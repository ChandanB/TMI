//
//  MeetingStore.swift
//  TMI
//
//  Testable persistence seam for MeetingService. Mirrors the narrow surface
//  MeetingService actually needs so paths and payloads can be verified
//  without the Firestore emulator.
//

@preconcurrency import FirebaseFirestore
import Foundation

nonisolated protocol MeetingStore: Sendable {
    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])]

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])]

    @discardableResult
    func addDocument(atCollectionPath path: String, data: sending [String: Any]) async throws -> String

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: sending [String: Any],
        merge: Bool
    ) async throws

    func updateDocument(atCollectionPath path: String, id: String, data: sending [String: Any]) async throws

    func deleteDocument(atCollectionPath path: String, id: String) async throws
}

/// Firestore-backed implementation of `MeetingStore`.
nonisolated final class FirebaseMeetingStore: MeetingStore, Sendable {
    private let db = Firestore.firestore()

    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])] {
        let snapshot = try await db.collection(path).getDocuments()
        return snapshot.documents.map { ($0.documentID, $0.data()) }
    }

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

    @discardableResult
    func addDocument(atCollectionPath path: String, data: sending [String: Any]) async throws -> String {
        let reference = try await db.collection(path).addDocument(data: data)
        return reference.documentID
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
