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
}
