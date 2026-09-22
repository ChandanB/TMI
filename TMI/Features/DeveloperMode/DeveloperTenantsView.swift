#if DEBUG
import SwiftUI

struct DeveloperTenantsView: View {
    let state: DeveloperModeState
    @State private var isCreatingDistrict = false

    var body: some View {
        List {
            if state.tenants.isEmpty {
                ContentUnavailableView(
                    "No organizations",
                    systemImage: "building.2",
                    description: Text("Create a district or early-learning provider to start issuing invitations.")
                )
            }
            ForEach(state.tenants) { tenant in
                NavigationLink {
                    DeveloperTenantDetailView(state: state, districtID: tenant.districtID)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tenant.name).font(.headline)
                        Text("\(tenant.districtID) · \(tenant.organizationKind.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            DeveloperBadge(text: tenant.programType.displayName, tone: .neutral)
                            Text("\(tenant.schools.count) sites · \(tenant.memberCount) staff")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Organizations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreatingDistrict = true
                } label: {
                    Label("New organization", systemImage: "plus")
                }
            }
        }
        .refreshable { await state.reloadTenants() }
        .sheet(isPresented: $isCreatingDistrict) {
            DeveloperDistrictEditor(state: state, tenant: nil)
        }
        .developerErrorAlert(state)
    }
}

struct DeveloperTenantDetailView: View {
    let state: DeveloperModeState
    let districtID: String
    @State private var isEditingDistrict = false
    @State private var editingSchool: DevSchool?
    @State private var isCreatingSchool = false

    var body: some View {
        List {
            if let tenant = state.tenant(districtID) {
                Section("Organization") {
                    LabeledContent("Name", value: tenant.name)
                    LabeledContent("Identifier", value: tenant.districtID)
                    LabeledContent("Kind", value: tenant.organizationKind.displayName)
                    LabeledContent("Default program", value: tenant.programType.displayName)
                    LabeledContent("Staff memberships", value: "\(tenant.memberCount)")
                    Button("Edit organization") { isEditingDistrict = true }
                }
                Section {
                    ForEach(tenant.schools) { school in
                        Button {
                            editingSchool = school
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(school.name).foregroundStyle(.primary)
                                    Text(school.schoolID).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                DeveloperBadge(
                                    text: tenant.effectiveProgram(for: school).displayName
                                        + (school.programType == nil ? " (default)" : ""),
                                    tone: .neutral
                                )
                            }
                        }
                    }
                    Button {
                        isCreatingSchool = true
                    } label: {
                        Label("Add site", systemImage: "plus")
                    }
                } header: {
                    Text("Sites")
                } footer: {
                    Text("A site without its own program type inherits the organization default.")
                }
                .sheet(isPresented: $isEditingDistrict) {
                    DeveloperDistrictEditor(state: state, tenant: tenant)
                }
                .sheet(item: $editingSchool) { school in
                    DeveloperSchoolEditor(state: state, tenant: tenant, school: school)
                }
                .sheet(isPresented: $isCreatingSchool) {
                    DeveloperSchoolEditor(state: state, tenant: tenant, school: nil)
                }
            } else {
                ContentUnavailableView("Organization not found", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle(state.tenant(districtID)?.name ?? districtID)
        .navigationBarTitleDisplayMode(.inline)
        .developerErrorAlert(state)
    }
}

private struct DeveloperDistrictEditor: View {
    let state: DeveloperModeState
    let tenant: DevTenant?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var districtID: String
    @State private var organizationKind: OrganizationKind
    @State private var programType: ProgramType
    @State private var identifierEdited = false

    init(state: DeveloperModeState, tenant: DevTenant?) {
        self.state = state
        self.tenant = tenant
        _name = State(initialValue: tenant?.name ?? "")
        _districtID = State(initialValue: tenant?.districtID ?? "")
        _organizationKind = State(initialValue: tenant?.organizationKind ?? .schoolDistrict)
        _programType = State(initialValue: tenant?.programType ?? .k12)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && DeveloperIdentifier.isValid(districtID)
            && !state.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if tenant == nil, !identifierEdited {
                                districtID = DeveloperIdentifier.slug(from: newValue)
                            }
                        }
                    if tenant == nil {
                        TextField("Identifier", text: Binding(
                            get: { districtID },
                            set: { districtID = $0; identifierEdited = true }
                        ))
                        .tmiTextInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    } else {
                        LabeledContent("Identifier", value: districtID)
                    }
                } footer: {
                    Text("The identifier is permanent; only the display name can change later.")
                }
                Section("Program") {
                    Picker("Kind", selection: $organizationKind) {
                        ForEach(OrganizationKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .onChange(of: organizationKind) { _, newValue in
                        if tenant == nil {
                            programType = newValue == .earlyLearningProvider ? .earlyChildhood : .k12
                        }
                    }
                    Picker("Default program", selection: $programType) {
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(tenant == nil ? "New organization" : "Edit organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let saved = await state.saveDistrict(
                                districtID: districtID,
                                name: name.trimmingCharacters(in: .whitespaces),
                                organizationKind: organizationKind,
                                programType: programType
                            )
                            if saved { dismiss() }
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

private struct DeveloperSchoolEditor: View {
    let state: DeveloperModeState
    let tenant: DevTenant
    let school: DevSchool?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var schoolID: String
    @State private var programOverride: ProgramType?
    @State private var identifierEdited = false

    init(state: DeveloperModeState, tenant: DevTenant, school: DevSchool?) {
        self.state = state
        self.tenant = tenant
        self.school = school
        _name = State(initialValue: school?.name ?? "")
        _schoolID = State(initialValue: school?.schoolID ?? "")
        _programOverride = State(initialValue: school?.programType)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && DeveloperIdentifier.isValid(schoolID)
            && !state.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Site name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if school == nil, !identifierEdited {
                                schoolID = DeveloperIdentifier.slug(from: newValue)
                            }
                        }
                    if school == nil {
                        TextField("Identifier", text: Binding(
                            get: { schoolID },
                            set: { schoolID = $0; identifierEdited = true }
                        ))
                        .tmiTextInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    } else {
                        LabeledContent("Identifier", value: schoolID)
                    }
                } header: {
                    Text(tenant.name)
                }
                Section {
                    Picker("Program", selection: $programOverride) {
                        Text("Inherit (\(tenant.programType.displayName))").tag(ProgramType?.none)
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(ProgramType?.some(type))
                        }
                    }
                } footer: {
                    Text("Early-childhood sites use the child, family, and observation flow instead of student surveys and careers.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(school == nil ? "New site" : "Edit site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let saved = await state.saveSchool(
                                districtID: tenant.districtID,
                                schoolID: schoolID,
                                name: name.trimmingCharacters(in: .whitespaces),
                                programType: programOverride
                            )
                            if saved { dismiss() }
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
