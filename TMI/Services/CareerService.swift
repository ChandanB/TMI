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

    private init() {}

    // MARK: - Static Career Catalog

    /// All available careers from the static catalog (32 careers across 8 categories)
    var allCareers: [Career] {
        CareerDatabase.allCareerPaths.map { careerFromPath($0) }
    }

    // MARK: - Career Conversion

    /// Convert a CareerPath to a Career for the existing API surface
    private func careerFromPath(_ path: CareerPath) -> Career {
        let salaryLower = Double(path.estimatedSalary?.min ?? 30000)
        let salaryUpper = Double(path.estimatedSalary?.max ?? 100000)

        // Map category string to a human-readable field name
        let field = fieldName(for: path.category)

        // Derive job outlook and growth rate from category
        let (jobOutlook, growthRate) = outlookAndGrowth(for: path.category)

        // Derive skills from requiredInterests and category
        let skills = deriveSkills(from: path)

        return Career(
            id: path.id.uuidString,
            title: path.title,
            field: field,
            description: path.description,
            skills: skills,
            education: path.educationLevel.rawValue,
            salaryRange: salaryLower...salaryUpper,
            jobOutlook: jobOutlook,
            growthRate: growthRate,
            relatedInterests: path.requiredInterests,
            tags: [path.category] + path.requiredInterests
        )
    }

    private func fieldName(for category: String) -> String {
        switch category {
        case "technology": return "Technology"
        case "health_wellness": return "Healthcare"
        case "business_entrepreneurship": return "Business"
        case "creative_arts": return "Arts"
        case "education": return "Education"
        case "social_services": return "Social Services"
        case "sports_athletics": return "Sports & Athletics"
        case "audio_media": return "Media"
        default: return category.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func outlookAndGrowth(for category: String) -> (String, Double) {
        switch category {
        case "technology":
            return ("Excellent long-term outlook with continuous innovation and strong demand.", 0.22)
        case "health_wellness":
            return ("Strong outlook due to aging demographics and expanding healthcare needs.", 0.16)
        case "business_entrepreneurship":
            return ("Stable with opportunities in emerging markets and digital commerce.", 0.10)
        case "creative_arts":
            return ("Evolving with digital transformation and new content platforms.", 0.08)
        case "education":
            return ("Stable with ongoing need for qualified educators.", 0.05)
        case "social_services":
            return ("Growing demand for social support and mental health services.", 0.12)
        case "sports_athletics":
            return ("Steady with opportunities in coaching, training, and sports analytics.", 0.07)
        case "audio_media":
            return ("Rapidly growing with the podcast and streaming content boom.", 0.18)
        default:
            return ("Outlook varies by specific role and location.", 0.08)
        }
    }

    private func deriveSkills(from path: CareerPath) -> [String] {
        var skills: [String] = []

        // Category-specific base skills
        switch path.category {
        case "technology":
            skills = ["Problem Solving", "Programming", "Critical Thinking", "Collaboration"]
        case "health_wellness":
            skills = ["Patient Care", "Communication", "Empathy", "Medical Knowledge"]
        case "business_entrepreneurship":
            skills = ["Strategic Planning", "Leadership", "Communication", "Analytics"]
        case "creative_arts":
            skills = ["Creativity", "Visual Communication", "Attention to Detail", "Design Thinking"]
        case "education":
            skills = ["Communication", "Patience", "Curriculum Development", "Adaptability"]
        case "social_services":
            skills = ["Empathy", "Active Listening", "Case Management", "Advocacy"]
        case "sports_athletics":
            skills = ["Physical Fitness", "Teamwork", "Coaching", "Performance Analysis"]
        case "audio_media":
            skills = ["Storytelling", "Audio Production", "Content Creation", "Audience Engagement"]
        default:
            skills = ["Communication", "Problem Solving", "Adaptability"]
        }

        // Title-specific additional skills
        let title = path.title.lowercased()
        if title.contains("engineer") || title.contains("developer") {
            skills.append(contentsOf: ["Software Development", "System Design"])
        }
        if title.contains("analyst") || title.contains("data") {
            skills.append(contentsOf: ["Data Analysis", "Statistical Reasoning"])
        }
        if title.contains("designer") {
            skills.append(contentsOf: ["Adobe Creative Suite", "UI/UX Design"])
        }
        if title.contains("counselor") || title.contains("therapist") {
            skills.append(contentsOf: ["Counseling Techniques", "Mental Health Support"])
        }

        return skills
    }

    // MARK: - Career Search

    /// Search careers by query string — synchronous, filters static catalog
    func searchCareers(query: String) -> [Career] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allCareers
        }
        let lowercaseQuery = query.lowercased()
        return allCareers.filter { career in
            career.title.lowercased().contains(lowercaseQuery) ||
            career.description.lowercased().contains(lowercaseQuery) ||
            career.field.lowercased().contains(lowercaseQuery) ||
            career.skills.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }

    /// Fetch careers by field/category — synchronous
    func fetchCareers(byField field: String) -> [Career] {
        allCareers.filter { $0.field.lowercased() == field.lowercased() }
    }

    /// Fetch careers by skills — synchronous
    func fetchCareers(bySkills skills: [String]) -> [Career] {
        allCareers.filter { career in
            !Set(skills).isDisjoint(with: Set(career.skills))
        }
    }

    /// Fetch careers within salary range — synchronous
    func fetchCareers(salaryRange: ClosedRange<Double>) -> [Career] {
        allCareers.filter { $0.salaryRange.overlaps(salaryRange) }
    }

    /// Get trending/featured careers — synchronous, sorted by growth rate
    func fetchTrendingCareers() -> [Career] {
        Array(allCareers.sorted { $0.growthRate > $1.growthRate }.prefix(5))
    }

    // MARK: - Career Recommendations

    /// Get personalized career recommendations based on student's interest clusters
    /// Uses CareerMatchingService for interest-cluster-to-career matching
    func getCareerRecommendations(for student: Student) async throws -> [Career] {
        let interests = await fetchStudentInterests(student)
        let clusters = buildInterestClusters(from: interests)

        if clusters.isEmpty {
            // Return top trending careers when no interests are available
            return fetchTrendingCareers()
        }

        let matches = CareerMatchingService.shared.matchCareers(from: clusters, dreamJob: nil)
        return matches.map { careerFromPath($0.career) }
    }

    /// Get career recommendations from pre-built interest clusters (for survey results)
    func getCareerRecommendations(from clusters: [InterestCluster], dreamJob: String? = nil) -> [Career] {
        let matches = CareerMatchingService.shared.matchCareers(from: clusters, dreamJob: dreamJob)
        return matches.map { careerFromPath($0.career) }
    }

    // MARK: - Related Careers

    /// Get related careers based on field and skills — synchronous
    func getRelatedCareers(to career: Career, limit: Int = 5) -> [Career] {
        var scoredCareers: [(career: Career, score: Double)] = []

        for other in allCareers {
            guard other.title != career.title else { continue }

            var score = 0.0

            if other.field == career.field {
                score += 0.5
            }

            let sharedSkills = Set(career.skills).intersection(Set(other.skills))
            score += Double(sharedSkills.count) * 0.1

            if career.salaryRange.overlaps(other.salaryRange) {
                score += 0.2
            }

            if score > 0 {
                scoredCareers.append((career: other, score: score))
            }
        }

        return Array(scoredCareers.sorted { $0.score > $1.score }.prefix(limit).map { $0.career })
    }

    // MARK: - Career Statistics

    /// Get statistics across the static career catalog — synchronous
    func getCareerStatistics() -> CareerStatistics {
        let careers = allCareers

        let totalCareers = careers.count
        let fields = Set(careers.map { $0.field })
        let allSkills = Set(careers.flatMap { $0.skills })

        let salaryMidpoints = careers.map { ($0.salaryRange.lowerBound + $0.salaryRange.upperBound) / 2 }
        let averageSalary = salaryMidpoints.isEmpty ? 0 : salaryMidpoints.reduce(0, +) / Double(salaryMidpoints.count)

        let highGrowthCareers = careers.filter { $0.growthRate > 0.1 }.count

        var fieldDistribution: [String: Int] = [:]
        for career in careers {
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

    // MARK: - Utility Methods

    /// Get all unique career fields — synchronous
    func getAllCareerFields() -> [String] {
        Array(Set(allCareers.map { $0.field })).sorted()
    }

    /// Get all unique skills across careers — synchronous
    func getAllSkills() -> [String] {
        Array(Set(allCareers.flatMap { $0.skills })).sorted()
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
        case "sports & athletics": return "figure.run"
        case "culinary": return "fork.knife"
        case "social services": return "hands.sparkles"
        default: return "star"
        }
    }

    // MARK: - Firebase: Bookmarks

    /// Save user's career bookmark
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

    // MARK: - Firebase: Saved Careers (from survey results)

    /// Save a career to a student's savedCareers subcollection
    func saveCareer(career: Career, for studentId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw CareerServiceError.userNotAuthenticated
        }

        let collection = firestore
            .collection(FirestoreCollection.users.rawValue)
            .document(currentUser.uid)
            .collection("students")
            .document(studentId)
            .collection("savedCareers")

        let docId = career.id ?? career.title
        try collection.document(docId).setData(from: career)
    }

    /// Fetch careers saved for a specific student
    func fetchSavedCareers(for studentId: String) async throws -> [Career] {
        guard let currentUser = Auth.auth().currentUser else {
            throw CareerServiceError.userNotAuthenticated
        }

        let collection = firestore
            .collection(FirestoreCollection.users.rawValue)
            .document(currentUser.uid)
            .collection("students")
            .document(studentId)
            .collection("savedCareers")

        let snapshot = try await collection.getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: Career.self)
        }
    }

    /// Remove a saved career from a student's savedCareers subcollection
    func removeSavedCareer(careerId: String, for studentId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw CareerServiceError.userNotAuthenticated
        }

        let document = firestore
            .collection(FirestoreCollection.users.rawValue)
            .document(currentUser.uid)
            .collection("students")
            .document(studentId)
            .collection("savedCareers")
            .document(careerId)

        try await document.delete()
    }

    // MARK: - Firebase: Exploration Tracking

    /// Track career exploration for analytics
    func trackCareerExploration(career: Career, action: CareerExplorationAction) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            return // Don't throw for analytics
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

    // MARK: - Resource Integration

    /// Get career-specific resources from ResourceService
    func getCareerResources(for career: Career) async -> [Resource] {
        let resourceService = ResourceService.shared

        do {
            let allResources = try await resourceService.fetchAllResources()
            let careerKeywords = [career.field.lowercased(), career.title.lowercased()] +
                                 career.skills.map { $0.lowercased() }
            return allResources.filter { resource in
                resource.tags.contains { tag in
                    careerKeywords.contains { $0.contains(tag.lowercased()) }
                } || resource.title.lowercased().contains(career.field.lowercased())
            }.prefix(5).map { $0 }
        } catch {
            print("[CareerService] Failed to fetch career resources: \(error)")
            return []
        }
    }

    /// Get recommended resources for a student based on their career interests
    func getRecommendedResources(for student: Student) async -> [Resource] {
        let resourceService = ResourceService.shared

        do {
            let allResources = try await resourceService.fetchAllResources()
            let careerRecommendations = try await getCareerRecommendations(for: student)
            let studentInterests = await fetchStudentInterests(student)
            let studentInterestNames = Set(studentInterests.map { $0.name.lowercased() })
            let relevantFields = Set(careerRecommendations.map { $0.field.lowercased() })

            return allResources.filter { resource in
                let resourceKeywords = resource.tags.map { $0.lowercased() } +
                                      [resource.title.lowercased()]

                return relevantFields.contains { field in
                    resourceKeywords.contains { $0.contains(field) }
                } || studentInterestNames.contains { interest in
                    resourceKeywords.contains { $0.contains(interest) }
                }
            }.prefix(8).map { $0 }
        } catch {
            print("[CareerService] Failed to fetch recommended resources: \(error)")
            return []
        }
    }

    // MARK: - Private Helpers

    private func fetchStudentInterests(_ student: Student) async -> [Interest] {
        guard let studentId = student.id else { return [] }
        let studentInterestService = StudentInterestService.shared
        let interestLibraryService = InterestLibraryService.shared

        do {
            let edges = try await studentInterestService.getStudentInterests(studentId: studentId)
            var interests: [Interest] = []
            for edge in edges {
                if let interest = try await interestLibraryService.fetchInterest(id: edge.interestId) {
                    interests.append(interest)
                }
            }
            return interests
        } catch {
            print("[CareerService] Failed to fetch interests for student: \(error)")
            return []
        }
    }

    /// Build InterestCluster array from student Interest objects for CareerMatchingService
    private func buildInterestClusters(from interests: [Interest]) -> [InterestCluster] {
        // Group interests by category and produce one cluster per category
        var categoryMap: [String: (interests: [Interest], totalScore: Int)] = [:]

        for interest in interests {
            let categoryKey = interest.category.first?.rawValue ?? "general"
            var entry = categoryMap[categoryKey, default: ([], 0)]
            entry.interests.append(interest)
            entry.totalScore += interest.popularityScore ?? 1
            categoryMap[categoryKey] = entry
        }

        return categoryMap.compactMap { (categoryKey, entry) -> InterestCluster? in
            // Map interest category to cluster name expected by CareerMatchingService
            let clusterName = interestCategoryToClusterName(categoryKey)
            guard !clusterName.isEmpty else { return nil }

            // Normalize weight to 0.0–1.0 based on average popularity score
            let averageScore = Double(entry.totalScore) / Double(entry.interests.count)
            let weight = min(averageScore / 10.0, 1.0)

            return InterestCluster(
                name: clusterName,
                displayName: categoryKey.replacingOccurrences(of: "_", with: " ").capitalized,
                weight: weight,
                relatedCareers: [],
                icon: "star",
                color: "#888888"
            )
        }
    }

    private func interestCategoryToClusterName(_ category: String) -> String {
        switch category.lowercased() {
        case "technology": return "technology"
        case "science & discovery", "mathematics": return "technology"
        case "arts & creativity", "photography", "making & building": return "creative_arts"
        case "sports & athletics": return "sports_athletics"
        case "music", "entertainment & media": return "audio_media"
        case "academics", "learning & education": return "education"
        case "leadership & service", "social causes", "social activities": return "social_services"
        case "health & wellness": return "health_wellness"
        case "outdoors & nature": return "health_wellness"
        case "communication", "languages & culture": return "social_services"
        default: return ""
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
