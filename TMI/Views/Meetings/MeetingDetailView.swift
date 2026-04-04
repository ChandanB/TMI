//
//  MeetingDetailView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #7
//  Detailed view of a meeting with notes and action items
//

import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentMeeting: Meeting
    @State private var notes: String
    @State private var showingAddActionItem = false
    @State private var isProcessing = false

    private let meetingService = MeetingService.shared

    init(meeting: Meeting, onUpdate: @escaping () -> Void) {
        self.meeting = meeting
        self.onUpdate = onUpdate
        _currentMeeting = State(initialValue: meeting)
        _notes = State(initialValue: meeting.notes ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                meetingHeader

                // Details
                meetingDetails

                // Participants
                if !currentMeeting.participants.isEmpty {
                    participantsSection
                }

                // Notes
                notesSection

                // Action Items
                actionItemsSection

                // Actions
                if currentMeeting.status != .completed && currentMeeting.status != .cancelled {
                    actionsSection
                }
            }
            .padding()
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Meeting Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddActionItem) {
            AddActionItemSheet(onSave: { actionItem in
                Task { await addActionItem(actionItem) }
            })
            .tmiSheetStyle()
        }
    }

    // MARK: - Meeting Header

    private var meetingHeader: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: currentMeeting.meetingType.icon)
                        .font(.title)
                        .foregroundStyle(Color(hex: currentMeeting.meetingType.color).gradient)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentMeeting.title)
                            .font(.title2.bold())
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(currentMeeting.meetingType.rawValue)
                            .font(.caption)
                            .foregroundColor(Color.tmiTextSecondary)
                    }

                    Spacer()

                    MeetingStatusBadge(status: currentMeeting.status)
                }

                if let description = currentMeeting.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(Color.tmiTextSecondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Meeting Details

    private var meetingDetails: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                DetailRow(
                    icon: "calendar",
                    title: "Date",
                    value: currentMeeting.startTime.formatted(date: .complete, time: .omitted)
                )

                DetailRow(
                    icon: "clock",
                    title: "Time",
                    value: "\(currentMeeting.startTime.formatted(date: .omitted, time: .shortened)) - \(currentMeeting.endTime.formatted(date: .omitted, time: .shortened)) (\(currentMeeting.durationMinutes) min)"
                )

                if let location = currentMeeting.location {
                    DetailRow(
                        icon: "location.fill",
                        title: "Location",
                        value: location
                    )
                }

                if let completedAt = currentMeeting.completedAt {
                    DetailRow(
                        icon: "checkmark.circle.fill",
                        title: "Completed",
                        value: completedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants (\(currentMeeting.participants.count))")
                .font(.title3.bold())
                .foregroundColor(Color.tmiTextPrimary)

            TMIGlassCard(style: .default) {
                VStack(spacing: 12) {
                    ForEach(Array(currentMeeting.participants.enumerated()), id: \.element.id) { index, participant in
                        HStack {
                            Image(systemName: participant.role.icon)
                                .foregroundColor(.cyan)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                    .font(.subheadline)
                                    .foregroundColor(Color.tmiTextPrimary)

                                Text(participant.role.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(Color.tmiTextSecondary)
                            }

                            Spacer()

                            Circle()
                                .fill(Color(hex: participant.responseStatus.color))
                                .frame(width: 8, height: 8)
                        }

                        if index < currentMeeting.participants.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.title3.bold())
                .foregroundColor(Color.tmiTextPrimary)

            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Add meeting notes...", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundColor(Color.tmiTextPrimary)
                        .lineLimit(5...10)

                    if notes != (currentMeeting.notes ?? "") {
                        Button(action: saveNotes) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Notes")
                            }
                            .font(.caption.bold())
                            .foregroundColor(Color.tmiTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.cyan.gradient)
                            .cornerRadius(8)
                        }
                        .disabled(isProcessing)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Action Items (\(currentMeeting.actionItems.count))")
                    .font(.title3.bold())
                    .foregroundColor(Color.tmiTextPrimary)

                Spacer()

                Button(action: { showingAddActionItem = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                }
            }

            if currentMeeting.actionItems.isEmpty {
                TMIGlassCard(style: .default) {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundColor(Color.tmiTextTertiary)

                        Text("No action items yet")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(currentMeeting.actionItems) { actionItem in
                        ActionItemCard(
                            actionItem: actionItem,
                            onToggle: { Task { await toggleActionItem(actionItem.itemId) } },
                            onDelete: { Task { await deleteActionItem(actionItem.itemId) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: completeMeeting) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Mark as Complete")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.gradient)
                .foregroundColor(Color.tmiTextPrimary)
                .cornerRadius(12)
                .font(.headline)
            }
            .disabled(isProcessing)

            HStack(spacing: 12) {
                Button(action: cancelMeeting) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.gradient)
                    .foregroundColor(Color.tmiTextPrimary)
                    .cornerRadius(12)
                    .font(.subheadline.bold())
                }
                .disabled(isProcessing)

                Button(action: deleteMeeting) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.gradient)
                    .foregroundColor(Color.tmiTextPrimary)
                    .cornerRadius(12)
                    .font(.subheadline.bold())
                }
                .disabled(isProcessing)
            }
        }
    }

    // MARK: - Actions

    private func saveNotes() {
        isProcessing = true

        Task {
            do {
                try await meetingService.completeMeeting(currentMeeting.id!, notes: notes)
                await MainActor.run {
                    currentMeeting.notes = notes
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("[MeetingDetailView] Failed to save notes: \(error)")
            }
        }
    }

    private func completeMeeting() {
        isProcessing = true

        Task {
            do {
                try await meetingService.completeMeeting(currentMeeting.id!, notes: notes)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("[MeetingDetailView] Failed to complete meeting: \(error)")
            }
        }
    }

    private func cancelMeeting() {
        isProcessing = true

        Task {
            do {
                try await meetingService.cancelMeeting(currentMeeting.id!)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("[MeetingDetailView] Failed to cancel meeting: \(error)")
            }
        }
    }

    private func deleteMeeting() {
        isProcessing = true

        Task {
            do {
                try await meetingService.deleteMeeting(currentMeeting.id!)
                await MainActor.run {
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("[MeetingDetailView] Failed to delete meeting: \(error)")
            }
        }
    }

    private func addActionItem(_ actionItem: ActionItem) async {
        do {
            try await meetingService.addActionItem(to: currentMeeting.id!, actionItem: actionItem)
            await MainActor.run {
                currentMeeting.actionItems.append(actionItem)
            }
        } catch {
            print("[MeetingDetailView] Failed to add action item: \(error)")
        }
    }

    private func toggleActionItem(_ itemId: String) async {
        do {
            try await meetingService.toggleActionItemCompletion(
                meetingId: currentMeeting.id!,
                actionItemId: itemId,
                currentMeeting: currentMeeting
            )
            await MainActor.run {
                if let index = currentMeeting.actionItems.firstIndex(where: { $0.itemId == itemId }) {
                    currentMeeting.actionItems[index].isCompleted.toggle()
                    currentMeeting.actionItems[index].completedAt = currentMeeting.actionItems[index].isCompleted ? Date() : nil
                }
            }
        } catch {
            print("[MeetingDetailView] Failed to toggle action item: \(error)")
        }
    }

    private func deleteActionItem(_ itemId: String) async {
        do {
            try await meetingService.deleteActionItem(
                from: currentMeeting.id!,
                actionItemId: itemId,
                currentMeeting: currentMeeting
            )
            await MainActor.run {
                currentMeeting.actionItems.removeAll { $0.itemId == itemId }
            }
        } catch {
            print("[MeetingDetailView] Failed to delete action item: \(error)")
        }
    }
}

// MARK: - Supporting Views

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.tmiTextSecondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextPrimary)
            }

            Spacer()
        }
    }
}

private struct MeetingStatusBadge: View {
    let status: Meeting.MeetingStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.bold())
            .foregroundColor(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .cornerRadius(12)
    }

    private var statusColor: Color {
        switch status {
        case .scheduled: return .orange
        case .confirmed: return .cyan
        case .completed: return .green
        case .cancelled: return .red
        case .rescheduled: return .yellow
        }
    }
}

private struct ActionItemCard: View {
    let actionItem: ActionItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TMIGlassCard(style: .default) {
            HStack(alignment: .top) {
                Button(action: onToggle) {
                    Image(systemName: actionItem.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(actionItem.isCompleted ? .green : Color.tmiTextTertiary)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(actionItem.description)
                        .font(.subheadline)
                        .foregroundColor(Color.tmiTextPrimary)
                        .strikethrough(actionItem.isCompleted)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: actionItem.priority.icon)
                            Text(actionItem.priority.rawValue)
                        }
                        .font(.caption2)
                        .foregroundColor(Color(hex: actionItem.priority.color))

                        if let dueDate = actionItem.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            }
                            .font(.caption2)
                            .foregroundColor(actionItem.isOverdue ? .orange : Color.tmiTextSecondary)
                        }

                        if actionItem.isCompleted, let completedAt = actionItem.completedAt {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text(completedAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                }
            }
            .padding()
        }
    }
}

private struct AddActionItemSheet: View {
    let onSave: (ActionItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var priority: ActionItem.ActionItemPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400 * 7) // 1 week from now

    var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("What needs to be done?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(ActionItem.ActionItemPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let actionItem = ActionItem(
                            description: description,
                            dueDate: hasDueDate ? dueDate : nil,
                            priority: priority
                        )
                        onSave(actionItem)
                        dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingDetailView(meeting: .sampleMeeting, onUpdate: {})
    }
}
