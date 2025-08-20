//
//  ValidationTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class ValidationTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testValidEmailAddresses() {
        let validEmails = [
            "test@example.com",
            "user.name+tag@domain.com",
            "teacher123@school.edu",
            "admin@subdomain.domain.org",
            "simple@test.co"
        ]
        
        for email in validEmails {
            let result = ValidationRules.email(email)
            XCTAssertTrue(result.isValid, "Email '\(email)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidEmailAddresses() {
        let invalidEmails = [
            "",
            "notanemail",
            "@domain.com",
            "user@",
            "user@@domain.com",
            "user@domain",
            "user name@domain.com",
            "user@domain..com"
        ]
        
        for email in invalidEmails {
            let result = ValidationRules.email(email)
            XCTAssertFalse(result.isValid, "Email '\(email)' should be invalid")
            XCTAssertNotNil(result.errorMessage, "Invalid email should have error message")
        }
    }
    
    // MARK: - Name Validation Tests
    
    func testValidNames() {
        let validNames = [
            "John Doe",
            "Mary Jane Smith",
            "José María",
            "Anna-Lisa",
            "O'Connor",
            "Van Der Berg",
            "李小明" // Chinese characters
        ]
        
        for name in validNames {
            let result = ValidationRules.name(name)
            XCTAssertTrue(result.isValid, "Name '\(name)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidNames() {
        let invalidNames = [
            "",
            "  ",
            "A", // Too short
            "John123", // Contains numbers
            "John@Doe", // Contains special characters
            "John Doe!!!" // Contains special characters
        ]
        
        for name in invalidNames {
            let result = ValidationRules.name(name)
            XCTAssertFalse(result.isValid, "Name '\(name)' should be invalid")
            XCTAssertNotNil(result.errorMessage, "Invalid name should have error message")
        }
    }
    
    // MARK: - Phone Number Validation Tests
    
    func testValidPhoneNumbers() {
        let validPhones = [
            "(555) 123-4567",
            "555-123-4567",
            "5551234567",
            "+1 555 123 4567",
            "1-555-123-4567",
            "+1-555-123-4567"
        ]
        
        for phone in validPhones {
            let result = ValidationRules.phoneNumber(phone)
            XCTAssertTrue(result.isValid, "Phone '\(phone)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidPhoneNumbers() {
        let invalidPhones = [
            "",
            "123",
            "abc-def-ghij",
            "555-123-456", // Too short
            "555-123-45678", // Too long
            "555 123 4567 ext 123" // Extensions not supported
        ]
        
        for phone in invalidPhones {
            let result = ValidationRules.phoneNumber(phone)
            XCTAssertFalse(result.isValid, "Phone '\(phone)' should be invalid")
            XCTAssertNotNil(result.errorMessage, "Invalid phone should have error message")
        }
    }
    
    // MARK: - URL Validation Tests
    
    func testValidUrls() {
        let validUrls = [
            "https://www.example.com",
            "http://example.com",
            "https://subdomain.example.org/path",
            "https://example.com:8080/path?query=value",
            "ftp://files.example.com"
        ]
        
        for url in validUrls {
            let result = ValidationRules.url(url)
            XCTAssertTrue(result.isValid, "URL '\(url)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidUrls() {
        let invalidUrls = [
            "",
            "notaurl",
            "www.example.com", // Missing protocol
            "https://", // Missing domain
            "https://.com", // Invalid domain
            "https://example", // Missing TLD
            "javascript:alert('xss')" // Potentially dangerous
        ]
        
        for url in invalidUrls {
            let result = ValidationRules.url(url)
            XCTAssertFalse(result.isValid, "URL '\(url)' should be invalid")
            XCTAssertNotNil(result.errorMessage, "Invalid URL should have error message")
        }
    }
    
    // MARK: - Required Field Validation Tests
    
    func testRequiredFieldValidation() {
        // Valid required field
        let validResult = ValidationRules.required("Some content", fieldName: "Name")
        XCTAssertTrue(validResult.isValid, "Non-empty content should be valid for required field")
        
        // Invalid required fields
        let invalidInputs = ["", "   ", "\t\n "]
        for input in invalidInputs {
            let result = ValidationRules.required(input, fieldName: "Name")
            XCTAssertFalse(result.isValid, "Input '\(input)' should be invalid for required field")
            XCTAssertTrue(result.errorMessage?.contains("Name is required") == true, "Error message should mention field name")
        }
    }
    
    // MARK: - Student Age Validation Tests
    
    func testValidStudentAges() {
        let validAges = ["5", "12", "18", "22"]
        
        for age in validAges {
            let result = ValidationRules.studentAge(age)
            XCTAssertTrue(result.isValid, "Age '\(age)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidStudentAges() {
        let invalidAges = [
            "",
            "abc",
            "3", // Too young
            "26", // Too old
            "-5", // Negative
            "12.5", // Decimal
            "100" // Way too old
        ]
        
        for age in invalidAges {
            let result = ValidationRules.studentAge(age)
            XCTAssertFalse(result.isValid, "Age '\(age)' should be invalid")
            XCTAssertNotNil(result.errorMessage, "Invalid age should have error message")
        }
    }
    
    // MARK: - School Name Validation Tests
    
    func testValidSchoolNames() {
        let validSchools = [
            "Lincoln Elementary School",
            "Roosevelt High School",
            "St. Mary's Academy",
            "Tech Valley Middle School",
            "International School of Sciences"
        ]
        
        for school in validSchools {
            let result = ValidationRules.schoolName(school)
            XCTAssertTrue(result.isValid, "School name '\(school)' should be valid: \(result.errorMessage ?? "")")
        }
    }
    
    func testInvalidSchoolNames() {
        let invalidSchools = [
            "",
            "A", // Too short
            "School!!!", // Special characters
            "123 School", // Starts with number
            "   ", // Only whitespace
            String(repeating: "A", count: 101) // Too long (over 100 chars)
        ]
        
        for school in invalidSchools {
            let result = ValidationRules.schoolName(school)
            XCTAssertFalse(result.isValid, "School name '\(school)' should be invalid")
        }
    }
    
    // MARK: - Text Length Validation Tests
    
    func testTextLengthValidation() {
        // Valid length
        let validResult = ValidationRules.textLength("Hello World", min: 5, max: 20, fieldName: "Message")
        XCTAssertTrue(validResult.isValid, "Text within length limits should be valid")
        
        // Too short
        let tooShortResult = ValidationRules.textLength("Hi", min: 5, max: 20, fieldName: "Message")
        XCTAssertFalse(tooShortResult.isValid, "Text too short should be invalid")
        XCTAssertTrue(tooShortResult.errorMessage?.contains("at least 5 characters") == true)
        
        // Too long
        let tooLongText = String(repeating: "A", count: 25)
        let tooLongResult = ValidationRules.textLength(tooLongText, min: 5, max: 20, fieldName: "Message")
        XCTAssertFalse(tooLongResult.isValid, "Text too long should be invalid")
        XCTAssertTrue(tooLongResult.errorMessage?.contains("no more than 20 characters") == true)
    }
    
    // MARK: - Numeric Range Validation Tests
    
    func testNumericRangeValidation() {
        // Valid number
        let validResult = ValidationRules.numericRange("15", min: 10, max: 20, fieldName: "Score")
        XCTAssertTrue(validResult.isValid, "Number within range should be valid")
        
        // Too low
        let tooLowResult = ValidationRules.numericRange("5", min: 10, max: 20, fieldName: "Score")
        XCTAssertFalse(tooLowResult.isValid, "Number below minimum should be invalid")
        XCTAssertTrue(tooLowResult.errorMessage?.contains("at least 10") == true)
        
        // Too high
        let tooHighResult = ValidationRules.numericRange("25", min: 10, max: 20, fieldName: "Score")
        XCTAssertFalse(tooHighResult.isValid, "Number above maximum should be invalid")
        XCTAssertTrue(tooHighResult.errorMessage?.contains("no more than 20") == true)
        
        // Not a number
        let notNumberResult = ValidationRules.numericRange("abc", min: 10, max: 20, fieldName: "Score")
        XCTAssertFalse(notNumberResult.isValid, "Non-numeric input should be invalid")
    }
    
    // MARK: - Collection Size Validation Tests
    
    func testCollectionSizeValidation() {
        // Valid size
        let validCollection = ["item1", "item2", "item3"]
        let validResult = ValidationRules.collectionSize(validCollection, min: 1, max: 5, fieldName: "Items")
        XCTAssertTrue(validResult.isValid, "Collection within size limits should be valid")
        
        // Too small
        let emptyCollection: [String] = []
        let emptyResult = ValidationRules.collectionSize(emptyCollection, min: 1, max: 5, fieldName: "Items")
        XCTAssertFalse(emptyResult.isValid, "Empty collection should be invalid when minimum is required")
        
        // Too large
        let largeCollection = Array(repeating: "item", count: 10)
        let largeResult = ValidationRules.collectionSize(largeCollection, min: 1, max: 5, fieldName: "Items")
        XCTAssertFalse(largeResult.isValid, "Collection exceeding maximum should be invalid")
    }
    
    // MARK: - String Extension Tests
    
    func testStringValidationExtensions() {
        // Email validation
        XCTAssertTrue("test@example.com".validate(as: .email).isValid)
        XCTAssertFalse("invalid-email".validate(as: .email).isValid)
        
        // Name validation
        XCTAssertTrue("John Doe".validate(as: .name).isValid)
        XCTAssertFalse("John123".validate(as: .name).isValid)
        
        // Phone validation
        XCTAssertTrue("(555) 123-4567".validate(as: .phone).isValid)
        XCTAssertFalse("invalid-phone".validate(as: .phone).isValid)
        
        // URL validation
        XCTAssertTrue("https://example.com".validate(as: .url).isValid)
        XCTAssertFalse("not-a-url".validate(as: .url).isValid)
        
        // Student age validation
        XCTAssertTrue("16".validateAsStudentAge().isValid)
        XCTAssertFalse("30".validateAsStudentAge().isValid)
        
        // Range validation
        XCTAssertTrue("15".validate(min: 10, max: 20, fieldName: "Score").isValid)
        XCTAssertFalse("25".validate(min: 10, max: 20, fieldName: "Score").isValid)
    }
    
    // MARK: - Array Extension Tests
    
    func testArrayValidationExtensions() {
        let validArray = ["item1", "item2", "item3"]
        let validResult = validArray.validateSize(min: 1, max: 5, fieldName: "Items")
        XCTAssertTrue(validResult.isValid)
        
        let emptyArray: [String] = []
        let emptyResult = emptyArray.validateSize(min: 1, max: 5, fieldName: "Items")
        XCTAssertFalse(emptyResult.isValid)
        
        let largeArray = Array(repeating: "item", count: 10)
        let largeResult = largeArray.validateSize(min: 1, max: 5, fieldName: "Items")
        XCTAssertFalse(largeResult.isValid)
    }
    
    // MARK: - Validation Result Tests
    
    func testValidationResultCreation() {
        // Valid result
        let validResult = ValidationResult(isValid: true, errorMessage: nil)
        XCTAssertTrue(validResult.isValid)
        XCTAssertNil(validResult.errorMessage)
        
        // Invalid result
        let invalidResult = ValidationResult(isValid: false, errorMessage: "Test error")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertEqual(invalidResult.errorMessage, "Test error")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyAndWhitespaceInputs() {
        let emptyInputs = ["", "   ", "\t", "\n", "  \t\n  "]
        
        for input in emptyInputs {
            XCTAssertFalse(ValidationRules.email(input).isValid, "Empty/whitespace should be invalid for email")
            XCTAssertFalse(ValidationRules.name(input).isValid, "Empty/whitespace should be invalid for name")
            XCTAssertFalse(ValidationRules.phoneNumber(input).isValid, "Empty/whitespace should be invalid for phone")
            XCTAssertFalse(ValidationRules.url(input).isValid, "Empty/whitespace should be invalid for URL")
            XCTAssertFalse(ValidationRules.required(input, fieldName: "Field").isValid, "Empty/whitespace should be invalid for required field")
        }
    }
    
    func testUnicodeCharacters() {
        // Names with unicode characters should be valid
        let unicodeNames = ["José", "François", "山田太郎", "محمد", "Αλέξανδρος"]
        
        for name in unicodeNames {
            let result = ValidationRules.name(name)
            XCTAssertTrue(result.isValid, "Unicode name '\(name)' should be valid")
        }
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        let testInputs = [
            "test@example.com",
            "John Doe",
            "(555) 123-4567",
            "https://example.com",
            "Some required text"
        ]
        
        measure {
            for _ in 0..<1000 {
                for input in testInputs {
                    _ = ValidationRules.email(input)
                    _ = ValidationRules.name(input)
                    _ = ValidationRules.phoneNumber(input)
                    _ = ValidationRules.url(input)
                    _ = ValidationRules.required(input, fieldName: "Field")
                }
            }
        }
    }
}