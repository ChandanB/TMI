// Student.swift

import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore
import Combine

struct Student: Codable, Identifiable, Hashable, @unchecked Sendable {
    // MARK: - Firebase Properties
    @DocumentID var id: String?
    
    // MARK: - Core Properties
    let name: String
    let grade: String
    let school: String
    let dateOfBirth: Date
    let studentID: String?
    var photoURL: URL?
    
    // MARK: - TMI Related Properties
    let tmiPlans: [TMIPlan]?

    // DEPRECATED: Use StudentInterestService.getStudentInterests() instead
    // This field is maintained for backward compatibility during migration
    // Will be removed in a future release
    @available(*, deprecated, message: "Use StudentInterestService.getStudentInterests(studentId:) to fetch interests from edge collection")
    var interests: [Interest] // Now includes both interests and hobbies

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

    // First name only (for student mode privacy)
    var firstName: String {
        return name.components(separatedBy: " ").first ?? name
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
    
    // DEPRECATED: Use StudentInterestService to fetch interest categories
    // Primary interest categories for quick reference
    @available(*, deprecated, message: "Use StudentInterestService.getStudentInterests(studentId:) and extract categories from the result")
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
        
        // Fallback to neutral value for new students
        return 0.5
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
         school: String,
         dateOfBirth: Date,
         tmiPlans: [TMIPlan]? = nil,
         studentID: String? = nil,
         interests: [Interest] = [],
         photoURL: URL? = nil,
         surveyResults: [SurveyResult]? = nil,
         academicPerformance: AcademicPerformance? = nil,
         engagementHistory: [EngagementRecord]? = nil,
         notes: [StudentNote]? = nil,
         lastInteractionDate: Date? = nil) {
        
        self.id = id
        self.name = name
        self.grade = grade
        self.school = school
        self.dateOfBirth = dateOfBirth
        self.tmiPlans = tmiPlans
        self.studentID = studentID
        self.interests = interests
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
    
    // MARK: - Validation

    /// Validates the student data and throws validation errors if any issues are found
    func validate() throws {
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentValidationError.invalidName("Student name cannot be empty")
        }

        guard name.count <= 100 else {
            throw StudentValidationError.invalidName("Student name cannot exceed 100 characters")
        }

        // Validate grade
        guard !grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentValidationError.invalidGrade("Grade cannot be empty")
        }

        // Validate school
        guard !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudentValidationError.invalidSchool("School name cannot be empty")
        }

        guard school.count <= 200 else {
            throw StudentValidationError.invalidSchool("School name cannot exceed 200 characters")
        }

        // Validate age (derived from date of birth)
        let currentAge = age
        guard currentAge >= 3 && currentAge <= 120 else {
            throw StudentValidationError.invalidAge("Student age must be between 3 and 120")
        }

        // Validate date of birth is not in the future
        guard dateOfBirth <= Date() else {
            throw StudentValidationError.invalidDateOfBirth("Date of birth cannot be in the future")
        }

        // Validate student ID if provided
        if let studentID = studentID, !studentID.isEmpty {
            guard studentID.count <= 50 else {
                throw StudentValidationError.invalidStudentID("Student ID cannot exceed 50 characters")
            }
        }

        // Validate interests (now includes former hobbies)
        if interests.count > 40 {
            throw StudentValidationError.tooManyInterests("Cannot have more than 40 interests")
        }
    }

    /// Quick validation for UI feedback (non-throwing)
    var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }

    /// Get validation errors as an array for UI display
    var validationErrors: [StudentValidationError] {
        var errors: [StudentValidationError] = []

        do {
            try validate()
        } catch let error as StudentValidationError {
            errors.append(error)
        } catch {
            errors.append(.unknown(error.localizedDescription))
        }

        return errors
    }

    // MARK: - Firestore Conversion
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "grade": grade,
            "school": school,
            "dateOfBirth": dateOfBirth.timeIntervalSince1970
        ]
        
        // Optional properties
        if let studentID = studentID {
            data["studentID"] = studentID
        }
        
        if let photoURL = photoURL {
            data["photoURL"] = photoURL.absoluteString
        }
        
        if let lastInteractionDate = lastInteractionDate {
            data["lastInteractionDate"] = lastInteractionDate.timeIntervalSince1970
        }

        // MIGRATION NOTE: Interests are no longer stored inline in Student documents
        // They are now stored in edge collections: students/{studentId}/studentInterests/{interestId}
        // Use StudentInterestService to manage student interests
        // Keeping empty array for backward compatibility with existing reads
        data["interests"] = []

        // Note: Hobbies are now included in interests edge collection
        
        // Convert survey results
        if let surveyResults = surveyResults {
            data["surveyResults"] = surveyResults.map { surveyResult in
                [
                    "id": surveyResult.id,
                    "surveyName": surveyResult.surveyName,
                    "date": surveyResult.date.timeIntervalSince1970,
                    "isComplete": surveyResult.isComplete,
                    "responses": surveyResult.responses.map { response in
                        [
                            "questionID": response.questionID,
                            "question": response.question,
                            "answer": response.answer
                        ]
                    }
                ]
            }
        }
        
        // Convert academic performance
        if let academicPerformance = academicPerformance {
            data["academicPerformance"] = [
                "gpa": academicPerformance.gpa as Any,
                "subjects": academicPerformance.subjects.map { subject in
                    [
                        "name": subject.name,
                        "grade": subject.grade,
                        "score": subject.score,
                        "interestAlignment": subject.interestAlignment
                    ]
                },
                "strengths": academicPerformance.strengths,
                "areasForImprovement": academicPerformance.areasForImprovement
            ]
        }
        
        // Convert engagement history
        if let engagementHistory = engagementHistory {
            data["engagementHistory"] = engagementHistory.map { record in
                [
                    "date": record.date.timeIntervalSince1970,
                    "score": record.score,
                    "source": record.source.rawValue,
                    "notes": record.notes as Any
                ]
            }
        }
        
        // Convert notes
        if let notes = notes {
            data["notes"] = notes.map { note in
                [
                    "id": note.id.uuidString,
                    "date": note.date.timeIntervalSince1970,
                    "author": note.author,
                    "content": note.content,
                    "category": note.category.rawValue
                ]
            }
        }
        
        return data
    }
}

// MARK: - Supporting Types

enum EngagementTrend: String, Codable, Sendable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

enum AvatarColor: String, Codable, Sendable {
    case blue
    case green
    case orange
    case purple
    case teal
    case pink
    case indigo
}

struct EngagementRecord: Codable, Hashable, Sendable {
    var date: Date
    var score: Double
    var source: EngagementSource
    var notes: String?
    
    enum EngagementSource: String, Codable, Sendable {
        case survey
        case activityCompletion
        case teacherInput
        case systemCalculated
    }
}

struct AcademicPerformance: Codable, Hashable, Sendable {
    var gpa: Double?
    var subjects: [SubjectPerformance]
    var strengths: [String]
    var areasForImprovement: [String]
}

struct SubjectPerformance: Codable, Hashable, Sendable {
    var name: String
    var grade: String
    var score: Double
    var interestAlignment: Double
}

struct StudentNote: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var author: String
    var content: String
    var category: NoteCategory
    
    enum NoteCategory: String, Codable, Sendable {
        case general
        case academic
        case behavioral
        case tmiPlan
    }
}

struct SurveyResult: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var surveyName: String
    var date: Date
    var isComplete: Bool
    var responses: [SurveyResponse]
    
    struct SurveyResponse: Codable, Hashable, Sendable {
        var questionID: String
        var question: String
        var answer: String
    }
}

// MARK: - Sample Data

extension Student {
    static var sampleStudent: Student {
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
            school: "Sample High School",
            dateOfBirth: Date(),
            interests: [],
            surveyResults: surveyResults,
            academicPerformance: academicPerformance,
            engagementHistory: engagementHistory,
            notes: notes,
            lastInteractionDate: Date().addingTimeInterval(-3 * 24 * 60 * 60) // 3 days ago
        )
    }
    
    
    static var sampleStudents: [Student] {
        return comprehensiveSampleStudents
    }
}

// MARK: - Student Validation Errors

enum StudentValidationError: LocalizedError, Equatable {
    case invalidName(String)
    case invalidGrade(String)
    case invalidSchool(String)
    case invalidAge(String)
    case invalidDateOfBirth(String)
    case invalidStudentID(String)
    case tooManyInterests(String)
    case tooManyHobbies(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let message),
             .invalidGrade(let message),
             .invalidSchool(let message),
             .invalidAge(let message),
             .invalidDateOfBirth(let message),
             .invalidStudentID(let message),
             .tooManyInterests(let message),
             .tooManyHobbies(let message),
             .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Please enter a valid student name (1-100 characters)."
        case .invalidGrade:
            return "Please select or enter a valid grade level."
        case .invalidSchool:
            return "Please enter a valid school name (1-200 characters)."
        case .invalidAge:
            return "Please enter a valid date of birth for a student aged 3-120."
        case .invalidDateOfBirth:
            return "Please select a date of birth that is not in the future."
        case .invalidStudentID:
            return "Student ID should be 50 characters or less."
        case .tooManyInterests:
            return "Please limit interests to 20 or fewer."
        case .tooManyHobbies:
            return "Please limit hobbies to 20 or fewer."
        case .unknown:
            return "Please check your input and try again."
        }
    }
}

