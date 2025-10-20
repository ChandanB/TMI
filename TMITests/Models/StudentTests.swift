//
//  StudentTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class StudentTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var sampleStudent: Student!
    private var validDateOfBirth: Date!
    private var tooYoungDate: Date!
    private var tooOldDate: Date!
    
    override func setUp() {
        super.setUp()
        
        let calendar = Calendar.current
        let today = Date()
        
        // Create dates for testing
        validDateOfBirth = calendar.date(byAdding: .year, value: -10, to: today)!
        tooYoungDate = calendar.date(byAdding: .year, value: -2, to: today)!
        tooOldDate = calendar.date(byAdding: .year, value: -30, to: today)!
        
        // Create sample student
        sampleStudent = Student(
            name: "John Doe",
            grade: "5",
            school: "Lincoln Elementary",
            dateOfBirth: validDateOfBirth,
            studentID: "STU123"
        )
    }
    
    override func tearDown() {
        sampleStudent = nil
        validDateOfBirth = nil
        tooYoungDate = nil
        tooOldDate = nil
        super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    func testValidStudentPassesValidation() async throws {
        // Act & Assert
        try await sampleStudent.validate()
    }
    
    func testEmptyNameFailsValidation() async {
        // Arrange
        let student = Student(
            name: "",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "name")
            XCTAssertTrue(validationError.message.contains("required"))
        }
    }
    
    func testShortNameFailsValidation() async {
        // Arrange
        let student = Student(
            name: "A",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "name")
            XCTAssertTrue(validationError.message.contains("2 characters"))
        }
    }
    
    func testLongNameFailsValidation() async {
        // Arrange
        let longName = String(repeating: "A", count: 60)
        let student = Student(
            name: longName,
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "name")
            XCTAssertTrue(validationError.message.contains("50 characters"))
        }
    }
    
    func testInvalidGradeFailsValidation() async {
        // Arrange
        let student = Student(
            name: "John Doe",
            grade: "13",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "grade")
        }
    }
    
    func testTooYoungStudentFailsValidation() async {
        // Arrange
        let student = Student(
            name: "Baby Student",
            grade: "K",
            school: "Test School",
            dateOfBirth: tooYoungDate
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "dateOfBirth")
        }
    }
    
    func testTooOldStudentFailsValidation() async {
        // Arrange
        let student = Student(
            name: "Old Student",
            grade: "12",
            school: "Test School",
            dateOfBirth: tooOldDate
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testEmptySchoolNameFailsValidation() async {
        // Arrange
        let student = Student(
            name: "John Doe",
            grade: "5",
            school: "",
            dateOfBirth: validDateOfBirth
        )
        
        // Act & Assert
        await XCTAssertThrowsAsyncError(try await student.validate()) { error in
            XCTAssertTrue(error is StudentValidationError)
            let validationError = error as! StudentValidationError
            XCTAssertEqual(validationError.field, "school")
        }
    }
    
    // MARK: - Computed Properties Tests
    
    func testAgeCalculation() {
        // Arrange
        let calendar = Calendar.current
        let fiveYearsAgo = calendar.date(byAdding: .year, value: -5, to: Date())!
        let student = Student(
            name: "Test Student",
            grade: "K",
            school: "Test School",
            dateOfBirth: fiveYearsAgo
        )
        
        // Act & Assert
        XCTAssertEqual(student.age, 5)
    }
    
    func testInitialsGeneration() {
        // Test single name
        let singleName = Student(
            name: "John",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth
        )
        XCTAssertEqual(singleName.initials, "J")
        
        // Test full name
        let fullName = Student(
            name: "John William Doe",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth
        )
        XCTAssertEqual(fullName.initials, "JWD")
        
        // Test empty name
        let emptyName = Student(
            name: "",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth
        )
        XCTAssertEqual(emptyName.initials, "")
    }
    
    func testDisplayName() {
        // Test full name
        let fullName = Student(
            name: "John William Doe",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth
        )
        XCTAssertEqual(fullName.displayName, "John Doe")
        
        // Test single name
        let singleName = Student(
            name: "John",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth
        )
        XCTAssertEqual(singleName.displayName, "John")
    }
    
    func testEngagementScoreDefault() {
        // Test default engagement score for student without history
        XCTAssertEqual(sampleStudent.engagementScore, 0.5, accuracy: 0.01)
    }
    
    func testEngagementScoreWithHistory() {
        // Arrange
        let engagementRecords = [
            EngagementRecord(score: 0.8, date: Date(), notes: "Good participation"),
            EngagementRecord(score: 0.7, date: Date(), notes: "Moderate engagement"),
            EngagementRecord(score: 0.9, date: Date(), notes: "Excellent performance")
        ]
        
        let student = Student(
            name: "Test Student",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth,
            engagementHistory: engagementRecords
        )
        
        // Act & Assert
        let expectedAverage = (0.8 + 0.7 + 0.9) / 3.0
        XCTAssertEqual(student.engagementScore, expectedAverage, accuracy: 0.01)
    }
    
    func testHasTMIPlan() {
        // Test student without plans
        XCTAssertFalse(sampleStudent.hasTMIPlan)
        
        // Test student with empty plans
        let studentWithEmptyPlans = Student(
            name: "Test",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth,
            tmiPlans: []
        )
        XCTAssertFalse(studentWithEmptyPlans.hasTMIPlan)
        
        // Test student with plans
        let mockPlan = TMIPlan(
            id: "test-plan",
            title: "Test Plan",
            model: TMIPlanModel.chaseYourSpace.rawValue,
            students: ["student1"],
            startDate: Date(),
            createdBy: "teacher1"
        )
        
        let studentWithPlans = Student(
            name: "Test",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth,
            tmiPlans: [mockPlan]
        )
        XCTAssertTrue(studentWithPlans.hasTMIPlan)
    }
    
    // MARK: - Field Validation Tests
    
    func testValidateFieldName() {
        // Valid name
        let validResult = Student.validateField(.name, value: "John Doe")
        XCTAssertTrue(validResult.isValid)
        
        // Invalid name
        let invalidResult = Student.validateField(.name, value: "")
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertNotNil(invalidResult.errorMessage)
    }
    
    func testValidateFieldGrade() {
        // Valid grades
        let validGrades = ["K", "1", "5", "12", "Pre-K"]
        for grade in validGrades {
            let result = Student.validateField(.grade, value: grade)
            XCTAssertTrue(result.isValid, "Grade \(grade) should be valid")
        }
        
        // Invalid grades
        let invalidGrades = ["", "13", "invalid", "0"]
        for grade in invalidGrades {
            let result = Student.validateField(.grade, value: grade)
            XCTAssertFalse(result.isValid, "Grade \(grade) should be invalid")
        }
    }
    
    func testValidateFieldSchool() {
        // Valid school
        let validResult = Student.validateField(.school, value: "Lincoln Elementary School")
        XCTAssertTrue(validResult.isValid)
        
        // Invalid school
        let invalidResult = Student.validateField(.school, value: "AB") // Too short
        XCTAssertFalse(invalidResult.isValid)
    }
    
    func testValidateFieldDateOfBirth() {
        // Valid date
        let validResult = Student.validateField(.dateOfBirth, value: validDateOfBirth!)
        XCTAssertTrue(validResult.isValid)
        
        // Invalid date (too young)
        let invalidResult = Student.validateField(.dateOfBirth, value: tooYoungDate!)
        XCTAssertFalse(invalidResult.isValid)
    }
    
    func testValidateFieldStudentID() {
        // Valid student ID
        let validResult = Student.validateField(.studentID, value: "STU123")
        XCTAssertTrue(validResult.isValid)
        
        // Empty student ID (should be valid as it's optional)
        let emptyResult = Student.validateField(.studentID, value: "")
        XCTAssertTrue(emptyResult.isValid)
        
        // Too long student ID
        let longID = String(repeating: "A", count: 60)
        let invalidResult = Student.validateField(.studentID, value: longID)
        XCTAssertFalse(invalidResult.isValid)
    }
    
    // MARK: - Business Logic Tests
    
    func testEngagementTrend() {
        // Test stable trend (no history)
        XCTAssertEqual(sampleStudent.engagementTrend, .stable)
        
        // Test improving trend
        let improvingRecords = [
            EngagementRecord(score: 0.9, date: Date(), notes: "Recent"),
            EngagementRecord(score: 0.7, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, notes: "Previous")
        ]
        
        let improvingStudent = Student(
            name: "Test",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth,
            engagementHistory: improvingRecords
        )
        
        XCTAssertEqual(improvingStudent.engagementTrend, .improving)
        
        // Test declining trend
        let decliningRecords = [
            EngagementRecord(score: 0.3, date: Date(), notes: "Recent"),
            EngagementRecord(score: 0.8, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, notes: "Previous")
        ]
        
        let decliningStudent = Student(
            name: "Test",
            grade: "5",
            school: "Test",
            dateOfBirth: validDateOfBirth,
            engagementHistory: decliningRecords
        )
        
        XCTAssertEqual(decliningStudent.engagementTrend, .declining)
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        measure {
            let students = (1...100).map { i in
                Student(
                    name: "Student \(i)",
                    grade: "\(i % 12 + 1)",
                    school: "Test School \(i)",
                    dateOfBirth: Calendar.current.date(byAdding: .year, value: -(i % 20 + 5), to: Date())!
                )
            }
            
            let expectation = XCTestExpectation(description: "Validate all students")
            
            Task {
                for student in students {
                    do {
                        try await student.validate()
                    } catch {
                        // Some might fail due to age constraints, that's expected
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Test Helpers

extension StudentTests {
    /// Helper to assert async throws with specific error handling
    func XCTAssertThrowsAsyncError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        errorHandler: ((Error) -> Void)? = nil
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected expression to throw an error", file: file, line: line)
        } catch {
            errorHandler?(error)
        }
    }
    
    /// Helper to assert async doesn't throw
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("\(message()): Threw error \(error)", file: file, line: line)
        }
    }
}

// MARK: - Mock Data

extension Student {
    static func mockStudent(
        name: String = "Mock Student",
        grade: String = "5",
        school: String = "Mock School",
        age: Int = 10
    ) -> Student {
        let dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: Date())!
        
        return Student(
            name: name,
            grade: grade,
            school: school,
            dateOfBirth: dateOfBirth,
            studentID: "MOCK\(Int.random(in: 100...999))"
        )
    }
}