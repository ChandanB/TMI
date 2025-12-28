//
//  ScheduleMeetingView.swift
//  TMI
//
//  Meeting scheduling interface for TMI Plans
//

import SwiftUI
import FirebaseAuth

struct ScheduleMeetingView: View {
    let planId: String
    let relatedStudentIds: [String]
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Meeting details
    @State private var title = ""
    @State private var description = ""
    @State private var meetingType: Meeting.MeetingType = .checkIn
    @State private var startDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var duration: TimeInterval = 1800 // 30 minutes
    @State private var location = ""
    @State private var notes = ""

    // Participants
    @State private var participantName = ""
    @State private var participantRole: MeetingParticipant.ParticipantRole = .teacher
    @State private var participants: [MeetingParticipant] = []
    @State private var showingAddParticipant = false

    // State
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // Header
                    headerSection
                        .padding(.top, TMISpacing.lg)

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

                    // Notes
                    notesSection

                    // Save Button
                    saveButton
                        .padding(.bottom, TMISpacing.xl)
                }
            }
        }
        .navigationTitle("Schedule Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error Scheduling Meeting", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingAddParticipant) {
            addParticipantSheet
        }
        .onAppear {
            // Pre-fill title based on meeting type
            updateTitleForMeetingType()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: TMISpacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.tmiPrimary)

            Text("Schedule a Meeting")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)

            Text("Coordinate check-ins and reviews for your TMI Plan")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TMISpacing.xl)
        }
    }

    // MARK: - Meeting Type

    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            sectionHeader("Meeting Type")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: TMISpacing.sm) {
                ForEach(Meeting.MeetingType.allCases, id: \.self) { type in
                    meetingTypeCard(type)
                }
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    private func meetingTypeCard(_ type: Meeting.MeetingType) -> some View {
        Button(action: {
            meetingType = type
            updateTitleForMeetingType()
            TMIHaptics.lightImpact()
        }) {
            VStack(spacing: TMISpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(meetingType == type ? .white : Color(hex: type.color))

                Text(type.rawValue)
                    .font(.tmiCaption)
                    .fontWeight(.medium)
                    .foregroundColor(meetingType == type ? .white : .tmiTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(meetingType == type ? Color(hex: type.color) : Color.tmiSurface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            sectionHeader("Meeting Details")

            VStack(spacing: TMISpacing.md) {
                // Title
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    Text("Title")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)

                    TextField("Enter meeting title", text: $title)
                        .font(.tmiBody)
                        .padding(TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                .fill(Color.tmiSurface)
                        )
                }

                // Description
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    Text("Description (Optional)")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)

                    TextField("Add meeting description", text: $description, axis: .vertical)
                        .font(.tmiBody)
                        .lineLimit(3...6)
                        .padding(TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                .fill(Color.tmiSurface)
                        )
                }
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            sectionHeader("When")

            VStack(spacing: TMISpacing.md) {
                // Start Date & Time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.tmiPrimary)

                    DatePicker("Start Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .font(.tmiBody)
                }
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .fill(Color.tmiSurface)
                )

                // Duration
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    Text("Duration")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)

                    Picker("Duration", selection: $duration) {
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("45 minutes").tag(TimeInterval(2700))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                    }
                    .pickerStyle(.menu)
                    .font(.tmiBody)
                    .padding(TMISpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: TMIRadius.sm)
                            .fill(Color.tmiSurface)
                    )
                }

                // End Time Display
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.tmiTextSecondary)
                    Text("Ends at")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                    Spacer()
                    Text(endDate, style: .time)
                        .font(.tmiBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.tmiTextPrimary)
                }
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .fill(Color.tmiSurface)
                )
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            sectionHeader("Location")

            HStack {
                Image(systemName: "location")
                    .foregroundColor(.tmiPrimary)

                TextField("Room number, Zoom link, etc.", text: $location)
                    .font(.tmiBody)
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.sm)
                    .fill(Color.tmiSurface)
            )
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                sectionHeader("Participants")
                Spacer()
                Button(action: {
                    showingAddParticipant = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.tmiCaption)
                    .foregroundColor(.tmiPrimary)
                }
            }

            if participants.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                    .foregroundColor(.tmiTextTertiary)
                    Text("No participants added yet")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                    Spacer()
                }
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .fill(Color.tmiSurface)
                )
            } else {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(participants) { participant in
                        participantRow(participant)
                    }
                }
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    private func participantRow(_ participant: MeetingParticipant) -> some View {
        HStack {
            Image(systemName: participant.role.icon)
                .foregroundColor(.tmiPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextPrimary)

                Text(participant.role.rawValue)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()

            Button(action: {
                participants.removeAll { $0.id == participant.id }
                TMIHaptics.lightImpact()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.tmiTextTertiary)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm)
                .fill(Color.tmiSurface)
        )
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            sectionHeader("Notes (Optional)")

            TextField("Add any additional notes or agenda items", text: $notes, axis: .vertical)
                .font(.tmiBody)
                .lineLimit(3...6)
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .fill(Color.tmiSurface)
                )
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: scheduleMeeting) {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Schedule Meeting")
                        .fontWeight(.semibold)
                }
            }
            .font(.tmiBody)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(canSave && !isSaving ? Color.tmiPrimary : Color.tmiTextTertiary)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, TMISpacing.screenPadding)
    }

    // MARK: - Add Participant Sheet

    private var addParticipantSheet: some View {
        NavigationStack {
            ZStack {
                Color.tmiBackground
                    .ignoresSafeArea()

                VStack(spacing: TMISpacing.lg) {
                    VStack(alignment: .leading, spacing: TMISpacing.xs) {
                        Text("Name")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)

                        TextField("Enter participant name", text: $participantName)
                            .font(.tmiBody)
                            .padding(TMISpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: TMIRadius.sm)
                                    .fill(Color.tmiSurface)
                            )
                    }

                    VStack(alignment: .leading, spacing: TMISpacing.xs) {
                        Text("Role")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)

                        Picker("Role", selection: $participantRole) {
                            ForEach(MeetingParticipant.ParticipantRole.allCases, id: \.self) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.tmiBody)
                        .padding(TMISpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                .fill(Color.tmiSurface)
                        )
                    }

                    Spacer()
                }
                .padding(TMISpacing.screenPadding)
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
                        TMIHaptics.lightImpact()
                    }
                    .disabled(participantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.tmiBody)
            .fontWeight(.semibold)
            .foregroundColor(.tmiTextPrimary)
    }

    // MARK: - Actions

    private func updateTitleForMeetingType() {
        // Pre-fill title if empty
        if title.isEmpty {
            title = meetingType.rawValue
        }
    }

    private func scheduleMeeting() {
        guard canSave else { return }

        isSaving = true

        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "ScheduleMeeting", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

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
                    relatedPlanId: planId,
                    status: .scheduled,
                    notes: notes.isEmpty ? nil : notes,
                    completedAt: nil,
                    actionItems: [], // Action items can be added after meeting is created
                    createdAt: Date(),
                    lastUpdated: Date()
                )

                _ = try await MeetingService.shared.scheduleMeeting(meeting)

                await MainActor.run {
                    isSaving = false
                    TMIHaptics.success()
                    onComplete?()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                    showingError = true
                    print("[ERROR] Failed to schedule meeting: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScheduleMeetingView(
            planId: "sample-plan-id",
            relatedStudentIds: ["student-1"]
        )
    }
}
