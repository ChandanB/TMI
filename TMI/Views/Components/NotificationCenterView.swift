//
//  NotificationCenterView.swift
//  TMI
//
//  Notification center UI for viewing and managing in-app notifications
//  Created for Phase 3: Polish & Reporting
//

import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.notificationService) private var notificationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let notificationService {
                    if notificationService.notifications.isEmpty {
                        emptyState
                    } else {
                        ForEach(notificationService.notifications) { notification in
                            NotificationRow(notification: notification)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            try? await notificationService.markAsRead(notification.id)
                                        }
                                    } label: {
                                        Label("Mark Read", systemImage: "checkmark.circle")
                                    }
                                }
                        }
                    }
                } else {
                    unavailableState
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if let notificationService,
                       !notificationService.notifications.isEmpty,
                       notificationService.unreadCount > 0 {
                        Button("Mark All Read") {
                            Task {
                                try? await notificationService.markAllAsRead()
                            }
                        }
                    }
                }
            }
            .task {
                guard let notificationService = self.notificationService else {
                    return
                }
                try? await notificationService.fetchNotifications()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: TMISpacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.tmiTextTertiary)
            
            Text("No Notifications")
                .font(.tmiHeading2)
                .foregroundColor(.tmiTextSecondary)
            
            Text("You're all caught up!")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }

    private var unavailableState: some View {
        ContentUnavailableView(
            "Notifications Unavailable",
            systemImage: "bell.slash",
            description: Text("Notification services are not configured for this view.")
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: InAppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: TMISpacing.md) {
            // Icon
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.tmiBody.weight(notification.isRead ? .regular : .semibold))
                        .foregroundColor(.tmiTextPrimary)
                    
                    Spacer()
                    
                    Text(notification.timestamp.timeAgo)
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextTertiary)
                }
                
                Text(notification.message)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(2)
            }
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.tmiPrimary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, TMISpacing.xs)
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    private var iconColor: Color {
        switch notification.type.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - Notification Badge

struct NotificationBadge: View {
    @Environment(\.notificationService) private var notificationService
    
    var body: some View {
        if let unreadCount = notificationService?.unreadCount, unreadCount > 0 {
            Text("\(min(unreadCount, 99))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.tmiTextPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    @Environment(\.notificationService) private var notificationService
    @State private var showingNotifications = false
    
    var body: some View {
        Button {
            showingNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.tmiTextPrimary)
                
                if let unreadCount = notificationService?.unreadCount, unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Text("\(min(unreadCount, 9))")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.tmiTextPrimary)
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .disabled(notificationService == nil)
        .sheet(isPresented: $showingNotifications) {
            NotificationCenterView()
                .tmiSheetStyle()
        }
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @Environment(\.notificationService) private var notificationService
    @State private var preferences: NotificationPreferences = NotificationPreferences()
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Push Notifications", isOn: $preferences.pushEnabled)
                Toggle("In-App Notifications", isOn: $preferences.inAppEnabled)
            } header: {
                Text("General")
            }
            
            Section {
                Toggle("Plan Approvals & Updates", isOn: $preferences.planApprovals)
                Toggle("Student Alerts", isOn: $preferences.studentAlerts)
                Toggle("Meeting Reminders", isOn: $preferences.meetingReminders)
                Toggle("Survey Updates", isOn: $preferences.surveyUpdates)
                Toggle("Resource Recommendations", isOn: $preferences.resourceRecommendations)
            } header: {
                Text("Notification Types")
            }
            
            Section {
                Toggle("Enable Quiet Hours", isOn: $preferences.quietHoursEnabled)
                
                if preferences.quietHoursEnabled {
                    DatePicker("Start Time", selection: $preferences.quietHoursStart, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $preferences.quietHoursEnd, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Quiet Hours")
            } footer: {
                Text("During quiet hours, notifications will be silently delivered without alerts.")
            }
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(notificationService == nil)
        .onAppear {
            guard let notificationService = self.notificationService else {
                return
            }
            preferences = notificationService.preferences
        }
        .onChange(of: preferences.inAppEnabled) { _, _ in
            guard let notificationService = self.notificationService else {
                return
            }
            Task {
                isSaving = true
                try? await notificationService.updatePreferences(preferences)
                isSaving = false
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NotificationCenterView()
}
