//
//  PlanInputField.swift
//  TMI
//
//  Plan-scoped inputs captured from plan rules.
//

import FirebaseFirestore
import Foundation

struct PlanInputField: Codable, Identifiable, Hashable, Sendable {
    @DocumentID var id: String?
    var planId: String
    var key: String
    var label: String
    var value: String
    var createdAt: Date
    var updatedAt: Date
    var updatedBy: String?

    init(
        id: String? = nil,
        planId: String,
        key: String,
        label: String,
        value: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        updatedBy: String? = nil
    ) {
        self.id = id
        self.planId = planId
        self.key = key
        self.label = label
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }
}
