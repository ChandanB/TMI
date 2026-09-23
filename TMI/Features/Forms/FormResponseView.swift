import SwiftUI

/// Completes or reviews one student's response to one form. Staff can hand
/// the device to the family or the student: the screen then shows only this
/// form, and returning to the staff app requires the device owner's
/// authentication.
struct FormResponseView: View {
    let studentName: String
    let summary: StudentFormSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncCoordinator) private var sync
    @State private var session: FormResponseSession
    @State private var isHandedOff = false
    @State private var handoffMessage: String?
    @State private var reviewOutcome: FormReviewOutcome = .accepted
    @State private var reviewComment = ""

    init(
        districtID: String,
        studentID: String,
        studentName: String,
        summary: StudentFormSummary,
        repository: any FormResponseRepository
    ) {
        self.studentName = studentName
        self.summary = summary
        _session = State(initialValue: FormResponseSession(
            districtID: districtID,
            assignmentID: summary.assignmentID,
            studentID: studentID,
            repository: repository
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(summary.templateName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .tmiSheetStyle()
        .interactiveDismissDisabled(isHandedOff || session.isSubmitting)
        .task {
            session.sync = sync
            await session.load()
        }
        .alert(
            "Couldn't complete that",
            isPresented: Binding(get: { session.actionError != nil }, set: { if !$0 { session.actionError = nil } }),
            presenting: session.actionError
        ) { error in
            if error == .conflict {
                Button("Reload") { Task { await session.load() } }
            }
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .loading:
            ProgressView("Loading form…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            ContentUnavailableView {
                Label("Form unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try again") { Task { await session.load() } }
            }
        case .ready:
            if let document = session.document {
                form(document)
            }
        }
    }

    private func form(_ document: FormResponseDocument) -> some View {
        Form {
            header(document)

            if session.isEditable, !isHandedOff {
                Section {
                    Picker("Who is completing this?", selection: $session.respondentType) {
                        ForEach(FormRespondentType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if session.respondentType != .staff {
                        Button("Hand the device over", systemImage: "hand.raised") { isHandedOff = true }
                            .disabled(!FamilyHandoffLock.isAvailable)
                        if !FamilyHandoffLock.isAvailable {
                            Text("Set a device passcode to lock the hand-off, or complete the form yourself.")
                                .font(.footnote)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                    }
                } footer: {
                    Text("During a hand-off only this form is visible; returning to the staff app needs your passcode or Face ID.")
                }
            }

            ForEach(sections(of: document), id: \.title) { section in
                Section(section.title) {
                    ForEach(section.fields) { field in
                        FormFieldEditor(
                            field: field,
                            value: session.answer(for: field.key),
                            isEditable: session.isEditable
                        ) { session.setAnswer($0, for: field.key) }
                    }
                }
            }

            if session.isEditable {
                submitSection
            }

            if document.state.isFrozen, !isHandedOff {
                reviewSection(document)
            }

            if let handoffMessage {
                Section { Text(handoffMessage).foregroundStyle(TMIColors.textSecondary) }
            }
        }
        .formStyle(.grouped)
    }

    private func header(_ document: FormResponseDocument) -> some View {
        Section {
            if isHandedOff {
                Text("This form is about \(studentName). Answer what you can — only required questions must be filled in.")
            } else {
                LabeledContent("Student", value: studentName)
                LabeledContent("Status", value: document.state.displayName)
                if let submittedAt = document.submittedAt.flatMap(FormDates.parse) {
                    LabeledContent("Submitted", value: submittedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let scoring = document.scoring {
                    LabeledContent("Score", value: scoring.summary)
                        .accessibilityIdentifier("formResponse.score")
                }
                if let respondent = document.respondentType, document.state.isFrozen {
                    LabeledContent("Completed by", value: respondent == .staff ? "Staff" : respondent == .family ? "Family" : "Student")
                }
            }
            if let instructions = document.instructions, !instructions.isEmpty {
                Text(instructions).font(.callout).foregroundStyle(TMIColors.textSecondary)
            }
        }
    }

    private var submitSection: some View {
        Section {
            if !session.missingRequired.isEmpty {
                Label("\(session.missingRequired.count) required \(session.missingRequired.count == 1 ? "question" : "questions") left", systemImage: "exclamationmark.circle")
                    .foregroundStyle(TMIColors.warningText)
            }
            Button {
                Task {
                    if await session.submit(), isHandedOff {
                        handoffMessage = "Thank you! Please hand the device back."
                        returnToStaff()
                    }
                }
            } label: {
                Label(session.isSubmitting ? "Submitting…" : "Submit", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(TMIColors.teal)
            .disabled(!session.canSubmit)
            .accessibilityIdentifier("formResponse.submit")
        } footer: {
            Text("Answers save automatically. After submitting, they can't be changed.")
        }
    }

    @ViewBuilder
    private func reviewSection(_ document: FormResponseDocument) -> some View {
        if let review = document.review {
            Section("Review") {
                LabeledContent("Outcome", value: FormReviewOutcome(rawValue: review.outcome)?.displayName ?? review.outcome)
                if let comment = review.comment { Text(comment) }
                if let reviewedAt = review.reviewedAt.flatMap(FormDates.parse) {
                    LabeledContent("Reviewed", value: reviewedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        Section(document.review == nil ? "Review this response" : "Update the review") {
            Picker("Outcome", selection: $reviewOutcome) {
                ForEach(FormReviewOutcome.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            TextField("Comment (optional)", text: $reviewComment, axis: .vertical)
                .lineLimit(2...5)
            Button(session.isReviewing ? "Saving review…" : "Save review") {
                Task {
                    if await session.review(outcome: reviewOutcome, comment: reviewComment) {
                        reviewComment = ""
                    }
                }
            }
            .disabled(session.isReviewing)
            .accessibilityIdentifier("formResponse.review")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isHandedOff {
            ToolbarItem(placement: .cancellationAction) {
                Button("Return to staff", systemImage: "lock") { returnToStaff() }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    Task {
                        await session.saveDraftNow()
                        dismiss()
                    }
                }
                .disabled(session.isSubmitting)
            }
            ToolbarItem(placement: .status) {
                saveIndicator
            }
        }
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch session.saveStatus {
        case .idle: EmptyView()
        case .saving: Label("Saving…", systemImage: "arrow.triangle.2.circlepath").labelStyle(.titleAndIcon).font(.caption)
        case .saved: Label("Saved", systemImage: "checkmark.icloud").font(.caption)
        case .savedOnDevice: Label("Saved on this device", systemImage: "icloud.slash").font(.caption).foregroundStyle(TMIColors.warningText)
        case .failed: Label("Not saved", systemImage: "exclamationmark.icloud").font(.caption).foregroundStyle(TMIColors.errorText)
        }
    }

    private func returnToStaff() {
        Task {
            guard await FamilyHandoffLock.authenticateStaff() else {
                handoffMessage = "Staff authentication is required to leave this form."
                return
            }
            isHandedOff = false
        }
    }

    private struct FieldGroup {
        let title: String
        let fields: [FormFieldDescriptor]
    }

    private func sections(of document: FormResponseDocument) -> [FieldGroup] {
        var groups: [FieldGroup] = []
        for field in document.fields {
            let title = field.sectionTitle.isEmpty ? "Questions" : field.sectionTitle
            if let last = groups.last, last.title == title {
                groups[groups.count - 1] = FieldGroup(title: title, fields: last.fields + [field])
            } else {
                groups.append(FieldGroup(title: title, fields: [field]))
            }
        }
        return groups
    }
}

/// Renders one field by type. Values are strings, numbers, or yes/no so the
/// server can validate them against the template.
struct FormFieldEditor: View {
    let field: FormFieldDescriptor
    let value: FormAnswerValue?
    let isEditable: Bool
    let onChange: (FormAnswerValue?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            Text(field.label + (field.isRequired && field.isAnswerable ? " *" : ""))
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(field.isRequired ? "\(field.label), required" : field.label)
            editor
                .disabled(!isEditable)
        }
        .padding(.vertical, TMISpacing.xxs)
    }

    @ViewBuilder
    private var editor: some View {
        if !field.isAnswerable {
            Text("This question type can't be completed in the app.")
                .font(.footnote)
                .foregroundStyle(TMIColors.textSecondary)
        } else {
            switch field.type {
            case "longText":
                TextField("Answer", text: textBinding, axis: .vertical).lineLimit(3...8)
            case "number":
                TextField("Number", text: numberBinding)
                    .keyboardType(.decimalPad)
            case "checkbox":
                Toggle("Yes", isOn: Binding(
                    get: { if case .flag(let flag) = value { return flag }; return false },
                    set: { onChange(.flag($0)) }
                ))
            case "dropdown", "multipleChoice":
                Picker("Choose one", selection: Binding(
                    get: { if case .text(let text) = value { return text }; return "" },
                    set: { onChange($0.isEmpty ? nil : .text($0)) }
                )) {
                    Text("Choose…").tag("")
                    ForEach(field.options, id: \.self) { Text($0).tag($0) }
                }
            case "Rating":
                HStack(spacing: TMISpacing.sm) {
                    ForEach(1...5, id: \.self) { score in
                        let selected = currentRating == score
                        Button("\(score)") { onChange(.number(Double(score))) }
                            .buttonStyle(.bordered)
                            .tint(selected ? TMIColors.teal : TMIColors.interactiveBorder)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityLabel("\(score) of 5")
                    }
                }
            case "date", "dateTime", "time":
                DatePicker(
                    "Choose",
                    selection: Binding(
                        get: { dateValue ?? .now },
                        set: { onChange(.text(ISO8601DateFormatter().string(from: $0))) }
                    ),
                    displayedComponents: field.type == "date" ? .date : field.type == "time" ? .hourAndMinute : [.date, .hourAndMinute]
                )
                .labelsHidden()
            case "Signature":
                TextField("Type your full name", text: textBinding)
            case "email":
                TextField("Email", text: textBinding)
                    .keyboardType(.emailAddress)
                    .tmiTextInputAutocapitalization(.never)
            case "phoneNumber":
                TextField("Phone", text: textBinding).keyboardType(.phonePad)
            case "url":
                TextField("Link", text: textBinding)
                    .keyboardType(.URL)
                    .tmiTextInputAutocapitalization(.never)
            default:
                TextField("Answer", text: textBinding)
            }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { if case .text(let text) = value { return text }; return "" },
            set: { onChange($0.isEmpty ? nil : .text($0)) }
        )
    }

    private var numberBinding: Binding<String> {
        Binding(
            get: {
                guard case .number(let number) = value else { return "" }
                return number.rounded() == number ? String(Int(number)) : String(number)
            },
            set: { text in
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                onChange(trimmed.isEmpty ? nil : Double(trimmed).map(FormAnswerValue.number))
            }
        )
    }

    private var currentRating: Int? {
        if case .number(let number) = value { return Int(number) }
        return nil
    }

    private var dateValue: Date? {
        if case .text(let text) = value { return FormDates.parse(text) }
        return nil
    }
}
