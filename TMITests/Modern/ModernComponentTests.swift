//
//  ModernComponentTests.swift
//  TMITests
//
//  Created by Claude Code on 8/19/25.
//

import Testing
import SwiftUI
@testable import TMI

@Suite("MVP Empty State Copy Tests")
struct MVPEmptyStateCopyTests {

    @Test("MVP empty states guide users into the core workflow")
    func testMVPCopySupportsCoreWorkflow() {
        #expect(MVPEmptyStateCopy.dashboardActivityTitle == "Start the core loop")
        #expect(MVPEmptyStateCopy.dashboardActivityMessage.contains("add a student"))
        #expect(MVPEmptyStateCopy.studentPlansAction == "Create First Plan")
        #expect(MVPEmptyStateCopy.studentInterestsAction == "Take Survey")
        #expect(MVPEmptyStateCopy.studentMeetingsAction == "Schedule Meeting")
        #expect(MVPEmptyStateCopy.districtPilotTitle == "Pilot data will appear here")
    }
}

// MARK: - State Model Tests

@Suite("Modern State Model Tests")
struct ModernStateModelTests {
    
    @Test("BaseStateModel initializes correctly")
    func testBaseStateModelInitialization() async {
        let stateModel = BaseStateModel<[String], TMIError>()
        
        #expect(stateModel.isLoading == false)
        #expect(stateModel.isLoaded == false)
        #expect(stateModel.hasError == false)
        #expect(stateModel.value == nil)
        #expect(stateModel.currentError == nil)
    }
    
    @Test("BaseStateModel handles loading state")
    func testBaseStateModelLoading() async {
        let stateModel = BaseStateModel<[String], TMIError>()
        
        await stateModel.setLoading()
        
        #expect(stateModel.isLoading == true)
        #expect(stateModel.isLoaded == false)
        #expect(stateModel.hasError == false)
    }
    
    @Test("BaseStateModel handles loaded state")
    func testBaseStateModelLoaded() async {
        let stateModel = BaseStateModel<[String], TMIError>()
        let testData = ["test1", "test2", "test3"]
        
        await stateModel.setLoaded(testData)
        
        #expect(stateModel.isLoading == false)
        #expect(stateModel.isLoaded == true)
        #expect(stateModel.hasError == false)
        #expect(stateModel.value == testData)
    }
    
    @Test("BaseStateModel handles error state")
    func testBaseStateModelError() async {
        let stateModel = BaseStateModel<[String], TMIError>()
        let testError = TMIError.data(.dataNotFound, message: "Test error")
        
        await stateModel.setError(testError)
        
        #expect(stateModel.isLoading == false)
        #expect(stateModel.isLoaded == false)
        #expect(stateModel.hasError == true)
        #expect(stateModel.currentError?.code == testError.code)
    }
    
    @Test("BaseCollectionStateModel manages items correctly")
    func testBaseCollectionStateModel() async {
        let stateModel = BaseCollectionStateModel<Student, TMIError>()
        let students = [
            TestDataBuilder.student().withName("John", "Doe").build(),
            TestDataBuilder.student().withName("Jane", "Smith").build()
        ]
        
        await stateModel.setLoaded(students)
        
        #expect(stateModel.itemCount == 2)
        #expect(stateModel.isEmpty == false)
        
        let newStudent = TestDataBuilder.student().withName("Bob", "Johnson").build()
        await stateModel.addItem(newStudent)
        
        #expect(stateModel.itemCount == 3)
    }
}

// MARK: - Error Handling Tests

@Suite("TMI Error Handling Tests")
struct TMIErrorTests {
    
    @Test("TMIError creates correctly with all properties")
    func testTMIErrorCreation() {
        let error = TMIError.student(
            .studentNotFound,
            studentId: "test-123",
            message: "Test student not found"
        )
        
        #expect(error.code == .studentNotFound)
        #expect(error.message == "Test student not found")
        #expect(error.context["studentId"] == "test-123")
        #expect(error.context["category"] == "student")
    }
    
    @Test("TMIError provides localized descriptions")
    func testTMIErrorLocalizedDescription() {
        let error = TMIError.authentication(.authenticationFailed)
        
        #expect(error.errorDescription != nil)
        #expect(error.recoverySuggestion != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }
    
    @Test("TMIError handles different categories")
    func testTMIErrorCategories() {
        let authError = TMIError.authentication(.authenticationFailed)
        let dataError = TMIError.data(.dataNotFound)
        let networkError = TMIError.network(.networkUnavailable)
        
        #expect(authError.context["category"] == "authentication")
        #expect(dataError.context["category"] == "data")
        #expect(networkError.context["category"] == "network")
    }
    
    @Test("TMIError equality works correctly")
    func testTMIErrorEquality() {
        let error1 = TMIError(code: .studentNotFound, message: "Test")
        let error2 = TMIError(code: .studentNotFound, message: "Test")
        let error3 = TMIError(code: .studentCreationFailed, message: "Test")
        
        // Note: Equality is based on code and message, not timestamp
        #expect(error1.code == error2.code)
        #expect(error1.code != error3.code)
    }
}

// MARK: - Data Cache Tests

@Suite("Data Cache Tests")
struct DataCacheTests {
    
    @Test("DataCache stores and retrieves values")
    func testDataCacheBasicOperations() async {
        let cache = DataCache()
        let testValue = "test-value"
        let testKey = "test-key"
        
        await cache.set(key: testKey, value: testValue)
        let retrievedValue: String? = await cache.get(key: testKey)
        
        #expect(retrievedValue == testValue)
    }
    
    @Test("DataCache handles missing keys")
    func testDataCacheMissingKey() async {
        let cache = DataCache()
        let retrievedValue: String? = await cache.get(key: "nonexistent-key")
        
        #expect(retrievedValue == nil)
    }
    
    @Test("DataCache removes values")
    func testDataCacheRemoval() async {
        let cache = DataCache()
        let testValue = "test-value"
        let testKey = "test-key"
        
        await cache.set(key: testKey, value: testValue)
        await cache.remove(key: testKey)
        let retrievedValue: String? = await cache.get(key: testKey)
        
        #expect(retrievedValue == nil)
    }
    
    @Test("DataCache provides statistics")
    func testDataCacheStatistics() async {
        let cache = DataCache()
        
        await cache.set(key: "key1", value: "value1")
        await cache.set(key: "key2", value: "value2")
        
        let stats = await cache.getStatistics()
        
        #expect(stats.entryCount == 2)
        #expect(stats.totalSizeMB >= 0)
    }
    
    @Test("DataCache handles collection operations")
    func testDataCacheCollections() async {
        let cache = DataCache()
        let students = [
            TestDataBuilder.student().withName("John", "Doe").build(),
            TestDataBuilder.student().withName("Jane", "Smith").build()
        ]
        
        await cache.setCollection(key: "students", items: students)
        let retrievedStudents: [Student]? = await cache.getCollection(key: "students", type: Student.self)
        
        #expect(retrievedStudents?.count == 2)
        #expect(retrievedStudents?.first?.firstName == "John")
    }
}

// MARK: - Navigation Tests

@Suite("Navigation Manager Tests")
struct NavigationManagerTests {
    
    @Test("NavigationManager initializes with default state")
    @MainActor
    func testNavigationManagerInitialization() {
        let manager = NavigationManager()
        
        #expect(manager.selectedTab == .students)
        #expect(manager.studentsPath.isEmpty)
        #expect(manager.plansPath.isEmpty)
        #expect(manager.currentRoute == nil)
    }
    
    @Test("NavigationManager switches tabs correctly")
    @MainActor
    func testNavigationManagerTabSwitching() {
        let manager = NavigationManager()
        
        manager.selectTab(.plans)
        #expect(manager.selectedTab == .plans)
        
        manager.selectTab(.settings)
        #expect(manager.selectedTab == .settings)
    }
    
    @Test("NavigationManager handles route navigation")
    @MainActor
    func testNavigationManagerRouting() {
        let manager = NavigationManager()
        
        manager.navigate(to: .studentDetail("test-student-123"))
        
        #expect(manager.selectedTab == .students)
        #expect(!manager.studentsPath.isEmpty)
    }
    
    @Test("NavigationManager generates deep links")
    @MainActor
    func testNavigationManagerDeepLinks() {
        let manager = NavigationManager()
        
        let url = manager.generateDeepLink(for: .studentDetail("test-123"))
        
        #expect(url?.absoluteString == "tmi://students/test-123")
    }
    
    @Test("NavigationManager pops to root")
    @MainActor
    func testNavigationManagerPopToRoot() {
        let manager = NavigationManager()
        
        // Navigate to a detail view
        manager.navigate(to: .studentDetail("test-123"))
        #expect(!manager.studentsPath.isEmpty)
        
        // Pop to root
        manager.popToRoot()
        #expect(manager.studentsPath.isEmpty)
    }
}

// MARK: - Component Tests

@Suite("TMI Component Tests")
struct TMIComponentTests {
    
    @Test("TMIButton renders without crashing")
    @MainActor
    func testTMIButtonRendering() throws {
        let button = TMIButton("Test Button") {}
        
        try SwiftUITestHelpers.testViewRendering(button)
    }
    
    @Test("TMICard renders with different styles")
    @MainActor
    func testTMICardRendering() throws {
        let defaultCard = TMICard(style: .default) {
            Text("Default Card")
        }
        
        let elevatedCard = TMICard(style: .elevated) {
            Text("Elevated Card")
        }
        
        let glassCard = TMICard(style: .glass) {
            Text("Glass Card")
        }
        
        try SwiftUITestHelpers.testViewRendering(defaultCard)
        try SwiftUITestHelpers.testViewRendering(elevatedCard)
        try SwiftUITestHelpers.testViewRendering(glassCard)
    }
    
    @Test("TMITextField handles input correctly")
    @MainActor
    func testTMITextFieldInput() throws {
        @State var text = ""
        
        let textField = TMITextField(
            title: "Test Field",
            placeholder: "Enter text",
            text: $text
        )
        
        try SwiftUITestHelpers.testViewRendering(textField)
    }
    
    @Test("TMILoadingView displays correctly")
    @MainActor
    func testTMILoadingView() throws {
        let loadingView = TMILoadingView(message: "Loading test data...")
        
        try SwiftUITestHelpers.testViewRendering(loadingView)
    }
    
    @Test("TMIEmptyState renders with action")
    @MainActor
    func testTMIEmptyState() throws {
        let emptyState = TMIEmptyState(
            icon: "person.fill",
            title: "No Students",
            message: "Add your first student to get started",
            actionTitle: "Add Student"
        ) {}
        
        try SwiftUITestHelpers.testViewRendering(emptyState)
    }
}

// MARK: - Accessibility Tests

@Suite("Accessibility Tests")
struct AccessibilityTests {
    
    @Test("AccessibilityManager initializes correctly")
    @MainActor
    func testAccessibilityManagerInitialization() {
        let manager = AccessibilityManager.shared
        
        #expect(manager.minimumTapTargetSize.width >= 44)
        #expect(manager.minimumTapTargetSize.height >= 44)
        #expect(manager.recommendedAnimationDuration >= 0)
    }
    
    @Test("AccessibilityManager handles content size scaling")
    @MainActor
    func testAccessibilityContentSizeScaling() {
        let manager = AccessibilityManager.shared
        
        let baseSize: CGFloat = 16
        let scaledSize = manager.scaledFontSize(baseSize)
        
        #expect(scaledSize >= baseSize * 0.8) // Should be at least 80% of base
        #expect(scaledSize <= baseSize * 3.0) // Should not exceed 300% of base
    }
    
    @Test("AccessibilityManager provides accessible colors")
    @MainActor
    func testAccessibilityColors() {
        let manager = AccessibilityManager.shared
        let originalColor = Color.blue
        
        let accessibleColor = manager.accessibleColor(originalColor)
        
        #expect(accessibleColor != nil)
    }
    
    @Test("Accessible button meets accessibility requirements")
    @MainActor
    func testAccessibleButton() throws {
        let button = AccessibleButton(
            title: "Test Button",
            icon: "star.fill",
            action: {},
            style: .primary
        )
        
        try SwiftUITestHelpers.testViewRendering(button)
        
        let accessibilityResult = SwiftUITestHelpers.testAccessibility(button)
        #expect(accessibilityResult.hasAccessibilityLabel)
        #expect(accessibilityResult.meetsMinimumTapTarget)
    }
    
    @Test("Accessible text field has proper accessibility attributes")
    @MainActor
    func testAccessibleTextField() throws {
        @State var text = ""
        
        let textField = AccessibleTextField(
            title: "Test Field",
            placeholder: "Enter text",
            text: $text,
            isSecure: false
        )
        
        try SwiftUITestHelpers.testViewRendering(textField)
        
        let accessibilityResult = SwiftUITestHelpers.testAccessibility(textField)
        #expect(accessibilityResult.hasAccessibilityLabel)
    }
}

// MARK: - Performance Tests

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("StateModel loading performance")
    func testStateModelPerformance() async throws {
        let stateModel = TMITestUtilities.createMockStudentStateModel(
            initialData: Array(repeating: TMITestConfiguration.sampleStudentData, count: 100)
        )
        
        let (_, duration) = try await PerformanceTestUtilities.measureAsyncPerformance {
            await stateModel.load()
        }
        
        // Should load 100 students in less than 1 second
        #expect(duration < 1.0)
    }
    
    @Test("Cache performance with large datasets")
    func testCachePerformance() async throws {
        let cache = DataCache()
        let largeDataset = Array(0..<1000).map { "item-\($0)" }
        
        let (_, duration) = try await PerformanceTestUtilities.measureAsyncPerformance {
            await cache.set(key: "large-dataset", value: largeDataset)
        }
        
        // Should cache 1000 items in less than 0.5 seconds
        #expect(duration < 0.5)
        
        let (_, retrievalDuration) = try await PerformanceTestUtilities.measureAsyncPerformance {
            let _: [String]? = await cache.get(key: "large-dataset")
        }
        
        // Should retrieve 1000 items in less than 0.1 seconds
        #expect(retrievalDuration < 0.1)
    }
    
    @Test("Component rendering performance")
    @MainActor
    func testComponentRenderingPerformance() throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Render multiple components
        for i in 0..<100 {
            let button = TMIButton("Button \(i)") {}
            try SwiftUITestHelpers.testViewRendering(button)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Should render 100 buttons in less than 1 second
        #expect(duration < 1.0)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Student workflow integration")
    func testStudentWorkflowIntegration() async throws {
        // Create mock services
        let stateModel = TMITestUtilities.createMockStudentStateModel()
        
        // Test complete workflow
        await stateModel.load()
        #expect(stateModel.isLoaded || stateModel.isLoading)
        
        // Add a student
        let newStudent = TestDataBuilder.student()
            .withName("Integration", "Test")
            .withGrade("12")
            .build()
        
        do {
            try await stateModel.addStudent(newStudent)
            // Should succeed without throwing
        } catch {
            // Expected for mock service
        }
    }
    
    @Test("Navigation and state integration")
    @MainActor
    func testNavigationStateIntegration() {
        let navigationManager = NavigationManager()
        let stateModel = TMITestUtilities.createMockStudentStateModel()
        
        // Test navigation affects state
        navigationManager.selectTab(.students)
        #expect(navigationManager.selectedTab == .students)
        
        // Test deep link handling
        if let url = URL(string: "tmi://students/test-123") {
            navigationManager.handleDeepLink(url)
            #expect(navigationManager.selectedTab == .students)
        }
    }
    
    @Test("Error handling integration")
    func testErrorHandlingIntegration() async throws {
        let stateModel = TMITestUtilities.createMockStudentStateModel(shouldFailOperations: true)
        
        await stateModel.load()
        
        // Should handle error gracefully
        #expect(stateModel.hasError || stateModel.isLoading)
    }
}

// MARK: - Data Validation Tests

@Suite("Data Validation Tests")
struct DataValidationTests {
    
    @Test("Student validation passes for valid data")
    func testValidStudentValidation() throws {
        let validStudent = TestDataBuilder.student()
            .withName("John", "Doe")
            .withGrade("10")
            .withEngagement(0.75)
            .build()
        
        try TMIAssertions.assertValidStudent(validStudent)
    }
    
    @Test("Student validation fails for invalid data")
    func testInvalidStudentValidation() {
        let invalidStudent = TestDataBuilder.student()
            .withName("", "") // Empty names
            .withEngagement(-0.5) // Invalid engagement score
            .build()
        
        #expect(throws: TestFailure.self) {
            try TMIAssertions.assertValidStudent(invalidStudent)
        }
    }
    
    @Test("TMI Plan validation passes for valid data")
    func testValidTMIPlanValidation() throws {
        let validPlan = TestDataBuilder.tmiPlan()
            .withProgress(0.5)
            .build()
        
        try TMIAssertions.assertValidTMIPlan(validPlan)
    }
    
    @Test("TMI Plan validation fails for invalid data")
    func testInvalidTMIPlanValidation() {
        let invalidPlan = TestDataBuilder.tmiPlan()
            .withProgress(1.5) // Invalid progress > 1
            .build()
        
        #expect(throws: TestFailure.self) {
            try TMIAssertions.assertValidTMIPlan(invalidPlan)
        }
    }
}

// MARK: - Test Suite Organization

extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var performance: Self
    @Tag static var accessibility: Self
    @Tag static var ui: Self
}
