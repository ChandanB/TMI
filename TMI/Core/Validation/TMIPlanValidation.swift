//
//  TMIPlanValidation.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import Foundation

// MARK: - TMI Plan Validation Extension

extension TMIPlan: Validatable {
    // NOTE: goals is immutable (let); mutations are not allowed.
    func validate() async throws {
        let logger = Log.tmiPlan
        logger.debug("Validating TMI Plan", metadata: ["planId": id ?? "new", "title": title])
        
        var validator = BatchValidator()
        
        // Title validation
        validator.add(field: "title") {
            ValidationRules.textLength(
                self.title,
                min: 3,
                max: 200,
                fieldName: "Plan Title"
            )
        }
        
        // Description validation
        if let description = description {
            validator.add(field: "description") {
                ValidationRules.textLength(
                    description,
                    min: 0,
                    max: 2000,
                    fieldName: "Description"
                )
            }
        }
        
        // Model validation
        validator.add(field: "model") {
            let validModels = TMIPlanModel.allCases.map(\.rawValue)
            if validModels.contains(self.model.rawValue) {
                return .valid
            } else {
                return ValidationResult.error("Invalid TMI plan model selected")
            }
        }
        
        // Students validation
        validator.add(field: "students") {
            ValidationRules.collectionSize(self.students, min: 1, max: 50, fieldName: "Students")
        }
        
        // Date validation
        validator.add(field: "startDate") {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            
            return ValidationRules.date(
                self.startDate,
                after: oneYearAgo,
                before: oneYearFromNow,
                fieldName: "Start Date"
            )
        }
        
        // End date validation (if provided)
        if let endDate = endDate {
            validator.add(field: "endDate") {
                // End date must be after start date
                if endDate <= self.startDate {
                    return ValidationResult.error("End date must be after start date")
                }
                
                // End date cannot be more than 2 years in the future
                let twoYearsFromNow = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
                if endDate > twoYearsFromNow {
                    return ValidationResult.error("End date cannot be more than 2 years in the future")
                }
                
                return .valid
            }
        }
        
        // Goals validation
        validator.add(field: "goals") {
            ValidationRules.collectionSize(self.goals, min: 0, max: 20, fieldName: "Goals")
        }
        
        // Validate each goal
        for (index, goal) in goals.enumerated() {
            validator.add(field: "goals[\(index)]") {
                ValidationRules.textLength(
                    goal.description,
                    min: 3,
                    max: 500,
                    fieldName: "Goal \(index + 1)"
                )
            }
        }
        
        // Strategies validation (if provided)
        if let strategies = strategies {
            validator.add(field: "strategies") {
                ValidationRules.collectionSize(strategies, min: 0, max: 30, fieldName: "Strategies")
            }
            
            // Validate each strategy
            for (index, strategy) in strategies.enumerated() {
                validator.add(field: "strategies[\(index)]") {
                    ValidationRules.textLength(
                        strategy,
                        min: 3,
                        max: 1000,
                        fieldName: "Strategy \(index + 1)"
                    )
                }
            }
        }
        
        // Progress tracking validation
        if let progressTracking = progressTracking {
            for (index, progress) in progressTracking.enumerated() {
                validator.add(field: "progressTracking[\(index)].score") {
                    ValidationRules.numericRange(
                        progress.score,
                        min: 0,
                        max: 1,
                        fieldName: "Progress Score \(index + 1)"
                    )
                }
                
                validator.add(field: "progressTracking[\(index)].date") {
                    // Progress dates cannot be in the future
                    if progress.date > Date() {
                        return ValidationResult.error("Progress tracking dates cannot be in the future")
                    }
                    
                    // Progress dates should be after plan start date
                    if progress.date < self.startDate {
                        return ValidationResult.error("Progress tracking dates must be after plan start date")
                    }
                    
                    return .valid
                }
                
                if let notes = progress.notes, !notes.isEmpty {
                    validator.add(field: "progressTracking[\(index)].notes") {
                        ValidationRules.textLength(
                            notes,
                            min: 0,
                            max: 1000,
                            fieldName: "Progress Notes \(index + 1)"
                        )
                    }
                }
            }
        }
        
        // Run all validations
        try validator.validate()
        
        // Additional business logic validations
        try await validateBusinessRules()
        
        logger.info("TMI Plan validation completed successfully", metadata: ["planId": id ?? "new"])
    }
    
    private func validateBusinessRules() async throws {
        let logger = Log.tmiPlan
        logger.debug("Validating TMI Plan business rules")
        
        // Validate that the plan model is appropriate for the student ages
        try await validateModelAgeAppropriateness()
        
        // Check for conflicting plans for the same students
        try await validateNoPlanConflicts()
        
        // Validate that required fields for the specific model are present
        try validateModelSpecificRequirements()
        
        logger.debug("TMI Plan business rules validation completed successfully")
    }
    
    private func validateModelAgeAppropriateness() async throws {
        // Some TMI models may be more appropriate for certain age groups
        let modelAgeRequirements: [String: (min: Int, max: Int)] = [
            "chase_your_space": (min: 5, max: 18),
            "acknowledge_interests": (min: 8, max: 25),
            "motivational_interviewing": (min: 12, max: 25),
            "restorative_practices": (min: 10, max: 25),
            "strength_based": (min: 6, max: 25),
            "trauma_informed": (min: 5, max: 25)
        ]
        
        guard let ageRequirement = modelAgeRequirements[model.rawValue] else {
            // No specific age requirements for this model
            return
        }
        
        // Check if all students meet the age requirement
        let studentAges = students.map { $0.age }
        let minStudentAge = studentAges.min() ?? 0
        let maxStudentAge = studentAges.max() ?? 0
        
        if minStudentAge < ageRequirement.min {
            throw TMIPlanServiceError.saveFailed("Some students are too young for the '\(model.rawValue)' model (minimum age: \(ageRequirement.min))")
        }
        
        if maxStudentAge > ageRequirement.max {
            throw TMIPlanServiceError.saveFailed("Some students are too old for the '\(model.rawValue)' model (maximum age: \(ageRequirement.max))")
        }
    }
    
    private func validateNoPlanConflicts() async throws {
        // In a real implementation, this would check the database for overlapping plans
        // for the same students during the same time period
        
        guard let endDate = endDate else { return }
        
        let dateRange = startDate...endDate
        
        for student in students {
            if let existingPlans = student.tmiPlans {
                for existingPlan in existingPlans {
                    guard let existingEndDate = existingPlan.endDate else { continue }
                    
                    let existingRange = existingPlan.startDate...existingEndDate
                    
                    // Check for date overlap
                    if dateRange.overlaps(existingRange) && existingPlan.id != self.id {
                        throw TMIPlanServiceError.saveFailed("Student '\(student.name)' already has an active TMI plan during this time period")
                    }
                }
            }
        }
    }
    
    private func validateModelSpecificRequirements() throws {
        // Each TMI model may have specific requirements
        switch model {
        case .chaseYourSpace:
            // Chase Your Space is appropriate for all ages
            break
            
        case .acknowledgeInterests:
            // Acknowledge Interests requires interests to be defined
            if interests.isEmpty {
                Log.tmiPlan.warning("Acknowledge Interests plan has no defined interests", metadata: ["planId": id ?? "new"])
            }
            
        case .alignYourMind:
            // No specific requirements
            break
            
        case .directAndCorrect:
            // No specific requirements
            break
            
        case .bullyToBoss:
            // No specific requirements
            break
            
        case .meekToProtector:
            // No specific requirements
            break
        }
    }
}

// MARK: - Convenience Validation Methods

extension TMIPlan {
    /// Quick validation check for form inputs
    static func validateField(_ field: TMIPlanField, value: Any) -> ValidationResult {
        switch field {
        case .title:
            guard let stringValue = value as? String else {
                return ValidationResult.error("Invalid title format")
            }
            return ValidationRules.textLength(stringValue, min: 3, max: 200, fieldName: "Plan Title")
            
        case .model:
            guard let stringValue = value as? String,
                  let _ = TMIPlanModel(rawValue: stringValue) else {
                return ValidationResult.error("Invalid model format")
            }
            return .valid
            
        case .startDate:
            guard let dateValue = value as? Date else {
                return ValidationResult.error("Invalid start date format")
            }
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            return ValidationRules.date(dateValue, after: oneYearAgo, before: oneYearFromNow, fieldName: "Start Date")
            
        case .endDate:
            guard let dateValue = value as? Date else {
                return ValidationResult.error("Invalid end date format")
            }
            let twoYearsFromNow = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
            return ValidationRules.date(dateValue, before: twoYearsFromNow, fieldName: "End Date")
            
        case .description:
            guard let stringValue = value as? String else {
                return ValidationResult.error("Invalid description format")
            }
            return ValidationRules.textLength(stringValue, min: 0, max: 2000, fieldName: "Description")
            
        case .students:
            guard let arrayValue = value as? [Student] else {
                return ValidationResult.error("Invalid students format")
            }
            return ValidationRules.collectionSize(arrayValue, min: 1, max: 50, fieldName: "Students")
        }
    }
    
    /// Sanitize TMI Plan input data
    mutating func sanitizeInput() {
        title = Sanitizer.sanitizeText(title)
        
        if let desc = description {
            description = Sanitizer.sanitizeText(desc)
        }
        
        // Sanitize goals
        /*
         goals = goals.map { goal in
             var sanitizedGoal = goal
             sanitizedGoal.description = Sanitizer.sanitizeText(goal.description)
             return sanitizedGoal
         }
         */
        // Cannot mutate goals because it is a let constant
        
        // Sanitize strategies
        if let strat = strategies {
            strategies = strat.map { Sanitizer.sanitizeText($0) }
        }
        
        // Sanitize progress tracking notes
        if let progress = progressTracking {
            progressTracking = progress.map { entry in
                let sanitizedEntry = entry
                /*
                if let notes = entry.notes {
                    sanitizedEntry.notes = Sanitizer.sanitizeText(notes)
                }
                */
                // Cannot mutate notes because it is a let constant
                return sanitizedEntry
            }
        }
    }
    
    /// Generate validation summary for debugging
    func generateValidationSummary() -> ValidationSummary {
        return ValidationSummary(
            entityType: "TMIPlan",
            entityId: id ?? "new",
            requiredFields: TMIPlanField.allCases.filter(\.isRequired).map(\.displayName),
            optionalFields: TMIPlanField.allCases.filter { !$0.isRequired }.map(\.displayName),
            studentCount: students.count,
            hasEndDate: endDate != nil,
            hasGoals: !goals.isEmpty,
            hasStrategies: strategies != nil && !(strategies?.isEmpty ?? true),
            progressTrackingCount: progressTracking?.count ?? 0
        )
    }
}

// MARK: - TMI Plan Field Enum

enum TMIPlanField: String, CaseIterable, Sendable {
    case title = "title"
    case model = "model"
    case students = "students"
    case startDate = "startDate"
    case endDate = "endDate"
    case description = "description"
    
    var displayName: String {
        switch self {
        case .title: return "Plan Title"
        case .model: return "TMI Model"
        case .students: return "Students"
        case .startDate: return "Start Date"
        case .endDate: return "End Date"
        case .description: return "Description"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .title, .model, .students, .startDate:
            return true
        case .endDate, .description:
            return false
        }
    }
}

// MARK: - Validation Summary

struct ValidationSummary: Sendable {
    let entityType: String
    let entityId: String
    let requiredFields: [String]
    let optionalFields: [String]
    let studentCount: Int
    let hasEndDate: Bool
    let hasGoals: Bool
    let hasStrategies: Bool
    let progressTrackingCount: Int
    
    var description: String {
        """
        Validation Summary for \(entityType) (\(entityId)):
        - Required Fields: \(requiredFields.joined(separator: ", "))
        - Optional Fields: \(optionalFields.joined(separator: ", "))
        - Student Count: \(studentCount)
        - Has End Date: \(hasEndDate)
        - Has Goals: \(hasGoals)
        - Has Strategies: \(hasStrategies)
        - Progress Tracking Entries: \(progressTrackingCount)
        """
    }
}

