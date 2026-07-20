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
    private let authorizationSessions: any AuthorizationSessionProviding
    private let authorization = RBACService()

    init(
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared
    ) {
        self.authorizationSessions = authorizationSessions
    }

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
        let session = try authorizedSession()
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
                    let latestInterestSurveyId = data["latestInterestSurveyId"] as? String
                    let interestIdsSnapshot = data["interestIdsSnapshot"] as? [String]
                    let snapshotUpdatedAt = (data["snapshotUpdatedAt"] as? Double).map(Date.init(timeIntervalSince1970:))
                    
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
                        resources: resources,
                        latestInterestSurveyId: latestInterestSurveyId,
                        interestIdsSnapshot: interestIdsSnapshot,
                        snapshotUpdatedAt: snapshotUpdatedAt
                    )
                    
                    print("[TMIPlanService] Successfully reconstructed plan: \(plan.model.rawValue)")
                    return plan
            }
            
            let visiblePlans = try await authorizedPlans(
                plans,
                member: session.membership,
                operation: .read
            )
            print("[TMIPlanService] Successfully fetched \(visiblePlans.count) authorized TMI plans")
            return visiblePlans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch a single TMI plan by ID
    func fetchPlan(byId planId: String) async throws -> TMIPlan? {
        let session = try authorizedSession()
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
            let latestInterestSurveyId = data["latestInterestSurveyId"] as? String
            let interestIdsSnapshot = data["interestIdsSnapshot"] as? [String]
            let snapshotUpdatedAt = (data["snapshotUpdatedAt"] as? Double).map(Date.init(timeIntervalSince1970:))

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
                resources: resources,
                latestInterestSurveyId: latestInterestSurveyId,
                interestIdsSnapshot: interestIdsSnapshot,
                snapshotUpdatedAt: snapshotUpdatedAt
            )

            guard let authorizedPlan = try await authorizedPlan(
                plan,
                member: session.membership,
                operation: .read
            ) else {
                throw TMIPlanServiceError.authorizationDenied
            }
            print("[TMIPlanService] Successfully fetched plan: \(authorizedPlan.model.rawValue)")
            return authorizedPlan
        } catch {
            print("[TMIPlanService] Error fetching plan: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Add a new TMI plan to Firestore
    func addPlan(_ plan: TMIPlan) async throws -> TMIPlan {
        let session = try authorizedSession()
        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }

        let canonicalStudents = try await canonicalStudents(for: plan.students)
        let provisionalPlanID = collection.document().documentID
        let scope = try planAuthorizationScope(
            planID: provisionalPlanID,
            districtID: session.membership.districtID,
            students: canonicalStudents
        )
        try authorization.require(
            authorization.canWritePlan(member: session.membership, plan: scope)
        )

        var trustedPlan = plan
        trustedPlan.id = provisionalPlanID
        trustedPlan.students = canonicalStudents
        trustedPlan.districtId = session.membership.districtID
        trustedPlan.createdBy = session.membership.userID
        trustedPlan.creationDate = Date()
        trustedPlan.lastUpdated = Date()

        do {
            print("[TMIPlanService] Adding TMI plan: \(trustedPlan.model.rawValue)")
            
            // Convert plan to Firestore data (without ID)
            let data = trustedPlan.toFirestoreData()
            
            let documentRef = collection.document(provisionalPlanID)
            try await documentRef.setData(data)
            
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
            let latestInterestSurveyId = docData["latestInterestSurveyId"] as? String
            let interestIdsSnapshot = docData["interestIdsSnapshot"] as? [String]
            let snapshotUpdatedAt = (docData["snapshotUpdatedAt"] as? Double).map(Date.init(timeIntervalSince1970:))
            
            var savedPlan = TMIPlan(
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
                resources: resources,
                latestInterestSurveyId: latestInterestSurveyId,
                interestIdsSnapshot: interestIdsSnapshot,
                snapshotUpdatedAt: snapshotUpdatedAt
            )
            savedPlan.students = canonicalStudents
            savedPlan.districtId = session.membership.districtID
            savedPlan.createdBy = session.membership.userID
            return savedPlan
        } catch {
            print("[TMIPlanService] Error adding TMI plan: \(error)")
            throw TMIPlanServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Update an existing TMI plan in Firestore
    func updatePlan(_ plan: TMIPlan) async throws -> TMIPlan {
        let session = try authorizedSession()
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }

        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }

        guard let storedPlan = try await fetchPlan(byId: planId) else {
            throw TMIPlanServiceError.invalidPlanId
        }
        let canonicalStudents = try await canonicalStudents(for: storedPlan.students)
        let scope = try planAuthorizationScope(
            planID: planId,
            districtID: session.membership.districtID,
            students: canonicalStudents
        )
        try authorization.require(
            authorization.canWritePlan(member: session.membership, plan: scope)
        )

        do {
            print("[TMIPlanService] Updating TMI plan: \(plan.model.rawValue)")
            
            var updatedPlan = plan
            updatedPlan.students = canonicalStudents
            updatedPlan.districtId = session.membership.districtID
            updatedPlan.createdBy = storedPlan.createdBy
            updatedPlan.creationDate = storedPlan.creationDate
            updatedPlan.lastUpdated = Date()
            
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
        let session = try authorizedSession()
        guard let planId = plan.id else {
            throw TMIPlanServiceError.invalidPlanId
        }

        guard let collection = userPlansCollection else {
            throw TMIPlanServiceError.userNotAuthenticated
        }

        guard let storedPlan = try await fetchPlan(byId: planId) else {
            throw TMIPlanServiceError.invalidPlanId
        }
        let canonicalStudents = try await canonicalStudents(for: storedPlan.students)
        let scope = try planAuthorizationScope(
            planID: planId,
            districtID: session.membership.districtID,
            students: canonicalStudents
        )
        guard authorization.canDeletePlan(
            member: session.membership,
            plan: scope
        ) else {
            throw TMIPlanServiceError.authorizationDenied
        }
    }
    
    /// Get a specific TMI plan by ID
    func getPlan(by id: String) async throws -> TMIPlan? {
        return try await fetchPlan(byId: id)

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
                let latestInterestSurveyId = data["latestInterestSurveyId"] as? String
                let interestIdsSnapshot = data["interestIdsSnapshot"] as? [String]
                let snapshotUpdatedAt = (data["snapshotUpdatedAt"] as? Double).map(Date.init(timeIntervalSince1970:))

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
                    resources: resources,
                    latestInterestSurveyId: latestInterestSurveyId,
                    interestIdsSnapshot: interestIdsSnapshot,
                    snapshotUpdatedAt: snapshotUpdatedAt
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
        guard userPlansCollection != nil else {
            throw TMIPlanServiceError.userNotAuthenticated
        }

        do {
            print("[TMIPlanService] Fetching TMI plans for student: \(studentId)")

            // Fetch all plans and filter locally (arrayContains doesn't work with map elements)
            let allPlans = try await fetchPlans()
            let filteredPlans = allPlans.filter { plan in
                plan.students.contains(where: { $0.id == studentId })
            }

            print("[TMIPlanService] Successfully fetched \(filteredPlans.count) TMI plans for student")
            return filteredPlans
        } catch {
            print("[TMIPlanService] Error fetching TMI plans for student: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }

    /// Update plan with survey snapshot data
    func updateSurveySnapshot(planId: String, surveyId: String, interestIds: [String]) async throws {
        _ = try await requireAuthorizedPlan(planID: planId, operation: .write)
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

    // MARK: - Phase 1: District-Scoped Queries
    
    /// Fetch all plans in a district (for cross-staff access)
    func fetchPlansInDistrict(_ districtId: String) async throws -> [TMIPlan] {
        let session = try authorizedSession()
        guard districtId == session.membership.districtID,
              AuthorizationPolicy.canViewAggregate(
                session.membership,
                districtID: districtId
              ) else {
            throw TMIPlanServiceError.authorizationDenied
        }
        print("[TMIPlanService] Fetching plans for district: \(districtId)")
        
        let query = db.collection("plans")
            .whereField("districtId", isEqualTo: districtId)
        
        do {
            let snapshot = try await query.getDocuments()
            
            // Use simple parsing for district-scoped plans
            let plans = snapshot.documents.compactMap { document -> TMIPlan? in
                let data = document.data()
                
                guard let modelRaw = data["model"] as? String,
                      let model = TMIPlanModel(rawValue: modelRaw),
                      let progress = data["progress"] as? Double,
                      let notes = data["notes"] as? String,
                      let creationTimestamp = data["creationDate"] as? Double,
                      let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
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
                
                let title = data["title"] as? String ?? ""
                let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                let createdBy = data["createdBy"] as? String ?? ""
                let districtId = data["districtId"] as? String
                let assignedCounselorId = data["assignedCounselorId"] as? String
                
                return TMIPlan(
                    id: document.documentID,
                    title: title,
                    description: data["description"] as? String,
                    students: students,
                    model: model,
                    interests: [],
                    startDate: startDate,
                    endDate: endDate,
                    creationDate: creationDate,
                    lastUpdated: lastUpdated,
                    goals: [],
                    progress: progress,
                    notes: notes,
                    createdBy: createdBy,
                    resources: [],
                    districtId: districtId,
                    assignedCounselorId: assignedCounselorId
                )
            }
            
            let visiblePlans = try await authorizedPlans(
                plans,
                member: session.membership,
                operation: .read
            )
            print("[TMIPlanService] Found \(visiblePlans.count) authorized plans in district")
            return visiblePlans
        } catch {
            print("[TMIPlanService] Error fetching district plans: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch plans assigned to a specific counselor (caseload)
    func fetchPlansForCounselor(_ counselorId: String) async throws -> [TMIPlan] {
        let session = try authorizedSession()
        guard counselorId == session.membership.userID
                || AuthorizationPolicy.canManageStaff(session.membership) else {
            throw TMIPlanServiceError.authorizationDenied
        }
        print("[TMIPlanService] Fetching plans for counselor: \(counselorId)")
        
        let query = db.collection("plans")
            .whereField("assignedCounselorId", isEqualTo: counselorId)
        
        do {
            let snapshot = try await query.getDocuments()
            
            let plans = snapshot.documents.compactMap { document -> TMIPlan? in
                let data = document.data()
                
                guard let modelRaw = data["model"] as? String,
                      let model = TMIPlanModel(rawValue: modelRaw),
                      let progress = data["progress"] as? Double,
                      let notes = data["notes"] as? String,
                      let creationTimestamp = data["creationDate"] as? Double,
                      let lastUpdatedTimestamp = data["lastUpdated"] as? Double else {
                    return nil
                }
                
                let creationDate = Date(timeIntervalSince1970: creationTimestamp)
                let lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
                
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
                
                let title = data["title"] as? String ?? ""
                let startDate = (data["startDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let endDate = (data["endDate"] as? Double).map(Date.init(timeIntervalSince1970:))
                let createdBy = data["createdBy"] as? String ?? ""
                let districtId = data["districtId"] as? String
                let assignedCounselorId = data["assignedCounselorId"] as? String
                
                return TMIPlan(
                    id: document.documentID,
                    title: title,
                    description: data["description"] as? String,
                    students: students,
                    model: model,
                    interests: [],
                    startDate: startDate,
                    endDate: endDate,
                    creationDate: creationDate,
                    lastUpdated: lastUpdated,
                    goals: [],
                    progress: progress,
                    notes: notes,
                    createdBy: createdBy,
                    resources: [],
                    districtId: districtId,
                    assignedCounselorId: assignedCounselorId
                )
            }
            
            let visiblePlans = try await authorizedPlans(
                plans,
                member: session.membership,
                operation: .read
            )
            print("[TMIPlanService] Found \(visiblePlans.count) authorized plans for counselor")
            return visiblePlans
        } catch {
            print("[TMIPlanService] Error fetching counselor plans: \(error)")
            throw TMIPlanServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Assign a counselor to a plan
    func assignCounselor(_ counselorId: String, to planId: String) async throws {
        let session = try authorizedSession()
        guard AuthorizationPolicy.canManageStaff(session.membership) else {
            throw TMIPlanServiceError.authorizationDenied
        }
        _ = try await requireAuthorizedPlan(planID: planId, operation: .write)
        print("[TMIPlanService] Assigning counselor \(counselorId) to plan \(planId)")
        
        try await db.collection("plans")
            .document(planId)
            .updateData([
                "assignedCounselorId": counselorId,
                "lastUpdated": Date().timeIntervalSince1970
            ])
        
        print("[TMIPlanService] Counselor assigned successfully")
    }

    // MARK: - Plan Inputs & Evidence

    private func planInputsCollection(planId: String) -> CollectionReference {
        db.collection(FirestorePaths.planInputs(planId: planId))
    }

    private func planEvidenceCollection(planId: String) -> CollectionReference {
        db.collection(FirestorePaths.planEvidence(planId: planId))
    }

    func fetchPlanInputs(planId: String) async throws -> [PlanInputField] {
        _ = try await requireAuthorizedPlan(planID: planId, operation: .read)
        let snapshot = try await planInputsCollection(planId: planId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? document.data(as: PlanInputField.self)
        }
    }

    func savePlanInputs(planId: String, fields: [PlanInputField]) async throws {
        let session = try authorizedSession()
        _ = try await requireAuthorizedPlan(planID: planId, operation: .write)
        guard !fields.isEmpty else { return }
        let batch = db.batch()
        let now = Date()
        let userId = session.membership.userID

        for field in fields {
            let docRef: DocumentReference
            if let id = field.id {
                docRef = planInputsCollection(planId: planId).document(id)
            } else {
                docRef = planInputsCollection(planId: planId).document()
            }

            var updated = field
            updated.planId = planId
            updated.updatedAt = now
            updated.updatedBy = userId

            if updated.createdAt > now {
                updated.createdAt = now
            }

            let data = try Firestore.Encoder().encode(updated)
            batch.setData(data, forDocument: docRef, merge: true)
        }

        try await batch.commit()
    }

    func upsertPlanInput(planId: String, field: PlanInputField) async throws -> PlanInputField {
        let session = try authorizedSession()
        _ = try await requireAuthorizedPlan(planID: planId, operation: .write)
        let now = Date()
        let userId = session.membership.userID
        let docRef: DocumentReference

        if let id = field.id {
            docRef = planInputsCollection(planId: planId).document(id)
        } else {
            docRef = planInputsCollection(planId: planId).document()
        }

        var updated = field
        updated.planId = planId
        updated.updatedAt = now
        updated.updatedBy = userId
        if updated.createdAt > now {
            updated.createdAt = now
        }

        let data = try Firestore.Encoder().encode(updated)
        try await docRef.setData(data, merge: true)

        var returned = updated
        returned.id = docRef.documentID
        return returned
    }

    func fetchPlanEvidence(planId: String) async throws -> [PlanEvidenceEntry] {
        _ = try await requireAuthorizedPlan(planID: planId, operation: .read)
        let snapshot = try await planEvidenceCollection(planId: planId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? document.data(as: PlanEvidenceEntry.self)
        }
    }

    func addPlanEvidence(planId: String, entry: PlanEvidenceEntry) async throws -> PlanEvidenceEntry {
        let session = try authorizedSession()
        _ = try await requireAuthorizedPlan(planID: planId, operation: .write)
        let now = Date()
        let userId = session.membership.userID
        let docRef = planEvidenceCollection(planId: planId).document()

        var updated = entry
        updated.planId = planId
        updated.createdAt = now
        updated.createdBy = userId

        let data = try Firestore.Encoder().encode(updated)
        try await docRef.setData(data, merge: true)

        var returned = updated
        returned.id = docRef.documentID
        return returned
    }

    func fetchPlanEvidence(forPlanIds planIds: [String]) async throws -> [PlanEvidenceEntry] {
        guard !planIds.isEmpty else { return [] }

        var collected: [PlanEvidenceEntry] = []
        try await withThrowingTaskGroup(of: [PlanEvidenceEntry].self) { group in
            for planId in planIds {
                group.addTask {
                    try await self.fetchPlanEvidence(planId: planId)
                }
            }

            for try await entries in group {
                collected.append(contentsOf: entries)
            }
        }
        return collected
    }

    private enum PlanAuthorizationOperation {
        case read
        case write
        case approve
    }

    private func authorizedSession() throws -> AuthenticatedSession {
        let userID = Auth.auth().currentUser?.uid
        guard let session = authorizationSessions.session(
            authenticatedUserID: userID
        ) else {
            throw TMIPlanServiceError.userNotAuthenticated
        }
        return session
    }

    private func canonicalStudents(for students: [Student]) async throws -> [Student] {
        let studentIDs = Array(Set(students.compactMap(\.id))).sorted()
        guard !studentIDs.isEmpty else {
            throw TMIPlanServiceError.authorizationDenied
        }

        let studentService = StudentService(
            authorizationSessions: authorizationSessions
        )
        var canonicalStudents: [Student] = []
        for studentID in studentIDs {
            guard let student = try await studentService.getStudent(by: studentID) else {
                throw TMIPlanServiceError.authorizationDenied
            }
            canonicalStudents.append(student)
        }
        return canonicalStudents
    }

    private func planAuthorizationScope(
        planID: String,
        districtID: String,
        students: [Student]
    ) throws -> PlanAuthorizationScope {
        let studentScopes = try students.map { student in
            guard let scope = StudentAuthorizationScope(student: student),
                  scope.districtID == districtID else {
                throw TMIPlanServiceError.authorizationDenied
            }
            return scope
        }

        return PlanAuthorizationScope(
            planID: planID,
            districtID: districtID,
            students: studentScopes
        )
    }

    private func authorizedPlan(
        _ plan: TMIPlan,
        member: MembershipContext,
        operation: PlanAuthorizationOperation
    ) async throws -> TMIPlan? {
        guard let planID = plan.id else {
            return nil
        }

        let students = try await canonicalStudents(for: plan.students)
        let districtIDs = Set(students.compactMap(\.districtId))
        guard districtIDs == [member.districtID],
              plan.districtId == nil || plan.districtId == member.districtID else {
            return nil
        }

        let scope = try planAuthorizationScope(
            planID: planID,
            districtID: member.districtID,
            students: students
        )
        let isAllowed: Bool
        switch operation {
        case .read:
            isAllowed = authorization.canReadPlan(member: member, plan: scope)
        case .write:
            isAllowed = authorization.canWritePlan(member: member, plan: scope)
        case .approve:
            isAllowed = authorization.canApprovePlan(member: member, plan: scope)
        }
        guard isAllowed else {
            return nil
        }

        var trustedPlan = plan
        trustedPlan.students = students
        trustedPlan.districtId = member.districtID
        return trustedPlan
    }

    private func authorizedPlans(
        _ plans: [TMIPlan],
        member: MembershipContext,
        operation: PlanAuthorizationOperation
    ) async throws -> [TMIPlan] {
        var authorized: [TMIPlan] = []
        for plan in plans {
            if let plan = try? await authorizedPlan(
                plan,
                member: member,
                operation: operation
            ) {
                authorized.append(plan)
            }
        }
        return authorized
    }

    private func requireAuthorizedPlan(
        planID: String,
        operation: PlanAuthorizationOperation
    ) async throws -> TMIPlan {
        let session = try authorizedSession()
        guard let plan = try await fetchPlan(byId: planID),
              let authorized = try await authorizedPlan(
                plan,
                member: session.membership,
                operation: operation
              ) else {
            throw TMIPlanServiceError.authorizationDenied
        }
        return authorized
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
    case authorizationDenied
    
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
        case .authorizationDenied:
            return "You don’t have access to this TMI plan"
        }
    }
}
