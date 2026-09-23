import SwiftUI

/// Caregiver form for recording what a child chose during play. Observations
/// describe what was seen — never diagnoses — and save only after the server
/// confirms them.
struct InterestObservationSheet: View {
    let childName: String
    let onSave: @MainActor (InterestObservationDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = InterestObservationDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let interests = EarlyChildhoodSurveyContent.interests

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: TMISpacing.sm)], spacing: TMISpacing.sm) {
                        ForEach(interests, id: \.id) { interest in
                            let selected = draft.observedInterestIDs.contains(interest.id)
                            Button {
                                toggle(interest.id)
                            } label: {
                                Label(interest.name, systemImage: selected ? "checkmark.circle.fill" : interest.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .padding(.horizontal, TMISpacing.sm)
                                    .foregroundStyle(selected ? TMIColors.infoText : TMIColors.textPrimary)
                                    .background(selected ? TMIColors.infoSurface : TMIColors.surface,
                                                in: RoundedRectangle(cornerRadius: TMIRadius.md))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: TMIRadius.md)
                                            .stroke(selected ? TMIColors.accent : TMIColors.interactiveBorder, lineWidth: selected ? 2 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("observation.interest.\(interest.id)")
                        }
                    }
                } header: {
                    Text("What did \(childName) choose on their own?")
                } footer: {
                    Text("Select every activity you saw the child choose during free play.")
                }

                if !draft.observedInterestIDs.isEmpty {
                    Section("Held attention longest") {
                        Picker("Activity", selection: $draft.longestAttentionInterestID) {
                            Text("Not sure").tag(String?.none)
                            ForEach(interests.filter { draft.observedInterestIDs.contains($0.id) }, id: \.id) { interest in
                                Text(interest.name).tag(String?.some(interest.id))
                            }
                        }
                    }
                }

                Section {
                    Picker("Engagement", selection: $draft.engagement) {
                        Text("Not recorded").tag(Int?.none)
                        ForEach(1...5, id: \.self) { value in
                            Text(engagementLabel(value)).tag(Int?.some(value))
                        }
                    }
                } header: {
                    Text("Engagement")
                }

                Section {
                    TextField("What did you see? What did the child do, say, or show?", text: $draft.note, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("observation.note")
                } header: {
                    Text("Notes (optional)")
                } footer: {
                    Text("Describe what you observed. Don't record diagnoses or family circumstances here.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(TMIColors.errorText)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Interest observation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(!draft.isValid || isSaving)
                        .accessibilityIdentifier("observation.save")
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .tmiSheetStyle()
    }

    private func toggle(_ interestID: String) {
        if let index = draft.observedInterestIDs.firstIndex(of: interestID) {
            draft.observedInterestIDs.remove(at: index)
            if draft.longestAttentionInterestID == interestID {
                draft.longestAttentionInterestID = nil
            }
        } else {
            draft.observedInterestIDs.append(interestID)
        }
    }

    private func engagementLabel(_ value: Int) -> String {
        switch value {
        case 1: "1 — briefly"
        case 3: "3 — several minutes"
        case 5: "5 — deeply focused"
        default: "\(value)"
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
