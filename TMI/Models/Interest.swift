// Interest.swift

import Foundation
import SwiftData
import FirebaseFirestore

struct Interest: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let name: String
    let details: String?
    let relatedStudents: [Student]?
    
    init(id: String? = nil, name: String, details: String?, relatedStudents: [Student]? = nil) {
        self.id = id
        self.name = name
        self.details = details
        self.relatedStudents = relatedStudents
    }
    
    public static func == (lhs: Interest, rhs: Interest) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Interest {
    static var sampleInterests: [Interest] {
        return [
            Interest(name: "Science", details: "Interested in physics and chemistry", relatedStudents: nil),
            Interest(name: "Art", details: "Likes drawing and painting", relatedStudents: nil),
            Interest(name: "Technology", details: "Enjoys coding and robotics", relatedStudents: nil)
        ]
    }
}
