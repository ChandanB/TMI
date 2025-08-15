// Hobby.swift

import Foundation
import SwiftUI
import SwiftData
import FirebaseFirestore

final class Hobby: Identifiable, Hashable, Codable, @unchecked Sendable {
    // MARK: - Equatable Implementation
    static func == (lhs: Hobby, rhs: Hobby) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Firebase Integration
    @DocumentID var firestoreID: String?
    
    // MARK: - Core Properties
    var id: UUID
    var name: String
    var category: [HobbyCategory]
    var description: String?
    var academicRelevance: [AcademicSubject]
    var popularityScore: Int?
    var isFeatured: Bool
    
    // MARK: - TMI Specific Properties
    var academicBenefits: String?
    var skillsDeveloped: [Skill]?
    var relatedInterests: [String]?
    var educationalActivities: [String]?
    var relatedStudents: [String]?
    
    // MARK: - Schema Versioning
    var schemaVersion: Int = 1
    
    // MARK: - Initializers
    init(
        id: UUID = UUID(),
        firestoreID: String? = nil,
        name: String,
        category: [HobbyCategory],
        description: String? = nil,
        academicRelevance: [AcademicSubject] = [],
        popularityScore: Int? = nil,
        isFeatured: Bool = false,
        academicBenefits: String? = nil,
        skillsDeveloped: [Skill]? = nil,
        relatedInterests: [String]? = nil,
        educationalActivities: [String]? = nil,
        relatedStudents: [String]? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.firestoreID = firestoreID
        self.name = name
        self.category = category
        self.description = description
        self.academicRelevance = academicRelevance
        self.popularityScore = popularityScore
        self.isFeatured = isFeatured
        self.academicBenefits = academicBenefits
        self.skillsDeveloped = skillsDeveloped
        self.relatedInterests = relatedInterests
        self.educationalActivities = educationalActivities
        self.relatedStudents = relatedStudents
        self.schemaVersion = schemaVersion
    }
    
    // Simple initializer with category
    convenience init(name: String, category: HobbyCategory) {
        self.init(name: name, category: [category])
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, firestoreID, name, category, description, academicRelevance
        case popularityScore, isFeatured, academicBenefits, skillsDeveloped
        case relatedInterests, educationalActivities, relatedStudents, schemaVersion
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        firestoreID = try container.decodeIfPresent(String.self, forKey: .firestoreID)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode([HobbyCategory].self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        academicRelevance = try container.decodeIfPresent([AcademicSubject].self, forKey: .academicRelevance) ?? []
        popularityScore = try container.decodeIfPresent(Int.self, forKey: .popularityScore)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        academicBenefits = try container.decodeIfPresent(String.self, forKey: .academicBenefits)
        skillsDeveloped = try container.decodeIfPresent([Skill].self, forKey: .skillsDeveloped)
        relatedInterests = try container.decodeIfPresent([String].self, forKey: .relatedInterests)
        educationalActivities = try container.decodeIfPresent([String].self, forKey: .educationalActivities)
        relatedStudents = try container.decodeIfPresent([String].self, forKey: .relatedStudents)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(firestoreID, forKey: .firestoreID)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(academicRelevance, forKey: .academicRelevance)
        try container.encodeIfPresent(popularityScore, forKey: .popularityScore)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encodeIfPresent(academicBenefits, forKey: .academicBenefits)
        try container.encodeIfPresent(skillsDeveloped, forKey: .skillsDeveloped)
        try container.encodeIfPresent(relatedInterests, forKey: .relatedInterests)
        try container.encodeIfPresent(educationalActivities, forKey: .educationalActivities)
        try container.encodeIfPresent(relatedStudents, forKey: .relatedStudents)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }
    
    // MARK: - Firebase Methods
    
    /// Create a hobby from a Firestore document
    static func fromFirestore(id: String, data: [String: Any]) -> Hobby? {
        guard let name = data["name"] as? String else { return nil }
        
        // Parse categories
        var categories: [HobbyCategory] = []
        if let categoryStrings = data["category"] as? [String] {
            categories = categoryStrings.compactMap { HobbyCategory(rawValue: $0) }
        }
        
        // Parse academic subjects
        var subjects: [AcademicSubject] = []
        if let subjectStrings = data["academicRelevance"] as? [String] {
            subjects = subjectStrings.compactMap { AcademicSubject(rawValue: $0) }
        }
        
        // Parse skills
        var skills: [Skill]?
        if let skillStrings = data["skillsDeveloped"] as? [String] {
            skills = skillStrings.compactMap { Skill(rawValue: $0) }
        }
        
        return Hobby(
            id: UUID(uuidString: data["id"] as? String ?? UUID().uuidString) ?? UUID(),
            firestoreID: id,
            name: name,
            category: categories.isEmpty ? [.other] : categories,
            description: data["description"] as? String,
            academicRelevance: subjects,
            popularityScore: data["popularityScore"] as? Int,
            isFeatured: data["isFeatured"] as? Bool ?? false,
            academicBenefits: data["academicBenefits"] as? String,
            skillsDeveloped: skills,
            relatedInterests: data["relatedInterests"] as? [String],
            educationalActivities: data["educationalActivities"] as? [String],
            relatedStudents: data["relatedStudents"] as? [String],
            schemaVersion: data["schemaVersion"] as? Int ?? 1
        )
    }
    
    /// Convert to Firestore data dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "category": category.map { $0.rawValue },
            "academicRelevance": academicRelevance.map { $0.rawValue },
            "isFeatured": isFeatured,
            "schemaVersion": schemaVersion
        ]
        
        if let description = description { data["description"] = description }
        if let popularityScore = popularityScore { data["popularityScore"] = popularityScore }
        if let academicBenefits = academicBenefits { data["academicBenefits"] = academicBenefits }
        if let skillsDeveloped = skillsDeveloped {
            data["skillsDeveloped"] = skillsDeveloped.map { $0.rawValue }
        }
        if let relatedInterests = relatedInterests { data["relatedInterests"] = relatedInterests }
        if let educationalActivities = educationalActivities {
            data["educationalActivities"] = educationalActivities
        }
        if let relatedStudents = relatedStudents { data["relatedStudents"] = relatedStudents }
        
        return data
    }
    
    // MARK: - TMI Specific Methods
    
    /// Match hobby to academic subjects
    func academicMatches(forSubject subject: AcademicSubject) -> Bool {
        return academicRelevance.contains(subject)
    }
    
    /// Add an academic subject if not already present
    func addAcademicSubject(_ subject: AcademicSubject) {
        if !academicRelevance.contains(subject) {
            academicRelevance.append(subject)
        }
    }
    
    // MARK: - Computed Properties
    
    var primaryCategory: HobbyCategory? {
        return category.first
    }
    
    var iconName: String {
        return primaryCategory?.iconName ?? "questionmark"
    }
    
    var color: Color {
        return primaryCategory?.color ?? .gray
    }
    
    static var collectionName: String { "hobbies" }
}

// MARK: - HobbyCategory Extension

enum HobbyCategory: String, CaseIterable, Identifiable, Codable {
    case sports = "Sports"
    case arts = "Arts & Crafts"
    case music = "Music"
    case reading = "Reading"
    case gaming = "Gaming"
    case cooking = "Cooking"
    case outdoors = "Outdoors"
    case collecting = "Collecting"
    case technology = "Technology"
    case learning = "Learning"
    case social = "Social"
    case creative = "Creative"
    case other = "Other"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .sports: return "figure.run"
        case .arts: return "paintpalette.fill"
        case .music: return "music.note"
        case .reading: return "book.fill"
        case .gaming: return "gamecontroller.fill"
        case .cooking: return "fork.knife"
        case .outdoors: return "leaf.fill"
        case .collecting: return "square.grid.2x2.fill"
        case .technology: return "desktopcomputer"
        case .learning: return "brain.head.profile"
        case .social: return "person.3.fill"
        case .creative: return "pencil.and.outline"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .sports: return Color.green
        case .arts: return Color.purple
        case .music: return Color(red: 0.6, green: 0, blue: 0.9)
        case .reading: return Color(red: 0.6, green: 0.3, blue: 0)
        case .gaming: return Color(red: 0.8, green: 0.15, blue: 0.2)
        case .cooking: return Color(red: 1, green: 0.5, blue: 0.2)
        case .outdoors: return Color(red: 0.2, green: 0.6, blue: 0)
        case .collecting: return Color(red: 0.8, green: 0.6, blue: 0.3)
        case .technology: return Color(red: 0, green: 0.7, blue: 0.9)
        case .learning: return Color.blue
        case .social: return Color(red: 0, green: 0.5, blue: 0.7)
        case .creative: return Color(red: 1, green: 0.3, blue: 0.5)
        case .other: return Color.gray
        }
    }
    
    var relatedSubjects: [AcademicSubject] {
        switch self {
        case .sports:
            return [.physicalEducation]
        case .arts:
            return [.art]
        case .music:
            return [.music]
        case .reading:
            return [.english, .history]
        case .gaming:
            return [.computerScience]
        case .cooking:
            return [.science]
        case .outdoors:
            return [.science, .physicalEducation]
        case .collecting:
            return [.history, .socialStudies]
        case .technology:
            return [.computerScience, .mathematics]
        case .learning:
            return AcademicSubject.allCases
        case .social:
            return [.socialStudies]
        case .creative:
            return [.art, .english, .music]
        case .other:
            return []
        }
    }
}

// MARK: - Sample Data Extension

extension Hobby {
    static var sampleHobbies: [Hobby] {
        return [
            // Sports & Physical Activities
            Hobby(
                name: "Basketball",
                category: [.sports],
                description: "Playing basketball regularly at recreational and competitive levels",
                academicRelevance: [.physicalEducation, .mathematics],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Improves coordination, understanding of statistics, and spatial reasoning",
                skillsDeveloped: [.teamwork, .leadership, .resilience, .timeManagement],
                educationalActivities: [
                    "Track personal and team statistics",
                    "Learn about basketball history and legends",
                    "Study game strategies and play analysis",
                    "Analyze shooting percentages and improve accuracy"
                ]
            ),
            
            Hobby(
                name: "Soccer",
                category: [.sports],
                description: "Playing and following soccer/football locally and internationally",
                academicRelevance: [.physicalEducation, .mathematics, .socialStudies],
                popularityScore: 88,
                academicBenefits: "Develops strategic thinking, global awareness, and physical coordination",
                skillsDeveloped: [.teamwork, .resilience, .adaptability, .leadership],
                educationalActivities: [
                    "Study World Cup history and international teams",
                    "Analyze team formations and tactics",
                    "Learn about soccer cultures around the world",
                    "Track fitness and performance improvements"
                ]
            ),
            
            Hobby(
                name: "Running & Track",
                category: [.sports, .outdoors],
                description: "Distance running, sprinting, and track field events",
                academicRelevance: [.physicalEducation, .science, .mathematics],
                popularityScore: 74,
                academicBenefits: "Teaches goal-setting, data tracking, and understanding of human physiology",
                skillsDeveloped: [.resilience, .timeManagement, .problemSolving],
                educationalActivities: [
                    "Track running times and analyze improvements",
                    "Study exercise physiology and nutrition",
                    "Set and achieve personal running goals",
                    "Learn about famous marathons and athletes"
                ]
            ),
            
            Hobby(
                name: "Swimming",
                category: [.sports],
                description: "Swimming for fitness, competition, and recreation",
                academicRelevance: [.physicalEducation, .science],
                popularityScore: 71,
                academicBenefits: "Develops understanding of physics principles and body mechanics",
                skillsDeveloped: [.resilience, .timeManagement, .problemSolving],
                educationalActivities: [
                    "Study different swimming strokes and techniques",
                    "Learn about water safety and lifesaving",
                    "Track swim times and distances",
                    "Understand the physics of buoyancy and drag"
                ]
            ),
            
            // Creative Arts & Crafts
            Hobby(
                name: "Drawing & Sketching",
                category: [.arts, .creative],
                description: "Creating drawings, sketches, and artistic illustrations",
                academicRelevance: [.art, .science],
                popularityScore: 76,
                academicBenefits: "Develops observation skills, spatial reasoning, and artistic techniques",
                skillsDeveloped: [.creativity, .criticalThinking, .timeManagement],
                educationalActivities: [
                    "Study different drawing techniques and styles",
                    "Create scientific illustrations and diagrams",
                    "Practice perspective and proportion",
                    "Sketch from life and nature observations"
                ]
            ),
            
            Hobby(
                name: "Photography",
                category: [.arts, .creative, .technology],
                description: "Taking and editing photographs of various subjects",
                academicRelevance: [.art, .science, .computerScience],
                popularityScore: 78,
                isFeatured: true,
                academicBenefits: "Teaches principles of light, composition, digital editing, and visual storytelling",
                skillsDeveloped: [.creativity, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Study composition techniques and rule of thirds",
                    "Learn photo editing software like Photoshop",
                    "Create themed photo collections and portfolios",
                    "Understand camera settings and light physics"
                ]
            ),
            
            Hobby(
                name: "Painting & Watercolors",
                category: [.arts, .creative],
                description: "Creating paintings using various mediums and techniques",
                academicRelevance: [.art, .science],
                popularityScore: 67,
                academicBenefits: "Develops color theory, composition skills, and artistic expression",
                skillsDeveloped: [.creativity, .timeManagement, .resilience],
                educationalActivities: [
                    "Study famous artists and painting styles",
                    "Learn color theory and mixing techniques",
                    "Paint landscapes and nature studies",
                    "Experiment with different painting mediums"
                ]
            ),
            
            Hobby(
                name: "Jewelry Making",
                category: [.arts, .creative],
                description: "Designing and creating jewelry and accessories",
                academicRelevance: [.art, .mathematics],
                popularityScore: 63,
                academicBenefits: "Develops fine motor skills, design principles, and geometric understanding",
                skillsDeveloped: [.creativity, .timeManagement, .problemSolving],
                educationalActivities: [
                    "Learn about different metals and gemstones",
                    "Study jewelry design principles",
                    "Practice wire wrapping and beading techniques",
                    "Create custom pieces for special occasions"
                ]
            ),
            
            // Music & Performance
            Hobby(
                name: "Guitar Playing",
                category: [.music],
                description: "Learning and playing acoustic or electric guitar",
                academicRelevance: [.music, .mathematics],
                popularityScore: 75,
                academicBenefits: "Develops pattern recognition, rhythm skills, and musical theory understanding",
                skillsDeveloped: [.creativity, .timeManagement, .resilience, .emotionalIntelligence],
                educationalActivities: [
                    "Learn music theory and chord progressions",
                    "Practice daily scales and finger exercises",
                    "Perform for friends, family, and school events",
                    "Study different musical genres and guitar styles"
                ]
            ),
            
            Hobby(
                name: "Piano & Keyboard",
                category: [.music],
                description: "Playing piano and electronic keyboards",
                academicRelevance: [.music, .mathematics],
                popularityScore: 73,
                academicBenefits: "Enhances mathematical thinking, coordination, and musical comprehension",
                skillsDeveloped: [.creativity, .timeManagement, .resilience],
                educationalActivities: [
                    "Learn classical and contemporary pieces",
                    "Study music composition and arrangement",
                    "Practice scales and musical exercises",
                    "Perform in recitals and school concerts"
                ]
            ),
            
            Hobby(
                name: "Singing & Vocals",
                category: [.music],
                description: "Developing vocal skills and performing songs",
                academicRelevance: [.music, .english],
                popularityScore: 69,
                academicBenefits: "Improves breath control, language skills, and musical expression",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence],
                educationalActivities: [
                    "Practice vocal warm-ups and breathing exercises",
                    "Learn songs from different cultures and eras",
                    "Perform in school choirs or talent shows",
                    "Study vocal techniques and music interpretation"
                ]
            ),
            
            // Reading & Literature
            Hobby(
                name: "Reading Fiction",
                category: [.reading],
                description: "Reading novels, short stories, and fictional works",
                academicRelevance: [.english, .history],
                popularityScore: 70,
                academicBenefits: "Enhances vocabulary, comprehension skills, and cultural understanding",
                skillsDeveloped: [.creativity, .emotionalIntelligence, .criticalThinking],
                educationalActivities: [
                    "Join or start a book club with peers",
                    "Write book reviews and character analyses",
                    "Explore different genres and time periods",
                    "Connect literature to historical and social contexts"
                ]
            ),
            
            Hobby(
                name: "Comic Books & Graphic Novels",
                category: [.reading, .arts],
                description: "Reading and collecting comics and graphic literature",
                academicRelevance: [.english, .art],
                popularityScore: 77,
                academicBenefits: "Develops visual literacy, storytelling appreciation, and artistic awareness",
                skillsDeveloped: [.creativity, .criticalThinking, .emotionalIntelligence],
                educationalActivities: [
                    "Analyze storytelling techniques in comics",
                    "Study the history of comic book art",
                    "Create original comic strips or stories",
                    "Explore comics from different cultures"
                ]
            ),
            
            Hobby(
                name: "Poetry & Creative Writing",
                category: [.reading, .creative],
                description: "Writing and reading poetry and creative literature",
                academicRelevance: [.english],
                popularityScore: 64,
                academicBenefits: "Develops language skills, self-expression, and literary appreciation",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence],
                educationalActivities: [
                    "Write personal poems and short stories",
                    "Study different poetry forms and styles",
                    "Participate in poetry slams or writing contests",
                    "Keep a creative writing journal"
                ]
            ),
            
            // Gaming & Technology
            Hobby(
                name: "Video Gaming",
                category: [.gaming, .technology],
                description: "Playing video games across different platforms and genres",
                academicRelevance: [.computerScience, .english, .mathematics],
                popularityScore: 90,
                isFeatured: true,
                academicBenefits: "Improves problem-solving, strategic thinking, and digital literacy",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability, .teamwork],
                educationalActivities: [
                    "Analyze game narratives and character development",
                    "Learn about game development and programming",
                    "Create game mods or custom levels",
                    "Study the history and evolution of video games"
                ]
            ),
            
            Hobby(
                name: "Board Games & Strategy Games",
                category: [.gaming, .social],
                description: "Playing board games, card games, and strategy games",
                academicRelevance: [.mathematics, .socialStudies],
                popularityScore: 72,
                academicBenefits: "Develops strategic thinking, probability understanding, and social skills",
                skillsDeveloped: [.problemSolving, .criticalThinking, .teamwork],
                educationalActivities: [
                    "Learn classic strategy games like chess",
                    "Organize game nights with friends and family",
                    "Study game theory and probability",
                    "Create original games and rule sets"
                ]
            ),
            
            Hobby(
                name: "Building Models & Miniatures",
                category: [.technology, .creative],
                description: "Building and painting model aircraft, cars, and miniatures",
                academicRelevance: [.art, .science, .mathematics],
                popularityScore: 58,
                academicBenefits: "Develops attention to detail, spatial reasoning, and historical knowledge",
                skillsDeveloped: [.creativity, .timeManagement, .resilience],
                educationalActivities: [
                    "Research historical accuracy for models",
                    "Learn about scale and proportion",
                    "Practice fine motor skills and painting techniques",
                    "Study engineering and design principles"
                ]
            ),
            
            // Cooking & Food
            Hobby(
                name: "Cooking & Baking",
                category: [.cooking],
                description: "Preparing meals, baking desserts, and experimenting with recipes",
                academicRelevance: [.science, .mathematics],
                popularityScore: 68,
                isFeatured: true,
                academicBenefits: "Teaches chemistry concepts, measurement skills, and cultural awareness",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement, .adaptability],
                educationalActivities: [
                    "Study food chemistry and cooking science",
                    "Create and modify recipes",
                    "Learn about cultural cuisines and traditions",
                    "Practice nutrition and healthy cooking"
                ]
            ),
            
            Hobby(
                name: "Gardening & Growing Food",
                category: [.outdoors, .learning],
                description: "Growing vegetables, herbs, and flowers",
                academicRelevance: [.science, .mathematics],
                popularityScore: 61,
                academicBenefits: "Teaches biology, ecology, and sustainable living practices",
                skillsDeveloped: [.problemSolving, .timeManagement, .resilience],
                educationalActivities: [
                    "Study plant biology and growth cycles",
                    "Track growth data and weather patterns",
                    "Learn about sustainable farming practices",
                    "Create a school or community garden project"
                ]
            ),
            
            // Outdoor Activities
            Hobby(
                name: "Hiking & Nature Walking",
                category: [.outdoors],
                description: "Exploring nature trails, parks, and outdoor environments",
                academicRelevance: [.science, .physicalEducation],
                popularityScore: 66,
                academicBenefits: "Develops environmental awareness, physical fitness, and observation skills",
                skillsDeveloped: [.resilience, .adaptability, .problemSolving],
                educationalActivities: [
                    "Study local flora and fauna",
                    "Learn navigation and map reading skills",
                    "Track hiking distances and elevation gains",
                    "Participate in environmental conservation efforts"
                ]
            ),
            
            Hobby(
                name: "Camping & Outdoor Skills",
                category: [.outdoors],
                description: "Camping, survival skills, and outdoor adventures",
                academicRelevance: [.science, .physicalEducation],
                popularityScore: 62,
                academicBenefits: "Teaches practical life skills, environmental science, and self-reliance",
                skillsDeveloped: [.problemSolving, .resilience, .adaptability, .leadership],
                educationalActivities: [
                    "Learn wilderness survival techniques",
                    "Study weather patterns and outdoor safety",
                    "Practice camp cooking and fire safety",
                    "Participate in scouting or outdoor programs"
                ]
            ),
            
            // Collecting & Organization
            Hobby(
                name: "Coin Collecting",
                category: [.collecting, .learning],
                description: "Collecting and studying coins from different countries and eras",
                academicRelevance: [.history, .socialStudies, .mathematics],
                popularityScore: 54,
                academicBenefits: "Develops historical knowledge, research skills, and attention to detail",
                skillsDeveloped: [.criticalThinking, .timeManagement, .problemSolving],
                educationalActivities: [
                    "Research the history behind different coins",
                    "Learn about world currencies and economies",
                    "Study metallurgy and coin production",
                    "Organize and catalog collections systematically"
                ]
            ),
            
            Hobby(
                name: "Trading Cards & Collectibles",
                category: [.collecting, .social],
                description: "Collecting and trading sports cards, Pokemon, or other collectibles",
                academicRelevance: [.mathematics, .socialStudies],
                popularityScore: 75,
                academicBenefits: "Develops mathematical thinking, research skills, and market awareness",
                skillsDeveloped: [.problemSolving, .communication, .criticalThinking],
                educationalActivities: [
                    "Study statistics and player performance data",
                    "Learn about market values and economics",
                    "Practice negotiation and trading skills",
                    "Research card history and production methods"
                ]
            ),
            
            // Social & Learning Activities
            Hobby(
                name: "Volunteering & Community Service",
                category: [.social, .learning],
                description: "Helping in the community through various volunteer activities",
                academicRelevance: [.socialStudies, .english],
                popularityScore: 65,
                academicBenefits: "Develops civic responsibility, communication skills, and social awareness",
                skillsDeveloped: [.leadership, .communication, .emotionalIntelligence, .teamwork],
                educationalActivities: [
                    "Participate in local charity events",
                    "Help at community food banks or shelters",
                    "Tutor younger students in academic subjects",
                    "Organize fundraising events for causes"
                ]
            ),
            
            Hobby(
                name: "Learning Languages",
                category: [.learning, .social],
                description: "Learning foreign languages and exploring different cultures",
                academicRelevance: [.foreignLanguage, .socialStudies],
                popularityScore: 59,
                academicBenefits: "Enhances cognitive flexibility, cultural awareness, and communication skills",
                skillsDeveloped: [.communication, .adaptability, .emotionalIntelligence],
                educationalActivities: [
                    "Practice with native speakers online or locally",
                    "Watch foreign films with subtitles",
                    "Study cultural traditions and celebrations",
                    "Use language learning apps and games"
                ]
            ),
            
            // Technology & Making
            Hobby(
                name: "3D Printing & Design",
                category: [.technology, .creative],
                description: "Designing and printing 3D objects and prototypes",
                academicRelevance: [.computerScience, .art, .mathematics],
                popularityScore: 67,
                academicBenefits: "Combines technology skills with design thinking and spatial reasoning",
                skillsDeveloped: [.creativity, .problemSolving, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Learn 3D modeling software like Tinkercad",
                    "Design solutions to everyday problems",
                    "Study engineering and product design",
                    "Create artistic sculptures and functional objects"
                ]
            ),
            
            Hobby(
                name: "Electronics & Circuits",
                category: [.technology, .learning],
                description: "Building electronic circuits and learning about electronics",
                academicRelevance: [.science, .mathematics, .computerScience],
                popularityScore: 56,
                academicBenefits: "Develops understanding of physics, engineering, and logical thinking",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Build simple circuits with LEDs and resistors",
                    "Learn about electricity and magnetism",
                    "Create electronic projects and inventions",
                    "Study how electronic devices work"
                ]
            )
        ]
    }
}

// MARK: - Array Extensions for Hobbies

extension Array where Element == Hobby {
    /// Filter hobbies relevant to specific academic subjects
    func forAcademicSubject(_ subject: AcademicSubject) -> [Hobby] {
        return self.filter { $0.academicMatches(forSubject: subject) }
    }
    
    /// Get hobbies grouped by academic subject
    func groupedByAcademicSubject() -> [AcademicSubject: [Hobby]] {
        var result: [AcademicSubject: [Hobby]] = [:]
        
        for subject in AcademicSubject.allCases {
            result[subject] = self.filter { $0.academicMatches(forSubject: subject) }
        }
        
        return result
    }
    
    /// Get featured hobbies first, then sort by popularity
    var featuredAndPopular: [Hobby] {
        return self.sorted {
            if $0.isFeatured && !$1.isFeatured {
                return true
            } else if !$0.isFeatured && $1.isFeatured {
                return false
            } else {
                return ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0)
            }
        }
    }
    
    /// Get hobbies that develop specific skills
    func developingSkill(_ skill: Skill) -> [Hobby] {
        return self.filter { $0.skillsDeveloped?.contains(skill) ?? false }
    }
    
    /// Get hobbies by category
    func byCategory(_ category: HobbyCategory) -> [Hobby] {
        return self.filter { $0.category.contains(category) }
    }
    
    /// Get hobbies grouped by category
    func groupedByCategory() -> [HobbyCategory: [Hobby]] {
        var result: [HobbyCategory: [Hobby]] = [:]
        
        for category in HobbyCategory.allCases {
            result[category] = self.filter { $0.category.contains(category) }
        }
        
        return result
    }
    
    /// Find hobbies that match a student's academic needs
    func matchingAcademicNeeds(subjects: [AcademicSubject]) -> [Hobby] {
        return self.filter { hobby in
            !Set(hobby.academicRelevance).isDisjoint(with: Set(subjects))
        }
    }
    
    /// Find hobbies that develop specific skills
    func developingSkills(_ skills: [Skill]) -> [Hobby] {
        return self.filter { hobby in
            guard let hobbySkills = hobby.skillsDeveloped else { return false }
            return !Set(hobbySkills).isDisjoint(with: Set(skills))
        }
    }
}
