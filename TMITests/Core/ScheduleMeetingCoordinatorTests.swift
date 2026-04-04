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
            try draft.toMeeting()
        }
    }
}
