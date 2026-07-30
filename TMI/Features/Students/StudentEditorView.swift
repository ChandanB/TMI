import SwiftUI

struct StudentEditorView: View {
    enum SaveOutcome {
        case confirmed
        case queued
        case duplicate(candidateIDs: [String])
        case failed
    }

    enum Mode: Equatable {
        case create
        case edit(StudentRecord)

        var title: String {
            switch self {
            case .create: "Add Student"
            case .edit: "Edit Student"
            }
        }

        var confirmationAnnouncement: String {
            switch self {
            case .create: "Student added."
            case .edit: "Student updated."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let member: MembershipContext
    let validationPolicy: StudentValidationPolicy
    let isSubmitting: Bool
    let isQueued: Bool
    let duplicateCandidateIDs: [String]
    let submissionError: String?
    let onSave: @MainActor (StudentDraft) async -> SaveOutcome

    @State private var displayName: String
    @State private var schoolID: String
    @State private var grade: String
    @State private var studentIdentifier: String
    @State private var pronouns: String
    @State private var hasDateOfBirth: Bool
    @State private var dateOfBirth: Date
    @State private var assignmentText: String
    @State private var isAwaitingServer = false
    @State private var isLocallyQueued: Bool
    @State private var isLocallyDuplicate = false
    @State private var localDuplicateCandidateIDs: [String] = []
    @AccessibilityFocusState private var isDuplicateWarningFocused: Bool

    init(
        mode: Mode,
        member: MembershipContext,
        draft: StudentDraft? = nil,
        validationPolicy: StudentValidationPolicy = .standard,
        isSubmitting: Bool = false,
        isQueued: Bool = false,
        duplicateCandidateIDs: [String] = [],
        submissionError: String? = nil,
        onSave: @escaping @MainActor (StudentDraft) async -> SaveOutcome
    ) {
        let initialDraft = draft ?? Self.initialDraft(for: mode, member: member)

        self.mode = mode
        self.member = member
        self.validationPolicy = validationPolicy
        self.isSubmitting = isSubmitting
        self.isQueued = isQueued
        self.duplicateCandidateIDs = duplicateCandidateIDs
        self.submissionError = submissionError
        self.onSave = onSave
        _displayName = State(initialValue: initialDraft.displayName)
        _schoolID = State(initialValue: initialDraft.schoolID)
        _grade = State(initialValue: initialDraft.grade)
        _studentIdentifier = State(initialValue: initialDraft.studentIdentifier ?? "")
        _pronouns = State(initialValue: initialDraft.pronouns ?? "")
        _hasDateOfBirth = State(initialValue: initialDraft.dateOfBirth != nil)
        _dateOfBirth = State(initialValue: initialDraft.dateOfBirth ?? .now)
        _assignmentText = State(
            initialValue: initialDraft.assignedMemberIDs.sorted().joined(separator: ", ")
        )
        _isLocallyQueued = State(initialValue: isQueued)
    }

    var body: some View {
        Form {
            identitySection
            optionalDetailsSection
            assignmentSection
            feedbackSection
        }
        .disabled(queued)
        .formStyle(.grouped)
        .navigationTitle(mode.title)
        .accessibilityIdentifier("studentEditor.screen")
        .safeAreaInset(edge: .bottom) {
            if !visibleDuplicateCandidateIDs.isEmpty {
                duplicateWarning
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(queued ? "Done" : "Cancel", action: dismiss.callAsFunction)
                    .disabled(submissionInFlight)
                    .accessibilityIdentifier("studentEditor.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: submit)
                    .disabled(!canSubmit || submissionInFlight || queued || duplicateLocked)
                    .accessibilityIdentifier("studentEditor.save")
            }
        }
        .interactiveDismissDisabled(submissionInFlight)
    }

    private var identitySection: some View {
        Section("Student record") {
            TextField("Student name", text: $displayName)
                .textContentType(.name)
                .accessibilityIdentifier("studentEditor.name")
            fieldError(for: .displayName)

            schoolField
            fieldError(for: .schoolID)

            TextField("Grade", text: $grade)
                .accessibilityIdentifier("studentEditor.grade")
            fieldError(for: .grade)

            TextField("Student identifier (optional)", text: $studentIdentifier)
                .textContentType(.username)
                .accessibilityIdentifier("studentEditor.identifier")
            fieldError(for: .studentIdentifier)
        }
    }

    private var schoolField: some View {
        Group {
            if member.schoolIDs.count > 1 {
                Picker("School", selection: $schoolID) {
                    Text("Select a school").tag("")
                    ForEach(member.schoolIDs.sorted(), id: \.self) { schoolID in
                        Text(schoolID).tag(schoolID)
                    }
                }
            } else if let authorizedSchoolID = member.schoolIDs.first {
                LabeledContent("School", value: authorizedSchoolID)
                    .onAppear {
                        if schoolID.isEmpty {
                            schoolID = authorizedSchoolID
                        }
                    }
            } else {
                TextField("School identifier", text: $schoolID)
            }
        }
        .accessibilityIdentifier("studentEditor.school")
    }

    private var optionalDetailsSection: some View {
        Section("Optional details") {
            TextField("Pronouns", text: $pronouns)
                .accessibilityIdentifier("studentEditor.pronouns")
            fieldError(for: .pronouns)

            Toggle("Include date of birth", isOn: $hasDateOfBirth)
                .frame(minHeight: 44)
                .accessibilityIdentifier("studentEditor.hasDateOfBirth")
            if hasDateOfBirth {
                DatePicker(
                    "Date of birth",
                    selection: $dateOfBirth,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("studentEditor.dateOfBirth")
                fieldError(for: .dateOfBirth)
            }
        }
    }

    private var assignmentSection: some View {
        Section {
            if canManageAssignments {
                TextField("Staff member IDs", text: $assignmentText, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("studentEditor.assignments")
                Text("Separate staff member IDs with commas. Access is confirmed by the server.")
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                LabeledContent("Assigned staff") {
                    Text(assignedMemberIDs.sorted().joined(separator: ", "))
                        .foregroundStyle(TMIColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityIdentifier("studentEditor.assignments.readOnly")
            }
            fieldError(for: .assignedMemberIDs)
        } header: {
            Text("Access")
        } footer: {
            Text("Only assigned and authorized staff can open this student record.")
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if !visibleDuplicateCandidateIDs.isEmpty
            || submissionError != nil
            || submissionInFlight
            || queued {
            Section("Save status") {
                if submissionInFlight {
                    LabeledContent {
                        ProgressView()
                    } label: {
                        Text("Waiting for server confirmation")
                    }
                    .accessibilityIdentifier("studentEditor.submitting")
                }

                if queued {
                    Label(
                        "Saved on this device. TMI will submit this student after you reconnect and refresh the roster.",
                        systemImage: "clock.badge.checkmark"
                    )
                    .foregroundStyle(TMIColors.infoText)
                    .accessibilityIdentifier("studentEditor.queued")
                } else if let submissionError {
                    Label(submissionError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(TMIColors.errorText)
                        .accessibilityIdentifier("studentEditor.error")
                }
            }
        }
    }

    private var duplicateWarning: some View {
        Label(
            duplicateWarningMessage,
            systemImage: "person.2.badge.gearshape"
        )
        .font(.subheadline)
        .foregroundStyle(TMIColors.warningText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(TMIColors.warningSurface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(duplicateWarningMessage)
        .accessibilityIdentifier("studentEditor.duplicates")
        .accessibilityFocused($isDuplicateWarningFocused)
    }

    private var duplicateWarningMessage: String {
        "\(visibleDuplicateCandidateIDs.count) possible duplicate record"
            + (visibleDuplicateCandidateIDs.count == 1 ? "" : "s")
            + " found. Cancel and search the roster by name or identifier before saving."
    }

    private var draft: StudentDraft {
        StudentDraft(
            displayName: displayName,
            schoolID: schoolID,
            grade: grade,
            studentIdentifier: studentIdentifier,
            dateOfBirth: hasDateOfBirth ? dateOfBirth : nil,
            pronouns: pronouns,
            assignedMemberIDs: assignedMemberIDs
        )
        .normalized
    }

    private var assignedMemberIDs: Set<String> {
        guard canManageAssignments else {
            switch mode {
            case .create:
                return [member.userID]
            case .edit(let record):
                return record.assignedMemberIDs
            }
        }

        return Set(
            assignmentText
                .split(whereSeparator: { $0 == "," || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private var validationIssues: [StudentValidation.Issue] {
        StudentValidation.issues(
            for: draft,
            districtID: member.districtID,
            policy: validationPolicy
        )
    }

    private var canSubmit: Bool {
        validationIssues.isEmpty
    }

    private var submissionInFlight: Bool {
        isSubmitting || isAwaitingServer
    }

    private var queued: Bool {
        isQueued || isLocallyQueued
    }

    private var duplicateLocked: Bool {
        isLocallyDuplicate || !visibleDuplicateCandidateIDs.isEmpty
    }

    private var visibleDuplicateCandidateIDs: [String] {
        duplicateCandidateIDs.isEmpty ? localDuplicateCandidateIDs : duplicateCandidateIDs
    }

    private var canManageAssignments: Bool {
        member.capabilities.contains(.staffManage)
            && member.capabilities.contains(.studentWriteDetail)
            && (member.role == .schoolAdministrator || member.role == .districtAdministrator)
    }

    @ViewBuilder
    private func fieldError(for field: StudentValidation.Field) -> some View {
        if let issue = validationIssues.first(where: { $0.field == field }) {
            Text(issue.message)
                .font(.footnote)
                .foregroundStyle(TMIColors.errorText)
                .accessibilityIdentifier("studentEditor.error.\(field.rawValue)")
        }
    }

    private func submit() {
        guard canSubmit, !submissionInFlight, !queued, !duplicateLocked else { return }

        isAwaitingServer = true
        let normalizedDraft = draft
        Task { @MainActor in
            let outcome = await self.onSave(normalizedDraft)
            self.isAwaitingServer = false
            switch outcome {
            case .confirmed:
                AccessibilityManager.shared.announce(
                    self.mode.confirmationAnnouncement,
                    priority: .high
                )
                self.dismiss()
            case .queued:
                self.isLocallyQueued = true
                AccessibilityManager.shared.announce(
                    "Student saved on this device for submission after reconnecting.",
                    priority: .high
                )
            case .duplicate(let candidateIDs):
                self.isLocallyDuplicate = true
                self.localDuplicateCandidateIDs = candidateIDs
                AccessibilityManager.shared.announce(
                    self.duplicateWarningMessage,
                    priority: .high
                )
                await Task.yield()
                self.isDuplicateWarningFocused = true
            case .failed:
                break
            }
        }
    }

    private static func initialDraft(
        for mode: Mode,
        member: MembershipContext
    ) -> StudentDraft {
        switch mode {
        case .create:
            return StudentDraft(
                displayName: "",
                schoolID: member.schoolIDs.count == 1 ? member.schoolIDs.first ?? "" : "",
                grade: "",
                studentIdentifier: nil,
                dateOfBirth: nil,
                pronouns: nil,
                assignedMemberIDs: [member.userID]
            )
        case .edit(let record):
            return StudentDraft(
                displayName: record.displayName,
                schoolID: record.schoolID,
                grade: record.grade,
                studentIdentifier: record.studentIdentifier,
                dateOfBirth: record.dateOfBirth,
                pronouns: record.pronouns,
                assignedMemberIDs: record.assignedMemberIDs
            )
        }
    }
}
