//
//  File.swift
//  
//
//  Created by Chandan Brown on 9/12/24.
//

import Foundation
import FirebaseFirestore
import Combine

@attached(accessor) @attached(peer, names: prefixed(`_`))
public macro FirestoreQuery() = #externalMacro(module: "FirestoreModelMacros", type: "FirestoreQueryMacro")

@attached(accessor) @attached(peer, names: prefixed(`_`))
public macro FirestoreQuery<Element: FirestorePersistentModel>(
    filter: ((Query) -> Query)? = nil,
    limit: Int? = nil,
    order: (String, Bool)? = nil
) = #externalMacro(module: "FirestoreModelMacros", type: "FirestoreQueryMacro")

@propertyWrapper
public class FirestoreQuery<T: FirestorePersistentModel>: ObservableObject {
    @Published public var wrappedValue: [T] = []
    
    private let context: FirestoreContext
    private let filter: ((Query) -> Query)?
    private let limit: Int?
    private let order: (String, Bool)?
    
    public init(context: FirestoreContext, filter: ((Query) -> Query)? = nil, limit: Int? = nil, order: (String, Bool)? = nil) {
        self.context = context
        self.filter = filter
        self.limit = limit
        self.order = order
    }
    
    public var projectedValue: FirestoreQuery<T> { self }
    
    public func fetch() async {
        do {
            var query: Query = context.db.collection(T.collectionName)
            
            if let filter = filter {
                query = filter(query)
            }
            
            if let limit = limit {
                query = query.limit(to: limit)
            }
            
            if let order = order {
                query = query.order(by: order.0, descending: order.1)
            }
            
            let snapshot = try await query.getDocuments()
            let documents = snapshot.documents.compactMap { document -> T? in
                var data = document.data()
                data["id"] = document.documentID
                return T(id: document.documentID, data: data)
            }
            
            await MainActor.run {
                self.wrappedValue = documents
            }
        } catch {
            print("Error fetching documents: \(error)")
        }
    }
}
