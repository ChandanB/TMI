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
    static let shared = NotificationService()
    
    // State
    private(set) var notifications: [InAppNotification] = []
    private(set) var unreadCount: Int = 0
    private(set) var preferences: NotificationPreferences = NotificationPreferences()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Dependencies
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    deinit {
        Task { @MainActor in
            listenerRegistration?.remove()
        }
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
    
    func fetchNotifications() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        notifications = snapshot.documents.compactMap { doc in
            try? doc.data(as: InAppNotification.self)
        }
        
        updateUnreadCount()
    }
    
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        listenerRegistration = db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else {
                    print("[NotificationService] Listener error: \(String(describing: error))")
                    return
                }
                
                Task { @MainActor in
                    self.notifications = snapshot.documents.compactMap { doc in
                        try? doc.data(as: InAppNotification.self)
                    }
                    self.updateUnreadCount()
                }
            }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
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
        let userId = forUserId ?? Auth.auth().currentUser?.uid
        guard let userId = userId else { return }
        
        let notification = InAppNotification(
            type: type,
            title: title,
            message: message,
            actionUrl: actionUrl,
            targetId: targetId
        )
        
        try db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notification.id)
            .setData(from: notification)
        
        // Also schedule local notification if enabled
        if preferences.pushEnabled && preferences.shouldNotify(for: type) {
            await scheduleLocalNotification(notification)
        }
    }
    
    // MARK: - Marking as Read
    
    func markAsRead(_ notificationId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notificationId)
            .updateData(["isRead": true])
        
        // Update local state
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            updateUnreadCount()
        }
    }
    
    func markAllAsRead() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for notification in notifications where !notification.isRead {
            let ref = db.collection("users")
                .document(userId)
                .collection("notifications")
                .document(notification.id)
            batch.updateData(["isRead": true], forDocument: ref)
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
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        preferences = newPreferences
        
        try await db.collection("users")
            .document(userId)
            .setData(["notificationPreferences": try Firestore.Encoder().encode(newPreferences)], merge: true)
    }
    
    func loadPreferences() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let doc = try await db.collection("users").document(userId).getDocument()
        
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
                actionUrl: "tmi://plans/\(planId)",
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
    @Entry var notificationService: NotificationService = NotificationService.shared
}
