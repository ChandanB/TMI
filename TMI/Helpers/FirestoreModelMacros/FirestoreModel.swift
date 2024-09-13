import Foundation

@attached(member, names: arbitrary)
@attached(extension, conformances: FirestorePersistentModel)
public macro FirestoreModel() = #externalMacro(module: "FirestoreModelMacros", type: "FirestoreModelMacro")

import SwiftData
import FirebaseFirestore
import Combine

public protocol FirestorePersistentModel: Identifiable, Codable {
    var id: String { get set }
    var data: [String: Any] { get }
    static var collectionName: String { get }
    init(id: String, data: [String: Any])
    mutating func update(with data: [String: Any])
}

public extension FirestorePersistentModel {
    var id: String {
        get { data["id"] as? String ?? UUID().uuidString }
        set { /* Implementation needed */ }
    }
    
    func getValue<Value>(forKey key: String) -> Value? {
        return data[key] as? Value
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public class FirestoreModelWrapper<T: FirestorePersistentModel>: ObservableObject {
    @Published public var model: T
    public var firestoreContext: FirestoreContext?
    
    public init(_ model: T, context: FirestoreContext? = nil) {
        self.model = model
        self.firestoreContext = context
    }
    
    public var hasChanges: Bool {
        guard let context = firestoreContext else { return false }
        return context.isChanged(id: model.id, in: T.collectionName)
    }
    
    public var isDeleted: Bool {
        guard let context = firestoreContext else { return false }
        return context.isDeleted(id: model.id, in: T.collectionName)
    }
    
    public func save() async throws {
        guard let context = firestoreContext else {
            throw FirestoreError.contextNotSet
        }
        
        if hasChanges {
            await context.update(model.data, id: model.id, in: T.collectionName)
        } else {
            await context.insert(model.data, in: T.collectionName)
        }
    }
    
    public func delete() async throws {
        guard let context = firestoreContext else {
            throw FirestoreError.contextNotSet
        }
        
        await context.delete(id: model.id, in: T.collectionName)
    }
    
    public static func fetch(withId id: String, in context: FirestoreContext) async throws -> FirestoreModelWrapper<T> {
        let snapshot = try await context.db.collection(T.collectionName).document(id).getDocument()
        guard var data = snapshot.data() else {
            throw FirestoreError.documentNotFound
        }
        data["id"] = id
        let model = T(id: id, data: data)
        return FirestoreModelWrapper(model, context: context)
    }
    
    public static func fetchAll(in context: FirestoreContext, where predicate: ((Query) -> Query)? = nil) async throws -> [FirestoreModelWrapper<T>] {
        let documents = try await context.fetch(from: T.collectionName, where: predicate)
        return documents.compactMap { document in
            var data = document
            let id = document["id"] as? String ?? UUID().uuidString
            data["id"] = id
            let model = T(id: id, data: data)
            return FirestoreModelWrapper(model, context: context)
        }
    }
}

enum FirestoreError: Error {
    case contextNotSet
    case documentNotFound
}
