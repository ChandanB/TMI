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
            let querySnapshot = try await collection.getDocuments()
            
            let students = querySnapshot.documents.compactMap { document -> Student? in
                let data = document.data()
                print("[StudentService] Document \(document.documentID) data: \(data)")
                
                // Extract required fields
                guard let name = data["name"] as? String,
                      let grade = data["grade"] as? String,
                      let dateOfBirthTimestamp = data["dateOfBirth"] as? Double else {
                    print("[StudentService] Missing required fields in document \(document.documentID)")
                    return nil
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
                    return Interest(id: id, name: name, category: [])
                }
                
                // Parse hobbies
                let hobbies = (data["hobbies"] as? [[String: Any]] ?? []).compactMap { hobbyData -> Hobby? in
                    guard let name = hobbyData["name"] as? String else { return nil }
                    return Hobby(name: name, category: [])
                }
                
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
                
                // Create student with all parsed data
                var student = Student(
                    id: document.documentID,
                    name: name,
                    grade: grade,
                    dateOfBirth: dateOfBirth,
                    studentID: studentID,
                    interests: interests,
                    hobbies: hobbies,
                    photoURL: photoURL,
                    surveyResults: surveyResults,
                    academicPerformance: academicPerformance,
                    engagementHistory: engagementHistory,
                    notes: notes,
                    lastInteractionDate: lastInteractionDate
                )
                
                return student
            }
            
            print("[StudentService] Successfully fetched \(students.count) students")
            return students
        } catch {
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
            let documentRef = try await collection.addDocument(data: data)
            
            print("[StudentService] Student added with ID: \(documentRef.documentID)")
            
            // Return the student with the generated ID
            var savedStudent = student
            savedStudent.id = documentRef.documentID
            
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
            try await collection.document(studentId).updateData(data)
            
            print("[StudentService] Student updated successfully")
            return student
        } catch {
            print("[StudentService] Error updating student: \(error)")
            throw StudentServiceError.updateFailed(error.localizedDescription)
        }
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
            try await collection.document(studentId).delete()
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
            let document = try await collection.document(id).getDocument()
            
            if document.exists {
                guard let data = document.data() else { return nil }
                
                // Use same parsing logic as fetchStudents
                guard let name = data["name"] as? String,
                      let grade = data["grade"] as? String,
                      let dateOfBirthTimestamp = data["dateOfBirth"] as? Double else {
                    print("[StudentService] Missing required fields in document \(document.documentID)")
                    return nil
                }
                
                let dateOfBirth = Date(timeIntervalSince1970: dateOfBirthTimestamp)
                let studentID = data["studentID"] as? String
                let photoURL = (data["photoURL"] as? String).flatMap { URL(string: $0) }
                let lastInteractionDate = (data["lastInteractionDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
                
                // Parse interests, hobbies, and other complex data using same logic as fetchStudents
                let interests = (data["interests"] as? [[String: Any]] ?? []).compactMap { interestData -> Interest? in
                    guard let name = interestData["name"] as? String else { return nil }
                    let id = interestData["id"] as? String
                    return Interest(id: id, name: name, category: [])
                }
                
                let hobbies = (data["hobbies"] as? [[String: Any]] ?? []).compactMap { hobbyData -> Hobby? in
                    guard let name = hobbyData["name"] as? String else { return nil }
                    return Hobby(name: name, category: [])
                }
                
                let student = Student(
                    id: document.documentID,
                    name: name,
                    grade: grade,
                    dateOfBirth: dateOfBirth,
                    studentID: studentID,
                    interests: interests,
                    hobbies: hobbies,
                    photoURL: photoURL,
                    lastInteractionDate: lastInteractionDate
                )
                
                return student
            } else {
                return nil
            }
        } catch {
            print("[StudentService] Error fetching student: \(error)")
            throw StudentServiceError.fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum StudentServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidStudentId
    case fetchFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidStudentId:
            return "Student ID is invalid or missing"
        case .fetchFailed(let message):
            return "Failed to fetch students: \(message)"
        case .saveFailed(let message):
            return "Failed to save student: \(message)"
        case .updateFailed(let message):
            return "Failed to update student: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete student: \(message)"
        }
    }
}