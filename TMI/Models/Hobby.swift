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
            Hobby(
                name: "Basketball",
                category: [.sports],
                description: "Playing basketball regularly",
                academicRelevance: [.physicalEducation, .mathematics],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Improves coordination and understanding of statistics",
                skillsDeveloped: [.teamwork, .leadership, .resilience],
                educationalActivities: [
                    "Track personal statistics",
                    "Learn about basketball history",
                    "Study game strategies"
                ]
            ),
            Hobby(
                name: "Reading Fiction",
                category: [.reading],
                description: "Reading fiction novels and short stories",
                academicRelevance: [.english],
                popularityScore: 70,
                academicBenefits: "Enhances vocabulary and comprehension skills",
                skillsDeveloped: [.creativity, .emotionalIntelligence],
                educationalActivities: [
                    "Join a book club",
                    "Write book reviews",
                    "Create character analyses"
                ]
            ),
            Hobby(
                name: "Guitar Playing",
                category: [.music],
                description: "Learning and playing guitar",
                academicRelevance: [.music, .mathematics],
                popularityScore: 75,
                academicBenefits: "Develops pattern recognition and rhythm skills",
                skillsDeveloped: [.creativity, .timeManagement, .resilience],
                educationalActivities: [
                    "Learn music theory",
                    "Practice daily scales",
                    "Perform for friends and family"
                ]
            ),
            Hobby(
                name: "Video Gaming",
                category: [.gaming, .technology],
                description: "Playing video games across different platforms",
                academicRelevance: [.computerScience, .english],
                popularityScore: 90,
                academicBenefits: "Improves problem-solving and strategic thinking",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability],
                educationalActivities: [
                    "Analyze game narratives",
                    "Learn about game development",
                    "Create game mods or levels"
                ]
            ),
            Hobby(
                name: "Cooking",
                category: [.cooking],
                description: "Preparing and experimenting with different recipes",
                academicRelevance: [.science, .mathematics],
                popularityScore: 65,
                isFeatured: true,
                academicBenefits: "Teaches chemistry concepts and measurement skills",
                skillsDeveloped: [.creativity, .problemSolving, .timeManagement],
                educationalActivities: [
                    "Study food chemistry",
                    "Create a recipe book",
                    "Learn about cultural cuisines"
                ]
            ),
            Hobby(
                name: "Photography",
                category: [.arts, .creative, .technology],
                description: "Taking and editing photographs",
                academicRelevance: [.art, .science],
                popularityScore: 72,
                academicBenefits: "Teaches principles of light, composition, and digital editing",
                skillsDeveloped: [.creativity, .criticalThinking],
                educationalActivities: [
                    "Study composition techniques",
                    "Learn photo editing software",
                    "Create themed photo collections"
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
