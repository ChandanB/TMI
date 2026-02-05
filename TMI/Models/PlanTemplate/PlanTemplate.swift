//
//  PlanTemplate.swift
//  TMI
//
//  Plan templates for structured TMI intervention creation
//

import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseFirestoreCombineSwift


/// A template for creating TMI Plans quickly
struct PlanTemplate: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let title: String
    let description: String
    let model: TMIPlanModel
    let category: Category
    let goalsTemplate: [GoalTemplate]
    let strategiesTemplate: [String]
    let suggestedDurationWeeks: Int
    let targetGradeLevels: [String]?
    let isPublic: Bool
    let createdBy: String
    let districtId: String?
    let createdAt: Date
    let updatedAt: Date
    var usageCount: Int
    var rating: Double?
    
    // MARK: - Categories
    
    enum Category: String, Codable, CaseIterable, Sendable {
        case behavioral = "Behavioral"
        case academic = "Academic"
        case socialEmotional = "Social-Emotional"
        case careerPrep = "Career Preparation"
        case leadership = "Leadership"
        case engagement = "Engagement"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .behavioral: return "hand.raised.fill"
            case .academic: return "book.fill"
            case .socialEmotional: return "heart.fill"
            case .careerPrep: return "briefcase.fill"
            case .leadership: return "person.badge.shield.checkmark.fill"
            case .engagement: return "sparkles"
            case .custom: return "square.grid.2x2"
            }
        }
        
        var color: String {
            switch self {
            case .behavioral: return "orange"
            case .academic: return "blue"
            case .socialEmotional: return "pink"
            case .careerPrep: return "green"
            case .leadership: return "purple"
            case .engagement: return "yellow"
            case .custom: return "gray"
            }
        }
    }
    
    // MARK: - Goal Template
    
    struct GoalTemplate: Codable, Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let description: String
        
        enum GoalStatus: String, Codable, CaseIterable, Sendable {
            case notStarted
            case inProgress
            case completed
        }
        
        let category: GoalStatus
        
        struct MilestoneTemplate: Codable, Equatable, Sendable, Identifiable {
            let id: String
            let title: String
            let ordinal: Int
        }
        
        let milestones: [MilestoneTemplate]
        
        init(
            id: String = UUID().uuidString,
            title: String,
            description: String,
            milestones: [MilestoneTemplate] = [],
            category: GoalStatus = .notStarted
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.milestones = milestones
            self.category = category
        }
    }
    
    // MARK: - Initializer
    
    init(
        id: String? = nil,
        title: String,
        description: String,
        model: TMIPlanModel,
        category: Category,
        goalsTemplate: [GoalTemplate] = [],
        strategiesTemplate: [String] = [],
        suggestedDurationWeeks: Int = 12,
        targetGradeLevels: [String]? = nil,
        isPublic: Bool = false,
        createdBy: String,
        districtId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0,
        rating: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.model = model
        self.category = category
        self.goalsTemplate = goalsTemplate
        self.strategiesTemplate = strategiesTemplate
        self.suggestedDurationWeeks = suggestedDurationWeeks
        self.targetGradeLevels = targetGradeLevels
        self.isPublic = isPublic
        self.createdBy = createdBy
        self.districtId = districtId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
        self.rating = rating
    }
    
    // MARK: - Factory Methods for Built-in Templates
    
    static func behavioralIntervention() -> PlanTemplate {
        PlanTemplate(
            title: "Behavioral Intervention Plan",
            description: "A structured approach to address and correct negative behaviors using positive reinforcement and interest-based redirection.",
            model: .directAndCorrect,
            category: .behavioral,
            goalsTemplate: [
                GoalTemplate(
                    title: "Decrease Disruptive Behavior",
                    description: "Reduce classroom disruptions by implementing coping strategies",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Identify triggers", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Learn 3 coping strategies", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Practice in safe environment", ordinal: 3),
                        .init(id: UUID().uuidString, title: "Apply in classroom", ordinal: 4)
                    ]
                ),
                GoalTemplate(
                    title: "Build Positive Relationships",
                    description: "Develop positive peer interactions through interest-based activities",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Join interest-based group", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Complete 3 collaborative activities", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Lead a peer activity", ordinal: 3)
                    ]
                )
            ],
            strategiesTemplate: [
                "Weekly check-ins with counselor",
                "Interest-based behavior redirection",
                "Parent communication log",
                "Positive reinforcement chart"
            ],
            suggestedDurationWeeks: 12,
            targetGradeLevels: ["6", "7", "8", "9", "10"],
            isPublic: true,
            createdBy: "system"
        )
    }
    
    static func careerExploration() -> PlanTemplate {
        PlanTemplate(
            title: "Career Pathway Exploration",
            description: "Help students explore career options aligned with their interests and develop a pathway to their goals.",
            model: .chaseYourSpace,
            category: .careerPrep,
            goalsTemplate: [
                GoalTemplate(
                    title: "Career Discovery",
                    description: "Explore careers matching identified interests",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Complete career interest inventory", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Research 3 career options", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Interview a professional", ordinal: 3)
                    ]
                ),
                GoalTemplate(
                    title: "Educational Planning",
                    description: "Create educational pathway aligned with career goals",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Map required courses", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Identify extracurricular opportunities", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Create 4-year plan", ordinal: 3)
                    ]
                )
            ],
            strategiesTemplate: [
                "Career mentor matching",
                "Job shadowing opportunities",
                "Skills assessment activities",
                "Portfolio development"
            ],
            suggestedDurationWeeks: 8,
            targetGradeLevels: ["8", "9", "10", "11", "12"],
            isPublic: true,
            createdBy: "system"
        )
    }
    
    static func confidenceBuilding() -> PlanTemplate {
        PlanTemplate(
            title: "Confidence & Self-Advocacy",
            description: "Empower introverted or passive students to build confidence and develop self-advocacy skills.",
            model: .meekToProtector,
            category: .socialEmotional,
            goalsTemplate: [
                GoalTemplate(
                    title: "Self-Awareness Development",
                    description: "Identify personal strengths and areas for growth",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Complete strengths assessment", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Create personal affirmation list", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Set 3 personal goals", ordinal: 3)
                    ]
                ),
                GoalTemplate(
                    title: "Communication Skills",
                    description: "Develop assertive communication and self-advocacy",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Practice with counselor", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Role-play scenarios", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Advocate in real situation", ordinal: 3)
                    ]
                )
            ],
            strategiesTemplate: [
                "Weekly reflection journal",
                "Peer mentoring pairing",
                "Small group leadership opportunities",
                "Progressive challenge activities"
            ],
            suggestedDurationWeeks: 10,
            targetGradeLevels: ["5", "6", "7", "8"],
            isPublic: true,
            createdBy: "system"
        )
    }
    
    static func leadershipDevelopment() -> PlanTemplate {
        PlanTemplate(
            title: "From Challenge to Champion",
            description: "Transform challenging behaviors into positive leadership through interest-driven mentorship.",
            model: .bullyToBoss,
            category: .leadership,
            goalsTemplate: [
                GoalTemplate(
                    title: "Leadership Role Discovery",
                    description: "Identify leadership qualities and positive outlets",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Identify personal leadership style", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Study positive role models", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Take on small leadership role", ordinal: 3)
                    ]
                ),
                GoalTemplate(
                    title: "Conflict Resolution",
                    description: "Learn constructive conflict resolution strategies",
                    milestones: [
                        .init(id: UUID().uuidString, title: "Learn conflict styles", ordinal: 1),
                        .init(id: UUID().uuidString, title: "Practice mediation skills", ordinal: 2),
                        .init(id: UUID().uuidString, title: "Resolve peer conflict positively", ordinal: 3)
                    ]
                )
            ],
            strategiesTemplate: [
                "Peer mediation training",
                "Interest-based leadership projects",
                "Mentor pairing with community leader",
                "Restorative practices circles"
            ],
            suggestedDurationWeeks: 16,
            targetGradeLevels: ["6", "7", "8", "9", "10", "11"],
            isPublic: true,
            createdBy: "system"
        )
    }
    
    static var defaultTemplates: [PlanTemplate] {
        [
            behavioralIntervention(),
            careerExploration(),
            confidenceBuilding(),
            leadershipDevelopment()
        ]
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

