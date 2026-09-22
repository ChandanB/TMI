import Foundation

/// Developmental domains for early-childhood goals, following the five central
/// domains of the Head Start Early Learning Outcomes Framework. Used to
/// organize goals, not to screen or assess children.
nonisolated enum DevelopmentalDomain: String, Codable, Sendable, CaseIterable, Identifiable, Equatable {
    case approachesToLearning
    case socialEmotional
    case languageLiteracy
    case cognition
    case perceptualMotorPhysical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .approachesToLearning: "Approaches to learning"
        case .socialEmotional: "Social & emotional"
        case .languageLiteracy: "Language & literacy"
        case .cognition: "Cognition"
        case .perceptualMotorPhysical: "Perceptual, motor & physical"
        }
    }

    var systemImage: String {
        switch self {
        case .approachesToLearning: "lightbulb"
        case .socialEmotional: "heart"
        case .languageLiteracy: "text.bubble"
        case .cognition: "puzzlepiece"
        case .perceptualMotorPhysical: "figure.run"
        }
    }
}

extension TMIPlanModel {
    /// Early-childhood descriptions are DRAFT copy awaiting product-owner
    /// approval (blueprint §15): strength-based, no clinical claims, and the
    /// brand names are unchanged.
    static let earlyChildhoodGuidanceIsDraft = true

    nonisolated func description(for profile: ProgramProfile) -> String {
        guard profile.program == .earlyChildhood else { return description }
        switch self {
        case .chaseYourSpace:
            return "For a child with a strong, lasting fascination. Build daily play and exploration around it so they can go deeper."
        case .acknowledgeInterests:
            return "Caregivers notice and name what the child loves, then bring those interests into routines to build belonging and engagement."
        case .alignYourMind:
            return "Predictable routines, visuals, and calming strategies built around the child's interests to support self-regulation and attention."
        case .directAndCorrect:
            return "Positive guidance for challenging behavior: teach and practice replacement skills using the child's interests, in partnership with the family."
        case .bullyToBoss:
            return "Channel big social energy into helper and leader roles (line leader, room helper) that practice turn-taking, gentle hands, and empathy."
        case .meekToProtector:
            return "Gently grow confidence for quieter children through interest-based play with a trusted adult, then with peers."
        }
    }

    /// Models that make developmental sense for an age group. Infants are
    /// supported through interests and routines only.
    nonisolated func isAvailable(for ageGroup: AgeGroup?) -> Bool {
        guard let ageGroup else { return true }
        switch self {
        case .acknowledgeInterests:
            return true
        case .alignYourMind, .directAndCorrect, .meekToProtector:
            return ageGroup != .infant
        case .chaseYourSpace, .bullyToBoss:
            return ageGroup.supportsPictureChoice
        }
    }

    /// The models to offer for a learner, in canonical order.
    nonisolated static func available(for profile: ProgramProfile, grade: String?) -> [TMIPlanModel] {
        guard profile.program == .earlyChildhood else { return allCases }
        let ageGroup = grade.flatMap(AgeGroup.init(rawValue:))
        return allCases.filter { $0.isAvailable(for: ageGroup) }
    }
}
