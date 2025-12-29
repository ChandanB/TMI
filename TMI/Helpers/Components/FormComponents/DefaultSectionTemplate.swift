//
//  DefaultSectionTemplate.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation

struct DefaultSectionTemplates {
    
    static let studentPersonalDetails = FormSection(
        title: "Student Details",
        fields: [
            FormField( label: "First Name", type: .text, isRequired: true),
            FormField( label: "Last Name", type: .text, isRequired: true),
            FormField( label: "Date of Birth", type: .date, isRequired: true),
            FormField( label: "Gender", type: .dropdown, isRequired: true, options: ["Male", "Female", "Other"])
        ]
    )
    
    static let personalDetails = FormSection(
        title: "Personal Details",
        fields: [
            FormField( label: "First Name", type: .text, isRequired: true),
            FormField( label: "Last Name", type: .text, isRequired: true),
            FormField( label: "Date of Birth", type: .date, isRequired: true),
            FormField( label: "Email Address", type: .email, isRequired: true),
            FormField( label: "Phone Number", type: .phoneNumber, isRequired: true)
        ]
    )
    
    static let address = FormSection(
        title: "Address",
        fields: [
            FormField( label: "Street Address", type: .text, isRequired: true),
            FormField( label: "City", type: .text, isRequired: true),
            FormField( label: "State/Province/Region", type: .text, isRequired: true),
            FormField( label: "Postal Code", type: .text, isRequired: true, validationRules: [
                ValidationRule.custom(message: "Enter a valid postal code", validator: { value in
                    guard let text = value as? String else { return false }
                    let pattern = "\\d{5}(-\\d{4})?"
                    return text.range(of: pattern, options: .regularExpression) != nil
                })
            ]),
            FormField( label: "Country", type: .dropdown, isRequired: true,options: ["United States", "Canada", "Mexico", "Other"])
        ]
    )
    
    static let medicalForm = FormSection(
        title: "Medical Information",
        fields: [
            FormField( label: "Allergies", type: .longText, isRequired: false),
            FormField( label: "Medications", type: .longText, isRequired: false),
            FormField( label: "Special Dietary Requirements", type: .longText, isRequired: false)
        ]
    )

    static let emergencyContact = FormSection(
        title: "Emergency Contact",
        fields: [
            FormField( label: "Emergency Contact Name", type: .text, isRequired: true),
            FormField( label: "Relationship to Student", type: .text, isRequired: true),
            FormField( label: "Emergency Contact Phone", type: .phoneNumber, isRequired: true, validationRules: [
                ValidationRule.custom(message: "Enter a valid phone number", validator: { value in
                    guard let text = value as? String else { return false }
                    let pattern = "^[+\\d]?(?:[\\d-\\.\\s()]*)$"
                    return text.range(of: pattern, options: .regularExpression) != nil
                })
            ]),
            FormField( label: "Email Address", type: .email, isRequired: true, validationRules: [
                ValidationRule.email(message: "Enter a valid email address")
            ])
        ]
    )
    
    static let photoConsent = FormSection(
        title: "Consent",
        fields: [
            FormField(label: "Photo Consent", type: .checkbox, isRequired: false, validationRules: []),
            FormField( label: "I agree to the Terms and Conditions", type: .checkbox, isRequired: true, validationRules: [
                ValidationRule.required(message: "You must agree to the terms and conditions to register")
            ])
        ]
    )
    
    static let employmentHistory = FormSection(
        title: "Employment History",
        fields: [FormField(  label: "Most Recent Job Title", type: .text, isRequired: true),
        ]
    )
    
    static let educationBackground = FormSection(
        title: "Education Background",
        fields: [FormField( label: "Highest Level of Education", type: .dropdown, isRequired: true, options: ["High School", "Associate's", "Bachelor's", "Master's", "Doctorate", "Other"]),
        ]
    )
    
    static let fileUpload = FormSection(
        title: "File Upload",
        fields: [FormField( label: "Cover Letter (optional)", type: .file, isRequired: false),
            FormField( label: "Resume", type: .file, isRequired: true)
        ]
    )
    
    static let declaration = FormSection(
        title: "Declaration",
        fields: [FormField( label: "I declare that the information provided is true and complete to the best of my knowledge.", type: .checkbox, isRequired: true, validationRules: [
            ValidationRule.required(message: "You must declare the information is true to submit the application")
        ])
        ]
    )
    
    static let all: [FormSection] = [studentPersonalDetails, personalDetails, address, emergencyContact, medicalForm, photoConsent, employmentHistory, educationBackground, fileUpload, declaration]
}

