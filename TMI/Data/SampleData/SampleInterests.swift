//
//  SampleInterests.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

extension Interest {
    static var expandedSampleInterests: [Interest] {
        return [
            // MARK: - Technology & Computer Science
            Interest(
                id: "int_001",
                name: "Robotics & Engineering",
                category: [.technology, .science],
                description: "Building, programming, and controlling robotic systems",
                academicRelevance: [.computerScience, .mathematics, .science],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Develops logical thinking, mathematical reasoning, and applied physics concepts. Improves problem-solving and systematic thinking skills.",
                careerPathways: [.stem, .technology],
                educationalActivities: [
                    "Build Arduino-based projects",
                    "Program simple robot movements",
                    "Design solutions to engineering challenges",
                    "Participate in robotics competitions",
                    "Create mechanical prototypes"
                ],
                behavioralBenefits: "Builds patience, attention to detail, and persistence through complex problem-solving",
                skillsDeveloped: [.problemSolving, .criticalThinking, .teamwork, .creativity],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_002",
                name: "Computer Programming",
                category: [.technology],
                description: "Writing code, developing software, and creating digital solutions",
                academicRelevance: [.computerScience, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind, .acknowledgeInterests],
                popularityScore: 82,
                isFeatured: true,
                academicBenefits: "Strengthens logical reasoning, mathematical concepts, and algorithmic thinking",
                careerPathways: [.technology, .stem],
                educationalActivities: [
                    "Create simple mobile apps",
                    "Build websites for school projects",
                    "Solve coding challenges and puzzles",
                    "Develop games or interactive stories",
                    "Learn multiple programming languages"
                ],
                behavioralBenefits: "Develops focus, analytical thinking, and systematic approach to problem-solving",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability, .timeManagement],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_003",
                name: "Video Game Design",
                category: [.technology, .arts, .entertainment],
                description: "Creating interactive digital games and virtual experiences",
                academicRelevance: [.computerScience, .art, .mathematics],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
                popularityScore: 88,
                academicBenefits: "Combines artistic creativity with technical skills, teaches project management and user experience design",
                careerPathways: [.technology, .creativeArts],
                educationalActivities: [
                    "Design game characters and storylines",
                    "Create simple games using visual programming",
                    "Study game mechanics and player psychology",
                    "Develop educational games for younger students",
                    "Analyze successful games and their design elements"
                ],
                behavioralBenefits: "Channels creative energy into structured projects, builds persistence through iterative design",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement, .communication],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Creative Arts & Expression
            Interest(
                id: "int_004",
                name: "Creative Writing & Storytelling",
                category: [.literature, .arts],
                description: "Writing original stories, poems, scripts, and creative non-fiction",
                academicRelevance: [.english, .history],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising, .alignYourMind],
                popularityScore: 72,
                academicBenefits: "Enhances vocabulary, grammar, reading comprehension, and critical analysis skills",
                careerPathways: [.creativeArts, .education],
                educationalActivities: [
                    "Start a personal writing journal",
                    "Create stories based on historical events",
                    "Write and perform original poetry",
                    "Develop characters for school plays",
                    "Contribute to school newspaper or magazine"
                ],
                behavioralBenefits: "Provides emotional outlet, builds self-expression and confidence in sharing ideas",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence, .criticalThinking],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_005",
                name: "Visual Arts & Design",
                category: [.arts],
                description: "Creating visual art through various mediums including digital and traditional methods",
                academicRelevance: [.art, .history],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising, .alignYourMind],
                popularityScore: 75,
                academicBenefits: "Develops spatial reasoning, cultural awareness, and visual communication skills",
                careerPathways: [.creativeArts, .technology],
                educationalActivities: [
                    "Create illustrations for school projects",
                    "Design posters for school events",
                    "Study art history and cultural movements",
                    "Experiment with digital art tools",
                    "Participate in local art exhibitions"
                ],
                behavioralBenefits: "Builds confidence through creative expression, provides stress relief and emotional processing",
                skillsDeveloped: [.creativity, .criticalThinking, .emotionalIntelligence, .adaptability],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_006",
                name: "Music Production & Performance",
                category: [.music, .technology],
                description: "Creating, recording, editing, and performing music using various instruments and technology",
                academicRelevance: [.music, .mathematics, .science],
                interventionModels: [.acknowledgeInterests, .alignYourMind, .directAndCorrect],
                popularityScore: 78,
                academicBenefits: "Teaches mathematical patterns, physics of sound, and develops auditory processing skills",
                careerPathways: [.creativeArts, .technology],
                educationalActivities: [
                    "Learn music theory and composition",
                    "Record and edit original songs",
                    "Perform at school events and talent shows",
                    "Study the physics of musical instruments",
                    "Collaborate with other musicians on projects"
                ],
                behavioralBenefits: "Provides emotional regulation, builds discipline through practice, enhances social connections",
                skillsDeveloped: [.creativity, .timeManagement, .teamwork, .emotionalIntelligence],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_007",
                name: "Drama & Theater Arts",
                category: [.arts, .entertainment],
                description: "Acting, directing, and participating in theatrical productions",
                academicRelevance: [.english, .history, .art],
                interventionModels: [.fromMeek2Promising, .fromBully2Boss, .acknowledgeInterests],
                popularityScore: 68,
                academicBenefits: "Enhances literary analysis, historical context understanding, and public speaking skills",
                careerPathways: [.creativeArts, .education],
                educationalActivities: [
                    "Perform in class plays and school productions",
                    "Analyze character motivations in literature",
                    "Write and direct original scenes",
                    "Study theater history and cultural contexts",
                    "Develop improvisation and communication skills"
                ],
                behavioralBenefits: "Builds confidence, empathy, and social skills through character exploration and collaboration",
                skillsDeveloped: [.communication, .teamwork, .creativity, .emotionalIntelligence, .leadership],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Sports & Physical Activities
            Interest(
                id: "int_008",
                name: "Team Sports & Athletics",
                category: [.sports],
                description: "Participating in organized team sports like basketball, soccer, football, volleyball",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect, .fromBully2Boss, .acknowledgeInterests],
                popularityScore: 90,
                isFeatured: true,
                academicBenefits: "Teaches statistics, geometry, physics concepts, and strategic thinking",
                careerPathways: [.healthcare, .education, .business],
                educationalActivities: [
                    "Track and analyze game statistics",
                    "Study sports psychology and team dynamics",
                    "Learn about nutrition and exercise science",
                    "Develop training and practice schedules",
                    "Research sports history and cultural impact"
                ],
                behavioralBenefits: "Builds teamwork, discipline, leadership skills, and provides positive outlet for energy",
                skillsDeveloped: [.teamwork, .leadership, .resilience, .timeManagement],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_009",
                name: "Individual Sports & Fitness",
                category: [.sports, .wellness],
                description: "Personal fitness activities like running, swimming, martial arts, weightlifting",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.alignYourMind, .directAndCorrect, .acknowledgeInterests],
                popularityScore: 73,
                academicBenefits: "Teaches anatomy, physiology, biomechanics, and goal-setting principles",
                careerPathways: [.healthcare],
                educationalActivities: [
                    "Create personal fitness plans with measurable goals",
                    "Study human anatomy and exercise physiology",
                    "Track progress using data and analysis",
                    "Research nutrition and health science",
                    "Learn about mental health benefits of exercise"
                ],
                behavioralBenefits: "Develops self-discipline, goal-setting abilities, stress management, and self-confidence",
                skillsDeveloped: [.resilience, .timeManagement, .adaptability, .criticalThinking],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Science & Discovery
            Interest(
                id: "int_010",
                name: "Environmental Science & Conservation",
                category: [.science, .outdoors, .socialCauses],
                description: "Studying ecosystems, climate, and working to protect natural environments",
                academicRelevance: [.science, .socialStudies, .mathematics],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 76,
                isFeatured: true,
                academicBenefits: "Integrates biology, chemistry, geography, and statistical analysis skills",
                careerPathways: [.stem, .publicService],
                educationalActivities: [
                    "Conduct water and air quality testing",
                    "Start school recycling and sustainability programs",
                    "Research local environmental issues and solutions",
                    "Create presentations on climate change impacts",
                    "Participate in community conservation projects"
                ],
                behavioralBenefits: "Develops civic responsibility, connects learning to real-world impact, builds leadership skills",
                skillsDeveloped: [.criticalThinking, .problemSolving, .leadership, .communication],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_011",
                name: "Medical Science & Healthcare",
                category: [.science, .wellness, .socialCauses],
                description: "Learning about human health, medical procedures, and healthcare careers",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 81,
                academicBenefits: "Strengthens biology, chemistry, anatomy knowledge and research methodology",
                careerPathways: [.healthcare, .stem],
                educationalActivities: [
                    "Study human anatomy and physiology",
                    "Learn about diseases and treatment methods",
                    "Shadow healthcare professionals",
                    "Participate in health awareness campaigns",
                    "Research medical breakthroughs and innovations"
                ],
                behavioralBenefits: "Develops empathy, attention to detail, and desire to help others",
                skillsDeveloped: [.criticalThinking, .communication, .emotionalIntelligence, .problemSolving],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_012",
                name: "Space Science & Astronomy",
                category: [.science, .technology],
                description: "Studying celestial bodies, space exploration, and astronomical phenomena",
                academicRelevance: [.science, .mathematics, .physicalEducation],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests, .alignYourMind],
                popularityScore: 79,
                academicBenefits: "Applies physics, mathematics, and chemistry concepts to understand the universe",
                careerPathways: [.stem, .technology],
                educationalActivities: [
                    "Use telescopes to observe celestial objects",
                    "Build model rockets and study propulsion",
                    "Research current space missions and discoveries", 
                    "Create star charts and astronomical calendars",
                    "Study the physics of space travel"
                ],
                behavioralBenefits: "Inspires curiosity and wonder, develops long-term thinking and scientific methodology",
                skillsDeveloped: [.criticalThinking, .problemSolving, .adaptability, .timeManagement],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Social Causes & Leadership
            Interest(
                id: "int_013",
                name: "Community Service & Volunteering",
                category: [.socialCauses, .leadership],
                description: "Organizing and participating in community service projects and volunteer work",
                academicRelevance: [.socialStudies, .english],
                interventionModels: [.fromBully2Boss, .acknowledgeInterests, .chaseYourSpace],
                popularityScore: 71,
                academicBenefits: "Develops understanding of social issues, civic responsibility, and research skills",
                careerPathways: [.publicService, .education],
                educationalActivities: [
                    "Organize food drives and charity events",
                    "Tutor younger students in academic subjects",
                    "Participate in environmental cleanup projects",
                    "Research social issues and propose solutions",
                    "Create awareness campaigns for important causes"
                ],
                behavioralBenefits: "Builds empathy, leadership skills, and sense of civic responsibility",
                skillsDeveloped: [.leadership, .communication, .emotionalIntelligence, .teamwork],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_014",
                name: "Student Government & Leadership",
                category: [.leadership, .socialCauses],
                description: "Participating in student government, organizing school events, and leading initiatives",
                academicRelevance: [.socialStudies, .english, .mathematics],
                interventionModels: [.fromBully2Boss, .chaseYourSpace, .acknowledgeInterests],
                popularityScore: 67,
                academicBenefits: "Teaches government processes, public speaking, event planning, and budgeting skills",
                careerPathways: [.publicService, .business, .education],
                educationalActivities: [
                    "Run for class or student body office",
                    "Organize school dances and spirit events",
                    "Create student surveys and analyze results",
                    "Study local and national government processes",
                    "Develop and present policy proposals"
                ],
                behavioralBenefits: "Develops confidence, public speaking abilities, and collaborative problem-solving skills",
                skillsDeveloped: [.leadership, .communication, .problemSolving, .teamwork],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Hands-On & Technical Skills
            Interest(
                id: "int_015",
                name: "Automotive Technology & Repair",
                category: [.technology, .crafts],
                description: "Learning about car mechanics, automotive systems, and vehicle repair",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.directAndCorrect, .acknowledgeInterests, .alignYourMind],
                popularityScore: 69,
                academicBenefits: "Applies physics, chemistry, and mathematical concepts to real-world mechanical systems",
                careerPathways: [.trades, .technology],
                educationalActivities: [
                    "Learn basic car maintenance and repair",
                    "Study automotive electrical systems",
                    "Research alternative fuel technologies",
                    "Calculate fuel efficiency and performance metrics",
                    "Restore or modify vehicles as projects"
                ],
                behavioralBenefits: "Provides hands-on learning that builds confidence and practical problem-solving skills",
                skillsDeveloped: [.problemSolving, .criticalThinking, .timeManagement, .adaptability],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_016",
                name: "Construction & Architecture",
                category: [.crafts, .technology, .arts],
                description: "Designing and building structures, learning construction techniques and architectural principles",
                academicRelevance: [.mathematics, .science, .art],
                interventionModels: [.acknowledgeInterests, .alignYourMind, .chaseYourSpace],
                popularityScore: 64,
                academicBenefits: "Integrates geometry, physics, engineering principles with creative design",
                careerPathways: [.trades, .stem, .creativeArts],
                educationalActivities: [
                    "Design and build scale models of buildings",
                    "Learn about structural engineering and materials",
                    "Study architectural history and cultural styles",
                    "Calculate load-bearing requirements and costs",
                    "Use CAD software for design projects"
                ],
                behavioralBenefits: "Develops spatial reasoning, attention to detail, and pride in creating tangible results",
                skillsDeveloped: [.problemSolving, .creativity, .timeManagement, .criticalThinking],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Business & Entrepreneurship
            Interest(
                id: "int_017",
                name: "Entrepreneurship & Business",
                category: [.leadership, .technology],
                description: "Starting businesses, learning about economics, marketing, and financial management",
                academicRelevance: [.mathematics, .socialStudies, .english],
                interventionModels: [.chaseYourSpace, .fromBully2Boss, .acknowledgeInterests],
                popularityScore: 74,
                academicBenefits: "Teaches mathematical concepts, economic principles, and communication skills",
                careerPathways: [.business, .technology],
                educationalActivities: [
                    "Start a small school-based business",
                    "Create business plans and financial projections",
                    "Learn about marketing and customer psychology",
                    "Study successful entrepreneurs and business models",
                    "Participate in business plan competitions"
                ],
                behavioralBenefits: "Develops initiative, risk assessment abilities, and financial responsibility",
                skillsDeveloped: [.leadership, .criticalThinking, .communication, .adaptability],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Gaming & Digital Culture
            Interest(
                id: "int_018",
                name: "Competitive Gaming & Esports",
                category: [.entertainment, .technology, .sports],
                description: "Competitive video gaming, game strategy analysis, and esports participation",
                academicRelevance: [.mathematics, .computerScience],
                interventionModels: [.alignYourMind, .acknowledgeInterests, .directAndCorrect],
                popularityScore: 86,
                academicBenefits: "Develops strategic thinking, statistical analysis, and technology skills",
                careerPathways: [.technology, .business, .business],
                educationalActivities: [
                    "Analyze game strategies and statistics",
                    "Learn about game design and programming",
                    "Organize school gaming tournaments",
                    "Study the business side of esports industry",
                    "Create content about gaming techniques"
                ],
                behavioralBenefits: "Builds teamwork, strategic thinking, and provides structured competitive outlet",
                skillsDeveloped: [.criticalThinking, .teamwork, .adaptability, .communication],
                tierRelevance: [.tier1, .tier2]
            ),
            
            // MARK: - Cultural & Language Interests
            Interest(
                id: "int_019",
                name: "World Languages & Cultures",
                category: [.academics, .socialCauses],
                description: "Learning foreign languages and exploring different cultures around the world",
                academicRelevance: [.foreignLanguage, .socialStudies, .history],
                interventionModels: [.acknowledgeInterests, .chaseYourSpace, .alignYourMind],
                popularityScore: 61,
                academicBenefits: "Enhances cognitive flexibility, cultural awareness, and communication skills",
                careerPathways: [.education, .publicService, .business],
                educationalActivities: [
                    "Learn conversational skills in target languages",
                    "Research cultural traditions and celebrations",
                    "Connect with international pen pals or exchange students",
                    "Cook traditional foods from different cultures",
                    "Present about global issues and perspectives"
                ],
                behavioralBenefits: "Develops cultural sensitivity, global awareness, and appreciation for diversity",
                skillsDeveloped: [.communication, .adaptability, .emotionalIntelligence, .criticalThinking],
                tierRelevance: [.tier1, .tier2]
            ),
            
            Interest(
                id: "int_020",
                name: "History & Genealogy Research",
                category: [.academics, .socialCauses],
                description: "Researching historical events, family history, and cultural heritage",
                academicRelevance: [.history, .socialStudies, .english],
                interventionModels: [.acknowledgeInterests, .alignYourMind, .fromMeek2Promising],
                popularityScore: 58,
                academicBenefits: "Develops research skills, critical analysis, and understanding of cause and effect",
                careerPathways: [.education, .publicService],
                educationalActivities: [
                    "Research family genealogy and create family trees",
                    "Study local history and historical landmarks",
                    "Interview elderly community members about past events",
                    "Create timelines and historical presentations",
                    "Visit museums and historical sites"
                ],
                behavioralBenefits: "Builds connection to community and heritage, develops patience and attention to detail",
                skillsDeveloped: [.criticalThinking, .communication, .timeManagement, .emotionalIntelligence],
                tierRelevance: [.tier1, .tier2]
            )
        ]
    }
}

