import Foundation
import Testing
@testable import TMI

@Suite("Recent Activity")
struct RecentActivityTests {
    @Test("Generated fallback IDs are non-empty and unique")
    func fallbackIDsAreUnique() {
        let now = Date(timeIntervalSince1970: 1_234_567)

        let first = RecentActivity(
            icon: "doc.fill",
            title: "Plan Updated",
            description: "Plan for Student A was updated",
            date: now,
            iconColorName: "blue"
        )
        let second = RecentActivity(
            icon: "doc.fill",
            title: "Plan Updated",
            description: "Plan for Student A was updated",
            date: now,
            iconColorName: "blue"
        )

        #expect(first.id.isEmpty == false)
        #expect(second.id.isEmpty == false)
        #expect(first.id != second.id)
    }

    @Test("Default plan title is deterministic for the same students")
    func defaultPlanTitleIsDeterministic() {
        let firstStudent = Student(
            id: "b-student",
            name: "Taylor Brooks",
            grade: "5",
            school: "TMI Academy",
            dateOfBirth: Date(timeIntervalSince1970: 100)
        )
        let secondStudent = Student(
            id: "a-student",
            name: "Alex Carter",
            grade: "5",
            school: "TMI Academy",
            dateOfBirth: Date(timeIntervalSince1970: 200)
        )

        let firstOrdering = TMIPlanEditorView.defaultPlanTitle(
            for: .alignYourMind,
            students: [firstStudent, secondStudent]
        )
        let secondOrdering = TMIPlanEditorView.defaultPlanTitle(
            for: .alignYourMind,
            students: [secondStudent, firstStudent]
        )

        #expect(firstOrdering == "Align Your Mind - Alex Carter")
        #expect(firstOrdering == secondOrdering)
    }

    @Test("Default plan title uses ID as tie-breaker when names match")
    func defaultPlanTitleUsesIDTieBreaker() {
        let firstStudent = Student(
            id: "b-student",
            name: "Alex Carter",
            grade: "5",
            school: "TMI Academy",
            dateOfBirth: Date(timeIntervalSince1970: 100)
        )
        let secondStudent = Student(
            id: "a-student",
            name: "Alex Carter",
            grade: "5",
            school: "TMI Academy",
            dateOfBirth: Date(timeIntervalSince1970: 200)
        )

        let firstOrdering = TMIPlanEditorView.defaultPlanTitle(
            for: .alignYourMind,
            students: [firstStudent, secondStudent]
        )
        let secondOrdering = TMIPlanEditorView.defaultPlanTitle(
            for: .alignYourMind,
            students: [secondStudent, firstStudent]
        )

        #expect(firstOrdering == "Align Your Mind - Alex Carter")
        #expect(firstOrdering == secondOrdering)
    }

    @Test("Default plan title falls back to model when there are no students")
    func defaultPlanTitleFallsBackWithoutStudents() {
        #expect(
            TMIPlanEditorView.defaultPlanTitle(for: .chaseYourSpace, students: []) == "Chase Your Space"
        )
    }

    @Test("Student next step round trips when notes already exist")
    func studentNextStepRoundTripsWithExistingNotes() {
        let combinedNotes = TMIPlanEditorView.notes(
            withStudentNextStep: "Bring planner\nAsk for help",
            notes: "Student prefers morning check-ins."
        )
        let extracted = TMIPlanEditorView.extractStudentNextStep(from: combinedNotes)

        #expect(combinedNotes == "Student Next Step: Bring planner Ask for help\n\nStudent prefers morning check-ins.")
        #expect(extracted.nextStep == "Bring planner Ask for help")
        #expect(extracted.notes == "Student prefers morning check-ins.")
    }
}
