//
//  MeetingDetailView.swift
//  TMI
//
//  One meeting: when and where, who is coming, its action items and notes,
//  and the two lifecycle moves a participant makes — completing or
//  cancelling it.
//

import SwiftUI

struct MeetingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.meetingsStateModel) private var meetingsStateModel

    @State private var meeting: Meeting
    @State private var notesDraft: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var confirmingCancel = false

    init(meeting: Meeting) {
        _meeting = State(initialValue: meeting)
        _notesDraft = State(initialValue: meeting.notes ?? "")
    }

    private var isOpen: Bool {
        meeting.status != .completed && meeting.status != .cancelled
    }

    private var notesChanged: Bool {
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            != (meeting.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                header
                scheduleSection
                if !meeting.participants.isEmpty { participantsSection }
                if let description = meeting.description, !description.isEmpty {
                    Section("About") {
                        Text(description)
                            .foregroundStyle(TMIColors.textPrimary)
                    }
                }
                if meeting.hasActionItems { actionItemsSection }
                notesSection
                if isOpen { lifecycleSection }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tmiScreenBackground()
            .navigationTitle("Meeting")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Couldn’t Update Meeting",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "Cancel this meeting?",
                isPresented: $confirmingCancel,
                titleVisibility: .visible
            ) {
                Button("Cancel Meeting", role: .destructive) {
                    perform { try await meetingsStateModel.cancelMeeting(meeting) }
                }
                Button("Keep Meeting", role: .cancel) {}
            } message: {
                Text("Participants will see it as cancelled.")
            }
            .disabled(isSaving)
        }
        .tmiMacSheetFrame(minWidth: 460, idealWidth: 540, minHeight: 520, idealHeight: 640)
    }

    // MARK: - Sections

    private var header: some View {
        Section {
            HStack(alignment: .top, spacing: TMISpacing.ms) {
                TMIIconTile(meeting.meetingType.icon, tone: meeting.meetingType.tone, size: 44)
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    Text(meeting.title)
                        .font(.tmiEditorial(.title2))
                        .foregroundStyle(TMIColors.textPrimary)
                    HStack(spacing: TMISpacing.sm) {
                        Text(meeting.meetingType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                        TMIStatusBadge(meeting.status.rawValue, tone: meeting.status.tone)
                    }
                }
            }
            .padding(.vertical, TMISpacing.xs)
        }
    }

    private var scheduleSection: some View {
        Section("When & where") {
            LabeledContent("Date") {
                Text(meeting.startTime, format: .dateTime.weekday(.wide).month(.wide).day().year())
            }
            LabeledContent("Time") {
                Text(meeting.timeRange)
            }
            LabeledContent("Duration", value: "\(meeting.durationMinutes) min")
            if let location = meeting.location, !location.isEmpty {
                LabeledContent("Location", value: location)
            }
        }
    }

    private var participantsSection: some View {
        Section("Participants") {
            ForEach(meeting.participants) { participant in
                HStack(spacing: TMISpacing.ms) {
                    TMIAvatar(initials: Self.initials(for: participant.name), size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.name)
                            .foregroundStyle(TMIColors.textPrimary)
                        Text(participant.role.rawValue)
                            .font(.footnote)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                    Spacer()
                    TMIStatusBadge(participant.responseStatus.rawValue, tone: participant.responseStatus.tone)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var actionItemsSection: some View {
        Section {
            ForEach(meeting.actionItems) { item in
                Button {
                    toggle(item)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: TMISpacing.ms) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? TMIColors.successText : TMIColors.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .foregroundStyle(item.isCompleted ? TMIColors.textSecondary : TMIColors.textPrimary)
                                .strikethrough(item.isCompleted, color: TMIColors.textTertiary)
                            if let due = item.dueDate {
                                Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.footnote)
                                    .foregroundStyle(
                                        !item.isCompleted && due < .now ? TMIColors.errorText : TMIColors.textTertiary
                                    )
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item.isCompleted ? .isSelected : [])
            }
        } header: {
            Text("Action items")
        } footer: {
            Text("\(meeting.completedActionItemsCount) of \(meeting.actionItems.count) done")
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("What was discussed or decided", text: $notesDraft, axis: .vertical)
                .lineLimit(3...10)
            if notesChanged {
                Button("Save Notes") {
                    let notes = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    perform { try await meetingsStateModel.addNotes(to: meeting, notes: notes) }
                }
            }
        }
    }

    private var lifecycleSection: some View {
        Section {
            Button("Mark as Completed", systemImage: "checkmark.seal") {
                perform { try await meetingsStateModel.markAsCompleted(meeting) }
            }
            Button("Cancel Meeting", systemImage: "xmark.circle", role: .destructive) {
                confirmingCancel = true
            }
            .foregroundStyle(TMIColors.errorText)
        }
    }

    private static func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }

    // MARK: - Writes

    private func toggle(_ item: ActionItem) {
        var updated = meeting
        guard let index = updated.actionItems.firstIndex(where: { $0.id == item.id }) else { return }
        updated.actionItems[index].isCompleted.toggle()
        updated.actionItems[index].completedAt = updated.actionItems[index].isCompleted ? .now : nil
        updated.lastUpdated = .now
        perform { try await meetingsStateModel.updateMeeting(updated) }
    }

    private func perform(_ write: @escaping () async throws -> Meeting) {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let saved = try await write()
                meeting = saved
                notesDraft = saved.notes ?? ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension MeetingParticipant.ResponseStatus {
    var tone: TMITone {
        switch self {
        case .pending: .neutral
        case .accepted: .success
        case .declined: .danger
        case .tentative: .warning
        }
    }
}

#Preview {
    MeetingDetailView(meeting: Meeting.sampleMeeting)
}
