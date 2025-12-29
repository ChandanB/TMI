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
final class CareerService: @unchecked Sendable {
  static let shared = CareerService()
  private let firestore = FirebaseManager.shared.firestore

  // Phase 3: Global Career Library Integration
  private let careerLibraryService = CareerLibraryService.shared

  // In-memory cache for performance
  private var careerCache: [Career] = []
  private var lastCacheUpdate: Date?
  private let cacheExpirationTime: TimeInterval = 300 // 5 minutes

  private init() {
    // Initialize with sample data
    careerCache = Career.sampleCareers
  }
  
  // MARK: - AI-Powered Career Search

  /// Search for careers using AI-powered generation based on query
  /// Phase 3: Now caches AI-generated careers in global library
  func searchCareersWithAI(query: String, student: Student? = nil) async throws -> AICareerResponse {
    print("[CareerService] searchCareersWithAI called with query: '\(query)'")

    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("[CareerService] Empty query provided")
      throw CareerServiceError.invalidCareerData
    }

    var aiResponse: AICareerResponse

    if #available(iOS 26.0, *) {
      print("[CareerService] iOS 26+ available, attempting AI search")
      do {
        aiResponse = try await AIInsightsService.shared.generateCareerDataFromSearch(query: query, student: student)
        print("[CareerService] AI search successful - Generated \(aiResponse.careers.count) AI careers for query: '\(query)'")
      } catch {
        print("[CareerService] AI career search failed for '\(query)': \(error)")
        print("[CareerService] Falling back to enhanced AI career generation")
        // Enhanced fallback using AICareerGenerator
        aiResponse = AIInsightsService.shared.generateSampleCareerSearchResponse(query: query, student: student)
      }
    } else {
      print("[CareerService] iOS 26+ not available, using enhanced AI career generation fallback")
      // Enhanced fallback using AICareerGenerator with intelligent career generation
      aiResponse = AIInsightsService.shared.generateSampleCareerSearchResponse(query: query, student: student)
      print("[CareerService] Enhanced fallback generated \(aiResponse.careers.count) careers for query: '\(query)'")
    }

    // Phase 3: Cache AI-generated careers in global library
    await cacheAICareers(aiResponse.careers)

    return aiResponse
  }

  /// Cache AI-generated careers in global library
  private func cacheAICareers(_ careers: [Career]) async {
    for career in careers {
      do {
        _ = try await careerLibraryService.cacheAICareer(career)
        print("[CareerService] Cached AI career: \(career.title)")
      } catch {
        // Don't fail the entire operation if caching fails
        print("[CareerService] Failed to cache career '\(career.title)': \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Enhanced Career Data Management
  
  /// Fetch all available careers with enhanced caching and analytics
  /// Phase 3: Now fetches from global library first, then generates if needed
  func fetchAllCareers(forceRefresh: Bool = false, districtId: String? = nil) async throws -> [Career] {
    // Check in-memory cache first
    if !forceRefresh, let lastUpdate = lastCacheUpdate,
       Date().timeIntervalSince(lastUpdate) < cacheExpirationTime,
       !careerCache.isEmpty {
      return careerCache
    }

    // Phase 3: Fetch from global library
    do {
      let globalCareers = try await careerLibraryService.fetchAllCareers(districtId: districtId)
      if !globalCareers.isEmpty {
        print("[CareerService] Fetched \(globalCareers.count) careers from global library")
        careerCache = globalCareers
        lastCacheUpdate = Date()
        return careerCache
      }
    } catch {
      print("[CareerService] Failed to fetch from global library: \(error)")
    }

    // If global library is empty, generate with AI and cache
    if #available(iOS 26.0, *) {
        do {
            let aiResponse = try await AIInsightsService.shared.generateCareerData(for: nil)
            print("[CareerService] Generated \(aiResponse.careers.count) careers with AI")
            // Cache in global library
            await cacheAICareers(aiResponse.careers)
            careerCache = aiResponse.careers
            lastCacheUpdate = Date()
            return careerCache
        } catch {
            print("[CareerService] Failed to generate careers with AI: \(error)")
            // Fallback to sample data if AI generation fails
            careerCache = Career.sampleCareers
            lastCacheUpdate = Date()
            return careerCache
        }
    } else {
        // Fallback to sample data for older iOS versions
        careerCache = Career.sampleCareers
        lastCacheUpdate = Date()
        return careerCache
    }
  }
  
  /// Get personalized career discovery insights
  func getCareerDiscoveryInsights(for student: Student) async throws -> CareerDiscoveryInsights {
    if #available(iOS 26.0, *) {
        do {
            let aiResponse = try await AIInsightsService.shared.generateCareerData(for: student)
            return aiResponse.insights
        } catch {
            print("Failed to generate career insights with AI: \(error)")
            // Fallback to rule-based insights if AI fails
            let allCareers = try await fetchAllCareers()
            return generateRuleBasedCareerDiscoveryInsights(for: student, allCareers: allCareers)
        }
    } else {
        // Fallback to rule-based insights for older iOS versions
        let allCareers = try await fetchAllCareers()
        return generateRuleBasedCareerDiscoveryInsights(for: student, allCareers: allCareers)
    }
  }

  // New helper function for rule-based insights (extracted from original getCareerDiscoveryInsights)
  private func generateRuleBasedCareerDiscoveryInsights(for student: Student, allCareers: [Career]) -> CareerDiscoveryInsights {
    let recommendations = generateRuleBasedCareerRecommendations(for: student, allCareers: allCareers)
    
    // Analyze student's interest patterns
    let allCategories = student.interests.flatMap { $0.category }
    let interestCategories = Dictionary(grouping: allCategories) { $0 }
    let topInterestCategory = interestCategories.max { $0.value.count < $1.value.count }?.key.rawValue ?? "General"
    
    // Find career fields with highest representation
    let _ = Dictionary(grouping: allCareers) { $0.field }
    let recommendedFields = Dictionary(grouping: recommendations) { $0.field }
    
    return CareerDiscoveryInsights(
      totalCareersExplored: allCareers.count,
      personalizedRecommendations: recommendations.count,
      topInterestCategory: topInterestCategory,
      strongestCareerFields: Array(recommendedFields.keys.prefix(3)),
      emergingOpportunities: getEmergingCareers(from: recommendations),
      skillGaps: identifySkillGaps(student: student, targetCareers: recommendations),
      nextSteps: generateNextSteps(for: student, basedOn: recommendations)
    )
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
  
  /// Get comprehensive career recommendations based on student interests, performance, and engagement
  /// Phase 3: Now caches AI-generated recommendations in global library
  func getCareerRecommendations(for student: Student) async throws -> [Career] {
    if #available(iOS 26.0, *) {
        do {
            let aiResponse = try await AIInsightsService.shared.generateCareerData(for: student)
            // Phase 3: Cache AI-generated recommendations
            await cacheAICareers(aiResponse.careers)
            return aiResponse.careers
        } catch {
            print("[CareerService] Failed to generate personalized careers with AI: \(error)")
            // Fallback to rule-based recommendations if AI fails
            let allCareers = try await fetchAllCareers()
            return generateRuleBasedCareerRecommendations(for: student, allCareers: allCareers)
        }
    } else {
        // Fallback to rule-based recommendations for older iOS versions
        let allCareers = try await fetchAllCareers()
        return generateRuleBasedCareerRecommendations(for: student, allCareers: allCareers)
    }
  }

  // New helper function for rule-based recommendations (extracted from original getCareerRecommendations)
  private func generateRuleBasedCareerRecommendations(for student: Student, allCareers: [Career]) -> [Career] {
    var scoredCareers: [(career: Career, score: Double)] = []
    
    for career in allCareers {
      var score = 0.0
      
      // Interest-based scoring with weighted categories
      for interest in student.interests {
        let interestWeight = Double(interest.popularityScore ?? 1)
        let categoryWeight = getInterestCategoryWeight(interest.category.first?.rawValue ?? "")
        
        if career.field.lowercased().contains(interest.name.lowercased()) {
          score += interestWeight * 0.4 * categoryWeight // Direct field match gets highest weight
        } else if career.title.lowercased().contains(interest.name.lowercased()) {
          score += interestWeight * 0.3 * categoryWeight
        } else if career.description.lowercased().contains(interest.name.lowercased()) {
          score += interestWeight * 0.2 * categoryWeight
        }
        
        // Check if interest aligns with career skills
        for skill in career.skills {
          if skill.lowercased().contains(interest.name.lowercased()) {
            score += interestWeight * 0.25 * categoryWeight
          }
        }
      }
      
      // Hobby-based scoring with skill alignment
      // Note: Hobbies are now part of interests array
      // Additional interest-based scoring is handled above
      
      // Enhanced academic performance scoring with subject alignment
      if let academicPerformance = student.academicPerformance {
        if let gpa = academicPerformance.gpa {
          // Education level alignment
          if gpa >= 3.5 && career.education.contains("Master's") {
            score += 0.25
          } else if gpa >= 3.5 && career.education.contains("PhD") {
            score += 0.3
          } else if gpa >= 3.0 && career.education.contains("Bachelor's") {
            score += 0.2
          } else if gpa >= 2.5 && (career.education.contains("Associate") || career.education.contains("Certificate")) {
            score += 0.15
          }
        }
        
        // Subject-specific performance alignment
        for subjectPerformance in academicPerformance.subjects {
          if career.skills.contains(where: { $0.lowercased().contains(subjectPerformance.name.lowercased()) }) {
            let gradeValue = convertGradeToNumeric(subjectPerformance.grade)
            score += gradeValue * 0.1
          }
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
  // Phase 3: Firebase integration now handled by CareerLibraryService
  
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
  
  /// Get career field icon with extended coverage
  func getFieldIcon(for field: String) -> String {
    switch field.lowercased() {
    case "technology": return "desktopcomputer"
    case "healthcare": return "heart.text.square"
    case "education": return "book"
    case "business": return "briefcase"
    case "engineering": return "gearshape.2"
    case "arts": return "paintpalette"
    case "science": return "atom"
    case "finance": return "dollarsign.circle"
    case "law": return "scale.3d"
    case "public service": return "building.columns"
    case "media": return "tv"
    case "sports": return "figure.run"
    case "culinary": return "fork.knife"
    default: return "star"
    }
  }
  
  // MARK: - Enhanced Helper Methods
  
  private func getInterestCategoryWeight(_ category: String) -> Double {
    switch category.lowercased() {
    case "academic", "stem": return 1.2
    case "creative", "arts": return 1.1
    case "social", "leadership": return 1.0
    case "physical", "sports": return 0.9
    default: return 1.0
    }
  }
  
  private func convertGradeToNumeric(_ grade: String) -> Double {
    switch grade.uppercased() {
    case "A+", "A": return 4.0
    case "A-": return 3.7
    case "B+": return 3.3
    case "B": return 3.0
    case "B-": return 2.7
    case "C+": return 2.3
    case "C": return 2.0
    case "C-": return 1.7
    case "D": return 1.0
    default: return 0.0
    }
  }
  
  private func getEmergingCareers(from careers: [Career]) -> [Career] {
    return careers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 }
  }
  
  private func identifySkillGaps(student: Student, targetCareers: [Career]) -> [String] {
    let studentSkills = Set(student.interests.map { $0.name })
    let requiredSkills = Set(targetCareers.flatMap { $0.skills })
    return Array(requiredSkills.subtracting(studentSkills)).prefix(5).map { $0 }
  }
  
  private func generateNextSteps(for student: Student, basedOn careers: [Career]) -> [String] {
    var steps: [String] = []
    
    if careers.isEmpty {
      steps.append("Complete a comprehensive interest assessment")
      steps.append("Explore different career fields through job shadowing")
    } else {
      steps.append("Research the top 3 recommended career paths in detail")
      steps.append("Connect with professionals in \(careers.first?.field ?? "your field of interest")")
      steps.append("Consider relevant coursework or certifications")
    }
    
    return steps
  }
  
  // MARK: - Resource Integration
  
  /// Get career-specific resources from ResourceService
  func getCareerResources(for career: Career) async -> [Resource] {
    let resourceService = ResourceService.shared
    
    do {
      // Get all resources
      let allResources = try await resourceService.fetchAllResources()
      
      // Filter resources relevant to this career
      return allResources.filter { resource in
        // Check if resource tags match career field or skills
        let careerKeywords = [career.field.lowercased(), career.title.lowercased()] +
                           career.skills.map { $0.lowercased() }
        
        return resource.tags.contains { tag in
          careerKeywords.contains { $0.contains(tag.lowercased()) }
        } || resource.title.lowercased().contains(career.field.lowercased())
      }.prefix(5).map { $0 }
    } catch {
      print("Failed to fetch career resources: \(error)")
      return []
    }
  }
  
  /// Get recommended resources for a student based on their career interests
  func getRecommendedResources(for student: Student) async -> [Resource] {
    let resourceService = ResourceService.shared
    
    do {
      let allResources = try await resourceService.fetchAllResources()
      let careerRecommendations = try await getCareerRecommendations(for: student)
      
      // Get resources that match student's recommended career fields
      let relevantFields = Set(careerRecommendations.map { $0.field.lowercased() })
      let studentInterests = Set(student.interests.map { $0.name.lowercased() })
      
      return allResources.filter { resource in
        // Check if resource is relevant to recommended career fields
        let resourceKeywords = resource.tags.map { $0.lowercased() } +
                              [resource.title.lowercased()]
        
        return relevantFields.contains { field in
          resourceKeywords.contains { $0.contains(field) }
        } || studentInterests.contains { interest in
          resourceKeywords.contains { $0.contains(interest) }
        }
      }.prefix(8).map { $0 }
    } catch {
      print("Failed to fetch recommended resources: \(error)")
      return []
    }
  }
}

// MARK: - Supporting Models

struct CareerStatistics: Codable, Sendable {
  let totalCareers: Int
  let uniqueFields: Int
  let uniqueSkills: Int
  let averageSalary: Double
  let highGrowthCareers: Int
  let fieldDistribution: [String: Int]
}

struct CareerDiscoveryInsights: Codable, Sendable, Equatable {
  let totalCareersExplored: Int
  let personalizedRecommendations: Int
  let topInterestCategory: String
  let strongestCareerFields: [String]
  let emergingOpportunities: [Career]
  let skillGaps: [String]
  let nextSteps: [String]
  let generatedAt: Date
  
  init(totalCareersExplored: Int, personalizedRecommendations: Int, topInterestCategory: String, strongestCareerFields: [String], emergingOpportunities: [Career], skillGaps: [String], nextSteps: [String]) {
    self.totalCareersExplored = totalCareersExplored
    self.personalizedRecommendations = personalizedRecommendations
    self.topInterestCategory = topInterestCategory
    self.strongestCareerFields = strongestCareerFields
    self.emergingOpportunities = emergingOpportunities
    self.skillGaps = skillGaps
    self.nextSteps = nextSteps
    self.generatedAt = Date()
  }
}

struct CareerBookmark: Codable, Identifiable, @unchecked Sendable {
  @DocumentID var id: String?
  let careerTitle: String
  let careerField: String
  let bookmarkedAt: Date
}

struct CareerExploration: Codable, @unchecked Sendable {
  @DocumentID var id: String?
  let careerTitle: String
  let careerField: String
  let action: CareerExplorationAction
  let timestamp: Date
}

enum CareerExplorationAction: String, Codable, CaseIterable, Sendable {
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

