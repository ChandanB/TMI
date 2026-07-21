// Interest.swift

import Foundation
import SwiftUI
import SwiftData
import FirebaseFirestore

nonisolated struct Interest: Identifiable, Hashable, Codable, Sendable {
    // MARK: - Equatable Implementation
    static func == (lhs: Interest, rhs: Interest) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Firebase Integration
    var id: String?
    
    // MARK: - Core Properties
    var name: String
    var category: [InterestCategory]
    var description: String?
    var academicRelevance: [AcademicSubject]
    var interventionModels: [InterventionModel]
    var popularityScore: Int?
    var isFeatured: Bool
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]

    // MARK: - Library Scope Properties
    var scope: InterestScope
    var districtId: String?
    var ownerUid: String?
    
    // MARK: - TMI Specific Properties
    var academicBenefits: String?
    var careerPathways: [CareerPathway]?
    var educationalActivities: [String]?
    var behavioralBenefits: String?
    var skillsDeveloped: [Skill]?
    var tierRelevance: [InterventionTier]

    // MARK: - Legacy Hobby Properties (for backward compatibility)
    var relatedInterests: [String]?
    var relatedStudents: [String]?
    
    // MARK: - Schema Versioning
    var schemaVersion: Int = 1
    
    // MARK: - Initializers
    init(
        id: String? = nil,
        name: String,
        category: [InterestCategory],
        description: String? = nil,
        academicRelevance: [AcademicSubject] = [],
        interventionModels: [InterventionModel] = [],
        popularityScore: Int? = nil,
        isFeatured: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        scope: InterestScope = .global,
        districtId: String? = nil,
        ownerUid: String? = nil,
        academicBenefits: String? = nil,
        careerPathways: [CareerPathway]? = nil,
        educationalActivities: [String]? = nil,
        behavioralBenefits: String? = nil,
        skillsDeveloped: [Skill]? = nil,
        tierRelevance: [InterventionTier] = [.tier1, .tier2],
        relatedInterests: [String]? = nil,
        relatedStudents: [String]? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.academicRelevance = academicRelevance
        self.interventionModels = interventionModels
        self.popularityScore = popularityScore
        self.isFeatured = isFeatured
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.scope = scope
        self.districtId = districtId
        self.ownerUid = ownerUid
        self.academicBenefits = academicBenefits
        self.careerPathways = careerPathways
        self.educationalActivities = educationalActivities
        self.behavioralBenefits = behavioralBenefits
        self.skillsDeveloped = skillsDeveloped
        self.tierRelevance = tierRelevance
        self.relatedInterests = relatedInterests
        self.relatedStudents = relatedStudents
        self.schemaVersion = schemaVersion
    }
    
    // Simple initializer with category (update to include createdAt)
    init(name: String, category: InterestCategory) {
        self.init(name: name, category: [category], createdAt: Date())
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, firestoreID, name, category, description, academicRelevance, interventionModels
        case popularityScore, isFeatured, createdAt, updatedAt, tags, scope, districtId, ownerUid
        case academicBenefits, careerPathways, educationalActivities
        case behavioralBenefits, skillsDeveloped, tierRelevance, relatedInterests, relatedStudents, schemaVersion
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode([InterestCategory].self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        academicRelevance = try container.decodeIfPresent([AcademicSubject].self, forKey: .academicRelevance) ?? []
        interventionModels = try container.decodeIfPresent([InterventionModel].self, forKey: .interventionModels) ?? []
        popularityScore = try container.decodeIfPresent(Int.self, forKey: .popularityScore)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        scope = try container.decodeIfPresent(InterestScope.self, forKey: .scope) ?? .global
        districtId = try container.decodeIfPresent(String.self, forKey: .districtId)
        ownerUid = try container.decodeIfPresent(String.self, forKey: .ownerUid)
        academicBenefits = try container.decodeIfPresent(String.self, forKey: .academicBenefits)
        careerPathways = try container.decodeIfPresent([CareerPathway].self, forKey: .careerPathways)
        educationalActivities = try container.decodeIfPresent([String].self, forKey: .educationalActivities)
        behavioralBenefits = try container.decodeIfPresent(String.self, forKey: .behavioralBenefits)
        skillsDeveloped = try container.decodeIfPresent([Skill].self, forKey: .skillsDeveloped)
        tierRelevance = try container.decodeIfPresent([InterventionTier].self, forKey: .tierRelevance) ?? [.tier1, .tier2]
        relatedInterests = try container.decodeIfPresent([String].self, forKey: .relatedInterests)
        relatedStudents = try container.decodeIfPresent([String].self, forKey: .relatedStudents)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(academicRelevance, forKey: .academicRelevance)
        try container.encode(interventionModels, forKey: .interventionModels)
        try container.encodeIfPresent(popularityScore, forKey: .popularityScore)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(tags, forKey: .tags)
        try container.encode(scope, forKey: .scope)
        try container.encodeIfPresent(districtId, forKey: .districtId)
        try container.encodeIfPresent(ownerUid, forKey: .ownerUid)
        try container.encodeIfPresent(academicBenefits, forKey: .academicBenefits)
        try container.encodeIfPresent(careerPathways, forKey: .careerPathways)
        try container.encodeIfPresent(educationalActivities, forKey: .educationalActivities)
        try container.encodeIfPresent(behavioralBenefits, forKey: .behavioralBenefits)
        try container.encodeIfPresent(skillsDeveloped, forKey: .skillsDeveloped)
        try container.encode(tierRelevance, forKey: .tierRelevance)
        try container.encodeIfPresent(relatedInterests, forKey: .relatedInterests)
        try container.encodeIfPresent(relatedStudents, forKey: .relatedStudents)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }
    
    // MARK: - Firebase Methods
    
    /// Create an interest from a Firestore document
    static func fromFirestore(id: String, data: [String: Any]) -> Interest? {
        guard let name = data["name"] as? String else { return nil }
        
        // Parse categories
        var categories: [InterestCategory] = []
        if let categoryStrings = data["category"] as? [String] {
            categories = categoryStrings.compactMap { InterestCategory(rawValue: $0) }
        }
        
        // Parse academic subjects
        var subjects: [AcademicSubject] = []
        if let subjectStrings = data["academicRelevance"] as? [String] {
            subjects = subjectStrings.compactMap { AcademicSubject(rawValue: $0) }
        }
        
        // Parse intervention models
        var models: [InterventionModel] = []
        if let modelStrings = data["interventionModels"] as? [String] {
            models = modelStrings.compactMap { InterventionModel(rawValue: $0) }
        }
        
        // Parse tiers
        var tiers: [InterventionTier] = []
        if let tierStrings = data["tierRelevance"] as? [String] {
            tiers = tierStrings.compactMap { InterventionTier(rawValue: $0) }
        } else {
            tiers = [.tier1, .tier2]
        }
        
        let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
        let createdAtDate = createdAtTimestamp.dateValue()

        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        let updatedAtDate = updatedAtTimestamp.dateValue()

        // Parse scope
        let scopeString = data["scope"] as? String ?? "global"
        let scope = InterestScope(rawValue: scopeString) ?? .global

        return Interest(
            id: id,
            name: name,
            category: categories,
            description: data["description"] as? String,
            academicRelevance: subjects,
            interventionModels: models,
            popularityScore: data["popularityScore"] as? Int,
            isFeatured: data["isFeatured"] as? Bool ?? false,
            createdAt: createdAtDate,
            updatedAt: updatedAtDate,
            tags: data["tags"] as? [String] ?? [],
            scope: scope,
            districtId: data["districtId"] as? String,
            ownerUid: data["ownerUid"] as? String,
            academicBenefits: data["academicBenefits"] as? String,
            careerPathways: parseCareerPathways(data["careerPathways"]),
            educationalActivities: data["educationalActivities"] as? [String],
            behavioralBenefits: data["behavioralBenefits"] as? String,
            skillsDeveloped: parseSkills(data["skillsDeveloped"]),
            tierRelevance: tiers,
            relatedInterests: data["relatedInterests"] as? [String],
            relatedStudents: data["relatedStudents"] as? [String],
            schemaVersion: data["schemaVersion"] as? Int ?? 1
        )
    }
    
    private static func parseCareerPathways(_ data: Any?) -> [CareerPathway]? {
        guard let pathwayStrings = data as? [String] else { return nil }
        return pathwayStrings.compactMap { CareerPathway(rawValue: $0) }
    }
    
    private static func parseSkills(_ data: Any?) -> [Skill]? {
        guard let skillStrings = data as? [String] else { return nil }
        return skillStrings.compactMap { Skill(rawValue: $0) }
    }
    
    /// Convert to Firestore data dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id ?? UUID().uuidString,
            "name": name,
            "category": category.map { $0.rawValue },
            "academicRelevance": academicRelevance.map { $0.rawValue },
            "interventionModels": interventionModels.map { $0.rawValue },
            "tierRelevance": tierRelevance.map { $0.rawValue },
            "isFeatured": isFeatured,
            "schemaVersion": schemaVersion,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "tags": tags,
            "scope": scope.rawValue
        ]

        if let description = description { data["description"] = description }
        if let popularityScore = popularityScore { data["popularityScore"] = popularityScore }
        if let districtId = districtId { data["districtId"] = districtId }
        if let ownerUid = ownerUid { data["ownerUid"] = ownerUid }
        if let academicBenefits = academicBenefits { data["academicBenefits"] = academicBenefits }
        if let careerPathways = careerPathways {
            data["careerPathways"] = careerPathways.map { $0.rawValue }
        }
        if let educationalActivities = educationalActivities {
            data["educationalActivities"] = educationalActivities
        }
        if let behavioralBenefits = behavioralBenefits {
            data["behavioralBenefits"] = behavioralBenefits
        }
        if let skillsDeveloped = skillsDeveloped {
            data["skillsDeveloped"] = skillsDeveloped.map { $0.rawValue }
        }
        if let relatedInterests = relatedInterests {
            data["relatedInterests"] = relatedInterests
        }
        if let relatedStudents = relatedStudents {
            data["relatedStudents"] = relatedStudents
        }

        return data
    }
    
    // MARK: - Factory Methods

    /// Create an Interest from legacy Hobby data (for backward compatibility)
    static func fromHobby(
        name: String,
        hobbyCategories: [String],
        description: String? = nil,
        academicRelevance: [AcademicSubject] = [],
        popularityScore: Int? = nil,
        isFeatured: Bool = false,
        academicBenefits: String? = nil,
        skillsDeveloped: [Skill]? = nil,
        relatedInterests: [String]? = nil,
        educationalActivities: [String]? = nil,
        relatedStudents: [String]? = nil
    ) -> Interest {

        // Map hobby categories to interest categories
        let interestCategories = hobbyCategories.compactMap { hobbyCategoryString -> InterestCategory? in
            switch hobbyCategoryString.lowercased() {
            case "sports": return .sports
            case "arts & crafts", "arts": return .arts
            case "music": return .music
            case "reading": return .literature
            case "gaming": return .gaming
            case "cooking": return .cooking
            case "outdoors": return .outdoors
            case "collecting": return .collecting
            case "technology": return .technology
            case "learning": return .learning
            case "social": return .social
            case "creative": return .arts
            default: return .other
            }
        }

        return Interest(
            name: name,
            category: interestCategories.isEmpty ? [.other] : interestCategories,
            description: description,
            academicRelevance: academicRelevance,
            interventionModels: [], // Hobbies don't have intervention models by default
            popularityScore: popularityScore,
            isFeatured: isFeatured,
            academicBenefits: academicBenefits,
            skillsDeveloped: skillsDeveloped,
            tierRelevance: [.tier1, .tier2], // Default for all students
            relatedInterests: relatedInterests,
            relatedStudents: relatedStudents
        )
    }

    // MARK: - TMI Specific Methods

    /// Check if interest is relevant to a specific intervention model
    func isRelevantTo(model: InterventionModel) -> Bool {
        return interventionModels.contains(model)
    }
    
    /// Check if interest is applicable to specific tiers
    func isApplicableTo(tier: InterventionTier) -> Bool {
        return tierRelevance.contains(tier)
    }
    
    /// Match interest to academic subjects
    func academicMatches(forSubject subject: AcademicSubject) -> Bool {
        return academicRelevance.contains(subject)
    }
    
    /// Get activities suitable for a specific intervention model
    func activitiesFor(model: InterventionModel) -> [String] {
        // In a real implementation, this would filter activities by model
        return educationalActivities ?? []
    }
    
    /// Add an intervention model if not already present
    mutating func addInterventionModel(_ model: InterventionModel) {
        if !interventionModels.contains(model) {
            interventionModels.append(model)
        }
    }
    
    /// Add an academic subject if not already present
    mutating func addAcademicSubject(_ subject: AcademicSubject) {
        if !academicRelevance.contains(subject) {
            academicRelevance.append(subject)
        }
    }
    
    // MARK: - Computed Properties
    
    var primaryCategory: InterestCategory? {
        return category.first
    }
    
    var iconName: String {
        return primaryCategory?.iconName ?? "questionmark"
    }
    
    var color: Color {
        return primaryCategory?.color ?? .gray
    }
    
    var isCareerFocused: Bool {
        return careerPathways?.isEmpty == false
    }
}

// MARK: - Support Enums and Types

nonisolated enum InterestScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case global = "global"
    case district = "district"
    case personal = "personal"

    var id: String { rawValue }
}

nonisolated enum InterventionModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case chaseYourSpace = "Chase Your Space"
    case acknowledgeInterests = "Acknowledge Your Interests"
    case alignYourMind = "Align Your Mind"
    case directAndCorrect = "Direct & Correct"
    case fromBully2Boss = "From Bully 2 Boss"
    case fromMeek2Promising = "From Meek & Passive 2 Promising"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .chaseYourSpace:
            return "Help students cultivate their career pathway choices"
        case .acknowledgeInterests:
            return "Support students by acknowledging their interests and hobbies"
        case .alignYourMind:
            return "Keep students focused and on task through their interests"
        case .directAndCorrect:
            return "Help correct negative thoughts and behaviors through interest-based activities"
        case .fromBully2Boss:
            return "Transform bullying behaviors into leadership through guided interests"
        case .fromMeek2Promising:
            return "Help introverted students build confidence through their interests"
        }
    }
    
    var iconName: String {
        switch self {
        case .chaseYourSpace: return "arrow.up.right.circle.fill"
        case .acknowledgeInterests: return "hand.thumbsup.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.triangle.turn.up.right.circle.fill"
        case .fromBully2Boss: return "person.fill.checkmark"
        case .fromMeek2Promising: return "person.fill.badge.plus"
        }
    }
}

nonisolated enum InterventionTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case tier1 = "Tier 1"
    case tier2 = "Tier 2"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .tier1:
            return "Universal support for all students"
        case .tier2:
            return "Targeted support for students with specific needs"
        }
    }
}

nonisolated enum AcademicSubject: String, Codable, CaseIterable, Identifiable, Sendable {
    case mathematics = "Mathematics"
    case english = "English Language Arts"
    case science = "Science"
    case history = "History"
    case socialStudies = "Social Studies"
    case computerScience = "Computer Science"
    case art = "Art"
    case music = "Music"
    case physicalEducation = "Physical Education"
    case foreignLanguage = "Foreign Language"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .mathematics: return "function"
        case .english: return "text.book.closed"
        case .science: return "atom"
        case .history: return "clock.arrow.circlepath"
        case .socialStudies: return "globe"
        case .computerScience: return "desktopcomputer"
        case .art: return "paintpalette"
        case .music: return "music.note"
        case .physicalEducation: return "figure.run"
        case .foreignLanguage: return "text.bubble"
        }
    }
}

nonisolated enum CareerPathway: String, Codable, CaseIterable, Identifiable, Sendable {
    case stem = "STEM"
    case healthcare = "Healthcare"
    case business = "Business & Entrepreneurship"
    case creativeArts = "Creative Arts"
    case education = "Education"
    case trades = "Skilled Trades"
    case publicService = "Public Service"
    case technology = "Technology"
    
    var id: String { rawValue }
}

nonisolated enum Skill: String, Codable, CaseIterable, Identifiable, Sendable {
    case criticalThinking = "Critical Thinking"
    case communication = "Communication"
    case teamwork = "Teamwork"
    case leadership = "Leadership"
    case timeManagement = "Time Management"
    case problemSolving = "Problem Solving"
    case creativity = "Creativity"
    case emotionalIntelligence = "Emotional Intelligence"
    case resilience = "Resilience"
    case adaptability = "Adaptability"
    
    var id: String { rawValue }
}

// MARK: - InterestCategory Extension

nonisolated enum InterestCategory: String, CaseIterable, Identifiable, Codable, Comparable, Equatable, Sendable {
    static func < (lhs: InterestCategory, rhs: InterestCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Core educational categories
    case academics = "Academics"
    case science = "Science & Discovery"
    case technology = "Technology"
    case mathematics = "Mathematics"

    // Creative & expressive categories
    case arts = "Arts & Creativity"
    case music = "Music"
    case literature = "Reading & Writing"
    case crafts = "Making & Building"
    case photography = "Photography"

    // Physical & outdoor categories
    case sports = "Sports & Athletics"
    case outdoors = "Outdoors & Nature"
    case wellness = "Health & Wellness"

    // Social & life skills categories
    case leadership = "Leadership & Service"
    case socialCauses = "Social Causes"
    case social = "Social Activities"
    case communication = "Communication"

    // Entertainment & leisure categories
    case entertainment = "Entertainment & Media"
    case gaming = "Gaming"
    case collecting = "Collecting"

    // Life skills categories
    case cooking = "Cooking & Food"
    case learning = "Learning & Education"
    case languages = "Languages & Culture"

    // Catch-all
    case other = "Other"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        // Core educational
        case .academics: return "book.fill"
        case .science: return "atom"
        case .technology: return "laptopcomputer"
        case .mathematics: return "function"

        // Creative & expressive
        case .arts: return "paintpalette.fill"
        case .music: return "music.note"
        case .literature: return "text.book.closed"
        case .crafts: return "hammer.fill"
        case .photography: return "camera.fill"

        // Physical & outdoor
        case .sports: return "figure.run"
        case .outdoors: return "leaf.fill"
        case .wellness: return "heart.fill"

        // Social & life skills
        case .leadership: return "person.3.fill"
        case .socialCauses: return "hand.raised.fill"
        case .social: return "person.2.fill"
        case .communication: return "text.bubble.fill"

        // Entertainment & leisure
        case .entertainment: return "tv.fill"
        case .gaming: return "gamecontroller.fill"
        case .collecting: return "square.grid.2x2.fill"

        // Life skills
        case .cooking: return "fork.knife"
        case .learning: return "brain.head.profile"
        case .languages: return "globe"

        // Catch-all
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        // Core educational
        case .academics: return Color.blue
        case .science: return Color(red: 0, green: 0.2, blue: 0.5)
        case .technology: return Color(red: 0, green: 0.7, blue: 0.9)
        case .mathematics: return Color(red: 0.2, green: 0.3, blue: 0.7)

        // Creative & expressive
        case .arts: return Color.purple
        case .music: return Color(red: 0.6, green: 0, blue: 0.9)
        case .literature: return Color(red: 0.6, green: 0.3, blue: 0)
        case .crafts: return Color(red: 0.8, green: 0.6, blue: 0.3)
        case .photography: return Color(red: 0.4, green: 0.2, blue: 0.8)

        // Physical & outdoor
        case .sports: return Color.green
        case .outdoors: return Color(red: 0.2, green: 0.6, blue: 0)
        case .wellness: return Color(red: 1, green: 0.3, blue: 0.5)

        // Social & life skills
        case .leadership: return Color(red: 0, green: 0.5, blue: 0.7)
        case .socialCauses: return Color(red: 1, green: 0.5, blue: 0.2)
        case .social: return Color(red: 0.3, green: 0.5, blue: 0.8)
        case .communication: return Color(red: 0.5, green: 0.7, blue: 0.9)

        // Entertainment & leisure
        case .entertainment: return Color(red: 0.8, green: 0.15, blue: 0.2)
        case .gaming: return Color(red: 0.7, green: 0.2, blue: 0.9)
        case .collecting: return Color(red: 0.9, green: 0.7, blue: 0.3)

        // Life skills
        case .cooking: return Color(red: 1, green: 0.5, blue: 0.2)
        case .learning: return Color(red: 0.1, green: 0.4, blue: 0.8)
        case .languages: return Color(red: 0.3, green: 0.6, blue: 0.4)

        // Catch-all
        case .other: return Color.gray
        }
    }
    
    var relatedSubjects: [AcademicSubject] {
        switch self {
        // Core educational
        case .academics:
            return AcademicSubject.allCases
        case .science:
            return [.science, .mathematics]
        case .technology:
            return [.computerScience, .mathematics]
        case .mathematics:
            return [.mathematics, .science]

        // Creative & expressive
        case .arts:
            return [.art, .english]
        case .music:
            return [.music]
        case .literature:
            return [.english, .history]
        case .crafts:
            return [.art, .mathematics]
        case .photography:
            return [.art, .computerScience]

        // Physical & outdoor
        case .sports:
            return [.physicalEducation]
        case .outdoors:
            return [.science, .physicalEducation]
        case .wellness:
            return [.physicalEducation, .science]

        // Social & life skills
        case .leadership:
            return [.socialStudies]
        case .socialCauses:
            return [.socialStudies, .history]
        case .social:
            return [.socialStudies]
        case .communication:
            return [.english, .foreignLanguage]

        // Entertainment & leisure
        case .entertainment:
            return [.art, .english, .music]
        case .gaming:
            return [.computerScience]
        case .collecting:
            return [.history, .socialStudies]

        // Life skills
        case .cooking:
            return [.science]
        case .learning:
            return AcademicSubject.allCases
        case .languages:
            return [.foreignLanguage, .socialStudies, .history]

        // Catch-all
        case .other:
            return []
        }
    }
}

// MARK: - Sample Data Extension

extension Interest {
    static var sampleInterests: [Interest] {
        [
            // STEM & Technology Interests
            Interest(
                name: "Robotics",
                category: [.technology, .science],
                description: "Building and programming robots for competitions and practical applications",
                academicRelevance: [.computerScience, .mathematics, .science],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Improves logical thinking, applied science skills, and engineering concepts",
                careerPathways: [.stem, .technology],
                educationalActivities: [
                    "Build a simple robot using a kit",
                    "Program basic robot movements",
                    "Participate in FIRST Robotics competitions",
                    "Design solutions for real-world problems"
                ],
                behavioralBenefits: "Encourages focus, patience, attention to detail, and collaborative problem-solving",
                skillsDeveloped: [.problemSolving, .criticalThinking, .teamwork, .timeManagement]
            ),
            
            Interest(
                name: "Programming & Coding",
                category: [.technology],
                description: "Learning programming languages and software development",
                academicRelevance: [.computerScience, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 88,
                isFeatured: true,
                academicBenefits: "Strengthens logical thinking, mathematical reasoning, and problem-solving skills",
                careerPathways: [.technology, .stem],
                educationalActivities: [
                    "Create simple games or mobile apps",
                    "Solve coding challenges on platforms like HackerRank",
                    "Build a personal website or portfolio",
                    "Participate in coding competitions"
                ],
                behavioralBenefits: "Develops persistence, analytical thinking, and systematic approach to challenges",
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability, .timeManagement]
            ),
            
            Interest(
                name: "Data Science & Analytics",
                category: [.technology, .science],
                description: "Analyzing data to find patterns and make predictions",
                academicRelevance: [.mathematics, .computerScience, .science],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 79,
                academicBenefits: "Develops statistical thinking, research skills, and data interpretation",
                careerPathways: [.stem, .technology, .business],
                educationalActivities: [
                    "Analyze school survey data",
                    "Create data visualizations",
                    "Study sports or social media statistics",
                    "Build simple prediction models"
                ],
                behavioralBenefits: "Encourages evidence-based thinking and systematic analysis",
                skillsDeveloped: [.criticalThinking, .problemSolving, .communication]
            ),
            
            // Arts & Creative Interests
            Interest(
                name: "Creative Writing",
                category: [.literature, .arts],
                description: "Writing stories, poems, scripts, and other creative works",
                academicRelevance: [.english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 72,
                academicBenefits: "Enhances vocabulary, grammar, self-expression, and critical thinking",
                careerPathways: [.creativeArts, .education],
                educationalActivities: [
                    "Start a personal journal or blog",
                    "Create short stories based on daily experiences",
                    "Participate in writing contests and workshops",
                    "Write for the school newspaper or magazine"
                ],
                behavioralBenefits: "Provides healthy emotional outlet, self-reflection, and confidence building",
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence, .criticalThinking]
            ),
            
            Interest(
                name: "Digital Art & Design",
                category: [.arts, .technology],
                description: "Creating digital artwork, graphics, and visual designs",
                academicRelevance: [.art, .computerScience],
                interventionModels: [.acknowledgeInterests, .chaseYourSpace],
                popularityScore: 81,
                academicBenefits: "Combines artistic creativity with technological skills",
                careerPathways: [.creativeArts, .technology],
                educationalActivities: [
                    "Design posters for school events",
                    "Create digital portfolios",
                    "Learn graphic design software",
                    "Design logos for clubs or organizations"
                ],
                behavioralBenefits: "Builds confidence through creative expression and skill mastery",
                skillsDeveloped: [.creativity, .criticalThinking, .adaptability]
            ),
            
            Interest(
                name: "Theater & Drama",
                category: [.arts, .entertainment],
                description: "Acting, directing, and theater production",
                academicRelevance: [.english, .art, .music, .history],
                interventionModels: [.fromMeek2Promising, .fromBully2Boss, .acknowledgeInterests],
                popularityScore: 68,
                isFeatured: true,
                academicBenefits: "Enhances literary analysis, historical context understanding, and public speaking",
                careerPathways: [.creativeArts, .education],
                educationalActivities: [
                    "Perform in class plays and school productions",
                    "Analyze character motivations in literature",
                    "Write and direct original scripts",
                    "Study theater history and techniques"
                ],
                behavioralBenefits: "Builds confidence, empathy, public speaking skills, and emotional intelligence",
                skillsDeveloped: [.communication, .teamwork, .creativity, .emotionalIntelligence, .leadership]
            ),
            
            // Sports & Physical Activities
            Interest(
                name: "Basketball",
                category: [.sports],
                description: "Playing and analyzing basketball at competitive and recreational levels",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 90,
                academicBenefits: "Teaches statistics, geometry, physics concepts, and data analysis",
                educationalActivities: [
                    "Track and analyze game statistics",
                    "Study the physics of shooting techniques",
                    "Create team strategies and playbooks",
                    "Research basketball history and culture"
                ],
                behavioralBenefits: "Builds teamwork, discipline, positive competitive spirit, and resilience",
                skillsDeveloped: [.teamwork, .leadership, .resilience, .timeManagement]
            ),
            
            Interest(
                name: "Soccer & Football",
                category: [.sports],
                description: "Playing and studying soccer/football tactics and culture",
                academicRelevance: [.physicalEducation, .mathematics, .socialStudies],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 87,
                academicBenefits: "Develops spatial reasoning, strategic thinking, and cultural awareness",
                educationalActivities: [
                    "Analyze team formations and strategies",
                    "Study World Cup history and cultural impact",
                    "Track fitness and performance metrics",
                    "Learn about international soccer cultures"
                ],
                behavioralBenefits: "Promotes teamwork, cultural understanding, and physical fitness",
                skillsDeveloped: [.teamwork, .leadership, .resilience, .adaptability]
            ),
            
            // Science & Environmental Interests
            Interest(
                name: "Environmental Science & Conservation",
                category: [.science, .outdoors, .socialCauses],
                description: "Studying and protecting natural environments and ecosystems",
                academicRelevance: [.science, .socialStudies, .mathematics],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 75,
                isFeatured: true,
                academicBenefits: "Connects biology, chemistry, earth science, and social responsibility",
                careerPathways: [.stem, .publicService],
                educationalActivities: [
                    "Conduct water quality testing projects",
                    "Start a school recycling or sustainability program",
                    "Research local environmental issues",
                    "Participate in community conservation efforts"
                ],
                behavioralBenefits: "Develops community awareness, responsible citizenship, and long-term thinking",
                skillsDeveloped: [.criticalThinking, .problemSolving, .leadership, .communication]
            ),
            
            Interest(
                name: "Astronomy & Space Science",
                category: [.science, .technology],
                description: "Studying space, planets, stars, and the universe",
                academicRelevance: [.science, .mathematics, .computerScience],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 73,
                academicBenefits: "Integrates physics, mathematics, and cutting-edge technology",
                careerPathways: [.stem, .technology],
                educationalActivities: [
                    "Observe and track celestial objects",
                    "Build model rockets or telescopes",
                    "Study space missions and astronaut training",
                    "Participate in astronomy clubs or star parties"
                ],
                behavioralBenefits: "Encourages curiosity, wonder, and systematic observation skills",
                skillsDeveloped: [.criticalThinking, .problemSolving, .adaptability]
            ),
            
            // Music & Performance
            Interest(
                name: "Music Performance & Composition",
                category: [.music, .arts],
                description: "Playing instruments, singing, and creating original music",
                academicRelevance: [.music, .mathematics],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 77,
                academicBenefits: "Develops mathematical patterns, rhythm, and auditory processing skills",
                careerPathways: [.creativeArts, .education],
                educationalActivities: [
                    "Learn music theory and composition",
                    "Perform in school concerts and recitals",
                    "Create original songs or compositions",
                    "Study different musical cultures and genres"
                ],
                behavioralBenefits: "Builds confidence, emotional expression, and performance skills",
                skillsDeveloped: [.creativity, .timeManagement, .resilience, .emotionalIntelligence]
            ),
            
            // Leadership & Social Causes
            Interest(
                name: "Student Government & Leadership",
                category: [.leadership, .socialCauses],
                description: "Leading student organizations and representing peer interests",
                academicRelevance: [.socialStudies, .english],
                interventionModels: [.fromBully2Boss, .chaseYourSpace],
                popularityScore: 69,
                academicBenefits: "Develops civics knowledge, public speaking, and democratic processes",
                careerPathways: [.publicService, .business],
                educationalActivities: [
                    "Run for student council or class office",
                    "Organize school events and initiatives",
                    "Lead community service projects",
                    "Advocate for student rights and interests"
                ],
                behavioralBenefits: "Builds leadership skills, empathy, and social responsibility",
                skillsDeveloped: [.leadership, .communication, .problemSolving, .teamwork]
            ),
            
            Interest(
                name: "Debate & Public Speaking",
                category: [.academics, .leadership],
                description: "Participating in debates, speech competitions, and forensics",
                academicRelevance: [.english, .socialStudies, .history],
                interventionModels: [.fromMeek2Promising, .alignYourMind],
                popularityScore: 66,
                academicBenefits: "Enhances research skills, critical thinking, and argumentation",
                careerPathways: [.business, .publicService, .education],
                educationalActivities: [
                    "Participate in debate tournaments",
                    "Research current events and policy issues",
                    "Practice impromptu speaking",
                    "Analyze rhetorical techniques in speeches"
                ],
                behavioralBenefits: "Builds confidence, critical thinking, and persuasive communication",
                skillsDeveloped: [.communication, .criticalThinking, .resilience, .adaptability]
            ),
            
            // Health & Wellness
            Interest(
                name: "Health & Fitness Science",
                category: [.wellness, .science],
                description: "Understanding human health, nutrition, and physical fitness",
                academicRelevance: [.science, .physicalEducation, .mathematics],
                interventionModels: [.chaseYourSpace, .directAndCorrect],
                popularityScore: 71,
                academicBenefits: "Connects biology, chemistry, and data analysis to personal health",
                careerPathways: [.healthcare, .stem],
                educationalActivities: [
                    "Track fitness goals and analyze progress data",
                    "Study nutrition and its effects on performance",
                    "Research exercise physiology",
                    "Design workout programs for different goals"
                ],
                behavioralBenefits: "Promotes self-care, goal-setting, and healthy lifestyle choices",
                skillsDeveloped: [.problemSolving, .timeManagement, .resilience]
            ),
            
            // Reading & Literature
            Interest(
                name: "Literature & Book Clubs",
                category: [.literature, .academics],
                description: "Reading, analyzing, and discussing various forms of literature",
                academicRelevance: [.english, .history, .socialStudies],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 70,
                academicBenefits: "Enhances vocabulary, comprehension, cultural awareness, and analytical skills",
                educationalActivities: [
                    "Join or start a book club",
                    "Write book reviews and literary analyses",
                    "Explore different genres and time periods",
                    "Connect literature to historical contexts"
                ],
                behavioralBenefits: "Develops empathy, critical thinking, and cultural understanding",
                skillsDeveloped: [.criticalThinking, .communication, .emotionalIntelligence]
            ),
            
            // Business & Entrepreneurship
            Interest(
                name: "Entrepreneurship & Business",
                category: [.academics, .leadership],
                description: "Starting businesses, understanding economics, and developing entrepreneurial skills",
                academicRelevance: [.mathematics, .socialStudies, .english],
                interventionModels: [.chaseYourSpace, .fromBully2Boss],
                popularityScore: 74,
                academicBenefits: "Integrates math, economics, communication, and strategic thinking",
                careerPathways: [.business, .technology],
                educationalActivities: [
                    "Start a small business or online store",
                    "Participate in business plan competitions",
                    "Study successful entrepreneurs and companies",
                    "Learn about financial literacy and investing"
                ],
                behavioralBenefits: "Develops initiative, risk assessment, and goal-oriented thinking",
                skillsDeveloped: [.leadership, .problemSolving, .communication, .adaptability]
            ),
            
            // Language & Culture
            Interest(
                name: "Foreign Languages & Cultures",
                category: [.academics, .socialCauses],
                description: "Learning languages and exploring different cultures worldwide",
                academicRelevance: [.foreignLanguage, .socialStudies, .history],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 68,
                academicBenefits: "Enhances cognitive flexibility, cultural awareness, and communication skills",
                careerPathways: [.education, .publicService, .business],
                educationalActivities: [
                    "Practice conversation with native speakers",
                    "Explore cultural traditions and celebrations",
                    "Watch foreign films with subtitles",
                    "Participate in cultural exchange programs"
                ],
                behavioralBenefits: "Builds cultural empathy, global awareness, and cognitive flexibility",
                skillsDeveloped: [.communication, .adaptability, .emotionalIntelligence]
            ),
            
            // Making & Building
            Interest(
                name: "Engineering & Maker Projects",
                category: [.crafts, .technology, .science],
                description: "Building, designing, and creating physical objects and solutions",
                academicRelevance: [.science, .mathematics, .art],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 76,
                academicBenefits: "Applies physics, engineering principles, and creative problem-solving",
                careerPathways: [.stem, .trades],
                educationalActivities: [
                    "Build bridges, towers, or mechanical devices",
                    "Design solutions to everyday problems",
                    "Participate in engineering challenges",
                    "Learn about different engineering disciplines"
                ],
                behavioralBenefits: "Encourages persistence, creativity, and hands-on learning",
                skillsDeveloped: [.problemSolving, .creativity, .criticalThinking, .teamwork]
            )
        ]
    }
}

// MARK: - Array Extensions for Interests

extension Array where Element == Interest {
    /// Filter interests relevant to a specific intervention model
    func forInterventionModel(_ model: InterventionModel) -> [Interest] {
        return self.filter { $0.isRelevantTo(model: model) }
    }
    
    /// Filter interests for specific tier
    func forTier(_ tier: InterventionTier) -> [Interest] {
        return self.filter { $0.isApplicableTo(tier: tier) }
    }
    
    /// Filter interests relevant to specific academic subjects
    func forAcademicSubject(_ subject: AcademicSubject) -> [Interest] {
        return self.filter { $0.academicMatches(forSubject: subject) }
    }
    
    /// Get interests grouped by intervention model
    func groupedByInterventionModel() -> [InterventionModel: [Interest]] {
        var result: [InterventionModel: [Interest]] = [:]
        
        for model in InterventionModel.allCases {
            result[model] = self.filter { $0.isRelevantTo(model: model) }
        }
        
        return result
    }
    
    /// Get interests grouped by academic subject
    func groupedByAcademicSubject() -> [AcademicSubject: [Interest]] {
        var result: [AcademicSubject: [Interest]] = [:]
        
        for subject in AcademicSubject.allCases {
            result[subject] = self.filter { $0.academicMatches(forSubject: subject) }
        }
        
        return result
    }
    
    /// Get featured interests first, then sort by popularity
    var featuredAndPopular: [Interest] {
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
    
    /// Get interests that develop specific skills
    func developingSkill(_ skill: Skill) -> [Interest] {
        return self.filter { $0.skillsDeveloped?.contains(skill) ?? false }
    }
    
    /// Get interests related to a specific career pathway
    func forCareerPathway(_ pathway: CareerPathway) -> [Interest] {
        return self.filter { $0.careerPathways?.contains(pathway) ?? false }
    }
    
    /// Find interests that match a student's academic needs
    func matchingAcademicNeeds(subjects: [AcademicSubject]) -> [Interest] {
        return self.filter { interest in
            !Set(interest.academicRelevance).isDisjoint(with: Set(subjects))
        }
    }
    
    /// Find interests suitable for addressing behavioral challenges
    func forBehavioralIntervention() -> [Interest] {
        return self.filter {
            $0.isRelevantTo(model: .directAndCorrect) ||
            $0.isRelevantTo(model: .fromBully2Boss) ||
            $0.isRelevantTo(model: .fromMeek2Promising)
        }
    }
}
