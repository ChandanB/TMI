//
//  NotificationService.swift
//  TMI
//
//  Notification infrastructure for in-app and local notifications
//  Created for Phase 3: Polish & Reporting
//

import Foundation
import UserNotifications
import Observation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - In-App Notification Model

struct InAppNotification: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let actionUrl: String?
    let targetId: String?
    
    enum NotificationType: String, Codable, Sendable {
        case planApproval = "plan_approval"
        case planUpdate = "plan_update"
        case studentAlert = "student_alert"
        case meetingReminder = "meeting_reminder"
        case surveyComplete = "survey_complete"
        case resourceAdded = "resource_added"
        case systemMessage = "system_message"
        
        var icon: String {
            switch self {
            case .planApproval: return "checkmark.circle.badge.questionmark"
            case .planUpdate: return "doc.badge.arrow.up"
            case .studentAlert: return "exclamationmark.triangle.fill"
            case .meetingReminder: return "calendar.badge.clock"
            case .surveyComplete: return "list.clipboard.fill"
            case .resourceAdded: return "book.pages.fill"
            case .systemMessage: return "bell.fill"
            }
        }
        
        var color: String {
            switch self {
            case .planApproval: return "blue"
            case .planUpdate: return "green"
            case .studentAlert: return "red"
            case .meetingReminder: return "purple"
            case .surveyComplete: return "orange"
            case .resourceAdded: return "teal"
            case .systemMessage: return "gray"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        message: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        actionUrl: String? = nil,
        targetId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.actionUrl = actionUrl
        self.targetId = targetId
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable, Sendable {
    var pushEnabled: Bool = true
    var inAppEnabled: Bool = true
    var planApprovals: Bool = true
    var studentAlerts: Bool = true
    var meetingReminders: Bool = true
    var surveyUpdates: Bool = true
    var resourceRecommendations: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    
    func shouldNotify(for type: InAppNotification.NotificationType) -> Bool {
        guard inAppEnabled else { return false }
        
        switch type {
        case .planApproval, .planUpdate:
            return planApprovals
        case .studentAlert:
            return studentAlerts
        case .meetingReminder:
            return meetingReminders
        case .surveyComplete:
            return surveyUpdates
        case .resourceAdded:
            return resourceRecommendations
        case .systemMessage:
            return true // Always show system messages
        }
    }
}

// MARK: - Notification Service

@Observable
@MainActor
class NotificationService {
    enum ServiceError: Error {
        case unauthorized
        case unavailable
        case serverManaged
    }

    static let shared = NotificationService()
    
    // State
    private(set) var notifications: [InAppNotification] = []
    private(set) var unreadCount: Int = 0
    private(set) var preferences: NotificationPreferences = NotificationPreferences()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Dependencies
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var activeMembership: MembershipContext?
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    isolated deinit {
        listenerRegistration?.remove()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("[NotificationService] Authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    // MARK: - Fetching Notifications
    
    func fetchNotifications(member: MembershipContext) async throws {
        try authorize(member)
        activeMembership = member

        if isLocalDebugMembership(member) {
            notifications = []
            updateUnreadCount()
            return
        }

        let snapshot = try await notificationCollection(member: member)
            .whereField("recipientUserID", isEqualTo: member.userID)
            .limit(to: 50)
            .getDocuments()

        guard activeMembership == member else { return }
        notifications = decodedNotifications(snapshot)
        updateUnreadCount()
    }

    func fetchNotifications() async throws {
        guard let activeMembership else {
            throw ServiceError.unavailable
        }
        try await fetchNotifications(member: activeMembership)
    }

    func startListening(member: MembershipContext) {
        stopListening()
        guard (try? authorize(member)) != nil else {
            return
        }
        activeMembership = member

        if isLocalDebugMembership(member) {
            notifications = []
            updateUnreadCount()
            return
        }

        listenerRegistration = notificationCollection(member: member)
            .whereField("recipientUserID", isEqualTo: member.userID)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    Log.firebase.warning(
                        "notification_listener_failed",
                        metadata: ["error": error?.localizedDescription ?? "unknown"]
                    )
                    return
                }

                Task { @MainActor in
                    guard self.activeMembership == member else { return }
                    self.notifications = self.decodedNotifications(snapshot)
                    self.updateUnreadCount()
                }
            }
    }

    private func decodedNotifications(_ snapshot: QuerySnapshot) -> [InAppNotification] {
        snapshot.documents
            .compactMap { document in
                try? document.data(as: InAppNotification.self)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func notificationCollection(member: MembershipContext) -> CollectionReference {
        db.collection(FirestorePaths.notifications(districtID: member.districtID))
    }

    private func authorize(_ member: MembershipContext) throws {
        guard member.isActive,
              member.version > 0,
              TrustedIdentifier.isValid(member.districtID),
              TrustedIdentifier.isValid(member.userID),
              Auth.auth().currentUser?.uid == member.userID else {
            throw ServiceError.unauthorized
        }
    }

    private func isLocalDebugMembership(_ member: MembershipContext) -> Bool {
#if DEBUG
        DebugPlanRepository.isDebug(member)
#else
        false
#endif
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        activeMembership = nil
        clearNotificationState()
    }

    private func clearNotificationState() {
        notifications = []
        unreadCount = 0
    }

    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Creating Notifications
    
    func createNotification(
        type: InAppNotification.NotificationType,
        title: String,
        message: String,
        actionUrl: String? = nil,
        targetId: String? = nil,
        forUserId: String? = nil
    ) async throws {
        // Canonical notification records are institution-owned and server-created.
        // Client writes are deliberately denied by firestore.rules.
        throw ServiceError.serverManaged
    }
    
    // MARK: - Marking as Read
    
    func markAsRead(_ notificationId: String) async throws {
        guard let member = activeMembership else {
            throw ServiceError.unavailable
        }
        try authorize(member)
        guard !isLocalDebugMembership(member) else { return }

        try await notificationCollection(member: member)
            .document(notificationId)
            .updateData([
                "isRead": true,
                "readAt": FieldValue.serverTimestamp(),
            ])
        
        // Update local state
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            updateUnreadCount()
        }
    }
    
    func markAllAsRead() async throws {
        guard let member = activeMembership else {
            throw ServiceError.unavailable
        }
        try authorize(member)
        guard !isLocalDebugMembership(member) else { return }
        
        let batch = db.batch()
        
        for notification in notifications where !notification.isRead {
            let ref = notificationCollection(member: member)
                .document(notification.id)
            batch.updateData(
                [
                    "isRead": true,
                    "readAt": FieldValue.serverTimestamp(),
                ],
                forDocument: ref
            )
        }
        
        try await batch.commit()
        
        // Update local state
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        updateUnreadCount()
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(_ notification: InAppNotification) async {
        guard authorizationStatus == .authorized else { return }
        
        // Check quiet hours
        if preferences.quietHoursEnabled && isInQuietHours() {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)
        
        // Add category for actions
        content.categoryIdentifier = notification.type.rawValue
        
        // Immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NotificationService] Local notification scheduled: \(notification.title)")
        } catch {
            print("[NotificationService] Failed to schedule notification: \(error)")
        }
    }
    
    func scheduleMeetingReminder(meetingId: String, title: String, date: Date, reminderMinutes: Int = 15) async {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Meeting Reminder"
        content.body = "\(title) starts in \(reminderMinutes) minutes"
        content.sound = .default
        content.categoryIdentifier = InAppNotification.NotificationType.meetingReminder.rawValue
        
        let triggerDate = date.addingTimeInterval(TimeInterval(-reminderMinutes * 60))
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "meeting_\(meetingId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NotificationService] Meeting reminder scheduled for \(triggerDate)")
        } catch {
            print("[NotificationService] Failed to schedule meeting reminder: \(error)")
        }
    }
    
    func cancelNotification(_ identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Preferences
    
    func updatePreferences(_ newPreferences: NotificationPreferences) async throws {
        guard let member = activeMembership else {
            throw ServiceError.unavailable
        }
        try authorize(member)
        preferences = newPreferences
        guard !isLocalDebugMembership(member) else { return }

        try await db.document(FirestorePaths.preferences(userID: member.userID))
            .setData(
                ["notificationPreferences": try Firestore.Encoder().encode(newPreferences)],
                merge: true
            )
    }
    
    func loadPreferences() async throws {
        guard let member = activeMembership else {
            throw ServiceError.unavailable
        }
        try authorize(member)
        guard !isLocalDebugMembership(member) else { return }

        let doc = try await db.document(
            FirestorePaths.preferences(userID: member.userID)
        ).getDocument()
        
        if let data = doc.data()?["notificationPreferences"] as? [String: Any],
           let prefsData = try? JSONSerialization.data(withJSONObject: data),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: prefsData) {
            preferences = prefs
        }
    }
    
    private func isInQuietHours() -> Bool {
        guard preferences.quietHoursEnabled else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTime = currentHour * 60 + currentMinute
        
        let startHour = calendar.component(.hour, from: preferences.quietHoursStart)
        let startMinute = calendar.component(.minute, from: preferences.quietHoursStart)
        let startTime = startHour * 60 + startMinute
        
        let endHour = calendar.component(.hour, from: preferences.quietHoursEnd)
        let endMinute = calendar.component(.minute, from: preferences.quietHoursEnd)
        let endTime = endHour * 60 + endMinute
        
        if startTime < endTime {
            // Normal case: e.g., 22:00 to 07:00 next day
            return currentTime >= startTime || currentTime < endTime
        } else {
            // Overnight case
            return currentTime >= startTime || currentTime < endTime
        }
    }
    
    // MARK: - Convenience Methods for Common Notifications
    
    func notifyPlanApprovalNeeded(planId: String, planTitle: String, studentName: String, approverId: String) async {
        do {
            try await createNotification(
                type: .planApproval,
                title: "Plan Needs Approval",
                message: "TMI Plan for \(studentName) is ready for your review",
                actionUrl: nil,
                targetId: planId,
                forUserId: approverId
            )
        } catch {
            print("[NotificationService] Failed to create plan approval notification: \(error)")
        }
    }
    
    func notifyStudentAlert(studentId: String, studentName: String, alertMessage: String, counselorId: String) async {
        do {
            try await createNotification(
                type: .studentAlert,
                title: "Student Alert",
                message: "\(studentName): \(alertMessage)",
                actionUrl: "tmi://students/\(studentId)",
                targetId: studentId,
                forUserId: counselorId
            )
        } catch {
            print("[NotificationService] Failed to create student alert notification: \(error)")
        }
    }
    
    func notifySurveyComplete(studentId: String, studentName: String, teacherId: String) async {
        do {
            try await createNotification(
                type: .surveyComplete,
                title: "Survey Completed",
                message: "\(studentName) has completed their interest survey",
                actionUrl: "tmi://students/\(studentId)",
                targetId: studentId,
                forUserId: teacherId
            )
        } catch {
            print("[NotificationService] Failed to create survey complete notification: \(error)")
        }
    }
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var notificationService: NotificationService? = nil
}
