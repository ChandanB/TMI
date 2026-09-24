import Testing
import Foundation
@testable import TMI

@Suite("ScheduleMeetingCoordinator")
struct ScheduleMeetingCoordinatorTests {
    @Test("toMeeting throws when user not authenticated")
    func toMeetingWithoutAuth() {
        let draft = DraftMeeting(
            title: "Test Meeting",
            startTime: Date().addingTimeInterval(86400),
            endTime: Date().addingTimeInterval(86400 + 1800),
            meetingType: .checkIn,
            location: nil,
            notes: nil,
            studentIds: ["student1"],
            relatedPlanId: nil
        )
        #expect(throws: MeetingCreationError.self) {
            try draft.toMeeting(organizerID: nil)
        }
    }
}

@Suite("Schedule meeting defaults")
@MainActor
struct ScheduleMeetingDefaultsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: hour, minute: minute, second: second))!
    }

    @Test("A suggested start lands on the next half hour and never earlier")
    func roundsUpToHalfHour() {
        #expect(ScheduleMeetingView.roundedUpToHalfHour(date(9, 0), calendar: calendar) == date(9, 0))
        #expect(ScheduleMeetingView.roundedUpToHalfHour(date(9, 1), calendar: calendar) == date(9, 30))
        #expect(ScheduleMeetingView.roundedUpToHalfHour(date(9, 30, 5), calendar: calendar) == date(10, 0))
        #expect(ScheduleMeetingView.roundedUpToHalfHour(date(23, 45), calendar: calendar) == date(24, 0))
    }
}
