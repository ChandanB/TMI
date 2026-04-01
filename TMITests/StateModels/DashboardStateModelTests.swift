import Foundation
import Testing
@testable import TMI

@Suite("Dashboard State Model")
struct DashboardStateModelTests {
    @Test("Teacher prioritizes low-engagement students before plan creation work")
    func teacherPrioritizesLowEngagementStudents() {
        let lowEngagementStudent = makeStudent(
            id: "student-low",
            name: "Low Engagement",
            surveyCompleted: true,
            engagementScores: [0.22, 0.24]
        )
        let readyForPlanStudent = makeStudent(
            id: "student-plan",
            name: "Needs Plan",
            surveyCompleted: true,
            engagementScores: [0.72, 0.75]
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            role: .teacher,
            students: [lowEngagementStudent, readyForPlanStudent],
            plans: []
        )

        #expect(action?.type == .checkProgress)
        #expect(action?.targetStudentId == "student-low")
        #expect(action?.priority == .high)
    }

    @Test("Teacher prioritizes plan creation before survey follow-up")
    func teacherPrioritizesPlanCreationBeforeSurveyFollowUp() {
        let readyForPlanStudent = makeStudent(
            id: "student-plan",
            name: "Needs Plan",
            surveyCompleted: true,
            engagementScores: [0.66, 0.68]
        )
        let surveyPendingStudent = makeStudent(
            id: "student-survey",
            name: "Survey Pending",
            surveyCompleted: false,
            engagementScores: [0.61, 0.63]
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            role: .teacher,
            students: [readyForPlanStudent, surveyPendingStudent],
            plans: []
        )

        #expect(action?.type == .createPlan)
        #expect(action?.targetStudentId == "student-plan")
        #expect(action?.priority == .medium)
    }

    @Test("Counselor approvals outrank student-level actions")
    func counselorApprovalsOutrankStudentActions() {
        let lowEngagementStudent = makeStudent(
            id: "student-low",
            name: "Low Engagement",
            surveyCompleted: true,
            engagementScores: [0.18, 0.22]
        )
        let pendingPlan = makePlan(
            id: "plan-pending",
            students: [lowEngagementStudent],
            approvalStatus: .pendingApproval
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            role: .counselor,
            students: [lowEngagementStudent],
            plans: [pendingPlan]
        )

        #expect(action?.type == .pendingApproval)
        #expect(action?.targetPlanId == "plan-pending")
        #expect(action?.priority == .urgent)
    }
}

private extension DashboardStateModelTests {
    func makeStudent(
        id: String,
        name: String,
        surveyCompleted: Bool,
        engagementScores: [Double]
    ) -> Student {
        Student(
            id: id,
            name: name,
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
        students: [Student],
        approvalStatus: PlanApprovalStatus
    ) -> TMIPlan {
        TMIPlan(
            id: id,
            title: "Support Plan",
            students: students,
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
