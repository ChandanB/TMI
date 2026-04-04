//
//  StudentTests.swift
//  TMITests
//
//  Created by Claude Code on 8/20/25.
//

import XCTest
@testable import TMI

final class StudentTests: XCTestCase {
    private var validDateOfBirth: Date!

    override func setUp() {
        super.setUp()
        validDateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: .now)
    }

    override func tearDown() {
        validDateOfBirth = nil
        super.tearDown()
    }

    func testValidStudentPassesValidation() throws {
        let student = Student(
            id: "student-1",
            name: "John Doe",
            grade: "5",
            school: "Lincoln Elementary",
            dateOfBirth: validDateOfBirth,
            studentID: "STU123"
        )

        XCTAssertNoThrow(try student.validate())
    }

    func testEmptyNameFailsValidation() {
        let student = Student(
            name: "",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )

        XCTAssertThrowsError(try student.validate()) { error in
            guard case StudentValidationError.invalidName = error else {
                return XCTFail("Expected invalidName, got \(error)")
            }
        }
    }

    func testFutureDateOfBirthFailsValidation() {
        let student = Student(
            name: "John Doe",
            grade: "5",
            school: "Test School",
            dateOfBirth: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        )

        XCTAssertThrowsError(try student.validate())
    }

    func testAgeIsDerivedFromDateOfBirth() {
        let student = Student(
            name: "John Doe",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )

        XCTAssertGreaterThan(student.age, 0)
        XCTAssertEqual(student.firstName, "John")
        XCTAssertEqual(student.initials, "JD")
    }

    func testEngagementScoreUsesRecentHistory() {
        let student = Student(
            name: "Jane Doe",
            grade: "6",
            school: "Test School",
            dateOfBirth: validDateOfBirth,
            engagementHistory: [
                EngagementRecord(date: .now.addingTimeInterval(-300), score: 0.2, source: .teacherInput, notes: nil),
                EngagementRecord(date: .now.addingTimeInterval(-200), score: 0.4, source: .teacherInput, notes: nil),
                EngagementRecord(date: .now.addingTimeInterval(-100), score: 0.6, source: .teacherInput, notes: nil)
            ]
        )

        XCTAssertEqual(student.engagementScore, 0.4, accuracy: 0.001)
    }

    func testEngagementTrendReflectsImprovementAndDecline() {
        let improvingStudent = Student(
            name: "Improving Student",
            grade: "6",
            school: "Test School",
            dateOfBirth: validDateOfBirth,
            engagementHistory: [
                EngagementRecord(date: .now, score: 0.7, source: .teacherInput, notes: nil),
                EngagementRecord(date: .now.addingTimeInterval(-100), score: 0.4, source: .teacherInput, notes: nil)
            ]
        )

        let decliningStudent = Student(
            name: "Declining Student",
            grade: "6",
            school: "Test School",
            dateOfBirth: validDateOfBirth,
            engagementHistory: [
                EngagementRecord(date: .now, score: 0.2, source: .teacherInput, notes: nil),
                EngagementRecord(date: .now.addingTimeInterval(-100), score: 0.6, source: .teacherInput, notes: nil)
            ]
        )

        XCTAssertEqual(improvingStudent.engagementTrend, .improving)
        XCTAssertEqual(decliningStudent.engagementTrend, .declining)
    }

    func testHasTMIPlanUsesPlanPresence() {
        let baseStudent = Student(
            id: "student-1",
            name: "Student One",
            grade: "5",
            school: "Test School",
            dateOfBirth: validDateOfBirth
        )

        let plan = TMIPlan(
            id: "plan-1",
            title: "Support Plan",
            students: [baseStudent],
            model: .alignYourMind,
            interests: [],
            startDate: .now,
            endDate: nil,
            creationDate: .now,
            lastUpdated: .now,
            goals: [Goal(description: "Complete check-in")],
            progress: 0.0,
            notes: "Test notes",
            createdBy: "teacher-1"
        )

        let studentWithPlan = Student(
            id: baseStudent.id,
            name: baseStudent.name,
            grade: baseStudent.grade,
            school: baseStudent.school,
            dateOfBirth: baseStudent.dateOfBirth,
            tmiPlans: [plan]
        )

        XCTAssertTrue(studentWithPlan.hasTMIPlan)
    }
}
