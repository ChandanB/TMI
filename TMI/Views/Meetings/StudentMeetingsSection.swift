//
//  StudentMeetingsSection.swift
//  TMI
//
//  Lists meetings related to a single student. Reused inside
//  StudentDetailView's meetingsAndNotes domain, above the private
//  notes/reflections timeline.
//

import SwiftUI

struct StudentMeetingsSection: View {
    let studentID: String
    var studentName: String? = nil

    @Environment(\.meetingsStateModel) private var meetingsStateModel
    @State private var selectedMeeting: Meeting?
    @State private var isScheduling = false

    var body: some View {
        content
            .task(id: studentID) {
                await meetingsStateModel.fetchMeetings(forStudentId: studentID)
            }
            .sheet(item: $selectedMeeting) { meeting in
                MeetingDetailView(meeting: meeting)
            }
            .sheet(isPresented: $isScheduling) {
                ScheduleMeetingView(studentID: studentID, studentName: studentName)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch meetingsStateModel.state {
        case .idle, .loading:
            ProgressView("Loading meetings…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.md)
        case .error:
            ContentUnavailableView {
                Label("Couldn’t Load Meetings", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") {
                    Task { await meetingsStateModel.fetchMeetings(forStudentId: studentID) }
                }
                .buttonStyle(.tmiSecondary)
            }
        case .loaded(let meetings):
            if meetings.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    header

                    VStack(spacing: 0) {
                        let sorted = meetings.sorted(by: { $0.startTime > $1.startTime })
                        ForEach(sorted) { meeting in
                            Button {
                                selectedMeeting = meeting
                            } label: {
                                MeetingRow(meeting: meeting)
                                    .padding(.horizontal, TMISpacing.md)
                                    .padding(.vertical, TMISpacing.xs)
                            }
                            .buttonStyle(.tmiPressable)
                            if meeting.id != sorted.last?.id {
                                Divider().padding(.leading, TMISpacing.md + 36 + TMISpacing.ms)
                            }
                        }
                    }
                    .tmiSurface(padding: 0)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Meetings")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)
            Spacer()
            Button("Schedule", systemImage: "calendar.badge.plus") {
                isScheduling = true
            }
            .buttonStyle(.tmiTertiary)
            .accessibilityIdentifier("studentMeetings.schedule")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            header

            Text("No meetings have been scheduled for this student yet.")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    StudentMeetingsSection(studentID: "preview-student")
}
