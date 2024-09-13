// Student.swift

import Foundation
import SwiftData
import FirebaseFirestore

struct Student: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let name: String
    let grade: String
    let dateOfBirth: Date
    let tmiPlans: [TMIPlan]?
    let studentID: String?
    var interests: [Interest]
    var hobbies: [Hobby]
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        return components.reduce("") { result, component in
            guard let first = component.first else { return result }
            return result + String(first)
        }
    }
    
    var engagementScore: Double {
        Double.random(in: 0...1)
    }
    
    init(id: String? = nil, name: String, grade: String, dateOfBirth: Date, tmiPlans: [TMIPlan]? = nil, studentID: String? = nil, interests: [Interest], hobbies: [Hobby]) {
        self.id = id
        self.name = name
        self.grade = grade
        self.dateOfBirth = dateOfBirth
        self.tmiPlans = tmiPlans
        self.studentID = studentID
        self.interests = interests
        self.hobbies = hobbies
    }
    
    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Student {
    static var sampleStudent: Student {
        let interests = Interest.sampleInterests
        let hobbies = Hobby.sampleHobbies
        return Student(
            name: "John Doe",
            grade: "10",
            dateOfBirth: Date(),
            interests: interests,
            hobbies: hobbies
        )
    }
    
    static var sampleStudents: [Student] {
        return [
            Student(
                name: "John Doe",
                grade: "10",
                dateOfBirth: Date(),
                interests: Interest.sampleInterests,
                hobbies: Hobby.sampleHobbies
            ),
            Student(
                name: "Jane Smith",
                grade: "11",
                dateOfBirth: Date(),
                interests: [Interest.sampleInterests[0]],
                hobbies: [Hobby.sampleHobbies[1]]
            ),
            Student(
                name: "Alice Johnson",
                grade: "9",
                dateOfBirth: Date(),
                interests: [Interest.sampleInterests[2]],
                hobbies: [Hobby.sampleHobbies[2]]
            )
        ]
    }
}
