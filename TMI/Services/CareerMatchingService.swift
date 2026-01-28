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
                            weight: cluster.weight,
                            contribution: contribution
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

                dreamJobMatch = CareerMatchExplanation.DreamJobMatch(
                    dreamJob: dreamJob!,
                    careerTitle: career.title,
                    similarity: similarity,
                    matchedKeywords: extractMatchedKeywords(dream: dream, careerTitle: career.title, careerDescription: career.description)
                )
            }

            // Calculate education fit
            let educationScore = calculateEducationFit(educationLevel: career.educationLevel)
            let educationFit = CareerMatchExplanation.EducationFitScore(
                requiredLevel: career.educationLevel,
                description: educationDescription(for: career.educationLevel),
                pathwaySuggestions: career.pathway.beginnerGoals.map { $0.title }
            )

            // Calculate salary expectation fit
            var salaryScore: Double = 0.0
            var salaryFit: CareerMatchExplanation.SalaryFitScore?

            if let salary = career.estimatedSalary {
                salaryScore = CareerMatchExplanation.salaryWeight // Full points if salary data available
                salaryFit = CareerMatchExplanation.SalaryFitScore(
                    range: salary,
                    growthPotential: determineGrowthPotential(for: career.category),
                    industryOutlook: industryOutlook(for: career.category)
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
        switch category {
        case "technology":
            return "High - technology careers are growing rapidly with strong demand"
        case "health_wellness":
            return "High - healthcare is an expanding field with aging population"
        case "business_entrepreneurship":
            return "Moderate to High - entrepreneurship offers unlimited growth potential"
        case "creative_arts":
            return "Moderate - creative fields can be competitive but rewarding"
        case "education":
            return "Stable - consistent demand for educators"
        case "social_services":
            return "Moderate - growing awareness of mental health and social needs"
        case "sports_athletics":
            return "Moderate - competitive field with opportunities in various sports industries"
        case "audio_media":
            return "High - digital media and content creation is booming"
        default:
            return "Varies by specialization"
        }
    }

    /// Get industry outlook for a career category
    private func industryOutlook(for category: String) -> String {
        switch category {
        case "technology":
            return "Excellent long-term outlook with continuous innovation"
        case "health_wellness":
            return "Strong outlook due to aging demographics and health focus"
        case "business_entrepreneurship":
            return "Stable with opportunities in emerging markets"
        case "creative_arts":
            return "Evolving with digital transformation and new platforms"
        case "education":
            return "Stable with ongoing need for qualified educators"
        case "social_services":
            return "Growing demand for social support services"
        case "sports_athletics":
            return "Steady with opportunities in coaching, training, and analytics"
        case "audio_media":
            return "Rapidly growing with podcast and streaming boom"
        default:
            return "Outlook varies by specific role and location"
        }
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
        if educationFit.requiredLevel == .highSchool || educationFit.requiredLevel == .varies {
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
        var modules: [TMIPlanModel] = []

        // Everyone starts with Chase Your Space
        modules.append(.chaseYourSpace)

        // Add Acknowledge Interests for career exploration
        modules.append(.acknowledgeInterests)

        // Add Align Your Mind for careers requiring focus/discipline
        if career.category == "technology" || career.category == "creative_arts" {
            modules.append(.alignYourMind)
        }

        // Add Direct & Correct for leadership careers
        if career.category == "business_entrepreneurship" || career.category == "education" {
            modules.append(.directAndCorrect)
        }

        // Add Bully to Boss for entrepreneurship
        if career.category == "business_entrepreneurship" {
            modules.append(.bullyToBoss)
        }

        // Add Meek to Protector for helping professions
        if career.category == "social_services" || career.category == "health_wellness" {
            modules.append(.meekToProtector)
        }

        return modules
    }
}

// MARK: - Career Database

struct CareerDatabase {
    static let allCareerPaths: [CareerPath] = [
        // Audio & Media Careers
        .podcaster,
        .radioHost,
        .audioEngineer,
        .contentCreator,

        // Health & Wellness Careers
        .fitnessTrainer,
        .nutritionist,
        .physicalTherapist,
        .nurse,

        // Technology Careers
        .gameDeveloper,
        .appDesigner,
        .softwareEngineer,
        .dataAnalyst,

        // Creative Arts Careers
        .graphicDesigner,
        .photographer,
        .filmDirector,
        .animator,

        // Sports & Athletics Careers
        .coach,
        .athleticTrainer,
        .sportsAnalyst,
        .physicalEducationTeacher,

        // Business & Entrepreneurship Careers
        .entrepreneur,
        .marketingSpecialist,
        .financialAdvisor,
        .businessAnalyst,

        // Education Careers
        .teacher,
        .tutor,
        .educationSpecialist,
        .schoolCounselor,

        // Social Services Careers
        .socialWorker,
        .counselor,
        .communityOrganizer,
        .nonprofitDirector
    ]
}

// MARK: - Career Path Definitions

extension CareerPath {
    // MARK: - Audio & Media

    static let podcaster = CareerPath(
        title: "Podcaster",
        category: "audio_media",
        description: "Create and host audio shows on topics you're passionate about. Build an audience and share stories.",
        pathway: CareerPathways.podcasterPathway,
        requiredInterests: ["audio_media"],
        estimatedSalary: SalaryRange(min: 30000, max: 100000),
        educationLevel: .varies,
        icon: "mic.fill",
        color: "#9B59B6"
    )

    static let radioHost = CareerPath(
        title: "Radio Host",
        category: "audio_media",
        description: "Broadcast live shows, interview guests, and connect with listeners through radio.",
        pathway: CareerPathways.radioHostPathway,
        requiredInterests: ["audio_media"],
        estimatedSalary: SalaryRange(min: 35000, max: 85000),
        educationLevel: .bachelors,
        icon: "antenna.radiowaves.left.and.right",
        color: "#9B59B6"
    )

    static let audioEngineer = CareerPath(
        title: "Audio Engineer",
        category: "audio_media",
        description: "Mix and master sound for music, podcasts, films, and live events.",
        pathway: CareerPathways.audioEngineerPathway,
        requiredInterests: ["audio_media", "technology"],
        estimatedSalary: SalaryRange(min: 45000, max: 95000),
        educationLevel: .vocational,
        icon: "waveform",
        color: "#9B59B6"
    )

    static let contentCreator = CareerPath(
        title: "Content Creator",
        category: "audio_media",
        description: "Create videos, podcasts, and digital content for online platforms.",
        pathway: CareerPathways.contentCreatorPathway,
        requiredInterests: ["audio_media", "creative_arts"],
        estimatedSalary: SalaryRange(min: 25000, max: 150000),
        educationLevel: .varies,
        icon: "video.fill",
        color: "#9B59B6"
    )

    // MARK: - Technology

    static let gameDeveloper = CareerPath(
        title: "Game Developer",
        category: "technology",
        description: "Design and build video games, from mobile apps to console experiences.",
        pathway: CareerPathways.gameDeveloperPathway,
        requiredInterests: ["technology"],
        estimatedSalary: SalaryRange(min: 55000, max: 120000),
        educationLevel: .bachelors,
        icon: "gamecontroller.fill",
        color: "#3498DB"
    )

    static let appDesigner = CareerPath(
        title: "App Designer",
        category: "technology",
        description: "Create user interfaces and experiences for mobile and web applications.",
        pathway: CareerPathways.appDesignerPathway,
        requiredInterests: ["technology", "creative_arts"],
        estimatedSalary: SalaryRange(min: 60000, max: 130000),
        educationLevel: .bachelors,
        icon: "app.fill",
        color: "#3498DB"
    )

    static let softwareEngineer = CareerPath(
        title: "Software Engineer",
        category: "technology",
        description: "Build software systems and applications that solve real-world problems.",
        pathway: CareerPathways.softwareEngineerPathway,
        requiredInterests: ["technology"],
        estimatedSalary: SalaryRange(min: 70000, max: 180000),
        educationLevel: .bachelors,
        icon: "chevron.left.forwardslash.chevron.right",
        color: "#3498DB"
    )

    static let dataAnalyst = CareerPath(
        title: "Data Analyst",
        category: "technology",
        description: "Analyze data to help organizations make better decisions.",
        pathway: CareerPathways.dataAnalystPathway,
        requiredInterests: ["technology"],
        estimatedSalary: SalaryRange(min: 55000, max: 110000),
        educationLevel: .bachelors,
        icon: "chart.bar.fill",
        color: "#3498DB"
    )

    // MARK: - Creative Arts

    static let graphicDesigner = CareerPath(
        title: "Graphic Designer",
        category: "creative_arts",
        description: "Create visual content for brands, websites, and marketing materials.",
        pathway: CareerPathways.graphicDesignerPathway,
        requiredInterests: ["creative_arts"],
        estimatedSalary: SalaryRange(min: 40000, max: 90000),
        educationLevel: .bachelors,
        icon: "paintpalette.fill",
        color: "#E74C3C"
    )

    static let photographer = CareerPath(
        title: "Photographer",
        category: "creative_arts",
        description: "Capture moments and tell stories through photography.",
        pathway: CareerPathways.photographerPathway,
        requiredInterests: ["creative_arts"],
        estimatedSalary: SalaryRange(min: 30000, max: 85000),
        educationLevel: .varies,
        icon: "camera.fill",
        color: "#E74C3C"
    )

    static let filmDirector = CareerPath(
        title: "Film Director",
        category: "creative_arts",
        description: "Direct films, commercials, and video productions.",
        pathway: CareerPathways.filmDirectorPathway,
        requiredInterests: ["creative_arts", "audio_media"],
        estimatedSalary: SalaryRange(min: 45000, max: 150000),
        educationLevel: .bachelors,
        icon: "film.fill",
        color: "#E74C3C"
    )

    static let animator = CareerPath(
        title: "Animator",
        category: "creative_arts",
        description: "Bring characters and stories to life through animation.",
        pathway: CareerPathways.animatorPathway,
        requiredInterests: ["creative_arts", "technology"],
        estimatedSalary: SalaryRange(min: 50000, max: 110000),
        educationLevel: .bachelors,
        icon: "sparkles",
        color: "#E74C3C"
    )

    // MARK: - Health & Wellness

    static let fitnessTrainer = CareerPath(
        title: "Fitness Trainer",
        category: "health_wellness",
        description: "Help people achieve their health and fitness goals.",
        pathway: CareerPathways.fitnessTrainerPathway,
        requiredInterests: ["health_wellness", "sports_athletics"],
        estimatedSalary: SalaryRange(min: 35000, max: 75000),
        educationLevel: .certification,
        icon: "figure.strengthtraining.traditional",
        color: "#16A085"
    )

    static let nutritionist = CareerPath(
        title: "Nutritionist",
        category: "health_wellness",
        description: "Guide people toward healthier eating and lifestyle choices.",
        pathway: CareerPathways.nutritionistPathway,
        requiredInterests: ["health_wellness"],
        estimatedSalary: SalaryRange(min: 45000, max: 85000),
        educationLevel: .bachelors,
        icon: "leaf.fill",
        color: "#16A085"
    )

    static let physicalTherapist = CareerPath(
        title: "Physical Therapist",
        category: "health_wellness",
        description: "Help patients recover from injuries and improve mobility.",
        pathway: CareerPathways.physicalTherapistPathway,
        requiredInterests: ["health_wellness"],
        estimatedSalary: SalaryRange(min: 65000, max: 105000),
        educationLevel: .doctorate,
        icon: "figure.walk",
        color: "#16A085"
    )

    static let nurse = CareerPath(
        title: "Nurse",
        category: "health_wellness",
        description: "Provide care and support to patients in hospitals and clinics.",
        pathway: CareerPathways.nursePathway,
        requiredInterests: ["health_wellness", "social_services"],
        estimatedSalary: SalaryRange(min: 55000, max: 95000),
        educationLevel: .bachelors,
        icon: "cross.case.fill",
        color: "#16A085"
    )

    // MARK: - Sports & Athletics

    static let coach = CareerPath(
        title: "Coach",
        category: "sports_athletics",
        description: "Train athletes and teams to reach their full potential.",
        pathway: CareerPathways.coachPathway,
        requiredInterests: ["sports_athletics"],
        estimatedSalary: SalaryRange(min: 35000, max: 90000),
        educationLevel: .bachelors,
        icon: "sportscourt.fill",
        color: "#F39C12"
    )

    static let athleticTrainer = CareerPath(
        title: "Athletic Trainer",
        category: "sports_athletics",
        description: "Prevent and treat sports injuries for athletes.",
        pathway: CareerPathways.athleticTrainerPathway,
        requiredInterests: ["sports_athletics", "health_wellness"],
        estimatedSalary: SalaryRange(min: 45000, max: 75000),
        educationLevel: .masters,
        icon: "bandage.fill",
        color: "#F39C12"
    )

    static let sportsAnalyst = CareerPath(
        title: "Sports Analyst",
        category: "sports_athletics",
        description: "Analyze sports data and provide insights for teams and media.",
        pathway: CareerPathways.sportsAnalystPathway,
        requiredInterests: ["sports_athletics", "technology"],
        estimatedSalary: SalaryRange(min: 40000, max: 95000),
        educationLevel: .bachelors,
        icon: "chart.xyaxis.line",
        color: "#F39C12"
    )

    static let physicalEducationTeacher = CareerPath(
        title: "PE Teacher",
        category: "sports_athletics",
        description: "Teach physical education and promote healthy lifestyles in schools.",
        pathway: CareerPathways.peTeacherPathway,
        requiredInterests: ["sports_athletics", "education"],
        estimatedSalary: SalaryRange(min: 40000, max: 75000),
        educationLevel: .bachelors,
        icon: "figure.run",
        color: "#F39C12"
    )

    // MARK: - Business & Entrepreneurship

    static let entrepreneur = CareerPath(
        title: "Entrepreneur",
        category: "business_entrepreneurship",
        description: "Start and grow your own business ventures.",
        pathway: CareerPathways.entrepreneurPathway,
        requiredInterests: ["business_entrepreneurship"],
        estimatedSalary: SalaryRange(min: 0, max: 1000000),
        educationLevel: .varies,
        icon: "lightbulb.fill",
        color: "#2ECC71"
    )

    static let marketingSpecialist = CareerPath(
        title: "Marketing Specialist",
        category: "business_entrepreneurship",
        description: "Promote products and brands through creative campaigns.",
        pathway: CareerPathways.marketingSpecialistPathway,
        requiredInterests: ["business_entrepreneurship", "creative_arts"],
        estimatedSalary: SalaryRange(min: 45000, max: 95000),
        educationLevel: .bachelors,
        icon: "megaphone.fill",
        color: "#2ECC71"
    )

    static let financialAdvisor = CareerPath(
        title: "Financial Advisor",
        category: "business_entrepreneurship",
        description: "Help people and businesses manage their finances and investments.",
        pathway: CareerPathways.financialAdvisorPathway,
        requiredInterests: ["business_entrepreneurship"],
        estimatedSalary: SalaryRange(min: 50000, max: 150000),
        educationLevel: .bachelors,
        icon: "dollarsign.circle.fill",
        color: "#2ECC71"
    )

    static let businessAnalyst = CareerPath(
        title: "Business Analyst",
        category: "business_entrepreneurship",
        description: "Analyze business processes and recommend improvements.",
        pathway: CareerPathways.businessAnalystPathway,
        requiredInterests: ["business_entrepreneurship", "technology"],
        estimatedSalary: SalaryRange(min: 60000, max: 110000),
        educationLevel: .bachelors,
        icon: "briefcase.fill",
        color: "#2ECC71"
    )

    // MARK: - Education

    static let teacher = CareerPath(
        title: "Teacher",
        category: "education",
        description: "Educate and inspire students in schools.",
        pathway: CareerPathways.teacherPathway,
        requiredInterests: ["education"],
        estimatedSalary: SalaryRange(min: 40000, max: 75000),
        educationLevel: .bachelors,
        icon: "book.fill",
        color: "#E67E22"
    )

    static let tutor = CareerPath(
        title: "Tutor",
        category: "education",
        description: "Provide one-on-one or small group instruction to students.",
        pathway: CareerPathways.tutorPathway,
        requiredInterests: ["education"],
        estimatedSalary: SalaryRange(min: 25000, max: 65000),
        educationLevel: .varies,
        icon: "person.2.fill",
        color: "#E67E22"
    )

    static let educationSpecialist = CareerPath(
        title: "Education Specialist",
        category: "education",
        description: "Develop curriculum and support educational programs.",
        pathway: CareerPathways.educationSpecialistPathway,
        requiredInterests: ["education"],
        estimatedSalary: SalaryRange(min: 50000, max: 90000),
        educationLevel: .masters,
        icon: "graduationcap.fill",
        color: "#E67E22"
    )

    static let schoolCounselor = CareerPath(
        title: "School Counselor",
        category: "education",
        description: "Support students' academic, social, and emotional development.",
        pathway: CareerPathways.schoolCounselorPathway,
        requiredInterests: ["education", "social_services"],
        estimatedSalary: SalaryRange(min: 45000, max: 80000),
        educationLevel: .masters,
        icon: "heart.text.square.fill",
        color: "#E67E22"
    )

    // MARK: - Social Services

    static let socialWorker = CareerPath(
        title: "Social Worker",
        category: "social_services",
        description: "Help individuals and families overcome challenges and access resources.",
        pathway: CareerPathways.socialWorkerPathway,
        requiredInterests: ["social_services"],
        estimatedSalary: SalaryRange(min: 40000, max: 75000),
        educationLevel: .masters,
        icon: "hands.sparkles.fill",
        color: "#1ABC9C"
    )

    static let counselor = CareerPath(
        title: "Counselor",
        category: "social_services",
        description: "Provide mental health support and guidance to clients.",
        pathway: CareerPathways.counselorPathway,
        requiredInterests: ["social_services"],
        estimatedSalary: SalaryRange(min: 45000, max: 85000),
        educationLevel: .masters,
        icon: "brain.head.profile",
        color: "#1ABC9C"
    )

    static let communityOrganizer = CareerPath(
        title: "Community Organizer",
        category: "social_services",
        description: "Build community power and advocate for social change.",
        pathway: CareerPathways.communityOrganizerPathway,
        requiredInterests: ["social_services"],
        estimatedSalary: SalaryRange(min: 35000, max: 70000),
        educationLevel: .bachelors,
        icon: "person.3.fill",
        color: "#1ABC9C"
    )

    static let nonprofitDirector = CareerPath(
        title: "Nonprofit Director",
        category: "social_services",
        description: "Lead nonprofit organizations making a difference in communities.",
        pathway: CareerPathways.nonprofitDirectorPathway,
        requiredInterests: ["social_services", "business_entrepreneurship"],
        estimatedSalary: SalaryRange(min: 50000, max: 120000),
        educationLevel: .bachelors,
        icon: "building.2.fill",
        color: "#1ABC9C"
    )
}
