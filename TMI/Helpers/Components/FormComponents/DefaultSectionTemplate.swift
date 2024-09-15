//
//  DefaultSectionTemplate.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation

struct DefaultSectionTemplates {
    
    static let camperPersonalDetails = FormSection(
        id: UUID().uuidString,
        title: "Camper Details",
        fields: [
            FormField(id: UUID().uuidString, label: "First Name", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Last Name", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Date of Birth", type: .date, isRequired: true),
            FormField(id: UUID().uuidString, label: "Gender", type: .dropdown, isRequired: true, options: ["Male", "Female", "Other"])
        ]
    )
    
    static let personalDetails = FormSection(
        id: UUID().uuidString,
        title: "Personal Details",
        fields: [
            FormField(id: UUID().uuidString, label: "First Name", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Last Name", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Date of Birth", type: .date, isRequired: true),
            FormField(id: UUID().uuidString, label: "Email Address", type: .email, isRequired: true),
            FormField(id: UUID().uuidString, label: "Phone Number", type: .phoneNumber, isRequired: true)
        ]
    )
    
    static let address = FormSection(
        id: UUID().uuidString,
        title: "Address",
        fields: [
            FormField(id: UUID().uuidString, label: "Street Address", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "City", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "State/Province/Region", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Postal Code", type: .text, isRequired: true, validationRules: [ValidationRule(id: UUID().uuidString, rule: .regex, message: "Enter a valid postal code", value: AnyCodable("\\d{5}(-\\d{4})?"))]),
            FormField(id: UUID().uuidString, label: "Country", type: .dropdown, isRequired: true,options: ["United States", "Canada", "Mexico", "Other"])
        ]
    )
    
    static let medicalForm = FormSection(
        id: UUID().uuidString,
        title: "Medical Information",
        fields: [
            FormField(id: UUID().uuidString, label: "Allergies", type: .longText, isRequired: false),
            FormField(id: UUID().uuidString, label: "Medications", type: .longText, isRequired: false),
            FormField(id: UUID().uuidString, label: "Special Dietary Requirements", type: .longText, isRequired: false)
        ]
    )

    static let emergencyContact = FormSection(
        id: UUID().uuidString,
        title: "Emergency Contact",
        fields: [
            FormField(id: UUID().uuidString, label: "Emergency Contact Name", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Relationship to Camper", type: .text, isRequired: true),
            FormField(id: UUID().uuidString, label: "Emergency Contact Phone", type: .phoneNumber, isRequired: true, validationRules: [ValidationRule(id: UUID().uuidString, rule: .regex, message: "Enter a valid phone number", value: AnyCodable("^[+\\d]?(?:[\\d-\\.\\s()]*)$"))]),
            FormField(id: UUID().uuidString, label: "Email Address", type: .email, isRequired: true, validationRules: [ValidationRule(id: UUID().uuidString, rule: .email, message: "Enter a valid email address")])
        ]
    )
    
    static let photoConsent = FormSection(
        id: UUID().uuidString,
        title: "Consent",
        fields: [
            FormField(id: UUID().uuidString,label: "Photo Consent", type: .checkbox, isRequired: false, validationRules: []),
            FormField(id: UUID().uuidString, label: "I agree to the Terms and Conditions", type: .checkbox, isRequired: true, validationRules: [ValidationRule(id: UUID().uuidString, rule: .required, message: "You must agree to the terms and conditions to register")])
        ]
    )
    
    static let employmentHistory = FormSection(
        id: UUID().uuidString,
        title: "Employment History",
        fields: [FormField( id: UUID().uuidString, label: "Most Recent Job Title", type: .text, isRequired: true),
        ]
    )
    
    static let eductionBackground = FormSection(
        id: UUID().uuidString,
        title: "Education Background",
        fields: [FormField(id: UUID().uuidString, label: "Highest Level of Education", type: .dropdown, isRequired: true, options: ["High School", "Associate's", "Bachelor's", "Master's", "Doctorate", "Other"]),
        ]
    )
    
    static let fileUpload = FormSection(
        id: UUID().uuidString,
        title: "File Upload",
        fields: [FormField(id: UUID().uuidString, label: "Cover Letter (optional)", type: .file, isRequired: false),
            FormField(id: UUID().uuidString, label: "Resume", type: .file, isRequired: true)
        ]
    )
    
    static let declaration = FormSection(
        id: UUID().uuidString,
        title: "Declaration",
        fields: [FormField(id: UUID().uuidString, label: "I declare that the information provided is true and complete to the best of my knowledge.", type: .checkbox, isRequired: true, validationRules: [ValidationRule(id: UUID().uuidString, rule: .required, message: "You must declare the information is true to submit the application")])
        ]
    )
    
    static let all: [FormSection] = [camperPersonalDetails, personalDetails, address, emergencyContact, medicalForm, photoConsent, employmentHistory, eductionBackground, fileUpload, declaration]
}

