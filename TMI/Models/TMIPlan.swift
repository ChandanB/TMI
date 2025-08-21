// TMIPlan.swift

import Foundation
import SwiftData
import FirebaseFirestore

enum TMIPlanModel: String, CaseIterable, Codable, Sendable {
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

struct TMIPlan: Codable, Identifiable, Hashable, @unchecked Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var student: Student
    var students: [Student]
    var model: TMIPlanModel
    var interests: [Interest]
    var hobbies: [Hobby]
    var startDate: Date
    var endDate: Date?
    var creationDate: Date
    var lastUpdated: Date
    let goals: [Goal]
    var progress: Double
    var notes: String
    var strategies: [String]?
    var progressTracking: [ProgressEntry]?
    var createdBy: String


    init(id: String? = nil, title: String, description: String? = nil, student: Student, students: [Student], model: TMIPlanModel, interests: [Interest], hobbies: [Hobby], startDate: Date, endDate: Date?, creationDate: Date, lastUpdated: Date, goals: [Goal], progress: Double, notes: String, strategies: [String]? = nil, progressTracking: [ProgressEntry]? = nil, createdBy: String) {
        self.id = id
        self.title = title
        self.description = description
        self.student = student
        self.students = students
        self.model = model
        self.interests = interests
        self.hobbies = hobbies
        self.startDate = startDate
        self.endDate = endDate
        self.creationDate = creationDate
        self.lastUpdated = lastUpdated
        self.goals = goals
        self.progress = progress
        self.notes = notes
        self.strategies = strategies
        self.progressTracking = progressTracking
        self.createdBy = createdBy
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
            "title": title,
            "description": description ?? "",
            "model": model.rawValue,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate?.timeIntervalSince1970 as Any,
            "creationDate": creationDate.timeIntervalSince1970,
            "lastUpdated": lastUpdated.timeIntervalSince1970,
            "progress": progress,
            "notes": notes,
            "createdBy": createdBy
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
        data["hobbies"] = hobbies.map { $0.toFirestoreData() }

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
        
        data["strategies"] = strategies
        data["progressTracking"] = progressTracking?.map { entry in
            return [
                "score": entry.score,
                "date": entry.date.timeIntervalSince1970,
                "notes": entry.notes as Any
            ]
        }

        return data
    }
}

struct ProgressEntry: Codable, Sendable, Hashable {
    let score: Double
    let date: Date
    let notes: String?
}

extension TMIPlan {
    static var samplePlan: TMIPlan {
        return TMIPlan(
            title: "Chase Your Space Sample Plan",
            description: "A sample plan for chasing your space.",
            student: Student.sampleStudents[0],
            students: Student.sampleStudents,
            model: .chaseYourSpace,
            interests: [],
            hobbies: [],
            startDate: Date(),
            endDate: nil,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.50,
            notes: "Student is actively engaged in science club and coding workshops.",
            createdBy: "system"
        )
    }
    
    static var samplePlans: [TMIPlan] {
        let student = Student.sampleStudent
        let plan1 = TMIPlan.samplePlan
        
        let plan2 = TMIPlan(
            title: "Acknowledge Interests Sample Plan",
            description: "A sample plan for acknowledging interests.",
            student: Student.sampleStudents[1],
            students: Student.sampleStudents,
            model: .acknowledgeInterests,
            interests: student.interests,
            hobbies: student.hobbies,
            startDate: Date(),
            endDate: nil,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.75,
            notes: "Student is actively engaged in science club and coding workshops.",
            createdBy: "system")
        
        let plan3 = TMIPlan(
            title: "Align Your Mind Sample Plan",
            description: "A sample plan for aligning your mind.",
            student: Student.sampleStudents[2],
            students: Student.sampleStudents,
            model: .alignYourMind,
            interests: student.interests,
            hobbies: student.hobbies,
            startDate: Date(),
            endDate: nil,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0.15,
            notes: "Student is actively engaged in science club and coding workshops.",
            createdBy: "system")
        
        return [plan1, plan2, plan3]
    }
}

enum GoalStatus: String, Codable, CaseIterable, Sendable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
}

struct Goal: Identifiable, Codable, Sendable {
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
