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
    }

    @ViewBuilder
    private func content(for stateModel: MeetingsStateModel) -> some View {
        switch stateModel.state {
        case .idle, .loading:
            ProgressView("Loading meetings…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await stateModel.fetch()
                }
        case .error:
            ContentUnavailableView(
                "Couldn’t Load Meetings",
                systemImage: "exclamationmark.triangle",
                description: Text("Something went wrong while fetching meetings. Pull to try again.")
            )
            .task {
                await stateModel.fetch()
            }
        case .loaded:
            AllMeetingsView(
                meetings: stateModel.value ?? [],
                title: "Meetings",
                context: .all
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
