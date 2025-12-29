//
//  PlanResourceLink.swift
//  TMI
//
//  Plan Resource Link Edge Model
//  Represents a resource being added to a TMI plan's toolkit
//  Different from ResourceAssignment (which assigns to students)
//

import Foundation
@preconcurrency import FirebaseFirestore

struct PlanResourceLink: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
    let planId: String
    let resourceId: String
    let addedBy: String  // UID of educator who added this resource
    let addedAt: Date
    let updatedAt: Date
    let notes: String?  // Optional notes about why this resource fits the plan
    let orderIndex: Int?  // Optional ordering for displaying resources

    // MARK: - Initializer

    init(
        id: String? = nil,
        planId: String,
        resourceId: String,
        addedBy: String,
        addedAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String? = nil,
        orderIndex: Int? = nil
    ) {
        self.id = id
        self.planId = planId
        self.resourceId = resourceId
        self.addedBy = addedBy
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.orderIndex = orderIndex
    }

    // MARK: - Firestore Helpers

    /// Convert to Firestore data dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "planId": planId,
            "resourceId": resourceId,
            "addedBy": addedBy,
            "addedAt": Timestamp(date: addedAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let notes = notes {
            data["notes"] = notes
        }

        if let orderIndex = orderIndex {
            data["orderIndex"] = orderIndex
        }

        return data
    }

    /// Create from Firestore document
    static func fromFirestore(id: String, data: [String: Any]) -> PlanResourceLink? {
        guard
            let planId = data["planId"] as? String,
            let resourceId = data["resourceId"] as? String,
            let addedBy = data["addedBy"] as? String
        else {
            return nil
        }

        let addedAtTimestamp = data["addedAt"] as? Timestamp ?? Timestamp(date: Date())
        let addedAt = addedAtTimestamp.dateValue()

        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        let updatedAt = updatedAtTimestamp.dateValue()

        let notes = data["notes"] as? String
        let orderIndex = data["orderIndex"] as? Int

        return PlanResourceLink(
            id: id,
            planId: planId,
            resourceId: resourceId,
            addedBy: addedBy,
            addedAt: addedAt,
            updatedAt: updatedAt,
            notes: notes,
            orderIndex: orderIndex
        )
    }

    // MARK: - Equatable

    static func == (lhs: PlanResourceLink, rhs: PlanResourceLink) -> Bool {
        lhs.id == rhs.id &&
        lhs.planId == rhs.planId &&
        lhs.resourceId == rhs.resourceId
    }
}

// MARK: - Helper Extensions

extension PlanResourceLink {
    /// Check if link has notes
    var hasNotes: Bool {
        notes?.isEmpty == false
    }

    /// Get display order (0 if not set)
    var displayOrder: Int {
        orderIndex ?? 0
    }
}
