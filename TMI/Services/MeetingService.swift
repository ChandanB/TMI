//
//  MeetingService.swift
//  TMI
//
//  Service for managing meetings and check-ins
//

import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

nonisolated final class MeetingService: Sendable {
    static let shared = MeetingService()

    private let store: MeetingStore
    private let authorizationSessions: any AuthorizationSessionProviding
    private let currentUserID: @Sendable () -> String?

    init(
        store: MeetingStore = FirebaseMeetingStore(),
        authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.store = store
        self.authorizationSessions = authorizationSessions
        self.currentUserID = currentUserID
    }

    // MARK: - Create Meeting

    /// Schedule a new meeting
    func scheduleMeeting(_ meeting: Meeting) async throws -> Meeting {
        let session = try authorizedSession()

        print("[MeetingService] 📅 Scheduling meeting: \(meeting.title)")

        var newMeeting = meeting
        newMeeting.id = nil

        var data = try encode(newMeeting)
        data["organizer"] = session.membership.userID
        data["participantUserIDs"] = Self.participantUserIDs(
            organizerID: session.membership.userID,
            actingUserID: session.membership.userID,
            participants: meeting.participants
        )

        let documentID = try await store.addDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            data: data
        )

        print("[MeetingService] ✅ Meeting scheduled with ID: \(documentID)")

        // Post notification for calendar integration
        NotificationCenter.default.post(
            name: NSNotification.Name("MeetingScheduled"),
            object: nil,
            userInfo: ["meetingId": documentID]
        )

        // Return meeting with ID
        var savedMeeting = meeting
        savedMeeting.id = documentID
        return savedMeeting
    }

    // MARK: - Fetch Meetings

    /// Fetch all meetings for the caller's district that the caller participates in.
    ///
    /// The `meetings` collection's read rule requires
    /// `request.auth.uid in resource.data.participantUserIDs`, so an
    /// unconstrained list query would be denied by Firestore for docs the
    /// caller cannot read. Scoping with `arrayContains` keeps the query
    /// provably limited to readable documents.
    func fetchMeetings() async throws -> [Meeting] {
        let session = try authorizedSession()

        let documents = try await store.documents(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            whereField: "participantUserIDs",
            arrayContains: session.membership.userID
        )

        let meetings = documents.compactMap(decodeMeeting)
            .sorted { $0.startTime < $1.startTime }

        print("[MeetingService] 📖 Fetched \(meetings.count) meetings")
        return meetings
    }

    /// Fetch meetings for a specific TMI Plan.
    ///
    /// Filters client-side on `relatedPlanId` after the participant-scoped
    /// `arrayContains` query so this doesn't require a composite index
    /// (array-contains + equality would need one).
    func fetchMeetings(for planId: String) async throws -> [Meeting] {
        let session = try authorizedSession()

        let documents = try await store.documents(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            whereField: "participantUserIDs",
            arrayContains: session.membership.userID
        )

        let meetings = documents.compactMap(decodeMeeting)
            .filter { $0.relatedPlanId == planId }

        print("[MeetingService] 📖 Fetched \(meetings.count) meetings for plan: \(planId)")
        return meetings
    }

    /// Fetch upcoming meetings
    func fetchUpcomingMeetings() async throws -> [Meeting] {
        let allMeetings = try await fetchMeetings()
        return allMeetings.filter { $0.isUpcoming }
    }

    // MARK: - Update Meeting

    /// Update an existing meeting
    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        guard let meetingId = meeting.id else {
            throw MeetingServiceError.invalidRequest
        }
        let session = try authorizedSession()

        print("[MeetingService] 📝 Updating meeting: \(meeting.title)")

        var updatedMeeting = meeting
        updatedMeeting.lastUpdated = Date()

        var data = updatedMeeting.toFirestoreData()
        data["participantUserIDs"] = Self.participantUserIDs(
            organizerID: updatedMeeting.organizer,
            actingUserID: session.membership.userID,
            participants: updatedMeeting.participants
        )

        try await store.setDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: data,
            merge: false
        )

        print("[MeetingService] ✅ Meeting updated successfully")

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("MeetingUpdated"),
            object: nil,
            userInfo: ["meetingId": meetingId]
        )

        return updatedMeeting
    }

    /// Update meeting status
    func updateMeetingStatus(_ meetingId: String, status: Meeting.MeetingStatus) async throws {
        let session = try authorizedSession()

        print("[MeetingService] 📝 Updating meeting status to: \(status.rawValue)")

        var updateData: [String: Any] = [
            "status": status.rawValue,
            "lastUpdated": Timestamp(date: Date())
        ]

        if status == .completed {
            updateData["completedAt"] = Timestamp(date: Date())
        }

        try await store.updateDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: updateData
        )

        print("[MeetingService] ✅ Status updated successfully")
    }

    /// Mark meeting as completed with notes
    func completeMeeting(_ meetingId: String, notes: String?) async throws {
        let session = try authorizedSession()

        print("[MeetingService] ✅ Completing meeting")

        var updateData: [String: Any] = [
            "status": Meeting.MeetingStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date()),
            "lastUpdated": Timestamp(date: Date())
        ]

        if let notes = notes {
            updateData["notes"] = notes
        }

        try await store.updateDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: updateData
        )
    }

    // MARK: - Delete Meeting

    /// Cancel a meeting
    func cancelMeeting(_ meetingId: String) async throws {
        try await updateMeetingStatus(meetingId, status: .cancelled)

        print("[MeetingService] ❌ Meeting cancelled")

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("MeetingCancelled"),
            object: nil,
            userInfo: ["meetingId": meetingId]
        )
    }

    /// Delete a meeting permanently.
    ///
    /// `firestore.rules` denies `delete` unconditionally on
    /// `districts/{districtID}/meetings/{meetingID}` (`delete: if false`), so
    /// this call will be rejected server-side. The method is retained so
    /// callers keep compiling; use `cancelMeeting` for the supported
    /// soft-delete path instead of trying to route around the rule.
    func deleteMeeting(_ meetingId: String) async throws {
        let session = try authorizedSession()

        print("[MeetingService] 🗑️ Deleting meeting permanently")

        try await store.deleteDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId
        )

        print("[MeetingService] ✅ Meeting deleted")
    }

    // MARK: - Action Items

    /// Add an action item to a meeting
    func addActionItem(to meetingId: String, actionItem: ActionItem) async throws {
        let session = try authorizedSession()

        print("[MeetingService] ➕ Adding action item to meeting")

        try await store.updateDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: [
                "actionItems": FieldValue.arrayUnion([actionItem.toFirestoreData()]),
                "lastUpdated": Timestamp(date: Date())
            ]
        )

        print("[MeetingService] ✅ Action item added")
    }

    /// Update an action item within a meeting
    func updateActionItem(meetingId: String, actionItem: ActionItem, currentMeeting: Meeting) async throws {
        let session = try authorizedSession()

        print("[MeetingService] 📝 Updating action item")

        // Remove old version and add new version (Firestore doesn't support direct array element updates)
        var updatedMeeting = currentMeeting
        updatedMeeting.actionItems.removeAll { $0.itemId == actionItem.itemId }
        updatedMeeting.actionItems.append(actionItem)
        updatedMeeting.lastUpdated = Date()

        var data = updatedMeeting.toFirestoreData()
        data["participantUserIDs"] = Self.participantUserIDs(
            organizerID: updatedMeeting.organizer,
            actingUserID: session.membership.userID,
            participants: updatedMeeting.participants
        )

        try await store.setDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: data,
            merge: false
        )

        print("[MeetingService] ✅ Action item updated")
    }

    /// Toggle action item completion status
    func toggleActionItemCompletion(meetingId: String, actionItemId: String, currentMeeting: Meeting) async throws {
        let session = try authorizedSession()

        print("[MeetingService] ✅ Toggling action item completion")

        var updatedMeeting = currentMeeting
        if let index = updatedMeeting.actionItems.firstIndex(where: { $0.itemId == actionItemId }) {
            var actionItem = updatedMeeting.actionItems[index]
            actionItem.isCompleted.toggle()
            actionItem.completedAt = actionItem.isCompleted ? Date() : nil
            updatedMeeting.actionItems[index] = actionItem
        }
        updatedMeeting.lastUpdated = Date()

        var data = updatedMeeting.toFirestoreData()
        data["participantUserIDs"] = Self.participantUserIDs(
            organizerID: updatedMeeting.organizer,
            actingUserID: session.membership.userID,
            participants: updatedMeeting.participants
        )

        try await store.setDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: data,
            merge: false
        )

        print("[MeetingService] ✅ Action item completion toggled")
    }

    /// Delete an action item from a meeting
    func deleteActionItem(from meetingId: String, actionItemId: String, currentMeeting: Meeting) async throws {
        let session = try authorizedSession()

        print("[MeetingService] 🗑️ Deleting action item")

        var updatedMeeting = currentMeeting
        updatedMeeting.actionItems.removeAll { $0.itemId == actionItemId }
        updatedMeeting.lastUpdated = Date()

        var data = updatedMeeting.toFirestoreData()
        data["participantUserIDs"] = Self.participantUserIDs(
            organizerID: updatedMeeting.organizer,
            actingUserID: session.membership.userID,
            participants: updatedMeeting.participants
        )

        try await store.setDocument(
            atCollectionPath: FirestorePaths.meetings(districtID: session.membership.districtID),
            id: meetingId,
            data: data,
            merge: false
        )

        print("[MeetingService] ✅ Action item deleted")
    }

    /// Fetch all action items across all meetings
    func fetchAllActionItems() async throws -> [ActionItem] {
        let meetings = try await fetchMeetings()
        return meetings.flatMap { $0.actionItems }
    }

    /// Fetch action items assigned to a specific user
    func fetchActionItems(assignedTo userId: String) async throws -> [ActionItem] {
        let meetings = try await fetchMeetings()
        return meetings.flatMap { $0.actionItems }
            .filter { $0.assignedTo == userId }
    }

    /// Fetch overdue action items
    func fetchOverdueActionItems() async throws -> [ActionItem] {
        let meetings = try await fetchMeetings()
        return meetings.flatMap { $0.actionItems }
            .filter { $0.isOverdue }
    }

    // MARK: - Participant Visibility

    /// Computes the `participantUserIDs` array that satisfies the Firestore
    /// rule for `districts/{districtID}/meetings/{meetingID}`
    /// (`request.auth.uid in resource.data.participantUserIDs`).
    ///
    /// Includes the meeting's organizer, the acting user (so whoever is
    /// writing can always continue to read/update what they just wrote,
    /// even if they aren't yet listed as a participant), and every
    /// participant's user id, de-duplicated.
    private static func participantUserIDs(
        organizerID: String,
        actingUserID: String,
        participants: [MeetingParticipant]
    ) -> [String] {
        Array(Set([organizerID, actingUserID] + participants.map { $0.userId }))
    }

    // MARK: - Authorization Helpers

    private func authorizedSession() throws -> AuthenticatedSession {
        guard let session = authorizationSessions.session(
            authenticatedUserID: currentUserID()
        ) else {
            throw MeetingServiceError.userNotAuthenticated
        }
        return session
    }

    private func encode(_ meeting: Meeting) throws -> [String: Any] {
        try Firestore.Encoder().encode(meeting)
    }

    private func decodeMeeting(_ document: (id: String, data: [String: Any])) -> Meeting? {
        guard var meeting = try? Firestore.Decoder().decode(Meeting.self, from: document.data) else {
            return nil
        }
        meeting.id = document.id
        return meeting
    }
}

enum MeetingServiceError: Error, LocalizedError, Equatable {
    case userNotAuthenticated
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidRequest:
            return "Invalid meeting request"
        }
    }
}
