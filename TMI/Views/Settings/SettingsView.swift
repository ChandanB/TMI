//
//  SettingsView.swift
//  TMI
//
//  Created by Chandan Brown on 9/10/24.
//
//  Settings view with role-based sections.
//

import FirebaseAuth
import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(AppRouter.self) private var router

    @State private var showingLogoutAlert = false
    @State private var showingSignOutFailure = false
    @State private var showingDeleteAccountSheet = false

    // Role-based visibility
    private var currentMembership: MembershipContext? {
        authStateModel.currentMembership
    }

    private var isDistrictAdmin: Bool {
        guard let currentMembership else { return false }
        return AuthorizationPolicy.canViewAggregate(
            currentMembership,
            districtID: currentMembership.districtID
        )
    }

    private var canManageStaff: Bool {
        currentMembership.map(AuthorizationPolicy.canManageStaff) ?? false
    }

    private var canReadAudit: Bool {
        currentMembership.map(AuthorizationPolicy.canReadAudit) ?? false
    }

    var body: some View {
        Form {
            Section {
                Button {
                    try? router.open(.profile)
                } label: {
                    HStack(spacing: TMISpacing.ms) {
                        TMIAvatar(initials: initials, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authStateModel.currentUser?.displayName ?? "Your account")
                                .font(.headline)
                                .foregroundStyle(TMIColors.textPrimary)
                            Text(currentMembership?.role.displayName ?? "Staff")
                                .font(.subheadline)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TMIColors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your profile")
            }

            // Administration: compliance for district admins, staff for
            // staff.manage, audit for audit.read.
            if isDistrictAdmin || canManageStaff || canReadAudit {
                Section("Administration") {
                    if canManageStaff, let currentMembership {
                        NavigationLink {
                            StaffAdministrationView(member: currentMembership)
                        } label: {
                            settingsLabel("Staff Management", symbol: "person.2.badge.gearshape", tone: .info)
                        }
                        .accessibilityIdentifier("settings.staffManagement")
                    }
                    if canReadAudit, let currentMembership {
                        NavigationLink {
                            AuditLogView(member: currentMembership)
                        } label: {
                            settingsLabel("Audit Log", symbol: "doc.text.magnifyingglass", tone: .neutral)
                        }
                        .accessibilityIdentifier("settings.auditLog")
                    }
                    if isDistrictAdmin, let currentMembership {
                        NavigationLink {
                            ComplianceSettingsView(districtId: currentMembership.districtID)
                        } label: {
                            settingsLabel("Compliance Settings", symbol: "checkmark.seal", tone: .success)
                        }
                        NavigationLink {
                            ConsentManagementView()
                        } label: {
                            settingsLabel("Consent Management", symbol: "person.text.rectangle", tone: .brand)
                        }
                    }
                }
            }

            if currentMembership != nil {
                // Value links: destinations are built only when opened (the
                // eager form constructed every screen's services on render).
                Section("Forms & meetings") {
                    NavigationLink(value: AppRoute.formTemplates) {
                        settingsLabel("Form Templates", symbol: "doc.on.doc", tone: .brand)
                    }
                    NavigationLink(value: AppRoute.formAssignments) {
                        settingsLabel("Form Assignments", symbol: "list.bullet.rectangle", tone: .brand)
                    }
                    NavigationLink(value: AppRoute.meetings) {
                        settingsLabel("Meetings", symbol: "calendar", tone: .success)
                    }
                }
            }

            Section("Data") {
                NavigationLink {
                    SyncStatusView()
                } label: {
                    settingsLabel("Sync Status", symbol: "arrow.triangle.2.circlepath", tone: .info)
                }
            }

#if DEBUG
            Section("Developer") {
                NavigationLink {
                    DeveloperModeView()
                } label: {
                    settingsLabel("Developer Mode", symbol: "wrench.and.screwdriver", tone: .neutral)
                }
            }
            .accessibilityIdentifier("settings.developerMode")
#endif

            Section {
                Button(role: .destructive) {
                    showingLogoutAlert = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                Button(role: .destructive) {
                    showingDeleteAccountSheet = true
                } label: {
                    Label("Delete Account…", systemImage: "person.crop.circle.badge.minus")
                }
            } footer: {
                Text("Deleting your account removes your personal data. District records stay with the district.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .tmiScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDeleteAccountSheet) {
            DeleteAccountView()
                .tmiSheetStyle()
        }
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                attemptSignOut()
            }
        } message: {
            Text("Are you sure you want to log out? Your data will remain safe and you can sign back in anytime.")
        }
        .alert("Couldn’t Sign Out", isPresented: $showingSignOutFailure) {
            Button("Retry", action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your account is still signed in. Check your connection and try again.")
        }
    }

    // MARK: - Role-Specific Sections

    private func settingsLabel(_ title: String, symbol: String, tone: TMITone) -> some View {
        HStack(spacing: TMISpacing.ms) {
            TMIIconTile(symbol, tone: tone, size: 28)
            Text(title)
                .foregroundStyle(TMIColors.textPrimary)
        }
    }

    private var initials: String {
        (authStateModel.currentUser?.displayName ?? "")
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    @MainActor
    private func attemptSignOut() {
        guard authStateModel.signOut() else {
            showingSignOutFailure = true
            return
        }
        studentContext.clearContext()
        router.reset()
    }
}

private func clearCache() {
    Task {
        do {
            // Clear URLCache
            URLCache.shared.removeAllCachedResponses()
            
            // Clear UserDefaults cache keys
            let cacheKeys = ["lastSyncDate", "cachedUserProfile", "tempImageCache", "formDrafts"]
            for key in cacheKeys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            // Clear temporary files
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempContents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for url in tempContents {
                if url.pathExtension == "tmp" || url.lastPathComponent.hasPrefix("TMI_") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            // Clear Firebase offline cache
            try await FirebaseManager.shared.firestore.clearPersistence()
            
            await MainActor.run {
                // Could show success feedback
                print("Cache cleared successfully")
            }
        } catch {
            print("Error clearing cache: \(error.localizedDescription)")
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.tmiSecondary)
                
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.tmiTextPrimary)
            }
            .padding(.horizontal, 4)
            
            TMICard(style: .default) {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let titleColor: Color
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        titleColor: Color = TMIColors.textPrimary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.titleColor = titleColor
        self.action = action
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.tmiSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(titleColor)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color.tmiTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                TMIColors.fill.opacity(isPressed ? 1 : 0)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onTouchDownGesture { isPressed = true }
        .onTouchUpGesture { isPressed = false }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.tmiSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.tmiTextPrimary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.tmiSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Touch Gesture Extensions

extension View {
    func onTouchDownGesture(perform action: @escaping () -> Void) -> some View {
        self.onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                action()
            }
        }, perform: {})
    }
    
    func onTouchUpGesture(perform action: @escaping () -> Void) -> some View {
        self.onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !pressing {
                action()
            }
        }, perform: {})
    }
}

#Preview {
    SettingsView()
}
