// TMIPlan.swift

import Foundation
import SwiftData
import FirebaseFirestore

enum TMIPlanModel: String, CaseIterable, Codable {
    case chaseYourSpace = "Chase Your Space"
    case acknowledgeInterests = "Acknowledge Your Interests and Hobbies"
    case alignYourMind = "Align Your Mind"
    case directAndCorrect = "Direct & Correct Negative Behavior"
    case bullyToBoss = "From Bully to Boss"
    case meekToProtector = "From Meek to Promising Protector"
    
    var description: String {
        switch self {
        case .chaseYourSpace:
            return "For students who already know what they want to do in life. We help cultivate their career pathway choice."
        case .acknowledgeInterests:
            return "We meet with each student after the survey to reassure them of our support for their success based on their interests and hobbies."
        case .alignYourMind:
            return "Using individual survey results to help keep students focused and on task, like aligning a car."
        case .directAndCorrect:
            return "Working with the school Social Worker to provide coping skills and relate scenarios to students' interests and hobbies."
        case .bullyToBoss:
            return "Helping bullies find their intrinsic leader by tapping into their interests and guiding them towards positive leadership roles."
        case .meekToProtector:
            return "Empowering introverted or passive students by reflecting on their interests and hobbies to build confidence and develop coping skills."
        }
    }
}

struct TMIPlan: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var student: Student
    var students: [Student]
    var model: TMIPlanModel
    var interests: [Interest]
    var hobbies: [Hobby]
    var creationDate: Date
    var lastUpdated: Date
    let goals: [Goal]
    var progress: Double
    var notes: String
    
    init(id: String? = nil, student: Student, students: [Student], model: TMIPlanModel, interests: [Interest], hobbies: [Hobby], creationDate: Date, lastUpdated: Date, goals: [Goal], progress: Double, notes: String) {
        self.id = id
        self.student = student
        self.students = students
        self.model = model
        self.interests = interests
        self.hobbies = hobbies
        self.creationDate = creationDate
        self.lastUpdated = lastUpdated
        self.goals = goals
        self.progress = progress
        self.notes = notes
    }
    
    public static func == (lhs: TMIPlan, rhs: TMIPlan) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
    // MARK: - Firestore Conversion
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "model": model.rawValue,
            "creationDate": creationDate.timeIntervalSince1970,
            "lastUpdated": lastUpdated.timeIntervalSince1970,
            "progress": progress,
            "notes": notes
        ]
        
        // Convert student to basic data (just ID and name to avoid circular references)
        data["student"] = [
            "id": student.id ?? "",
            "name": student.name,
            "grade": student.grade
        ]
        
        // Convert students array
        data["students"] = students.map { student in
            return [
                "id": student.id ?? "",
                "name": student.name,
                "grade": student.grade
            ]
        }
        
        // Convert interests and hobbies to full objects for proper reconstruction
        data["interests"] = interests.map { $0.toFirestoreData() }
        data["hobbies"] = hobbies.map { hobby in
            return [
                "id": hobby.id.uuidString,
                "name": hobby.name,
                "category": hobby.category,
                "popularityScore": hobby.popularityScore as Any
            ]
        }
        
        // Convert goals
        data["goals"] = goals.map { goal in
            return [
                "id": goal.id.uuidString,
                "description": goal.description,
                "status": goal.status.rawValue,
                "progress": goal.progress,
                "notes": goal.notes as Any,
                "dueDate": goal.dueDate?.timeIntervalSince1970 as Any
            ]
        }
        
        return data
    }
}

extension TMIPlan {
    static var samplePlan: TMIPlan {
        return TMIPlan(
            student: Student.sampleStudents[0],
            students: Student.sampleStudents,
            model: .chaseYourSpace,
            interests: [],
            hobbies: [],
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.50,
            notes: "Student is actively engaged in science club and coding workshops."
        )
    }
    
    static var samplePlans: [TMIPlan] {
        let student = Student.sampleStudent
        let plan1 = TMIPlan.samplePlan
        
        let plan2 = TMIPlan(
            student: Student.sampleStudents[1],
            students: Student.sampleStudents,
            model: .acknowledgeInterests,
            interests: student.interests,
            hobbies: student.hobbies,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.75,
            notes: "Student is actively engaged in science club and coding workshops.")
        
        let plan3 = TMIPlan(
            student: Student.sampleStudents[2],
            students: Student.sampleStudents,
            model: .alignYourMind,
            interests: student.interests,
            hobbies: student.hobbies,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.15,
            notes: "Student is actively engaged in science club and coding workshops.")
        
        return [plan1, plan2, plan3]
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
}

struct Goal: Identifiable, Codable {
    let id: UUID
    var description: String
    var dueDate: Date?
    var status: GoalStatus
    var progress: Double // Range from 0.0 to 1.0
    var notes: String?
    
    // Initializer
    init(id: UUID = UUID(),
         description: String,
         dueDate: Date? = nil,
         status: GoalStatus = .notStarted,
         progress: Double = 0.0,
         notes: String? = nil) {
        self.id = id
        self.description = description
        self.dueDate = dueDate
        self.status = status
        self.progress = progress
        self.notes = notes
    }
}
