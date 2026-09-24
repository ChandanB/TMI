//
//  AllMeetingsView.swift
//  TMI
//
//  Meetings grouped into upcoming and past, with search and a status filter.
//  Selecting a meeting opens its detail sheet.
//

import SwiftUI

struct AllMeetingsView: View {
    let meetings: [Meeting]
    let title: String
    var onRefresh: (() async -> Void)? = nil

    @State private var searchText = ""
    @State private var filterStatus: Meeting.MeetingStatus?
    @State private var selectedMeeting: Meeting?

    private var filtered: [Meeting] {
        meetings.filter { meeting in
            let matchesStatus = filterStatus.map { meeting.status == $0 } ?? true
            let matchesSearch = searchText.isEmpty
                || meeting.title.localizedCaseInsensitiveContains(searchText)
                || (meeting.description?.localizedCaseInsensitiveContains(searchText) ?? false)
                || meeting.participants.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            return matchesStatus && matchesSearch
        }
    }

    /// Soonest first: the next meeting is the one worth preparing for.
    private var upcoming: [Meeting] {
        filtered.filter { $0.endTime >= .now }.sorted { $0.startTime < $1.startTime }
    }

    /// Most recent first.
    private var past: [Meeting] {
        filtered.filter { $0.endTime < .now }.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        List {
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { row(for: $0) }
                }
            }
            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { row(for: $0) }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        .tmiScreenBackground()
        .overlay { emptyState }
        .searchable(text: $searchText, prompt: "Search meetings or people")
        .refreshable { await onRefresh?() }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $filterStatus) {
                        Text("All Statuses").tag(Meeting.MeetingStatus?.none)
                        ForEach(Meeting.MeetingStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(
                        "Filter",
                        systemImage: filterStatus == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                }
            }
        }
        .sheet(item: $selectedMeeting) { meeting in
            MeetingDetailView(meeting: meeting)
        }
    }

    private func row(for meeting: Meeting) -> some View {
        Button {
            selectedMeeting = meeting
        } label: {
            MeetingRow(meeting: meeting)
        }
        .buttonStyle(.plain)
        .listRowBackground(TMIColors.surface)
    }

    @ViewBuilder
    private var emptyState: some View {
        if filtered.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if filterStatus != nil {
                ContentUnavailableView {
                    Label("No \(filterStatus?.rawValue ?? "") Meetings", systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button("Show All Meetings") { filterStatus = nil }
                        .buttonStyle(.tmiSecondary)
                }
            } else {
                ContentUnavailableView(
                    "No Meetings Yet",
                    systemImage: "calendar",
                    description: Text("Meetings you are invited to appear here.")
                )
            }
        }
    }
}

// MARK: - Row

/// One meeting as a list row: what, when, and where it stands.
struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(alignment: .top, spacing: TMISpacing.ms) {
            TMIIconTile(meeting.meetingType.icon, tone: meeting.meetingType.tone, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(TMIColors.textPrimary)
                    .lineLimit(2)
                Text(meeting.scheduleSummary)
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                if let location = meeting.location, !location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .imageScale(.small)
                        Text(location)
                    }
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textTertiary)
                    .lineLimit(1)
                }
                // Scheduled and confirmed are the expected state of an
                // upcoming meeting; only a status worth noticing earns a
                // badge, under the text so it never squeezes the title.
                if meeting.status.isNoteworthy {
                    TMIStatusBadge(meeting.status.rawValue, tone: meeting.status.tone)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(meeting.status == .cancelled ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens meeting details")
    }
}

// MARK: - Presentation

extension Meeting {
    /// "Tue, Sep 23 · 2:00 – 2:30 PM"
    var scheduleSummary: String {
        let day = startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(timeRange)"
    }

    /// "2:00 – 2:30 PM", sharing the day period when both ends have it.
    var timeRange: String {
        guard endTime > startTime else {
            return startTime.formatted(date: .omitted, time: .shortened)
        }
        return (startTime..<endTime).formatted(.interval.hour().minute())
    }
}

extension Meeting.MeetingStatus {
    var isNoteworthy: Bool {
        switch self {
        case .scheduled, .confirmed: false
        case .completed, .cancelled, .rescheduled: true
        }
    }

    var tone: TMITone {
        switch self {
        case .scheduled, .confirmed: .brand
        case .completed: .success
        case .cancelled: .neutral
        case .rescheduled: .warning
        }
    }
}

extension Meeting.MeetingType {
    var tone: TMITone {
        switch self {
        case .checkIn, .studentMeeting: .brand
        case .progressReview: .success
        case .parentConference: .info
        case .teamMeeting, .strategySession: .warning
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllMeetingsView(meetings: [Meeting.sampleMeeting], title: "Meetings")
    }
}
