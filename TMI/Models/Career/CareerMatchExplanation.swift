//
//  CareerMatchExplanation.swift
//  TMI
//
//  Explainable career matching with transparent scoring
//

import Foundation

/// Detailed explanation of why a career matches a student's profile
struct CareerMatchExplanation: Codable, Sendable {
    let matchScore: Double // 0-100 normalized score
    let matchedInterests: [InterestMatch]
    let dreamJobAlignment: DreamJobMatch?
    let educationFit: EducationFitScore
    let salaryExpectation: SalaryFitScore?
    let reasoning: String // Human-readable summary
    let recommendations: [String] // Action items for student

    /// Breakdown of how an interest contributed to the match
    struct InterestMatch: Codable, Identifiable, Sendable {
        let id: UUID
        let interestName: String
        let interestCategory: String
        let studentLevel: Int // 1-5 affinity level
        let weight: Double // 0-1 importance weight
        let contribution: Double // Points added to total score
        let isRequired: Bool // Whether this interest is required for the career

        init(
            id: UUID = UUID(),
            interestName: String,
            interestCategory: String,
            studentLevel: Int,
            weight: Double,
            contribution: Double,
            isRequired: Bool = false
        ) {
            self.id = id
            self.interestName = interestName
            self.interestCategory = interestCategory
            self.studentLevel = studentLevel
            self.weight = weight
            self.contribution = contribution
            self.isRequired = isRequired
        }
    }

    /// Dream job alignment analysis
    struct DreamJobMatch: Codable, Sendable {
        let similarity: Double // 0-1 semantic similarity
        let matchedKeywords: [String]
        let contribution: Double // Points added to total score
        let explanation: String

        var isStrongMatch: Bool {
            similarity >= 0.7
        }
    }

    /// Education level fit analysis
    struct EducationFitScore: Codable, Sendable {
        let careerEducationLevel: EducationLevel
        let isAccessible: Bool // Can student realistically pursue this
        let pathwayDescription: String
        let estimatedYears: Int? // Years of education needed

        init(
            careerEducationLevel: EducationLevel,
            isAccessible: Bool = true,
            pathwayDescription: String,
            estimatedYears: Int? = nil
        ) {
            self.careerEducationLevel = careerEducationLevel
            self.isAccessible = isAccessible
            self.pathwayDescription = pathwayDescription
            self.estimatedYears = estimatedYears
        }
    }

    /// Salary expectations fit
    struct SalaryFitScore: Codable, Sendable {
        let range: SalaryRange
        let averageSalary: Double
        let growthPotential: String // "High", "Medium", "Low"
        let explanation: String

        var formattedAverage: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: averageSalary)) ?? "$\(Int(averageSalary))"
        }
    }

    // MARK: - Scoring Breakdown

    /// Total possible points by category
    static let interestWeight: Double = 60.0
    static let dreamJobWeight: Double = 20.0
    static let educationWeight: Double = 10.0
    static let salaryWeight: Double = 10.0

    /// Calculate overall match percentage
    var matchPercentage: Int {
        Int(matchScore.rounded())
    }

    /// Get match quality description
    var matchQuality: MatchQuality {
        switch matchScore {
        case 80...100:
            return .excellent
        case 60..<80:
            return .good
        case 40..<60:
            return .fair
        case 20..<40:
            return .weak
        default:
            return .poor
        }
    }

    enum MatchQuality: String, Codable {
        case excellent = "Excellent Match"
        case good = "Good Match"
        case fair = "Fair Match"
        case weak = "Weak Match"
        case poor = "Poor Match"

        var color: String {
            switch self {
            case .excellent: return "#27AE60"
            case .good: return "#2ECC71"
            case .fair: return "#F39C12"
            case .weak: return "#E67E22"
            case .poor: return "#E74C3C"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "star.fill"
            case .good: return "star.leadinghalf.filled"
            case .fair: return "star"
            case .weak: return "star"
            case .poor: return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Initialization

    init(
        matchScore: Double,
        matchedInterests: [InterestMatch],
        dreamJobAlignment: DreamJobMatch? = nil,
        educationFit: EducationFitScore,
        salaryExpectation: SalaryFitScore? = nil,
        reasoning: String,
        recommendations: [String] = []
    ) {
        self.matchScore = matchScore
        self.matchedInterests = matchedInterests
        self.dreamJobAlignment = dreamJobAlignment
        self.educationFit = educationFit
        self.salaryExpectation = salaryExpectation
        self.reasoning = reasoning
        self.recommendations = recommendations
    }

    // MARK: - Scoring Helpers

    /// Calculate interest contribution score
    static func calculateInterestScore(
        matchedInterests: [InterestMatch],
        totalRequired: Int
    ) -> Double {
        guard totalRequired > 0 else { return 0 }

        // Base score from coverage (how many required interests matched)
        let coverage = Double(matchedInterests.count) / Double(totalRequired)

        // Average weight of matched interests
        let avgWeight = matchedInterests.isEmpty ? 0 :
            matchedInterests.map { $0.weight }.reduce(0, +) / Double(matchedInterests.count)

        // Combined score with 60% weight on coverage, 40% on interest strength
        let combinedScore = (coverage * 0.6) + (avgWeight * 0.4)

        return combinedScore * interestWeight
    }

    /// Generate human-readable reasoning
    static func generateReasoning(
        career: CareerPath,
        interestMatches: [InterestMatch],
        dreamMatch: DreamJobMatch?
    ) -> String {
        var parts: [String] = []

        // Interest alignment
        if !interestMatches.isEmpty {
            let topInterests = interestMatches
                .sorted { $0.contribution > $1.contribution }
                .prefix(3)
                .map { $0.interestName }

            if topInterests.count == 1 {
                parts.append("Your interest in \(topInterests[0]) aligns well with this career")
            } else {
                let lastInterest = topInterests.last!
                let otherInterests = topInterests.dropLast().joined(separator: ", ")
                parts.append("Your interests in \(otherInterests), and \(lastInterest) align well with this career")
            }
        }

        // Dream job alignment
        if let dream = dreamMatch, dream.isStrongMatch {
            parts.append("This closely matches your dream job aspirations")
        }

        // Education accessibility
        if career.educationLevel == .varies || career.educationLevel == .certification {
            parts.append("Multiple education pathways are available")
        }

        // Salary potential
        if let salary = career.estimatedSalary, salary.max > 80000 {
            parts.append("Strong earning potential in this field")
        }

        return parts.joined(separator: ". ") + "."
    }

    /// Generate actionable recommendations
    static func generateRecommendations(
        career: CareerPath,
        interestMatches: [InterestMatch],
        educationLevel: EducationLevel
    ) -> [String] {
        var recommendations: [String] = []

        // Interest development
        if interestMatches.count < career.requiredInterests.count {
            let missingCount = career.requiredInterests.count - interestMatches.count
            recommendations.append("Explore \(missingCount) additional interest area(s) to strengthen your fit")
        }

        // Strong matches
        if !interestMatches.isEmpty {
            let strongestInterest = interestMatches.max { $0.contribution < $1.contribution }!
            recommendations.append("Build deeper skills in \(strongestInterest.interestName) through coursework or projects")
        }

        // Education pathway
        switch educationLevel {
        case .certification, .vocational:
            recommendations.append("Research certification programs and vocational schools in your area")
        case .associates:
            recommendations.append("Explore 2-year associate degree programs at community colleges")
        case .bachelors:
            recommendations.append("Plan for a 4-year bachelor's degree program")
        case .masters, .doctorate:
            recommendations.append("Consider graduate school pathways after completing undergraduate education")
        case .varies:
            recommendations.append("Research different education pathways - several options are available")
        }

        // Career exploration
        recommendations.append("Shadow a professional or find a mentor in this field")
        recommendations.append("Look for internships, volunteer opportunities, or entry-level positions")

        return recommendations
    }
}

// MARK: - Enhanced Career Match Result

extension CareerMatchResult {
    /// Create result with explanation
    static func withExplanation(
        career: CareerPath,
        explanation: CareerMatchExplanation,
        suggestedTMIModules: [TMIPlanModel]
    ) -> CareerMatchResult {
        let matchingInterestNames = explanation.matchedInterests.map { $0.interestName }

        return CareerMatchResult(
            career: career,
            score: explanation.matchScore / 100.0, // Normalize to 0-1
            matchingInterests: matchingInterestNames,
            suggestedTMIModules: suggestedTMIModules,
            explanation: explanation
        )
    }
}

// MARK: - Convenience Factory

extension CareerMatchExplanation {
    /// Create a basic explanation from simple matching data
    static func basic(
        career: CareerPath,
        matchedInterests: [String],
        interestClusters: [InterestCluster],
        totalScore: Double
    ) -> CareerMatchExplanation {
        // Build interest matches
        let interestMatches: [InterestMatch] = matchedInterests.compactMap { interestName in
            guard let cluster = interestClusters.first(where: { $0.displayName == interestName || $0.name == interestName }) else {
                return nil
            }

            return InterestMatch(
                interestName: cluster.displayName,
                interestCategory: cluster.name,
                studentLevel: Int(cluster.weight * 5), // Convert 0-1 weight to 1-5 level
                weight: cluster.weight,
                contribution: cluster.weight * interestWeight / Double(career.requiredInterests.count),
                isRequired: career.requiredInterests.contains(cluster.name)
            )
        }

        // Education fit
        let educationFit = EducationFitScore(
            careerEducationLevel: career.educationLevel,
            isAccessible: true,
            pathwayDescription: getEducationPathwayDescription(career.educationLevel),
            estimatedYears: getEstimatedYears(career.educationLevel)
        )

        // Salary fit
        let salaryFit: SalaryFitScore? = career.estimatedSalary.map { range in
            SalaryFitScore(
                range: range,
                averageSalary: Double(range.min + range.max) / 2.0,
                growthPotential: determineGrowthPotential(career.category),
                explanation: "Average salary in this field"
            )
        }

        // Generate reasoning
        let reasoning = generateReasoning(
            career: career,
            interestMatches: interestMatches,
            dreamMatch: nil
        )

        // Generate recommendations
        let recommendations = generateRecommendations(
            career: career,
            interestMatches: interestMatches,
            educationLevel: career.educationLevel
        )

        return CareerMatchExplanation(
            matchScore: totalScore,
            matchedInterests: interestMatches,
            dreamJobAlignment: nil,
            educationFit: educationFit,
            salaryExpectation: salaryFit,
            reasoning: reasoning,
            recommendations: recommendations
        )
    }

    private static func getEducationPathwayDescription(_ level: EducationLevel) -> String {
        switch level {
        case .highSchool:
            return "High school diploma or equivalent required"
        case .someCollege:
            return "Some college coursework beneficial"
        case .certification:
            return "Professional certification program required"
        case .vocational:
            return "Vocational or trade school training required"
        case .associates:
            return "2-year associate degree required"
        case .bachelors:
            return "4-year bachelor's degree required"
        case .masters:
            return "Master's degree required (additional 2 years)"
        case .doctorate:
            return "Doctorate degree required (additional 4-6 years)"
        case .varies:
            return "Multiple education pathways available"
        }
    }

    private static func getEstimatedYears(_ level: EducationLevel) -> Int? {
        switch level {
        case .highSchool: return 0
        case .someCollege: return 1
        case .certification: return 1
        case .vocational: return 2
        case .associates: return 2
        case .bachelors: return 4
        case .masters: return 6
        case .doctorate: return 10
        case .varies: return nil
        }
    }

    private static func determineGrowthPotential(_ category: String) -> String {
        switch category {
        case "technology", "health_wellness", "business_entrepreneurship":
            return "High"
        case "education", "social_services", "audio_media":
            return "Medium"
        default:
            return "Medium"
        }
    }
}
