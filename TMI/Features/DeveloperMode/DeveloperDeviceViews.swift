#if DEBUG
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import SwiftUI

/// Inspects and resets the synthetic `district-debug` tenant that lives only on
/// this device and never touches Firestore.
struct DeveloperLocalTenantView: View {
    @State private var emails = DebugStaffAccessRegistry.registeredEmails()
    @State private var rosterSummary = Self.rosterSummary()
    @State private var didReset = false

    var body: some View {
        List {
            Section {
                LabeledContent("Invitation alias", value: DebugStaffInvitationProvisioner.invitationAlias)
                    .textSelection(.enabled)
                LabeledContent("Organization", value: DebugStaffInvitationProvisioner.districtID)
                LabeledContent("Site", value: DebugStaffInvitationProvisioner.schoolID)
                LabeledContent("Built-in account", value: DebugStaffInvitationProvisioner.allowedEmail)
            } header: {
                Text("Synthetic tenant")
            } footer: {
                Text("Any account registered with the alias is routed into this local tenant on this device instead of Firestore.")
            }

            Section("Accounts routed to the local tenant") {
                if emails.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                }
                ForEach(emails, id: \.self) { email in
                    Text(email)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                DebugStaffAccessRegistry.remove(email)
                                emails = DebugStaffAccessRegistry.registeredEmails()
                            }
                        }
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                DebugStaffAccessRegistry.remove(email)
                                emails = DebugStaffAccessRegistry.registeredEmails()
                            }
                        }
                }
            }

            Section {
                LabeledContent("Local roster", value: rosterSummary)
                Button("Reset local roster", role: .destructive) {
                    try? FileManager.default.removeItem(at: DebugStudentPersistence.standardURL)
                    rosterSummary = Self.rosterSummary()
                    didReset = true
                }
                if didReset {
                    Text("Relaunch the app to clear the roster already loaded in memory.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Stored data")
            } footer: {
                Text("Debug plans are kept in memory only and reset on relaunch.")
            }
        }
        .navigationTitle("Local debug tenant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func rosterSummary() -> String {
        let url = DebugStudentPersistence.standardURL
        guard let data = try? Data(contentsOf: url) else { return "Empty" }
        let count = (try? JSONDecoder().decode([StudentRecord].self, from: data).count) ?? 0
        let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        return "\(count) records (\(size))"
    }
}

/// Shows who the app thinks is signed in and what the server will trust. This
/// replaces ad-hoc console logging of claims and membership.
struct DeveloperSessionDiagnosticsView: View {
    @Environment(\.authStateModel) private var authStateModel
    @State private var claims: [(String, String)] = []
    @State private var tokenIssued: Date?
    @State private var appCheckStatus = "Checking…"
    @State private var isRefreshing = false

    /// Nil when Firebase isn't configured (UI-test fixtures) or signed out.
    private var user: User? {
        FirebaseApp.app() == nil ? nil : Auth.auth().currentUser
    }

    var body: some View {
        List {
            Section("Identity") {
                LabeledContent("User ID", value: user?.uid ?? "Signed out")
                    .textSelection(.enabled)
                LabeledContent("Email", value: user?.email ?? "—")
                LabeledContent("Email verified", value: (user?.isEmailVerified ?? false) ? "Yes" : "No")
                if let tokenIssued {
                    LabeledContent("Token issued", value: tokenIssued.formatted(date: .abbreviated, time: .standard))
                }
            }

            Section("Trusted claims") {
                if claims.isEmpty {
                    Text("No TMI claims on the current token.").foregroundStyle(.secondary)
                }
                ForEach(claims, id: \.0) { key, value in
                    LabeledContent(key, value: value)
                }
                Button(isRefreshing ? "Refreshing…" : "Force token refresh") {
                    Task { await load(forcingRefresh: true) }
                }
                .disabled(isRefreshing || user == nil)
            }

            Section("Membership in use") {
                if let membership = authStateModel.currentMembership {
                    LabeledContent("Organization", value: membership.districtID)
                    LabeledContent("Sites", value: membership.schoolIDs.sorted().joined(separator: ", "))
                    LabeledContent("Role", value: membership.role.displayName)
                    LabeledContent("Version", value: "\(membership.version)")
                    LabeledContent("Active", value: membership.isActive ? "Yes" : "No")
                    LabeledContent("Assigned students", value: "\(membership.assignedStudentIDs.count)")
                    ForEach(membership.capabilities.map(\.rawValue).sorted(), id: \.self) { capability in
                        Text(capability).font(.caption.monospaced())
                    }
                } else {
                    Text("No active membership.").foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("App Check", value: appCheckStatus)
            } header: {
                Text("App Check")
            } footer: {
                Text("Callables reject requests without a valid App Check token. On first launch the debug provider prints a debug token in the Xcode console; add it in Firebase console → App Check → Manage debug tokens.")
            }

            Section("Feature flags") {
                LabeledContent("Trusted mutation callables", value: FeatureFlags.production.usesTrustedMutationCallables ? "On" : "Off")
                LabeledContent("Guardian accounts", value: FeatureFlags.production.guardianAccounts ? "On" : "Off")
                LabeledContent("Independent student accounts", value: FeatureFlags.production.independentStudentAccounts ? "On" : "Off")
            }
        }
        .navigationTitle("Session diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(forcingRefresh: false) }
    }

    private func load(forcingRefresh: Bool) async {
        isRefreshing = true
        defer { isRefreshing = false }
        if FirebaseApp.app() != nil,
           let currentUser = Auth.auth().currentUser,
           let result = try? await currentUser.getIDTokenResult(forcingRefresh: forcingRefresh) {
            tokenIssued = result.issuedAtDate
            claims = result.claims
                .filter { $0.key.hasPrefix("tmi") }
                .map { ($0.key, "\($0.value)") }
                .sorted { $0.0 < $1.0 }
        }
        guard FirebaseApp.app() != nil else {
            appCheckStatus = "Firebase isn't configured in this launch mode"
            return
        }
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: false)
            appCheckStatus = "Token valid until \(token.expirationDate.formatted(date: .omitted, time: .shortened))"
        } catch {
            appCheckStatus = "Unavailable: \(error.localizedDescription)"
        }
    }
}
#endif
