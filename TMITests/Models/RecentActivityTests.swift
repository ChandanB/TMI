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
}
