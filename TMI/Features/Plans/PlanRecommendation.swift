import Foundation

/// A need an educator has explicitly identified for a student.
///
/// These are chosen by a person who knows the child. Nothing derives one from
/// student data: a need is a professional judgement, not something to be
/// inferred from a survey answer or a behaviour record.
nonisolated enum PlanNeedTag: String, Codable, Sendable, CaseIterable, Equatable {
    case belonging
    case engagement
    case emotionalRegulation
    case behaviorRedirection
    case leadingOthersWell
    case selfAdvocacy

    /// The branded model this need is addressed by.
    var model: TMIPlanModel {
        switch self {
        case .belonging: .chaseYourSpace
        case .engagement: .acknowledgeInterests
        case .emotionalRegulation: .alignYourMind
        case .behaviorRedirection: .directAndCorrect
        case .leadingOthersWell: .bullyToBoss
        case .selfAdvocacy: .meekToProtector
        }
    }

    var displayName: String {
        switch self {
        case .belonging: "Belonging"
        case .engagement: "Engagement"
        case .emotionalRegulation: "Emotional regulation"
        case .behaviorRedirection: "Behavior redirection"
        case .leadingOthersWell: "Leading others well"
        case .selfAdvocacy: "Self-advocacy"
        }
    }
}

nonisolated struct PlanRecommendation: Identifiable, Sendable, Equatable {
    var id: String { model.rawValue }

    let model: TMIPlanModel
    let rank: Int
    /// The canonical records this suggestion was built from, so an educator can
    /// go and read them.
    let inputRecordIDs: [String]
    let reasons: [String]
    let rulesVersion: Int
}

/// What the engine is allowed to look at.
///
/// Every field here is either an educator's own judgement or a record someone
/// has already approved. Nothing raw, nothing inferred.
nonisolated struct PlanRecommendationInput: Sendable {
    /// Chosen by the educator. Without these there is no ranking to make.
    var needTags: [PlanNeedTag] = []
    var approvedInterests: [StudentInterest] = []
    var savedCareerIDs: [String] = []
    /// Models already used, so a suggestion does not repeat recent work.
    var activeModels: [TMIPlanModel] = []
    var completedModels: [TMIPlanModel] = []
}
