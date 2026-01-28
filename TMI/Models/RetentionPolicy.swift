//
//  RetentionPolicy.swift
//  TMI
//
//  Data retention policy configuration
//

import Foundation

struct RetentionPolicy: Codable, Sendable {
    let districtId: String
    let retentionDays: Int
    let autoDelete: Bool
    let anonymizeAfterRetention: Bool

    init(
        districtId: String,
        retentionDays: Int,
        autoDelete: Bool,
        anonymizeAfterRetention: Bool
    ) {
        self.districtId = districtId
        self.retentionDays = retentionDays
        self.autoDelete = autoDelete
        self.anonymizeAfterRetention = anonymizeAfterRetention
    }
}

struct RetentionPolicyResult: Codable, Sendable {
    let districtId: String
    let evaluatedCount: Int
    let anonymizedCount: Int
    let deletedCount: Int
    let executedAt: Date
}
