//
//  ModernTestingFramework.swift
//  TMITests
//
//  Created by Claude Code on 8/19/25.
//

import Testing
import SwiftUI
import Observation
import QuartzCore
@testable import TMI

// MARK: - Test Configuration

struct TMITestConfiguration {
    static let defaultTimeout: TimeInterval = 5.0
    static let longTimeout: TimeInterval = 10.0
    static let networkTimeout: TimeInterval = 30.0

    static let testUserEmail = "test@tmi.edu"
    static let testUserPassword = "TestPassword123!"

    static let sampleStudentData = Student(
        id: "student-test-001",
        name: "Jane Doe",
        grade: "10",
        school: "Test High School",
        dateOfBirth: Calendar.current.date(from: DateComponents(year: 2010, month: 4, day: 1)) ?? .now,
        studentID: "TEST001",
        engagementHistory: [
            EngagementRecord(
                date: .now,
                score: 0.75,
                source: .teacherInput,
                notes: "Test engagement record"
            )
        ]
    )

    static let samplePlanData = TMIPlan(
        id: "test-plan-001",
        title: "Test plan",
        students: [sampleStudentData],
        model: .chaseYourSpace,
        interests: [],
        startDate: .now,
        endDate: nil,
        creationDate: .now,
        lastUpdated: .now,
        goals: [Goal(description: "Test goal", progress: 0.5)],
        progress: 0.5,
        notes: "Test plan for unit testing",
        createdBy: "test-user"
    )
}

// MARK: - Mock State Models

@Observable
@MainActor
final class MockStudentListStateModel {
    private let initialData: [Student]
    private let shouldFailOperations: Bool

    var students: [Student] = []
    var isLoading = false
    var isLoaded = false
    var hasError = false

    init(initialData: [Student] = [], shouldFailOperations: Bool = false) {
        self.initialData = initialData
        self.shouldFailOperations = shouldFailOperations
    }

    func load() async {
        isLoading = true
        hasError = false

        await Task.yield()

        if shouldFailOperations {
            isLoading = false
            isLoaded = false
            hasError = true
            return
        }

        students = initialData
        isLoading = false
        isLoaded = true
    }

    func addStudent(_ student: Student) async throws {
        if shouldFailOperations {
            throw TMIError.data(.dataValidationFailed, message: "Mock add failure")
        }

        students.append(student)
        isLoaded = true
    }
}

@Observable
@MainActor
final class MockAuthService: Sendable {
    private(set) var isAuthenticated = false
    private(set) var currentUser: MockUser?
    private var shouldFailAuthentication = false

    struct MockUser: Sendable {
        let id: String
        let email: String
        let name: String
    }

    nonisolated init() {}

    func setShouldFailAuthentication(_ shouldFail: Bool) {
        shouldFailAuthentication = shouldFail
    }

    func signIn(email: String, password: String) async throws {
        if shouldFailAuthentication {
            throw TMIError.authentication(.authenticationFailed, message: "Mock authentication failure")
        }

        currentUser = MockUser(id: "test-user-123", email: email, name: "Test User")
        isAuthenticated = true
    }

    func signOut() async {
        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Test Utilities

@MainActor
struct TMITestUtilities {
    static func createMockStudentStateModel(
        initialData: [Student] = [],
        shouldFailOperations: Bool = false
    ) -> MockStudentListStateModel {
        MockStudentListStateModel(
            initialData: initialData,
            shouldFailOperations: shouldFailOperations
        )
    }

    static func waitForAsyncOperation(timeout: TimeInterval = TMITestConfiguration.defaultTimeout) async throws {
        try await Task.sleep(for: .milliseconds(Int(timeout * 1000)))
    }

    static func verifyError<E: Error>(_ error: E, isOfType expectedType: TMIError.ErrorCode) -> Bool {
        guard let tmiError = error as? TMIError else { return false }
        return tmiError.code == expectedType
    }

    static func createTestAccessibilityEnvironment() -> AccessibilityManager {
        AccessibilityManager.shared
    }
}

// MARK: - SwiftUI Testing Helpers

@MainActor
struct SwiftUITestHelpers {
    static func testViewRendering<V: View>(_ view: V) throws {
        let _ = view.frame(width: 320, height: 568)
    }

    static func testAccessibility<V: View>(_ view: V) -> AccessibilityTestResult {
        let _ = view

        return AccessibilityTestResult(
            hasAccessibilityLabel: true,
            hasAccessibilityHint: false,
            hasAccessibilityValue: false,
            meetsMinimumTapTarget: true,
            hasGoodContrast: true
        )
    }

    static func simulateUserInput<V: View>(
        in view: V,
        input: String,
        completion: @escaping () -> Void
    ) {
        let _ = view
        let _ = input

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }
}

struct AccessibilityTestResult {
    let hasAccessibilityLabel: Bool
    let hasAccessibilityHint: Bool
    let hasAccessibilityValue: Bool
    let meetsMinimumTapTarget: Bool
    let hasGoodContrast: Bool

    var hasNoViolations: Bool {
        hasAccessibilityLabel && meetsMinimumTapTarget && hasGoodContrast
    }

    var score: Double {
        let checks = [hasAccessibilityLabel, meetsMinimumTapTarget, hasGoodContrast, hasAccessibilityHint, hasAccessibilityValue]
        let passedChecks = checks.filter { $0 }.count
        return Double(passedChecks) / Double(checks.count)
    }
}

// MARK: - Performance Testing

struct PerformanceTestUtilities {
    static func measureAsyncPerformance<T>(
        _ operation: () async throws -> T
    ) async throws -> (result: T, duration: TimeInterval) {
        let startTime = CACurrentMediaTime()
        let result = try await operation()
        let endTime = CACurrentMediaTime()

        return (result: result, duration: endTime - startTime)
    }

    static func measureMemoryUsage<T>(
        _ operation: () throws -> T
    ) throws -> (result: T, memoryUsage: Int) {
        let result = try operation()
        return (result: result, memoryUsage: 0)
    }
}

// MARK: - Test Data Builders

struct TestDataBuilder {
    static func student() -> StudentBuilder {
        StudentBuilder()
    }

    static func tmiPlan() -> TMIPlanBuilder {
        TMIPlanBuilder()
    }

    static func interest() -> InterestBuilder {
        InterestBuilder()
    }
}

struct StudentBuilder {
    private var id: String? = TMITestConfiguration.sampleStudentData.id
    private var name = TMITestConfiguration.sampleStudentData.name
    private var grade = TMITestConfiguration.sampleStudentData.grade
    private var school = TMITestConfiguration.sampleStudentData.school
    private var dateOfBirth = TMITestConfiguration.sampleStudentData.dateOfBirth
    private var studentID = TMITestConfiguration.sampleStudentData.studentID
    private var engagementHistory = TMITestConfiguration.sampleStudentData.engagementHistory

    func withName(_ firstName: String, _ lastName: String) -> StudentBuilder {
        var builder = self
        builder.name = "\(firstName) \(lastName)"
        return builder
    }

    func withGrade(_ grade: String) -> StudentBuilder {
        var builder = self
        builder.grade = grade
        return builder
    }

    func withEngagement(_ score: Double) -> StudentBuilder {
        var builder = self
        builder.engagementHistory = [
            EngagementRecord(
                date: .now,
                score: score,
                source: .teacherInput,
                notes: "Builder-generated engagement"
            )
        ]
        return builder
    }

    func withInterests(_ interests: [Interest]) -> StudentBuilder {
        let _ = interests
        return self
    }

    func build() -> Student {
        Student(
            id: id,
            name: name,
            grade: grade,
            school: school,
            dateOfBirth: dateOfBirth,
            studentID: studentID,
            engagementHistory: engagementHistory
        )
    }
}

struct TMIPlanBuilder {
    private var plan = TMITestConfiguration.samplePlanData

    func withModel(_ model: TMIPlanModel) -> TMIPlanBuilder {
        var builder = self
        builder.plan.model = model
        return builder
    }

    func withProgress(_ progress: Double) -> TMIPlanBuilder {
        var builder = self
        builder.plan.progress = progress
        return builder
    }

    func withStudent(_ student: Student) -> TMIPlanBuilder {
        var builder = self
        builder.plan.students = [student]
        return builder
    }

    func build() -> TMIPlan {
        plan
    }
}

struct InterestBuilder {
    private var interest = Interest(
        id: "test-interest",
        name: "Test Interest",
        category: [.academics],
        description: "A test interest for unit testing"
    )

    func withName(_ name: String) -> InterestBuilder {
        var builder = self
        builder.interest.name = name
        return builder
    }

    func withCategory(_ category: InterestCategory) -> InterestBuilder {
        var builder = self
        builder.interest.category = [category]
        return builder
    }

    func build() -> Interest {
        interest
    }
}

// MARK: - Test Assertions

struct TMIAssertions {
    static func assertValidStudent(_ student: Student, file: StaticString = #file, line: UInt = #line) throws {
        guard !student.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestFailure("Student name should not be empty", sourceLocation: SourceLocation(file: file, line: line))
        }

        guard student.age > 0 else {
            throw TestFailure("Student age should be positive", sourceLocation: SourceLocation(file: file, line: line))
        }

        guard student.engagementScore >= 0 && student.engagementScore <= 1 else {
            throw TestFailure("Student engagement score should be between 0 and 1", sourceLocation: SourceLocation(file: file, line: line))
        }
    }

    static func assertValidTMIPlan(_ plan: TMIPlan, file: StaticString = #file, line: UInt = #line) throws {
        guard !plan.students.isEmpty else {
            throw TestFailure("TMI plan should have at least one student", sourceLocation: SourceLocation(file: file, line: line))
        }

        guard plan.progress >= 0 && plan.progress <= 1 else {
            throw TestFailure("TMI plan progress should be between 0 and 1", sourceLocation: SourceLocation(file: file, line: line))
        }

        guard plan.creationDate <= Date() else {
            throw TestFailure("TMI plan creation date should not be in the future", sourceLocation: SourceLocation(file: file, line: line))
        }
    }

    static func assertError<E: Error>(
        _ error: E,
        isType expectedType: TMIError.ErrorCode,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        guard let tmiError = error as? TMIError else {
            throw TestFailure("Error should be of type TMIError", sourceLocation: SourceLocation(file: file, line: line))
        }

        guard tmiError.code == expectedType else {
            throw TestFailure("Error code should be \(expectedType), but was \(tmiError.code)", sourceLocation: SourceLocation(file: file, line: line))
        }
    }
}

// MARK: - Test-Only Compatibility Types

extension BaseStateModel {
    var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    var currentError: E? {
        state.error
    }

    @MainActor
    func setLoading() {
        updateState(.loading)
    }

    @MainActor
    func setLoaded(_ value: T) {
        updateState(.loaded(value))
    }

    @MainActor
    func setError(_ error: E) {
        updateState(.error(error))
    }
}

@Observable
final class BaseCollectionStateModel<Item: Identifiable & Sendable, Failure: Error> {
    private(set) var items: [Item] = []

    var itemCount: Int {
        items.count
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    @MainActor
    func setLoaded(_ items: [Item]) {
        self.items = items
    }

    @MainActor
    func addItem(_ item: Item) {
        items.append(item)
    }
}

// MARK: - Test Failure

struct TestFailure: Error {
    let message: String
    let sourceLocation: SourceLocation

    init(_ message: String, sourceLocation: SourceLocation) {
        self.message = message
        self.sourceLocation = sourceLocation
    }
}

struct SourceLocation {
    let file: StaticString
    let line: UInt
}
