//
//  MeetingService.swift
//  TMI
//
//  Service for managing meetings and check-ins
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class MeetingService {
    static let shared = MeetingService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Create Meeting

    /// Schedule a new meeting
    func scheduleMeeting(_ meeting: Meeting) async throws -> Meeting {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("[MeetingService] 📅 Scheduling meeting: \(meeting.title)")

        let meetingData = meeting.toFirestoreData()

        let docRef = try await db.collection("users").document(userId)
            .collection("meetings")
            .addDocument(data: meetingData)

        print("[MeetingService] ✅ Meeting scheduled with ID: \(docRef.documentID)")

        // Post notification for calendar integration
        NotificationCenter.default.post(
            name: NSNotification.Name("MeetingScheduled"),
            object: nil,
            userInfo: ["meetingId": docRef.documentID]
        )

        // Return meeting with ID
        var savedMeeting = meeting
        savedMeeting.id = docRef.documentID
        return savedMeeting
    }

    // MARK: - Fetch Meetings

    /// Fetch all meetings for current user
    func fetchMeetings() async throws -> [Meeting] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        let snapshot = try await db.collection("users").document(userId)
            .collection("meetings")
            .order(by: "startTime", descending: false)
            .getDocuments()

        let meetings = snapshot.documents.compactMap { doc -> Meeting? in
            try? doc.data(as: Meeting.self)
        }

        print("[MeetingService] 📖 Fetched \(meetings.count) meetings")
        return meetings
    }

    /// Fetch meetings for a specific TMI Plan
    func fetchMeetings(for planId: String) async throws -> [Meeting] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        let snapshot = try await db.collection("users").document(userId)
            .collection("meetings")
            .whereField("relatedPlanId", isEqualTo: planId)
            .getDocuments()

        let meetings = snapshot.documents.compactMap { doc -> Meeting? in
            try? doc.data(as: Meeting.self)
        }

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
        guard let userId = Auth.auth().currentUser?.uid,
              let meetingId = meeting.id else {
            throw NSError(domain: "MeetingService", code: 400)
        }

        print("[MeetingService] 📝 Updating meeting: \(meeting.title)")

        var updatedMeeting = meeting
        updatedMeeting.lastUpdated = Date()

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        try await docRef.setData(updatedMeeting.toFirestoreData())

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
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] 📝 Updating meeting status to: \(status.rawValue)")

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        var updateData: [String: Any] = [
            "status": status.rawValue,
            "lastUpdated": Timestamp(date: Date())
        ]

        if status == .completed {
            updateData["completedAt"] = Timestamp(date: Date())
        }

        try await docRef.updateData(updateData)

        print("[MeetingService] ✅ Status updated successfully")
    }

    /// Mark meeting as completed with notes
    func completeMeeting(_ meetingId: String, notes: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] ✅ Completing meeting")

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        var updateData: [String: Any] = [
            "status": Meeting.MeetingStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date()),
            "lastUpdated": Timestamp(date: Date())
        ]

        if let notes = notes {
            updateData["notes"] = notes
        }

        try await docRef.updateData(updateData)
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

    /// Delete a meeting permanently
    func deleteMeeting(_ meetingId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] 🗑️ Deleting meeting permanently")

        try await db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)
            .delete()

        print("[MeetingService] ✅ Meeting deleted")
    }

    // MARK: - Action Items

    /// Add an action item to a meeting
    func addActionItem(to meetingId: String, actionItem: ActionItem) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] ➕ Adding action item to meeting")

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        try await docRef.updateData([
            "actionItems": FieldValue.arrayUnion([actionItem.toFirestoreData()]),
            "lastUpdated": Timestamp(date: Date())
        ])

        print("[MeetingService] ✅ Action item added")
    }

    /// Update an action item within a meeting
    func updateActionItem(meetingId: String, actionItem: ActionItem, currentMeeting: Meeting) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] 📝 Updating action item")

        // Remove old version and add new version (Firestore doesn't support direct array element updates)
        var updatedMeeting = currentMeeting
        updatedMeeting.actionItems.removeAll { $0.itemId == actionItem.itemId }
        updatedMeeting.actionItems.append(actionItem)
        updatedMeeting.lastUpdated = Date()

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        try await docRef.setData(updatedMeeting.toFirestoreData())

        print("[MeetingService] ✅ Action item updated")
    }

    /// Toggle action item completion status
    func toggleActionItemCompletion(meetingId: String, actionItemId: String, currentMeeting: Meeting) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] ✅ Toggling action item completion")

        var updatedMeeting = currentMeeting
        if let index = updatedMeeting.actionItems.firstIndex(where: { $0.itemId == actionItemId }) {
            var actionItem = updatedMeeting.actionItems[index]
            actionItem.isCompleted.toggle()
            actionItem.completedAt = actionItem.isCompleted ? Date() : nil
            updatedMeeting.actionItems[index] = actionItem
        }
        updatedMeeting.lastUpdated = Date()

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        try await docRef.setData(updatedMeeting.toFirestoreData())

        print("[MeetingService] ✅ Action item completion toggled")
    }

    /// Delete an action item from a meeting
    func deleteActionItem(from meetingId: String, actionItemId: String, currentMeeting: Meeting) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        print("[MeetingService] 🗑️ Deleting action item")

        var updatedMeeting = currentMeeting
        updatedMeeting.actionItems.removeAll { $0.itemId == actionItemId }
        updatedMeeting.lastUpdated = Date()

        let docRef = db.collection("users").document(userId)
            .collection("meetings")
            .document(meetingId)

        try await docRef.setData(updatedMeeting.toFirestoreData())

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
}
