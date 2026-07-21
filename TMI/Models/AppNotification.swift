//
//  AppNotification.swift
//  TMI
//
//  In-app notification model for user-facing events
//

import Foundation

struct AppNotification: Codable, Identifiable, Sendable, Equatable {
    var id: String? = nil
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let createdAt: Date
    var readAt: Date?
    var isRead: Bool
    var priority: NotificationPriority
    var metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case userId
        case type
        case title
        case message
        case createdAt
        case readAt
        case isRead
        case priority
        case metadata
    }

    enum NotificationType: String, Codable, CaseIterable, Sendable {
        case planApprovalRequest = "plan_approval_request"
        case planApproved = "plan_approved"
        case planRejected = "plan_rejected"
        case surveyAssigned = "survey_assigned"
        case surveyCompleted = "survey_completed"
        case resourceAssigned = "resource_assigned"
        case goalCompleted = "goal_completed"
        case meetingReminder = "meeting_reminder"
        case formDue = "form_due"
        case systemAlert = "system_alert"

        var displayName: String {
            switch self {
            case .planApprovalRequest: return "Plan Approval Request"
            case .planApproved: return "Plan Approved"
            case .planRejected: return "Plan Rejected"
            case .surveyAssigned: return "Survey Assigned"
            case .surveyCompleted: return "Survey Completed"
            case .resourceAssigned: return "Resource Assigned"
            case .goalCompleted: return "Goal Completed"
            case .meetingReminder: return "Meeting Reminder"
            case .formDue: return "Form Due"
            case .systemAlert: return "System Alert"
            }
        }

        var iconName: String {
            switch self {
            case .planApprovalRequest: return "doc.text.magnifyingglass"
            case .planApproved: return "checkmark.seal.fill"
            case .planRejected: return "xmark.seal.fill"
            case .surveyAssigned: return "list.clipboard"
            case .surveyCompleted: return "checkmark.circle.fill"
            case .resourceAssigned: return "books.vertical.fill"
            case .goalCompleted: return "target"
            case .meetingReminder: return "calendar.badge.clock"
            case .formDue: return "doc.badge.exclamationmark"
            case .systemAlert: return "exclamationmark.triangle.fill"
            }
        }
    }

    enum NotificationPriority: String, Codable, CaseIterable, Sendable {
        case low
        case medium
        case high
        case critical

        var sortWeight: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .critical: return 3
            }
        }
    }

    var isUnread: Bool {
        !isRead
    }

    init(
        id: String? = nil,
        userId: String,
        type: NotificationType,
        title: String,
        message: String,
        createdAt: Date = Date(),
        readAt: Date? = nil,
        isRead: Bool = false,
        priority: NotificationPriority = .medium,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.readAt = readAt
        self.isRead = isRead
        self.priority = priority
        self.metadata = metadata
    }
}
