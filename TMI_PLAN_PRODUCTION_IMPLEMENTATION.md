# TMI Plans Production Implementation Plan

## Executive Summary

This document outlines the complete production-ready implementation for TMI Plans, focusing on:
1. Student interest synchronization between surveys and plans
2. Real-time progress calculation based on tangible data (goal completion)
3. Actionable "Next Action" items with full functionality
4. Meeting scheduling system integration

---

## Phase 1: Interest Synchronization System

### 1.1 Core Architecture

**Problem**: When students complete surveys and their interests are updated, TMI Plans don't automatically reflect these changes.

**Solution**: Implement a bidirectional synchronization system where:
- Student interest updates automatically propagate to all associated TMI Plans
- Plans display **current** student interests, not a snapshot from creation time
- Changes are tracked with timestamps for audit purposes

### 1.2 Implementation Components

#### A. StudentInterestSynchronizer Service
```swift
// TMI/Services/StudentInterestSynchronizer.swift
final class StudentInterestSynchronizer {
    static let shared = StudentInterestSynchronizer()
    private let planService = TMIPlanService()

    /// Synchronize student interests across all their TMI Plans
    func synchronizeInterests(for studentId: String, newInterests: [Interest]) async throws {
        // 1. Fetch all plans containing this student
        let plans = try await planService.fetchPlansForStudent(studentId)

        // 2. Update each plan's interests
        for plan in plans {
            var updatedPlan = plan

            // Merge: Keep plan-specific interests + add new student interests
            let existingInterestIds = Set(plan.interests.map { $0.id })
            let newUniqueInterests = newInterests.filter { !existingInterestIds.contains($0.id) }

            updatedPlan.interests = plan.interests + newUniqueInterests
            updatedPlan.lastUpdated = Date()

            try await planService.updatePlan(updatedPlan)
        }

        // 3. Post notification for UI refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentInterestsUpdated"),
            object: nil,
            userInfo: ["studentId": studentId]
        )
    }
}
```

#### B. Modified StudentSurveyFlow Integration
**File**: TMI/Views/Survey/SurveyResultsView.swift

Add synchronization after interests are saved to student:
```swift
// After saving interests to student
Task {
    try await StudentInterestSynchronizer.shared.synchronizeInterests(
        for: studentId,
        newInterests: selectedInterests
    )
}
```

#### C. Dynamic Interest Display in TMIPlanDetailView
**Change**: Instead of showing static `plan.interests`, show **live** student interests

```swift
// TMIPlanDetailView.swift - Add computed property
private var currentStudentInterests: [Interest] {
    // Fetch current interests from all students in the plan
    let allInterests = plan.students.flatMap { $0.interests }

    // Remove duplicates while preserving order
    var seen = Set<String>()
    return allInterests.filter { interest in
        guard let id = interest.id else { return false }
        return seen.insert(id).inserted
    }
}

// Update studentInterestsSection to use currentStudentInterests
private var studentInterestsSection: some View {
    // Use currentStudentInterests instead of plan.interests
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: TMISpacing.sm) {
        ForEach(currentStudentInterests) { interest in
            InterestCard(interest: interest)
        }
    }
}
```

---

## Phase 2: Real-Time Progress Calculation

### 2.1 Progress Architecture

**Current State**:
- `TMIPlan.progress` (Double) - manually set field
- `TMIPlan.calculatedProgress` - computed from goals but not stored

**New System**:
- Eliminate manual `progress` field
- Use `calculatedProgress` exclusively
- Auto-update when goals change
- Add progress history tracking

### 2.2 Implementation

#### A. Update TMIPlan Model
**File**: TMI/Models/TMIPlan.swift

```swift
// REMOVE the manual progress field
// var progress: Double  ❌ DELETE THIS

// UPDATE calculatedProgress to be the source of truth
var calculatedProgress: Double {
    guard !goals.isEmpty else { return 0.0 }

    // Weighted calculation:
    // - Goal completion status (50% weight)
    // - Individual goal progress (50% weight)
    let completedWeight = Double(completedGoalsCount) / Double(goals.count) * 0.5
    let progressWeight = (goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)) * 0.5

    return min(completedWeight + progressWeight, 1.0)
}

// ADD progress history tracking
var progressHistory: [ProgressSnapshot] {
    get { progressTracking?.map { ProgressSnapshot(score: $0.score, date: $0.date) } ?? [] }
}

struct ProgressSnapshot: Codable, Sendable {
    let score: Double
    let date: Date
    let triggeredBy: ProgressTrigger
}

enum ProgressTrigger: String, Codable {
    case goalCompleted
    case goalProgressUpdated
    case goalAdded
    case goalDeleted
}
```

#### B. Auto-Update Progress on Goal Changes
**File**: TMI/Views/TMIPlans/TMIPlanDetailView.swift

Add progress snapshot after goal updates:

```swift
private func updateGoal(_ updatedGoal: Goal) async {
    // ... existing code ...

    // Record progress snapshot
    let newProgressEntry = ProgressEntry(
        score: planWithUpdatedGoals.calculatedProgress,
        date: Date(),
        notes: "Goal \(updatedGoal.status.rawValue.lowercased()): \(updatedGoal.description)"
    )

    var progressTracking = planWithUpdatedGoals.progressTracking ?? []
    progressTracking.append(newProgressEntry)

    let finalPlan = TMIPlan(
        // ... all existing parameters ...
        progressTracking: progressTracking,
        // ...
    )

    let savedPlan = try await service.updatePlan(finalPlan)
    plan = savedPlan
}
```

#### C. Update All Progress References
**Files to Update**:
1. `TMIPlanListView.swift:484` - Change `plan.progress` → `plan.calculatedProgress`
2. `StudentDetailView.swift:484` - Same change
3. `TMIPlanCard.swift:56,64,71` - Already using `calculatedProgress` ✅

**Search & Replace**:
```bash
# Find all manual progress references
grep -r "plan.progress" --include="*.swift"

# Replace with calculatedProgress
```

---

## Phase 3: Actionable Next Actions

### 3.1 Action System Architecture

**Current**: Text-only suggestions with no interactivity
**New**: Each next action has an associated action handler

### 3.2 Implementation

#### A. NextAction Model
**New File**: TMI/Models/NextAction.swift

```swift
import SwiftUI

struct NextAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: NextActionType

    enum NextActionType {
        case completeSurvey(studentId: String)
        case addGoals
        case scheduleMeeting(plan: TMIPlan)
        case reviewProgress(plan: TMIPlan)
        case celebrateAchievements(plan: TMIPlan)
        case addResources
    }
}

extension TMIPlan {
    var nextAction: NextAction {
        if interests.isEmpty {
            return NextAction(
                title: "Complete Interest Survey",
                description: "Complete interest survey with \(primaryStudent?.name ?? "student") to personalize this plan",
                icon: "doc.text.fill",
                color: .tmiWarning,
                action: .completeSurvey(studentId: primaryStudent?.id ?? "")
            )
        } else if goals.isEmpty {
            return NextAction(
                title: "Set Goals",
                description: "Set specific, measurable goals for this intervention",
                icon: "target",
                color: .tmiPrimary,
                action: .addGoals
            )
        } else if calculatedProgress < 0.3 {
            return NextAction(
                title: "Schedule Check-In",
                description: "Schedule check-in to review initial progress and adjust strategies",
                icon: "calendar.badge.plus",
                color: .blue,
                action: .scheduleMeeting(plan: self)
            )
        } else if calculatedProgress < 0.7 {
            return NextAction(
                title: "Review Progress",
                description: "Continue current strategies and document student improvements",
                icon: "chart.line.uptrend.xyaxis",
                color: .tmiSuccess,
                action: .reviewProgress(plan: self)
            )
        } else {
            return NextAction(
                title: "Celebrate & Plan Transition",
                description: "Prepare for transition planning and celebrate achievements",
                icon: "party.popper.fill",
                color: .pink,
                action: .celebrateAchievements(plan: self)
            )
        }
    }
}
```

#### B. Actionable Next Action UI Component
**File**: TMI/Views/TMIPlans/TMIPlanDetailView.swift

Replace the current next action text with an interactive button:

```swift
// Replace lines 248-273
private var nextActionSection: some View {
    let action = plan.nextAction

    Button(action: { handleNextAction(action) }) {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiWarning)
                Text("Next Action")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            HStack(spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: action.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(action.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(action.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(action.color)
            }
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(action.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(action.color.opacity(0.3), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
}

// Add action handler
@State private var showingMeetingScheduler = false

private func handleNextAction(_ action: NextAction) {
    TMIHaptics.lightImpact()

    switch action.action {
    case .completeSurvey(let studentId):
        if let student = plan.students.first(where: { $0.id == studentId }) {
            selectedStudent = student
        }
        showingCompleteSurvey = true

    case .addGoals:
        showingAddGoal = true

    case .scheduleMeeting:
        showingMeetingScheduler = true

    case .reviewProgress:
        // Navigate to progress tracking view
        break

    case .celebrateAchievements:
        // Show celebration/completion flow
        break

    case .addResources:
        showingAddResource = true
    }
}
```

---

## Phase 4: Meeting Scheduling System

### 4.1 Meeting Model

**New File**: TMI/Models/Meeting.swift

```swift
import Foundation
import FirebaseFirestore

struct Meeting: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let description: String?
    let startTime: Date
    let endTime: Date
    let location: String?
    let meetingType: MeetingType

    // Participants
    let organizer: String // User ID
    let participants: [MeetingParticipant]

    // Related entities
    let relatedStudentId: String?
    let relatedPlanId: String?

    // Status
    var status: MeetingStatus
    var notes: String?

    let createdAt: Date
    var lastUpdated: Date

    enum MeetingType: String, Codable {
        case checkIn = "Check-In"
        case progressReview = "Progress Review"
        case parentConference = "Parent Conference"
        case teamMeeting = "Team Meeting"
        case studentMeeting = "Student Meeting"
    }

    enum MeetingStatus: String, Codable {
        case scheduled = "Scheduled"
        case confirmed = "Confirmed"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }
}

struct MeetingParticipant: Codable {
    let userId: String
    let name: String
    let role: ParticipantRole
    var responseStatus: ResponseStatus

    enum ParticipantRole: String, Codable {
        case teacher
        case counselor
        case administrator
        case parent
        case student
        case socialWorker
    }

    enum ResponseStatus: String, Codable {
        case pending
        case accepted
        case declined
        case tentative
    }
}
```

### 4.2 Meeting Scheduling UI

**New File**: TMI/Views/Meetings/ScheduleMeetingView.swift

```swift
import SwiftUI

struct ScheduleMeetingView: View {
    let plan: TMIPlan
    let onMeetingScheduled: (Meeting) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var meetingTitle: String
    @State private var meetingType: Meeting.MeetingType = .checkIn
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var duration: TimeInterval = 30 * 60 // 30 minutes
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedParticipants: Set<MeetingParticipant> = []

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(plan: TMIPlan, onMeetingScheduled: @escaping (Meeting) -> Void) {
        self.plan = plan
        self.onMeetingScheduled = onMeetingScheduled
        _meetingTitle = State(initialValue: "Progress Review: \(plan.title)")
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    // Header
                    headerSection

                    // Meeting Details
                    meetingDetailsSection

                    // Date & Time
                    dateTimeSection

                    // Participants
                    participantsSection

                    // Notes
                    notesSection

                    Spacer(minLength: 100)
                }
                .padding(TMISpacing.screenPadding)
            }

            // Bottom action bar
            VStack {
                Spacer()

                TMIButton(
                    text: "Schedule Meeting",
                    icon: "calendar.badge.plus",
                    style: .primary,
                    isLoading: isSaving,
                    isDisabled: !isValid,
                    action: scheduleMeeting
                )
                .padding(TMISpacing.md)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 15, y: -5)
                )
            }
        }
        .navigationTitle("Schedule Meeting")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ... sections implementation ...

    private var isValid: Bool {
        !meetingTitle.isEmpty && selectedDate > Date()
    }

    private func scheduleMeeting() {
        isSaving = true

        Task {
            do {
                let meeting = Meeting(
                    title: meetingTitle,
                    description: plan.title,
                    startTime: combineDateAndTime(date: selectedDate, time: selectedTime),
                    endTime: combineDateAndTime(date: selectedDate, time: selectedTime).addingTimeInterval(duration),
                    location: location.isEmpty ? nil : location,
                    meetingType: meetingType,
                    organizer: plan.createdBy,
                    participants: Array(selectedParticipants),
                    relatedStudentId: plan.primaryStudent?.id,
                    relatedPlanId: plan.id,
                    status: .scheduled,
                    notes: notes.isEmpty ? nil : notes,
                    createdAt: Date(),
                    lastUpdated: Date()
                )

                try await MeetingService.shared.scheduleMeeting(meeting)

                await MainActor.run {
                    TMIHaptics.successImpact()
                    onMeetingScheduled(meeting)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to schedule meeting: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}
```

### 4.3 Meeting Service

**New File**: TMI/Services/MeetingService.swift

```swift
import Foundation
import FirebaseFirestore

final class MeetingService {
    static let shared = MeetingService()
    private let db = Firestore.firestore()

    func scheduleMeeting(_ meeting: Meeting) async throws {
        guard let userId = FirebaseManager.shared.currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let meetingData: [String: Any] = [
            "title": meeting.title,
            "description": meeting.description ?? "",
            "startTime": meeting.startTime.timeIntervalSince1970,
            "endTime": meeting.endTime.timeIntervalSince1970,
            "location": meeting.location ?? "",
            "meetingType": meeting.meetingType.rawValue,
            "organizer": meeting.organizer,
            "participants": meeting.participants.map { participant in
                [
                    "userId": participant.userId,
                    "name": participant.name,
                    "role": participant.role.rawValue,
                    "responseStatus": participant.responseStatus.rawValue
                ]
            },
            "relatedStudentId": meeting.relatedStudentId ?? "",
            "relatedPlanId": meeting.relatedPlanId ?? "",
            "status": meeting.status.rawValue,
            "notes": meeting.notes ?? "",
            "createdAt": meeting.createdAt.timeIntervalSince1970,
            "lastUpdated": meeting.lastUpdated.timeIntervalSince1970
        ]

        try await db.collection("users").document(userId)
            .collection("meetings")
            .addDocument(data: meetingData)

        // Post notification for calendar integration
        NotificationCenter.default.post(
            name: NSNotification.Name("MeetingScheduled"),
            object: nil,
            userInfo: ["meeting": meeting]
        )
    }

    func fetchMeetings(for planId: String) async throws -> [Meeting] {
        guard let userId = FirebaseManager.shared.currentUser?.uid else {
            throw NSError(domain: "MeetingService", code: 401)
        }

        let snapshot = try await db.collection("users").document(userId)
            .collection("meetings")
            .whereField("relatedPlanId", isEqualTo: planId)
            .order(by: "startTime", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Meeting.self) }
    }
}
```

---

## Phase 5: Integration & Testing

### 5.1 Integration Points

#### A. Update TMIPlanDetailView
Add meeting scheduler sheet:

```swift
.sheet(isPresented: $showingMeetingScheduler) {
    NavigationStack {
        ScheduleMeetingView(plan: plan) { meeting in
            // Refresh plan to show scheduled meeting
            Task {
                await refreshPlan()
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showingMeetingScheduler = false
                }
            }
        }
    }
}
```

#### B. Display Scheduled Meetings in Plan Detail
Add section showing upcoming meetings:

```swift
private var upcomingMeetingsSection: some View {
    VStack(alignment: .leading, spacing: TMISpacing.md) {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
            Text("Upcoming Meetings")
                .font(.tmiTitle3)

            Spacer()

            Button("Schedule") {
                showingMeetingScheduler = true
            }
            .font(.tmiCaption)
            .foregroundColor(.tmiPrimary)
        }

        if scheduledMeetings.isEmpty {
            Text("No meetings scheduled")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        } else {
            ForEach(scheduledMeetings) { meeting in
                MeetingCard(meeting: meeting)
            }
        }
    }
    .tmiCard()
}

@State private var scheduledMeetings: [Meeting] = []

// In .task or .onAppear
Task {
    if let planId = plan.id {
        scheduledMeetings = try await MeetingService.shared.fetchMeetings(for: planId)
    }
}
```

### 5.2 Testing Checklist

#### Survey → Interest Sync Flow
- [ ] Complete survey for student
- [ ] Verify interests saved to student profile
- [ ] Verify all TMI Plans for that student show updated interests
- [ ] Verify notification posted
- [ ] Verify UI refreshes without manual refresh

#### Progress Calculation
- [ ] Create plan with 3 goals
- [ ] Mark 1 goal as "In Progress" (50% progress)
- [ ] Verify plan shows 16.7% progress (1/3 * 50%)
- [ ] Mark goal as "Completed" (100% progress)
- [ ] Verify plan shows 33.3% progress
- [ ] Add another goal, verify progress recalculates
- [ ] Check progress history recorded

#### Next Actions
- [ ] Plan with no interests → "Complete Survey" action works
- [ ] Click action → survey modal opens
- [ ] Plan with interests but no goals → "Set Goals" action works
- [ ] Plan at 25% → "Schedule Meeting" action works
- [ ] Click action → meeting scheduler opens
- [ ] Plan at 50% → "Review Progress" action works
- [ ] Plan at 80%+ → "Celebrate" action works

#### Meeting Scheduling
- [ ] Open meeting scheduler from Next Action
- [ ] Fill in all fields
- [ ] Save meeting
- [ ] Verify meeting saved to Firestore
- [ ] Verify meeting appears in plan detail
- [ ] Verify calendar notification posted
- [ ] Cancel meeting → verify status updated

---

## Phase 6: Firestore Security Rules

Update `firestore.rules`:

```javascript
// Meetings collection
match /users/{userId}/meetings/{meetingId} {
  allow read: if request.auth.uid == userId;
  allow create: if request.auth.uid == userId;
  allow update: if request.auth.uid == userId
                 && (request.resource.data.organizer == userId
                     || isParticipant(request.resource.data.participants, userId));
  allow delete: if request.auth.uid == userId
                 && resource.data.organizer == userId;

  function isParticipant(participants, userId) {
    return participants.hasAny([{userId: userId}]);
  }
}
```

---

## Implementation Order

### Week 1: Interest Synchronization
1. Create `StudentInterestSynchronizer.swift`
2. Integrate with `SurveyResultsView`
3. Update `TMIPlanDetailView` to show live interests
4. Test full sync flow

### Week 2: Progress System
1. Update `TMIPlan` model - remove manual progress
2. Update all progress references to use `calculatedProgress`
3. Add progress history tracking
4. Test with multiple goals and updates

### Week 3: Actionable Next Actions
1. Create `NextAction` model
2. Update `TMIPlanDetailView` with interactive next actions
3. Implement action handlers
4. Test all action types

### Week 4: Meeting Scheduling
1. Create `Meeting` model
2. Implement `MeetingService`
3. Build `ScheduleMeetingView`
4. Integrate with plan detail view
5. Update Firestore security rules

### Week 5: Integration & Polish
1. End-to-end testing
2. Error handling improvements
3. Loading states and optimistic UI
4. Documentation

---

## Success Metrics

- [ ] 100% of student interest changes propagate to plans within 1 second
- [ ] Plan progress accurately reflects goal completion (automated tests)
- [ ] All Next Actions are clickable and functional
- [ ] Meetings can be scheduled and appear in plan detail
- [ ] Zero manual progress updates required
- [ ] Survey completion creates and updates TMI Plans seamlessly

---

## File Structure

```
TMI/
├── Models/
│   ├── NextAction.swift (NEW)
│   └── Meeting.swift (NEW)
├── Services/
│   ├── StudentInterestSynchronizer.swift (NEW)
│   └── MeetingService.swift (NEW)
├── Views/
│   ├── Meetings/
│   │   ├── ScheduleMeetingView.swift (NEW)
│   │   └── MeetingCard.swift (NEW)
│   └── TMIPlans/
│       └── TMIPlanDetailView.swift (MODIFIED)
└── TMI/Models/
    └── TMIPlan.swift (MODIFIED - remove manual progress)
```

---

## End Result

After implementation, users will have:

✅ **Seamless Survey Integration**: Take survey → interests auto-update student → interests auto-sync to all TMI Plans
✅ **Real-Time Progress**: Progress calculated from actual goal completion, not manual updates
✅ **Actionable Interface**: Every "Next Action" is clickable and performs the suggested action
✅ **Full Meeting Management**: Schedule, view, and manage check-ins directly from plans
✅ **Audit Trail**: Complete history of progress changes and when they occurred
✅ **Zero Manual Work**: System handles synchronization and calculations automatically

This creates a fully production-ready, data-driven TMI Plan system.
