//
//  MeetingListViewModel.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #7
//  ViewModel for managing meetings list state
//

import Foundation
import Observation

@Observable
final class MeetingListViewModel {
    // MARK: - State

    var meetings: [Meeting] = []
    var filteredMeetings: [Meeting] = []
    var isLoading = false
    var errorMessage: String?

    // Filters
    var searchText = "" {
        didSet { applyFilters() }
    }
    var selectedMeetingType: Meeting.MeetingType? {
        didSet { applyFilters() }
    }
    var selectedStatus: Meeting.MeetingStatus? {
        didSet { applyFilters() }
    }
    var showOnlyUpcoming = false {
        didSet { applyFilters() }
    }

    // Service
    private let meetingService = MeetingService.shared

    // MARK: - Computed Properties

    var upcomingMeetings: [Meeting] {
        meetings.filter { $0.isUpcoming }
            .sorted { $0.startTime < $1.startTime }
    }

    var pastMeetings: [Meeting] {
        meetings.filter { $0.isPast }
            .sorted { $0.startTime > $1.startTime }
    }

    var meetingsWithActionItems: [Meeting] {
        meetings.filter { $0.hasActionItems }
    }

    var overdueActionItemsCount: Int {
        meetings.reduce(0) { $0 + $1.overdueActionItemsCount }
    }

    // MARK: - Data Loading

    @MainActor
    func loadMeetings() async {
        isLoading = true
        errorMessage = nil

        do {
            meetings = try await meetingService.fetchMeetings()
            applyFilters()
            print("[MeetingListViewModel] ✅ Loaded \(meetings.count) meetings")
        } catch {
            errorMessage = "Failed to load meetings: \(error.localizedDescription)"
            print("[MeetingListViewModel] ❌ Error loading meetings: \(error)")
        }

        isLoading = false
    }

    @MainActor
    func loadMeetings(for planId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            meetings = try await meetingService.fetchMeetings(for: planId)
            applyFilters()
            print("[MeetingListViewModel] ✅ Loaded \(meetings.count) meetings for plan")
        } catch {
            errorMessage = "Failed to load meetings: \(error.localizedDescription)"
            print("[MeetingListViewModel] ❌ Error loading meetings: \(error)")
        }

        isLoading = false
    }

    // MARK: - Meeting Actions

    @MainActor
    func deleteMeeting(_ meetingId: String) async {
        do {
            try await meetingService.deleteMeeting(meetingId)
            meetings.removeAll { $0.id == meetingId }
            applyFilters()
            print("[MeetingListViewModel] ✅ Meeting deleted")
        } catch {
            errorMessage = "Failed to delete meeting: \(error.localizedDescription)"
            print("[MeetingListViewModel] ❌ Error deleting meeting: \(error)")
        }
    }

    @MainActor
    func cancelMeeting(_ meetingId: String) async {
        do {
            try await meetingService.cancelMeeting(meetingId)
            if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
                meetings[index].status = .cancelled
            }
            applyFilters()
            print("[MeetingListViewModel] ✅ Meeting cancelled")
        } catch {
            errorMessage = "Failed to cancel meeting: \(error.localizedDescription)"
            print("[MeetingListViewModel] ❌ Error cancelling meeting: \(error)")
        }
    }

    @MainActor
    func completeMeeting(_ meetingId: String, notes: String?) async {
        do {
            try await meetingService.completeMeeting(meetingId, notes: notes)
            if let index = meetings.firstIndex(where: { $0.id == meetingId }) {
                meetings[index].status = .completed
                meetings[index].completedAt = Date()
                if let notes = notes {
                    meetings[index].notes = notes
                }
            }
            applyFilters()
            print("[MeetingListViewModel] ✅ Meeting completed")
        } catch {
            errorMessage = "Failed to complete meeting: \(error.localizedDescription)"
            print("[MeetingListViewModel] ❌ Error completing meeting: \(error)")
        }
    }

    // MARK: - Filters

    private func applyFilters() {
        var result = meetings

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { meeting in
                meeting.title.localizedCaseInsensitiveContains(searchText) ||
                (meeting.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (meeting.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Meeting type filter
        if let selectedMeetingType = selectedMeetingType {
            result = result.filter { $0.meetingType == selectedMeetingType }
        }

        // Status filter
        if let selectedStatus = selectedStatus {
            result = result.filter { $0.status == selectedStatus }
        }

        // Upcoming filter
        if showOnlyUpcoming {
            result = result.filter { $0.isUpcoming }
        }

        // Sort by start time
        result.sort { $0.startTime > $1.startTime }

        filteredMeetings = result
    }

    func clearFilters() {
        searchText = ""
        selectedMeetingType = nil
        selectedStatus = nil
        showOnlyUpcoming = false
    }
}
