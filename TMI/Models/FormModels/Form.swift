//
//  FormSubmission.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

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

    init(id: String? = nil, label: String, type: FieldType, isRequired: Bool, validationRules: [ValidationRule] = [], options: [String]? = nil) {
        self.id = id
        self.label = label
        self.type = type
        self.isRequired = isRequired
        self.validationRules = validationRules
        self.options = options
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
        isFree: Bool? = nil
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
    }
}

