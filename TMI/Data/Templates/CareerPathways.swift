//
//  CareerPathways.swift
//  TMI
//
//  Predefined career pathway templates with goals, activities, and resources
//

import Foundation

struct CareerPathways {
    // MARK: - Audio & Media Pathways

    static let podcasterPathway = TMICareerPathway(
        name: "Podcaster Path",
        beginnerGoals: [
            CEPGoal(
                title: "Plan your podcast concept",
                level: .beginner,
                strategies: [
                    "Brainstorm topics you're passionate about",
                    "Choose a format (interview, solo, storytelling)",
                    "Define your target audience"
                ],
                activities: [
                    Activity(title: "Complete concept worksheet", duration: 15, type: .practice),
                    Activity(title: "Listen to 3 podcasts in your niche", duration: 60, type: .reading)
                ],
                assessment: "Completed podcast concept document",
                reflectionPrompt: "What makes your podcast idea unique?",
                estimatedDuration: 75
            ),
            CEPGoal(
                title: "Write your first script",
                level: .beginner,
                strategies: [
                    "Use a script template",
                    "Practice reading aloud",
                    "Get peer feedback"
                ],
                activities: [
                    Activity(title: "Write 5-minute intro script", duration: 30, type: .practice),
                    Activity(title: "Record yourself reading", duration: 15, type: .practice),
                    Activity(title: "Peer review session", duration: 20, type: .collaboration)
                ],
                assessment: "Polished 5-minute script",
                reflectionPrompt: "What was challenging about scriptwriting?",
                estimatedDuration: 65
            )
        ],
        intermediateGoals: [
            CEPGoal(
                title: "Learn audio editing basics",
                level: .intermediate,
                strategies: [
                    "Download free DAW (Audacity/GarageBand)",
                    "Complete editing tutorial",
                    "Record and edit test episode"
                ],
                activities: [
                    Activity(title: "Watch Audacity tutorial", duration: 20, type: .video),
                    Activity(title: "Record test episode", duration: 30, type: .practice),
                    Activity(title: "Edit with transitions", duration: 45, type: .practice)
                ],
                assessment: "Completed edited audio file",
                reflectionPrompt: "How did editing improve your episode?",
                estimatedDuration: 95
            ),
            CEPGoal(
                title: "Design podcast branding",
                level: .intermediate,
                strategies: [
                    "Create show logo using Canva",
                    "Design intro/outro music",
                    "Write show description"
                ],
                activities: [
                    Activity(title: "Logo design in Canva", duration: 30, type: .practice),
                    Activity(title: "Find royalty-free music", duration: 15, type: .practice),
                    Activity(title: "Write compelling description", duration: 15, type: .practice)
                ],
                assessment: "Complete branding package",
                reflectionPrompt: "How does your branding reflect your show?",
                estimatedDuration: 60
            )
        ],
        advancedGoals: [
            CEPGoal(
                title: "Publish 3-episode series",
                level: .advanced,
                strategies: [
                    "Choose platform (Anchor, Buzzsprout)",
                    "Upload episodes with metadata",
                    "Promote on social media"
                ],
                activities: [
                    Activity(title: "Platform setup", duration: 30, type: .practice),
                    Activity(title: "Upload 3 episodes", duration: 20, type: .practice),
                    Activity(title: "Create social posts", duration: 15, type: .practice)
                ],
                assessment: "Live podcast with 3 published episodes",
                reflectionPrompt: "What did you learn from listener feedback?",
                estimatedDuration: 65
            )
        ],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
        resources: [
            ResourceReference(
                title: "Podcast Planning Worksheet",
                type: .worksheet,
                duration: "15min",
                level: .beginner
            ),
            ResourceReference(
                title: "Audacity Basics Video Tutorial",
                type: .video,
                url: "https://example.com/audacity-tutorial",
                duration: "20min",
                level: .intermediate
            )
        ]
    )

    static let radioHostPathway = TMICareerPathway(
        name: "Radio Host Path",
        beginnerGoals: [
            CEPGoal(
                title: "Develop your on-air voice",
                level: .beginner,
                strategies: ["Practice vocal exercises", "Study professional hosts", "Record practice segments"],
                activities: [
                    Activity(title: "Vocal warm-ups daily", duration: 10, type: .practice),
                    Activity(title: "Analyze pro broadcasts", duration: 30, type: .reading)
                ],
                assessment: "5-minute practice segment recording",
                reflectionPrompt: "How has your voice improved?",
                estimatedDuration: 40
            )
        ],
        intermediateGoals: [
            CEPGoal(
                title: "Master live broadcasting",
                level: .intermediate,
                strategies: ["Learn mixing board", "Practice timing", "Handle live calls"],
                activities: [
                    Activity(title: "Equipment training", duration: 45, type: .practice)
                ],
                assessment: "Live broadcast simulation",
                reflectionPrompt: "What challenges did you face going live?",
                estimatedDuration: 45
            )
        ],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .directAndCorrect],
        resources: []
    )

    static let audioEngineerPathway = TMICareerPathway(
        name: "Audio Engineer Path",
        beginnerGoals: [
            CEPGoal(
                title: "Learn signal flow basics",
                level: .beginner,
                strategies: ["Understand audio chain", "Study mic placement", "Practice gain staging"],
                activities: [
                    Activity(title: "Signal flow diagram study", duration: 30, type: .reading)
                ],
                assessment: "Signal flow quiz",
                reflectionPrompt: "Why is signal flow important?",
                estimatedDuration: 30
            )
        ],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind],
        resources: []
    )

    static let contentCreatorPathway = TMICareerPathway(
        name: "Content Creator Path",
        beginnerGoals: [
            CEPGoal(
                title: "Build your content strategy",
                level: .beginner,
                strategies: ["Choose platform", "Define niche", "Plan content calendar"],
                activities: [
                    Activity(title: "Platform research", duration: 20, type: .reading),
                    Activity(title: "30-day content plan", duration: 40, type: .practice)
                ],
                assessment: "Content strategy document",
                reflectionPrompt: "What makes your content stand out?",
                estimatedDuration: 60
            )
        ],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .bullyToBoss],
        resources: []
    )

    // MARK: - Technology Pathways

    static let gameDeveloperPathway = TMICareerPathway(
        name: "Game Developer Path",
        beginnerGoals: [
            CEPGoal(
                title: "Learn programming basics",
                level: .beginner,
                strategies: ["Start with Python or JavaScript", "Complete coding tutorials", "Build simple game"],
                activities: [
                    Activity(title: "Codecademy Python course", duration: 120, type: .reading),
                    Activity(title: "Build text adventure game", duration: 90, type: .project)
                ],
                assessment: "Completed simple game project",
                reflectionPrompt: "What programming concepts clicked for you?",
                estimatedDuration: 210
            )
        ],
        intermediateGoals: [
            CEPGoal(
                title: "Master game engine basics",
                level: .intermediate,
                strategies: ["Learn Unity or Godot", "Study game mechanics", "Create 2D platformer"],
                activities: [
                    Activity(title: "Unity tutorial series", duration: 180, type: .video)
                ],
                assessment: "Playable 2D game prototype",
                reflectionPrompt: "What game mechanics interest you most?",
                estimatedDuration: 180
            )
        ],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
        resources: []
    )

    static let appDesignerPathway = TMICareerPathway(
        name: "App Designer Path",
        beginnerGoals: [
            CEPGoal(
                title: "Learn design principles",
                level: .beginner,
                strategies: ["Study UI/UX basics", "Analyze popular apps", "Use Figma"],
                activities: [
                    Activity(title: "UI fundamentals course", duration: 90, type: .reading)
                ],
                assessment: "App design mockup in Figma",
                reflectionPrompt: "What makes a great user experience?",
                estimatedDuration: 90
            )
        ],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
        resources: []
    )

    static let softwareEngineerPathway = TMICareerPathway(
        name: "Software Engineer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind],
        resources: []
    )

    static let dataAnalystPathway = TMICareerPathway(
        name: "Data Analyst Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind],
        resources: []
    )

    // MARK: - Creative Arts Pathways

    static let graphicDesignerPathway = TMICareerPathway(
        name: "Graphic Designer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests],
        resources: []
    )

    static let photographerPathway = TMICareerPathway(
        name: "Photographer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests],
        resources: []
    )

    static let filmDirectorPathway = TMICareerPathway(
        name: "Film Director Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
        resources: []
    )

    static let animatorPathway = TMICareerPathway(
        name: "Animator Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
        resources: []
    )

    // MARK: - Health & Wellness Pathways

    static let fitnessTrainerPathway = TMICareerPathway(
        name: "Fitness Trainer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .meekToProtector],
        resources: []
    )

    static let nutritionistPathway = TMICareerPathway(
        name: "Nutritionist Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests],
        resources: []
    )

    static let physicalTherapistPathway = TMICareerPathway(
        name: "Physical Therapist Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .meekToProtector],
        resources: []
    )

    static let nursePathway = TMICareerPathway(
        name: "Nurse Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .meekToProtector, .directAndCorrect],
        resources: []
    )

    // MARK: - Sports & Athletics Pathways

    static let coachPathway = TMICareerPathway(
        name: "Coach Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .directAndCorrect, .bullyToBoss],
        resources: []
    )

    static let athleticTrainerPathway = TMICareerPathway(
        name: "Athletic Trainer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests],
        resources: []
    )

    static let sportsAnalystPathway = TMICareerPathway(
        name: "Sports Analyst Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind],
        resources: []
    )

    static let peTeacherPathway = TMICareerPathway(
        name: "PE Teacher Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .directAndCorrect],
        resources: []
    )

    // MARK: - Business & Entrepreneurship Pathways

    static let entrepreneurPathway = TMICareerPathway(
        name: "Entrepreneur Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .bullyToBoss, .directAndCorrect],
        resources: []
    )

    static let marketingSpecialistPathway = TMICareerPathway(
        name: "Marketing Specialist Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests, .bullyToBoss],
        resources: []
    )

    static let financialAdvisorPathway = TMICareerPathway(
        name: "Financial Advisor Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind, .directAndCorrect],
        resources: []
    )

    static let businessAnalystPathway = TMICareerPathway(
        name: "Business Analyst Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind],
        resources: []
    )

    // MARK: - Education Pathways

    static let teacherPathway = TMICareerPathway(
        name: "Teacher Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .directAndCorrect, .meekToProtector],
        resources: []
    )

    static let tutorPathway = TMICareerPathway(
        name: "Tutor Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .acknowledgeInterests],
        resources: []
    )

    static let educationSpecialistPathway = TMICareerPathway(
        name: "Education Specialist Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .alignYourMind, .directAndCorrect],
        resources: []
    )

    static let schoolCounselorPathway = TMICareerPathway(
        name: "School Counselor Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .meekToProtector, .directAndCorrect],
        resources: []
    )

    // MARK: - Social Services Pathways

    static let socialWorkerPathway = TMICareerPathway(
        name: "Social Worker Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .meekToProtector, .acknowledgeInterests],
        resources: []
    )

    static let counselorPathway = TMICareerPathway(
        name: "Counselor Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .meekToProtector, .alignYourMind],
        resources: []
    )

    static let communityOrganizerPathway = TMICareerPathway(
        name: "Community Organizer Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .bullyToBoss, .directAndCorrect],
        resources: []
    )

    static let nonprofitDirectorPathway = TMICareerPathway(
        name: "Nonprofit Director Path",
        beginnerGoals: [],
        intermediateGoals: [],
        advancedGoals: [],
        tmiModules: [.chaseYourSpace, .bullyToBoss, .directAndCorrect, .meekToProtector],
        resources: []
    )
}

