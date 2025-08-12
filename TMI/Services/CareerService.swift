//
//  CareerService.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable
class CareerService {
  static let shared = CareerService()
  private let firestore = FIRESTORE_DATABASE
  
  // In-memory cache for performance
  private var careerCache: [Career] = []
  private var lastCacheUpdate: Date?
  private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
  
  private init() {
    // Initialize with sample data
    careerCache = Career.sampleCareers
  }
  
  // MARK: - Career Data Management
  
  /// Fetch all available careers
  func fetchAllCareers(forceRefresh: Bool = false) async throws -> [Career] {
    // Check cache first
    if !forceRefresh, let lastUpdate = lastCacheUpdate,
       Date().timeIntervalSince(lastUpdate) < cacheExpirationTime,
       !careerCache.isEmpty {
      return careerCache
    }
    
    // Try to fetch from Firebase first, fallback to sample data
    do {
      let careers = try await fetchCareersFromFirebase()
      if !careers.isEmpty {
        careerCache = careers
        lastCacheUpdate = Date()
        return careers
      }
    } catch {
      print("Failed to fetch careers from Firebase: \(error)")
    }
    
    // Fallback to sample data
    careerCache = Career.sampleCareers
    lastCacheUpdate = Date()
    return careerCache
  }
  
  /// Fetch careers by field/category
  func fetchCareers(byField field: String) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    return allCareers.filter { $0.field.lowercased() == field.lowercased() }
  }
  
  /// Fetch careers by skills
  func fetchCareers(bySkills skills: [String]) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    return allCareers.filter { career in
      !Set(skills).isDisjoint(with: Set(career.skills))
    }
  }
  
  /// Fetch careers within salary range
  func fetchCareers(salaryRange: ClosedRange<Double>) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    return allCareers.filter { career in
      career.salaryRange.overlaps(salaryRange)
    }
  }
  
  /// Search careers by query
  func searchCareers(query: String) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    let lowercaseQuery = query.lowercased()
    
    return allCareers.filter { career in
      career.title.lowercased().contains(lowercaseQuery) ||
      career.description.lowercased().contains(lowercaseQuery) ||
      career.field.lowercased().contains(lowercaseQuery) ||
      career.skills.contains { $0.lowercased().contains(lowercaseQuery) }
    }
  }
  
  /// Get trending/featured careers
  func fetchTrendingCareers() async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    // Sort by growth rate, taking top careers
    return Array(allCareers.sorted { $0.growthRate > $1.growthRate }.prefix(5))
  }
  
  /// Get career recommendations based on student interests
  func getCareerRecommendations(for student: Student) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    var scoredCareers: [(career: Career, score: Double)] = []
    
    for career in allCareers {
      var score = 0.0
      
      // Score based on interests
      for interest in student.interests {
        if career.field.lowercased().contains(interest.name.lowercased()) ||
           career.title.lowercased().contains(interest.name.lowercased()) ||
           career.description.lowercased().contains(interest.name.lowercased()) {
          score += Double(interest.popularityScore ?? 1) * 0.3
        }
      }
      
      // Score based on hobbies
      for hobby in student.hobbies {
        if career.skills.contains(where: { skill in
          skill.lowercased().contains(hobby.name.lowercased())
        }) || career.description.lowercased().contains(hobby.name.lowercased()) {
          score += Double(hobby.popularityScore ?? 1) * 0.2
        }
      }
      
      // Score based on academic performance (if available)
      if let academicPerformance = student.academicPerformance {
        if let gpa = academicPerformance.gpa, gpa >= 3.5 && career.education.contains("Master's") {
          score += 0.2
        } else if let gpa = academicPerformance.gpa, gpa >= 3.0 && career.education.contains("Bachelor's") {
          score += 0.15
        }
      }
      
      if score > 0 {
        scoredCareers.append((career: career, score: score))
      }
    }
    
    // Return top 10 recommendations sorted by score
    return Array(scoredCareers.sorted { $0.score > $1.score }.prefix(10).map { $0.career })
  }
  
  /// Get related careers based on field and skills
  func getRelatedCareers(to career: Career, limit: Int = 5) async throws -> [Career] {
    let allCareers = try await fetchAllCareers()
    
    var scoredCareers: [(career: Career, score: Double)] = []
    
    for otherCareer in allCareers {
      guard otherCareer.title != career.title else { continue }
      
      var score = 0.0
      
      // Same field gives high score
      if otherCareer.field == career.field {
        score += 0.5
      }
      
      // Similar skills
      let sharedSkills = Set(career.skills).intersection(Set(otherCareer.skills))
      score += Double(sharedSkills.count) * 0.1
      
      // Similar salary range
      if career.salaryRange.overlaps(otherCareer.salaryRange) {
        score += 0.2
      }
      
      if score > 0 {
        scoredCareers.append((career: otherCareer, score: score))
      }
    }
    
    return Array(scoredCareers.sorted { $0.score > $1.score }.prefix(limit).map { $0.career })
  }
  
  /// Get career statistics
  func getCareerStatistics() async throws -> CareerStatistics {
    let allCareers = try await fetchAllCareers()
    
    let totalCareers = allCareers.count
    let fields = Set(allCareers.map { $0.field })
    let allSkills = Set(allCareers.flatMap { $0.skills })
    
    let salaryRanges = allCareers.map { ($0.salaryRange.lowerBound + $0.salaryRange.upperBound) / 2 }
    let averageSalary = salaryRanges.reduce(0, +) / Double(salaryRanges.count)
    
    let highGrowthCareers = allCareers.filter { $0.growthRate > 0.1 }.count
    
    var fieldDistribution: [String: Int] = [:]
    for career in allCareers {
      fieldDistribution[career.field, default: 0] += 1
    }
    
    return CareerStatistics(
      totalCareers: totalCareers,
      uniqueFields: fields.count,
      uniqueSkills: allSkills.count,
      averageSalary: averageSalary,
      highGrowthCareers: highGrowthCareers,
      fieldDistribution: fieldDistribution
    )
  }
  
  // MARK: - Firebase Integration
  
  private func fetchCareersFromFirebase() async throws -> [Career] {
    // For now, return empty array - in future this would fetch from global career database
    // This allows the service to work without Firebase career data
    return []
  }
  
  /// Save user's career interests/bookmarks
  func saveCareerBookmark(career: Career) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw CareerServiceError.userNotAuthenticated
    }
    
    let bookmark = CareerBookmark(
      careerTitle: career.title,
      careerField: career.field,
      bookmarkedAt: Date()
    )
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection("careerBookmarks")
    
    try collection.document(career.title).setData(from: bookmark)
  }
  
  /// Fetch user's career bookmarks
  func fetchCareerBookmarks() async throws -> [CareerBookmark] {
    guard let currentUser = Auth.auth().currentUser else {
      throw CareerServiceError.userNotAuthenticated
    }
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection("careerBookmarks")
    
    let snapshot = try await collection
      .order(by: "bookmarkedAt", descending: true)
      .getDocuments()
    
    return try snapshot.documents.compactMap { document in
      try document.data(as: CareerBookmark.self)
    }
  }
  
  /// Remove career bookmark
  func removeCareerBookmark(careerTitle: String) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw CareerServiceError.userNotAuthenticated
    }
    
    let document = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection("careerBookmarks")
      .document(careerTitle)
    
    try await document.delete()
  }
  
  /// Track career exploration for analytics
  func trackCareerExploration(career: Career, action: CareerExplorationAction) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      return // Don't throw error for analytics
    }
    
    let exploration = CareerExploration(
      careerTitle: career.title,
      careerField: career.field,
      action: action,
      timestamp: Date()
    )
    
    let collection = firestore
      .collection(FirestoreCollection.users.rawValue)
      .document(currentUser.uid)
      .collection("careerExplorations")
    
    try collection.document().setData(from: exploration)
  }
  
  // MARK: - Utility Methods
  
  /// Get all unique career fields
  func getAllCareerFields() async throws -> [String] {
    let allCareers = try await fetchAllCareers()
    return Array(Set(allCareers.map { $0.field })).sorted()
  }
  
  /// Get all unique skills across careers
  func getAllSkills() async throws -> [String] {
    let allCareers = try await fetchAllCareers()
    return Array(Set(allCareers.flatMap { $0.skills })).sorted()
  }
  
  /// Get career field icon
  func getFieldIcon(for field: String) -> String {
    switch field.lowercased() {
    case "technology": return "desktopcomputer"
    case "healthcare": return "heart.text.square"
    case "education": return "book"
    case "business": return "briefcase"
    case "engineering": return "gearshape.2"
    case "arts": return "paintpalette"
    case "science": return "atom"
    default: return "star"
    }
  }
}

// MARK: - Supporting Models

struct CareerStatistics: Codable {
  let totalCareers: Int
  let uniqueFields: Int
  let uniqueSkills: Int
  let averageSalary: Double
  let highGrowthCareers: Int
  let fieldDistribution: [String: Int]
}

struct CareerBookmark: Codable, Identifiable {
  @DocumentID var id: String?
  let careerTitle: String
  let careerField: String
  let bookmarkedAt: Date
}

struct CareerExploration: Codable {
  @DocumentID var id: String?
  let careerTitle: String
  let careerField: String
  let action: CareerExplorationAction
  let timestamp: Date
}

enum CareerExplorationAction: String, Codable, CaseIterable {
  case viewed = "viewed"
  case bookmarked = "bookmarked"
  case sharedDetails = "shared_details"
  case exploredEducation = "explored_education"
  case exploredSkills = "explored_skills"
  case exploredPathway = "explored_pathway"
  case searchedRelated = "searched_related"
}

// MARK: - Error Handling

extension CareerService {
  enum CareerServiceError: Error, LocalizedError {
    case userNotAuthenticated
    case careerNotFound
    case invalidCareerData
    case fetchFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
      switch self {
      case .userNotAuthenticated:
        return "User must be authenticated to access career features"
      case .careerNotFound:
        return "Career not found"
      case .invalidCareerData:
        return "Invalid career data provided"
      case .fetchFailed(let message):
        return "Failed to fetch career data: \(message)"
      case .saveFailed(let message):
        return "Failed to save career data: \(message)"
      }
    }
  }
}

