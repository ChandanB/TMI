//
//  StudentService.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing student data operations with Firestore
@Observable
class StudentService {
    private let db = Firestore.firestore()
    
    /// Get the user-scoped students collection
    private var userStudentsCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[StudentService] Error: User not logged in")
            return nil
        }
        return db.collection("users").document(uid).collection("students")
    }
    
    /// Fetch all students for the current user
    func fetchStudents() async throws -> [Student] {
        guard let collection = userStudentsCollection else {
            throw StudentServiceError.userNotAuthenticated
        }
        
        do {
            print("[StudentService] Fetching students...")
            let querySnapshot = try await withTimeout(seconds: 10) {
                try await collection.getDocuments()
            }
            
            let students: [Student] = try querySnapshot.documents.compactMap { document in
                do {
                    // Using a helper function to decode the document
                    return try parseStudent(from: document)
                } catch {
                    // If parsing fails for one document, we throw the specific error
                    throw StudentServiceError.dataParsingFailed(documentID: document.documentID, underlyingError: error)
                }
            }
            
            print("[StudentService] Successfully fetched \(students.count) students")
            return students
        } catch let error as StudentServiceError {
            // Re-throw our custom error
            throw error
        } catch {
            // Catch any other errors (e.g., network issues)
            print("[StudentService] Error fetching students: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Add a new student to Firestore
    func addStudent(_ student: Student) async throws -> Student {
        guard let collection = userStudentsCollection else {
            throw StudentServiceError.userNotAuthenticated
        }
        
        do {
            print("[StudentService] Adding student: \(student.name)")
            
            // Convert student to Firestore data (without ID)
            let data = student.toFirestoreData()
            
            // Add the document and get the reference
            let documentRef = try await withTimeout(seconds: 10) {
                try await collection.addDocument(data: data)
            }
            
            print("[StudentService] Student added with ID: \(documentRef.documentID)")
            
            // Re-fetch the document using our custom parser
            let document = try await withTimeout(seconds: 10) {
                try await documentRef.getDocument()
            }
            let savedStudent = try parseStudent(from: document)
            return savedStudent
        } catch {
            print("[StudentService] Error adding student: \(error)")
            throw StudentServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Update an existing student in Firestore
    func updateStudent(_ student: Student) async throws -> Student {
        guard let studentId = student.id else {
            throw StudentServiceError.invalidStudentId
        }

        guard let collection = userStudentsCollection else {
            throw StudentServiceError.userNotAuthenticated
        }

        do {
            print("[StudentService] Updating student: \(student.name)")

            let data = student.toFirestoreData()
            try await withTimeout(seconds: 10) {
                try await collection.document(studentId).updateData(data)
            }

            print("[StudentService] Student updated successfully")
            return student
        } catch {
            print("[StudentService] Error updating student: \(error)")
            throw StudentServiceError.updateFailed(error.localizedDescription)
        }
    }

    /// Add interests to a student with automatic deduplication
    /// Now uses StudentInterestService edge collection
    func addInterests(_ newInterests: [Interest], to student: Student) async throws -> Student {
        print("[StudentService] Adding \(newInterests.count) interests to student: \(student.name)")

        guard let studentId = student.id else {
            throw StudentServiceError.invalidStudentId
        }

        // Get existing interest edges from edge collection
        let existingEdges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
        let existingInterestIds = Set(existingEdges.map { $0.interestId })

        // Filter out duplicates by ID
        var duplicateCount = 0
        for interest in newInterests {
            guard let interestId = interest.id else {
                print("[StudentService] ⚠️ Skipping interest without ID: \(interest.name)")
                continue
            }

            // Skip if already exists
            if existingInterestIds.contains(interestId) {
                print("[StudentService] ⚠️ Skipping duplicate interest: \(interest.name)")
                duplicateCount += 1
                continue
            }

            // Add to edge collection
            try await StudentInterestService.shared.addInterest(
                studentId: studentId,
                interestId: interestId,
                level: 3,  // Default level
                source: .staff  // Added by staff
            )
        }

        print("[StudentService] ✅ Added \(newInterests.count - duplicateCount) unique interests (filtered \(duplicateCount) duplicates)")

        // Return the student unchanged (interests now managed via edge collection)
        return student
    }
    
    /// Delete a student from Firestore
    func deleteStudent(_ student: Student) async throws {
        guard let studentId = student.id else {
            throw StudentServiceError.invalidStudentId
        }
        
        guard let collection = userStudentsCollection else {
            throw StudentServiceError.userNotAuthenticated
        }
        
        do {
            print("[StudentService] Deleting student: \(student.name)")
            try await withTimeout(seconds: 10) {
                try await collection.document(studentId).delete()
            }
            print("[StudentService] Student deleted successfully")
        } catch {
            print("[StudentService] Error deleting student: \(error)")
            throw StudentServiceError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Get a specific student by ID
    func getStudent(by id: String) async throws -> Student? {
        guard let collection = userStudentsCollection else {
            throw StudentServiceError.userNotAuthenticated
        }

        do {
            print("[StudentService] Fetching student with ID: \(id)")
            let document = try await withTimeout(seconds: 10) {
                try await collection.document(id).getDocument()
            }

            guard document.exists else {
                return nil
            }

            return try parseStudent(from: document)

        } catch let error as StudentServiceError {
            throw error
        } catch {
            print("[StudentService] Error fetching student: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Listen to real-time updates for a specific student
    /// Returns a ListenerRegistration that should be removed when no longer needed
    func listenToStudent(id: String, onChange: @escaping (Result<Student, Error>) -> Void) -> ListenerRegistration? {
        guard let collection = userStudentsCollection else {
            onChange(.failure(StudentServiceError.userNotAuthenticated))
            return nil
        }

        print("[StudentService] Starting listener for student: \(id)")

        return collection.document(id).addSnapshotListener { snapshot, error in
            if let error {
                print("[StudentService] Listener error: \(error)")
                onChange(.failure(error))
                return
            }

            guard let snapshot, snapshot.exists else {
                print("[StudentService] Student document not found: \(id)")
                onChange(.failure(StudentServiceError.studentNotFound))
                return
            }

            do {
                let student = try self.parseStudent(from: snapshot)
                print("[StudentService] Student updated: \(student.name)")
                onChange(.success(student))
            } catch {
                print("[StudentService] Failed to parse student: \(error)")
                onChange(.failure(error))
            }
        }
    }

    // MARK: - Private Parsing Helper
    
    private func parseStudent(from document: QueryDocumentSnapshot) throws -> Student {
        let data = document.data()
        print("[StudentService] Parsing document \(document.documentID)...")
        
        // Extract required fields
        guard let name = data["name"] as? String,
              let grade = data["grade"] as? String,
              let dateOfBirthTimestamp = data["dateOfBirth"] as? Double else {
            // Using a specific error for missing fields
            throw NSError(domain: "StudentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing required fields"])
        }
        
        let dateOfBirth = Date(timeIntervalSince1970: dateOfBirthTimestamp)
        
        // Extract optional fields
        let studentID = data["studentID"] as? String
        let photoURL = (data["photoURL"] as? String).flatMap { URL(string: $0) }
        let lastInteractionDate = (data["lastInteractionDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
        
        // Parse interests
        let interests = (data["interests"] as? [[String: Any]] ?? []).compactMap { interestData -> Interest? in
            guard let name = interestData["name"] as? String else { return nil }
            let id = interestData["id"] as? String
            return Interest(id: id, name: name, category: [.academics])
        }
        
        // Note: Hobbies are now included in interests above
        
        // Parse survey results
        let surveyResults = (data["surveyResults"] as? [[String: Any]])?.compactMap { surveyData -> SurveyResult? in
            guard let id = surveyData["id"] as? String,
                  let surveyName = surveyData["surveyName"] as? String,
                  let dateTimestamp = surveyData["date"] as? Double,
                  let isComplete = surveyData["isComplete"] as? Bool else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            let responses = (surveyData["responses"] as? [[String: Any]] ?? []).compactMap { responseData -> SurveyResult.SurveyResponse? in
                guard let questionID = responseData["questionID"] as? String,
                      let question = responseData["question"] as? String,
                      let answer = responseData["answer"] as? String else { return nil }
                return SurveyResult.SurveyResponse(questionID: questionID, question: question, answer: answer)
            }
            
            return SurveyResult(id: id, surveyName: surveyName, date: date, isComplete: isComplete, responses: responses)
        }
        
        // Parse academic performance
        let academicPerformance: AcademicPerformance? = {
            guard let perfData = data["academicPerformance"] as? [String: Any] else { return nil }
            
            let gpa = perfData["gpa"] as? Double
            let subjects = (perfData["subjects"] as? [[String: Any]] ?? []).compactMap { subjectData -> SubjectPerformance? in
                guard let name = subjectData["name"] as? String,
                      let grade = subjectData["grade"] as? String,
                      let score = subjectData["score"] as? Double,
                      let interestAlignment = subjectData["interestAlignment"] as? Double else { return nil }
                return SubjectPerformance(name: name, grade: grade, score: score, interestAlignment: interestAlignment)
            }
            let strengths = perfData["strengths"] as? [String] ?? []
            let areasForImprovement = perfData["areasForImprovement"] as? [String] ?? []
            
            return AcademicPerformance(gpa: gpa, subjects: subjects, strengths: strengths, areasForImprovement: areasForImprovement)
        }()
        
        // Parse engagement history
        let engagementHistory = (data["engagementHistory"] as? [[String: Any]])?.compactMap { engagementData -> EngagementRecord? in
            guard let dateTimestamp = engagementData["date"] as? Double,
                  let score = engagementData["score"] as? Double,
                  let sourceRaw = engagementData["source"] as? String,
                  let source = EngagementRecord.EngagementSource(rawValue: sourceRaw) else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            let notes = engagementData["notes"] as? String
            
            return EngagementRecord(date: date, score: score, source: source, notes: notes)
        }
        
        // Parse notes
        let notes = (data["notes"] as? [[String: Any]])?.compactMap { noteData -> StudentNote? in
            guard let idString = noteData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let dateTimestamp = noteData["date"] as? Double,
                  let author = noteData["author"] as? String,
                  let content = noteData["content"] as? String,
                  let categoryRaw = noteData["category"] as? String,
                  let category = StudentNote.NoteCategory(rawValue: categoryRaw) else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            return StudentNote(id: id, date: date, author: author, content: content, category: category)
        }

        // Extract school from Firestore data
        let school = data["school"] as? String ?? ""

        // Phase 1: Extract district scoping and staff assignment fields
        let districtId = data["districtId"] as? String
        let schoolId = data["schoolId"] as? String
        let assignedCounselorId = data["assignedCounselorId"] as? String
        let primaryTeacherId = data["primaryTeacherId"] as? String
        let createdBy = data["createdBy"] as? String
        let createdAt = (data["createdAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        let updatedAt = (data["updatedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }

        // Create student with all parsed data
        return Student(
            id: document.documentID,
            name: name,
            grade: grade,
            school: school,
            dateOfBirth: dateOfBirth,
            districtId: districtId,
            schoolId: schoolId,
            assignedCounselorId: assignedCounselorId,
            primaryTeacherId: primaryTeacherId,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            studentID: studentID,
            photoURL: photoURL,
            surveyResults: surveyResults,
            academicPerformance: academicPerformance,
            engagementHistory: engagementHistory,
            notes: notes,
            lastInteractionDate: lastInteractionDate
        )
    }

    private func parseStudent(from document: DocumentSnapshot) throws -> Student {
        let data = document.data() ?? [:]
        print("[StudentService] Parsing document \(document.documentID)...")
        
        // Extract required fields
        guard let name = data["name"] as? String,
              let grade = data["grade"] as? String,
              let dateOfBirthTimestamp = data["dateOfBirth"] as? Double else {
            // Using a specific error for missing fields
            throw NSError(domain: "StudentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing required fields"])
        }
        
        let dateOfBirth = Date(timeIntervalSince1970: dateOfBirthTimestamp)
        
        // Extract optional fields
        let studentID = data["studentID"] as? String
        let photoURL = (data["photoURL"] as? String).flatMap { URL(string: $0) }
        let lastInteractionDate = (data["lastInteractionDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
        
        // Parse interests
        let interests = (data["interests"] as? [[String: Any]] ?? []).compactMap { interestData -> Interest? in
            guard let name = interestData["name"] as? String else { return nil }
            let id = interestData["id"] as? String
            return Interest(id: id, name: name, category: [.academics])
        }
        
        // Note: Hobbies are now included in interests above
        
        // Parse survey results
        let surveyResults = (data["surveyResults"] as? [[String: Any]])?.compactMap { surveyData -> SurveyResult? in
            guard let id = surveyData["id"] as? String,
                  let surveyName = surveyData["surveyName"] as? String,
                  let dateTimestamp = surveyData["date"] as? Double,
                  let isComplete = surveyData["isComplete"] as? Bool else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            let responses = (surveyData["responses"] as? [[String: Any]] ?? []).compactMap { responseData -> SurveyResult.SurveyResponse? in
                guard let questionID = responseData["questionID"] as? String,
                      let question = responseData["question"] as? String,
                      let answer = responseData["answer"] as? String else { return nil }
                return SurveyResult.SurveyResponse(questionID: questionID, question: question, answer: answer)
            }
            
            return SurveyResult(id: id, surveyName: surveyName, date: date, isComplete: isComplete, responses: responses)
        }
        
        // Parse academic performance
        let academicPerformance: AcademicPerformance? = {
            guard let perfData = data["academicPerformance"] as? [String: Any] else { return nil }
            
            let gpa = perfData["gpa"] as? Double
            let subjects = (perfData["subjects"] as? [[String: Any]] ?? []).compactMap { subjectData -> SubjectPerformance? in
                guard let name = subjectData["name"] as? String,
                      let grade = subjectData["grade"] as? String,
                      let score = subjectData["score"] as? Double,
                      let interestAlignment = subjectData["interestAlignment"] as? Double else { return nil }
                return SubjectPerformance(name: name, grade: grade, score: score, interestAlignment: interestAlignment)
            }
            let strengths = perfData["strengths"] as? [String] ?? []
            let areasForImprovement = perfData["areasForImprovement"] as? [String] ?? []
            
            return AcademicPerformance(gpa: gpa, subjects: subjects, strengths: strengths, areasForImprovement: areasForImprovement)
        }()
        
        // Parse engagement history
        let engagementHistory = (data["engagementHistory"] as? [[String: Any]])?.compactMap { engagementData -> EngagementRecord? in
            guard let dateTimestamp = engagementData["date"] as? Double,
                  let score = engagementData["score"] as? Double,
                  let sourceRaw = engagementData["source"] as? String,
                  let source = EngagementRecord.EngagementSource(rawValue: sourceRaw) else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            let notes = engagementData["notes"] as? String
            
            return EngagementRecord(date: date, score: score, source: source, notes: notes)
        }
        
        // Parse notes
        let notes = (data["notes"] as? [[String: Any]])?.compactMap { noteData -> StudentNote? in
            guard let idString = noteData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let dateTimestamp = noteData["date"] as? Double,
                  let author = noteData["author"] as? String,
                  let content = noteData["content"] as? String,
                  let categoryRaw = noteData["category"] as? String,
                  let category = StudentNote.NoteCategory(rawValue: categoryRaw) else { return nil }
            
            let date = Date(timeIntervalSince1970: dateTimestamp)
            return StudentNote(id: id, date: date, author: author, content: content, category: category)
        }
        
        // Extract school from Firestore data
        let school = data["school"] as? String ?? ""

        // Phase 1: Extract district scoping and staff assignment fields
        let districtId = data["districtId"] as? String
        let schoolId = data["schoolId"] as? String
        let assignedCounselorId = data["assignedCounselorId"] as? String
        let primaryTeacherId = data["primaryTeacherId"] as? String
        let createdBy = data["createdBy"] as? String
        let createdAt = (data["createdAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        let updatedAt = (data["updatedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }

        // Create student with all parsed data
        return Student(
            id: document.documentID,
            name: name,
            grade: grade,
            school: school,
            dateOfBirth: dateOfBirth,
            districtId: districtId,
            schoolId: schoolId,
            assignedCounselorId: assignedCounselorId,
            primaryTeacherId: primaryTeacherId,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            studentID: studentID,
            photoURL: photoURL,
            surveyResults: surveyResults,
            academicPerformance: academicPerformance,
            engagementHistory: engagementHistory,
            notes: notes,
            lastInteractionDate: lastInteractionDate
        )
    }

    // MARK: - Phase 1: District-Scoped Queries
    
    /// Fetch all students in a district (for cross-staff access)
    func fetchStudentsInDistrict(_ districtId: String) async throws -> [Student] {
        print("[StudentService] Fetching students for district: \(districtId)")
        
        // Query global students collection filtered by districtId
        let query = db.collection("students")
            .whereField("districtId", isEqualTo: districtId)
        
        do {
            let snapshot = try await withTimeout(seconds: 15) {
                try await query.getDocuments()
            }
            
            let students = try snapshot.documents.compactMap { document in
                try parseStudent(from: document)
            }
            
            print("[StudentService] Found \(students.count) students in district")
            return students
        } catch {
            print("[StudentService] Error fetching district students: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch students assigned to a specific counselor (caseload)
    func fetchStudentsForCounselor(_ counselorId: String) async throws -> [Student] {
        print("[StudentService] Fetching caseload for counselor: \(counselorId)")
        
        let query = db.collection("students")
            .whereField("assignedCounselorId", isEqualTo: counselorId)
        
        do {
            let snapshot = try await withTimeout(seconds: 15) {
                try await query.getDocuments()
            }
            
            let students = try snapshot.documents.compactMap { document in
                try parseStudent(from: document)
            }
            
            print("[StudentService] Found \(students.count) students in caseload")
            return students
        } catch {
            print("[StudentService] Error fetching counselor caseload: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch students assigned to a specific teacher
    func fetchStudentsForTeacher(_ teacherId: String) async throws -> [Student] {
        print("[StudentService] Fetching students for teacher: \(teacherId)")
        
        let query = db.collection("students")
            .whereField("primaryTeacherId", isEqualTo: teacherId)
        
        do {
            let snapshot = try await withTimeout(seconds: 15) {
                try await query.getDocuments()
            }
            
            let students = try snapshot.documents.compactMap { document in
                try parseStudent(from: document)
            }
            
            print("[StudentService] Found \(students.count) students for teacher")
            return students
        } catch {
            print("[StudentService] Error fetching teacher students: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Assign a counselor to a student
    func assignCounselor(_ counselorId: String, to studentId: String) async throws {
        print("[StudentService] Assigning counselor \(counselorId) to student \(studentId)")
        
        try await db.collection("students")
            .document(studentId)
            .updateData([
                "assignedCounselorId": counselorId,
                "updatedAt": Date().timeIntervalSince1970
            ])
        
        print("[StudentService] Counselor assigned successfully")
    }
    
    /// Assign a primary teacher to a student
    func assignPrimaryTeacher(_ teacherId: String, to studentId: String) async throws {
        print("[StudentService] Assigning teacher \(teacherId) to student \(studentId)")
        
        try await db.collection("students")
            .document(studentId)
            .updateData([
                "primaryTeacherId": teacherId,
                "updatedAt": Date().timeIntervalSince1970
            ])
        
        print("[StudentService] Teacher assigned successfully")
    }
}

// MARK: - Error Types

enum StudentServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidStudentId
    case studentNotFound
    case fetchFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case dataParsingFailed(documentID: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidStudentId:
            return "Student ID is invalid or missing"
        case .studentNotFound:
            return "Student not found"
        case .fetchFailed(let message):
            return "Failed to fetch students: \(message)"
        case .saveFailed(let message):
            return "Failed to save student: \(message)"
        case .updateFailed(let message):
            return "Failed to update student: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete student: \(message)"
        case .dataParsingFailed(let documentID, let underlyingError):
            return "Failed to parse data for document \(documentID): \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - Mock Service for Previews

class MockStudentService: StudentService {
    private var mockStudents: [Student] = Student.sampleStudents.map {
        // Adjust sampleStudents to have school: "" by creating new struct
        Student(
            id: $0.id,
            name: $0.name,
            grade: $0.grade,
            school: "",
            dateOfBirth: $0.dateOfBirth,
            studentID: $0.studentID,
            photoURL: $0.photoURL,
            surveyResults: $0.surveyResults,
            academicPerformance: $0.academicPerformance,
            engagementHistory: $0.engagementHistory,
            notes: $0.notes,
            lastInteractionDate: $0.lastInteractionDate
        )
    }
    
    override func fetchStudents() async throws -> [Student] {
        print("[MockStudentService] Fetching mock students...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        return mockStudents
    }
    
    override func addStudent(_ student: Student) async throws -> Student {
        print("[MockStudentService] Adding mock student: \(student.name)")
        let newStudent = Student(
            id: UUID().uuidString,
            name: student.name,
            grade: student.grade,
            school: "",
            dateOfBirth: student.dateOfBirth,
            studentID: student.studentID,
            photoURL: student.photoURL,
            surveyResults: student.surveyResults,
            academicPerformance: student.academicPerformance,
            engagementHistory: student.engagementHistory,
            notes: student.notes,
            lastInteractionDate: student.lastInteractionDate
        )
        mockStudents.append(newStudent)
        return newStudent
    }
    
    override func updateStudent(_ student: Student) async throws -> Student {
        print("[MockStudentService] Updating mock student: \(student.name)")
        if let index = mockStudents.firstIndex(where: { $0.id == student.id }) {
            let updatedStudent = Student(
                id: student.id,
                name: student.name,
                grade: student.grade,
                school: "",
                dateOfBirth: student.dateOfBirth,
                studentID: student.studentID,
                photoURL: student.photoURL,
                surveyResults: student.surveyResults,
                academicPerformance: student.academicPerformance,
                engagementHistory: student.engagementHistory,
                notes: student.notes,
                lastInteractionDate: student.lastInteractionDate
            )
            mockStudents[index] = updatedStudent
            return updatedStudent
        }
        return student
    }
    
    override func deleteStudent(_ student: Student) async throws {
        print("[MockStudentService] Deleting mock student: \(student.name)")
        mockStudents.removeAll { $0.id == student.id }
    }
    
    override func getStudent(by id: String) async throws -> Student? {
        print("[MockStudentService] Getting mock student by ID: \(id)")
        return mockStudents.first { $0.id == id }
    }
}

