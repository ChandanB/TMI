//
//  ScheduleMeetingCoordinator.swift
//  TMI
//
//  Unified coordinator for scheduling meetings.
//  Single entry point for scheduling from any context (dashboard, student, plan).
//

import Foundation
import SwiftUI
import Observation
import FirebaseAuth

// MARK: - Schedule Meeting Coordinator

/// Unified coordinator for meeting scheduling.
/// Used from Dashboard, Student Detail, Plan Detail, and any other context.
@Observable
final class ScheduleMeetingCoordinator {
    
    // MARK: - State
    
    /// Whether the scheduling sheet is showing
    var isShowingScheduler: Bool = false
    
    /// The meeting being created/edited
    var draftMeeting: DraftMeeting?
    
    /// Error state
    var error: SchedulingError?
    
    /// Whether a save is in progress
    var isSaving: Bool = false
    
    // MARK: - Context
    
    /// The student context for the meeting
    private(set) var studentId: String?
    
    /// The plan context for the meeting
    private(set) var planId: String?
    
    /// Pre-filled student info
    private(set) var students: [Student] = []
    
    // MARK: - Dependencies
    
    private let meetingService: MeetingService
    
    init(meetingService: MeetingService = .shared) {
        self.meetingService = meetingService
    }
    
    // MARK: - Public API
    
    /// Start scheduling a new meeting
    @MainActor
    func startScheduling(
        forStudentId studentId: String? = nil,
        forPlanId planId: String? = nil,
        withStudents students: [Student] = []
    ) {
        self.studentId = studentId
        self.planId = planId
        self.students = students
        
        // Create draft meeting with context
        var studentIds: [String] = []
        if let studentId = studentId {
            studentIds.append(studentId)
        }
        studentIds.append(contentsOf: students.compactMap { $0.id })
        
        let startTime = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow
        draftMeeting = DraftMeeting(
            title: "",
            startTime: startTime,
            endTime: startTime.addingTimeInterval(30 * 60), // 30 minutes
            meetingType: .checkIn,
            location: nil,
            notes: nil,
            studentIds: Array(Set(studentIds)), // Deduplicate
            relatedPlanId: planId
        )
        
        isShowingScheduler = true
        
        print("[ScheduleMeetingCoordinator] Started scheduling for student: \(studentId ?? "nil"), plan: \(planId ?? "nil")")
    }
    
    /// Edit an existing meeting
    @MainActor
    func editMeeting(_ meeting: Meeting) {
        draftMeeting = DraftMeeting(from: meeting)
        studentId = meeting.relatedStudentIds.first
        planId = meeting.relatedPlanId
        isShowingScheduler = true
        
        print("[ScheduleMeetingCoordinator] Editing meeting: \(meeting.id ?? "unknown")")
    }
    
    /// Save the current draft meeting
    @MainActor
    func saveMeeting() async throws -> Meeting {
        guard let draft = draftMeeting else {
            throw SchedulingError.noDraft
        }
        
        // Validate
        try draft.validate()
        
        isSaving = true
        defer { isSaving = false }
        
        let meeting = draft.toMeeting()
        
        let savedMeeting: Meeting
        if let existingId = draft.existingId {
            // Update existing
            var updateMeeting = meeting
            updateMeeting.id = existingId
            savedMeeting = try await meetingService.updateMeeting(updateMeeting)
        } else {
            // Create new
            savedMeeting = try await meetingService.scheduleMeeting(meeting)
        }
        
        // Reset state
        dismiss()
        
        print("[ScheduleMeetingCoordinator] Saved meeting: \(savedMeeting.id ?? "unknown")")
        return savedMeeting
    }
    
    /// Dismiss the scheduler
    @MainActor
    func dismiss() {
        isShowingScheduler = false
        draftMeeting = nil
        studentId = nil
        planId = nil
        students = []
        error = nil
    }
    
    /// Update draft meeting field
    @MainActor
    func updateDraft(_ update: (inout DraftMeeting) -> Void) {
        guard var draft = draftMeeting else { return }
        update(&draft)
        draftMeeting = draft
    }
}

// MARK: - Draft Meeting

/// Mutable draft meeting for the scheduling form
struct DraftMeeting {
    var existingId: String?
    var title: String
    var startTime: Date
    var endTime: Date
    var meetingType: Meeting.MeetingType
    var location: String?
    var notes: String?
    var studentIds: [String]
    var relatedPlanId: String?
    
    init(
        existingId: String? = nil,
        title: String,
        startTime: Date,
        endTime: Date,
        meetingType: Meeting.MeetingType,
        location: String?,
        notes: String?,
        studentIds: [String],
        relatedPlanId: String?
    ) {
        self.existingId = existingId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.meetingType = meetingType
        self.location = location
        self.notes = notes
        self.studentIds = studentIds
        self.relatedPlanId = relatedPlanId
    }
    
    init(from meeting: Meeting) {
        self.existingId = meeting.id
        self.title = meeting.title
        self.startTime = meeting.startTime
        self.endTime = meeting.endTime
        self.meetingType = meeting.meetingType
        self.location = meeting.location
        self.notes = meeting.notes
        self.studentIds = meeting.relatedStudentIds
        self.relatedPlanId = meeting.relatedPlanId
    }
    
    var duration: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchedulingError.titleRequired
        }
        
        if studentIds.isEmpty {
            throw SchedulingError.studentRequired
        }
        
        if startTime < Date() {
            throw SchedulingError.dateInPast
        }
        
        let durationMinutes = duration
        if durationMinutes < 5 || durationMinutes > 480 {
            throw SchedulingError.invalidDuration
        }
    }
    
    func toMeeting() -> Meeting {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            fatalError("User must be authenticated to create a meeting")
        }
        
        return Meeting(
            id: existingId,
            title: title,
            description: nil,
            startTime: startTime,
            endTime: endTime,
            location: location,
            meetingType: meetingType,
            organizer: currentUserId,
            participants: [],
            relatedStudentIds: studentIds,
            relatedPlanId: relatedPlanId,
            status: .scheduled,
            notes: notes,
            completedAt: nil,
            actionItems: [],
            createdAt: Date(),
            lastUpdated: Date()
        )
    }
}

// MARK: - Scheduling Errors

enum SchedulingError: LocalizedError {
    case noDraft
    case titleRequired
    case studentRequired
    case dateInPast
    case invalidDuration
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noDraft:
            return "No meeting draft available"
        case .titleRequired:
            return "Meeting title is required"
        case .studentRequired:
            return "At least one student must be selected"
        case .dateInPast:
            return "Meeting date cannot be in the past"
        case .invalidDuration:
            return "Meeting duration must be between 5 and 480 minutes"
        case .saveFailed(let message):
            return "Failed to save meeting: \(message)"
        }
    }
}

// MARK: - Environment Key

private struct ScheduleMeetingCoordinatorKey: EnvironmentKey {
    static let defaultValue = ScheduleMeetingCoordinator()
}

extension EnvironmentValues {
    var scheduleMeetingCoordinator: ScheduleMeetingCoordinator {
        get { self[ScheduleMeetingCoordinatorKey.self] }
        set { self[ScheduleMeetingCoordinatorKey.self] = newValue }
    }
}


