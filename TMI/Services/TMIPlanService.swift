//
//  TMIPlanService.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing TMI Plan data operations with Firestore
@Observable
class TMIPlanService {
    private let db = Firestore.firestore()
    
    /// Get the user-scoped TMI plans collection
    private var userPlansCollection: CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[TMIPlanService] Error: User not logged in")
            return nil
        }
        return db.collection("users").document(uid).collection("tmiPlans")
    }
    
    /// Fetch all TMI plans for the current user
    func fetchPlans() async throws -> [TMIPlan] {
        guard let collection = userPlansCollection else {
            print("[TMIPlanService] Error: No user logged in, cannot fetch plans")
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plans for user: \(Auth.auth().currentUser?.uid ?? "unknown")")
            let querySnapshot = try await collection.getDocuments()
            print("[TMIPlanService] Found \(querySnapshot.documents.count) documents in collection")
            
            let plans = querySnapshot.documents.compactMap { document -> TMIPlan? in
                print("[TMIPlanService] Processing document: \(document.documentID)")
                let data = document.data()
                
                // Manual reconstruction of TMIPlan from Firestore data
                guard let modelRaw = data["model"] as? String,
                          let model = TMIPlanModel(rawValue: modelRaw),
                          let progress = data["progress"] as? Double,
                          let notes = data["notes"] as? String,
                          let creationTimestamp = data["creationDate"] as? Double,
                          let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
                        print("[TMIPlanService] Missing required fields in document \(document.documentID)")
                        return nil
                    }
                    
                    let creationDate = Date(timeIntervalSince1970: creationTimestamp)
                    let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
                    
                    // Reconstruct student from simplified data
                    let student: Student
                    if let studentData = data["student"] as? [String: Any] {
                        student = Student(
                            id: studentData["id"] as? String,
                            name: studentData["name"] as? String ?? "Unknown",
                            grade: studentData["grade"] as? String ?? "",
                            school: "",
                            dateOfBirth: Date()
                        )
                    } else {
                        print("[TMIPlanService] Missing student data in document \(document.documentID)")
                        return nil
                    }
                    
                    // Reconstruct students array from simplified data
                    let students: [Student]
                    if let studentsData = data["students"] as? [[String: Any]] {
                        students = studentsData.map { studentInfo in
                            Student(
                                id: studentInfo["id"] as? String,
                                name: studentInfo["name"] as? String ?? "Unknown",
                                grade: studentInfo["grade"] as? String ?? "",
                                school: "",
                                dateOfBirth: Date()
                            )
                        }
                    } else {
                        students = [student] // Fallback to main student
                    }
                    
                    // Reconstruct interests from full objects
                    let interests: [Interest]
                    if let interestsData = data["interests"] as? [[String: Any]] {
                        interests = interestsData.compactMap { interestData in
                            Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                        }
                    } else {
                        interests = []
                    }
                    
                    // Reconstruct hobbies from full objects
                    let hobbies: [Hobby]
                    if let hobbiesData = data["hobbies"] as? [[String: Any]] {
                        hobbies = hobbiesData.compactMap { hobbyData in
                            guard let idString = hobbyData["id"] as? String else { return nil }
                            return Hobby.fromFirestore(id: idString, data: hobbyData)
                        }
                    } else {
                        hobbies = []
                    }
                    
                    // Reconstruct goals from array data
                    let goals: [Goal]
                    if let goalsData = data["goals"] as? [[String: Any]] {
                        goals = goalsData.compactMap { goalData in
                            guard let idString = goalData["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let description = goalData["description"] as? String,
                                  let statusString = goalData["status"] as? String,
                                  let status = GoalStatus(rawValue: statusString),
                                  let progress = goalData["progress"] as? Double else {
                                return nil
                            }
                            
                            let notes = goalData["notes"] as? String
                            let dueDate: Date?
                            if let dueDateTimestamp = goalData["dueDate"] as? Double {
                                dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
                            } else {
                                dueDate = nil
                            }
                            
                            return Goal(
                                id: id,
                                description: description,
                                dueDate: dueDate, status: status,
                                progress: progress,
                                notes: notes
                            )
                        }
                    } else {
                        goals = []
                    }
                    
                    let title = data["title"] as? String ?? ""
                    let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                    let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                    let createdBy = data["createdBy"] as? String ?? ""
                    let plan = TMIPlan(
                        id: document.documentID,
                        title: title,
                        description: data["description"] as? String,
                        student: student,
                        students: students,
                        model: model,
                        interests: interests,
                        hobbies: hobbies,
                        startDate: startDate,
                        endDate: endDate,
                        creationDate: creationDate,
                        lastUpdated: lastUpdated,
                        goals: goals,
                        progress: progress,
                        notes: notes,
                        strategies: data["strategies"] as? [String],
                        progressTracking: nil,
                        createdBy: createdBy
                    )
                    
                    print("[TMIPlanService] Successfully reconstructed plan: \(plan.model.rawValue)")
                    return plan
            }
            
            print("[TMIPlanService] Successfully fetched \(plans.count) TMI plans")
            return plans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Add a new TMI plan to Firestore
    func addPlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Adding TMI plan: \(plan.model.rawValue)")
            
            // Convert plan to Firestore data (without ID)
            let data = plan.toFirestoreData()
            
            // Add the document and get the reference
            let documentRef = try await collection.addDocument(data: data)
            
            print("[TMIPlanService] TMI plan added with ID: \(documentRef.documentID)")
            
            // Re-fetch the document using manual parsing to avoid Codable issues
            let document = try await documentRef.getDocument()
            guard document.exists, let docData = document.data() else {
                throw TMIPlanServiceError.saveFailed("Document was not created successfully")
            }
            
            // Use the same manual reconstruction logic as in fetchPlans
            guard let modelRaw = docData["model"] as? String,
                  let model = TMIPlanModel(rawValue: modelRaw),
                  let progress = docData["progress"] as? Double,
                  let notes = docData["notes"] as? String,
                  let creationTimestamp = docData["creationDate"] as? Double,
                  let lastUpdatedTimestamp = docData["lastUpdated"] as? Double,
                  let studentData = docData["student"] as? [String: Any] else {
                throw TMIPlanServiceError.saveFailed("Invalid document structure")
            }
            
            let creationDate = Date(timeIntervalSince1970: creationTimestamp)
            let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
            
            let student = Student(
                id: studentData["id"] as? String,
                name: studentData["name"] as? String ?? "Unknown",
                grade: studentData["grade"] as? String ?? "",
                school: "",
                dateOfBirth: Date()
            )
            
            let students: [Student]
            if let studentsData = docData["students"] as? [[String: Any]] {
                students = studentsData.map { studentInfo in
                    Student(
                        id: studentInfo["id"] as? String,
                        name: studentInfo["name"] as? String ?? "Unknown",
                        grade: studentInfo["grade"] as? String ?? "",
                        school: "",
                        dateOfBirth: Date()
                    )
                }
            } else {
                students = [student]
            }
            
            let interests: [Interest]
            if let interestsData = docData["interests"] as? [[String: Any]] {
                interests = interestsData.compactMap { interestData in
                    Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                }
            } else {
                interests = []
            }
            
            let hobbies: [Hobby]
            if let hobbiesData = docData["hobbies"] as? [[String: Any]] {
                hobbies = hobbiesData.compactMap { hobbyData in
                    guard let idString = hobbyData["id"] as? String else { return nil }
                    return Hobby.fromFirestore(id: idString, data: hobbyData)
                }
            } else {
                hobbies = []
            }
            
            let goals: [Goal]
            if let goalsData = docData["goals"] as? [[String: Any]] {
                goals = goalsData.compactMap { goalData in
                    guard let idString = goalData["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let description = goalData["description"] as? String,
                          let statusString = goalData["status"] as? String,
                          let status = GoalStatus(rawValue: statusString),
                          let goalProgress = goalData["progress"] as? Double else {
                        return nil
                    }
                    
                    let goalNotes = goalData["notes"] as? String
                    let dueDate: Date?
                    if let dueDateTimestamp = goalData["dueDate"] as? Double {
                        dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
                    } else {
                        dueDate = nil
                    }
                    
                    return Goal(
                        id: id,
                        description: description,
                        dueDate: dueDate,
                        status: status,
                        progress: goalProgress,
                        notes: goalNotes
                    )
                }
            } else {
                goals = []
            }
            
            let title = docData["title"] as? String ?? ""
            let startDate = (docData["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let endDate = (docData["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
            let createdBy = docData["createdBy"] as? String ?? ""
            
            let savedPlan = TMIPlan(
                id: document.documentID,
                title: title,
                description: docData["description"] as? String,
                student: student,
                students: students,
                model: model,
                interests: interests,
                hobbies: hobbies,
                startDate: startDate,
                endDate: endDate,
                creationDate: creationDate,
                lastUpdated: lastUpdated,
                goals: goals,
                progress: progress,
                notes: notes,
                strategies: docData["strategies"] as? [String],
                progressTracking: nil,
                createdBy: createdBy
            )
            
            return savedPlan
        } catch {
            print("[TMIPlanService] Error adding TMI plan: \(error)")
            throw TMIPlanServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Update an existing TMI plan in Firestore
    func updatePlan(_ plan: TMIPlan) async throws -> TMIPlan {
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }
        
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Updating TMI plan: \(plan.model.rawValue)")
            
            var updatedPlan = plan
            updatedPlan.lastUpdated = Date() // Update the lastUpdated timestamp
            
            let data = updatedPlan.toFirestoreData()
            try await collection.document(planId).updateData(data)
            
            print("[TMIPlanService] TMI plan updated successfully")
            return updatedPlan
        } catch {
            print("[TMIPlanService] Error updating TMI plan: \(error)")
            throw TMIPlanServiceError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Delete a TMI plan from Firestore
    func deletePlan(_ plan: TMIPlan) async throws {
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }
        
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Deleting TMI plan: \(plan.model.rawValue)")
            try await collection.document(planId).delete()
            print("[TMIPlanService] TMI plan deleted successfully")
        } catch {
            print("[TMIPlanService] Error deleting TMI plan: \(error)")
            throw TMIPlanServiceError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Get a specific TMI plan by ID
    func getPlan(by id: String) async throws -> TMIPlan? {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plan with ID: \(id)")
            let document = try await collection.document(id).getDocument()
            
            if document.exists {
                // Use the same manual reconstruction logic
                let data = document.data()!
                
                guard let modelRaw = data["model"] as? String,
                      let model = TMIPlanModel(rawValue: modelRaw),
                      let progress = data["progress"] as? Double,
                      let notes = data["notes"] as? String,
                      let creationTimestamp = data["creationDate"] as? Double,
                      let lastUpdatedTimestamp = data["lastUpdated"] as? Double,
                      let studentData = data["student"] as? [String: Any] else {
                    return nil
                }
                
                let creationDate = Date(timeIntervalSince1970: creationTimestamp)
                let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
                
                let student = Student(
                    id: studentData["id"] as? String,
                    name: studentData["name"] as? String ?? "Unknown",
                    grade: studentData["grade"] as? String ?? "",
                    school: "",
                    dateOfBirth: Date()
                )
                
                let students: [Student]
                if let studentsData = data["students"] as? [[String: Any]] {
                    students = studentsData.map { studentInfo in
                        Student(
                            id: studentInfo["id"] as? String,
                            name: studentInfo["name"] as? String ?? "Unknown",
                            grade: studentInfo["grade"] as? String ?? "",
                            school: "",
                            dateOfBirth: Date()
                        )
                    }
                } else {
                    students = [student]
                }
                
                let interests: [Interest]
                if let interestsData = data["interests"] as? [[String: Any]] {
                    interests = interestsData.compactMap { interestData in
                        Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                    }
                } else {
                    interests = []
                }
                
                let hobbies: [Hobby]
                if let hobbiesData = data["hobbies"] as? [[String: Any]] {
                    hobbies = hobbiesData.compactMap { hobbyData in
                        guard let idString = hobbyData["id"] as? String else { return nil }
                        return Hobby.fromFirestore(id: idString, data: hobbyData)
                    }
                } else {
                    hobbies = []
                }
                
                let goals: [Goal]
                if let goalsData = data["goals"] as? [[String: Any]] {
                    goals = goalsData.compactMap { goalData in
                        guard let idString = goalData["id"] as? String,
                              let id = UUID(uuidString: idString),
                              let description = goalData["description"] as? String,
                              let statusString = goalData["status"] as? String,
                              let status = GoalStatus(rawValue: statusString),
                              let progress = goalData["progress"] as? Double else {
                            return nil
                        }
                        
                        let notes = goalData["notes"] as? String
                        let dueDate: Date?
                        if let dueDateTimestamp = goalData["dueDate"] as? Double {
                            dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
                        } else {
                            dueDate = nil
                        }
                        
                        return Goal(
                            id: id,
                            description: description,
                            dueDate: dueDate, status: status,
                            progress: progress,
                            notes: notes
                        )
                    }
                } else {
                    goals = []
                }
                
                let title = data["title"] as? String ?? ""
                let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                let createdBy = data["createdBy"] as? String ?? ""
                return TMIPlan(
                    id: document.documentID,
                    title: title,
                    description: data["description"] as? String,
                    student: student,
                    students: students,
                    model: model,
                    interests: interests,
                    hobbies: hobbies,
                    startDate: startDate,
                    endDate: endDate,
                    creationDate: creationDate,
                    lastUpdated: lastUpdated,
                    goals: goals,
                    progress: progress,
                    notes: notes,
                    strategies: data["strategies"] as? [String],
                    progressTracking: nil,
                    createdBy: createdBy
                )
            } else {
                return nil
            }
        } catch {
            print("[TMIPlanService] Error fetching TMI plan: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Get plans for a specific student
    func getPlansForStudent(_ studentId: String) async throws -> [TMIPlan] {
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        
        do {
            print("[TMIPlanService] Fetching TMI plans for student: \(studentId)")
            let querySnapshot = try await collection
                .whereField("student.id", isEqualTo: studentId)
                .getDocuments()
            
            let plans = querySnapshot.documents.compactMap { document -> TMIPlan? in
                print("[TMIPlanService] Processing document: \(document.documentID)")
                let data = document.data()
                
                // Manual reconstruction of TMIPlan from Firestore data
                guard let modelRaw = data["model"] as? String,
                          let model = TMIPlanModel(rawValue: modelRaw),
                          let progress = data["progress"] as? Double,
                          let notes = data["notes"] as? String,
                          let creationTimestamp = data["creationDate"] as? Double,
                          let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
                        print("[TMIPlanService] Missing required fields in document \(document.documentID)")
                        return nil
                    }
                    
                    let creationDate = Date(timeIntervalSince1970: creationTimestamp)
                    let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
                    
                    // Reconstruct student from simplified data
                    let student: Student
                    if let studentData = data["student"] as? [String: Any] {
                        student = Student(
                            id: studentData["id"] as? String,
                            name: studentData["name"] as? String ?? "Unknown",
                            grade: studentData["grade"] as? String ?? "",
                            school: "",
                            dateOfBirth: Date()
                        )
                    } else {
                        print("[TMIPlanService] Missing student data in document \(document.documentID)")
                        return nil
                    }
                    
                    // Reconstruct students array from simplified data
                    let students: [Student]
                    if let studentsData = data["students"] as? [[String: Any]] {
                        students = studentsData.map { studentInfo in
                            Student(
                                id: studentInfo["id"] as? String,
                                name: studentInfo["name"] as? String ?? "Unknown",
                                grade: studentInfo["grade"] as? String ?? "",
                                school: "",
                                dateOfBirth: Date()
                            )
                        }
                    } else {
                        students = [student] // Fallback to main student
                    }
                    
                    // Reconstruct interests from full objects
                    let interests: [Interest]
                    if let interestsData = data["interests"] as? [[String: Any]] {
                        interests = interestsData.compactMap { interestData in
                            Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                        }
                    } else {
                        interests = []
                    }
                    
                    // Reconstruct hobbies from full objects
                    let hobbies: [Hobby]
                    if let hobbiesData = data["hobbies"] as? [[String: Any]] {
                        hobbies = hobbiesData.compactMap { hobbyData in
                            guard let idString = hobbyData["id"] as? String else { return nil }
                            return Hobby.fromFirestore(id: idString, data: hobbyData)
                        }
                    } else {
                        hobbies = []
                    }
                    
                    // Reconstruct goals from array data
                    let goals: [Goal]
                    if let goalsData = data["goals"] as? [[String: Any]] {
                        goals = goalsData.compactMap { goalData in
                            guard let idString = goalData["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let description = goalData["description"] as? String,
                                  let statusString = goalData["status"] as? String,
                                  let status = GoalStatus(rawValue: statusString),
                                  let progress = goalData["progress"] as? Double else {
                                return nil
                            }
                            
                            let notes = goalData["notes"] as? String
                            let dueDate: Date?
                            if let dueDateTimestamp = goalData["dueDate"] as? Double {
                                dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
                            } else {
                                dueDate = nil
                            }
                            
                            return Goal(
                                id: id,
                                description: description,
                                dueDate: dueDate, status: status,
                                progress: progress,
                                notes: notes
                            )
                        }
                    } else {
                        goals = []
                    }
                    
                    let title = data["title"] as? String ?? ""
                    let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                    let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                    let createdBy = data["createdBy"] as? String ?? ""
                    let plan = TMIPlan(
                        id: document.documentID,
                        title: title,
                        description: data["description"] as? String,
                        student: student,
                        students: students,
                        model: model,
                        interests: interests,
                        hobbies: hobbies,
                        startDate: startDate,
                        endDate: endDate,
                        creationDate: creationDate,
                        lastUpdated: lastUpdated,
                        goals: goals,
                        progress: progress,
                        notes: notes,
                        strategies: data["strategies"] as? [String],
                        progressTracking: nil,
                        createdBy: createdBy
                    )
                    
                    print("[TMIPlanService] Successfully reconstructed plan: \(plan.model.rawValue)")
                    return plan
            }
            
            print("[TMIPlanService] Successfully fetched \(plans.count) TMI plans for student")
            return plans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans for student: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum TMIPlanServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidPlanId
    case fetchFailed(String)
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidPlanId:
            return "TMI Plan ID is invalid or missing"
        case .fetchFailed(let message):
            return "Failed to fetch TMI plans: \(message)"
        case .saveFailed(let message):
            return "Failed to save TMI plan: \(message)"
        case .updateFailed(let message):
            return "Failed to update TMI plan: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete TMI plan: \(message)"
        }
    }
}

