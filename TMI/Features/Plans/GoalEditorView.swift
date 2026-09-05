import SwiftUI

/// Writes one goal.
///
/// Staff wording and student wording are captured separately and labelled as
/// such, because the sentence a professional records and the sentence a child
/// reads about themselves are not the same sentence.
struct GoalEditorView: View {
    let planID: String
    let studentID: String
    let member: MembershipContext
    let planStartDate: Date
    var existing: GoalRecord?
    var statusOnly = false
    var onSaved: (GoalRecord) -> Void = { _ in }

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var studentFacingTitle = ""
    @State private var measure: GoalMeasure = .count
    @State private var baseline = ""
    @State private var target = ""
    @State private var dueDate = Date()
    @State private var status: GoalRecordStatus = .notStarted
    @State private var operationID = UUID()
    @State private var isSaving = false
    @State private var issues: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("goalEditor.title")
                        .disabled(statusOnly)
                    Picker("Measure", selection: $measure) {
                        ForEach(GoalMeasure.allCases, id: \.self) { measure in
                            Text(measure.displayName).tag(measure)
                        }
                    }
                    .disabled(statusOnly)
                }

                Section {
                    TextField("Baseline", text: $baseline, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("goalEditor.baseline")
                        .disabled(statusOnly)
                    TextField("Target", text: $target, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("goalEditor.target")
                        .disabled(statusOnly)
                } header: {
                    Text("Where the student is starting, and where this is going")
                } footer: {
                    Text("Progress is read against the baseline, so it has to say where things stand today.")
                }

                Section {
                    TextField("How the student sees this (optional)", text: $studentFacingTitle, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("goalEditor.studentWording")
                        .disabled(statusOnly)
                } header: {
                    Text("Student wording")
                } footer: {
                    Text("Written for the student to read. Left empty, the student sees the title above.")
                }

                Section("Schedule and ownership") {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        .disabled(statusOnly)
                    LabeledContent("Responsible", value: member.userID)
                    Picker("Status", selection: $status) {
                        ForEach(GoalRecordStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                if !issues.isEmpty {
                    Section {
                        ForEach(issues, id: \.self) { issue in
                            Text(issue)
                                .font(.footnote)
                                .foregroundStyle(TMIColors.errorText)
                        }
                    }
                    .accessibilityIdentifier("goalEditor.issues")
                }
            }
            .navigationTitle(existing == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                        .accessibilityIdentifier("goalEditor.save")
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let existing else {
            dueDate = max(Date(), planStartDate)
            return
        }
        title = existing.title
        studentFacingTitle = existing.studentFacingTitle ?? ""
        measure = existing.measure
        baseline = existing.baseline
        target = existing.target
        dueDate = existing.dueDate
        status = existing.status
    }

    private func save() async {
        guard let repository = dependencies.planChildRepository else {
            issues = ["Goals are unavailable in this build."]
            return
        }
        isSaving = true
        defer { isSaving = false }

        let goal = GoalRecord(
            id: existing?.id ?? "goal_\(operationID.uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            planID: planID,
            studentID: studentID,
            title: title.trimmed,
            studentFacingTitle: studentFacingTitle.trimmed.isEmpty ? nil : studentFacingTitle.trimmed,
            measure: measure,
            baseline: baseline.trimmed,
            target: target.trimmed,
            dueDate: dueDate,
            responsibleMemberID: existing?.responsibleMemberID ?? member.userID,
            status: status
        )

        // The same validation the record itself defines, so a goal cannot be
        // saved in a shape the rest of the app refuses to read.
        issues = GoalValidation.issues(for: goal, startDate: planStartDate)
        guard issues.isEmpty else { return }

        do {
            try await repository.save(goal: goal, member: member)
            onSaved(goal)
            dismiss()
        } catch PlanRecordRepositoryError.permissionDenied {
            issues = ["You do not have access to change this plan's goals."]
        } catch PlanRecordRepositoryError.unavailable {
            issues = ["You appear to be offline. Nothing was saved."]
        } catch {
            issues = ["The goal could not be saved."]
        }
    }
}
