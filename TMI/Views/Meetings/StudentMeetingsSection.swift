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

    @Environment(\.meetingsStateModel) private var meetingsStateModel

    var body: some View {
        content
            .task(id: studentID) {
                await meetingsStateModel.fetchMeetings(forStudentId: studentID)
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
            ContentUnavailableView(
                "Couldn’t Load Meetings",
                systemImage: "exclamationmark.triangle",
                description: Text("Something went wrong while fetching this student's meetings.")
            )
        case .loaded(let meetings):
            if meetings.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Text("Meetings")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    ForEach(meetings.sorted(by: { $0.startTime > $1.startTime })) { meeting in
                        MeetingListCard(meeting: meeting)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            Text("Meetings")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

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
