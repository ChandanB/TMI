//
//  Meeting.swift
//  TMI
//
//  Model for scheduled meetings, check-ins, and conferences
//

import Foundation
import FirebaseFirestore

// MARK: - Coding Keys for proper Firestore Date handling

extension Meeting {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startTime
        case endTime
        case location
        case meetingType
        case organizer
        case participants
        case relatedStudentIds
        case relatedPlanId
        case status
        case notes
        case completedAt
        case actionItems
        case createdAt
        case lastUpdated
    }
}

struct Meeting: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let location: String?
    let meetingType: MeetingType

    // Participants
    let organizer: String // User ID
    let participants: [MeetingParticipant]

    // Related entities
    let relatedStudentIds: [String]
    let relatedPlanId: String?

    // Status
    var status: MeetingStatus
    var notes: String?
    var completedAt: Date?

    // Action Items
    var actionItems: [ActionItem]

    let createdAt: Date
    var lastUpdated: Date

    enum MeetingType: String, Codable, CaseIterable {
        case checkIn = "Check-In"
        case progressReview = "Progress Review"
        case parentConference = "Parent Conference"
        case teamMeeting = "Team Meeting"
        case studentMeeting = "Student Meeting"
        case strategySession = "Strategy Session"

        var icon: String {
            switch self {
            case .checkIn: return "checkmark.circle"
            case .progressReview: return "chart.line.uptrend.xyaxis"
            case .parentConference: return "person.2"
            case .teamMeeting: return "person.3"
            case .studentMeeting: return "person.circle"
            case .strategySession: return "lightbulb"
            }
        }

        var color: String {
            switch self {
            case .checkIn: return "#3498DB"
            case .progressReview: return "#2ECC71"
            case .parentConference: return "#9B59B6"
            case .teamMeeting: return "#E67E22"
            case .studentMeeting: return "#1ABC9C"
            case .strategySession: return "#F39C12"
            }
        }
    }

    enum MeetingStatus: String, Codable {
        case scheduled = "Scheduled"
        case confirmed = "Confirmed"
        case completed = "Completed"
        case cancelled = "Cancelled"
        case rescheduled = "Rescheduled"
    }

    // MARK: - Computed Properties

    var isUpcoming: Bool {
        startTime > Date() && (status == .scheduled || status == .confirmed)
    }

    var isPast: Bool {
        endTime < Date()
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    // MARK: - Firestore Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "meetingType": meetingType.rawValue,
            "organizer": organizer,
            "participants": participants.map { $0.toFirestoreData() },
            "relatedStudentIds": relatedStudentIds,
            "status": status.rawValue,
            "actionItems": actionItems.map { $0.toFirestoreData() },
            "createdAt": Timestamp(date: createdAt),
            "lastUpdated": Timestamp(date: lastUpdated)
        ]

        if let description = description {
            data["description"] = description
        }

        if let location = location {
            data["location"] = location
        }

        if let relatedPlanId = relatedPlanId {
            data["relatedPlanId"] = relatedPlanId
        }

        if let notes = notes {
            data["notes"] = notes
        }

        if let completedAt = completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        return data
    }

    var hasActionItems: Bool {
        !actionItems.isEmpty
    }

    var completedActionItemsCount: Int {
        actionItems.filter { $0.isCompleted }.count
    }

    var overdueActionItemsCount: Int {
        actionItems.filter { $0.isOverdue }.count
    }
}

struct MeetingParticipant: Codable, Hashable, Identifiable {
    var id: String { userId }
    let userId: String
    let name: String
    let role: ParticipantRole
    var responseStatus: ResponseStatus

    enum ParticipantRole: String, Codable, CaseIterable {
        case teacher = "Teacher"
        case counselor = "Counselor"
        case administrator = "Administrator"
        case parent = "Parent"
        case student = "Student"
        case socialWorker = "Social Worker"
        case other = "Other"

        var icon: String {
            switch self {
            case .teacher: return "person.fill"
            case .counselor: return "heart.circle.fill"
            case .administrator: return "person.badge.key.fill"
            case .parent: return "house.fill"
            case .student: return "graduationcap.fill"
            case .socialWorker: return "hands.sparkles.fill"
            case .other: return "person.circle.fill"
            }
        }
    }

    enum ResponseStatus: String, Codable {
        case pending = "Pending"
        case accepted = "Accepted"
        case declined = "Declined"
        case tentative = "Tentative"

        var color: String {
            switch self {
            case .pending: return "#95A5A6"
            case .accepted: return "#2ECC71"
            case .declined: return "#E74C3C"
            case .tentative: return "#F39C12"
            }
        }
    }

    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "name": name,
            "role": role.rawValue,
            "responseStatus": responseStatus.rawValue
        ]
    }
}

// MARK: - Action Item

struct ActionItem: Codable, Hashable, Identifiable {
    var id: String { itemId }
    let itemId: String
    let description: String
    let assignedTo: String? // User ID
    let dueDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    let createdAt: Date

    enum ActionItemPriority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var icon: String {
            switch self {
            case .low: return "arrow.down.circle.fill"
            case .medium: return "minus.circle.fill"
            case .high: return "arrow.up.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .low: return "#3498DB"
            case .medium: return "#F39C12"
            case .high: return "#E74C3C"
            }
        }
    }

    var priority: ActionItemPriority

    init(
        itemId: String = UUID().uuidString,
        description: String,
        assignedTo: String? = nil,
        dueDate: Date? = nil,
        priority: ActionItemPriority = .medium,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.itemId = itemId
        self.description = description
        self.assignedTo = assignedTo
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "itemId": itemId,
            "description": description,
            "priority": priority.rawValue,
            "isCompleted": isCompleted,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let assignedTo = assignedTo {
            data["assignedTo"] = assignedTo
        }

        if let dueDate = dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }

        if let completedAt = completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        return data
    }
}

// MARK: - Sample Data

extension Meeting {
    static var sampleMeeting: Meeting {
        Meeting(
            id: "sample-meeting-1",
            title: "Progress Review: Chase Your Space",
            description: "Review initial progress and adjust intervention strategies",
            startTime: Date().addingTimeInterval(86400), // Tomorrow
            endTime: Date().addingTimeInterval(86400 + 1800), // 30 min meeting
            location: "Room 204",
            meetingType: .checkIn,
            organizer: "current-user-id",
            participants: [
                MeetingParticipant(
                    userId: "user-1",
                    name: "Ms. Johnson",
                    role: .teacher,
                    responseStatus: .accepted
                ),
                MeetingParticipant(
                    userId: "user-2",
                    name: "Mr. Smith",
                    role: .counselor,
                    responseStatus: .pending
                )
            ],
            relatedStudentIds: ["student-1"],
            relatedPlanId: "plan-1",
            status: .scheduled,
            notes: nil,
            completedAt: nil,
            actionItems: [
                ActionItem(
                    description: "Follow up with student about goals",
                    assignedTo: "user-1",
                    dueDate: Date().addingTimeInterval(604800), // 1 week
                    priority: .high
                ),
                ActionItem(
                    description: "Update intervention strategy document",
                    assignedTo: "user-2",
                    dueDate: Date().addingTimeInterval(259200), // 3 days
                    priority: .medium
                )
            ],
            createdAt: Date(),
            lastUpdated: Date()
        )
    }
}
