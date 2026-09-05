//
//  MeetingServiceTests.swift
//  TMITests
//
//  Verifies MeetingService derives the district scope from the trusted
//  authorization session (mirroring FormTemplateService) instead of
//  reading users/{uid}/meetings.
//

import FirebaseFirestore
import Foundation
import Testing
@testable import TMI

@Suite("MeetingService district scoping")
struct MeetingServiceTests {
    private let districtID = "district-1"
    private let userID = "teacher-1"

    private func makeSession(userID: String = "teacher-1", districtID: String = "district-1") -> AuthenticatedSession {
        let user = TMIUser(
            id: userID,
            email: "teacher@example.com",
            displayName: "Test Teacher",
            requestedRole: .teacher,
            profileCreatedDate: .distantPast
        )
        let claim = TrustedTenantClaim(
            userID: userID,
            districtID: districtID,
            accessClass: .staff,
            membershipVersion: 1
        )
        let membership = MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: ["school-1"],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: ["student-1"],
            isActive: true,
            version: 1
        )
        return AuthenticatedSession(profile: user, claim: claim, membership: membership)
    }

    private func makeMeeting(
        id: String? = nil,
        relatedPlanId: String? = "plan-1",
        participants: [MeetingParticipant] = []
    ) -> Meeting {
        Meeting(
            id: id,
            title: "Check-in",
            description: nil,
            startTime: Date(timeIntervalSince1970: 1_000),
            endTime: Date(timeIntervalSince1970: 2_000),
            location: nil,
            meetingType: .checkIn,
            organizer: "someone-else",
            participants: participants,
            relatedStudentIds: ["student-1"],
            relatedPlanId: relatedPlanId,
            status: .scheduled,
            notes: nil,
            completedAt: nil,
            actionItems: [],
            createdAt: Date(timeIntervalSince1970: 500),
            lastUpdated: Date(timeIntervalSince1970: 500)
        )
    }

    @Test("scheduleMeeting writes to the district meetings path with the session's userID as organizer and stamps participantUserIDs")
    func scheduleMeetingWritesDistrictPath() async throws {
        let store = FakeMeetingStore()
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = MeetingService(store: store, authorizationSessions: sessions, currentUserID: { userID })
        let participant = MeetingParticipant(userId: "participant-1", name: "Participant", role: .teacher, responseStatus: .pending)

        let result = try await service.scheduleMeeting(makeMeeting(participants: [participant]))

        #expect(store.addCalls.count == 1)
        let call = try #require(store.addCalls.first)
        #expect(call.path == FirestorePaths.meetings(districtID: districtID))
        #expect(!call.path.contains("users/"))
        #expect(call.data["organizer"] as? String == userID)
        let participantUserIDs = try #require(call.data["participantUserIDs"] as? [String])
        #expect(participantUserIDs.contains(userID))
        #expect(participantUserIDs.contains("participant-1"))
        #expect(result.id == store.nextDocumentID)
    }

    @Test("fetchMeetings issues an arrayContains query on participantUserIDs scoped to the session user")
    func fetchMeetingsReadsDistrictPath() async throws {
        let store = FakeMeetingStore()
        let meeting = makeMeeting(id: "meeting-1")
        store.seed(
            atCollectionPath: FirestorePaths.meetings(districtID: districtID),
            id: "meeting-1",
            meeting: meeting,
            participantUserIDs: [userID]
        )
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = MeetingService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        let meetings = try await service.fetchMeetings()

        #expect(store.listCalls.isEmpty)
        #expect(store.arrayContainsCalls.count == 1)
        let call = try #require(store.arrayContainsCalls.first)
        #expect(call.path == FirestorePaths.meetings(districtID: districtID))
        #expect(call.field == "participantUserIDs")
        #expect(call.value == userID)
        #expect(!call.path.contains("users/"))
        #expect(meetings.count == 1)
        #expect(meetings.first?.id == "meeting-1")
    }

    @Test("fetchMeetings(for:) queries participantUserIDs arrayContains, then filters relatedPlanId client-side")
    func fetchMeetingsForPlanQueriesDistrictPath() async throws {
        let store = FakeMeetingStore()
        let matching = makeMeeting(id: "meeting-1", relatedPlanId: "plan-1")
        let nonMatching = makeMeeting(id: "meeting-2", relatedPlanId: "plan-2")
        store.seed(atCollectionPath: FirestorePaths.meetings(districtID: districtID), id: "meeting-1", meeting: matching, participantUserIDs: [userID])
        store.seed(atCollectionPath: FirestorePaths.meetings(districtID: districtID), id: "meeting-2", meeting: nonMatching, participantUserIDs: [userID])
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = MeetingService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        let meetings = try await service.fetchMeetings(for: "plan-1")

        #expect(store.arrayContainsCalls.count == 1)
        let call = try #require(store.arrayContainsCalls.first)
        #expect(call.path == FirestorePaths.meetings(districtID: districtID))
        #expect(call.field == "participantUserIDs")
        #expect(call.value == userID)
        #expect(!call.path.contains("users/"))
        // No compound Firestore query for relatedPlanId - filtered client-side instead.
        #expect(store.queryCalls.isEmpty)
        #expect(meetings.count == 1)
        #expect(meetings.first?.id == "meeting-1")
    }

    @Test("No trusted session throws and performs no store writes")
    func noSessionThrowsWithoutWriting() async throws {
        let store = FakeMeetingStore()
        let sessions = FakeAuthorizationSessionProvider(session: nil)
        let service = MeetingService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        await #expect(throws: MeetingServiceError.userNotAuthenticated) {
            _ = try await service.scheduleMeeting(self.makeMeeting())
        }

        #expect(store.addCalls.isEmpty)
    }
}

// MARK: - Test doubles

private final class FakeAuthorizationSessionProvider: AuthorizationSessionProviding, @unchecked Sendable {
    private let session: AuthenticatedSession?

    init(session: AuthenticatedSession?) {
        self.session = session
    }

    func session(authenticatedUserID: String?) -> AuthenticatedSession? {
        session
    }
}

private final class FakeMeetingStore: MeetingStore, @unchecked Sendable {
    private(set) var addCalls: [(path: String, data: [String: Any])] = []
    private(set) var setCalls: [(path: String, id: String, data: [String: Any], merge: Bool)] = []
    private(set) var updateCalls: [(path: String, id: String, data: [String: Any])] = []
    private(set) var deleteCalls: [(path: String, id: String)] = []
    private(set) var listCalls: [String] = []
    private(set) var queryCalls: [(path: String, field: String, value: String)] = []
    private(set) var arrayContainsCalls: [(path: String, field: String, value: String)] = []

    var nextDocumentID = "generated-meeting-id"
    private var seeded: [String: [(id: String, data: [String: Any])]] = [:]

    func seed(atCollectionPath path: String, id: String, meeting: Meeting, participantUserIDs: [String] = []) {
        var data = (try? Firestore.Encoder().encode(meeting)) ?? [:]
        data["participantUserIDs"] = participantUserIDs
        seeded[path, default: []].append((id: id, data: data))
    }

    func documents(atCollectionPath path: String) async throws -> [(id: String, data: [String: Any])] {
        listCalls.append(path)
        return seeded[path] ?? []
    }

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        queryCalls.append((path: path, field: field, value: value))
        return (seeded[path] ?? []).filter { ($0.data[field] as? String) == value }
    }

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        arrayContains value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        arrayContainsCalls.append((path: path, field: field, value: value))
        return (seeded[path] ?? []).filter { ($0.data[field] as? [String])?.contains(value) == true }
    }

    @discardableResult
    func addDocument(atCollectionPath path: String, data: [String: Any]) async throws -> String {
        addCalls.append((path: path, data: data))
        return nextDocumentID
    }

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: [String: Any],
        merge: Bool
    ) async throws {
        setCalls.append((path: path, id: id, data: data, merge: merge))
    }

    func updateDocument(atCollectionPath path: String, id: String, data: [String: Any]) async throws {
        updateCalls.append((path: path, id: id, data: data))
    }

    func deleteDocument(atCollectionPath path: String, id: String) async throws {
        deleteCalls.append((path: path, id: id))
    }
}
