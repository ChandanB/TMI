//
//  CareerModels.swift
//  TMI
//
//  Career data models and pathway definitions
//

import CryptoKit
import Foundation

// MARK: - Career Path

struct CareerPath: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: String // Maps to InterestCluster name
    let subcategory: String
    let description: String
    let pathway: TMICareerPathway?
    let requiredInterests: [String] // Interest cluster names
    let estimatedSalary: SalaryRange?
    let educationLevel: EducationLevel
    let icon: String
    let color: String // Hex color

    init(
        id: UUID? = nil,
        title: String,
        category: String,
        subcategory: String = "",
        description: String,
        pathway: TMICareerPathway? = nil,
        requiredInterests: [String],
        estimatedSalary: SalaryRange? = nil,
        educationLevel: EducationLevel = .varies,
        icon: String,
        color: String
    ) {
        // A random id would be new on every launch, so a saved or plan-linked
        // career would stop resolving as soon as the app restarted. Derive it
        // from the career's identity instead.
        self.id = id ?? CareerPath.stableID(category: category, title: title)
        self.title = title
        self.category = category
        self.subcategory = subcategory
        self.description = description
        self.pathway = pathway
        self.requiredInterests = requiredInterests
        self.estimatedSalary = estimatedSalary
        self.educationLevel = educationLevel
        self.icon = icon
        self.color = color
    }

    /// Calculate relevance score based on student's interest clusters
    func relevanceScore(for clusters: [InterestCluster]) -> Double {
        let clusterNames = Set(clusters.map { $0.name })
        let matchingInterests = requiredInterests.filter { clusterNames.contains($0) }

        guard !matchingInterests.isEmpty else { return 0.0 }

        // Base score from matching interests
        let baseScore = Double(matchingInterests.count) / Double(requiredInterests.count)

        // Boost from cluster weights
        let weightBoost = clusters
            .filter { matchingInterests.contains($0.name) }
            .map { $0.weight }
            .reduce(0.0, +) / Double(matchingInterests.count)

        return (baseScore * 0.6) + (weightBoost * 0.4)
    }
}

// MARK: - TMI Career Pathway

struct TMICareerPathway: Codable, Hashable {
    let name: String
    let beginnerGoals: [CEPGoal]
    let intermediateGoals: [CEPGoal]
    let advancedGoals: [CEPGoal]
    let tmiModules: [TMIPlanModel]
    let resources: [ResourceReference]

    var allGoals: [CEPGoal] {
        beginnerGoals + intermediateGoals + advancedGoals
    }
}

// MARK: - CEP Goal

struct CEPGoal: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let level: SkillLevel
    let strategies: [String]
    let activities: [Activity]
    let assessment: String
    let reflectionPrompt: String
    let estimatedDuration: TimeInterval? // In minutes

    init(
        id: UUID = UUID(),
        title: String,
        level: SkillLevel,
        strategies: [String],
        activities: [Activity],
        assessment: String,
        reflectionPrompt: String,
        estimatedDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.strategies = strategies
        self.activities = activities
        self.assessment = assessment
        self.reflectionPrompt = reflectionPrompt
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - Activity

struct Activity: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let duration: TimeInterval // In minutes
    let type: ActivityType

    init(id: UUID = UUID(), title: String, duration: TimeInterval, type: ActivityType = .practice) {
        self.id = id
        self.title = title
        self.duration = duration
        self.type = type
    }
}

enum ActivityType: String, Codable, Hashable {
    case reading
    case video
    case practice
    case project
    case reflection
    case collaboration
}

// MARK: - Resource Reference

struct ResourceReference: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let type: ResourceType
    let url: String?
    let duration: String // "5min", "15min", etc.
    let level: SkillLevel

    init(
        id: UUID = UUID(),
        title: String,
        type: ResourceType,
        url: String? = nil,
        duration: String,
        level: SkillLevel
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.url = url
        self.duration = duration
        self.level = level
    }
}

enum ResourceType: String, Codable, Hashable {
    case video
    case article
    case course
    case tool
    case worksheet
    case template
}

// MARK: - Supporting Enums

enum SkillLevel: String, Codable, Hashable, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        rawValue.capitalized
    }
}

enum EducationLevel: String, Codable, Hashable {
    case highSchool = "High School"
    case someCollege = "Some College"
    case bachelors = "Bachelor's Degree"
    case masters = "Master's Degree"
    case doctorate = "Doctorate"
    case vocational = "Vocational Training"
    case certification = "Professional Certification"
    case varies = "Varies"
}

extension CareerPath {
    /// A stable identifier for a catalog entry.
    ///
    /// Derived from the career's own identity — category and title, compared
    /// the way a person would read them — so the same career keeps the same id
    /// across launches, catalog rebuilds, and devices. Two entries that
    /// normalize alike are the same career and collide deliberately; that is
    /// what makes the collision visible instead of silently duplicating.
    static func stableID(category: String, title: String) -> UUID {
        let key = "\(normalizedIdentityComponent(category))/\(normalizedIdentityComponent(title))"
        var digest = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        // Name-based UUID, RFC 4122 version 5 layout.
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }

    /// Case, spacing and punctuation are presentation, not identity.
    static func normalizedIdentityComponent(_ value: String) -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: nil
        )
        var words: [String] = []
        var current = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words.joined(separator: "-")
    }
}

struct SalaryRange: Codable, Hashable {
    let min: Int
    let max: Int
    let currency: String

    init(min: Int, max: Int, currency: String = "USD") {
        self.min = min
        self.max = max
        self.currency = currency
    }

    var displayRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0

        let minStr = formatter.string(from: NSNumber(value: min)) ?? "$\(min)"
        let maxStr = formatter.string(from: NSNumber(value: max)) ?? "$\(max)"

        return "\(minStr) - \(maxStr)"
    }
}

// MARK: - Career Match Result

struct CareerMatchResult: Identifiable, Hashable {
    let id: UUID
    let career: CareerPath
    let score: Double // 0.0 - 1.0
    let matchingInterests: [String]
    let suggestedTMIModules: [TMIPlanModel]

    init(
        id: UUID = UUID(),
        career: CareerPath,
        score: Double,
        matchingInterests: [String],
        suggestedTMIModules: [TMIPlanModel],
    ) {
        self.id = id
        self.career = career
        self.score = score
        self.matchingInterests = matchingInterests
        self.suggestedTMIModules = suggestedTMIModules
    }

    var matchPercentage: Int {
        Int(score * 100)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CareerMatchResult, rhs: CareerMatchResult) -> Bool {
        lhs.id == rhs.id
    }
}
