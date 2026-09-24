//
//  MeetingsHubView.swift
//  TMI
//
//  Container that fetches all district-scoped meetings and presents them
//  via AllMeetingsView. Reached from Settings > Forms & Meetings > Meetings.
//

import SwiftUI

struct MeetingsHubView: View {
    @Environment(\.meetingsStateModel) private var meetingsStateModel

    var body: some View {
        content(for: meetingsStateModel)
            // The state model is shared with each student's meetings section,
            // which narrows it to one student, so the hub always refetches
            // everything when it appears rather than trusting a loaded state.
            .task { await meetingsStateModel.fetch() }
    }

    @ViewBuilder
    private func content(for stateModel: MeetingsStateModel) -> some View {
        switch stateModel.state {
        case .idle, .loading:
            ProgressView("Loading meetings…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tmiScreenBackground()
                .navigationTitle("Meetings")
        case .error:
            ContentUnavailableView {
                Label("Couldn’t Load Meetings", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") {
                    Task { await stateModel.fetch() }
                }
                .buttonStyle(.tmiPrimary)
            }
            .tmiScreenBackground()
            .navigationTitle("Meetings")
        case .loaded:
            AllMeetingsView(
                meetings: stateModel.value ?? [],
                title: "Meetings",
                onRefresh: { await stateModel.fetch() }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingsHubView()
    }
}
