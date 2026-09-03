import SwiftUI

/// Starts a TMI plan for one student.
///
/// A plan begins in the student's context, not from the plan list, because the
/// student is what gives it scope: the school and assignment that Firestore
/// rules authorize the write against come from the roster record.
struct CanonicalPlanEditorView: View {
    let studentID: String
    let studentName: String
    let schoolID: String
    let member: MembershipContext
    var onCreated: (PlanRecord) -> Void = { _ in }

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var model: TMIPlanModel = .chaseYourSpace
    @State private var title = TMIPlanModel.chaseYourSpace.rawValue
    @State private var summary = ""
    @State private var startDate = Date()
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervention model") {
                    Picker("Model", selection: $model) {
                        ForEach(TMIPlanModel.allCases, id: \.self) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .accessibilityIdentifier("planEditor.model")
                    Text(model.description)
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                }

                Section("Plan") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("planEditor.title")
                    TextField("Summary (optional)", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("planEditor.summary")
                }

                Section("Dates") {
                    DatePicker(
                        "Start",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    Toggle("Set a target date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker(
                            "Target",
                            selection: $targetDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    LabeledContent("Student", value: studentName)
                    LabeledContent("Starts as", value: PlanRecordStatus.draft.displayName)
                } footer: {
                    Text("You can activate the plan once it is ready.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(TMIColors.errorText)
                            .accessibilityIdentifier("planEditor.error")
                    }
                }
            }
            .navigationTitle("New TMI Plan")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .onChange(of: model) { oldModel, newModel in
                title = PlanCreation.title(
                    movingFrom: oldModel,
                    to: newModel,
                    currentTitle: title
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isSaving || trimmedTitle.isEmpty)
                    .accessibilityIdentifier("planEditor.create")
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Creating…")
                        .padding(TMISpacing.lg)
                        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.lg))
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() async {
        guard let repository = dependencies.planRepository else {
            errorMessage = "Plans are unavailable in this build."
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let draft = PlanCreation.draft(
            studentID: studentID,
            schoolID: schoolID,
            member: member,
            model: model,
            title: title,
            summary: summary,
            startDate: startDate,
            targetDate: hasTargetDate ? targetDate : nil
        )

        let issues = PlanValidation.issues(for: draft, member: member)
        guard issues.isEmpty else {
            errorMessage = issues.joined(separator: " ")
            return
        }

        do {
            let record = try await repository.create(
                draft,
                operationID: UUID(),
                member: member
            )
            onCreated(record)
            dismiss()
        } catch PlanRecordRepositoryError.permissionDenied {
            errorMessage = "You do not have access to create a plan for this student."
        } catch PlanRecordRepositoryError.unavailable {
            errorMessage = "You appear to be offline. Try again when you reconnect."
        } catch PlanRecordRepositoryError.invalidDraft {
            errorMessage = "Check the plan details and try again."
        } catch {
            errorMessage = "The plan could not be created."
        }
    }
}
