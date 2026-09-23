import SwiftUI

/// Staff, invitations, and access for administrators with `staff.manage`.
/// Pushed from Settings onto the existing navigation stack, so it must not
/// create its own `NavigationStack`.
struct StaffAdministrationView: View {
    enum Section: String, CaseIterable, Identifiable {
        case staff = "Staff"
        case invitations = "Invitations"
        var id: String { rawValue }
    }

    let member: MembershipContext
    private let repository: any StaffAdministrationRepository

    @Environment(\.programContext) private var programContext
    @State private var section: Section = .staff
    @State private var staff: [AdminStaffMember] = []
    @State private var invitations: [AdminInvitation] = []
    @State private var isLoading = false
    @State private var loadError: StaffAdministrationError?
    @State private var actionError: StaffAdministrationError?
    @State private var editing: AdminMembershipDraft?
    @State private var isInviting = false
    @State private var invitationLoadError: StaffAdministrationError?
    @State private var pendingRevoke: AdminInvitation?

    init(member: MembershipContext, repository: (any StaffAdministrationRepository)? = nil) {
        self.member = member
        self.repository = repository ?? FirebaseStaffAdministrationRepository()
    }


    var body: some View {
        List {
            if let loadError, section == .staff {
                ContentUnavailableView {
                    Label("Staff unavailable", systemImage: "person.2.slash")
                } description: {
                    Text(loadError.localizedDescription)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.tmiPrimary)
                }
            } else if let invitationLoadError, section == .invitations {
                ContentUnavailableView {
                    Label("Invitations unavailable", systemImage: "envelope.badge.shield.half.filled")
                } description: {
                    Text(invitationLoadError.localizedDescription)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                        .buttonStyle(.tmiPrimary)
                }
            } else {
                switch section {
                case .staff: staffList
                case .invitations: invitationList
                }
            }
        }
        // The segmented control sits above the list so it can't reshape the
        // first section's corners (it used to render inside the list).
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Show", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.sm)
        }
        .scrollContentBackground(.hidden)
        .tmiScreenBackground()
        .confirmationDialog(
            "Revoke this invitation?",
            isPresented: Binding(get: { pendingRevoke != nil }, set: { if !$0 { pendingRevoke = nil } }),
            titleVisibility: .visible,
            presenting: pendingRevoke
        ) { invitation in
            Button("Revoke Invitation", role: .destructive) {
                revoke(invitation)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("The code stops working immediately. This can't be undone.")
        }
        .navigationTitle("Staff management")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isInviting = true
                } label: {
                    Label("Invite staff", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("staffAdmin.invite")
            }
        }
        .overlay { if isLoading && staff.isEmpty { ProgressView() } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: Binding(
            get: { editing.map(EditBox.init) },
            set: { editing = $0?.draft }
        )) { box in
            StaffAccessEditor(
                draft: box.draft,
                caller: member,
                sites: programContext.sites(for: member),
                allSchoolsAllowed: member.role == .districtAdministrator
            ) { draft in
                try await repository.updateMembership(draft, districtID: member.districtID, operationID: UUID().uuidString)
                await load()
            }
        }
        .sheet(isPresented: $isInviting) {
            StaffInvitationEditor(caller: member, sites: programContext.sites(for: member)) { draft in
                let created = try await repository.createInvitation(draft, districtID: member.districtID, operationID: UUID().uuidString)
                await load()
                return created
            }
        }
        .alert(
            "Couldn't complete that",
            isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } }),
            presenting: actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var staffList: some View {
        if staff.isEmpty, !isLoading {
            Text("No staff yet. Invite someone to get started.").foregroundStyle(TMIColors.textSecondary)
        }
        ForEach(staff) { person in
            Button {
                if person.isManageable { editing = AdminMembershipDraft(member: person) }
            } label: {
                HStack(alignment: .center, spacing: TMISpacing.ms) {
                    TMIAvatar(initials: Self.initials(person.title), size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: TMISpacing.sm) {
                            Text(person.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(TMIColors.textPrimary)
                            if person.isSelf {
                                TMIStatusBadge("You", tone: .neutral)
                            }
                        }
                        if let email = person.email, person.displayName != nil {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(TMIColors.textSecondary)
                                .textSelection(.enabled)
                        }
                        let sites = person.schoolIDs.map(programContext.siteName).joined(separator: ", ")
                        if !sites.isEmpty {
                            Text(sites)
                                .font(.footnote)
                                .foregroundStyle(TMIColors.textTertiary)
                        }
                    }
                    Spacer(minLength: TMISpacing.sm)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(person.role?.displayName ?? "Unknown role")
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                        if !person.isActive {
                            TMIStatusBadge("Inactive", tone: .warning, systemImage: "pause.circle.fill")
                        }
                    }
                    if person.isManageable {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TMIColors.textTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(TMIColors.surface)
            .disabled(!person.isManageable)
            .accessibilityHint(person.isManageable ? "Edit access" : "Outside your administrative scope")
        }
    }

    @ViewBuilder
    private var invitationList: some View {
        if invitations.isEmpty, !isLoading {
            Text("No invitations yet.").foregroundStyle(TMIColors.textSecondary)
        }
        ForEach(invitations) { invitation in
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                HStack {
                    Text(invitation.label ?? invitation.role.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TMIColors.textPrimary)
                    Spacer()
                    TMIStatusBadge(invitation.status.displayName, tone: invitation.status == .active ? .success : .neutral)
                }
                Text("\(invitation.role.displayName) · \(invitation.schoolIDs.map(programContext.siteName).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
            }
            .listRowBackground(TMIColors.surface)
            // Revoking changes the row's status rather than removing it, so it
            // is not a destructive-role swipe (which would animate a delete).
            .swipeActions {
                if invitation.status == .active || invitation.status == .expired {
                    Button("Revoke", systemImage: "xmark.octagon") {
                        pendingRevoke = invitation
                    }
                    .tint(TMIColors.errorText)
                }
            }
            .contextMenu {
                if invitation.status == .active || invitation.status == .expired {
                    Button("Revoke…", systemImage: "xmark.octagon", role: .destructive) {
                        pendingRevoke = invitation
                    }
                }
            }
        }
    }

    private func revoke(_ invitation: AdminInvitation) {
        Task {
            do {
                try await repository.revokeInvitation(invitationID: invitation.invitationID, districtID: member.districtID)
                await load()
            } catch {
                actionError = StaffAdministrationError.map(error)
            }
        }
    }

    /// Staff and invitations load independently: an invitations failure no
    /// longer hides a staff list that loaded fine.
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            staff = try await repository.staff(districtID: member.districtID)
            loadError = nil
        } catch {
            loadError = StaffAdministrationError.map(error)
        }
        do {
            invitations = try await repository.invitations(districtID: member.districtID)
            invitationLoadError = nil
        } catch {
            invitationLoadError = StaffAdministrationError.map(error)
        }
    }

    private static func initials(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

private struct EditBox: Identifiable {
    let draft: AdminMembershipDraft
    var id: String { draft.member.userID }
}

/// Edits one staff member's role, sites, capabilities, and activation.
/// Capabilities the caller doesn't hold are shown but can't be granted.
struct StaffAccessEditor: View {
    @State var draft: AdminMembershipDraft
    let caller: MembershipContext
    let sites: [OrganizationProfile.Site]
    let allSchoolsAllowed: Bool
    let onSave: @MainActor (AdminMembershipDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var roles: [StaffRole] {
        caller.role == .districtAdministrator ? StaffRole.allCases : StaffRole.allCases.filter { $0 != .districtAdministrator }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(draft.member.title) {
                    Picker("Role", selection: $draft.role) {
                        ForEach(roles, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Active", isOn: $draft.isActive)
                }
                Section("Sites") {
                    ForEach(sites) { site in
                        Toggle(site.name, isOn: Binding(
                            get: { draft.schoolIDs.contains(site.id) },
                            set: { isOn in
                                if isOn { draft.schoolIDs.append(site.id) } else { draft.schoolIDs.removeAll { $0 == site.id } }
                            }
                        ))
                    }
                }
                Section {
                    ForEach(Capability.allCases, id: \.self) { capability in
                        Toggle(capability.displayName, isOn: Binding(
                            get: { draft.capabilities.contains(capability) },
                            set: { isOn in
                                if isOn { draft.capabilities.append(capability) } else { draft.capabilities.removeAll { $0 == capability } }
                            }
                        ))
                        .disabled(!caller.capabilities.contains(capability))
                    }
                } header: {
                    Text("Capabilities")
                } footer: {
                    Text("You can only grant capabilities you hold. Changes take effect the next time this person signs in.")
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                try await onSave(draft)
                                dismiss()
                            } catch {
                                errorMessage = StaffAdministrationError.map(error).localizedDescription
                            }
                        }
                    }
                    .disabled(isSaving || (draft.role != .districtAdministrator && draft.schoolIDs.isEmpty))
                }
            }
        }
        .tmiSheetStyle()
    }
}

/// Creates a single-use, email-bound invitation and shows its code once.
struct StaffInvitationEditor: View {
    let caller: MembershipContext
    let sites: [OrganizationProfile.Site]
    let onCreate: @MainActor (AdminInvitationDraft) async throws -> AdminCreatedInvitation

    @Environment(\.dismiss) private var dismiss
    @State private var draft = AdminInvitationDraft()
    @State private var created: AdminCreatedInvitation?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var roles: [StaffRole] {
        caller.role == .districtAdministrator ? StaffRole.allCases : StaffRole.allCases.filter { $0 != .districtAdministrator }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let created {
                    Section {
                        Text(created.invitationCode)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        ShareLink(item: "You're invited to TMI. Register with \(draft.recipientEmail) and enter this invitation code: \(created.invitationCode)") {
                            Label("Share invitation", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Text("Invitation code")
                    } footer: {
                        Text("This is the only time the code is shown. Only \(draft.recipientEmail) can redeem it, once.")
                    }
                } else {
                    Section("Recipient") {
                        TextField("Email", text: $draft.recipientEmail)
                            .tmiTextInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("staffInvite.email")
                        TextField("Label (optional)", text: $draft.label)
                    }
                    Section("Role") {
                        Picker("Role", selection: $draft.role) {
                            ForEach(roles, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .onChange(of: draft.role) { _, role in
                            draft.capabilities = role.defaultCapabilities.filter(caller.capabilities.contains)
                        }
                    }
                    Section("Sites") {
                        ForEach(sites) { site in
                            Toggle(site.name, isOn: Binding(
                                get: { draft.schoolIDs.contains(site.id) },
                                set: { isOn in
                                    if isOn { draft.schoolIDs.append(site.id) } else { draft.schoolIDs.removeAll { $0 == site.id } }
                                }
                            ))
                        }
                    }
                    Section {
                        ForEach(Capability.allCases, id: \.self) { capability in
                            Toggle(capability.displayName, isOn: Binding(
                                get: { draft.capabilities.contains(capability) },
                                set: { isOn in
                                    if isOn { draft.capabilities.append(capability) } else { draft.capabilities.removeAll { $0 == capability } }
                                }
                            ))
                            .disabled(!caller.capabilities.contains(capability))
                        }
                    } header: {
                        Text("Capabilities")
                    }
                    Section {
                        Stepper("Expires in \(draft.expiresInDays) days", value: $draft.expiresInDays, in: 1...30)
                    }
                    if let errorMessage {
                        Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText) }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(created == nil ? "Invite staff" : "Invitation created")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if created == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Creating…" : "Create") {
                            isSaving = true
                            Task {
                                defer { isSaving = false }
                                do {
                                    created = try await onCreate(draft)
                                } catch {
                                    errorMessage = StaffAdministrationError.map(error).localizedDescription
                                }
                            }
                        }
                        .disabled(isSaving || !draft.recipientEmail.contains("@")
                                  || (draft.role != .districtAdministrator && draft.schoolIDs.isEmpty))
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .interactiveDismissDisabled(isSaving || created != nil)
            .onAppear {
                draft.capabilities = draft.role.defaultCapabilities.filter(caller.capabilities.contains)
                if sites.count == 1 { draft.schoolIDs = sites.map(\.id) }
            }
        }
        .tmiSheetStyle()
    }
}

/// District audit trail for members with `audit.read`.
struct AuditLogView: View {
    let member: MembershipContext
    private let repository: any StaffAdministrationRepository

    @State private var events: [AuditEventSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    init(member: MembershipContext, repository: (any StaffAdministrationRepository)? = nil) {
        self.member = member
        self.repository = repository ?? FirebaseStaffAdministrationRepository()
    }

    var body: some View {
        List {
            if let errorMessage {
                ContentUnavailableView("Audit log unavailable", systemImage: "doc.text.magnifyingglass", description: Text(errorMessage))
            } else if events.isEmpty, !isLoading {
                ContentUnavailableView("No audit events yet", systemImage: "doc.text.magnifyingglass")
            }
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                    HStack {
                        Text(event.title).font(.headline)
                        if event.isOperator {
                            Text("Operator").font(.caption2.weight(.semibold)).foregroundStyle(TMIColors.warningText)
                        }
                    }
                    Text(event.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Pending")
                        .font(.caption)
                        .foregroundStyle(TMIColors.textSecondary)
                    Text("By \(event.actorUserID)").font(.caption2.monospaced()).foregroundStyle(TMIColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Audit log")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isLoading && events.isEmpty { ProgressView() } }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await repository.auditEvents(districtID: member.districtID)
            errorMessage = nil
        } catch {
            errorMessage = "Your access doesn't include the audit log, or it couldn't be loaded."
        }
    }
}
