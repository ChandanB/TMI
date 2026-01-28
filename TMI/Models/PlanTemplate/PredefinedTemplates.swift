//
//  PredefinedTemplates.swift
//  TMI
//
//  Predefined plan templates for each TMI model
//  Phase 2.3: Plan Templates
//

import Foundation

extension PlanTemplate {
    /// All built-in TMI plan templates
    static let builtInTemplates: [PlanTemplate] = [
        chaseYourSpaceTemplate,
        acknowledgeInterestsTemplate,
        alignYourMindTemplate,
        recognizeRelevanceTemplate,
        youMatterTemplate,
        increaseSelfEfficacyTemplate
    ]

    // MARK: - Chase Your Space

    static let chaseYourSpaceTemplate = PlanTemplate(
        name: "Chase Your Space - Career Exploration",
        model: .chaseYourSpace,
        description: "Help students explore career pathways aligned with their interests and aspirations. Focus on creating a safe space for self-discovery and future planning.",
        category: "Career Exploration",
        recommendedDuration: 90, // days
        activities: [
            // Week 1: Getting Started
            ActivityTemplate(
                title: "Initial Interest Survey",
                description: "Complete comprehensive interest inventory to identify passion areas",
                type: .assessment,
                scheduleSuggestion: .atStart,
                estimatedDuration: 30,
                sequenceOrder: 1,
                instructions: "Complete the TMI interest survey, being honest about your likes, dislikes, and dream job.",
                assessmentCriteria: "Survey completed with thoughtful responses"
            ),
            ActivityTemplate(
                title: "Create Your Vision Board",
                description: "Visual representation of career aspirations and life goals",
                type: .projectWork,
                scheduleSuggestion: .weekly,
                estimatedDuration: 45,
                sequenceOrder: 2,
                instructions: "Collect images, words, and symbols that represent your ideal future. Create a digital or physical collage.",
                requiredMaterials: ["Images/magazines", "Poster board or digital tool", "Markers/glue"],
                assessmentCriteria: "Vision board includes career goals, lifestyle aspirations, and personal values"
            ),

            // Ongoing Activities
            ActivityTemplate(
                title: "Weekly Career Exploration Check-In",
                description: "Discuss career research progress and questions",
                type: .checkIn,
                scheduleSuggestion: .weekly,
                estimatedDuration: 15,
                sequenceOrder: 3,
                instructions: "Share one new career you explored this week and what interested you about it."
            ),
            ActivityTemplate(
                title: "Career Research Assignment",
                description: "Deep dive into 2-3 matched career paths",
                type: .assignment,
                scheduleSuggestion: .biweekly,
                estimatedDuration: 60,
                sequenceOrder: 4,
                instructions: "Research day-in-the-life, required education, salary range, and growth outlook for each career.",
                requiredMaterials: ["Career research worksheet", "Internet access"],
                assessmentCriteria: "Completed research on at least 2 careers with all required sections"
            ),
            ActivityTemplate(
                title: "Professional Interview Activity",
                description: "Conduct informational interviews with professionals in fields of interest",
                type: .skillPractice,
                scheduleSuggestion: .monthly,
                estimatedDuration: 45,
                sequenceOrder: 5,
                instructions: "Prepare 5-10 questions. Interview a professional (virtual or in-person). Document key insights.",
                requiredMaterials: ["Interview question template", "Recording device (optional)"]
            ),

            // Reflection and Planning
            ActivityTemplate(
                title: "Monthly Reflection Journal",
                description: "Reflect on discoveries, evolving interests, and next steps",
                type: .reflection,
                scheduleSuggestion: .monthly,
                estimatedDuration: 30,
                sequenceOrder: 6,
                instructions: "Write about: What surprised you? What confirmed your interests? What new questions emerged?"
            ),
            ActivityTemplate(
                title: "Create Your Action Plan",
                description: "Develop concrete next steps toward career goals",
                type: .goalSetting,
                scheduleSuggestion: .atEnd,
                estimatedDuration: 45,
                sequenceOrder: 7,
                instructions: "List 3-5 achievable steps you can take in the next 6 months toward your career goals.",
                assessmentCriteria: "Action plan includes specific, measurable, and realistic steps"
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Complete comprehensive interest assessment",
                description: "Finish TMI interest survey to identify top 3-5 interest areas",
                category: .career,
                measurableOutcome: "Completed interest survey with results showing clear interest clusters",
                successCriteria: [
                    "Survey completed",
                    "Top interests identified",
                    "Results reviewed with counselor"
                ],
                timeframe: "1 week",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Research 3 aligned career paths",
                description: "Conduct in-depth research on careers matching your interests",
                category: .career,
                measurableOutcome: "Complete career research worksheets for 3 different careers",
                successCriteria: [
                    "Research completed for career #1",
                    "Research completed for career #2",
                    "Research completed for career #3",
                    "Comparison chart created"
                ],
                timeframe: "1 month",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Connect with professionals in target fields",
                description: "Build network by conducting informational interviews",
                category: .career,
                measurableOutcome: "Complete at least 1 informational interview with a professional",
                successCriteria: [
                    "Identified professionals to contact",
                    "Prepared interview questions",
                    "Conducted interview",
                    "Documented insights and follow-up steps"
                ],
                timeframe: "2 months",
                sequenceOrder: 3
            ),
            GoalTemplate(
                title: "Develop actionable career pathway plan",
                description: "Create concrete next steps toward career goals",
                category: .career,
                measurableOutcome: "Written action plan with 3-5 specific steps",
                successCriteria: [
                    "Short-term goals identified (6 months)",
                    "Long-term goals identified (2-5 years)",
                    "Education requirements researched",
                    "Action plan reviewed with counselor"
                ],
                timeframe: "3 months",
                sequenceOrder: 4
            )
        ],
        resourceCategories: ["Career exploration videos", "Interest assessments", "Industry overviews", "Professional networking tips"],
        tier: 1, // Tier 1 - Universal support
        targetedInterventions: ["Career readiness", "Interest exploration", "Future planning", "Self-discovery"],
        isPublic: true
    )

    // MARK: - Acknowledge Interests

    static let acknowledgeInterestsTemplate = PlanTemplate(
        name: "Acknowledge Interests - Validation & Exploration",
        model: .acknowledgeInterests,
        description: "Validate student interests and help them see how passions can translate into academic and career success.",
        category: "Engagement",
        recommendedDuration: 60,
        activities: [
            ActivityTemplate(
                title: "Interest Mapping Activity",
                description: "Create visual map connecting interests to academic subjects and careers",
                type: .skillPractice,
                scheduleSuggestion: .atStart,
                estimatedDuration: 45,
                sequenceOrder: 1,
                instructions: "Draw connections between your interests, favorite school subjects, and potential careers.",
                requiredMaterials: ["Interest map template", "Colored pencils"],
                assessmentCriteria: "Map shows at least 3 interests with connections to academics and careers"
            ),
            ActivityTemplate(
                title: "Passion Project Proposal",
                description: "Design a personal project based on your interests",
                type: .projectWork,
                scheduleSuggestion: .weekly,
                estimatedDuration: 90,
                sequenceOrder: 2,
                instructions: "Propose a project that combines your interests with academic learning. Include goals, timeline, and deliverables."
            ),
            ActivityTemplate(
                title: "Bi-Weekly Interest Check-In",
                description: "Discuss how you're incorporating interests into learning",
                type: .checkIn,
                scheduleSuggestion: .biweekly,
                estimatedDuration: 20,
                sequenceOrder: 3
            ),
            ActivityTemplate(
                title: "Share Your Expertise Session",
                description: "Present on a topic related to your interests",
                type: .peerCollaboration,
                scheduleSuggestion: .monthly,
                estimatedDuration: 30,
                sequenceOrder: 4,
                instructions: "Prepare a 5-10 minute presentation teaching others about something you're passionate about.",
                assessmentCriteria: "Presentation delivered with clear enthusiasm and knowledge"
            ),
            ActivityTemplate(
                title: "Interest Reflection Journal",
                description: "Document how interests are shaping your learning and goals",
                type: .reflection,
                scheduleSuggestion: .weekly,
                estimatedDuration: 15,
                sequenceOrder: 5
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Identify and articulate top 3 interests",
                description: "Clearly define your strongest interests and why they matter to you",
                category: .engagement,
                measurableOutcome: "Written description of 3 interests with examples of engagement",
                successCriteria: [
                    "Interests identified",
                    "Examples of each interest documented",
                    "Shared with counselor/teacher"
                ],
                timeframe: "1 week",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Complete passion-driven project",
                description: "Design and execute a project combining interests with learning",
                category: .engagement,
                measurableOutcome: "Finished project demonstrating interest application",
                successCriteria: [
                    "Project proposal approved",
                    "Project milestones completed",
                    "Final project presented",
                    "Reflection completed"
                ],
                timeframe: "2 months",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Connect interests to academic subjects",
                description: "Find relevance between passions and school curriculum",
                category: .academic,
                measurableOutcome: "Interest map showing connections to at least 2 academic subjects",
                successCriteria: [
                    "Interest-academic connections identified",
                    "Discussed connections with teacher",
                    "Applied interests to classwork"
                ],
                timeframe: "1 month",
                sequenceOrder: 3
            )
        ],
        resourceCategories: ["Interest exploration", "Project-based learning", "Academic connections", "Student presentations"],
        tier: 1,
        targetedInterventions: ["Student engagement", "Interest validation", "Academic relevance", "Motivation"],
        isPublic: true
    )

    // MARK: - Align Your Mind

    static let alignYourMindTemplate = PlanTemplate(
        name: "Align Your Mind - Focus & Self-Regulation",
        model: .alignYourMind,
        description: "Develop mindfulness, focus, and emotional regulation skills to support academic and personal success.",
        category: "Social-Emotional",
        recommendedDuration: 90,
        activities: [
            ActivityTemplate(
                title: "Daily Mindfulness Practice",
                description: "5-minute guided mindfulness or breathing exercise",
                type: .skillPractice,
                scheduleSuggestion: .daily,
                estimatedDuration: 5,
                sequenceOrder: 1,
                instructions: "Use provided mindfulness app or recording. Practice deep breathing and present-moment awareness."
            ),
            ActivityTemplate(
                title: "Focus Skills Workshop",
                description: "Learn techniques for improving concentration and reducing distractions",
                type: .skillPractice,
                scheduleSuggestion: .weekly,
                estimatedDuration: 30,
                sequenceOrder: 2,
                instructions: "Practice Pomodoro technique, distraction management, and priority setting.",
                requiredMaterials: ["Timer", "Focus tracking sheet"]
            ),
            ActivityTemplate(
                title: "Emotional Check-In",
                description: "Weekly reflection on emotional state and regulation strategies",
                type: .checkIn,
                scheduleSuggestion: .weekly,
                estimatedDuration: 15,
                sequenceOrder: 3,
                instructions: "Rate your emotional state this week. What helped? What was challenging?"
            ),
            ActivityTemplate(
                title: "Stress Management Toolkit",
                description: "Build personalized toolkit of coping strategies",
                type: .projectWork,
                scheduleSuggestion: .biweekly,
                estimatedDuration: 45,
                sequenceOrder: 4,
                instructions: "Identify and practice 5 different stress management techniques. Create toolkit with your favorites."
            ),
            ActivityTemplate(
                title: "Growth Mindset Journaling",
                description: "Reflect on challenges as opportunities for growth",
                type: .reflection,
                scheduleSuggestion: .weekly,
                estimatedDuration: 20,
                sequenceOrder: 5,
                instructions: "Document a challenge you faced. What did you learn? How did you grow?"
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Establish daily mindfulness practice",
                description: "Practice mindfulness 5 days per week consistently",
                category: .emotional,
                measurableOutcome: "80% completion rate on mindfulness tracking log",
                successCriteria: [
                    "Practice logged daily",
                    "Minimum 5 days per week for 4 weeks",
                    "Reflection on benefits completed"
                ],
                timeframe: "1 month",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Improve focus and concentration",
                description: "Use focus techniques to increase sustained attention",
                category: .academic,
                measurableOutcome: "Increase focused work time by 50%",
                successCriteria: [
                    "Baseline focus time measured",
                    "Focus techniques practiced weekly",
                    "Progress tracked and documented",
                    "Improvement demonstrated"
                ],
                timeframe: "2 months",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Build stress management toolkit",
                description: "Identify and practice effective coping strategies",
                category: .emotional,
                measurableOutcome: "Personal toolkit with 5 stress management techniques",
                successCriteria: [
                    "Techniques researched",
                    "Each technique practiced",
                    "Toolkit created and shared",
                    "Strategies used during stressful situations"
                ],
                timeframe: "6 weeks",
                sequenceOrder: 3
            )
        ],
        resourceCategories: ["Mindfulness exercises", "Focus techniques", "Stress management", "Emotional regulation"],
        tier: 2, // Tier 2 - Targeted support
        targetedInterventions: ["Emotional regulation", "Focus/attention", "Stress management", "Mindfulness"],
        isPublic: true
    )

    // MARK: - Recognize Relevance

    static let recognizeRelevanceTemplate = PlanTemplate(
        name: "Recognize Relevance - Academic Connection",
        model: .recognizeRelevance,
        description: "Help students see the real-world relevance of academic content and connect learning to their lives and goals.",
        category: "Academic Support",
        recommendedDuration: 60,
        activities: [
            ActivityTemplate(
                title: "Real-World Connections Workshop",
                description: "Explore how academic subjects apply to careers and daily life",
                type: .discussion,
                scheduleSuggestion: .weekly,
                estimatedDuration: 45,
                sequenceOrder: 1,
                instructions: "Choose one subject per week. Research and present real-world applications."
            ),
            ActivityTemplate(
                title: "Career-Academic Mapping",
                description: "Map connections between school subjects and desired career",
                type: .skillPractice,
                scheduleSuggestion: .atStart,
                estimatedDuration: 30,
                sequenceOrder: 2,
                instructions: "Create visual map showing how each school subject supports your career goals.",
                assessmentCriteria: "Map includes all core subjects with specific career connections"
            ),
            ActivityTemplate(
                title: "Weekly Relevance Reflection",
                description: "Journal about one relevant thing learned each week",
                type: .reflection,
                scheduleSuggestion: .weekly,
                estimatedDuration: 10,
                sequenceOrder: 3
            ),
            ActivityTemplate(
                title: "Applied Learning Project",
                description: "Complete project using academic skills in practical context",
                type: .projectWork,
                scheduleSuggestion: .monthly,
                estimatedDuration: 120,
                sequenceOrder: 4,
                instructions: "Design a project that solves a real problem using skills from 2+ subjects.",
                requiredMaterials: ["Project proposal template", "Resources based on project topic"]
            ),
            ActivityTemplate(
                title: "Guest Speaker Sessions",
                description: "Learn from professionals about academic skills in their careers",
                type: .discussion,
                scheduleSuggestion: .monthly,
                estimatedDuration: 45,
                sequenceOrder: 5,
                instructions: "Prepare questions about how speakers use school subjects in their work."
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Identify relevance in each core subject",
                description: "Find and document real-world applications for all academic subjects",
                category: .academic,
                measurableOutcome: "Completed relevance map for 4+ subjects",
                successCriteria: [
                    "Math relevance identified",
                    "English/Language Arts relevance identified",
                    "Science relevance identified",
                    "Social Studies relevance identified",
                    "Presented findings"
                ],
                timeframe: "1 month",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Complete applied learning project",
                description: "Use academic skills to solve real-world problem",
                category: .academic,
                measurableOutcome: "Finished project demonstrating practical application",
                successCriteria: [
                    "Project proposal approved",
                    "Academic connections documented",
                    "Project completed",
                    "Reflection on learning"
                ],
                timeframe: "6 weeks",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Improve academic engagement",
                description: "Increase participation and effort in academic classes",
                category: .engagement,
                measurableOutcome: "10% improvement in class participation or grades",
                successCriteria: [
                    "Baseline participation measured",
                    "Weekly progress tracked",
                    "Improvement documented",
                    "Teacher feedback obtained"
                ],
                timeframe: "2 months",
                sequenceOrder: 3
            )
        ],
        resourceCategories: ["Real-world applications", "Career-academic connections", "Project-based learning", "Professional perspectives"],
        tier: 2,
        targetedInterventions: ["Academic relevance", "Student engagement", "Real-world connections", "Motivation"],
        isPublic: true
    )

    // MARK: - You Matter

    static let youMatterTemplate = PlanTemplate(
        name: "You Matter - Self-Advocacy & Worth",
        model: .youMatter,
        description: "Build self-worth, self-advocacy skills, and recognition of personal strengths and value.",
        category: "Social-Emotional",
        recommendedDuration: 90,
        activities: [
            ActivityTemplate(
                title: "Strength Inventory Assessment",
                description: "Identify personal strengths, skills, and positive qualities",
                type: .assessment,
                scheduleSuggestion: .atStart,
                estimatedDuration: 30,
                sequenceOrder: 1,
                instructions: "Complete strength finder assessment. Reflect on top 5 strengths.",
                assessmentCriteria: "Strengths identified with specific examples"
            ),
            ActivityTemplate(
                title: "Daily Affirmation Practice",
                description: "Write and reflect on personal affirmations",
                type: .skillPractice,
                scheduleSuggestion: .daily,
                estimatedDuration: 5,
                sequenceOrder: 2,
                instructions: "Write one positive affirmation about yourself. Read it aloud."
            ),
            ActivityTemplate(
                title: "Self-Advocacy Skills Workshop",
                description: "Learn to communicate needs, set boundaries, and ask for help",
                type: .skillPractice,
                scheduleSuggestion: .weekly,
                estimatedDuration: 45,
                sequenceOrder: 3,
                instructions: "Practice asking for help, saying no, and expressing needs assertively.",
                requiredMaterials: ["Self-advocacy scenarios", "Role-play partner"]
            ),
            ActivityTemplate(
                title: "Success Story Sharing",
                description: "Share personal achievements and growth moments",
                type: .peerCollaboration,
                scheduleSuggestion: .biweekly,
                estimatedDuration: 30,
                sequenceOrder: 4,
                instructions: "Prepare to share a recent success, no matter how small. Celebrate together."
            ),
            ActivityTemplate(
                title: "Personal Value Reflection",
                description: "Journal about your unique contributions and worth",
                type: .reflection,
                scheduleSuggestion: .weekly,
                estimatedDuration: 20,
                sequenceOrder: 5,
                instructions: "Write about: How did I make a difference this week? What value do I bring?"
            ),
            ActivityTemplate(
                title: "Boundary Setting Practice",
                description: "Identify and practice setting healthy boundaries",
                type: .skillPractice,
                scheduleSuggestion: .monthly,
                estimatedDuration: 45,
                sequenceOrder: 6,
                instructions: "Identify one boundary you need. Practice setting it assertively.",
                assessmentCriteria: "Boundary identified and communicated effectively"
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Identify and embrace personal strengths",
                description: "Recognize at least 5 personal strengths with evidence",
                category: .selfAdvocacy,
                measurableOutcome: "Completed strength inventory with examples",
                successCriteria: [
                    "Strength assessment completed",
                    "Top 5 strengths identified",
                    "Evidence/examples documented",
                    "Strengths shared with supportive adult"
                ],
                timeframe: "2 weeks",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Practice self-advocacy in 3 situations",
                description: "Use self-advocacy skills to communicate needs",
                category: .selfAdvocacy,
                measurableOutcome: "Document 3 instances of successful self-advocacy",
                successCriteria: [
                    "Self-advocacy scenario #1 completed",
                    "Self-advocacy scenario #2 completed",
                    "Self-advocacy scenario #3 completed",
                    "Reflection on experience"
                ],
                timeframe: "1 month",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Establish healthy boundaries",
                description: "Identify and communicate personal boundaries",
                category: .social,
                measurableOutcome: "Set and maintain 2 healthy boundaries",
                successCriteria: [
                    "Boundaries identified",
                    "Communication plan created",
                    "Boundaries communicated",
                    "Follow-through documented"
                ],
                timeframe: "6 weeks",
                sequenceOrder: 3
            ),
            GoalTemplate(
                title: "Build positive self-concept",
                description: "Develop consistent positive self-talk and affirmations",
                category: .emotional,
                measurableOutcome: "Complete 30 days of affirmation practice",
                successCriteria: [
                    "Daily affirmations logged",
                    "Reflections on self-perception",
                    "Changes in self-talk noted",
                    "Progress reviewed with counselor"
                ],
                timeframe: "1 month",
                sequenceOrder: 4
            )
        ],
        resourceCategories: ["Self-advocacy skills", "Strength assessments", "Positive affirmations", "Boundary setting"],
        tier: 2,
        targetedInterventions: ["Self-advocacy", "Self-worth", "Boundary setting", "Personal growth"],
        isPublic: true
    )

    // MARK: - Increase Self-Efficacy

    static let increaseSelfEfficacyTemplate = PlanTemplate(
        name: "Increase Self-Efficacy - Confidence Building",
        model: .increaseSelfEfficacy,
        description: "Build confidence through achievable goals, skill mastery, and celebrating progress.",
        category: "Academic Support",
        recommendedDuration: 90,
        activities: [
            ActivityTemplate(
                title: "Baseline Skills Assessment",
                description: "Identify current skill levels and growth areas",
                type: .assessment,
                scheduleSuggestion: .atStart,
                estimatedDuration: 30,
                sequenceOrder: 1,
                instructions: "Self-assess skills in target area. Identify specific growth goals."
            ),
            ActivityTemplate(
                title: "Small Wins Tracking",
                description: "Document daily/weekly achievements and progress",
                type: .skillPractice,
                scheduleSuggestion: .daily,
                estimatedDuration: 10,
                sequenceOrder: 2,
                instructions: "Record at least one thing you accomplished or learned today."
            ),
            ActivityTemplate(
                title: "Skill-Building Practice Sessions",
                description: "Focused practice on specific skills with scaffolded difficulty",
                type: .skillPractice,
                scheduleSuggestion: .weekly,
                estimatedDuration: 45,
                sequenceOrder: 3,
                instructions: "Practice target skill using incremental challenges. Start easy, increase difficulty.",
                requiredMaterials: ["Skill practice worksheets", "Progress tracker"]
            ),
            ActivityTemplate(
                title: "Growth Mindset Workshop",
                description: "Learn about brain plasticity, effort, and growth",
                type: .discussion,
                scheduleSuggestion: .biweekly,
                estimatedDuration: 30,
                sequenceOrder: 4,
                instructions: "Explore how effort leads to growth. Reframe challenges as opportunities."
            ),
            ActivityTemplate(
                title: "Mentor Check-In and Feedback",
                description: "Receive encouragement and constructive feedback",
                type: .checkIn,
                scheduleSuggestion: .weekly,
                estimatedDuration: 20,
                sequenceOrder: 5,
                instructions: "Share progress. Receive feedback. Adjust strategies as needed."
            ),
            ActivityTemplate(
                title: "Success Showcase",
                description: "Present or demonstrate skill mastery",
                type: .peerCollaboration,
                scheduleSuggestion: .monthly,
                estimatedDuration: 30,
                sequenceOrder: 6,
                instructions: "Demonstrate a skill you've developed. Teach others what you learned.",
                assessmentCriteria: "Clear demonstration of skill improvement"
            ),
            ActivityTemplate(
                title: "Confidence Reflection Journal",
                description: "Reflect on growing confidence and self-belief",
                type: .reflection,
                scheduleSuggestion: .weekly,
                estimatedDuration: 15,
                sequenceOrder: 7,
                instructions: "Write about: What made you feel capable this week? What challenges did you overcome?"
            )
        ],
        goalTemplates: [
            GoalTemplate(
                title: "Master specific skill",
                description: "Demonstrate proficiency in chosen skill area",
                category: .academic,
                measurableOutcome: "Achieve 80% proficiency on skill assessment",
                successCriteria: [
                    "Baseline assessment completed",
                    "Practice sessions logged (minimum 8)",
                    "Progress tracked weekly",
                    "Final assessment showing improvement",
                    "Skill demonstrated to others"
                ],
                timeframe: "2 months",
                sequenceOrder: 1
            ),
            GoalTemplate(
                title: "Complete 30 days of small wins tracking",
                description: "Build habit of recognizing daily achievements",
                category: .emotional,
                measurableOutcome: "Daily achievements logged for 30 consecutive days",
                successCriteria: [
                    "Tracking sheet set up",
                    "Daily entries completed",
                    "Patterns identified",
                    "Reflection on growth"
                ],
                timeframe: "1 month",
                sequenceOrder: 2
            ),
            GoalTemplate(
                title: "Develop growth mindset",
                description: "Shift perspective on challenges and mistakes",
                category: .emotional,
                measurableOutcome: "Demonstrate growth mindset language in reflections",
                successCriteria: [
                    "Growth mindset concepts learned",
                    "Fixed mindset thoughts identified",
                    "Reframing practiced",
                    "Growth language used in journal"
                ],
                timeframe: "6 weeks",
                sequenceOrder: 3
            ),
            GoalTemplate(
                title: "Take on new challenge successfully",
                description: "Attempt and complete something outside comfort zone",
                category: .selfAdvocacy,
                measurableOutcome: "Complete one new challenge with documented effort",
                successCriteria: [
                    "Challenge identified",
                    "Support plan created",
                    "Challenge attempted",
                    "Outcome documented (regardless of 'success')",
                    "Learning reflected upon"
                ],
                timeframe: "3 months",
                sequenceOrder: 4
            )
        ],
        resourceCategories: ["Skill-building exercises", "Growth mindset resources", "Progress tracking tools", "Confidence building"],
        tier: 2,
        targetedInterventions: ["Self-efficacy", "Skill mastery", "Confidence building", "Growth mindset"],
        isPublic: true
    )
}
