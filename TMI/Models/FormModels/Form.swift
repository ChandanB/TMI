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
import FirebaseFirestore

struct FormSubmission: Codable, Identifiable {
    @DocumentID var id: String?
    var formId: String
    var data: [String: AnyCodable]
    var submissionDate: Date = Date()
    
    init(id: String? = nil, formId: String, data: [String: AnyCodable], submissionDate: Date = Date()) {
          self.id = id
          self.formId = formId
          self.data = data
          self.submissionDate = submissionDate
      }
}

struct FormSection: Codable, Identifiable, Transferable {
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

struct FormField: Codable, Identifiable, Transferable {
    @DocumentID var id: String?
    var label: String
    var type: FieldType
    var isRequired: Bool
    var validationRules: [ValidationRule] = []
    var options: [String]?
    
    var placeholder: String?
    var defaultValue: AnyCodable?

    init(id: String? = nil, label: String, type: FieldType, isRequired: Bool, validationRules: [ValidationRule] = [], options: [String]? = nil, placeholder: String? = nil, defaultValue: AnyCodable? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.isRequired = isRequired
        self.validationRules = validationRules
        self.options = options
        self.placeholder = placeholder
        self.defaultValue = defaultValue
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sectionField)
    }
}

struct FormTemplate: Codable, Identifiable {
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
        colorHex: String? = nil
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
    }
}

// MARK: - Parental Incarceration Support Module Template

extension FormTemplate {
    static let parentalIncarcerationSupportTemplate = FormTemplate(
        name: "Parental Incarceration Support",
        templateDescription: "This module addresses the unique challenges faced by students who have experienced parental incarceration, offering targeted support, assessment, and resources.",
        sections: [
            FormSection(
                title: "Parental Incarceration Details",
                fields: [
                    FormField(
                        label: "Which parent is currently incarcerated?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Mother", "Father", "Both parents", "Other primary caregiver"]
                    ),
                    FormField(
                        label: "How frequently do you have contact with your incarcerated parent?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Multiple times per week", "Once per week", "A few times per month", "Once per month", "Less than once per month", "No contact"]
                    ),
                    FormField(
                        label: "How old were you when your parent(s) was first incarcerated?",
                        type: .number,
                        isRequired: true,
                        validationRules: [
                            ValidationRule(rule: .minValue, message: "Age must be at least 0", value: AnyCodable(0)),
                            ValidationRule(rule: .maxValue, message: "Age must be 25 or younger", value: AnyCodable(25))
                        ],
                        placeholder: "Enter your age at the time"
                    )
                ]
            ),
            FormSection(
                title: "Impact Assessment",
                fields: [
                    FormField(
                        label: "How does your parent's incarceration affect your schooling and daily life?",
                        type: .longText,
                        isRequired: false,
                        placeholder: "Consider academics, social life, emotions, attendance, etc."
                    ),
                    FormField(
                        label: "What areas are most impacted?",
                        type: .multipleChoice,
                        isRequired: false,
                        options: ["Difficulty concentrating", "Absence from school", "Social relationships", "Behavior changes", "Emotional distress", "Stigma", "Other"]
                    )
                ]
            ),
            FormSection(
                title: "Living Arrangement",
                fields: [
                    FormField(
                        label: "What is your current living arrangement?",
                        type: .multipleChoice,
                        isRequired: true,
                        options: ["Living with legal guardian (grandmother, grandfather, aunt, uncle, etc.)", "Living with other parent", "Foster care", "Other family arrangement"]
                    )
                ]
            ),
            FormSection(
                title: "Support Resources",
                fields: [
                    FormField(
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

