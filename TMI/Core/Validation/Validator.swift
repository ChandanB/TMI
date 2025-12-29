//
//  Validator.swift
//  TMI
//
//  Created by Claude Code on 8/20/25.
//

import Foundation

// MARK: - Validation Protocol
protocol Validatable: Sendable {
    func validate() async throws
}

// MARK: - Validation Result
enum ValidationResult: Sendable, Equatable {
    case valid
    case error(String)
    case idle
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    var hasError: Bool {
        if case .error = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Validation Rule Types
enum ValidationRuleType: String, Codable, Hashable, Sendable, CaseIterable {
    case email
    case name
    case phone
    case url
    case required
    case schoolName
    case textLength
    case numericRange
    case collectionSize
    case date
    case custom
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .name: return "Name"
        case .phone: return "Phone"
        case .url: return "URL"
        case .required: return "Required"
        case .schoolName: return "School Name"
        case .textLength: return "Text Length"
        case .numericRange: return "Numeric Range"
        case .collectionSize: return "Collection Size"
        case .date: return "Date"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Validation Configuration
struct ValidationRule: Codable, Hashable, Identifiable, Sendable {
    var id: String = UUID().uuidString
    var ruleType: ValidationRuleType
    var message: String
    var parameters: ValidationParameters?
    
    init(
        id: String = UUID().uuidString,
        ruleType: ValidationRuleType,
        message: String,
        parameters: ValidationParameters? = nil
    ) {
        self.id = id
        self.ruleType = ruleType
        self.message = message
        self.parameters = parameters
    }
    
    // MARK: - Convenience Initializers
    
    /// Create an email validation rule
    static func email(message: String = "Invalid email format") -> ValidationRule {
        return ValidationRule(ruleType: .email, message: message)
    }
    
    /// Create a name validation rule
    static func name(message: String = "Invalid name format") -> ValidationRule {
        return ValidationRule(ruleType: .name, message: message)
    }
    
    /// Create a phone validation rule
    static func phone(message: String = "Invalid phone number format") -> ValidationRule {
        return ValidationRule(ruleType: .phone, message: message)
    }
    
    /// Create a URL validation rule
    static func url(message: String = "Invalid URL format") -> ValidationRule {
        return ValidationRule(ruleType: .url, message: message)
    }
    
    /// Create a required field validation rule
    static func required(message: String = "This field is required") -> ValidationRule {
        return ValidationRule(ruleType: .required, message: message)
    }
    
    /// Create a school name validation rule
    static func schoolName(message: String = "Invalid school name format") -> ValidationRule {
        return ValidationRule(ruleType: .schoolName, message: message)
    }
    
    /// Create a text length validation rule
    static func textLength(
        min: Int,
        max: Int,
        fieldName: String,
        message: String? = nil
    ) -> ValidationRule {
        let defaultMessage = message ?? "\(fieldName) must be between \(min) and \(max) characters"
        let parameters = ValidationParameters.textLength(min: min, max: max, fieldName: fieldName)
        return ValidationRule(ruleType: .textLength, message: defaultMessage, parameters: parameters)
    }
    
    /// Create a numeric range validation rule
    static func numericRange(
        min: Int,
        max: Int,
        fieldName: String,
        message: String? = nil
    ) -> ValidationRule {
        let defaultMessage = message ?? "\(fieldName) must be between \(min) and \(max)"
        let parameters = ValidationParameters.numericRange(min: min, max: max, fieldName: fieldName)
        return ValidationRule(ruleType: .numericRange, message: defaultMessage, parameters: parameters)
    }
    
    /// Create a collection size validation rule
    static func collectionSize(
        min: Int,
        max: Int,
        fieldName: String,
        message: String? = nil
    ) -> ValidationRule {
        let defaultMessage = message ?? "\(fieldName) must contain between \(min) and \(max) items"
        let parameters = ValidationParameters.collectionSize(min: min, max: max, fieldName: fieldName)
        return ValidationRule(ruleType: .collectionSize, message: defaultMessage, parameters: parameters)
    }
    
    /// Create a date validation rule
    static func date(
        after: Date? = nil,
        before: Date? = nil,
        fieldName: String,
        message: String? = nil
    ) -> ValidationRule {
        let defaultMessage = message ?? "Invalid date for \(fieldName)"
        let parameters = ValidationParameters.date(after: after, before: before, fieldName: fieldName)
        return ValidationRule(ruleType: .date, message: defaultMessage, parameters: parameters)
    }
    
    /// Create a custom validation rule
    static func custom(
        message: String,
        validator: @escaping @Sendable (Any?) -> Bool
    ) -> ValidationRule {
        let parameters = ValidationParameters.custom(validator: validator)
        return ValidationRule(ruleType: .custom, message: message, parameters: parameters)
    }
}

// MARK: - Validation Parameters
enum ValidationParameters: Codable, Hashable, Sendable {
    case textLength(min: Int, max: Int, fieldName: String)
    case numericRange(min: Int, max: Int, fieldName: String)
    case collectionSize(min: Int, max: Int, fieldName: String)
    case date(after: Date?, before: Date?, fieldName: String)
    case custom(validator: @Sendable (Any?) -> Bool)
    
    // Custom coding for the validator case
    enum CodingKeys: String, CodingKey {
        case type, min, max, fieldName, after, before
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "textLength":
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            let fieldName = try container.decode(String.self, forKey: .fieldName)
            self = .textLength(min: min, max: max, fieldName: fieldName)
        case "numericRange":
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            let fieldName = try container.decode(String.self, forKey: .fieldName)
            self = .numericRange(min: min, max: max, fieldName: fieldName)
        case "collectionSize":
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            let fieldName = try container.decode(String.self, forKey: .fieldName)
            self = .collectionSize(min: min, max: max, fieldName: fieldName)
        case "date":
            let after = try container.decodeIfPresent(Date.self, forKey: .after)
            let before = try container.decodeIfPresent(Date.self, forKey: .before)
            let fieldName = try container.decode(String.self, forKey: .fieldName)
            self = .date(after: after, before: before, fieldName: fieldName)
        case "custom":
            // Custom validators can't be encoded/decoded, so use a default
            self = .custom(validator: { _ in true })
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown validation parameter type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .textLength(let min, let max, let fieldName):
            try container.encode("textLength", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
            try container.encode(fieldName, forKey: .fieldName)
        case .numericRange(let min, let max, let fieldName):
            try container.encode("numericRange", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
            try container.encode(fieldName, forKey: .fieldName)
        case .collectionSize(let min, let max, let fieldName):
            try container.encode("collectionSize", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
            try container.encode(fieldName, forKey: .fieldName)
        case .date(let after, let before, let fieldName):
            try container.encode("date", forKey: .type)
            try container.encodeIfPresent(after, forKey: .after)
            try container.encodeIfPresent(before, forKey: .before)
            try container.encode(fieldName, forKey: .fieldName)
        case .custom:
            try container.encode("custom", forKey: .type)
        }
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        switch self {
        case .textLength(let min, let max, let fieldName):
            hasher.combine("textLength")
            hasher.combine(min)
            hasher.combine(max)
            hasher.combine(fieldName)
        case .numericRange(let min, let max, let fieldName):
            hasher.combine("numericRange")
            hasher.combine(min)
            hasher.combine(max)
            hasher.combine(fieldName)
        case .collectionSize(let min, let max, let fieldName):
            hasher.combine("collectionSize")
            hasher.combine(min)
            hasher.combine(max)
            hasher.combine(fieldName)
        case .date(let after, let before, let fieldName):
            hasher.combine("date")
            hasher.combine(after)
            hasher.combine(before)
            hasher.combine(fieldName)
        case .custom:
            hasher.combine("custom")
        }
    }
    
    static func == (lhs: ValidationParameters, rhs: ValidationParameters) -> Bool {
        switch (lhs, rhs) {
        case (.textLength(let lMin, let lMax, let lField), .textLength(let rMin, let rMax, let rField)):
            return lMin == rMin && lMax == rMax && lField == rField
        case (.numericRange(let lMin, let lMax, let lField), .numericRange(let rMin, let rMax, let rField)):
            return lMin == rMin && lMax == rMax && lField == rField
        case (.collectionSize(let lMin, let lMax, let lField), .collectionSize(let rMin, let rMax, let rField)):
            return lMin == rMin && lMax == rMax && lField == rField
        case (.date(let lAfter, let lBefore, let lField), .date(let rAfter, let rBefore, let rField)):
            return lAfter == rAfter && lBefore == rBefore && lField == rField
        case (.custom, .custom):
            return true // Can't compare functions
        default:
            return false
        }
    }
}

// MARK: - Field Validation Configuration
struct FieldValidation: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let fieldName: String
    let rules: [ValidationRule]
    let isRequired: Bool
    
    init(fieldName: String, rules: [ValidationRule], isRequired: Bool = false) {
        self.id = UUID().uuidString
        self.fieldName = fieldName
        self.rules = isRequired ? [.required()] + rules : rules
        self.isRequired = isRequired
    }
    
    /// Create validation for student data fields
    static func studentField(
        _ fieldName: String,
        rules: [ValidationRule],
        isRequired: Bool = true
    ) -> FieldValidation {
        return FieldValidation(fieldName: fieldName, rules: rules, isRequired: isRequired)
    }
    
    /// Create validation for teacher data fields
    static func teacherField(
        _ fieldName: String,
        rules: [ValidationRule],
        isRequired: Bool = true
    ) -> FieldValidation {
        return FieldValidation(fieldName: fieldName, rules: rules, isRequired: isRequired)
    }
}

// MARK: - TMI-Specific Validation Rules
extension ValidationRule {
    // Student-specific validations
    static func studentId(message: String = "Invalid student ID format") -> ValidationRule {
        return .textLength(min: 3, max: 20, fieldName: "Student ID", message: message)
    }
    
    static func gradeLevel(message: String = "Grade level must be K-12 or college") -> ValidationRule {
        return .custom(message: message) { value in
            guard let grade = value as? String else { return false }
            let validGrades = ["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "College"]
            return validGrades.contains(grade)
        }
    }
    
    static func studentAge(message: String = "Student age must be between 5 and 25") -> ValidationRule {
        return .numericRange(min: 5, max: 25, fieldName: "Age", message: message)
    }
    
    // Career plan validations
    static func careerGoal(message: String = "Career goal must be 10-500 characters") -> ValidationRule {
        return .textLength(min: 10, max: 500, fieldName: "Career Goal", message: message)
    }
    
    static func interestCategories(message: String = "Must select 1-5 interest categories") -> ValidationRule {
        return .collectionSize(min: 1, max: 5, fieldName: "Interest Categories", message: message)
    }
    
    // School-specific validations
    static func schoolCode(message: String = "Invalid school code format") -> ValidationRule {
        return .textLength(min: 4, max: 10, fieldName: "School Code", message: message)
    }
    
    static func academicYear(message: String = "Invalid academic year") -> ValidationRule {
        let currentYear = Calendar.current.component(.year, from: Date())
        let startDate = Calendar.current.date(from: DateComponents(year: currentYear - 1))!
        let endDate = Calendar.current.date(from: DateComponents(year: currentYear + 2))!
        return .date(after: startDate, before: endDate, fieldName: "Academic Year", message: message)
    }
}

// MARK: - Usage Examples for TMI App
extension FieldValidation {
    /// Common student form validations
    static let studentFormValidations: [FieldValidation] = [
        .studentField("firstName", rules: [.name(), .textLength(min: 2, max: 50, fieldName: "First Name")]),
        .studentField("lastName", rules: [.name(), .textLength(min: 2, max: 50, fieldName: "Last Name")]),
        .studentField("email", rules: [.email()]),
        .studentField("studentId", rules: [.studentId()]),
        .studentField("gradeLevel", rules: [.gradeLevel()]),
        .studentField("age", rules: [.studentAge()]),
        .studentField("schoolName", rules: [.schoolName(), .textLength(min: 3, max: 100, fieldName: "School Name")])
    ]
    
    /// Common teacher form validations
    static let teacherFormValidations: [FieldValidation] = [
        .teacherField("firstName", rules: [.name(), .textLength(min: 2, max: 50, fieldName: "First Name")]),
        .teacherField("lastName", rules: [.name(), .textLength(min: 2, max: 50, fieldName: "Last Name")]),
        .teacherField("email", rules: [.email()]),
        .teacherField("schoolCode", rules: [.schoolCode()]),
        .teacherField("department", rules: [.textLength(min: 2, max: 100, fieldName: "Department")])
    ]
    
    /// Career plan form validations
    static let careerPlanValidations: [FieldValidation] = [
        .studentField("careerGoal", rules: [.careerGoal()]),
        .studentField("interests", rules: [.interestCategories()]),
        .studentField("targetGraduationDate", rules: [.academicYear()])
    ]
}

// MARK: - Validation Rules
struct ValidationRules: Sendable {
    private static let logger = TMILogger(category: "Validation")
    
    // MARK: - Email Validation
    static func email(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .error("Email is required")
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: trimmed) {
            logger.debug("Email validation failed", metadata: ["email": trimmed])
            return .error("Please enter a valid email address")
        }
        
        return .valid
    }
    
    // MARK: - Password Validation
    static func password(_ value: String) -> ValidationResult {
        if value.isEmpty {
            return .error("Password is required")
        }
        
        if value.count < 8 {
            return .error("Password must be at least 8 characters")
        }
        
        if value.count > 128 {
            return .error("Password must be less than 128 characters")
        }
        
        if !value.contains(where: { $0.isUppercase }) {
            return .error("Password must contain at least one uppercase letter")
        }
        
        if !value.contains(where: { $0.isLowercase }) {
            return .error("Password must contain at least one lowercase letter")
        }
        
        if !value.contains(where: { $0.isNumber }) {
            return .error("Password must contain at least one number")
        }
        
        // Check for common weak passwords
        let commonPasswords = ["password", "123456", "password123", "admin", "qwerty"]
        if commonPasswords.contains(where: { value.lowercased().contains($0) }) {
            return .error("Password is too common. Please choose a more secure password")
        }
        
        return .valid
    }
    
    // MARK: - Name Validation
    static func name(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .error("Name is required")
        }
        
        if trimmed.count < 2 {
            return .error("Name must be at least 2 characters")
        }
        
        if trimmed.count > 50 {
            return .error("Name must be less than 50 characters")
        }
        
        // Check for invalid characters (allow letters, spaces, hyphens, apostrophes, periods)
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'."))
        
        if trimmed.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return .error("Name contains invalid characters")
        }
        
        // Check for suspicious patterns
        if trimmed.contains(where: { $0.isNumber }) {
            return .error("Name cannot contain numbers")
        }
        
        // Check for repeated characters (more than 3 in a row)
        let pattern = "(.)\\1{3,}"
        if trimmed.range(of: pattern, options: .regularExpression) != nil {
            return .error("Name contains too many repeated characters")
        }
        
        return .valid
    }
    
    // MARK: - Age Validation
    static func studentAge(_ value: Int) -> ValidationResult {
        if value < 3 {
            return .error("Student must be at least 3 years old")
        }
        
        if value > 25 {
            return .error("Student age must be 25 or younger")
        }
        
        return .valid
    }
    
    // MARK: - Grade Validation
    static func grade(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .error("Grade is required")
        }
        
        // Support various grade formats: K, 1, 2, ..., 12, Pre-K, etc.
        let validGrades = ["Pre-K", "K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
        
        if !validGrades.contains(trimmed) {
            return .error("Grade must be Pre-K, K, or 1-12")
        }
        
        return .valid
    }
    
    // MARK: - School Name Validation
    static func schoolName(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .error("School name is required")
        }
        
        if trimmed.count < 3 {
            return .error("School name must be at least 3 characters")
        }
        
        if trimmed.count > 100 {
            return .error("School name must be less than 100 characters")
        }
        
        // Allow letters, numbers, spaces, periods, hyphens, apostrophes
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'.&"))
        
        if trimmed.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return .error("School name contains invalid characters")
        }
        
        return .valid
    }
    
    // MARK: - Phone Number Validation
    static func phoneNumber(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .idle // Phone is optional
        }
        
        // Remove all non-numeric characters
        let numbersOnly = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // US phone numbers should have 10 digits
        if numbersOnly.count != 10 {
            return .error("Phone number must be 10 digits")
        }
        
        // Check for invalid patterns
        let invalidPatterns = ["0000000000", "1111111111", "1234567890"]
        if invalidPatterns.contains(numbersOnly) {
            return .error("Please enter a valid phone number")
        }
        
        return .valid
    }
    
    // MARK: - URL Validation
    static func url(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .idle // URL is optional
        }
        
        guard let url = URL(string: trimmed) else {
            return .error("Please enter a valid URL")
        }
        
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return .error("URL must start with http:// or https://")
        }
        
        guard let host = url.host, !host.isEmpty else {
            return .error("Please enter a valid URL")
        }
        
        return .valid
    }
    
    // MARK: - Text Length Validation
    static func textLength(
        _ value: String,
        min: Int = 0,
        max: Int = 1000,
        fieldName: String = "Text"
    ) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty && min > 0 {
            return .error("\(fieldName) is required")
        }
        
        if trimmed.count < min {
            return .error("\(fieldName) must be at least \(min) characters")
        }
        
        if trimmed.count > max {
            return .error("\(fieldName) must be less than \(max) characters")
        }
        
        return .valid
    }
    
    // MARK: - Date Validation
    static func date(_ value: Date,
                     after minDate: Date? = nil,
                     before maxDate: Date? = nil,
                     fieldName: String = "Date") -> ValidationResult {
        
        if let minDate = minDate, value < minDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return .error("\(fieldName) must be after \(formatter.string(from: minDate))")
        }
        
        if let maxDate = maxDate, value > maxDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return .error("\(fieldName) must be before \(formatter.string(from: maxDate))")
        }
        
        return .valid
    }
    
    static func numericRange<T: Numeric & Comparable>(_ value: T, min: T, max: T, fieldName: String) -> ValidationResult {
        if value < min {
            return .error("\(fieldName) must be at least \(min)")
        }
        if value > max {
            return .error("\(fieldName) must be no more than \(max)")
        }
        return .valid
    }
    
    static func collectionSize<T: Collection>(_ value: T, min: Int, max: Int, fieldName: String) -> ValidationResult {
        if value.count < min {
            return .error("\(fieldName) must have at least \(min) items")
        }
        if value.count > max {
            return .error("\(fieldName) must have no more than \(max) items")
        }
        return .valid
    }
    
    // MARK: - Custom Validation
    static func custom<T>(_ value: T, validator: (T) -> ValidationResult) -> ValidationResult {
        return validator(value)
    }
}

// MARK: - Validation Error
enum ValidationError: Error, LocalizedError, Sendable {
    case missingRequiredField(String)
    case invalidDataType(String)
    case validationFailed(field: String, message: String)
    
    // MARK: - Computed Properties
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let fieldId):
            return "Missing required field: \(fieldId)"
        case .invalidDataType(let fieldId):
            return "Invalid data type for field: \(fieldId)"
        case .validationFailed(let fieldId, let message):
            return "Validation failed for field \(fieldId): \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .missingRequiredField(let fieldId):
            return "Validation failed for field: \(fieldId) - field is required but not provided"
        case .invalidDataType(let fieldId):
            return "Validation failed for field: \(fieldId) - data type mismatch"
        case .validationFailed(let fieldId, _):
            return "Validation failed for field: \(fieldId)"
        }
    }
    
    var field: String {
        switch self {
        case .missingRequiredField(let fieldId):
            return fieldId
        case .invalidDataType(let fieldId):
            return fieldId
        case .validationFailed(let fieldId, _):
            return fieldId
        }
    }
    
    var message: String {
        return errorDescription ?? "Unknown validation error"
    }
    
    // MARK: - Methods
    /// Convert to TMIError for broader error handling
    func toTMIError() -> TMIError {
        let errorCode: TMIError.ErrorCode
        let category: String
        
        switch self {
        case .missingRequiredField:
            errorCode = .dataValidationFailed
            category = "missing_field"
        case .invalidDataType:
            errorCode = .dataValidationFailed
            category = "invalid_type"
        case .validationFailed:
            errorCode = .dataValidationFailed
            category = "validation"
        }
        
        return TMIError(
            code: errorCode,
            message: message,
            underlyingError: self,
            context: [
                "field": field,
                "category": category,
                "error_type": String(describing: self)
            ]
        )
    }
    
    // MARK: - Convenience Initializers
    /// Create a generic validation failed error (similar to the original struct initializer)
    static func failed(field: String, message: String) -> ValidationError {
        return .validationFailed(field: field, message: message)
    }
    
    /// Create a missing field error
    static func missing(_ field: String) -> ValidationError {
        return .missingRequiredField(field)
    }
    
    /// Create an invalid data type error
    static func invalidType(_ field: String) -> ValidationError {
        return .invalidDataType(field)
    }
}

// MARK: - Usage Examples for TMI App
extension ValidationError {
    // TMI-specific validation errors
    static func invalidAge(_ age: String) -> ValidationError {
        return .validationFailed(field: "age", message: "Age must be between 5 and 25 for educational programs")
    }
    
    static func invalidGradeLevel(_ grade: String) -> ValidationError {
        return .validationFailed(field: "grade_level", message: "Grade level must be K-12 or college level")
    }
    
    static func invalidInterestCategory(_ category: String) -> ValidationError {
        return .validationFailed(field: "interest_category", message: "Interest category '\(category)' is not supported in TMI program")
    }
    
    static func missingStudentId() -> ValidationError {
        return .missingRequiredField("student_id")
    }
    
    static func missingCareerGoal() -> ValidationError {
        return .missingRequiredField("career_goal")
    }
}

// MARK: - Batch Validator
struct BatchValidator: Sendable {
    private let logger = TMILogger(category: "BatchValidation")
    
    private var validations: [(String, @Sendable () -> ValidationResult)] = []
    
    mutating func add(field: String, validation: @escaping @Sendable () -> ValidationResult) {
        validations.append((field, validation))
    }
    
    func validate() throws {
        logger.debug("Starting batch validation with \(validations.count) rules")
        
        var errors: [ValidationError] = []
        
        for (field, validation) in validations {
            let result = validation()
            if case .error(let message) = result {
                errors.append(.validationFailed(field: field, message: message))
            }
        }
        
        if !errors.isEmpty {
            logger.warning("Batch validation failed", metadata: [
                "errorCount": errors.count,
                "fields": errors.map { $0.field }
            ])
            
            // Throw the first error (you could also create a compound error)
            throw errors.first!
        }
        
        logger.debug("Batch validation completed successfully")
    }
}

// MARK: - Sanitization
struct Sanitizer: Sendable {
    /// Sanitize user input to prevent XSS and other attacks
    static func sanitizeText(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove potentially dangerous characters
        let dangerousChars = CharacterSet(charactersIn: "<>\"'&")
        let sanitized = trimmed.components(separatedBy: dangerousChars).joined(separator: "")
        
        // Limit length to prevent abuse
        return String(sanitized.prefix(1000))
    }
    
    /// Sanitize HTML content
    static func sanitizeHTML(_ input: String) -> String {
        // In a real implementation, use a proper HTML sanitization library
        let htmlTags = ["<script>", "</script>", "<iframe>", "</iframe>", "<object>", "</object>"]
        var sanitized = input
        
        for tag in htmlTags {
            sanitized = sanitized.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }
        
        return sanitized
    }
    
    /// Sanitize SQL to prevent injection
    static func sanitizeSQL(_ input: String) -> String {
        let sqlKeywords = ["DROP", "DELETE", "UPDATE", "INSERT", "SELECT", "UNION", "ALTER"]
        var sanitized = input
        
        for keyword in sqlKeywords {
            let pattern = "\\b\(keyword)\\b"
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.caseInsensitive, .regularExpression]
            )
        }
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Advanced Validation Features

/// Async validation with timeout and retry
actor AsyncValidationManager {
    private let logger = Log.validation
    private let timeout: TimeInterval = 10.0
    
    /// Perform async validation with timeout
    func validateWithTimeout<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) {
            group in
            // Add the validation task
            group.addTask {
                return try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeout))
                throw TMIError(
                    code: .networkTimeout,
                    message: "Validation timed out after \(self.timeout) seconds",
                    context: ["timeout": String(self.timeout)]
                )
            }
            
            // Return the first completed task and cancel others
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    /// Validate with retry logic
    func validateWithRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                logger.debug("Validation attempt \(attempt) of \(maxAttempts)")
                return try await operation()
            } catch {
                lastError = error
                logger.warning("Validation attempt \(attempt) failed", metadata: ["error": error.localizedDescription])
                
                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(delay * Double(attempt)))
                }
            }
        }
        
        throw lastError ?? TMIError(
            code: .unknownError,
            message: "Validation failed after \(maxAttempts) attempts"
        )
    }
}

/// Real-time form validation state
@Observable
final class FormValidator {
    private(set) var fieldStates: [String: ValidationResult] = [:]
    private(set) var isValid = false
    private(set) var firstError: String?
    
    private let logger = Log.validation
    
    /// Update field validation state
    func updateField(_ field: String, result: ValidationResult) {
        fieldStates[field] = result
        updateOverallState()
        
        logger.debug("Field validation updated", metadata: [
            "field": field,
            "isValid": result.isValid,
            "error": result.errorMessage ?? "none"
        ])
    }
    
    /// Validate all fields at once
    func validateAll<T: Validatable>(_ object: T) async {
        do {
            try await object.validate()
            isValid = true
            firstError = nil
            logger.info("Form validation successful")
        } catch let error as ValidationError {
            fieldStates[error.field] = .error(error.message)
            updateOverallState()
        } catch {
            firstError = error.localizedDescription
            isValid = false
            logger.error("Form validation failed", error: error)
        }
    }
    
    /// Clear all validation states
    func reset() {
        fieldStates.removeAll()
        isValid = false
        firstError = nil
    }
    
    /// Get validation state for a specific field
    func getFieldState(_ field: String) -> ValidationResult {
        return fieldStates[field] ?? .idle
    }
    
    /// Get all fields with errors
    var fieldsWithErrors: [String] {
        return fieldStates.compactMap { (key, value) in
            value.hasError ? key : nil
        }
    }
    
    private func updateOverallState() {
        let hasErrors = fieldStates.values.contains { $0.hasError }
        let hasIdleFields = fieldStates.values.contains { $0 == .idle }
        
        isValid = !hasErrors && !hasIdleFields && !fieldStates.isEmpty
        firstError = fieldsWithErrors.first.flatMap { fieldStates[$0]?.errorMessage }
    }
}

// MARK: - Extensions for Common Types

extension String {
    /// Quick validation using ValidationRules
    func validate(as rule: ValidationRule) -> ValidationResult {
        switch rule {
        case .email():
            return ValidationRules.email(self)
        case .name():
            return ValidationRules.name(self)
        case .phone():
            return ValidationRules.phoneNumber(self)
        case .url():
            return ValidationRules.url(self)
        case .required():
            return self.isEmpty ? .error("Field is required") : .valid
        case .schoolName():
            return ValidationRules.schoolName(self)
        default:
            return .valid
        }
    }
}

extension Int {
    /// Quick age validation
    func validateAsStudentAge() -> ValidationResult {
        return ValidationRules.studentAge(self)
    }
    
    /// Quick range validation
    func validate(min: Int, max: Int, fieldName: String) -> ValidationResult {
        return ValidationRules.numericRange(self, min: min, max: max, fieldName: fieldName)
    }
}

extension Array {
    /// Quick collection size validation
    func validateSize(min: Int = 0, max: Int = Int.max, fieldName: String) -> ValidationResult {
        return ValidationRules.collectionSize(self, min: min, max: max, fieldName: fieldName)
    }
}

