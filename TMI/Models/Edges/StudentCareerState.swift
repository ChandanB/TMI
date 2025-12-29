//
//  StudentCareerState.swift
//  TMI
//
//  Student Career State Edge Model
//  Represents a student's relationship with a career from the global library
//

import Foundation
@preconcurrency import FirebaseFirestore

struct StudentCareerState: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
    let studentId: String
    let careerId: String
    let status: CareerStatus
    let progress: Double  // 0.0-1.0 representing exploration progress
    let isFavorite: Bool
    let lastViewedAt: Date
    let addedAt: Date
    let updatedAt: Date
    let createdBy: String  // UID of who created this relationship

    enum CareerStatus: String, Codable, CaseIterable, Sendable {
        case exploring = "exploring"
        case researching = "researching"
        case interested = "interested"
        case pursuing = "pursuing"
        case notInterested = "not_interested"

        var displayName: String {
            switch self {
            case .exploring: return "Exploring"
            case .researching: return "Researching"
            case .interested: return "Interested"
            case .pursuing: return "Pursuing"
            case .notInterested: return "Not Interested"
            }
        }

        var icon: String {
            switch self {
            case .exploring: return "magnifyingglass"
            case .researching: return "book.fill"
            case .interested: return "star.fill"
            case .pursuing: return "flag.fill"
            case .notInterested: return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Initializer

    init(
        id: String? = nil,
        studentId: String,
        careerId: String,
        status: CareerStatus,
        progress: Double = 0.0,
        isFavorite: Bool = false,
        lastViewedAt: Date = Date(),
        addedAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String
    ) {
        self.id = id
        self.studentId = studentId
        self.careerId = careerId
        self.status = status
        self.progress = max(0.0, min(1.0, progress))  // Clamp to 0.0-1.0 range
        self.isFavorite = isFavorite
        self.lastViewedAt = lastViewedAt
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
    }

    // MARK: - Firestore Helpers

    /// Convert to Firestore data dictionary
    func toFirestoreData() -> [String: Any] {
        [
            "studentId": studentId,
            "careerId": careerId,
            "status": status.rawValue,
            "progress": progress,
            "isFavorite": isFavorite,
            "lastViewedAt": Timestamp(date: lastViewedAt),
            "addedAt": Timestamp(date: addedAt),
            "updatedAt": Timestamp(date: updatedAt),
            "createdBy": createdBy
        ]
    }

    /// Create from Firestore document
    static func fromFirestore(id: String, data: [String: Any]) -> StudentCareerState? {
        guard
            let studentId = data["studentId"] as? String,
            let careerId = data["careerId"] as? String,
            let statusString = data["status"] as? String,
            let status = CareerStatus(rawValue: statusString),
            let progress = data["progress"] as? Double,
            let isFavorite = data["isFavorite"] as? Bool,
            let createdBy = data["createdBy"] as? String
        else {
            return nil
        }

        let lastViewedAtTimestamp = data["lastViewedAt"] as? Timestamp ?? Timestamp(date: Date())
        let lastViewedAt = lastViewedAtTimestamp.dateValue()

        let addedAtTimestamp = data["addedAt"] as? Timestamp ?? Timestamp(date: Date())
        let addedAt = addedAtTimestamp.dateValue()

        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        let updatedAt = updatedAtTimestamp.dateValue()

        return StudentCareerState(
            id: id,
            studentId: studentId,
            careerId: careerId,
            status: status,
            progress: progress,
            isFavorite: isFavorite,
            lastViewedAt: lastViewedAt,
            addedAt: addedAt,
            updatedAt: updatedAt,
            createdBy: createdBy
        )
    }

    // MARK: - Equatable

    static func == (lhs: StudentCareerState, rhs: StudentCareerState) -> Bool {
        lhs.id == rhs.id &&
        lhs.studentId == rhs.studentId &&
        lhs.careerId == rhs.careerId
    }
}

// MARK: - Helper Extensions

extension StudentCareerState {
    /// Check if this career is actively being pursued
    var isActivePursuit: Bool {
        status == .pursuing || status == .interested
    }

    /// Check if this career is in early exploration
    var isExploring: Bool {
        status == .exploring || status == .researching
    }

    /// Get a progress percentage (0-100)
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// Check if the career was recently viewed (within last 7 days)
    var isRecentlyViewed: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return lastViewedAt > sevenDaysAgo
    }
}
