#if DEBUG
import SwiftUI

struct DeveloperInvitationsView: View {
    let state: DeveloperModeState
    @State private var districtFilter: String?
    @State private var statusFilter: DevInvitationStatus?
    @State private var isCreating = false
    @State private var pendingDelete: DevInvitation?

    private var visibleInvitations: [DevInvitation] {
        state.invitations.filter { statusFilter == nil || $0.status == statusFilter }
    }

    var body: some View {
        List {
            Section {
                Picker("Organization", selection: $districtFilter) {
                    Text("All organizations").tag(String?.none)
                    ForEach(state.tenants) { tenant in
                        Text(tenant.name).tag(String?.some(tenant.districtID))
                    }
                }
                Picker("Status", selection: $statusFilter) {
                    Text("Any status").tag(DevInvitationStatus?.none)
                    ForEach(DevInvitationStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(DevInvitationStatus?.some(status))
                    }
                }
            }

            Section {
                if visibleInvitations.isEmpty {
                    Text(state.isWorking ? "Loading…" : "No invitations match.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleInvitations) { invitation in
                    DeveloperInvitationRow(state: state, invitation: invitation)
                        .swipeActions(edge: .trailing) {
                            if invitation.status.canDelete {
                                Button(role: .destructive) {
                                    pendingDelete = invitation
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if invitation.status.canRevoke {
                                Button {
                                    Task { await state.revoke(invitation, filter: districtFilter) }
                                } label: {
                                    Label("Revoke", systemImage: "nosign")
                                }
                                .tint(TMIColors.warningText)
                            }
                        }
                        .contextMenu {
                            if invitation.status.canRevoke {
                                Button("Revoke", systemImage: "nosign") {
                                    Task { await state.revoke(invitation, filter: districtFilter) }
                                }
                            }
                            if invitation.status.canDelete {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDelete = invitation
                                }
                            }
                        }
                }
            } header: {
                Text("\(visibleInvitations.count) invitations")
            } footer: {
                Text("Codes are single-use, bound to one recipient email, and shown only once when created. Revoke keeps the record; delete removes revoked or expired, unused codes.")
            }
        }
        .navigationTitle("Invitation codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New invitation", systemImage: "plus")
                }
                .disabled(state.tenants.isEmpty)
            }
        }
        .task(id: districtFilter) {
            await state.loadInvitations(districtID: districtFilter)
        }
        .refreshable { await state.loadInvitations(districtID: districtFilter) }
        .sheet(isPresented: $isCreating) {
            DeveloperInvitationEditor(
                state: state,
                districtFilter: districtFilter,
                initialDistrictID: districtFilter ?? state.tenants.first?.districtID ?? ""
            )
        }
        .confirmationDialog(
            "Delete this invitation?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { invitation in
            Button("Delete", role: .destructive) {
                Task { await state.delete(invitation, filter: districtFilter) }
            }
        } message: { invitation in
            Text("Invitation \(invitation.shortID) will be removed permanently. Its audit events remain.")
        }
        .developerErrorAlert(state)
    }
}

private struct DeveloperInvitationRow: View {
    let state: DeveloperModeState
    let invitation: DevInvitation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(invitation.label ?? invitation.role.displayName)
                    .font(.headline)
                Spacer()
                DeveloperBadge(text: invitation.status.displayName, tone: invitation.status.badgeTone)
            }
            Text("\(invitation.role.displayName) · \(state.tenant(invitation.districtID)?.name ?? invitation.districtID)")
                .font(.subheadline)
            if !invitation.schoolIDs.isEmpty {
                Text(invitation.schoolIDs.map { state.schoolName($0, in: invitation.districtID) }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Group {
                switch invitation.status {
                case .consumed:
                    Text("Redeemed \(DeveloperDates.display(invitation.consumedAt)) by \(invitation.consumedByUserID ?? "?")")
                case .revoked:
                    Text("Revoked \(DeveloperDates.display(invitation.revokedAt))")
                case .active, .expired:
                    Text("Expires \(DeveloperDates.display(invitation.expiresAt))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("ID \(invitation.shortID) · created \(DeveloperDates.display(invitation.createdAt))")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct DeveloperInvitationEditor: View {
    let state: DeveloperModeState
    let districtFilter: String?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DevInvitationDraft

    init(state: DeveloperModeState, districtFilter: String?, initialDistrictID: String) {
        self.state = state
        self.districtFilter = districtFilter
        let schools = state.tenant(initialDistrictID)?.schools.prefix(1).map(\.schoolID) ?? []
        _draft = State(initialValue: .defaults(districtID: initialDistrictID, schoolIDs: schools))
    }

    private var tenant: DevTenant? { state.tenant(draft.districtID) }

    private var canSave: Bool {
        let email = draft.recipientEmail.trimmingCharacters(in: .whitespaces)
        return email.contains("@")
            && (draft.role == .districtAdministrator || !draft.schoolIDs.isEmpty)
            && !state.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    TextField("Recipient email", text: $draft.recipientEmail)
                        .tmiTextInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Label (optional, no student data)", text: $draft.label)
                }
                Section("Access") {
                    Picker("Organization", selection: $draft.districtID) {
                        ForEach(state.tenants) { tenant in
                            Text(tenant.name).tag(tenant.districtID)
                        }
                    }
                    .onChange(of: draft.districtID) { _, _ in draft.schoolIDs = [] }
                    Picker("Role", selection: $draft.role) {
                        ForEach(StaffRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .onChange(of: draft.role) { _, role in
                        draft.capabilities = DeveloperConsoleDefaults.capabilities(for: role)
                    }
                }
                DeveloperSchoolPicker(
                    schools: tenant?.schools ?? [],
                    selection: $draft.schoolIDs,
                    isRequired: draft.role != .districtAdministrator
                )
                DeveloperCapabilityPicker(selection: $draft.capabilities)
                Section("Expiry") {
                    Stepper("Expires in \(draft.expiresInDays) days", value: $draft.expiresInDays, in: 1...90)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await state.createInvitation(draft, filter: districtFilter) }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(item: Binding(
                get: { state.createdInvitation.map(CreatedInvitationBox.init) },
                set: { if $0 == nil { state.createdInvitation = nil; dismiss() } }
            )) { box in
                DeveloperCreatedInvitationView(created: box.created, email: draft.recipientEmail)
            }
            .developerErrorAlert(state)
        }
        .tmiSheetStyle()
    }
}

private struct CreatedInvitationBox: Identifiable {
    let created: DevCreatedInvitation
    var id: String { created.invitationID }
}

private struct DeveloperCreatedInvitationView: View {
    let created: DevCreatedInvitation
    let email: String
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var shareText: String {
        """
        You're invited to TMI. Register with \(email) and enter this invitation code:
        \(created.invitationCode)
        The code expires \(DeveloperDates.display(created.expiresAt)).
        """
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(created.invitationCode)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .accessibilityLabel("Invitation code")
                    Button(didCopy ? "Copied" : "Copy code", systemImage: didCopy ? "checkmark" : "doc.on.doc") {
                        DeveloperClipboard.copy(created.invitationCode)
                        didCopy = true
                    }
                    ShareLink(item: shareText) {
                        Label("Share invitation", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Invitation code")
                } footer: {
                    Text("This is the only time the code is shown. Only \(email) can redeem it, once, before \(DeveloperDates.display(created.expiresAt)).")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Invitation created")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tmiSheetStyle()
        .interactiveDismissDisabled()
    }
}

// MARK: - Shared pickers

struct DeveloperSchoolPicker: View {
    let schools: [DevSchool]
    @Binding var selection: [String]
    let isRequired: Bool

    var body: some View {
        Section {
            if schools.isEmpty {
                Text("This organization has no sites yet.").foregroundStyle(.secondary)
            }
            ForEach(schools) { school in
                Toggle(isOn: Binding(
                    get: { selection.contains(school.schoolID) },
                    set: { isOn in
                        if isOn {
                            selection.append(school.schoolID)
                        } else {
                            selection.removeAll { $0 == school.schoolID }
                        }
                    }
                )) {
                    Text(school.name)
                }
            }
        } header: {
            Text("Sites")
        } footer: {
            Text(isRequired ? "Select at least one site." : "District administrators may span every site.")
        }
    }
}

struct DeveloperCapabilityPicker: View {
    @Binding var selection: [Capability]

    var body: some View {
        Section {
            ForEach(Capability.allCases, id: \.self) { capability in
                Toggle(capability.displayName, isOn: Binding(
                    get: { selection.contains(capability) },
                    set: { isOn in
                        if isOn {
                            selection.append(capability)
                        } else {
                            selection.removeAll { $0 == capability }
                        }
                    }
                ))
            }
        } header: {
            Text("Capabilities")
        } footer: {
            Text("Defaults follow the role. Restricted-record capabilities are never granted by default.")
        }
    }
}
#endif
