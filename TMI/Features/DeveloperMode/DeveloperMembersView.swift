#if DEBUG
import SwiftUI

struct DeveloperMembersView: View {
    let state: DeveloperModeState
    @State private var districtID: String = ""
    @State private var editing: DevMembershipDraft?

    var body: some View {
        List {
            Section {
                Picker("Organization", selection: $districtID) {
                    ForEach(state.tenants) { tenant in
                        Text(tenant.name).tag(tenant.districtID)
                    }
                }
            }
            Section {
                if state.members.isEmpty {
                    Text(state.isWorking ? "Loading…" : "No staff memberships yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.members) { member in
                    Button {
                        editing = DevMembershipDraft(
                            districtID: districtID,
                            userID: member.userID,
                            email: member.email ?? "",
                            role: member.role ?? .teacher,
                            schoolIDs: member.schoolIDs,
                            capabilities: member.capabilities,
                            isActive: member.isActive
                        )
                    } label: {
                        DeveloperMemberRow(state: state, districtID: districtID, member: member)
                    }
                }
            } header: {
                Text("Staff")
            } footer: {
                Text("Saving bumps the membership version and refreshes that account's trusted claims to this organization. The person must sign out and back in (or pull their session) to pick it up.")
            }
        }
        .navigationTitle("Staff access")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = DevMembershipDraft(
                        districtID: districtID,
                        userID: nil,
                        email: "",
                        role: .teacher,
                        schoolIDs: [],
                        capabilities: DeveloperConsoleDefaults.capabilities(for: .teacher),
                        isActive: true
                    )
                } label: {
                    Label("Add existing account", systemImage: "person.badge.plus")
                }
                .disabled(districtID.isEmpty)
            }
        }
        .onAppear {
            if districtID.isEmpty {
                districtID = state.tenants.first?.districtID ?? ""
            }
        }
        .task(id: districtID) {
            guard !districtID.isEmpty else { return }
            await state.loadMembers(districtID: districtID)
        }
        .refreshable {
            guard !districtID.isEmpty else { return }
            await state.loadMembers(districtID: districtID)
        }
        .sheet(item: Binding(
            get: { editing.map(MembershipDraftBox.init) },
            set: { editing = $0?.draft }
        )) { box in
            DeveloperMembershipEditor(state: state, draft: box.draft) { editing = nil }
        }
        .developerErrorAlert(state)
    }
}

private struct MembershipDraftBox: Identifiable {
    let draft: DevMembershipDraft
    var id: String { draft.userID ?? "new" }
}

private struct DeveloperMemberRow: View {
    let state: DeveloperModeState
    let districtID: String
    let member: DevMember

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(member.title).font(.headline).foregroundStyle(.primary)
                Spacer()
                DeveloperBadge(
                    text: member.isActive ? (member.role?.displayName ?? "Unknown role") : "Inactive",
                    tone: member.isActive ? .neutral : .negative
                )
            }
            if let email = member.email, member.displayName != nil {
                Text(email).font(.caption).foregroundStyle(.secondary)
            }
            Text(member.schoolIDs.map { state.schoolName($0, in: districtID) }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("v\(member.version) · \(member.capabilities.count) capabilities · \(member.assignedStudentCount) assigned")
                if member.claimDistrictID != districtID {
                    Label("Claims point elsewhere", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(TMIColors.warningText)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct DeveloperMembershipEditor: View {
    let state: DeveloperModeState
    let onDone: () -> Void
    @State private var draft: DevMembershipDraft

    init(state: DeveloperModeState, draft: DevMembershipDraft, onDone: @escaping () -> Void) {
        self.state = state
        self.onDone = onDone
        _draft = State(initialValue: draft)
    }

    private var isNew: Bool { draft.userID == nil }

    private var canSave: Bool {
        (!isNew || draft.email.contains("@"))
            && (draft.role == .districtAdministrator || !draft.schoolIDs.isEmpty)
            && !state.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if isNew {
                        TextField("Existing account email", text: $draft.email)
                            .tmiTextInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        LabeledContent("Account", value: draft.email.isEmpty ? (draft.userID ?? "") : draft.email)
                    }
                    Toggle("Active", isOn: $draft.isActive)
                }
                Section("Role") {
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
                    schools: state.tenant(draft.districtID)?.schools ?? [],
                    selection: $draft.schoolIDs,
                    isRequired: draft.role != .districtAdministrator
                )
                DeveloperCapabilityPicker(selection: $draft.capabilities)
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Add staff" : "Edit access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await state.saveMembership(draft) { onDone() }
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .developerErrorAlert(state)
        }
        .tmiSheetStyle()
    }
}
#endif
