//
//  ScheduleMeetingView.swift
//  TMI
//
//  Schedules a meeting about one student. The organizer is the signed-in
//  educator, who is also its first participant, so it is readable by them
//  under the meetings rules as soon as it is saved.
//

import SwiftUI

struct ScheduleMeetingView: View {
    let studentID: String
    var studentName: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.meetingsStateModel) private var meetingsStateModel

    @State private var draft: DraftMeeting
    @State private var durationMinutes = 30
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private static let durations = [15, 30, 45, 60, 90]

    init(studentID: String, studentName: String? = nil, now: Date = .now) {
        self.studentID = studentID
        self.studentName = studentName
        // Tomorrow, on the next half hour: a sensible first guess to adjust.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let start = Self.roundedUpToHalfHour(tomorrow)
        _draft = State(initialValue: DraftMeeting(
            title: "",
            startTime: start,
            endTime: start.addingTimeInterval(30 * 60),
            meetingType: .checkIn,
            location: nil,
            notes: nil,
            studentIds: [studentID],
            relatedPlanId: nil
        ))
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title, prompt: Text("Weekly check-in"))
                        .focused($titleFocused)
                        .submitLabel(.done)
                    Picker("Type", selection: $draft.meetingType) {
                        ForEach(Meeting.MeetingType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                } footer: {
                    if let studentName {
                        Text("About \(studentName).")
                    }
                }

                Section("When") {
                    DatePicker(
                        "Starts",
                        selection: $draft.startTime,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(Self.durations, id: \.self) { minutes in
                            Text(Self.durationLabel(minutes)).tag(minutes)
                        }
                    }
                }

                Section("Details") {
                    TextField("Location", text: optional(\.location), prompt: Text("Room 204 or video link"))
                    TextField("Agenda or notes", text: optional(\.notes), axis: .vertical)
                        .lineLimit(2...6)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(TMIColors.errorText)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tmiScreenBackground()
            .navigationTitle("Schedule Meeting")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Schedule") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear { titleFocused = true }
        }
        .tmiMacSheetFrame(minWidth: 440, idealWidth: 500, minHeight: 440, idealHeight: 520)
    }

    private func save() async {
        errorMessage = nil
        var candidate = draft
        candidate.title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate.endTime = candidate.startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        do {
            try candidate.validate()
            let meeting = try candidate.toMeeting(organizerID: FirebaseSession.currentUserID())
            isSaving = true
            defer { isSaving = false }
            _ = try await meetingsStateModel.createMeeting(meeting)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Binds an optional draft field to a text field, storing empty as nil.
    private func optional(_ keyPath: WritableKeyPath<DraftMeeting, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = trimmed.isEmpty ? nil : value
            }
        )
    }

    private static func durationLabel(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func roundedUpToHalfHour(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let floored = calendar.date(from: components) ?? date
        let minute = components.minute ?? 0
        let add = (minute % 30 == 0 && floored == date) ? 0 : 30 - minute % 30
        return calendar.date(byAdding: .minute, value: add, to: floored) ?? date
    }
}

#Preview {
    ScheduleMeetingView(studentID: "preview-student", studentName: "Avery")
}
