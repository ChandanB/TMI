import SwiftUI

/// Writes one action under a goal.
///
/// An action names who does it and who it is for. Both matter: work nobody
/// owns does not happen, and an action written for a student is read by the
/// student, so it is worded for them.
struct ActionEditorView: View {
    let planID: String
    let goal: GoalRecord
    let member: MembershipContext
    var existing: ActionRecord?
    var onSaved: () -> Void = {}

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var audience: ActionAudience = .staff
    @State private var cadence: ActionCadence = .weekly
    @State private var dueDate = Date()
    @State private var status: ActionStatus = .open
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Goal", value: goal.title)
                }

                Section("Action") {
                    TextField("What happens", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("actionEditor.title")
                    Picker("Cadence", selection: $cadence) {
                        ForEach(ActionCadence.allCases, id: \.self) { cadence in
                            Text(cadence.displayName).tag(cadence)
                        }
                    }
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }

                Section {
                    Picker("Who it is for", selection: $audience) {
                        ForEach(ActionAudience.allCases, id: \.self) { audience in
                            Text(audience.displayName).tag(audience)
                        }
                    }
                    .accessibilityIdentifier("actionEditor.audience")
                    LabeledContent("Owner", value: member.userID)
                } footer: {
                    Text(audience == .student
                        ? "The student will read this, so write it to them."
                        : "Staff-facing. The student does not see this wording.")
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ActionStatus.allCases, id: \.self) { status in
                            Text(statusLabel(status)).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    if status == .skipped {
                        Text("A skipped action leaves the completion count. Work withdrawn is not work owed.")
                            .font(.caption)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TMIColors.errorText)
                            .accessibilityIdentifier("actionEditor.error")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Action" : "Edit Action")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || title.trimmed.isEmpty)
                        .accessibilityIdentifier("actionEditor.save")
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func statusLabel(_ status: ActionStatus) -> String {
        switch status {
        case .open: "Open"
        case .done: "Done"
        case .skipped: "Skipped"
        }
    }

    private func prefill() {
        guard let existing else {
            dueDate = goal.dueDate
            return
        }
        title = existing.title
        audience = existing.audience
        cadence = existing.cadence
        dueDate = existing.dueDate
        status = existing.status
    }

    private func save() async {
        guard let repository = dependencies.planChildRepository else {
            errorMessage = "Actions are unavailable in this build."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let action = ActionRecord(
            id: existing?.id ?? "action_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            planID: planID,
            goalID: goal.id,
            title: title.trimmed,
            ownerMemberID: existing?.ownerMemberID ?? member.userID,
            audience: audience,
            cadence: cadence,
            dueDate: dueDate,
            status: status
        )

        do {
            try await repository.save(action: action, member: member)
            onSaved()
            dismiss()
        } catch PlanRecordRepositoryError.permissionDenied {
            errorMessage = "You do not have access to change this plan's actions."
        } catch PlanRecordRepositoryError.unavailable {
            errorMessage = "You appear to be offline. Nothing was saved."
        } catch {
            errorMessage = "The action could not be saved."
        }
    }
}
