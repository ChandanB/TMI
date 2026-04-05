//
//  CareerMatchingService.swift
//  TMI
//
//  Service for matching student interests to career paths
//

import Foundation

@Observable
class CareerMatchingService {
    static let shared = CareerMatchingService()

    private init() {}

    /// Match student interests to career paths with detailed explanations
    func matchCareers(from clusters: [InterestCluster], dreamJob: String? = nil) -> [CareerMatchResult] {
        var matches: [CareerMatchResult] = []

        // Get all available career paths
        let allCareers = CareerDatabase.allCareerPaths

        // Calculate match score for each career path with detailed explanations
        for career in allCareers {
            // Build interest matches with contribution scores
            var interestMatches: [CareerMatchExplanation.InterestMatch] = []
            var totalInterestScore: Double = 0.0

            for requiredInterest in career.requiredInterests {
                if let cluster = clusters.first(where: { $0.name == requiredInterest }) {
                    // Interest level (1-5) converted to contribution (0-12 points each)
                    let contribution = Double(cluster.weight) * 12.0
                    totalInterestScore += contribution

                    interestMatches.append(
                        CareerMatchExplanation.InterestMatch(
                            interestName: cluster.displayName,
                            interestCategory: cluster.name,
                            studentLevel: max(1, min(5, Int((cluster.weight * 5).rounded()))),
                            weight: cluster.weight,
                            contribution: contribution,
                            isRequired: career.requiredInterests.contains(cluster.name)
                        )
                    )
                }
            }

            // Skip careers with no matching interests
            guard !interestMatches.isEmpty else { continue }

            // Calculate dream job alignment
            var dreamJobMatch: CareerMatchExplanation.DreamJobMatch?
            var dreamJobScore: Double = 0.0

            if let dream = dreamJob?.lowercased(), !dream.isEmpty {
                let similarity = calculateDreamJobSimilarity(dream: dream, careerTitle: career.title, careerDescription: career.description)
                dreamJobScore = similarity * CareerMatchExplanation.dreamJobWeight

                let matchedKeywords = extractMatchedKeywords(
                    dream: dream,
                    careerTitle: career.title,
                    careerDescription: career.description
                )
                dreamJobMatch = CareerMatchExplanation.DreamJobMatch(
                    similarity: similarity,
                    matchedKeywords: matchedKeywords,
                    contribution: dreamJobScore,
                    explanation: matchedKeywords.isEmpty
                        ? "General alignment with your stated dream job"
                        : "Matched keywords: \(matchedKeywords.joined(separator: ", "))"
                )
            }

            // Calculate education fit
            let educationScore = calculateEducationFit(educationLevel: career.educationLevel)
            let educationFit = CareerMatchExplanation.EducationFitScore(
                careerEducationLevel: career.educationLevel,
                isAccessible: career.educationLevel == .highSchool || career.educationLevel == .varies,
                pathwayDescription: educationDescription(for: career.educationLevel),
                estimatedYears: estimatedEducationYears(for: career.educationLevel)
            )

            // Calculate salary expectation fit
            var salaryScore: Double = 0.0
            var salaryFit: CareerMatchExplanation.SalaryFitScore?

            if let salary = career.estimatedSalary {
                salaryScore = CareerMatchExplanation.salaryWeight // Full points if salary data available
                let averageSalary = Double(salary.min + salary.max) / 2.0
                salaryFit = CareerMatchExplanation.SalaryFitScore(
                    range: salary,
                    averageSalary: averageSalary,
                    growthPotential: determineGrowthPotential(for: career.category),
                    explanation: industryOutlook(for: career.category)
                )
            }

            // Calculate total score (0-100)
            let totalScore = totalInterestScore + dreamJobScore + educationScore + salaryScore

            // Generate reasoning and recommendations
            let reasoning = generateReasoning(
                career: career,
                interestMatches: interestMatches,
                dreamJobMatch: dreamJobMatch,
                educationFit: educationFit,
                salaryFit: salaryFit
            )

            let recommendations = generateRecommendations(
                career: career,
                interestMatches: interestMatches,
                educationLevel: career.educationLevel
            )

            // Build explanation
            let explanation = CareerMatchExplanation(
                matchScore: totalScore,
                matchedInterests: interestMatches,
                dreamJobAlignment: dreamJobMatch,
                educationFit: educationFit,
                salaryExpectation: salaryFit,
                reasoning: reasoning,
                recommendations: recommendations
            )

            // Get matching interest names for backwards compatibility
            let matchingInterestNames = interestMatches.map { $0.interestName }

            // Suggest TMI modules based on career needs
            let suggestedModules = suggestTMIModules(for: career, interests: clusters)

            let match = CareerMatchResult(
                career: career,
                score: totalScore / 100.0, // Normalize to 0-1 for backwards compatibility
                matchingInterests: matchingInterestNames,
                suggestedTMIModules: suggestedModules,
                explanation: explanation
            )

            matches.append(match)
        }

        // Sort by score (highest first)
        return matches.sorted { $0.score > $1.score }
    }

    // MARK: - Explanation Helpers

    /// Calculate dream job similarity using keyword matching
    private func calculateDreamJobSimilarity(dream: String, careerTitle: String, careerDescription: String) -> Double {
        let dreamWords = Set(dream.lowercased().split(separator: " ").map(String.init))
        let titleWords = Set(careerTitle.lowercased().split(separator: " ").map(String.init))
        let descriptionWords = Set(careerDescription.lowercased().split(separator: " ").map(String.init))

        // Direct title match gets highest similarity
        if careerTitle.lowercased().contains(dream) || dream.contains(careerTitle.lowercased()) {
            return 1.0
        }

        // Calculate Jaccard similarity with words
        let titleIntersection = dreamWords.intersection(titleWords)
        let descriptionIntersection = dreamWords.intersection(descriptionWords)

        // Weight title matches higher than description matches
        let titleSimilarity = titleIntersection.count > 0 ? 0.7 : 0.0
        let descriptionSimilarity = Double(descriptionIntersection.count) / max(Double(dreamWords.count), 1.0) * 0.3

        return min(titleSimilarity + descriptionSimilarity, 1.0)
    }

    /// Extract keywords that matched between dream job and career
    private func extractMatchedKeywords(dream: String, careerTitle: String, careerDescription: String) -> [String] {
        let dreamWords = dream.lowercased().split(separator: " ").map(String.init)
        let careerText = (careerTitle + " " + careerDescription).lowercased()

        return dreamWords.filter { careerText.contains($0) && $0.count > 3 } // Filter out short words
    }

    /// Calculate education fit score
    private func calculateEducationFit(educationLevel: EducationLevel) -> Double {
        // More accessible education levels get higher scores
        switch educationLevel {
        case .highSchool:
            return CareerMatchExplanation.educationWeight
        case .certification, .vocational:
            return CareerMatchExplanation.educationWeight * 0.9
        case .someCollege, .bachelors:
            return CareerMatchExplanation.educationWeight * 0.8
        case .masters:
            return CareerMatchExplanation.educationWeight * 0.6
        case .doctorate:
            return CareerMatchExplanation.educationWeight * 0.5
        case .varies:
            return CareerMatchExplanation.educationWeight * 0.95
        }
    }

    /// Generate education description
    private func educationDescription(for level: EducationLevel) -> String {
        switch level {
        case .highSchool:
            return "High school diploma or equivalent required"
        case .certification:
            return "Professional certification required, typically 6-12 months of training"
        case .vocational:
            return "Vocational training or technical school, typically 1-2 years"
        case .someCollege:
            return "Some college coursework helpful, degree not always required"
        case .bachelors:
            return "Bachelor's degree required, typically 4 years of college"
        case .masters:
            return "Master's degree required, typically 2 additional years after bachelor's"
        case .doctorate:
            return "Doctoral degree required, typically 4-7 years after bachelor's"
        case .varies:
            return "Education requirements vary based on specialization and employer"
        }
    }

    /// Determine growth potential for a career category
    private func determineGrowthPotential(for category: String) -> String {
        CareerCategory(rawValue: category)?.growthPotential ?? "Varies by specialization"
    }

    /// Get industry outlook for a career category
    private func industryOutlook(for category: String) -> String {
        CareerCategory(rawValue: category)?.industryOutlook ?? "Outlook varies by specific role and location"
    }

    /// Generate human-readable reasoning
    private func generateReasoning(
        career: CareerPath,
        interestMatches: [CareerMatchExplanation.InterestMatch],
        dreamJobMatch: CareerMatchExplanation.DreamJobMatch?,
        educationFit: CareerMatchExplanation.EducationFitScore,
        salaryFit: CareerMatchExplanation.SalaryFitScore?
    ) -> String {
        var parts: [String] = []

        // Interest alignment
        if !interestMatches.isEmpty {
            let topInterests = interestMatches.prefix(3).map { $0.interestName }
            if topInterests.count == 1 {
                parts.append("Your strong interest in \(topInterests[0]) aligns well with this career")
            } else {
                let interestList = topInterests.dropLast().joined(separator: ", ") + ", and " + topInterests.last!
                parts.append("Your interests in \(interestList) align well with this career")
            }
        }

        // Dream job alignment
        if let dreamMatch = dreamJobMatch, dreamMatch.similarity > 0.7 {
            parts.append("This closely matches your dream job aspirations")
        }

        // Education accessibility
        if educationFit.careerEducationLevel == .highSchool || educationFit.careerEducationLevel == .varies {
            parts.append("This career has accessible entry requirements")
        }

        // Growth potential
        if let salary = salaryFit {
            parts.append(salary.growthPotential)
        }

        return parts.joined(separator: ". ") + "."
    }

    /// Generate actionable recommendations
    private func generateRecommendations(
        career: CareerPath,
        interestMatches: [CareerMatchExplanation.InterestMatch],
        educationLevel: EducationLevel
    ) -> [String] {
        var recommendations: [String] = []

        // Exploration recommendation
        recommendations.append("Explore beginner-level activities in \(career.title) through the suggested TMI modules")

        // Interest development
        if let topInterest = interestMatches.first {
            recommendations.append("Continue developing your skills in \(topInterest.interestName)")
        }

        // Education pathway
        switch educationLevel {
        case .highSchool, .varies:
            recommendations.append("Research entry-level opportunities and internships in this field")
        case .certification, .vocational:
            recommendations.append("Look into certification programs and vocational training opportunities")
        case .bachelors, .someCollege:
            recommendations.append("Consider colleges with strong programs in \(career.category.replacingOccurrences(of: "_", with: " "))")
        case .masters, .doctorate:
            recommendations.append("This career requires advanced education - start by building a strong academic foundation")
        }

        // Networking recommendation
        recommendations.append("Connect with professionals in \(career.title) to learn about day-to-day experiences")

        return recommendations
    }

    /// Suggest TMI modules based on career path and interests
    private func suggestTMIModules(for career: CareerPath, interests: [InterestCluster]) -> [TMIPlanModel] {
        CareerCategory(rawValue: career.category)?.suggestedTMIModules
            ?? [.chaseYourSpace, .acknowledgeInterests]
    }

    private func estimatedEducationYears(for level: EducationLevel) -> Int? {
        switch level {
        case .highSchool: return 0
        case .someCollege: return 1
        case .certification: return 1
        case .vocational: return 2
        case .bachelors: return 4
        case .masters: return 6
        case .doctorate: return 10
        case .varies: return nil
        }
    }
}

// MARK: - Career Database

struct CareerDatabase {
    static let allCareerPaths: [CareerPath] = CareerCatalog.allCareers
}
