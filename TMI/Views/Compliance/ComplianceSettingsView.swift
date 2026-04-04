//
//  ComplianceSettingsView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  View for administrators to configure district compliance settings
//

import SwiftUI

struct ComplianceSettingsView: View {
    let districtId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authState

    @State private var settings: ComplianceSettings?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingSuccessAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false

    // Form state
    @State private var coppaEnabled = true
    @State private var coppaMinimumAge = 13
    @State private var ferpaEnabled = true
    @State private var requireParentalConsent = true
    @State private var consentExpirationDays: Int? = 365
    @State private var dataRetentionEnabled = true
    @State private var retentionPolicyDays = 2555
    @State private var autoDeleteEnabled = false
    @State private var auditLoggingEnabled = true
    @State private var auditRetentionDays = 2555
    @State private var logSensitiveOperations = true
    @State private var requireConsentForSurveys = true
    @State private var requireConsentForDataSharing = true
    @State private var allowDataExport = true
    @State private var allowThirdPartyIntegrations = false
    @State private var notifyOnDataAccess = false
    @State private var notifyOnDataExport = true
    @State private var notifyParentsOnMajorChanges = true

    private let complianceService = ComplianceService.shared

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else {
                settingsForm
            }
        }
        .navigationTitle("Compliance Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task { await saveSettings() }
                }
                .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        .task {
            await loadSettings()
        }
        .alert("Unsaved Changes", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Settings Saved", isPresented: $showingSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Compliance settings have been updated successfully.")
        }
    }

    // MARK: - Settings Form

    private var settingsForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header info
                headerSection

                // COPPA Compliance
                coppaSection

                // FERPA Compliance
                ferpaSection

                // Data Retention
                dataRetentionSection

                // Audit Logging
                auditLoggingSection

                // Privacy Settings
                privacySection

                // Notification Settings
                notificationSection

                // Error message
                if let errorMessage = errorMessage {
                    errorMessageView(errorMessage)
                }
            }
            .padding()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.title2)
                        .foregroundColor(.cyan)

                    Text("Compliance Configuration")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Text("Configure COPPA, FERPA, data retention, and audit logging settings for your district. These settings help ensure compliance with federal regulations.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
    }

    // MARK: - COPPA Section

    private var coppaSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "COPPA Compliance",
                    icon: "figure.and.child.holdinghands",
                    description: "Children's Online Privacy Protection Act (COPPA) requires parental consent for children under 13."
                )

                Toggle(isOn: $coppaEnabled.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable COPPA Compliance")
                            .foregroundColor(.white)
                        Text("Require parental consent for students under minimum age")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                if coppaEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Age")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        Stepper(value: $coppaMinimumAge.onChange { hasUnsavedChanges = true }, in: 10...18) {
                            Text("\(coppaMinimumAge) years")
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text("Students under this age require parental consent")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.leading)
                }
            }
            .padding()
        }
    }

    // MARK: - FERPA Section

    private var ferpaSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "FERPA Compliance",
                    icon: "doc.text.fill.badge.checkmark",
                    description: "Family Educational Rights and Privacy Act (FERPA) protects student education records."
                )

                Toggle(isOn: $ferpaEnabled.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable FERPA Compliance")
                            .foregroundColor(.white)
                        Text("Protect student education records")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                if ferpaEnabled {
                    Toggle(isOn: $requireParentalConsent.onChange { hasUnsavedChanges = true }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Require Parental Consent")
                                .foregroundColor(.white)
                            Text("Require explicit consent for data collection")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .tint(.cyan)
                    .padding(.leading)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Consent Expiration")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { consentExpirationDays != nil },
                                set: { enabled in
                                    if enabled {
                                        consentExpirationDays = 365
                                    } else {
                                        consentExpirationDays = nil
                                    }
                                    hasUnsavedChanges = true
                                }
                            ))
                            .labelsHidden()
                            .tint(.cyan)
                        }

                        if let expirationDays = consentExpirationDays {
                            Stepper(value: Binding(
                                get: { expirationDays },
                                set: { consentExpirationDays = $0; hasUnsavedChanges = true }
                            ), in: 30...1825, step: 30) {
                                Text("\(expirationDays) days (\(expirationDays / 365) year\(expirationDays / 365 == 1 ? "" : "s"))")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        Text(consentExpirationDays == nil ? "Consent never expires" : "Consent must be renewed periodically")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.leading)
                }
            }
            .padding()
        }
    }

    // MARK: - Data Retention Section

    private var dataRetentionSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Data Retention",
                    icon: "clock.arrow.circlepath",
                    description: "Automatically delete student data after a specified retention period (FERPA recommends 7 years)."
                )

                Toggle(isOn: $dataRetentionEnabled.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Data Retention Policy")
                            .foregroundColor(.white)
                        Text("Automatically manage student data lifecycle")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                if dataRetentionEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Retention Period")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        Stepper(value: $retentionPolicyDays.onChange { hasUnsavedChanges = true }, in: 365...3650, step: 365) {
                            Text("\(retentionPolicyDays) days (\(retentionPolicyDays / 365) years)")
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text("Student data will be retained for this period after graduation/exit")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.leading)

                    Toggle(isOn: $autoDeleteEnabled.onChange { hasUnsavedChanges = true }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Delete After Retention Period")
                                .foregroundColor(.white)
                            Text(autoDeleteEnabled ? "⚠️ Data will be permanently deleted" : "Data will be flagged but not deleted")
                                .font(.caption2)
                                .foregroundColor(autoDeleteEnabled ? .orange : .white.opacity(0.6))
                        }
                    }
                    .tint(.orange)
                    .padding(.leading)
                }
            }
            .padding()
        }
    }

    // MARK: - Audit Logging Section

    private var auditLoggingSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Audit Logging",
                    icon: "list.clipboard.fill",
                    description: "Track all sensitive operations for compliance and security auditing."
                )

                Toggle(isOn: $auditLoggingEnabled.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Audit Logging")
                            .foregroundColor(.white)
                        Text("Track all sensitive operations")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                if auditLoggingEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audit Log Retention")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        Stepper(value: $auditRetentionDays.onChange { hasUnsavedChanges = true }, in: 365...3650, step: 365) {
                            Text("\(auditRetentionDays) days (\(auditRetentionDays / 365) years)")
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text("Audit logs will be retained for compliance purposes")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.leading)

                    Toggle(isOn: $logSensitiveOperations.onChange { hasUnsavedChanges = true }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log Sensitive Operations")
                                .foregroundColor(.white)
                            Text("Track data exports, deletions, and access")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .tint(.cyan)
                    .padding(.leading)
                }
            }
            .padding()
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Privacy Settings",
                    icon: "hand.raised.fill",
                    description: "Control what requires explicit consent and what features are enabled."
                )

                Toggle(isOn: $requireConsentForSurveys.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Require Consent for Surveys")
                            .foregroundColor(.white)
                        Text("Students must have consent to participate in surveys")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                Toggle(isOn: $requireConsentForDataSharing.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Require Consent for Data Sharing")
                            .foregroundColor(.white)
                        Text("Explicit consent needed to share data with partners")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                Toggle(isOn: $allowDataExport.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow Data Export")
                            .foregroundColor(.white)
                        Text("Users can export their student data")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                Toggle(isOn: $allowThirdPartyIntegrations.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow Third-Party Integrations")
                            .foregroundColor(.white)
                        Text(allowThirdPartyIntegrations ? "⚠️ May share data with external services" : "Third-party integrations disabled")
                            .font(.caption2)
                            .foregroundColor(allowThirdPartyIntegrations ? .orange : .white.opacity(0.6))
                    }
                }
                .tint(.orange)
            }
            .padding()
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Notification Settings",
                    icon: "bell.fill",
                    description: "Configure when parents and guardians are notified about data operations."
                )

                Toggle(isOn: $notifyOnDataAccess.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notify on Data Access")
                            .foregroundColor(.white)
                        Text("Alert when student records are viewed")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                Toggle(isOn: $notifyOnDataExport.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notify on Data Export")
                            .foregroundColor(.white)
                        Text("Alert when student data is exported")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)

                Toggle(isOn: $notifyParentsOnMajorChanges.onChange { hasUnsavedChanges = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notify Parents on Major Changes")
                            .foregroundColor(.white)
                        Text("Alert parents when significant changes are made")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .tint(.cyan)
            }
            .padding()
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.cyan)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorMessageView(_ message: String) -> some View {
        TMIGlassCard(style: .default) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading compliance settings...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadSettings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedSettings = try await complianceService.fetchSettings(districtId: districtId)
            settings = loadedSettings

            // Populate form state
            coppaEnabled = loadedSettings?.coppaEnabled ?? coppaEnabled
            coppaMinimumAge = loadedSettings?.coppaMinimumAge ?? coppaMinimumAge
            ferpaEnabled = loadedSettings?.ferpaEnabled ?? ferpaEnabled
            requireParentalConsent = loadedSettings?.requireParentalConsent ?? requireParentalConsent
            consentExpirationDays = loadedSettings?.consentExpirationDays
            dataRetentionEnabled = loadedSettings?.dataRetentionEnabled ?? dataRetentionEnabled
            retentionPolicyDays = loadedSettings?.retentionPolicyDays ?? retentionPolicyDays
            autoDeleteEnabled = loadedSettings?.autoDeleteEnabled ?? autoDeleteEnabled
            auditLoggingEnabled = loadedSettings?.auditLoggingEnabled ?? auditLoggingEnabled
            auditRetentionDays = loadedSettings?.auditRetentionDays ?? auditRetentionDays
            logSensitiveOperations = loadedSettings?.logSensitiveOperations ?? logSensitiveOperations
            requireConsentForSurveys = loadedSettings?.requireConsentForSurveys ?? requireConsentForSurveys
            requireConsentForDataSharing = loadedSettings?.requireConsentForDataSharing ?? requireConsentForDataSharing
            allowDataExport = loadedSettings?.allowDataExport ?? allowDataExport
            allowThirdPartyIntegrations = loadedSettings?.allowThirdPartyIntegrations ?? allowThirdPartyIntegrations
            notifyOnDataAccess = loadedSettings?.notifyOnDataAccess ?? notifyOnDataAccess
            notifyOnDataExport = loadedSettings?.notifyOnDataExport ?? notifyOnDataExport
            notifyParentsOnMajorChanges = loadedSettings?.notifyParentsOnMajorChanges ?? notifyParentsOnMajorChanges

            print("[ComplianceSettingsView] ✅ Loaded settings")
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
            print("[ComplianceSettingsView] ❌ Error: \(error)")
        }
    }

    @MainActor
    private func saveSettings() async {
        guard let currentSettings = settings else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Create updated settings
        let updatedSettings = ComplianceSettings(
            id: currentSettings.id,
            districtId: districtId,
            coppaEnabled: coppaEnabled,
            coppaMinimumAge: coppaMinimumAge,
            ferpaEnabled: ferpaEnabled,
            requireParentalConsent: requireParentalConsent,
            consentExpirationDays: consentExpirationDays,
            dataRetentionEnabled: dataRetentionEnabled,
            retentionPolicyDays: retentionPolicyDays,
            autoDeleteEnabled: autoDeleteEnabled,
            auditLoggingEnabled: auditLoggingEnabled,
            auditRetentionDays: auditRetentionDays,
            logSensitiveOperations: logSensitiveOperations,
            requireConsentForSurveys: requireConsentForSurveys,
            requireConsentForDataSharing: requireConsentForDataSharing,
            allowDataExport: allowDataExport,
            allowThirdPartyIntegrations: allowThirdPartyIntegrations,
            notifyOnDataAccess: notifyOnDataAccess,
            notifyOnDataExport: notifyOnDataExport,
            notifyParentsOnMajorChanges: notifyParentsOnMajorChanges,
            createdAt: currentSettings.createdAt,
            lastUpdated: Date()
        )

        do {
            try await complianceService.updateSettings(districtId: districtId, settings: updatedSettings)
            hasUnsavedChanges = false
            showingSuccessAlert = true
            print("[ComplianceSettingsView] ✅ Settings saved")
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            print("[ComplianceSettingsView] ❌ Save error: \(error)")
        }
    }
}

// MARK: - Binding Extension for onChange

extension Binding {
    func onChange(_ handler: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler()
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComplianceSettingsView(districtId: "sample-district")
    }
}
