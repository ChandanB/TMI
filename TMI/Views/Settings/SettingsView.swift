//
//  SettingsView.swift
//  TMI
//
//  Created by Chandan Brown on 9/10/24.
//
//  Settings view with role-based sections.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.authStateModel) private var authStateModel
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showAnimations") private var showAnimations = true
    @AppStorage("dataBackupEnabled") private var dataBackupEnabled = true
    @AppStorage("offlineModeEnabled") private var offlineModeEnabled = true
    
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var isLoggedOut = false
    @State private var isLoaded = false
    
    // Role-based visibility
    private var currentRole: UserRole? {
        authStateModel.currentUser?.role
    }
    
    private var isDistrictAdmin: Bool {
        currentRole?.isDistrictRole ?? false
    }
    
    private var isStudent: Bool {
        currentRole == .student
    }
    
    private var isParent: Bool {
        currentRole == .parent || currentRole == .legalGuardian
    }
    
    var body: some View {
        ZStack {
            // Background
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isLoaded)
                    
                    VStack(spacing: 16) {
                        // Account Section - visible to all
                        accountSection
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: isLoaded)
                        
                        
                        // District admin-only sections
                        if isDistrictAdmin {
                            districtAdminSection
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: isLoaded)
                        }
                        
                        // Student-only sections
                        if isStudent {
                            studentSettingsSection
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: isLoaded)
                        }
                        
                        // Parent-only sections
                        if isParent {
                            parentSettingsSection
                                .opacity(isLoaded ? 1 : 0)
                                .offset(y: isLoaded ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: isLoaded)
                        }
                        
                        
                        // Account Actions Section - visible to all
                        dangerousActionsSection
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: isLoaded)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                isLoaded = true
            }
        }
    }
    
    // MARK: - Role-Specific Sections

    private var districtAdminSection: some View {
        settingsSectionCard(title: "District Administration", icon: "building.2") {
            VStack(spacing: 0) {
                settingsRow(icon: "checkmark.seal", title: "Compliance Settings") {
                    // Compliance configuration
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                settingsRow(icon: "doc.text.magnifyingglass", title: "Audit Configuration") {
                    // Audit settings
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                settingsRow(icon: "person.2.badge.gearshape", title: "Staff Management") {
                    // Staff management
                }
            }
        }
    }
    
    private var studentSettingsSection: some View {
        settingsSectionCard(title: "My Settings", icon: "person.circle") {
            VStack(spacing: 0) {
                settingsRow(icon: "heart", title: "Interest Preferences") {
                    // Interest preferences
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                settingsRow(icon: "lock.shield", title: "Privacy Settings") {
                    // Privacy settings
                }
            }
        }
    }
    
    private var parentSettingsSection: some View {
        settingsSectionCard(title: "Parent Settings", icon: "person.2") {
            VStack(spacing: 0) {
                settingsRow(icon: "bell", title: "Progress Notifications") {
                    // Progress notification settings
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                settingsRow(icon: "doc.text", title: "Consent Management") {
                    // Consent management
                }
            }
        }
    }
    
    
    // MARK: - Helper Views
    
    private func settingsSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.tmiPrimary)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            content()
                .background(Color.tmiSurface.opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color.tmiSurface)
        .cornerRadius(16)
    }
    
    private func settingsRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder destination: () -> Content
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.tmiTextSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tmiTextTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                logOut()
            }
        } message: {
            Text("Are you sure you want to log out? Your data will remain safe and you can sign back in anytime.")
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $isLoggedOut) {
            AuthenticationView()
        }
        .sheet(isPresented: $showingExportSheet) {
            DataExportView()
        }
        .sheet(isPresented: $showingImportSheet) {
            DataImportView()
        }
    }
}

// MARK: - Header View

private var headerView: some View {
    TMIGlassCard(style: .default) {
        HStack(spacing: 16) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(Color.tmiSecondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                if let user = Auth.auth().currentUser,
                   let name = user.displayName,
                   !name.isEmpty {
                    Text(String(name.prefix(1).uppercased()))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.tmiSecondary)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.tmiSecondary)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                if let user = Auth.auth().currentUser {
                    Text(user.displayName ?? "TMI Educator")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(user.email ?? "Not available")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("TMI Professional")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.tmiSecondary.opacity(0.2))
                    )
                    .foregroundColor(.tmiSecondary)
            }
            
            Spacer()
            
            NavigationLink(destination: UserProfileView()) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Settings Sections

private var accountSection: some View {
    SettingsSection(title: "Account", icon: "person.circle.fill") {
        SettingsRow(
            title: "Edit Profile",
            subtitle: "Update your personal information",
            icon: "person.badge.plus",
            action: {
                // Navigate to profile editing
            }
        )
        
        //      SettingsRow(
        //        title: "Notification Preferences",
        //        subtitle: "Manage your notification settings",
        //        icon: "bell.badge",
        //        action: {
        //          // Navigate to notification settings
        //        }
        //      )
    }
}

extension SettingsView {
    private var tmiSettingsSection: some View {
        SettingsSection(title: "TMI Settings", icon: "brain.head.profile") {
            SettingsToggleRow(
                title: "Offline Mode",
                subtitle: "Work without internet connection",
                icon: "wifi.slash",
                isOn: $offlineModeEnabled
            )
            
            SettingsToggleRow(
                title: "Auto Backup",
                subtitle: "Automatically sync data to cloud",
                icon: "cloud.fill",
                isOn: $dataBackupEnabled
            )
            
            SettingsRow(
                title: "Default TMI Models",
                subtitle: "Choose preferred intervention models",
                icon: "slider.horizontal.3",
                action: {
                    // Navigate to model preferences
                }
            )
        }
    }

    private var appPreferencesSection: some View {
        SettingsSection(title: "App Preferences", icon: "gear") {
            SettingsToggleRow(
                title: "Dark Mode",
                subtitle: "Use dark interface theme",
                icon: "moon.fill",
                isOn: $darkModeEnabled
            )
            
            SettingsToggleRow(
                title: "Enable Animations",
                subtitle: "Show interface animations",
                icon: "sparkles",
                isOn: $showAnimations
            )
            
            SettingsToggleRow(
                title: "Push Notifications",
                subtitle: "Receive important updates",
                icon: "bell.fill",
                isOn: $notificationsEnabled
            )
        }
    }

    private var dataManagementSection: some View {
        SettingsSection(title: "Data Management", icon: "folder.fill") {
            SettingsRow(
                title: "Export Data",
                subtitle: "Download your TMI data",
                icon: "square.and.arrow.up.fill",
                action: {
                    showingExportSheet = true
                }
            )
            
            SettingsRow(
                title: "Import Data",
                subtitle: "Upload data from other sources",
                icon: "square.and.arrow.down.fill",
                action: {
                    showingImportSheet = true
                }
            )
            
            SettingsRow(
                title: "Clear Cache",
                subtitle: "Free up storage space",
                icon: "trash.fill",
                action: {
                    clearCache()
                }
            )
        }
    }


    private var dangerousActionsSection: some View {
        SettingsSection(title: "Account Actions", icon: "exclamationmark.triangle.fill") {
            SettingsRow(
                title: "Log Out",
                subtitle: "Sign out of your account",
                icon: "rectangle.portrait.and.arrow.right",
                titleColor: .orange,
                action: {
                    showingLogoutAlert = true
                }
            )
            
            SettingsRow(
                title: "Delete Account",
                subtitle: "Permanently remove your account",
                icon: "person.crop.circle.badge.xmark",
                titleColor: .red,
                action: {
                    showingDeleteAlert = true
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func logOut() {
        do {
            try FIREBASE_MANAGER.signOut()
            isLoggedOut = true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    private func deleteAccount() {
        Task {
            do {
                // Delete user data from Firestore
                if let user = Auth.auth().currentUser {
                    let db = Firestore.firestore()
                    let userDoc = db.collection("users").document(user.uid)
                    
                    // Delete all user subcollections
                    let collections = ["students", "tmiPlans", "interests", "hobbies", "resources", "forms"]
                    for collection in collections {
                        let snapshot = try await userDoc.collection(collection).getDocuments()
                        for document in snapshot.documents {
                            try await document.reference.delete()
                        }
                    }
                    
                    // Delete user document
                    try await userDoc.delete()
                    
                    // Delete Firebase Auth account
                    try await user.delete()
                    
                    // Navigate to authentication
                    await MainActor.run {
                        isLoggedOut = true
                    }
                }
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
                // Could show an alert here for user feedback
            }
        }
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
            try await FIREBASE_MANAGER.firestore.clearPersistence()
            
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
                    .font(.system(size: 16))
                    .foregroundColor(.tmiSecondary)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            TMIGlassCard(style: .default) {
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
        titleColor: Color = .white,
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
                    .font(.system(size: 18))
                    .foregroundColor(.tmiSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(titleColor)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                Color.white.opacity(isPressed ? 0.1 : 0)
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
                .font(.system(size: 18))
                .foregroundColor(.tmiSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
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
