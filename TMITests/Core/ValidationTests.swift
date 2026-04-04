//
//  ValidationTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class ValidationTests: XCTestCase {

    func testEmailValidation() {
        XCTAssertTrue(ValidationRules.email("teacher@example.com").isValid)
        XCTAssertFalse(ValidationRules.email("not-an-email").isValid)
    }

    func testNameValidation() {
        XCTAssertTrue(ValidationRules.name("Taylor Brooks").isValid)
        XCTAssertFalse(ValidationRules.name("A").isValid)
        XCTAssertFalse(ValidationRules.name("John123").isValid)
    }

    func testPhoneValidation() {
        XCTAssertTrue(ValidationRules.phoneNumber("555-123-4567").isValid)
        XCTAssertFalse(ValidationRules.phoneNumber("123").isValid)
    }

    func testURLValidation() {
        XCTAssertTrue(ValidationRules.url("https://example.com").isValid)
        XCTAssertFalse(ValidationRules.url("javascript:alert('xss')").isValid)
    }

    func testStudentAgeValidation() {
        XCTAssertTrue(ValidationRules.studentAge(12).isValid)
        XCTAssertFalse(ValidationRules.studentAge(2).isValid)
        XCTAssertFalse(ValidationRules.studentAge(26).isValid)
    }

    func testSchoolNameValidation() {
        XCTAssertTrue(ValidationRules.schoolName("Lincoln High School").isValid)
        XCTAssertFalse(ValidationRules.schoolName("A").isValid)
    }

    func testTextLengthValidation() {
        XCTAssertTrue(ValidationRules.textLength("Hello World", min: 5, max: 20, fieldName: "Message").isValid)
        XCTAssertFalse(ValidationRules.textLength("Hi", min: 5, max: 20, fieldName: "Message").isValid)
    }

    func testNumericRangeValidation() {
        XCTAssertTrue(ValidationRules.numericRange(15, min: 10, max: 20, fieldName: "Score").isValid)
        XCTAssertFalse(ValidationRules.numericRange(5, min: 10, max: 20, fieldName: "Score").isValid)
    }

    func testCollectionSizeValidation() {
        XCTAssertTrue(ValidationRules.collectionSize([1, 2, 3], min: 1, max: 5, fieldName: "Items").isValid)
        XCTAssertFalse(ValidationRules.collectionSize([], min: 1, max: 5, fieldName: "Items").isValid)
    }

    func testValidationRuleConvenienceFactories() {
        XCTAssertEqual(ValidationRule.email().ruleType, .email)
        XCTAssertEqual(ValidationRule.name().ruleType, .name)
        XCTAssertEqual(ValidationRule.phone().ruleType, .phone)
        XCTAssertEqual(ValidationRule.url().ruleType, .url)
        XCTAssertEqual(ValidationRule.required().ruleType, .required)
        XCTAssertEqual(ValidationRule.schoolName().ruleType, .schoolName)
        XCTAssertEqual(ValidationRule.textLength(min: 1, max: 10, fieldName: "Field").ruleType, .textLength)
        XCTAssertEqual(ValidationRule.numericRange(min: 1, max: 10, fieldName: "Field").ruleType, .numericRange)
        XCTAssertEqual(ValidationRule.collectionSize(min: 1, max: 10, fieldName: "Field").ruleType, .collectionSize)
        XCTAssertEqual(ValidationRule.date(fieldName: "Date").ruleType, .date)
    }

    func testStringValidationHelpers() {
        XCTAssertTrue("teacher@example.com".validate(as: .email()).isValid)
        XCTAssertFalse("not-an-email".validate(as: .email()).isValid)
        XCTAssertTrue(12.validateAsStudentAge().isValid)
        XCTAssertFalse(30.validateAsStudentAge().isValid)
        XCTAssertTrue([1, 2].validateSize(min: 1, max: 3, fieldName: "Values").isValid)
    }

    func testValidationErrorConversionToTMIError() {
        let error = ValidationError.failed(field: "email", message: "Invalid email")
        let tmiError = error.toTMIError()

        XCTAssertEqual(tmiError.code, .dataValidationFailed)
        XCTAssertEqual(tmiError.context["field"], "email")
    }
}
