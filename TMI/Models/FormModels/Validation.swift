//
//  Validation.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftData
import SwiftUI
import CoreTransferable
import FirebaseFirestore
import UniformTypeIdentifiers

struct ValidationRule: Codable, Identifiable {
    @DocumentID var id: String?
    var rule: ValidationType
    var message: String
    var value: AnyCodable?
    
    init(id: String? = nil, rule: ValidationType, message: String, value: AnyCodable? = nil) {
        self.id = id
        self.rule = rule
        self.message = message
        self.value = value
    }
}

enum ValidationType: String, Codable, CaseIterable {
    case minLength = "Minimum Length"
    case maxLength = "Maximum Length"
    case minValue = "Minimum Numeric Value"
    case maxValue = "Maximum Numeric Value"
    case regex = "Regex Pattern"
    case required = "Required Field"
    case email = "Email Format"
    case url = "URL Format"
    
    var description: String {
        switch self {
        case .minLength:
            return "Field must have a minimum number of characters."
        case .maxLength:
            return "Field must not exceed a maximum number of characters."
        case .minValue:
            return "Field must have a numeric value greater than or equal to the specified minimum."
        case .maxValue:
            return "Field must have a numeric value less than or equal to the specified maximum."
        case .regex:
            return "Field value must match the specified regular expression pattern."
        case .required:
            return "Field is mandatory and cannot be left blank."
        case .email:
            return "Field must contain a valid email address."
        case .url:
            return "Field must contain a valid URL."
        }
    }
    
    var valuePlaceholder: String {
        switch self {
        case .minLength:
            return "Minimum character count"
        case .maxLength:
            return "Maximum character count"
        case .minValue:
            return "Minimum numeric value"
        case .maxValue:
            return "Maximum numeric value"
        case .regex:
            return "Regular expression pattern"
        default:
            return "Value"
        }
    }
    
    var placeholderText: String {
        switch self {
        case .minLength, .maxLength:
            return "Enter number of characters"
        case .minValue, .maxValue:
            return "Enter numeric value"
        case .regex:
            return "Enter regex pattern"
        default:
            return "Enter value"
        }
    }
    
    var displayValue: String {
        switch self {
        case .minLength: return "Min Length"
        case .maxLength: return "Max Length"
        default: return self.rawValue.capitalized
        }
    }
    
    var requiresValue: Bool {
        switch self {
        case .minLength, .maxLength, .minValue, .maxValue, .regex:
            return true
        default:
            return false
        }
    }
    
    var keyboardType: UIKeyboardType {
        switch self {
        case .minValue, .maxValue:
            return .numberPad
        default:
            return .default
        }
    }
    
    static func defaultRule(for fieldType: FieldType) -> ValidationType {
        switch fieldType {
        case .text, .longText:
            return .minLength
        case .number:
            return .minValue
        default:
            return .required
        }
    }
    
    func isApplicable(to fieldType: FieldType) -> Bool {
        switch self {
        case .minLength, .maxLength:
            return fieldType == .text || fieldType == .longText || fieldType == .email || fieldType == .url
        case .minValue, .maxValue:
            return fieldType == .number
        case .regex:
            return fieldType != .checkbox && fieldType != .dropdown && fieldType != .multipleChoice && fieldType != .date && fieldType != .dateTime && fieldType != .time
        case .required:
            return true
        case .email:
            return fieldType == .email
        case .url:
            return fieldType == .url
        }
    }
}

enum FieldType: String, Codable, CaseIterable {
    case text
    case longText
    case number
    case date
    case dateTime
    case time
    case dropdown
    case multipleChoice
    case checkbox
    case email
    case phoneNumber
    case url
    case file
    case allCases
    
    var requiresOptions: Bool {
        switch self {
        case .dropdown, .multipleChoice:
            return true
        default:
            return false
        }
    }
    
    var allowsValidation: Bool {
        switch self {
        case .text, .longText, .number, .email, .phoneNumber, .url:
            return true
        default:
            return false
        }
    }
    
    var defaultLabel: String {
        switch self {
        case .text:
            return "Text Field"
        case .longText:
            return "Large Text Field"
        case .number:
            return "Number Field"
        case .date:
            return "Date Field"
        case .time:
            return "Time Field"
        case .dateTime:
            return "Date & Time Field"
        case .dropdown:
            return "Dropdown Field"
        case .multipleChoice:
            return "Multiple Choice Field"
        case .checkbox:
            return "Checkbox Field"
        case .email:
            return "Email Field"
        case .phoneNumber:
            return "Phone Number Field"
        case .url:
            return "URL Field"
        case .file:
            return "File Upload Field"
        case .allCases:
            return "All Field"
        }
    }
}

extension UTType {
    static var formSection: UTType { UTType(exportedAs: "com.example.formSection") }
    static var sectionField: UTType { UTType(exportedAs: "com.example.sectionField") }
}

