//
//  FirestoreContext.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import FirebaseFirestore

public class FirestoreContext: Equatable, ObservableObject {
    public var undoManager: UndoManager?
    
    private var insertedModels: [String: [String: Any]] = [:]
    private var changedModels: [String: [String: Any]] = [:]
    private var deletedModels: Set<String> = []
    
    public var insertedModelsArray: [[String: Any]] { Array(insertedModels.values) }
    public var changedModelsArray: [[String: Any]] { Array(changedModels.values) }
    public var deletedModelsArray: [String] { Array(deletedModels) }
    
    public let db: Firestore
    public var autosaveEnabled: Bool
    
    public init(_ db: Firestore, autosaveEnabled: Bool = true) {
        self.db = db
        self.autosaveEnabled = autosaveEnabled
    }
    
    public static func == (lhs: FirestoreContext, rhs: FirestoreContext) -> Bool {
        return lhs.db == rhs.db
    }
    
    public var hasChanges: Bool {
        return !insertedModels.isEmpty || !changedModels.isEmpty || !deletedModels.isEmpty
    }
    
    public func model(for id: String, in collection: String) -> [String: Any]? {
        return insertedModels["\(collection)/\(id)"] ?? changedModels["\(collection)/\(id)"]
    }
    
    public func insert(_ model: [String: Any], in collection: String) async {
        let id = UUID().uuidString
        insertedModels["\(collection)/\(id)"] = model
        if autosaveEnabled {
            try? await save()
        }
    }
    
    public func update(_ model: [String: Any], id: String, in collection: String) async {
        changedModels["\(collection)/\(id)"] = model
        if autosaveEnabled {
            try? await save()
        }
    }
    
    public func delete(id: String, in collection: String) async {
        deletedModels.insert("\(collection)/\(id)")
        if autosaveEnabled {
            try? await save()
        }
    }
    
    public func isChanged(id: String, in collection: String) -> Bool {
        return changedModels["\(collection)/\(id)"] != nil
    }
    
    public func isDeleted(id: String, in collection: String) -> Bool {
        return deletedModels.contains("\(collection)/\(id)")
    }
    
    public func rollback() {
        insertedModels.removeAll()
        changedModels.removeAll()
        deletedModels.removeAll()
    }
    
    public func save() async throws {
        let batch = db.batch()
        
        for (path, model) in insertedModels {
            let ref = db.document(path)
            batch.setData(model, forDocument: ref)
        }
        
        for (path, model) in changedModels {
            let ref = db.document(path)
            batch.updateData(model, forDocument: ref)
        }
        
        for path in deletedModels {
            let ref = db.document(path)
            batch.deleteDocument(ref)
        }
        
        try await batch.commit()
        
        rollback() // Clear changes after successful save
    }
    
    public func fetch(from collection: String, where predicate: ((Query) -> Query)? = nil) async throws -> [[String: Any]] {
        var query: Query = db.collection(collection)
        if let predicate = predicate {
            query = predicate(query)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.map { $0.data() }
    }
    
    public func fetchCount(from collection: String, where predicate: ((Query) -> Query)? = nil) async throws -> Int {
        var query: Query = db.collection(collection)
        if let predicate = predicate {
            query = predicate(query)
        }
        let snapshot = try await query.count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    public static let willSave = Notification.Name("FirestoreContextWillSave")
    public static let didSave = Notification.Name("FirestoreContextDidSave")
    
    public enum NotificationKey: String {
        case queryGeneration
        case invalidatedAllIdentifiers
        case insertedIdentifiers
        case updatedIdentifiers
        case deletedIdentifiers
    }
}
