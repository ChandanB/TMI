// Student.swift

import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore
import Combine

struct Student: Codable, Identifiable, Hashable {
    // MARK: - Firebase Properties
    @DocumentID var id: String?
    
    // MARK: - Core Properties
    let name: String
    let grade: String
    let dateOfBirth: Date
    let studentID: String?
    var photoURL: URL?
    
    // MARK: - TMI Related Properties
    let tmiPlans: [TMIPlan]?
    var interests: [Interest]
    var hobbies: [Hobby]
    var surveyResults: [SurveyResult]?
    
    // MARK: - Academic & Performance Tracking
    var academicPerformance: AcademicPerformance?
    var engagementHistory: [EngagementRecord]?
    var notes: [StudentNote]?
    var lastInteractionDate: Date?
    
    // MARK: - Computed Properties
    
    // Student initials for avatar display
    var initials: String {
        let components = name.components(separatedBy: " ")
        return components.reduce("") { result, component in
            guard let first = component.first else { return result }
            return result + String(first)
        }
    }
    
    // Calculates display name with appropriate formatting
    var displayName: String {
        let components = name.components(separatedBy: " ")
        if components.count > 1, let first = components.first, let last = components.last {
            return "\(first) \(last)"
        }
        return name
    }
    
    // Formatted date of birth
    var formattedDateOfBirth: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateOfBirth)
    }
    
    // Age calculation
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    // Primary interest categories for quick reference
    var primaryInterestCategories: [InterestCategory] {
        let categories = interests.flatMap { $0.category }
        let uniqueCategories = Set(categories)
        return uniqueCategories.sorted()
    }

    // Status indicators
    var hasTMIPlan: Bool {
        return tmiPlans?.isEmpty == false
    }
    
    var hasActiveSurvey: Bool {
        return surveyResults?.contains(where: { $0.isComplete == false }) ?? false
    }
    
    // Engagement score - calculated based on real data if available, otherwise random placeholder
    var engagementScore: Double {
        if let engagementHistory = engagementHistory, !engagementHistory.isEmpty {
            // Calculate average from last 5 engagement records (or fewer if not available)
            let recentEngagements = engagementHistory.sorted(by: { $0.date > $1.date })
                .prefix(5)
            
            let sum = recentEngagements.reduce(0.0) { $0 + $1.score }
            return sum / Double(recentEngagements.count)
        }
        
        // Fallback to random for demo/placeholder
        return Double.random(in: 0...1)
    }
    
    // Engagement trend - whether engagement is improving, declining, or stable
    var engagementTrend: EngagementTrend {
        guard let engagementHistory = engagementHistory, engagementHistory.count >= 2 else {
            return .stable
        }
        
        let sortedRecords = engagementHistory.sorted(by: { $0.date > $1.date })
        if sortedRecords.count >= 2 {
            let current = sortedRecords[0].score
            let previous = sortedRecords[1].score
            
            let difference = current - previous
            if difference > 0.05 {
                return .improving
            } else if difference < -0.05 {
                return .declining
            }
        }
        
        return .stable
    }
    
    // Visual avatar for UI representation
    var avatarColor: AvatarColor {
        // Deterministic color based on name
        let nameHash = name.hash
        let colors: [AvatarColor] = [.blue, .green, .orange, .purple, .teal, .pink, .indigo]
        let index = abs(nameHash) % colors.count
        return colors[index]
    }
    
    // MARK: - Initialization
    
    init(id: String? = nil,
         name: String,
         grade: String,
         dateOfBirth: Date,
         tmiPlans: [TMIPlan]? = nil,
         studentID: String? = nil,
         interests: [Interest] = [],
         hobbies: [Hobby] = [],
         photoURL: URL? = nil,
         surveyResults: [SurveyResult]? = nil,
         academicPerformance: AcademicPerformance? = nil,
         engagementHistory: [EngagementRecord]? = nil,
         notes: [StudentNote]? = nil,
         lastInteractionDate: Date? = nil) {
        
        self.id = id
        self.name = name
        self.grade = grade
        self.dateOfBirth = dateOfBirth
        self.tmiPlans = tmiPlans
        self.studentID = studentID
        self.interests = interests
        self.hobbies = hobbies
        self.photoURL = photoURL
        self.surveyResults = surveyResults
        self.academicPerformance = academicPerformance
        self.engagementHistory = engagementHistory
        self.notes = notes
        self.lastInteractionDate = lastInteractionDate
    }
    
    // MARK: - Hashable & Equatable
    
    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Supporting Types

enum EngagementTrend: String, Codable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

enum AvatarColor: String, Codable {
    case blue
    case green
    case orange
    case purple
    case teal
    case pink
    case indigo
}

struct EngagementRecord: Codable, Hashable {
    var date: Date
    var score: Double
    var source: EngagementSource
    var notes: String?
    
    enum EngagementSource: String, Codable {
        case survey
        case activityCompletion
        case teacherInput
        case systemCalculated
    }
}

struct AcademicPerformance: Codable, Hashable {
    var gpa: Double?
    var subjects: [SubjectPerformance]
    var strengths: [String]
    var areasForImprovement: [String]
}

struct SubjectPerformance: Codable, Hashable {
    var name: String
    var grade: String
    var score: Double
    var interestAlignment: Double
}

struct StudentNote: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var author: String
    var content: String
    var category: NoteCategory
    
    enum NoteCategory: String, Codable {
        case general
        case academic
        case behavioral
        case tmiPlan
    }
}

struct SurveyResult: Codable, Hashable, Identifiable {
    var id: String
    var surveyName: String
    var date: Date
    var isComplete: Bool
    var responses: [SurveyResponse]
    
    struct SurveyResponse: Codable, Hashable {
        var questionID: String
        var question: String
        var answer: String
    }
}

// MARK: - Sample Data

extension Student {
    static var sampleStudent: Student {
        let interests = Interest.sampleInterests
        let hobbies = Hobby.sampleHobbies
        let surveyResults = [
            SurveyResult(
                id: "survey1",
                surveyName: "Interest Assessment",
                date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 1 week ago
                isComplete: true,
                responses: [
                    SurveyResult.SurveyResponse(
                        questionID: "q1",
                        question: "What subjects do you enjoy most?",
                        answer: "Science, Art"
                    )
                ]
            )
        ]
        
        let academicPerformance = AcademicPerformance(
            gpa: 3.7,
            subjects: [
                SubjectPerformance(name: "Mathematics", grade: "B+", score: 0.87, interestAlignment: 0.65),
                SubjectPerformance(name: "Science", grade: "A", score: 0.92, interestAlignment: 0.88),
                SubjectPerformance(name: "English", grade: "A-", score: 0.90, interestAlignment: 0.72)
            ],
            strengths: ["Critical thinking", "Scientific inquiry"],
            areasForImprovement: ["Writing organization", "Time management"]
        )
        
        let engagementHistory = [
            EngagementRecord(
                date: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
                score: 0.65,
                source: .teacherInput
            ),
            EngagementRecord(
                date: Date().addingTimeInterval(-15 * 24 * 60 * 60), // 15 days ago
                score: 0.72,
                source: .survey
            ),
            EngagementRecord(
                date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
                score: 0.78,
                source: .activityCompletion
            )
        ]
        
        let notes = [
            StudentNote(
                date: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2 weeks ago
                author: "Ms. Johnson",
                content: "John has shown significant improvement in science projects, particularly when they align with his interest in robotics.",
                category: .academic
            )
        ]
        
        return Student(
            name: "John Doe",
            grade: "10",
            dateOfBirth: Date(),
            interests: [],
            hobbies: [],
            surveyResults: surveyResults,
            academicPerformance: academicPerformance,
            engagementHistory: engagementHistory,
            notes: notes,
            lastInteractionDate: Date().addingTimeInterval(-3 * 24 * 60 * 60) // 3 days ago
        )
    }
    
    static var sampleStudents: [Student] {
        return [
            Student(
                name: "John Doe",
                grade: "10",
                dateOfBirth: Date(),
                interests: [],
                hobbies: [],
                surveyResults: [
                    SurveyResult(
                        id: "survey1",
                        surveyName: "Interest Assessment",
                        date: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                        isComplete: true,
                        responses: []
                    )
                ],
                engagementHistory: [
                    EngagementRecord(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        score: 0.65,
                        source: .teacherInput
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                        score: 0.72,
                        source: .survey
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                        score: 0.78,
                        source: .activityCompletion
                    )
                ]
            ),
            Student(
                name: "Jane Smith",
                grade: "11",
                dateOfBirth: Date(),
                interests: [],
                hobbies: [],
                engagementHistory: [
                    EngagementRecord(
                        date: Date().addingTimeInterval(-45 * 24 * 60 * 60),
                        score: 0.82,
                        source: .teacherInput
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        score: 0.85,
                        source: .survey
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                        score: 0.80,
                        source: .activityCompletion
                    )
                ]
            ),
            Student(
                name: "Alice Johnson",
                grade: "9",
                dateOfBirth: Date(),
                interests: [],
                hobbies: [],
                engagementHistory: [
                    EngagementRecord(
                        date: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                        score: 0.45,
                        source: .teacherInput
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        score: 0.52,
                        source: .survey
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                        score: 0.58,
                        source: .activityCompletion
                    )
                ]
            ),
            Student(
                name: "Michael Chen",
                grade: "12",
                dateOfBirth: Date(),
                tmiPlans: [],
                hobbies: [],
                engagementHistory: [
                    EngagementRecord(
                        date: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                        score: 0.70,
                        source: .teacherInput
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                        score: 0.75,
                        source: .survey
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        score: 0.90,
                        source: .activityCompletion
                    )
                ]
            ),
            Student(
                name: "Emma Rodriguez",
                grade: "10",
                dateOfBirth: Date(),
                interests: [],
                hobbies: [],
                engagementHistory: [
                    EngagementRecord(
                        date: Date().addingTimeInterval(-45 * 24 * 60 * 60),
                        score: 0.30,
                        source: .teacherInput
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        score: 0.25,
                        source: .survey
                    ),
                    EngagementRecord(
                        date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                        score: 0.20,
                        source: .activityCompletion
                    )
                ]
            )
        ]
    }
}
