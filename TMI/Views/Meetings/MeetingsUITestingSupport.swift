#if DEBUG
import Foundation
import SwiftUI

/// `-fixture meetings`: the Meetings hub over an in-memory store, seeded
/// through the real `MeetingService` so stored documents have the same shape
/// Firestore would hold.
struct MeetingsUITestingContent: View {
    @State private var stateModel: MeetingsStateModel?

    var body: some View {
        NavigationStack {
            if let stateModel {
                MeetingsHubView()
                    .environment(\.meetingsStateModel, stateModel)
            } else {
                ProgressView()
            }
        }
        .task {
            guard stateModel == nil else { return }
            let service = MeetingsUITestingData.service()
            await MeetingsUITestingData.seed(service)
            stateModel = MeetingsStateModel(meetingService: service)
        }
    }
}

enum MeetingsUITestingData {
    nonisolated static let userID = "fixture-teacher"
    nonisolated static let districtID = "district-fixture"

    static func service() -> MeetingService {
        MeetingService(
            store: InMemoryMeetingStore(),
            authorizationSessions: FixtureSessionProvider(),
            currentUserID: { userID }
        )
    }

    static func seed(_ service: MeetingService, now: Date = .now) async {
        let day: TimeInterval = 86_400
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        func at(_ offsetDays: Double, hour: Int, minute: Int = 0) -> Date {
            today.addingTimeInterval(offsetDays * day + TimeInterval(hour * 3600 + minute * 60))
        }
        let people = [
            MeetingParticipant(userId: userID, name: "Jordan Lee", role: .teacher, responseStatus: .accepted),
            MeetingParticipant(userId: "fixture-counselor", name: "Priya Shah", role: .counselor, responseStatus: .accepted),
            MeetingParticipant(userId: "fixture-parent", name: "Dana Rivera", role: .parent, responseStatus: .tentative),
        ]
        let meetings = [
            meeting("Weekly check-in with Kai", .checkIn, at(1, hour: 9, minute: 30), 30, "Room 204",
                    people: Array(people.prefix(2)),
                    about: "Review how the creative routine is going and pick next week's project step.",
                    items: [
                        ActionItem(description: "Bring the sketchbook", dueDate: at(1, hour: 9)),
                        ActionItem(description: "Share the project checklist with family", dueDate: at(3, hour: 15)),
                    ]),
            meeting("Family conference: Kai Rivera", .parentConference, at(4, hour: 15), 45, "Main office",
                    people: people,
                    about: "Share progress on the TMI plan and hear what is working at home."),
            meeting("Support team strategy session", .strategySession, at(8, hour: 13), 60, "Video call",
                    people: Array(people.prefix(2))),
            meeting("Progress review: Maya Thompson", .progressReview, at(-3, hour: 10), 30, "Room 112",
                    people: Array(people.prefix(2)), status: .completed,
                    notes: "Maya met her first goal. Moving to two check-ins a week.",
                    items: [ActionItem(description: "Update the goal target", isCompleted: true, completedAt: at(-2, hour: 12))]),
            meeting("Student meeting: Leo Park", .studentMeeting, at(-6, hour: 11), 20, nil,
                    people: Array(people.prefix(1)), status: .cancelled),
        ]
        for meeting in meetings {
            _ = try? await service.scheduleMeeting(meeting)
        }
    }

    private static func meeting(
        _ title: String,
        _ type: Meeting.MeetingType,
        _ start: Date,
        _ minutes: Int,
        _ location: String?,
        people: [MeetingParticipant],
        about: String? = nil,
        status: Meeting.MeetingStatus = .confirmed,
        notes: String? = nil,
        items: [ActionItem] = []
    ) -> Meeting {
        Meeting(
            title: title,
            description: about,
            startTime: start,
            endTime: start.addingTimeInterval(TimeInterval(minutes * 60)),
            location: location,
            meetingType: type,
            organizer: userID,
            participants: people,
            relatedStudentIds: ["student-fixture"],
            relatedPlanId: nil,
            status: status,
            notes: notes,
            completedAt: status == .completed ? start : nil,
            actionItems: items,
            createdAt: start.addingTimeInterval(-7 * 86_400),
            lastUpdated: start
        )
    }

    private nonisolated struct FixtureSessionProvider: AuthorizationSessionProviding {
        func session(authenticatedUserID: String?) -> AuthenticatedSession? {
            AuthenticatedSession(
                profile: TMIUser(
                    id: userID,
                    email: "jordan.lee@example.edu",
                    displayName: "Jordan Lee",
                    requestedRole: .teacher,
                    profileCreatedDate: .distantPast
                ),
                claim: TrustedTenantClaim(
                    userID: userID,
                    districtID: districtID,
                    accessClass: .staff,
                    membershipVersion: 1
                ),
                membership: MembershipContext(
                    userID: userID,
                    districtID: districtID,
                    schoolIDs: ["school-fixture"],
                    role: .teacher,
                    capabilities: [.studentReadDetail, .studentWriteDetail],
                    assignedStudentIDs: ["student-fixture"],
                    isActive: true,
                    version: 1
                )
            )
        }
    }
}

/// Collection-path keyed documents held in memory.
nonisolated final class InMemoryMeetingStore: MeetingStore, @unchecked Sendable {
    private let lock = NSLock()
    private var collections: [String: [(id: String, data: [String: Any])]] = [:]

    private func read(_ path: String) -> [(id: String, data: [String: Any])] {
        lock.withLock { collections[path] ?? [] }
    }

    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])] {
        read(path)
    }

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        read(path).filter { ($0.data[field] as? String) == value }
    }

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        arrayContains value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        read(path).filter { ($0.data[field] as? [String])?.contains(value) == true }
    }

    func addDocument(atCollectionPath path: String, data: sending [String: Any]) async throws -> String {
        let id = UUID().uuidString
        lock.withLock { collections[path, default: []].append((id: id, data: data)) }
        return id
    }

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: sending [String: Any],
        merge: Bool
    ) async throws {
        lock.withLock {
            var documents = collections[path] ?? []
            if let index = documents.firstIndex(where: { $0.id == id }) {
                var merged = merge ? documents[index].data : [:]
                merged.merge(data) { _, new in new }
                documents[index] = (id: id, data: merged)
            } else {
                documents.append((id: id, data: data))
            }
            collections[path] = documents
        }
    }

    func updateDocument(atCollectionPath path: String, id: String, data: sending [String: Any]) async throws {
        try await setDocument(atCollectionPath: path, id: id, data: data, merge: true)
    }

    func deleteDocument(atCollectionPath path: String, id: String) async throws {
        lock.withLock { collections[path]?.removeAll { $0.id == id } }
    }
}
#endif
