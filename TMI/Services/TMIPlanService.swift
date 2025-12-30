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
    static let shared = TMIPlanService()

    private let db = Firestore.firestore()

    private init() {}

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
                        print("[TMIPlanService] Missing students data in document \(document.documentID)")
                        return nil
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
                    
                    // Note: Hobbies are now included in interests
                    
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

                    // Reconstruct resources
                    let resources: [Resource]
                    if let resourcesData = data["resources"] as? [[String: Any]] {
                        resources = resourcesData.compactMap { resourceData in
                            guard let title = resourceData["title"] as? String,
                                  let description = resourceData["description"] as? String,
                                  let categoryRaw = resourceData["category"] as? String,
                                  let category = Resource.ResourceCategory(rawValue: categoryRaw),
                                  let url = resourceData["url"] as? String,
                                  let createdAtTimestamp = resourceData["createdAt"] as? Double,
                                  let updatedAtTimestamp = resourceData["updatedAt"] as? Double else {
                                return nil
                            }
                            
                            let tags = resourceData["tags"] as? [String] ?? []
                            let recommendedFor = resourceData["recommendedFor"] as? [String] ?? []
                            let isFeatured = resourceData["isFeatured"] as? Bool ?? false
                            let thumbnail = resourceData["thumbnail"] as? String
                            let scopeRaw = resourceData["scope"] as? String
                            let scope = scopeRaw.flatMap { Resource.ResourceScope(rawValue: $0) }
                            let districtId = resourceData["districtId"] as? String
                            let ownerUid = resourceData["ownerUid"] as? String

                            return Resource(
                                id: resourceData["id"] as? String,
                                title: title,
                                description: description,
                                category: category,
                                url: url,
                                createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
                                updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
                                tags: tags,
                                recommendedFor: recommendedFor,
                                isFeatured: isFeatured,
                                thumbnail: thumbnail,
                                scope: scope,
                                districtId: districtId,
                                ownerUid: ownerUid
                            )
                        }
                    } else {
                        resources = []
                    }
                    
                    let title = data["title"] as? String ?? ""
                    let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                    let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                    let createdBy = data["createdBy"] as? String ?? ""
                    let plan = TMIPlan(
                        id: document.documentID,
                        title: title,
                        description: data["description"] as? String,
                        students: students,
                        model: model,
                        interests: interests,
                                startDate: startDate,
                        endDate: endDate,
                        creationDate: creationDate,
                        lastUpdated: lastUpdated,
                        goals: goals,
                        progress: progress,
                        notes: notes,
                        strategies: data["strategies"] as? [String],
                        progressTracking: nil,
                        createdBy: createdBy,
                        resources: resources
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

    /// Fetch a single TMI plan by ID
    func fetchPlan(byId planId: String) async throws -> TMIPlan? {
        guard let collection = userPlansCollection else {
            print("[TMIPlanService] Error: No user logged in, cannot fetch plan")
            throw TMIPlanServiceError.userNotAuthenticated
        }

        do {
            print("[TMIPlanService] Fetching TMI plan with ID: \(planId)")
            let document = try await collection.document(planId).getDocument()

            guard document.exists, let data = document.data() else {
                print("[TMIPlanService] Plan not found with ID: \(planId)")
                return nil
            }

            // Use same reconstruction logic as fetchPlans
            guard let modelRaw = data["model"] as? String,
                  let model = TMIPlanModel(rawValue: modelRaw),
                  let progress = data["progress"] as? Double,
                  let notes = data["notes"] as? String,
                  let creationTimestamp = data["creationDate"] as? Double,
                  let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
                print("[TMIPlanService] Missing required fields in plan document")
                return nil
            }

            let creationDate = Date(timeIntervalSince1970: creationTimestamp)
            let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)

            // Reconstruct students
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
                students = []
            }

            // Reconstruct interests
            let interests: [Interest]
            if let interestsData = data["interests"] as? [[String: Any]] {
                interests = interestsData.compactMap { interestData in
                    Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                }
            } else {
                interests = []
            }

            // Reconstruct goals
            let goals: [Goal]
            if let goalsData = data["goals"] as? [[String: Any]] {
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

            // Reconstruct resources
            let resources: [Resource]
            if let resourcesData = data["resources"] as? [[String: Any]] {
                resources = resourcesData.compactMap { resourceData in
                    guard let title = resourceData["title"] as? String,
                          let description = resourceData["description"] as? String,
                          let categoryRaw = resourceData["category"] as? String,
                          let category = Resource.ResourceCategory(rawValue: categoryRaw),
                          let url = resourceData["url"] as? String,
                          let createdAtTimestamp = resourceData["createdAt"] as? Double,
                          let updatedAtTimestamp = resourceData["updatedAt"] as? Double else {
                        return nil
                    }
                    
                    let tags = resourceData["tags"] as? [String] ?? []
                    let recommendedFor = resourceData["recommendedFor"] as? [String] ?? []
                    let isFeatured = resourceData["isFeatured"] as? Bool ?? false
                    let thumbnail = resourceData["thumbnail"] as? String
                    let scopeRaw = resourceData["scope"] as? String
                    let scope = scopeRaw.flatMap { Resource.ResourceScope(rawValue: $0) }
                    let districtId = resourceData["districtId"] as? String
                    let ownerUid = resourceData["ownerUid"] as? String

                    return Resource(
                        id: resourceData["id"] as? String,
                        title: title,
                        description: description,
                        category: category,
                        url: url,
                        createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
                        updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
                        tags: tags,
                        recommendedFor: recommendedFor,
                        isFeatured: isFeatured,
                        thumbnail: thumbnail,
                        scope: scope,
                        districtId: districtId,
                        ownerUid: ownerUid
                    )
                }
            } else {
                resources = []
            }

            let title = data["title"] as? String ?? ""
            let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
            let createdBy = data["createdBy"] as? String ?? ""

            let plan = TMIPlan(
                id: planId,
                title: title,
                description: data["description"] as? String,
                students: students,
                model: model,
                interests: interests,
                startDate: startDate,
                endDate: endDate,
                creationDate: creationDate,
                lastUpdated: lastUpdated,
                goals: goals,
                progress: progress,
                notes: notes,
                strategies: data["strategies"] as? [String],
                progressTracking: nil,
                createdBy: createdBy,
                resources: resources
            )

            print("[TMIPlanService] Successfully fetched plan: \(plan.model.rawValue)")
            return plan
        } catch {
            print("[TMIPlanService] Error fetching plan: \(error)")
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
                  let lastUpdatedTimestamp = docData["lastUpdated"] as? Double else {
                throw TMIPlanServiceError.saveFailed("Invalid document structure")
            }
            
            let creationDate = Date(timeIntervalSince1970: creationTimestamp)
            let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
            
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
                students = [] // No students if the data is missing
            }
            
            let interests: [Interest]
            if let interestsData = docData["interests"] as? [[String: Any]] {
                interests = interestsData.compactMap { interestData in
                    Interest.fromFirestore(id: interestData["id"] as? String ?? "", data: interestData)
                }
            } else {
                interests = []
            }
            
            // Note: Hobbies are now included in interests
            
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

            // Reconstruct resources
            let resources: [Resource]
            if let resourcesData = docData["resources"] as? [[String: Any]] {
                resources = resourcesData.compactMap { resourceData in
                    guard let title = resourceData["title"] as? String,
                          let description = resourceData["description"] as? String,
                          let categoryRaw = resourceData["category"] as? String,
                          let category = Resource.ResourceCategory(rawValue: categoryRaw),
                          let url = resourceData["url"] as? String,
                          let createdAtTimestamp = resourceData["createdAt"] as? Double,
                          let updatedAtTimestamp = resourceData["updatedAt"] as? Double else {
                        return nil
                    }
                    
                    let tags = resourceData["tags"] as? [String] ?? []
                    let recommendedFor = resourceData["recommendedFor"] as? [String] ?? []
                    let isFeatured = resourceData["isFeatured"] as? Bool ?? false
                    let thumbnail = resourceData["thumbnail"] as? String
                    let scopeRaw = resourceData["scope"] as? String
                    let scope = scopeRaw.flatMap { Resource.ResourceScope(rawValue: $0) }
                    let districtId = resourceData["districtId"] as? String
                    let ownerUid = resourceData["ownerUid"] as? String

                    return Resource(
                        id: resourceData["id"] as? String,
                        title: title,
                        description: description,
                        category: category,
                        url: url,
                        createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
                        updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
                        tags: tags,
                        recommendedFor: recommendedFor,
                        isFeatured: isFeatured,
                        thumbnail: thumbnail,
                        scope: scope,
                        districtId: districtId,
                        ownerUid: ownerUid
                    )
                }
            } else {
                resources = []
            }
            
            let title = docData["title"] as? String ?? ""
            let startDate = (docData["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let endDate = (docData["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
            let createdBy = docData["createdBy"] as? String ?? ""
            
            let savedPlan = TMIPlan(
                id: document.documentID,
                title: title,
                description: docData["description"] as? String,
                students: students,
                model: model,
                interests: interests,
                startDate: startDate,
                endDate: endDate,
                creationDate: creationDate,
                lastUpdated: lastUpdated,
                goals: goals,
                progress: progress,
                notes: notes,
                strategies: docData["strategies"] as? [String],
                progressTracking: nil,
                createdBy: createdBy,
                resources: resources
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
                
                // Note: Hobbies are now included in interests
                
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

                // Reconstruct resources
                let resources: [Resource]
                if let resourcesData = data["resources"] as? [[String: Any]] {
                    resources = resourcesData.compactMap { resourceData in
                        guard let title = resourceData["title"] as? String,
                              let description = resourceData["description"] as? String,
                              let categoryRaw = resourceData["category"] as? String,
                              let category = Resource.ResourceCategory(rawValue: categoryRaw),
                              let url = resourceData["url"] as? String,
                              let createdAtTimestamp = resourceData["createdAt"] as? Double,
                              let updatedAtTimestamp = resourceData["updatedAt"] as? Double else {
                            return nil
                        }
                        
                        let tags = resourceData["tags"] as? [String] ?? []
                        let recommendedFor = resourceData["recommendedFor"] as? [String] ?? []
                        let isFeatured = resourceData["isFeatured"] as? Bool ?? false
                        let thumbnail = resourceData["thumbnail"] as? String
                        let scopeRaw = resourceData["scope"] as? String
                        let scope = scopeRaw.flatMap { Resource.ResourceScope(rawValue: $0) }
                        let districtId = resourceData["districtId"] as? String
                        let ownerUid = resourceData["ownerUid"] as? String

                        return Resource(
                            id: resourceData["id"] as? String,
                            title: title,
                            description: description,
                            category: category,
                            url: url,
                            createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
                            updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
                            tags: tags,
                            recommendedFor: recommendedFor,
                            isFeatured: isFeatured,
                            thumbnail: thumbnail,
                            scope: scope,
                            districtId: districtId,
                            ownerUid: ownerUid
                        )
                    }
                } else {
                    resources = []
                }
                
                let title = data["title"] as? String ?? ""
                let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                let createdBy = data["createdBy"] as? String ?? ""
                return TMIPlan(
                    id: document.documentID,
                    title: title,
                    description: data["description"] as? String,
                    students: students,
                    model: model,
                    interests: interests,
                        startDate: startDate,
                    endDate: endDate,
                    creationDate: creationDate,
                    lastUpdated: lastUpdated,
                    goals: goals,
                    progress: progress,
                    notes: notes,
                    strategies: data["strategies"] as? [String],
                    progressTracking: nil,
                    createdBy: createdBy,
                    resources: resources
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
                .whereField("students", arrayContains: ["id": studentId])
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
                        print("[TMIPlanService] Missing students data in document \(document.documentID)")
                        return nil
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
                    
                    // Note: Hobbies are now included in interests
                    
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

                    // Reconstruct resources
                    let resources: [Resource]
                    if let resourcesData = data["resources"] as? [[String: Any]] {
                        resources = resourcesData.compactMap { resourceData in
                            guard let title = resourceData["title"] as? String,
                                  let description = resourceData["description"] as? String,
                                  let categoryRaw = resourceData["category"] as? String,
                                  let category = Resource.ResourceCategory(rawValue: categoryRaw),
                                  let url = resourceData["url"] as? String,
                                  let createdAtTimestamp = resourceData["createdAt"] as? Double,
                                  let updatedAtTimestamp = resourceData["updatedAt"] as? Double else {
                                return nil
                            }
                            
                            let tags = resourceData["tags"] as? [String] ?? []
                            let recommendedFor = resourceData["recommendedFor"] as? [String] ?? []
                            let isFeatured = resourceData["isFeatured"] as? Bool ?? false
                            let thumbnail = resourceData["thumbnail"] as? String
                            let scopeRaw = resourceData["scope"] as? String
                            let scope = scopeRaw.flatMap { Resource.ResourceScope(rawValue: $0) }
                            let districtId = resourceData["districtId"] as? String
                            let ownerUid = resourceData["ownerUid"] as? String

                            return Resource(
                                id: resourceData["id"] as? String,
                                title: title,
                                description: description,
                                category: category,
                                url: url,
                                createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
                                updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
                                tags: tags,
                                recommendedFor: recommendedFor,
                                isFeatured: isFeatured,
                                thumbnail: thumbnail,
                                scope: scope,
                                districtId: districtId,
                                ownerUid: ownerUid
                            )
                        }
                    } else {
                        resources = []
                    }
                    
                    let title = data["title"] as? String ?? ""
                    let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                    let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                    let createdBy = data["createdBy"] as? String ?? ""
                    let plan = TMIPlan(
                        id: document.documentID,
                        title: title,
                        description: data["description"] as? String,
                        students: students,
                        model: model,
                        interests: interests,
                                startDate: startDate,
                        endDate: endDate,
                        creationDate: creationDate,
                        lastUpdated: lastUpdated,
                        goals: goals,
                        progress: progress,
                        notes: notes,
                        strategies: data["strategies"] as? [String],
                        progressTracking: nil,
                        createdBy: createdBy,
                        resources: resources
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

    /// Update plan with survey snapshot data
    func updateSurveySnapshot(planId: String, surveyId: String, interestIds: [String]) async throws {
        guard let collection = userPlansCollection else {
            print("[TMIPlanService] Error: No user logged in, cannot update plan snapshot")
            throw TMIPlanServiceError.userNotAuthenticated
        }

        let updates: [String: Any] = [
            "latestInterestSurveyId": surveyId,
            "interestIdsSnapshot": interestIds,
            "snapshotUpdatedAt": Timestamp(date: Date()),
            "lastUpdated": Timestamp(date: Date())
        ]

        do {
            try await collection.document(planId).updateData(updates)
            print("[TMIPlanService] Updated plan \(planId) with survey snapshot")
        } catch {
            print("[TMIPlanService] Error updating plan snapshot: \(error)")
            throw TMIPlanServiceError.updateFailed(error.localizedDescription)
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

