// Hobby.swift

import Foundation
import SwiftData
import FirebaseFirestore

struct Hobby: Codable, Identifiable, Hashable {
    public static func == (lhs: Hobby, rhs: Hobby) -> Bool {
        lhs.id == rhs.id
    }
    
    @DocumentID var id: String?
    var name: String
    var details: String?
    var relatedStudents: [Student]?
    
    static var collectionName: String { "hobbies" }
    
    init(id: String? = nil, name: String, details: String? = nil, relatedStudents: [Student]? = nil) {
        self.id = id
        self.name = name
        self.details = details
        self.relatedStudents = relatedStudents
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Hobby {
    static var sampleHobbies: [Hobby] {
        return [
            Hobby(name: "Reading", details: "Enjoys reading fiction novels", relatedStudents: nil),
            Hobby(name: "Sports", details: "Plays soccer and basketball", relatedStudents: nil),
            Hobby(name: "Music", details: "Plays the guitar and enjoys singing", relatedStudents: nil)
        ]
    }
}
