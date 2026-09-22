import SwiftUI

/// Family intake form. In hand-off mode the family sees only this child's
/// form — no navigation, no other records — and returning to the staff
/// workspace requires the caregiver's device authentication.
struct FamilyInputSheet: View {
    let childName: String
    let onSubmit: @MainActor (FamilyInputDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = FamilyInputDraft()
    @State private var isHandedOff = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false
    @State private var lockMessage: String?

    private let interests = EarlyChildhoodSurveyContent.interests

    var body: some View {
        NavigationStack {
            Form {
                if !isHandedOff {
                    Section {
                        Picker("Who is completing this?", selection: $draft.completedBy) {
                            ForEach(FamilyInputDraft.CompletedBy.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        if draft.completedBy == .family {
                            Button("Hand the device to the family", systemImage: "hand.raised") {
                                isHandedOff = true
                            }
                            .disabled(!FamilyHandoffLock.isAvailable)
                            if !FamilyHandoffLock.isAvailable {
                                Text("Set a device passcode to lock the hand-off, or record the family's answers yourself.")
                                    .font(.footnote)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                        }
                    } footer: {
                        Text("The family sees only this form for \(childName). Returning to the staff app requires your device passcode or Face ID.")
                    }
                }

                if isHandedOff {
                    Section {
                        Text("Thank you for helping us get to know \(childName). Answer as much or as little as you like.")
                            .font(.body)
                    }
                }

                Section("About you") {
                    TextField("Your relationship to \(childName) (optional)", text: $draft.relationship)
                }

                Section("\(childName)'s favorite things to play") {
                    ForEach(interests, id: \.id) { interest in
                        Toggle(isOn: Binding(
                            get: { draft.favoritePlayInterestIDs.contains(interest.id) },
                            set: { isOn in
                                if isOn {
                                    draft.favoritePlayInterestIDs.append(interest.id)
                                } else {
                                    draft.favoritePlayInterestIDs.removeAll { $0 == interest.id }
                                }
                            }
                        )) {
                            Label(interest.name, systemImage: interest.symbol)
                        }
                        .frame(minHeight: 44)
                    }
                }

                ForEach(FamilyInputDraft.questions) { question in
                    Section(question.prompt) {
                        TextField("Your answer", text: Binding(
                            get: { draft.answers[question.id] ?? "" },
                            set: { draft.answers[question.id] = $0 }
                        ), axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityLabel(question.prompt)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(TMIColors.errorText)
                    }
                }
                if let lockMessage {
                    Section {
                        Text(lockMessage).foregroundStyle(TMIColors.textSecondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isHandedOff ? "All about \(childName)" : "Family input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isHandedOff {
                        Button("Return to staff", systemImage: "lock") { returnToStaff(thenDismiss: false) }
                    } else {
                        Button("Cancel") { dismiss() }.disabled(isSubmitting)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending…" : (isHandedOff ? "I'm done" : "Save")) { submit() }
                        .disabled(!draft.isValid || isSubmitting)
                        .accessibilityIdentifier("familyInput.submit")
                }
            }
            .interactiveDismissDisabled(isHandedOff || isSubmitting)
        }
        .tmiSheetStyle()
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await onSubmit(draft)
                didSubmit = true
                if isHandedOff {
                    lockMessage = "Thank you! Please hand the device back to the caregiver."
                    returnToStaff(thenDismiss: true)
                } else {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func returnToStaff(thenDismiss: Bool) {
        Task {
            guard await FamilyHandoffLock.authenticateStaff() else {
                lockMessage = "Staff authentication is required to leave the family form."
                return
            }
            isHandedOff = false
            lockMessage = nil
            if thenDismiss || didSubmit { dismiss() }
        }
    }
}
