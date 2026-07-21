//
//  StudentValidation.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import Foundation

nonisolated extension Student: Validatable {
    func validate() async throws {
        let logger = TMILogger(category: "StudentValidation")
        logger.debug("Validating student record")
        
        var validator = BatchValidator()
        
        // Name validation
        validator.add(field: "name") {
            ValidationRules.name(self.name)
        }
        
        // Grade validation
        validator.add(field: "grade") {
            ValidationRules.grade(self.grade)
        }
        
        // School validation
        validator.add(field: "school") {
            ValidationRules.schoolName(self.school)
        }
        
        // Age validation (based on date of birth)
        validator.add(field: "dateOfBirth") {
            let currentAge = self.age
            return ValidationRules.studentAge(currentAge)
        }
        
        // Date of birth range validation
        validator.add(field: "dateOfBirth") {
            let currentDate = Date()
            let minDate = Calendar.current.date(byAdding: .year, value: -25, to: currentDate) ?? currentDate
            let maxDate = Calendar.current.date(byAdding: .year, value: -3, to: currentDate) ?? currentDate
            
            return ValidationRules.date(
                self.dateOfBirth,
                after: minDate,
                before: maxDate,
                fieldName: "Date of birth"
            )
        }
        
        // Student ID validation (if provided)
        if let studentID = studentID, !studentID.isEmpty {
            validator.add(field: "studentID") {
                ValidationRules.textLength(
                    studentID,
                    min: 1,
                    max: 50,
                    fieldName: "Student ID"
                )
            }
        }
        
        // Photo URL validation (if provided)
        if let photoURL = photoURL {
            validator.add(field: "photoURL") {
                ValidationRules.url(photoURL.absoluteString)
            }
        }
        
        // Note: Hobbies are now included in interests array
        
        // Run all validations
        try validator.validate()
        
        // Additional business logic validations
        try await validateBusinessRules()
        
        logger.info("Student record validation completed successfully")
    }
    
    private func validateBusinessRules() async throws {
        let logger = TMILogger(category: "StudentBusinessRules")
        
        // Check for duplicate student based on name and date of birth
        // This would typically involve a database query
        logger.debug("Validating business rules for student")
        
        // Load interests via edge collection (migration helpers)
        let interests: [Interest] = (try? await self.fetchInterestsFromEdgeCollection()) ?? []
        let interestCount: Int = (try? await self.getInterestCount()) ?? interests.count
        
        // Enforce maximum interests rule (moved from synchronous batch validation)
        if interestCount > 20 {
            throw ValidationError.validationFailed(
                field: "interests",
                message: "Too many interests selected (maximum 20)"
            )
        }
        
        // Example: Validate that student is not too young for selected interests
        let hasAgeRestrictedInterests = interests.contains { interest in
            (interest.careerPathways?.contains(CareerPathway.business) == true) ||
            (interest.category.contains(InterestCategory.technology))
        }
        
        if age < 13 && hasAgeRestrictedInterests {
            throw ValidationError.validationFailed(
                field: "interests",
                message: "Some selected interests are not appropriate for students under 13"
            )
        }
        
        // Validate engagement history consistency
        if let engagementHistory = engagementHistory {
            for record in engagementHistory {
                if record.score < 0.0 || record.score > 1.0 {
                    throw ValidationError.validationFailed(
                        field: "engagementHistory",
                        message: "Engagement scores must be between 0.0 and 1.0"
                    )
                }
                
                if record.date > Date() {
                    throw ValidationError.validationFailed(
                        field: "engagementHistory",
                        message: "Engagement records cannot be dated in the future"
                    )
                }
            }
        }
        
        // Validate TMI plans if present
        if let tmiPlans = tmiPlans {
            for plan in tmiPlans {
                do {
                    try await plan.validate()
                } catch {
                    throw ValidationError.validationFailed(
                        field: "tmiPlans",
                        message: "Invalid TMI plan: \(error.localizedDescription)"
                    )
                }
            }
        }
        
        logger.debug("Business rules validation completed successfully")
    }
}

// MARK: - Convenience Validation Methods
nonisolated extension Student {
    /// Quick validation check for form inputs
    static func validateField(_ field: StudentField, value: Any) -> ValidationResult {
        switch field {
        case .name:
            guard let stringValue = value as? String else { return .error("Invalid name format") }
            return ValidationRules.name(stringValue)
            
        case .grade:
            guard let stringValue = value as? String else { return .error("Invalid grade format") }
            return ValidationRules.grade(stringValue)
            
        case .school:
            guard let stringValue = value as? String else { return .error("Invalid school format") }
            return ValidationRules.schoolName(stringValue)
            
        case .dateOfBirth:
            guard let dateValue = value as? Date else { return .error("Invalid date format") }
            let currentDate = Date()
            let minDate = Calendar.current.date(byAdding: .year, value: -25, to: currentDate) ?? currentDate
            let maxDate = Calendar.current.date(byAdding: .year, value: -3, to: currentDate) ?? currentDate
            return ValidationRules.date(dateValue, after: minDate, before: maxDate, fieldName: "Date of birth")
            
        case .studentID:
            guard let stringValue = value as? String else { return .error("Invalid student ID format") }
            if stringValue.isEmpty { return .valid } // Optional field
            return ValidationRules.textLength(stringValue, min: 1, max: 50, fieldName: "Student ID")
            
        case .photoURL:
            guard let urlValue = value as? URL else { return .error("Invalid URL format") }
            return ValidationRules.url(urlValue.absoluteString)
        }
    }
    
    /// Sanitize student input data
    mutating func sanitizeInput() {
        let sanitizedName = Sanitizer.sanitizeText(name)
        let sanitizedGrade = Sanitizer.sanitizeText(grade)
        let sanitizedSchool = Sanitizer.sanitizeText(school)
        
        // Create new student with sanitized data
        let sanitizedStudent = Student(
            id: id,
            name: sanitizedName,
            grade: sanitizedGrade,
            school: sanitizedSchool,
            dateOfBirth: dateOfBirth,
            tmiPlans: tmiPlans,
            studentID: studentID.map(Sanitizer.sanitizeText),
            photoURL: photoURL,
            surveyResults: surveyResults,
            academicPerformance: academicPerformance,
            engagementHistory: engagementHistory,
            notes: notes?.map { note in
                var sanitizedNote = note
                sanitizedNote.content = Sanitizer.sanitizeText(note.content)
                return sanitizedNote
            },
            lastInteractionDate: lastInteractionDate
        )
        
        self = sanitizedStudent
    }
}

// MARK: - Student Field Enum
nonisolated enum StudentField: String, CaseIterable, Sendable {
    case name = "name"
    case grade = "grade"
    case school = "school"
    case dateOfBirth = "dateOfBirth"
    case studentID = "studentID"
    case photoURL = "photoURL"
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .grade: return "Grade"
        case .school: return "School"
        case .dateOfBirth: return "Date of Birth"
        case .studentID: return "Student ID"
        case .photoURL: return "Photo URL"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .name, .grade, .school, .dateOfBirth:
            return true
        case .studentID, .photoURL:
            return false
        }
    }
}
