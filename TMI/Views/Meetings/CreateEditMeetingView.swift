//
//  CreateEditMeetingView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #7
//  Standalone view for creating/editing meetings
//

import SwiftUI
import FirebaseAuth

struct CreateEditMeetingView: View {
    let existingMeeting: Meeting?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Meeting fields
    @State private var title = ""
    @State private var description = ""
    @State private var meetingType: Meeting.MeetingType = .checkIn
    @State private var startDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var duration: TimeInterval = 1800 // 30 minutes
    @State private var location = ""

    // Participants
    @State private var participants: [MeetingParticipant] = []
    @State private var showingAddParticipant = false
    @State private var participantName = ""
    @State private var participantRole: MeetingParticipant.ParticipantRole = .teacher

    // Related students (optional)
    @State private var relatedStudentIds: [String] = []

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private let meetingService = MeetingService.shared

    init(meeting: Meeting? = nil, onSave: @escaping () -> Void) {
        self.existingMeeting = meeting
        self.onSave = onSave

        if let meeting = meeting {
            _title = State(initialValue: meeting.title)
            _description = State(initialValue: meeting.description ?? "")
            _meetingType = State(initialValue: meeting.meetingType)
            _startDate = State(initialValue: meeting.startTime)
            _duration = State(initialValue: meeting.endTime.timeIntervalSince(meeting.startTime))
            _location = State(initialValue: meeting.location ?? "")
            _participants = State(initialValue: meeting.participants)
            _relatedStudentIds = State(initialValue: meeting.relatedStudentIds)
        }
    }

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Meeting Type
                meetingTypeSection

                // Basic Info
                basicInfoSection

                // Date & Time
                dateTimeSection

                // Location
                locationSection

                // Participants
                participantsSection

                // Save Button
                saveButton
            }
            .padding()
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle(existingMeeting == nil ? "New Meeting" : "Edit Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingAddParticipant) {
            addParticipantSheet
                .tmiSheetStyle()
        }
    }

    // MARK: - Meeting Type

    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meeting Type")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Meeting.MeetingType.allCases, id: \.self) { type in
                    meetingTypeCard(type)
                }
            }
        }
    }

    private func meetingTypeCard(_ type: Meeting.MeetingType) -> some View {
        Button(action: {
            meetingType = type
            if title.isEmpty {
                title = type.rawValue
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(meetingType == type ? .white : Color(hex: type.color))

                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(meetingType == type ? .white : .white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(meetingType == type ? Color(hex: type.color) : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Meeting title", text: $title)
                    .font(.body)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSurface)
                    )
                    .foregroundColor(.white)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .font(.body)
                    .lineLimit(3...6)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSurface)
                    )
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.cyan)

                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tmiSurface)
                )

                Picker("Duration", selection: $duration) {
                    Text("15 min").tag(TimeInterval(900))
                    Text("30 min").tag(TimeInterval(1800))
                    Text("45 min").tag(TimeInterval(2700))
                    Text("1 hour").tag(TimeInterval(3600))
                    Text("1.5 hours").tag(TimeInterval(5400))
                    Text("2 hours").tag(TimeInterval(7200))
                }
                .pickerStyle(.menu)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tmiSurface)
                )
                .foregroundColor(.white)

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.white.opacity(0.6))
                    Text("Ends at")
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(endDate, style: .time)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .font(.caption)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tmiSurface)
                )
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Image(systemName: "location")
                    .foregroundColor(.cyan)

                TextField("Room number, Zoom link, etc.", text: $location)
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tmiSurface)
            )
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participants")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showingAddParticipant = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                }
            }

            if participants.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.white.opacity(0.5))
                    Text("No participants added")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tmiSurface)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(participants) { participant in
                        participantRow(participant)
                    }
                }
            }
        }
    }

    private func participantRow(_ participant: MeetingParticipant) -> some View {
        HStack {
            Image(systemName: participant.role.icon)
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(participant.role.rawValue)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: {
                participants.removeAll { $0.id == participant.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiSurface)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveMeeting) {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text(existingMeeting == nil ? "Create Meeting" : "Save Changes")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSave && !isSaving ? Color.cyan.gradient : Color.gray.gradient)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSaving)
    }

    // MARK: - Add Participant Sheet

    private var addParticipantSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Enter name", text: $participantName)
                }

                Section("Role") {
                    Picker("Role", selection: $participantRole) {
                        ForEach(MeetingParticipant.ParticipantRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        participantName = ""
                        showingAddParticipant = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let participant = MeetingParticipant(
                            userId: UUID().uuidString,
                            name: participantName,
                            role: participantRole,
                            responseStatus: .pending
                        )
                        participants.append(participant)
                        participantName = ""
                        showingAddParticipant = false
                    }
                    .disabled(participantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveMeeting() {
        guard canSave else { return }

        isSaving = true

        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "CreateEditMeeting", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                if let existingMeeting = existingMeeting {
                    // Update existing meeting
                    var updatedMeeting = existingMeeting
                    updatedMeeting.lastUpdated = Date()

                    _ = try await meetingService.updateMeeting(updatedMeeting)
                } else {
                    // Create new meeting
                    let meeting = Meeting(
                        id: nil,
                        title: title,
                        description: description.isEmpty ? nil : description,
                        startTime: startDate,
                        endTime: endDate,
                        location: location.isEmpty ? nil : location,
                        meetingType: meetingType,
                        organizer: userId,
                        participants: participants,
                        relatedStudentIds: relatedStudentIds,
                        relatedPlanId: nil,
                        status: .scheduled,
                        notes: nil,
                        completedAt: nil,
                        actionItems: [],
                        createdAt: Date(),
                        lastUpdated: Date()
                    )

                    _ = try await meetingService.scheduleMeeting(meeting)
                }

                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    print("[CreateEditMeetingView] Failed to save meeting: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CreateEditMeetingView(onSave: {})
    }
}
