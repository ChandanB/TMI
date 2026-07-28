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
        #expect(MVPEmptyStateCopy.dashboardActivityTitle == "Roster activity will appear here")
        #expect(MVPEmptyStateCopy.dashboardActivityMessage.localizedCaseInsensitiveContains("add a student"))
        #expect(MVPEmptyStateCopy.studentInterestsTitle == "Discover what motivates this student")
        #expect(MVPEmptyStateCopy.studentPlansTitle == "Turn interests into a support plan")
        #expect(MVPEmptyStateCopy.districtPilotTitle == "Pilot data will appear here")
    }
}

@Suite("Modern State Model Tests")
struct ModernStateModelTests {
    @Test("BaseStateModel compatibility helpers update state")
    @MainActor
    func testBaseStateModelHelpers() {
        let stateModel = BaseStateModel<[String], TMIError>()

        stateModel.setLoading()
        #expect(stateModel.isLoading)
        #expect(stateModel.isLoaded == false)

        stateModel.setLoaded(["test1", "test2"])
        #expect(stateModel.isLoaded)
        #expect(stateModel.value == ["test1", "test2"])

        let error = TMIError.data(.dataNotFound, message: "Missing")
        stateModel.setError(error)
        #expect(stateModel.hasError)
        #expect(stateModel.currentError?.code == .dataNotFound)
    }

    @Test("Mock student state model loads data")
    @MainActor
    func testMockStudentStateModelLoad() async throws {
        let stateModel = TMITestUtilities.createMockStudentStateModel(
            initialData: [TMITestConfiguration.sampleStudentData]
        )

        await stateModel.load()

        #expect(stateModel.isLoaded)
        #expect(stateModel.students.count == 1)
    }

    @Test("Mock student state model reports failure path")
    @MainActor
    func testMockStudentStateModelFailure() async throws {
        let stateModel = TMITestUtilities.createMockStudentStateModel(shouldFailOperations: true)

        await stateModel.load()

        #expect(stateModel.hasError)
        #expect(stateModel.isLoaded == false)
    }
}

@Suite("Builder Tests")
struct BuilderTests {
    @Test("Student builder composes name and engagement")
    func testStudentBuilder() {
        let student = TestDataBuilder.student()
            .withName("Alex", "Carter")
            .withGrade("7")
            .withEngagement(0.8)
            .build()

        #expect(student.name == "Alex Carter")
        #expect(student.grade == "7")
        #expect(student.engagementScore == 0.8)
    }

    @Test("Plan builder swaps student and progress")
    func testPlanBuilder() {
        let student = TestDataBuilder.student().withName("Taylor", "Brooks").build()
        let plan = TestDataBuilder.tmiPlan()
            .withStudent(student)
            .withModel(.alignYourMind)
            .withProgress(0.6)
            .build()

        #expect(plan.students.first?.name == "Taylor Brooks")
        #expect(plan.model == .alignYourMind)
        #expect(plan.progress == 0.6)
    }

    @Test("SwiftUI helper accepts simple views")
    @MainActor
    func testSwiftUIRenderHelper() throws {
        let view = Text("Hello")
        try SwiftUITestHelpers.testViewRendering(view)
        let accessibility = SwiftUITestHelpers.testAccessibility(view)
        #expect(accessibility.hasAccessibilityLabel)
        #expect(accessibility.hasNoViolations)
    }
}
