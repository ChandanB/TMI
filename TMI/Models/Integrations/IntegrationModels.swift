//
//  IntegrationModels.swift
//  TMI
//
//  Shared models for SIS/LMS integrations
//

import Foundation

struct RosterSyncResult: Codable, Sendable {
    let provider: String
    let startedAt: Date
    let completedAt: Date
    let studentsAdded: Int
    let studentsUpdated: Int
    let studentsArchived: Int
    let staffAdded: Int
    let staffUpdated: Int
    let staffArchived: Int
    let classesSynced: Int
    let errors: [String]

    init(
        provider: String,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        studentsAdded: Int = 0,
        studentsUpdated: Int = 0,
        studentsArchived: Int = 0,
        staffAdded: Int = 0,
        staffUpdated: Int = 0,
        staffArchived: Int = 0,
        classesSynced: Int = 0,
        errors: [String] = []
    ) {
        self.provider = provider
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.studentsAdded = studentsAdded
        self.studentsUpdated = studentsUpdated
        self.studentsArchived = studentsArchived
        self.staffAdded = staffAdded
        self.staffUpdated = staffUpdated
        self.staffArchived = staffArchived
        self.classesSynced = classesSynced
        self.errors = errors
    }
}

struct StudentGrade: Codable, Sendable {
    let studentId: String
    let courseId: String
    let gradeValue: String
    let updatedAt: Date

    init(studentId: String, courseId: String, gradeValue: String, updatedAt: Date = Date()) {
        self.studentId = studentId
        self.courseId = courseId
        self.gradeValue = gradeValue
        self.updatedAt = updatedAt
    }
}

enum IntegrationStatus: String, Codable, CaseIterable, Sendable {
    case connected
    case disconnected
    case error
    case syncing
}

struct IntegrationConnection: Codable, Sendable {
    let provider: String
    let districtId: String
    let status: IntegrationStatus
    let connectedAt: Date?
    let lastSyncAt: Date?
    let lastSyncStatus: IntegrationStatus
}
