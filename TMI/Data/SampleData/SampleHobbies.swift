//
//  SampleHobbies.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

extension Hobby {
    static var expandedSampleHobbies: [Hobby] {
        return [
            // MARK: - Sports & Physical Activities
            Hobby(
                name: "Basketball",
                category: [.sports],
                description: "Playing basketball recreationally and competitively",
                academicRelevance: [.physicalEducation, .mathematics],
                popularityScore: 88,
                isFeatured: true,
                academicBenefits: "Develops statistical thinking, geometric concepts, and physics understanding through gameplay analysis",
                skillsDeveloped: [.teamwork, .leadership, .resilience, .timeManagement],
                educationalActivities: [
                    "Track personal and team statistics",
                    "Study basketball strategy and plays",
                    "Learn about sports psychology and motivation",
                    "Analyze professional games for tactical insights",
                    "Create training schedules and goals"
                ]
            ),
            
            Hobby(
                name: "Soccer/Football",
                category: [.sports],
                description: "Playing soccer at recreational and competitive levels",
                academicRelevance: [.physicalEducation, .mathematics, .science],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Teaches physics principles, statistical analysis, and global cultural awareness",
                skillsDeveloped: [.teamwork, .resilience, .adaptability, .communication],
                educationalActivities: [
                    "Study different playing formations and strategies",
                    "Learn about soccer history and global culture",
                    "Analyze player performance data",
                    "Create fitness and nutrition plans",
                    "Research soccer physics and biomechanics"
                ]
            ),
            
            Hobby(
                name: "Swimming & Water Sports",
                category: [.sports],
                description: "Swimming laps, competitive swimming, or water sports activities",
                academicRelevance: [.physicalEducation, .science],
                popularityScore: 72,
                academicBenefits: "Teaches physics of fluid dynamics, anatomy, and personal goal-setting strategies",
                skillsDeveloped: [.resilience, .timeManagement, .adaptability, .criticalThinking],
                educationalActivities: [
                    "Track swimming times and analyze improvement",
                    "Study stroke mechanics and efficiency",
                    "Learn about water safety and lifeguarding",
                    "Research aquatic ecosystems and conservation",
                    "Create training schedules for endurance building"
                ]
            ),
            
            Hobby(
                name: "Martial Arts & Self-Defense",
                category: [.sports],
                description: "Practicing martial arts like karate, taekwondo, jiu-jitsu, or boxing",
                academicRelevance: [.physicalEducation, .history],
                popularityScore: 69,
                academicBenefits: "Combines physical fitness with cultural history, philosophy, and discipline studies",
                skillsDeveloped: [.resilience, .emotionalIntelligence, .adaptability, .timeManagement],
                educationalActivities: [
                    "Study the history and philosophy of martial arts",
                    "Learn about different cultural fighting traditions",
                    "Practice mindfulness and meditation techniques",
                    "Research the science of human movement",
                    "Set and track skill progression goals"
                ]
            ),
            
            Hobby(
                name: "Running & Track Sports",
                category: [.sports],
                description: "Distance running, sprinting, cross-country, or track and field events",
                academicRelevance: [.physicalEducation, .mathematics, .science],
                popularityScore: 76,
                academicBenefits: "Develops data analysis skills through performance tracking and understanding of human physiology",
                skillsDeveloped: [.resilience, .timeManagement, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Track running times and distances using data",
                    "Study human anatomy and exercise physiology",
                    "Create personalized training and nutrition plans",
                    "Research running techniques and injury prevention",
                    "Learn about the history of Olympic sports"
                ]
            ),
            
            // MARK: - Creative Arts & Crafts
            Hobby(
                name: "Drawing & Sketching",
                category: [.arts, .creative],
                description: "Creating artwork through pencil drawing, sketching, and illustration",
                academicRelevance: [.art, .science],
                popularityScore: 81,
                isFeatured: true,
                academicBenefits: "Develops observational skills, spatial reasoning, and understanding of light and shadow",
                skillsDeveloped: [.creativity, .criticalThinking, .emotionalIntelligence, .timeManagement],
                educationalActivities: [
                    "Study anatomy for figure drawing",
                    "Learn about perspective and composition",
                    "Research famous artists and art movements",
                    "Create scientific illustrations for biology",
                    "Document nature through botanical sketches"
                ]
            ),
            
            Hobby(
                name: "Digital Art & Design",
                category: [.arts, .creative, .technology],
                description: "Creating digital artwork using software like Photoshop, Procreate, or Illustrator",
                academicRelevance: [.art, .computerScience],
                popularityScore: 79,
                academicBenefits: "Combines artistic creativity with technical software skills and design principles",
                skillsDeveloped: [.creativity, .problemSolving, .adaptability, .criticalThinking],
                educationalActivities: [
                    "Learn different digital art software and tools",
                    "Study color theory and digital composition",
                    "Create infographics for school projects",
                    "Design posters and promotional materials",
                    "Explore careers in graphic design and animation"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Photography",
                category: [.arts, .creative, .technology],
                description: "Taking and editing photographs of people, nature, events, and artistic subjects",
                academicRelevance: [.art, .science],
                popularityScore: 77,
                academicBenefits: "Teaches principles of light, composition, technology, and visual storytelling",
                skillsDeveloped: [.creativity, .criticalThinking, .timeManagement, .adaptability],
                educationalActivities: [
                    "Study composition techniques and rule of thirds",
                    "Learn photo editing software and techniques",
                    "Create photo essays about social issues",
                    "Document school events and activities",
                    "Research famous photographers and their styles"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Jewelry Making & Crafts",
                category: [.arts, .creative],
                description: "Creating handmade jewelry, accessories, and small craft projects",
                academicRelevance: [.art, .mathematics],
                popularityScore: 64,
                academicBenefits: "Develops fine motor skills, geometric understanding, and business/entrepreneurial thinking",
                skillsDeveloped: [.creativity, .timeManagement, .problemSolving, .adaptability],
                educationalActivities: [
                    "Learn about different materials and their properties",
                    "Study geometric patterns in jewelry design",
                    "Research cultural jewelry traditions",
                    "Calculate costs and pricing for selling crafts",
                    "Create gifts for family and community events"
                ]
            ),
            
            // MARK: - Music & Performance
            Hobby(
                id: UUID(),
                name: "Guitar Playing",
                category: [.music],
                description: "Learning and playing acoustic or electric guitar",
                academicRelevance: [.music, .mathematics],
                popularityScore: 83,
                isFeatured: true,
                academicBenefits: "Develops mathematical pattern recognition, memory skills, and music theory understanding",
                skillsDeveloped: [.creativity, .timeManagement, .resilience, .emotionalIntelligence],
                educationalActivities: [
                    "Learn music theory and chord progressions",
                    "Study different musical genres and their history",
                    "Practice daily scales and technical exercises",
                    "Perform for friends, family, and school events",
                    "Research famous guitarists and their techniques"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Piano & Keyboard",
                category: [.music],
                description: "Playing piano or electronic keyboard instruments",
                academicRelevance: [.music, .mathematics],
                popularityScore: 75,
                academicBenefits: "Strengthens mathematical thinking, hand-eye coordination, and music theory knowledge",
                skillsDeveloped: [.creativity, .timeManagement, .resilience, .criticalThinking],
                educationalActivities: [
                    "Learn to read musical notation and sheet music",
                    "Study classical and contemporary piano pieces",
                    "Compose original melodies and songs",
                    "Accompany school choirs or other musicians",
                    "Research piano history and famous composers"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Singing & Vocal Performance",
                category: [.music],
                description: "Solo singing, choir participation, or vocal performance",
                academicRelevance: [.music, .english],
                popularityScore: 71,
                academicBenefits: "Improves language skills, breath control, and performance confidence",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence, .resilience],
                educationalActivities: [
                    "Learn proper vocal techniques and breath control",
                    "Study lyrics and their literary meanings",
                    "Participate in school choir or musical theater",
                    "Research different vocal styles and genres",
                    "Perform at talent shows and community events"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Music Production & Beatmaking",
                category: [.music, .creative, .technology],
                description: "Creating original music using digital audio workstations and beat-making software",
                academicRelevance: [.music, .computerScience, .mathematics],
                popularityScore: 80,
                academicBenefits: "Combines music theory with technology skills and mathematical pattern understanding",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement, .adaptability],
                educationalActivities: [
                    "Learn digital audio workstation software",
                    "Study different musical genres and production styles",
                    "Create original beats and instrumental tracks",
                    "Collaborate with other musicians and vocalists",
                    "Research music industry and career opportunities"
                ]
            ),
            
            // MARK: - Reading & Writing
            Hobby(
                id: UUID(),
                name: "Reading Fiction & Novels",
                category: [.reading],
                description: "Reading fiction books, novels, fantasy, sci-fi, and other literary genres",
                academicRelevance: [.english, .history],
                popularityScore: 73,
                academicBenefits: "Enhances vocabulary, reading comprehension, critical thinking, and cultural awareness",
                skillsDeveloped: [.creativity, .emotionalIntelligence, .criticalThinking, .communication],
                educationalActivities: [
                    "Join book clubs and reading discussion groups",
                    "Write book reviews and literary analyses",
                    "Research authors and their historical contexts",
                    "Create reading lists for different genres",
                    "Recommend books to friends and classmates"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Creative Writing & Journaling",
                category: [.creative, .reading],
                description: "Writing stories, poetry, personal journals, and creative non-fiction",
                academicRelevance: [.english],
                popularityScore: 68,
                academicBenefits: "Develops writing skills, self-reflection abilities, and creative expression techniques",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence, .criticalThinking],
                educationalActivities: [
                    "Write daily journal entries and personal reflections",
                    "Create short stories and poetry collections",
                    "Participate in writing contests and competitions",
                    "Share writing with peer review groups",
                    "Study different writing styles and techniques"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Comic Books & Graphic Novels",
                category: [.reading, .arts],
                description: "Reading and collecting comic books, graphic novels, and manga",
                academicRelevance: [.english, .art, .history],
                popularityScore: 76,
                academicBenefits: "Combines visual literacy with reading comprehension and storytelling analysis",
                skillsDeveloped: [.creativity, .criticalThinking, .emotionalIntelligence, .communication],
                educationalActivities: [
                    "Analyze storytelling techniques in graphic novels",
                    "Study the history and evolution of comics",
                    "Create original comic strips or stories",
                    "Research comic book artists and their styles",
                    "Discuss themes and social issues in graphic literature"
                ]
            ),
            
            // MARK: - Gaming & Technology
            Hobby(
                id: UUID(),
                name: "Video Gaming",
                category: [.gaming, .technology],
                description: "Playing video games across different platforms and genres",
                academicRelevance: [.computerScience, .english],
                popularityScore: 90,
                isFeatured: true,
                academicBenefits: "Develops problem-solving skills, strategic thinking, and narrative analysis abilities",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability, .teamwork],
                educationalActivities: [
                    "Analyze game narratives and character development",
                    "Study game design principles and mechanics",
                    "Learn about the gaming industry and careers",
                    "Create game mods or custom levels",
                    "Research the psychology of gaming and motivation"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Board Games & Strategy Games",
                category: [.gaming, .learning, .social],
                description: "Playing tabletop board games, strategy games, and puzzle games",
                academicRelevance: [.mathematics, .socialStudies],
                popularityScore: 67,
                academicBenefits: "Strengthens strategic thinking, mathematical reasoning, and social interaction skills",
                skillsDeveloped: [.criticalThinking, .problemSolving, .teamwork, .communication],
                educationalActivities: [
                    "Learn complex strategy games and their rules",
                    "Analyze winning strategies and probability",
                    "Create custom game variants and house rules",
                    "Organize game nights and tournaments",
                    "Research the history and cultural impact of games"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Computer Programming & Coding",
                category: [.technology, .learning],
                description: "Learning programming languages and creating software projects",
                academicRelevance: [.computerScience, .mathematics],
                popularityScore: 74,
                academicBenefits: "Develops logical thinking, problem-solving skills, and mathematical reasoning",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability, .timeManagement],
                educationalActivities: [
                    "Create simple games and applications",
                    "Build websites and online portfolios",
                    "Participate in coding challenges and hackathons",
                    "Learn different programming languages",
                    "Research computer science careers and opportunities"
                ]
            ),
            
            // MARK: - Cooking & Food
            Hobby(
                id: UUID(),
                name: "Cooking & Baking",
                category: [.cooking],
                description: "Preparing meals, baking desserts, and experimenting with recipes",
                academicRelevance: [.science, .mathematics],
                popularityScore: 78,
                isFeatured: true,
                academicBenefits: "Teaches chemistry concepts, measurement skills, and cultural studies through cuisine",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement, .adaptability],
                educationalActivities: [
                    "Study food chemistry and cooking science",
                    "Learn about different cultural cuisines",
                    "Create family recipe collections",
                    "Calculate nutritional values and costs",
                    "Research sustainable cooking and food sources"
                ]
            ),
            
            // MARK: - Outdoor & Nature Activities
            Hobby(
                id: UUID(),
                name: "Hiking & Nature Exploration",
                category: [.outdoors],
                description: "Hiking trails, exploring nature, camping, and outdoor adventures",
                academicRelevance: [.science, .physicalEducation],
                popularityScore: 71,
                academicBenefits: "Teaches environmental science, geography, and promotes physical fitness",
                skillsDeveloped: [.resilience, .adaptability, .criticalThinking, .problemSolving],
                educationalActivities: [
                    "Identify local plants, animals, and ecosystems",
                    "Learn navigation and outdoor survival skills",
                    "Study environmental conservation efforts",
                    "Track weather patterns and seasonal changes",
                    "Document nature through photography and journaling"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Gardening & Plant Care",
                category: [.outdoors, .learning],
                description: "Growing plants, vegetables, flowers, and maintaining gardens",
                academicRelevance: [.science, .mathematics],
                popularityScore: 63,
                academicBenefits: "Teaches biology, chemistry, environmental science, and patience through cultivation",
                skillsDeveloped: [.timeManagement, .resilience, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Study plant biology and growth cycles",
                    "Learn about soil composition and nutrients",
                    "Research sustainable gardening practices",
                    "Track plant growth with data and measurements",
                    "Create a school or community garden project"
                ]
            ),
            
            // MARK: - Collecting & Organizing
            Hobby(
                id: UUID(),
                name: "Trading Card Collection",
                category: [.collecting, .gaming],
                description: "Collecting and trading sports cards, Pokemon cards, or other collectible card games",
                academicRelevance: [.mathematics, .socialStudies],
                popularityScore: 70,
                academicBenefits: "Develops mathematical skills through statistics, probability, and market value analysis",
                skillsDeveloped: [.criticalThinking, .problemSolving, .communication, .timeManagement],
                educationalActivities: [
                    "Research card values and market trends",
                    "Learn about the history behind collectible subjects",
                    "Calculate statistics and probabilities",
                    "Organize and catalog collections systematically",
                    "Trade and negotiate with other collectors"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Model Building & Scale Models",
                category: [.collecting, .creative, .technology],
                description: "Building model airplanes, cars, trains, or architectural scale models",
                academicRelevance: [.science, .mathematics, .art],
                popularityScore: 59,
                academicBenefits: "Combines engineering principles, mathematical scaling, and historical knowledge",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement, .criticalThinking],
                educationalActivities: [
                    "Research the history of model subjects",
                    "Learn about scale ratios and proportions",
                    "Study engineering and design principles",
                    "Practice precision and attention to detail",
                    "Create dioramas and display environments"
                ]
            ),
            
            // MARK: - Social & Community Activities
            Hobby(
                id: UUID(),
                name: "Volunteer Work & Community Service",
                category: [.social],
                description: "Participating in community service projects and volunteer organizations",
                academicRelevance: [.socialStudies, .english],
                popularityScore: 66,
                academicBenefits: "Develops civic responsibility, communication skills, and understanding of social issues",
                skillsDeveloped: [.leadership, .communication, .emotionalIntelligence, .teamwork],
                educationalActivities: [
                    "Research community needs and social issues",
                    "Organize charity drives and fundraising events",
                    "Tutor younger students or community members",
                    "Participate in environmental cleanup projects",
                    "Document service experiences through reflection"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Event Planning & Organization",
                category: [.social, .creative],
                description: "Planning and organizing social events, parties, fundraisers, and community gatherings",
                academicRelevance: [.mathematics, .english, .socialStudies],
                popularityScore: 61,
                academicBenefits: "Teaches project management, budgeting, communication, and organizational skills",
                skillsDeveloped: [.leadership, .communication, .problemSolving, .timeManagement],
                educationalActivities: [
                    "Create detailed event timelines and budgets",
                    "Learn about marketing and promotion strategies",
                    "Coordinate with vendors and community partners",
                    "Practice public speaking and presentation skills",
                    "Evaluate event success and areas for improvement"
                ]
            ),
            
            // MARK: - Individual Learning & Skills
            Hobby(
                id: UUID(),
                name: "Chess & Strategic Thinking",
                category: [.learning, .gaming],
                description: "Playing chess competitively and studying chess strategy",
                academicRelevance: [.mathematics, .socialStudies],
                popularityScore: 65,
                academicBenefits: "Develops strategic thinking, pattern recognition, and logical reasoning skills",
                skillsDeveloped: [.criticalThinking, .problemSolving, .timeManagement, .resilience],
                educationalActivities: [
                    "Study famous chess games and strategies",
                    "Learn chess notation and record games",
                    "Participate in school or community chess clubs",
                    "Research chess history and famous players",
                    "Teach chess to younger students or friends"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Language Learning",
                category: [.learning],
                description: "Learning foreign languages through apps, classes, or immersion experiences",
                academicRelevance: [.foreignLanguage, .socialStudies],
                popularityScore: 58,
                academicBenefits: "Enhances cognitive flexibility, cultural awareness, and communication abilities",
                skillsDeveloped: [.communication, .adaptability, .emotionalIntelligence, .timeManagement],
                educationalActivities: [
                    "Practice conversation with native speakers",
                    "Study cultural contexts and traditions",
                    "Watch foreign films and read international literature",
                    "Connect with international pen pals or exchange students",
                    "Research career opportunities requiring language skills"
                ]
            ),
            
            Hobby(
                id: UUID(),
                name: "Science Experiments & Discovery",
                category: [.learning, .technology],
                description: "Conducting science experiments, building science fair projects, and exploring scientific concepts",
                academicRelevance: [.science, .mathematics],
                popularityScore: 62,
                academicBenefits: "Strengthens scientific method, hypothesis testing, and analytical thinking skills",
                skillsDeveloped: [.criticalThinking, .problemSolving, .adaptability, .communication],
                educationalActivities: [
                    "Design and conduct independent research projects",
                    "Participate in science fairs and competitions",
                    "Build simple machines and test their efficiency",
                    "Study current scientific discoveries and breakthroughs",
                    "Create educational presentations about scientific concepts"
                ]
            )
        ]
    }
}
