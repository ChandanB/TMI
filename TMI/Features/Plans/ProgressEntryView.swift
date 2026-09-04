import SwiftUI

/// Records one observation against a goal or an action.
///
/// Nothing here edits history. Each save adds an entry, and the form says so,
/// because someone correcting a mistake needs to know the earlier reading
/// stays visible rather than being quietly replaced.
struct ProgressEntryView: View {
    let planID: String
    let studentID: String
    let member: MembershipContext
    let source: ProgressSource
    let sourceID: String
    let sourceTitle: String
    var onRecorded: () -> Void = {}

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var measuredValue = ""
    @State private var note = ""
    @State private var visibility: ProgressVisibility = .staffOnly
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Recording against", value: sourceTitle)
                } footer: {
                    Text("Each save adds an entry. Earlier readings stay in the history.")
                }

                Section("What was observed") {
                    TextField("Measured value (optional)", text: $measuredValue)
                        .accessibilityIdentifier("progressEntry.value")
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("progressEntry.note")
                }

                Section {
                    Picker("Who can read this", selection: $visibility) {
                        Text("Staff only").tag(ProgressVisibility.staffOnly)
                        Text("Shared with the student").tag(ProgressVisibility.sharedWithStudent)
                    }
                    .accessibilityIdentifier("progressEntry.visibility")
                } footer: {
                    Text(visibility == .sharedWithStudent
                        ? "The student will read this, so write it to them."
                        : "Kept to staff. It stays out of student-facing views and unauthorized exports.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TMIColors.errorText)
                            .accessibilityIdentifier("progressEntry.error")
                    }
                }
            }
            .navigationTitle("Record progress")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { Task { await record() } }
                        .disabled(isSaving || isEmpty)
                        .accessibilityIdentifier("progressEntry.record")
                }
            }
        }
    }

    private var isEmpty: Bool {
        measuredValue.trimmed.isEmpty && note.trimmed.isEmpty
    }

    private func record() async {
        guard let repository = dependencies.planChildRepository else {
            errorMessage = "Progress is unavailable in this build."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let entry = ProgressRecord(
            id: "progress_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            planID: planID,
            studentID: studentID,
            source: source,
            sourceID: sourceID,
            measuredValue: measuredValue.trimmed.isEmpty ? nil : measuredValue.trimmed,
            note: note.trimmed.isEmpty ? nil : note.trimmed,
            visibility: visibility,
            authorID: member.userID,
            // Replaced by the server's own time on write.
            recordedAt: Date()
        )

        do {
            try await repository.append(progress: entry, member: member)
            onRecorded()
            dismiss()
        } catch PlanRecordRepositoryError.permissionDenied {
            errorMessage = "You do not have access to record progress on this plan."
        } catch PlanRecordRepositoryError.unavailable {
            errorMessage = "You appear to be offline. Nothing was recorded."
        } catch {
            errorMessage = "The entry could not be recorded."
        }
    }
}
