//
//  MeetingsStateModel.swift
//  TMI
//
//  Authoritative state model for meetings within the app.
//  Manages meeting list, upcoming meetings, and per-student/per-plan views.
//

import Foundation
import Observation
import SwiftUI
import FirebaseFirestore

// MARK: - Meetings State Model

@Observable
final class MeetingsStateModel: BaseStateModel<[Meeting], IdentifiableError> {
    
    // MARK: - Dependencies
    
    private let meetingService: MeetingService
    
    // MARK: - State
    
    /// All meetings for the current user/context
    private(set) var meetings: [Meeting] = []
    
    /// Meetings filtered by current context (student/plan)
    private(set) var contextMeetings: [Meeting] = []
    
    /// Upcoming meetings (next 7 days)
    private(set) var upcomingMeetings: [Meeting] = []
    
    /// Past meetings
    private(set) var pastMeetings: [Meeting] = []
    
    /// Currently selected meeting for detail view
    private(set) var selectedMeeting: Meeting?
    
    // MARK: - Filter State
    
    /// Current filter for student ID
    private(set) var filterStudentId: String?
    
    /// Current filter for plan ID
    private(set) var filterPlanId: String?
    
    /// Date range filter
    private(set) var filterDateRange: ClosedRange<Date>?
    
    // MARK: - Computed Properties
    
    /// Meetings scheduled for today
    var todayMeetings: [Meeting] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return meetings.filter { meeting in
            meeting.startTime >= today && meeting.startTime < tomorrow
        }.sorted(by: { $0.startTime < $1.startTime })
    }
    
    /// Meetings this week
    var thisWeekMeetings: [Meeting] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return meetings.filter { meeting in
            meeting.startTime >= today && meeting.startTime < weekEnd
        }.sorted(by: { $0.startTime < $1.startTime })
    }
    
    /// Count of meetings needing attention (e.g., notes not completed)
    var meetingsNeedingAttention: Int {
        pastMeetings.filter { meeting in
            // Meetings that occurred but don't have notes
            meeting.endTime < Date() && (meeting.notes?.isEmpty ?? true)
        }.count
    }
    
    // MARK: - Initialization
    
    init(meetingService: MeetingService = .shared) {
        self.meetingService = meetingService
        super.init()
    }
    
    // MARK: - Fetch Operations
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            let fetchedMeetings = try await meetingService.fetchMeetings()
            meetings = fetchedMeetings
            
            updateDerivedCollections()
            updateState(.loaded(meetings))
            
            print("[MeetingsStateModel] Fetched \(meetings.count) meetings")
        } catch {
            let identifiableError = IdentifiableError(message: error.localizedDescription)
            updateState(.error(identifiableError))
            print("[MeetingsStateModel] Error fetching meetings: \(error.localizedDescription)")
        }
    }
    
    /// Fetch meetings for a specific student
    @MainActor
    func fetchMeetings(forStudentId studentId: String) async {
        filterStudentId = studentId
        filterPlanId = nil
        
        updateState(.loading)
        
        do {
            // Fetch all meetings and filter by student
            let allMeetings = try await meetingService.fetchMeetings()
            meetings = allMeetings.filter { $0.relatedStudentIds.contains(studentId) }
            
            updateDerivedCollections()
            updateState(.loaded(meetings))
            
            print("[MeetingsStateModel] Fetched \(meetings.count) meetings for student: \(studentId)")
        } catch {
            let identifiableError = IdentifiableError(message: error.localizedDescription)
            updateState(.error(identifiableError))
        }
    }
    
    /// Fetch meetings for a specific plan
    @MainActor
    func fetchMeetings(forPlanId planId: String) async {
        filterPlanId = planId
        filterStudentId = nil
        
        updateState(.loading)
        
        do {
            let fetchedMeetings = try await meetingService.fetchMeetings(for: planId)
            meetings = fetchedMeetings
            
            updateDerivedCollections()
            updateState(.loaded(meetings))
            
            print("[MeetingsStateModel] Fetched \(meetings.count) meetings for plan: \(planId)")
        } catch {
            let identifiableError = IdentifiableError(message: error.localizedDescription)
            updateState(.error(identifiableError))
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new meeting
    @MainActor
    func createMeeting(_ meeting: Meeting) async throws -> Meeting {
        let createdMeeting = try await meetingService.scheduleMeeting(meeting)
        
        // Add to local state
        meetings.append(createdMeeting)
        updateDerivedCollections()
        updateState(.loaded(meetings))
        
        print("[MeetingsStateModel] Created meeting: \(createdMeeting.id ?? "unknown")")
        return createdMeeting
    }
    
    /// Update an existing meeting
    @MainActor
    func updateMeeting(_ meeting: Meeting) async throws -> Meeting {
        let updatedMeeting = try await meetingService.updateMeeting(meeting)
        
        // Update local state
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = updatedMeeting
        }
        updateDerivedCollections()
        updateState(.loaded(meetings))
        
        print("[MeetingsStateModel] Updated meeting: \(updatedMeeting.id ?? "unknown")")
        return updatedMeeting
    }
    
    /// Delete a meeting
    @MainActor
    func deleteMeeting(_ meeting: Meeting) async throws {
        guard let meetingId = meeting.id else {
            throw NSError(domain: "MeetingsStateModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Meeting ID is required"])
        }
        try await meetingService.deleteMeeting(meetingId)
        
        // Remove from local state
        meetings.removeAll { $0.id == meeting.id }
        updateDerivedCollections()
        updateState(.loaded(meetings))
        
        print("[MeetingsStateModel] Deleted meeting: \(meetingId)")
    }
    
    /// Add notes to a meeting
    @MainActor
    func addNotes(to meeting: Meeting, notes: String) async throws -> Meeting {
        var updatedMeeting = meeting
        updatedMeeting.notes = notes
        updatedMeeting.lastUpdated = Date()
        
        return try await updateMeeting(updatedMeeting)
    }
    
    /// Mark a meeting as completed
    @MainActor
    func markAsCompleted(_ meeting: Meeting) async throws -> Meeting {
        var updatedMeeting = meeting
        updatedMeeting.status = .completed
        updatedMeeting.lastUpdated = Date()
        
        return try await updateMeeting(updatedMeeting)
    }
    
    /// Cancel a meeting
    @MainActor
    func cancelMeeting(_ meeting: Meeting, reason: String? = nil) async throws -> Meeting {
        var updatedMeeting = meeting
        updatedMeeting.status = .cancelled
        if let reason = reason {
            updatedMeeting.notes = (updatedMeeting.notes ?? "") + "\nCancellation reason: \(reason)"
        }
        updatedMeeting.lastUpdated = Date()
        
        return try await updateMeeting(updatedMeeting)
    }
    
    // MARK: - Selection
    
    /// Select a meeting for detail view
    @MainActor
    func selectMeeting(_ meeting: Meeting?) {
        selectedMeeting = meeting
    }
    
    // MARK: - Filtering
    
    /// Apply filters and update context meetings
    @MainActor
    func applyFilters(studentId: String? = nil, planId: String? = nil, dateRange: ClosedRange<Date>? = nil) {
        filterStudentId = studentId
        filterPlanId = planId
        filterDateRange = dateRange
        
        updateDerivedCollections()
    }
    
    /// Clear all filters
    @MainActor
    func clearFilters() {
        filterStudentId = nil
        filterPlanId = nil
        filterDateRange = nil
        
        updateDerivedCollections()
    }
    
    // MARK: - Private Helpers
    
    private func updateDerivedCollections() {
        let now = Date()
        
        // Apply filters to get context meetings
        contextMeetings = meetings.filter { meeting in
            var matches = true
            
            if let studentId = filterStudentId {
                matches = matches && meeting.relatedStudentIds.contains(studentId)
            }
            
            if let planId = filterPlanId {
                matches = matches && meeting.relatedPlanId == planId
            }
            
            if let dateRange = filterDateRange {
                matches = matches && dateRange.contains(meeting.startTime)
            }
            
            return matches
        }
        
        // Split into upcoming and past
        upcomingMeetings = contextMeetings
            .filter { $0.startTime >= now && $0.status != .cancelled }
            .sorted(by: { $0.startTime < $1.startTime })
        
        pastMeetings = contextMeetings
            .filter { $0.endTime < now }
            .sorted(by: { $0.startTime > $1.startTime })
    }
}

// MARK: - Environment Key

private struct MeetingsStateModelKey: EnvironmentKey {
    static let defaultValue = MeetingsStateModel()
}

extension EnvironmentValues {
    var meetingsStateModel: MeetingsStateModel {
        get { self[MeetingsStateModelKey.self] }
        set { self[MeetingsStateModelKey.self] = newValue }
    }
}

