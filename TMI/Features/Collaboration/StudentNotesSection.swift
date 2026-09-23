import SwiftUI

/// Team notes for one student, plus restricted records for staff with the
/// restricted capabilities. Restricted records stay hidden until requested,
/// because every read is audited.
struct StudentNotesSection: View {
    let districtID: String
    let studentID: String
    let member: MembershipContext?
    var repository: (any CollaborationRepository)? = nil

    @Environment(\.syncCoordinator) private var sync
    @State private var notes: [TeamNote] = []
    @State private var canWrite = false
    @State private var names: [String: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editing: NoteEditorTarget?
    @State private var restricted: [RestrictedRecord]?
    @State private var restrictedError: String?
    @State private var isAddingRestricted = false

    private var resolved: any CollaborationRepository { repository ?? FirebaseCollaborationRepository() }
    private var canReadRestricted: Bool { member?.capabilities.contains(.studentRestrictedRead) == true }
    private var canWriteRestricted: Bool { member?.capabilities.contains(.studentRestrictedWrite) == true }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Team notes").font(.headline)
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                if canWrite {
                    Button("Add note", systemImage: "square.and.pencil") { editing = .new }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("studentNotes.add")
                }
            }

            PendingSyncList(prefixes: [SyncAggregate.notes(studentID: studentID)])

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(TMIColors.errorText)
                Button("Try again") { Task { await load() } }.buttonStyle(.bordered)
            } else if notes.isEmpty, !isLoading {
                Text("No notes yet. Notes are visible to staff who can see this student's record.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            }

            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    HStack {
                        Text(note.category.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TMIColors.aubergine)
                        Spacer()
                        if note.isAuthor {
                            Button("Edit") { editing = .existing(note) }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                    Text(note.body).font(.body)
                    Text(byline(note))
                        .font(.caption)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                .padding(TMISpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
                .overlay { RoundedRectangle(cornerRadius: TMIRadius.md).stroke(TMIColors.border, lineWidth: 1) }
                .accessibilityElement(children: .combine)
            }

            if canReadRestricted || canWriteRestricted {
                restrictedSection
            }
        }
        .task(id: "\(districtID)/\(studentID)") { await load() }
        .sheet(item: $editing) { target in
            NoteEditorSheet(target: target) { category, body in
                let existing: TeamNote? = if case .existing(let note) = target { note } else { nil }
                let payload = NoteSyncPayload(
                    districtID: districtID, studentID: studentID, noteID: existing?.noteID,
                    category: category, body: body, expectedRecordVersion: existing?.recordVersion ?? 0
                )
                let result = try await sync.perform(
                    .saveNote,
                    aggregateKey: SyncAggregate.note(studentID: studentID, noteID: existing?.noteID),
                    summary: existing == nil ? "New note: \(body.prefix(60))" : "Edited note: \(body.prefix(60))",
                    districtID: districtID,
                    payload: payload
                ) { operationID in
                    try await resolved.saveNote(
                        districtID: payload.districtID, studentID: payload.studentID, noteID: payload.noteID,
                        category: payload.category, body: payload.body,
                        expectedRecordVersion: payload.expectedRecordVersion, operationID: operationID
                    )
                }
                if result == .sent { await load() }
            }
        }
        .sheet(isPresented: $isAddingRestricted) {
            NoteEditorSheet(target: .new, isRestricted: true) { category, body in
                // Restricted records are online-only: they are never kept on the device.
                try await resolved.createRestrictedRecord(districtID: districtID, studentID: studentID, category: category.rawValue, body: body)
                if restricted != nil { await loadRestricted() }
            }
        }
    }

    private var restrictedSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack {
                Label("Restricted records", systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                if canWriteRestricted {
                    Button("Add", systemImage: "plus") { isAddingRestricted = true }
                        .buttonStyle(.bordered)
                }
            }
            Text("Kept separately from team notes. Opening them is recorded in the audit log.")
                .font(.caption)
                .foregroundStyle(TMIColors.textSecondary)
            if let restrictedError {
                Label(restrictedError, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText)
            }
            if let restricted {
                if restricted.isEmpty {
                    Text("No restricted records.").foregroundStyle(TMIColors.textSecondary)
                }
                ForEach(restricted) { record in
                    VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                        Text(record.category.capitalized).font(.caption.weight(.semibold))
                        Text(record.body)
                        Text(record.createdAt.flatMap(FormDates.parse)?.formatted(date: .abbreviated, time: .shortened) ?? "")
                            .font(.caption)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                    .padding(TMISpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TMIColors.warningSurface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
                }
                Button("Hide restricted records") { self.restricted = nil }
                    .buttonStyle(.borderless)
            } else if canReadRestricted {
                Button("Show restricted records", systemImage: "eye") { Task { await loadRestricted() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("studentNotes.showRestricted")
            }
        }
        .padding(TMISpacing.md)
        .overlay { RoundedRectangle(cornerRadius: TMIRadius.md).stroke(TMIColors.warningText.opacity(0.4), lineWidth: 1) }
    }

    private func byline(_ note: TeamNote) -> String {
        let author = note.isAuthor ? "You" : (names[note.authorUserID] ?? "A colleague")
        let date = note.createdAt.flatMap(FormDates.parse)?.formatted(date: .abbreviated, time: .shortened) ?? ""
        return note.revisionCount > 0 ? "\(author) · \(date) · edited" : "\(author) · \(date)"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await resolved.notes(districtID: districtID, studentID: studentID)
            notes = result.notes
            canWrite = result.canWrite
            errorMessage = nil
            if names.isEmpty, notes.contains(where: { !$0.isAuthor }) {
                let colleagues = (try? await resolved.colleagues(districtID: districtID, studentID: studentID)) ?? []
                names = Dictionary(colleagues.map { ($0.userID, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            }
        } catch {
            errorMessage = CollaborationError.map(error).localizedDescription
        }
    }

    private func loadRestricted() async {
        do {
            restricted = try await resolved.restrictedRecords(districtID: districtID, studentID: studentID)
            restrictedError = nil
        } catch {
            restrictedError = CollaborationError.map(error).localizedDescription
        }
    }
}

enum NoteEditorTarget: Identifiable {
    case new
    case existing(TeamNote)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let note): note.noteID
        }
    }
}

struct NoteEditorSheet: View {
    let target: NoteEditorTarget
    var isRestricted = false
    let onSave: @MainActor (NoteCategory, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: NoteCategory = .general
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(NoteCategory.allCases) { Text($0.displayName).tag($0) }
                }
                Section {
                    TextField("What happened, what you noticed, what's next", text: $text, axis: .vertical)
                        .lineLimit(5...14)
                        .accessibilityIdentifier("noteEditor.body")
                } footer: {
                    Text(isRestricted
                        ? "Only staff with restricted-record access can read this, and each read is audited."
                        : "Visible to staff who can see this student. Edits keep the earlier version.")
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isRestricted ? "Restricted record" : (isNew ? "New note" : "Edit note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                try await onSave(category, text)
                                dismiss()
                            } catch {
                                errorMessage = CollaborationError.map(error).localizedDescription
                            }
                        }
                    }
                    .disabled(isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if case .existing(let note) = target {
                    category = note.category
                    text = note.body
                }
            }
        }
        .tmiSheetStyle()
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }
}
