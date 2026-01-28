//
//  PlanTemplate.swift
//  TMI
//
//  Plan templates for structured TMI intervention creation
//

import Foundation
@preconcurrency import FirebaseFirestore

// MARK: - Plan Template

/// Template for creating TMI intervention plans with pre-defined activities and goals
struct PlanTemplate: Codable, Identifiable, Sendable {
    @DocumentID var id: String?

    // Template identification
    let name: String
    let model: TMIPlanModel
    let description: String
    let category: String // e.g., "Academic Support", "Behavioral", "Career Exploration"

    // Structure
    let recommendedDuration: Int // days
    let activities: [ActivityTemplate]
    let goalTemplates: [GoalTemplate]
    let resourceCategories: [String] // Suggested resource types

    // MTSS alignment
    let tier: Int // MTSS tier 1, 2, or 3
    let targetedInterventions: [String] // Specific areas this template addresses

    // Metadata
    let createdAt: Date
    let createdBy: String?
    let isActive: Bool
    let version: Int

    // Usage tracking
    var usageCount: Int
    var lastUsedAt: Date?

    // District/School scope
    var districtId: String?
    var schoolId: String?
    var isPublic: Bool // Available to all districts

    init(
        id: String? = nil,
        name: String,
        model: TMIPlanModel,
        description: String,
        category: String,
        recommendedDuration: Int,
        activities: [ActivityTemplate],
        goalTemplates: [GoalTemplate],
        resourceCategories: [String],
        tier: Int = 2,
        targetedInterventions: [String] = [],
        createdAt: Date = Date(),
        createdBy: String? = nil,
        isActive: Bool = true,
        version: Int = 1,
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        districtId: String? = nil,
        schoolId: String? = nil,
        isPublic: Bool = false
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.description = description
        self.category = category
        self.recommendedDuration = recommendedDuration
        self.activities = activities
        self.goalTemplates = goalTemplates
        self.resourceCategories = resourceCategories
        self.tier = tier
        self.targetedInterventions = targetedInterventions
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.isActive = isActive
        self.version = version
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.districtId = districtId
        self.schoolId = schoolId
        self.isPublic = isPublic
    }
}

// MARK: - Activity Template

/// Template for scheduled intervention activities
struct ActivityTemplate: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let type: ActivityType
    let scheduleSuggestion: ScheduleSuggestion
    let estimatedDuration: Int // minutes
    let sequenceOrder: Int // Order in the plan
    let instructions: String?
    let requiredMaterials: [String]?
    let assessmentCriteria: String?

    enum ActivityType: String, Codable, Sendable {
        case checkIn = "check_in"
        case assignment = "assignment"
        case discussion = "discussion"
        case reflection = "reflection"
        case assessment = "assessment"
        case goalSetting = "goal_setting"
        case resourceReview = "resource_review"
        case skillPractice = "skill_practice"
        case projectWork = "project_work"
        case peerCollaboration = "peer_collaboration"
    }

    enum ScheduleSuggestion: String, Codable, Sendable {
        case daily = "daily"
        case weekly = "weekly"
        case biweekly = "biweekly"
        case monthly = "monthly"
        case asNeeded = "as_needed"
        case atStart = "at_start"
        case atEnd = "at_end"

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .biweekly: return "Every 2 weeks"
            case .monthly: return "Monthly"
            case .asNeeded: return "As needed"
            case .atStart: return "At plan start"
            case .atEnd: return "At plan end"
            }
        }

        /// Calculate scheduled date based on start date and occurrence number
        func scheduledDate(startDate: Date, occurrence: Int = 1) -> Date {
            let calendar = Calendar.current
            switch self {
            case .daily:
                return calendar.date(byAdding: .day, value: occurrence - 1, to: startDate) ?? startDate
            case .weekly:
                return calendar.date(byAdding: .weekOfYear, value: occurrence - 1, to: startDate) ?? startDate
            case .biweekly:
                return calendar.date(byAdding: .weekOfYear, value: (occurrence - 1) * 2, to: startDate) ?? startDate
            case .monthly:
                return calendar.date(byAdding: .month, value: occurrence - 1, to: startDate) ?? startDate
            case .atStart:
                return startDate
            case .atEnd, .asNeeded:
                return startDate // Will be manually scheduled
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        type: ActivityType,
        scheduleSuggestion: ScheduleSuggestion,
        estimatedDuration: Int,
        sequenceOrder: Int,
        instructions: String? = nil,
        requiredMaterials: [String]? = nil,
        assessmentCriteria: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.scheduleSuggestion = scheduleSuggestion
        self.estimatedDuration = estimatedDuration
        self.sequenceOrder = sequenceOrder
        self.instructions = instructions
        self.requiredMaterials = requiredMaterials
        self.assessmentCriteria = assessmentCriteria
    }
}

// MARK: - Goal Template

/// Template for intervention goals
struct GoalTemplate: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let category: GoalCategory
    let measurableOutcome: String
    let successCriteria: [String]
    let timeframe: String // e.g., "2 weeks", "1 month"
    let sequenceOrder: Int

    enum GoalCategory: String, Codable, Sendable {
        case academic = "academic"
        case behavioral = "behavioral"
        case social = "social"
        case emotional = "emotional"
        case career = "career"
        case selfAdvocacy = "self_advocacy"
        case engagement = "engagement"

        var displayName: String {
            switch self {
            case .academic: return "Academic"
            case .behavioral: return "Behavioral"
            case .social: return "Social"
            case .emotional: return "Emotional"
            case .career: return "Career Exploration"
            case .selfAdvocacy: return "Self-Advocacy"
            case .engagement: return "Engagement"
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: GoalCategory,
        measurableOutcome: String,
        successCriteria: [String],
        timeframe: String,
        sequenceOrder: Int
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.measurableOutcome = measurableOutcome
        self.successCriteria = successCriteria
        self.timeframe = timeframe
        self.sequenceOrder = sequenceOrder
    }

    /// Convert template to concrete Goal
    func toGoal() -> Goal {
        return Goal(
            id: UUID(),
            title: title,
            description: description,
            category: category.rawValue,
            targetDate: Date().addingTimeInterval(parsedTimeframe()),
            isCompleted: false,
            completedDate: nil,
            progress: 0.0,
            milestones: successCriteria.map { Milestone(description: $0, isCompleted: false) }
        )
    }

    /// Parse timeframe string to seconds
    private func parsedTimeframe() -> TimeInterval {
        let components = timeframe.lowercased().split(separator: " ")
        guard components.count == 2,
              let value = Int(components[0]) else {
            return 30 * 24 * 60 * 60 // Default to 30 days
        }

        let unit = String(components[1])
        if unit.hasPrefix("week") {
            return TimeInterval(value * 7 * 24 * 60 * 60)
        } else if unit.hasPrefix("month") {
            return TimeInterval(value * 30 * 24 * 60 * 60)
        } else if unit.hasPrefix("day") {
            return TimeInterval(value * 24 * 60 * 60)
        }

        return 30 * 24 * 60 * 60 // Default to 30 days
    }
}

// MARK: - Intervention Activity (Instantiated from Template)

/// Actual scheduled activity in a TMI plan
struct InterventionActivity: Codable, Identifiable, Sendable {
    let id: UUID
    let planId: String
    let templateId: UUID? // Reference to source template

    // Activity details
    let title: String
    let description: String
    let type: ActivityTemplate.ActivityType
    let estimatedDuration: Int // minutes

    // Scheduling
    var scheduledDate: Date
    var completedDate: Date?
    var status: ActivityStatus

    // Assignment
    let assignedTo: String // studentId
    var assignedBy: String?
    var completedBy: String?

    // Content
    let instructions: String?
    let requiredMaterials: [String]?
    let assessmentCriteria: String?

    // Feedback
    var studentNotes: String?
    var staffNotes: String?
    var attachments: [String]? // URLs to uploaded files

    enum ActivityStatus: String, Codable, Sendable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case skipped = "skipped"
        case overdue = "overdue"

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .skipped: return "Skipped"
            case .overdue: return "Overdue"
            }
        }

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .inProgress: return "hourglass"
            case .completed: return "checkmark.circle.fill"
            case .skipped: return "xmark.circle"
            case .overdue: return "exclamationmark.triangle.fill"
            }
        }
    }

    init(
        id: UUID = UUID(),
        planId: String,
        templateId: UUID? = nil,
        title: String,
        description: String,
        type: ActivityTemplate.ActivityType,
        estimatedDuration: Int,
        scheduledDate: Date,
        completedDate: Date? = nil,
        status: ActivityStatus = .pending,
        assignedTo: String,
        assignedBy: String? = nil,
        completedBy: String? = nil,
        instructions: String? = nil,
        requiredMaterials: [String]? = nil,
        assessmentCriteria: String? = nil,
        studentNotes: String? = nil,
        staffNotes: String? = nil,
        attachments: [String]? = nil
    ) {
        self.id = id
        self.planId = planId
        self.templateId = templateId
        self.title = title
        self.description = description
        self.type = type
        self.estimatedDuration = estimatedDuration
        self.scheduledDate = scheduledDate
        self.completedDate = completedDate
        self.status = status
        self.assignedTo = assignedTo
        self.assignedBy = assignedBy
        self.completedBy = completedBy
        self.instructions = instructions
        self.requiredMaterials = requiredMaterials
        self.assessmentCriteria = assessmentCriteria
        self.studentNotes = studentNotes
        self.staffNotes = staffNotes
        self.attachments = attachments
    }

    var isOverdue: Bool {
        return status == .pending && Date() > scheduledDate
    }
}

// MARK: - Supporting Types

/// Goal milestone for tracking progress
struct Milestone: Codable, Sendable {
    let description: String
    var isCompleted: Bool
    var completedDate: Date?

    init(description: String, isCompleted: Bool = false, completedDate: Date? = nil) {
        self.description = description
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }
}

/// Goal model (if not already defined elsewhere)
struct Goal: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let category: String
    let targetDate: Date
    var isCompleted: Bool
    var completedDate: Date?
    var progress: Double // 0.0 - 1.0
    var milestones: [Milestone]

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: String,
        targetDate: Date,
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        progress: Double = 0.0,
        milestones: [Milestone] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.progress = progress
        self.milestones = milestones
    }
}
