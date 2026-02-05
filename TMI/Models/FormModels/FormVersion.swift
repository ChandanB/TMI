//
//  FormVersion.swift
//  TMI
//
//  Form version tracking for template evolution and assignment stability
//

import Foundation
@preconcurrency import FirebaseFirestore

/// Represents a specific version of a form template
struct FormVersion: Codable, Identifiable, Sendable {
    @DocumentID var id: String?

    // Version identification
    let templateId: String
    var version: Int
    let versionLabel: String? // e.g., "v1.0", "Draft", "Final"

    // Template content snapshot
    let name: String
    let templateDescription: String
    let sections: [FormSection]

    // Metadata
    let createdAt: Date
    let createdBy: String
    let createdByName: String?
    var isActive: Bool
    var isPublished: Bool

    // Change tracking
    let changeLog: String?
    let parentVersionId: String? // Previous version this was based on

    // Usage tracking
    var usageCount: Int

    // Archival
    var archivedAt: Date?
    var archivedBy: String?

    init(
        id: String? = nil,
        templateId: String,
        version: Int,
        versionLabel: String? = nil,
        name: String,
        templateDescription: String,
        sections: [FormSection],
        createdAt: Date = Date(),
        createdBy: String,
        createdByName: String? = nil,
        isActive: Bool = true,
        isPublished: Bool = false,
        changeLog: String? = nil,
        parentVersionId: String? = nil,
        usageCount: Int = 0,
        archivedAt: Date? = nil,
        archivedBy: String? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.version = version
        self.versionLabel = versionLabel
        self.name = name
        self.templateDescription = templateDescription
        self.sections = sections
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.isActive = isActive
        self.isPublished = isPublished
        self.changeLog = changeLog
        self.parentVersionId = parentVersionId
        self.usageCount = usageCount
        self.archivedAt = archivedAt
        self.archivedBy = archivedBy
    }

    /// Create a version from a FormTemplate
    static func from(template: FormTemplate, createdBy: String, changeLog: String? = nil) -> FormVersion {
        return FormVersion(
            templateId: template.id ?? UUID().uuidString,
            version: template.version,
            versionLabel: "v\(template.version)",
            name: template.name,
            templateDescription: template.templateDescription,
            sections: template.sections,
            createdAt: Date(),
            createdBy: createdBy,
            isActive: true,
            isPublished: template.isPublic,
            changeLog: changeLog
        )
    }

    /// Convert version back to FormTemplate
    func toFormTemplate() -> FormTemplate {
        return FormTemplate(
            id: templateId,
            name: name,
            templateDescription: templateDescription,
            sections: sections,
            createdAt: createdAt,
            updatedAt: Date(),
            isActive: isActive,
            version: version,
            createdBy: createdBy
        )
    }
}

/// Version comparison metadata
struct FormVersionDiff: Codable, Sendable {
    let oldVersionId: String
    let newVersionId: String
    let sectionsAdded: Int
    let sectionsRemoved: Int
    let fieldsAdded: Int
    let fieldsRemoved: Int
    let fieldsModified: Int
    let summary: String

    init(
        oldVersion: FormVersion,
        newVersion: FormVersion
    ) {
        self.oldVersionId = oldVersion.id ?? ""
        self.newVersionId = newVersion.id ?? ""

        let oldSections = Set(oldVersion.sections.map { $0.id ?? "" })
        let newSections = Set(newVersion.sections.map { $0.id ?? "" })

        self.sectionsAdded = newSections.subtracting(oldSections).count
        self.sectionsRemoved = oldSections.subtracting(newSections).count

        let oldFields = Set(oldVersion.sections.flatMap { $0.fields }.map { $0.id ?? "" })
        let newFields = Set(newVersion.sections.flatMap { $0.fields }.map { $0.id ?? "" })

        self.fieldsAdded = newFields.subtracting(oldFields).count
        self.fieldsRemoved = oldFields.subtracting(newFields).count
        self.fieldsModified = oldFields.intersection(newFields).count

        // Generate summary
        var summaryParts: [String] = []
        if sectionsAdded > 0 { summaryParts.append("\(sectionsAdded) section(s) added") }
        if sectionsRemoved > 0 { summaryParts.append("\(sectionsRemoved) section(s) removed") }
        if fieldsAdded > 0 { summaryParts.append("\(fieldsAdded) field(s) added") }
        if fieldsRemoved > 0 { summaryParts.append("\(fieldsRemoved) field(s) removed") }

        self.summary = summaryParts.isEmpty ? "No changes" : summaryParts.joined(separator: ", ")
    }
}
