//
//  FormSubmission.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI
import SwiftData
import Foundation
import CoreTransferable
@preconcurrency import FirebaseFirestore

struct FormSection: Codable, Identifiable, Transferable, @unchecked Sendable {
    @DocumentID var id: String?
    var title: String
    var fields: [FormField]
    var location: CGPoint?
    var description: String?
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .formSection)
    }

    init(id: String? = nil, title: String, fields: [FormField], location: CGPoint? = nil) {
        self.id = id
        self.title = title
        self.fields = fields
        self.location = location
    }
}

struct FormField: Codable, Identifiable, Transferable, @unchecked Sendable {
    @DocumentID var id: String?
    var label: String
    var type: FieldType
    var isRequired: Bool
    var validationRules: [ValidationRule] = []
    var options: [String]?
    
    var placeholder: String?
    var defaultValue: AnyCodable?

    /// Scored forms: points for each option, parallel to `options`.
    var optionPoints: [Double]?
    /// Scored forms: points for a checked checkbox, or the multiplier for a rating.
    var points: Double?

    init(id: String? = nil, label: String, type: FieldType, isRequired: Bool, validationRules: [ValidationRule] = [], options: [String]? = nil, placeholder: String? = nil, defaultValue: AnyCodable? = nil, optionPoints: [Double]? = nil, points: Double? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.isRequired = isRequired
        self.validationRules = validationRules
        self.options = options
        self.placeholder = placeholder
        self.defaultValue = defaultValue
        self.optionPoints = optionPoints
        self.points = points
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sectionField)
    }
}

struct FormTemplate: Codable, Identifiable, @unchecked Sendable {
    @DocumentID var id: String?
    var name: String
    var templateDescription: String
    var sections: [FormSection]
    var createdAt: Date?
    var updatedAt: Date?
    var isActive: Bool
    var imageName: String?
    var category: String?
    var isFree: Bool?
    var author: String?
    var uses: Int = 0
    var tags: [String] = []

    /// New hex color string (e.g. "#FF5733") stored in Firestore
    var colorHex: String?

    // Phase 1: District Pilot fields
    var isPublic: Bool = false
    var districtId: String?
    var schoolId: String?
    var version: Int = 1
    var createdBy: String?

    /// When true, the server scores submissions from each field's points.
    var isScored: Bool?
    /// Labels for score ranges; each applies from its minimum upward.
    var scoreBands: [FormScoreBand]?

    // Computed helper to turn the hex into a SwiftUI Color
    var themeColor: Color {
        Color(colorHex ?? "#FFFFFF")
    }
    
    init(
        id: String? = nil,
        name: String,
        templateDescription: String,
        sections: [FormSection],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isActive: Bool,
        imageName: String? = nil,
        category: String? = nil,
        isFree: Bool? = nil,
        author: String? = nil,
        uses: Int = 0,
        tags: [String] = [],
        colorHex: String? = nil,
        isPublic: Bool = false,
        districtId: String? = nil,
        schoolId: String? = nil,
        version: Int = 1,
        createdBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.sections = sections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.imageName = imageName
        self.category = category
        self.isFree = isFree
        self.author = author
        self.uses = uses
        self.tags = tags
        self.colorHex = colorHex
        self.isPublic = isPublic
        self.districtId = districtId
        self.schoolId = schoolId
        self.version = version
        self.createdBy = createdBy
    }

    // Ensure Firestore encodes/decodes the new field
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case templateDescription
        case sections
        case createdAt
        case updatedAt
        case isActive
        case imageName
        case category
        case isFree
        case author
        case uses
        case tags
        case colorHex
        case isPublic
        case districtId
        case schoolId
        case version
        case createdBy
        case isScored
        case scoreBands
    }
}

/// A named score range for a scored form ("Low", "Moderate", …).
nonisolated struct FormScoreBand: Codable, Hashable, Sendable, Identifiable {
    var minimum: Double
    var label: String

    var id: String { "\(minimum)-\(label)" }
}

// MARK: - Parental Incarceration Support Module Template

extension FormTemplate {
    @MainActor
    static let parentalIncarcerationSupportTemplate = FormTemplate(
        name: "Parental Incarceration Support",
        templateDescription: "This module addresses the unique challenges faced by students who have experienced parental incarceration, offering targeted support, assessment, and resources.",
        sections: [
            FormSection(
                id: UUID().uuidString,
                title: "Parental Incarceration Details",
                fields: [
                    FormField(
                        id: UUID().uuidString,
                        label: "Which parent is currently incarcerated?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Mother", "Father", "Both parents", "Other primary caregiver"]
                    ),
                    FormField(
                        id: UUID().uuidString,
                        label: "How frequently do you have contact with your incarcerated parent?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Multiple times per week", "Once per week", "A few times per month", "Once per month", "Less than once per month", "No contact"]
                    ),
                    FormField(
                        id: UUID().uuidString,
                        label: "How old were you when your parent(s) was first incarcerated?",
                        type: .number,
                        isRequired: true,
                        validationRules: [
                            ValidationRule.numericRange(min: 0, max: 25, fieldName: "Age", message: "Age must be between 0 and 25")
                        ],
                        placeholder: "Enter your age at the time"
                    )
                ]
            ),
            FormSection(
                id: UUID().uuidString,
                title: "Impact Assessment",
                fields: [
                    FormField(
                        id: UUID().uuidString,
                        label: "How does your parent's incarceration affect your schooling and daily life?",
                        type: .longText,
                        isRequired: false,
                        placeholder: "Consider academics, social life, emotions, attendance, etc."
                    ),
                    FormField(
                        id: UUID().uuidString,
                        label: "What areas are most impacted?",
                        type: .multipleChoice,
                        isRequired: false,
                        options: ["Difficulty concentrating", "Absence from school", "Social relationships", "Behavior changes", "Emotional distress", "Stigma", "Other"]
                    )
                ]
            ),
            FormSection(
                id: UUID().uuidString,
                title: "Living Arrangement",
                fields: [
                    FormField(
                        id: UUID().uuidString,
                        label: "What is your current living arrangement?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Living with legal guardian (grandmother, grandfather, aunt, uncle, etc.)", "Living with other parent", "Foster care", "Other family arrangement"]
                    )
                ]
            ),
            FormSection(
                id: UUID().uuidString,
                title: "Support Resources",
                fields: [
                    FormField(
                        id: UUID().uuidString,
                        label: "What support or resources would help you most right now?",
                        type: .longText,
                        isRequired: false,
                        placeholder: "Examples: counseling, academic help, peer support, family resources, legal info, etc."
                    )
                ]
            )
        ],
        createdAt: Date(),
        updatedAt: Date(),
        isActive: true,
        imageName: nil, category: "Support",
        isFree: true,
        author: "TMI Team",
        tags: ["incarceration", "support", "wellness", "resources"],
        colorHex: "#7D5FFF"
    )
}

// End of Parental Incarceration Support Module Template


