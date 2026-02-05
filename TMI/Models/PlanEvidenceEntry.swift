//
//  PlanEvidenceEntry.swift
//  TMI
//
//  Evidence tracking entries captured per plan.
//

import FirebaseFirestore
import Foundation

enum PlanEvidenceKind: String, Codable, CaseIterable, Sendable {
    case checklist
    case streak
    case incident
    case thoughtLog
    case rating
    case feedback
    case tally
    case quest
    case reflection
    case note
}

struct PlanEvidenceEntry: Codable, Identifiable, Hashable, Sendable {
    @DocumentID var id: String?
    var planId: String
    var type: PlanEvidenceKind
    var category: String?
    var title: String
    var details: String?
    var numericValue: Double?
    var createdAt: Date
    var createdBy: String?
    var metadata: [String: String]?

    init(
        id: String? = nil,
        planId: String,
        type: PlanEvidenceKind,
        category: String? = nil,
        title: String,
        details: String? = nil,
        numericValue: Double? = nil,
        createdAt: Date = Date(),
        createdBy: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.planId = planId
        self.type = type
        self.category = category
        self.title = title
        self.details = details
        self.numericValue = numericValue
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.metadata = metadata
    }
}
