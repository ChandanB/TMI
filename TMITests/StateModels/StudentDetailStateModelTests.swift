import Foundation
import Testing
@testable import TMI

@Suite("Student Detail State Model")
struct StudentDetailStateModelTests {
    @Test("Summary surfaces survey follow-up for students without a completed survey")
    @MainActor
    func summaryFlagsSurveyPendingStudents() {
        let model = StudentDetailStateModel(studentId: "student-1")

        model.student = makeStudent(id: "student-1", surveyCompleted: false, engagementScores: [0.62, 0.65])
        model.tmiPlans = []

        let summary = model.summary

        #expect(summary.activePlanCount == 0)
        #expect(summary.assignedNextStepCount == 1)
        #expect(summary.followUpStatus == .surveyPending)
        #expect(summary.needsFollowUp)
    }

    @Test("Summary surfaces plan follow-up when draft work is still open")
    @MainActor
    func summaryFlagsDraftPlansForFollowUp() {
        let student = makeStudent(id: "student-2", surveyCompleted: true, engagementScores: [0.68, 0.7])
        let model = StudentDetailStateModel(studentId: "student-2")

        model.student = student
        model.tmiPlans = [
            makePlan(id: "plan-draft", student: student, approvalStatus: .draft),
            makePlan(id: "plan-approved", student: student, approvalStatus: .approved)
        ]

        let summary = model.summary

        #expect(summary.activePlanCount == 2)
        #expect(summary.assignedNextStepCount == 1)
        #expect(summary.followUpStatus == .planFollowUp)
        #expect(summary.needsFollowUp)
    }

    @Test("Summary settles on progress monitoring when the student is covered")
    @MainActor
    func summaryMarksCoveredStudentsAsOnTrack() {
        let student = makeStudent(id: "student-3", surveyCompleted: true, engagementScores: [0.71, 0.73])
        let model = StudentDetailStateModel(studentId: "student-3")

        model.student = student
        model.tmiPlans = [
            makePlan(id: "plan-approved", student: student, approvalStatus: .approved)
        ]

        let summary = model.summary

        #expect(summary.activePlanCount == 1)
        #expect(summary.assignedNextStepCount == 0)
        #expect(summary.followUpStatus == .onTrack)
        #expect(!summary.needsFollowUp)
    }
}

private extension StudentDetailStateModelTests {
    func makeStudent(
        id: String,
        surveyCompleted: Bool,
        engagementScores: [Double]
    ) -> Student {
        Student(
            id: id,
            name: "Jordan Rivera",
            grade: "5",
            school: "North Elementary",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            surveyResults: surveyCompleted ? [
                SurveyResult(
                    id: "\(id)-survey",
                    surveyName: "Interest Survey",
                    date: Date(),
                    isComplete: true,
                    responses: []
                )
            ] : [],
            engagementHistory: engagementScores.enumerated().map { index, score in
                EngagementRecord(
                    date: Date().addingTimeInterval(TimeInterval(index) * -86_400),
                    score: score,
                    source: .teacherInput
                )
            }
        )
    }

    func makePlan(
        id: String,
        student: Student,
        approvalStatus: PlanApprovalStatus
    ) -> TMIPlan {
        TMIPlan(
            id: id,
            title: "Support Plan",
            students: [student],
            model: .chaseYourSpace,
            interests: [],
            startDate: Date(),
            endDate: nil,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0,
            notes: "",
            createdBy: "teacher-1",
            approvalStatus: approvalStatus
        )
    }
}
