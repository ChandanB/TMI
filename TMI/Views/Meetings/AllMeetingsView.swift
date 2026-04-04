//
//  AllMeetingsView.swift
//  TMI
//
//  View displaying all meetings with filtering and search
//

import SwiftUI

struct AllMeetingsView: View {
    let meetings: [Meeting]
    let title: String
    let context: MeetingContext

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var filterStatus: Meeting.MeetingStatus? = nil
    @State private var sortOrder: SortOrder = .dateDescending

    enum SortOrder: String, CaseIterable {
        case dateAscending = "Date (Oldest First)"
        case dateDescending = "Date (Newest First)"
        case statusPriority = "Status Priority"

        var systemImage: String {
            switch self {
            case .dateAscending: return "arrow.up"
            case .dateDescending: return "arrow.down"
            case .statusPriority: return "exclamationmark.circle"
            }
        }
    }

    enum MeetingContext {
        case student(studentId: String)
        case plan(planId: String)
        case all
    }

    var filteredAndSortedMeetings: [Meeting] {
        var result = meetings

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { meeting in
                meeting.title.localizedCaseInsensitiveContains(searchText) ||
                (meeting.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by status
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }

        // Sort
        switch sortOrder {
        case .dateAscending:
            result.sort { $0.startTime < $1.startTime }
        case .dateDescending:
            result.sort { $0.startTime > $1.startTime }
        case .statusPriority:
            result.sort { (m1, m2) in
                let priority1 = statusPriority(m1.status)
                let priority2 = statusPriority(m2.status)
                if priority1 != priority2 {
                    return priority1 < priority2
                }
                return m1.startTime < m2.startTime
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar

                // Meetings List
                if filteredAndSortedMeetings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: TMISpacing.md) {
                            ForEach(filteredAndSortedMeetings) { meeting in
                                MeetingListCard(meeting: meeting)
                                    .padding(.horizontal, TMISpacing.screenPadding)
                            }
                        }
                        .padding(.vertical, TMISpacing.md)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Search and Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: TMISpacing.sm) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.tmiTextSecondary)

                TextField("Search meetings...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.tmiTextPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.tmiTextTertiary)
                    }
                }
            }
            .padding(TMISpacing.md)
            .background(Color.tmiSurface)
            .cornerRadius(TMIRadius.sm)
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.top, TMISpacing.md)

            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TMISpacing.sm) {
                    // Status Filter
                    Menu {
                        Button("All Statuses") {
                            filterStatus = nil
                        }

                        Divider()

                        ForEach(Meeting.MeetingStatus.allCases, id: \.self) { status in
                            Button(status.rawValue) {
                                filterStatus = status
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(filterStatus?.rawValue ?? "All Statuses")
                                .font(.tmiCaption)
                        }
                        .foregroundColor(.tmiTextPrimary)
                        .padding(.horizontal, TMISpacing.md)
                        .padding(.vertical, TMISpacing.sm)
                        .background(filterStatus != nil ? Color.tmiPrimary.opacity(0.2) : Color.tmiSurface)
                        .cornerRadius(TMIRadius.pill)
                    }

                    // Sort Order
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button(action: { sortOrder = order }) {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sortOrder.systemImage)
                            Text("Sort")
                                .font(.tmiCaption)
                        }
                        .foregroundColor(.tmiTextPrimary)
                        .padding(.horizontal, TMISpacing.md)
                        .padding(.vertical, TMISpacing.sm)
                        .background(Color.tmiSurface)
                        .cornerRadius(TMIRadius.pill)
                    }

                    // Count Badge
                    HStack(spacing: 4) {
                        Text("\(filteredAndSortedMeetings.count)")
                            .font(.system(size: 13, weight: .bold))
                        Text("meeting\(filteredAndSortedMeetings.count == 1 ? "" : "s")")
                            .font(.tmiCaption)
                    }
                    .foregroundColor(.tmiTextSecondary)
                    .padding(.horizontal, TMISpacing.md)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }
            .padding(.bottom, TMISpacing.sm)
        }
        .background(Color.tmiBackground.opacity(0.95))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: TMISpacing.md) {
            Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.tmiTextTertiary)

            Text(searchText.isEmpty ? "No Meetings" : "No Results")
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)

            Text(searchText.isEmpty
                ? "No meetings have been scheduled yet"
                : "Try adjusting your search or filters")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty || filterStatus != nil {
                TMIButton(
                    text: "Clear Filters",
                    style: .secondary,
                    action: {
                        searchText = ""
                        filterStatus = nil
                    }
                )
            }
        }
        .padding(TMISpacing.xl)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func statusPriority(_ status: Meeting.MeetingStatus) -> Int {
        switch status {
        case .confirmed: return 0
        case .scheduled: return 1
        case .rescheduled: return 2
        case .completed: return 3
        case .cancelled: return 4
        }
    }
}

// MARK: - Meeting List Card

struct MeetingListCard: View {
    let meeting: Meeting

    private var statusColor: Color {
        switch meeting.status {
        case .scheduled, .confirmed: return .tmiPrimary
        case .completed: return .tmiSuccess
        case .cancelled: return .tmiTextTertiary
        case .rescheduled: return .tmiWarning
        }
    }

    private var isPastMeeting: Bool {
        meeting.endTime < Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            // Header
            HStack(alignment: .top) {
                // Meeting Type Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: meeting.meetingType.color).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: meeting.meetingType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: meeting.meetingType.color))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)

                    HStack(spacing: 8) {
                        Text(meeting.meetingType.rawValue)
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)

                        Circle()
                            .fill(Color.tmiTextTertiary)
                            .frame(width: 3, height: 3)

                        Text(formattedDate(meeting.startTime))
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                    }
                }

                Spacer()

                // Status Badge
                Text(meeting.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.2))
                    )
            }

            // Time and Location
            HStack(spacing: TMISpacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("\(formattedTime(meeting.startTime)) - \(formattedTime(meeting.endTime))")
                        .font(.tmiCaption)
                }
                .foregroundColor(.tmiTextSecondary)

                if let location = meeting.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.system(size: 11))
                        Text(location)
                            .font(.tmiCaption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.tmiTextSecondary)
                }
            }

            // Participants
            if !meeting.participants.isEmpty {
                HStack(spacing: 6) {
                    ForEach(meeting.participants.prefix(3)) { participant in
                        HStack(spacing: 4) {
                            Image(systemName: participant.role.icon)
                                .font(.system(size: 10))
                            Text(participant.name)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.tmiTextPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.tmiSurface)
                        .cornerRadius(TMIRadius.pill)
                    }

                    if meeting.participants.count > 3 {
                        Text("+\(meeting.participants.count - 3)")
                            .font(.system(size: 11))
                            .foregroundColor(.tmiTextTertiary)
                    }
                }
            }
        }
        .padding(TMISpacing.md)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.md)
        .opacity(isPastMeeting && meeting.status != .completed ? 0.6 : 1.0)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllMeetingsView(
            meetings: [Meeting.sampleMeeting],
            title: "All Meetings",
            context: .all
        )
    }
}
