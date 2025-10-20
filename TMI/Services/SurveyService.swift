//
//  SurveyService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class SurveyService: @unchecked Sendable {
  static let shared = SurveyService()
  private let firestore = FirebaseManager.shared.firestore
  
  private init() {}
  
  // MARK: - Submit Survey
  func submitSurvey(_ survey: Survey) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    // Don't manually set @DocumentID - let Firestore manage it
    var surveyToSave = survey
    surveyToSave.completed = true
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let docRef = try collection.addDocument(from: surveyToSave)
    return docRef.documentID
  }
  
  // MARK: - Save Survey Draft
  func saveSurveyDraft(_ survey: Survey) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    // Don't manually set @DocumentID - let Firestore manage it
    var surveyToSave = survey
    surveyToSave.completed = false
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let docRef = try collection.addDocument(from: surveyToSave)
    return docRef.documentID
  }
  
  // MARK: - Fetch Survey
  func fetchSurvey(id: String) async throws -> Survey {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
      .document(id)
    
    let snapshot = try await document.getDocument()
    
    guard snapshot.exists else {
      throw SurveyServiceError.surveyNotFound
    }
    
    return try snapshot.data(as: Survey.self)
  }
  
  // MARK: - Fetch All Surveys
  func fetchAllSurveys() async throws -> [Survey] {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let snapshot = try await collection
      .order(by: "date", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Survey.self)
    }
  }
  
  // MARK: - Fetch Surveys by Type
  func fetchSurveys(by type: Survey.SurveyType) async throws -> [Survey] {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let snapshot = try await collection
      .whereField("surveyType", isEqualTo: type.rawValue)
      .order(by: "date", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Survey.self)
    }
  }
  
  // MARK: - Fetch Surveys for Student
  func fetchSurveys(for studentID: String) async throws -> [Survey] {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let snapshot = try await collection
      .whereField("studentId", isEqualTo: studentID)
      .order(by: "date", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Survey.self)
    }
  }
  
  // MARK: - Fetch Completed Surveys
  func fetchCompletedSurveys() async throws -> [Survey] {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let snapshot = try await collection
      .whereField("completed", isEqualTo: true)
      .order(by: "date", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Survey.self)
    }
  }
  
  // MARK: - Fetch Draft Surveys
  func fetchDraftSurveys() async throws -> [Survey] {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    let snapshot = try await collection
      .whereField("completed", isEqualTo: false)
      .order(by: "date", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: Survey.self)
    }
  }
  
  // MARK: - Update Survey
  func updateSurvey(_ survey: Survey) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    guard let surveyID = survey.id else {
      throw SurveyServiceError.invalidSurveyID
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
      .document(surveyID)
    
    try document.setData(from: survey, merge: true)
  }
  
  // MARK: - Update Survey Question Answer
  func updateSurveyAnswer(surveyID: String, questionID: String, answer: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
      .document(surveyID)
    
    // First fetch the survey to update the specific question
    let snapshot = try await document.getDocument()
    guard var survey = try? snapshot.data(as: Survey.self) else {
      throw SurveyServiceError.surveyNotFound
    }
    
    // Update the specific question's answer
    if let questionIndex = survey.questions.firstIndex(where: { $0.id == questionID }) {
      survey.questions[questionIndex].answer = answer
      try document.setData(from: survey)
    } else {
      throw SurveyServiceError.questionNotFound
    }
  }
  
  // MARK: - Delete Survey
  func deleteSurvey(id: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
      .document(id)
    
    try await document.delete()
  }
  
  // MARK: - Survey Analytics
  func fetchSurveyAnalytics(for type: Survey.SurveyType) async throws -> SurveyAnalytics {
    let surveys = try await fetchSurveys(by: type)
    let completedSurveys = surveys.filter { $0.completed }
    
    return SurveyAnalytics(
      totalSurveys: surveys.count,
      completedSurveys: completedSurveys.count,
      draftSurveys: surveys.count - completedSurveys.count,
      averageCompletionRate: surveys.isEmpty ? 0.0 : Double(completedSurveys.count) / Double(surveys.count),
      surveyType: type
    )
  }
  
  // MARK: - Listen to Survey Changes
  func listenToSurveys(completion: @escaping (Result<[Survey], Error>) -> Void) -> ListenerRegistration? {
    guard let currentUser = Auth.auth().currentUser else {
      completion(.failure(SurveyServiceError.userNotAuthenticated))
      return nil
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    return collection
      .order(by: "date", descending: true)
      .addSnapshotListener { snapshot, error in
        if let error = error {
          completion(.failure(error))
          return
        }
        
        guard let documents = snapshot?.documents else {
          completion(.success([]))
          return
        }
        
        do {
          let surveys = try documents.compactMap { document in
            try document.data(as: Survey.self)
          }
          completion(.success(surveys))
        } catch {
          completion(.failure(error))
        }
      }
  }
  
  // MARK: - Student Interest Survey (New Flow)

  /// Save student interest survey response
  func saveStudentSurveyResponse(
    _ responses: [String: SurveyResponse.SurveyAnswerValue],
    for studentId: String,
    duration: TimeInterval
  ) async throws -> SurveyResponse {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }

    // Analyze responses to create interest clusters
    let clusters = analyzeInterests(from: responses)
    let topInterests = extractTopInterests(from: clusters)

    // Create survey response
    let surveyResponse = SurveyResponse(
      id: UUID(),
      studentId: studentId,
      responses: responses,
      interestClusters: clusters,
      topInterests: topInterests,
      completedAt: Date(),
      completionTime: duration
    )

    // Save to Firestore
    let docRef = firestore
      .collection(FirestoreCollection.users.rawValue).document(currentUser.uid)
      .collection(FirestoreCollection.students.rawValue).document(studentId)
      .collection("interestSurveys").document(surveyResponse.id.uuidString)

    try await docRef.setData(surveyResponse.toFirestoreData())

    // Update student document with latest survey reference
    let studentRef = firestore
      .collection(FirestoreCollection.users.rawValue).document(currentUser.uid)
      .collection(FirestoreCollection.students.rawValue).document(studentId)

    try await studentRef.updateData([
      "latestSurveyId": surveyResponse.id.uuidString,
      "lastSurveyDate": Timestamp(date: surveyResponse.completedAt),
      "interestClusters": clusters.map { $0.toFirestoreData() },
      "topInterests": topInterests
    ])

    print("[Data] Interest survey saved for student: \(studentId)")

    return surveyResponse
  }

  /// Fetch latest interest survey for student
  func fetchLatestStudentSurvey(for studentId: String) async throws -> SurveyResponse? {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }

    let querySnapshot = try await firestore
      .collection(FirestoreCollection.users.rawValue).document(currentUser.uid)
      .collection(FirestoreCollection.students.rawValue).document(studentId)
      .collection("interestSurveys")
      .order(by: "completedAt", descending: true)
      .limit(to: 1)
      .getDocuments()

    guard let document = querySnapshot.documents.first else {
      return nil
    }

    return try document.data(as: SurveyResponse.self)
  }

  /// Get career matches for student based on latest survey
  func getCareerMatches(for studentId: String) async throws -> [CareerMatchResult] {
    guard let survey = try await fetchLatestStudentSurvey(for: studentId) else {
      throw SurveyServiceError.surveyNotFound
    }

    // Extract dream job if exists
    var dreamJob: String?
    if case .text(let text) = survey.responses["dream_job"] {
      dreamJob = text
    }

    // Use CareerMatchingService
    let matches = CareerMatchingService.shared.matchCareers(
      from: survey.interestClusters,
      dreamJob: dreamJob
    )

    return matches
  }

  // MARK: - Analysis Helpers

  private func analyzeInterests(from responses: [String: SurveyResponse.SurveyAnswerValue]) -> [InterestCluster] {
    // Extract selected interests
    var selectedInterestIds: [String] = []
    if case .options(let options) = responses["interests"] {
      selectedInterestIds = options
    }

    // Extract passion scale
    var passionScale: Int?
    if case .scale(let value) = responses["career_passion"] {
      passionScale = value
    }

    // Calculate weights
    var clusterWeights: [String: Double] = [:]
    for interestId in selectedInterestIds {
      clusterWeights[interestId] = 1.0
    }

    // Boost if high passion
    if let passion = passionScale, passion >= 4 {
      for key in clusterWeights.keys {
        clusterWeights[key]? *= 1.2
      }
    }

    // Normalize
    let maxWeight = clusterWeights.values.max() ?? 1.0
    for key in clusterWeights.keys {
      clusterWeights[key]? /= maxWeight
    }

    // Create clusters
    let allClusters = InterestCluster.allCategories
    var results: [InterestCluster] = []

    for clusterId in selectedInterestIds {
      if let baseCluster = allClusters.first(where: { $0.name == clusterId }) {
        let weight = clusterWeights[clusterId] ?? 0.5
        let weightedCluster = InterestCluster(
          id: baseCluster.id,
          name: baseCluster.name,
          displayName: baseCluster.displayName,
          weight: weight,
          relatedCareers: baseCluster.relatedCareers,
          icon: baseCluster.icon,
          color: baseCluster.color
        )
        results.append(weightedCluster)
      }
    }

    return results.sorted { $0.weight > $1.weight }
  }

  private func extractTopInterests(from clusters: [InterestCluster]) -> [String] {
    return clusters.prefix(3).map { $0.displayName }
  }

  // MARK: - Completion-based methods for backward compatibility
  func submitSurvey(_ survey: Survey, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
    Task {
      do {
        _ = try await submitSurvey(survey)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func fetchSurvey(id: String, completion: @escaping @Sendable (Result<Survey, Error>) -> Void) {
    Task {
      do {
        let survey = try await fetchSurvey(id: id)
        completion(.success(survey))
      } catch {
        completion(.failure(error))
      }
    }
  }
}

// MARK: - Survey Analytics Model
struct SurveyAnalytics: Codable, Sendable {
  let totalSurveys: Int
  let completedSurveys: Int
  let draftSurveys: Int
  let averageCompletionRate: Double
  let surveyType: Survey.SurveyType
}

// MARK: - Error Handling
extension SurveyService {
  enum SurveyServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case surveyNotFound
    case questionNotFound
    case invalidSurveyID
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
      switch self {
      case .userNotAuthenticated:
        return "User must be authenticated to access surveys"
      case .surveyNotFound:
        return "Survey not found"
      case .questionNotFound:
        return "Survey question not found"
      case .invalidSurveyID:
        return "Invalid survey ID provided"
      case .saveFailed(let message):
        return "Failed to save survey: \(message)"
      case .fetchFailed(let message):
        return "Failed to fetch survey: \(message)"
      case .updateFailed(let message):
        return "Failed to update survey: \(message)"
      case .deleteFailed(let message):
        return "Failed to delete survey: \(message)"
      }
    }
  }
}

// MARK: - Firestore Conversion Extensions

extension SurveyResponse {
  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "id": id.uuidString,
      "studentId": studentId,
      "interestClusters": interestClusters.map { $0.toFirestoreData() },
      "topInterests": topInterests,
      "completedAt": Timestamp(date: completedAt),
      "completionTime": completionTime
    ]

    // Convert responses dictionary
    var responsesData: [String: Any] = [:]
    for (key, value) in responses {
      switch value {
      case .text(let text):
        responsesData[key] = ["type": "text", "value": text]
      case .options(let options):
        responsesData[key] = ["type": "options", "value": options]
      case .scale(let scale):
        responsesData[key] = ["type": "scale", "value": scale]
      }
    }
    data["responses"] = responsesData

    return data
  }
}

extension InterestCluster {
  func toFirestoreData() -> [String: Any] {
    return [
      "id": id.uuidString,
      "name": name,
      "displayName": displayName,
      "weight": weight,
      "relatedCareers": relatedCareers,
      "icon": icon,
      "color": color
    ]
  }
}

