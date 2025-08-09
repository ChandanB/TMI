//
//  SurveyService.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class SurveyService {
  static let shared = SurveyService()
  private let firestore = FIRESTORE_DATABASE
  
  private init() {}
  
  // MARK: - Submit Survey
  func submitSurvey(_ survey: Survey) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let surveyID = survey.id ?? UUID().uuidString
    var surveyToSave = survey
    surveyToSave.id = surveyID
    surveyToSave.completed = true
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    try collection.document(surveyID).setData(from: surveyToSave)
    return surveyID
  }
  
  // MARK: - Save Survey Draft
  func saveSurveyDraft(_ survey: Survey) async throws -> String {
    guard let currentUser = Auth.auth().currentUser else {
      throw SurveyServiceError.userNotAuthenticated
    }
    
    let surveyID = survey.id ?? UUID().uuidString
    var surveyToSave = survey
    surveyToSave.id = surveyID
    surveyToSave.completed = false
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection(FirestoreCollection.surveys.rawValue)
    
    try collection.document(surveyID).setData(from: surveyToSave)
    return surveyID
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
  
  // MARK: - Completion-based methods for backward compatibility
  func submitSurvey(_ survey: Survey, completion: @escaping (Result<Void, Error>) -> Void) {
    Task {
      do {
        _ = try await submitSurvey(survey)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }
  
  func fetchSurvey(id: String, completion: @escaping (Result<Survey, Error>) -> Void) {
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
struct SurveyAnalytics: Codable {
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
