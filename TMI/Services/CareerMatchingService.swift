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

    /// Match student interests to career paths
    func matchCareers(from clusters: [InterestCluster], dreamJob: String? = nil) -> [CareerMatchResult] {
        var matches: [CareerMatchResult] = []

        // Get all available career paths
        let allCareers = CareerDatabase.allCareerPaths

        // Calculate match score for each career path
        for career in allCareers {
            let score = career.relevanceScore(for: clusters)

            guard score > 0.0 else { continue }

            let matchingInterests = career.requiredInterests.filter { requiredInterest in
                clusters.contains { $0.name == requiredInterest }
            }

            // Suggest TMI modules based on career needs
            let suggestedModules = suggestTMIModules(for: career, interests: clusters)

            let match = CareerMatchResult(
                career: career,
                score: score,
                matchingInterests: matchingInterests,
                suggestedTMIModules: suggestedModules
            )

            matches.append(match)
        }

        // Boost dream job match if it exists
        if let dream = dreamJob?.lowercased(), !dream.isEmpty {
            for index in matches.indices {
                if matches[index].career.title.lowercased().contains(dream) {
                    matches[index] = CareerMatchResult(
                        id: matches[index].id,
                        career: matches[index].career,
                        score: min(matches[index].score * 1.3, 1.0), // Boost by 30%
                        matchingInterests: matches[index].matchingInterests,
                        suggestedTMIModules: matches[index].suggestedTMIModules
                    )
                }
            }
        }

        // Sort by score (highest first)
        return matches.sorted { $0.score > $1.score }
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
