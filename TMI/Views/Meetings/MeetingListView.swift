//
//  MeetingListView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #7
//  Main list view for meetings with filtering and search
//

import SwiftUI

struct MeetingListView: View {
    @State private var viewModel = MeetingListViewModel()
    @State private var showingCreateMeeting = false
    @State private var showingCalendarView = false
    @State private var selectedMeeting: Meeting?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Filters
            filtersSection

            // Content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredMeetings.isEmpty {
                emptyView
            } else {
                meetingsList
            }
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Meetings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: { showingCalendarView = true }) {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.tmiTextPrimary)
                    }

                    Button(action: { showingCreateMeeting = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .task {
            await viewModel.loadMeetings()
        }
        .refreshable {
            await viewModel.loadMeetings()
        }
        .sheet(isPresented: $showingCreateMeeting) {
            NavigationStack {
                CreateEditMeetingView(onSave: {
                    Task { await viewModel.loadMeetings() }
                })
            }
            .tmiSheetStyle()
        }
        .sheet(isPresented: $showingCalendarView) {
            NavigationStack {
                MeetingCalendarView(meetings: viewModel.meetings)
            }
            .tmiSheetStyle()
        }
        .sheet(item: $selectedMeeting) { meeting in
            NavigationStack {
                MeetingDetailView(
                    meeting: meeting,
                    onUpdate: { Task { await viewModel.loadMeetings() } }
                )
            }
            .tmiSheetStyle()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.tmiTextSecondary)

            TextField("Search meetings...", text: $viewModel.searchText)
                .foregroundColor(Color.tmiTextPrimary)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.tmiTextSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiSurface)
        )
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Upcoming only toggle
                FilterChip(
                    title: "Upcoming",
                    icon: "clock.fill",
                    isSelected: viewModel.showOnlyUpcoming,
                    action: { viewModel.showOnlyUpcoming.toggle() }
                )

                // Meeting type filter
                Menu {
                    Button("All Types") {
                        viewModel.selectedMeetingType = nil
                    }

                    Divider()

                    ForEach(Meeting.MeetingType.allCases, id: \.self) { type in
                        Button(action: { viewModel.selectedMeetingType = type }) {
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        title: viewModel.selectedMeetingType?.rawValue ?? "Type",
                        icon: viewModel.selectedMeetingType?.icon ?? "star.fill",
                        isSelected: viewModel.selectedMeetingType != nil,
                        action: {}
                    )
                }

                // Status filter
                Menu {
                    Button("All Statuses") {
                        viewModel.selectedStatus = nil
                    }

                    Divider()

                    ForEach([Meeting.MeetingStatus.scheduled, .confirmed, .completed, .cancelled], id: \.self) { status in
                        Button(status.rawValue) {
                            viewModel.selectedStatus = status
                        }
                    }
                } label: {
                    FilterChip(
                        title: viewModel.selectedStatus?.rawValue ?? "Status",
                        icon: "checkmark.circle.fill",
                        isSelected: viewModel.selectedStatus != nil,
                        action: {}
                    )
                }

                // Clear filters
                if viewModel.selectedMeetingType != nil || viewModel.selectedStatus != nil || viewModel.showOnlyUpcoming {
                    Button(action: { viewModel.clearFilters() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Meetings List

    private var meetingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Statistics header
                if !viewModel.meetings.isEmpty {
                    statisticsHeader
                }

                // Meetings
                ForEach(viewModel.filteredMeetings) { meeting in
                    Button(action: { selectedMeeting = meeting }) {
                        MeetingCard(meeting: meeting, modelColor: .cyan)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        meetingContextMenu(for: meeting)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Statistics Header

    private var statisticsHeader: some View {
        TMIGlassCard(style: .elevated) {
            HStack(spacing: 20) {
                StatBox(
                    title: "Upcoming",
                    value: "\(viewModel.upcomingMeetings.count)",
                    icon: "calendar",
                    color: .cyan
                )

                Divider()
                    .frame(height: 40)

                StatBox(
                    title: "Past",
                    value: "\(viewModel.pastMeetings.count)",
                    icon: "checkmark.circle",
                    color: .green
                )

                Divider()
                    .frame(height: 40)

                StatBox(
                    title: "Action Items",
                    value: "\(viewModel.overdueActionItemsCount)",
                    icon: "exclamationmark.triangle",
                    color: viewModel.overdueActionItemsCount > 0 ? .orange : .gray
                )
            }
            .padding()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func meetingContextMenu(for meeting: Meeting) -> some View {
        if meeting.status != .completed {
            Button(action: { Task { await viewModel.completeMeeting(meeting.id!, notes: nil) } }) {
                Label("Mark Complete", systemImage: "checkmark.circle")
            }
        }

        if meeting.status != .cancelled {
            Button(role: .destructive, action: { Task { await viewModel.cancelMeeting(meeting.id!) } }) {
                Label("Cancel Meeting", systemImage: "xmark.circle")
            }
        }

        Divider()

        Button(role: .destructive, action: { Task { await viewModel.deleteMeeting(meeting.id!) } }) {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(Color.tmiTextTertiary)

            Text(viewModel.searchText.isEmpty ? "No meetings" : "No results")
                .font(.title2.bold())
                .foregroundColor(Color.tmiTextPrimary)

            Text(viewModel.searchText.isEmpty ? "Create your first meeting to get started" : "Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(Color.tmiTextSecondary)
                .multilineTextAlignment(.center)

            if viewModel.searchText.isEmpty {
                Button(action: { showingCreateMeeting = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Meeting")
                    }
                    .font(.headline)
                    .foregroundColor(Color.tmiTextPrimary)
                    .padding()
                    .background(Color.cyan.gradient)
                    .cornerRadius(12)
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading meetings...")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Supporting Views

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.bold())
            .foregroundColor(isSelected ? Color.tmiTextOnPrimary : Color.tmiTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.cyan : Color.tmiInputBackground)
            .cornerRadius(20)
        }
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(Color.tmiTextPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingListView()
    }
}
