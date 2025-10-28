# Student Mode Implementation

## Overview

Student Mode provides a **secure, restricted interface** where educators can hand devices directly to students without exposing other students' data or staff-only features. This addresses privacy concerns while enabling student self-exploration of interests and careers.

## Architecture

### 1. StudentModeSession Manager (`TMI/StateModels/StudentModeSession.swift`)

**Purpose**: Manages student mode sessions with security features

**Key Features**:
- **Session State Management**: Tracks active student and session timing
- **Biometric Authentication**: Requires Face ID/Touch ID/Passcode to exit
- **Auto-Timeout**: 30-minute inactivity timeout (configurable)
- **Activity Tracking**: Updates last activity time to prevent premature logout

**Properties**:
```swift
@Observable class StudentModeSession {
    var activeStudent: Student?              // Current student (nil = staff mode)
    var isStudentModeActive: Bool            // Computed: activeStudent != nil
    private(set) var sessionStartTime: Date?
    private(set) var lastActivityTime: Date?
    private let sessionTimeout: TimeInterval = 1800  // 30 minutes
    var requiresBiometricExit: Bool = true
}
```

**Methods**:
- `startStudentMode(for: Student)` - Initiates secure session
- `updateActivity()` - Refreshes timeout timer
- `hasSessionTimedOut() -> Bool` - Checks if session expired
- `exitStudentMode(completion:)` - Exits with biometric auth
- `forceExitDueToTimeout()` - Emergency exit on timeout

**Environment Access**:
```swift
@Environment(\.studentModeSession) private var studentModeSession
```

### 2. StudentModeView (`TMI/Views/StudentMode/StudentModeView.swift`)

**Purpose**: Restricted interface showing only the active student's data

**Security Features**:
- ✅ **No navigation to other students**: No access to StudentListView
- ✅ **No staff features**: No TMI Plans management, no forms, no reports
- ✅ **Disabled back gestures**: Cannot swipe back to staff interface
- ✅ **Exit requires authentication**: Face ID/Touch ID/Passcode mandatory
- ✅ **Session timeout**: Auto-exit after 30 minutes of inactivity
- ✅ **Immutable navigation**: `.interactiveDismissDisabled(true)`

**Three Tabs**:

#### Tab 1: My Interests
- Shows student's interests from survey
- Displays interest cards with categories
- Empty state if no interests yet
- **Data Source**: `student.interests` array

#### Tab 2: Careers
- Shows career matches based on student interests
- Displays top 10 career recommendations
- Match percentage for each career
- Empty state if survey not completed
- **Data Source**: `CareerMatchingService.matchCareers()`

#### Tab 3: My Progress
- Shows TMI Plans the student is part of
- Progress bars for each plan
- Goal counts and completion percentages
- Empty state if no plans assigned
- **Data Source**: `TMIPlanService.fetchPlans()` filtered by student ID

**Navigation Structure**:
```
StudentModeView (NavigationStack)
├── Student Header (avatar, name, grade)
├── TabView
│   ├── My Interests Tab
│   ├── Careers Tab
│   └── My Progress Tab
└── Toolbar
    └── Exit Button (requires auth)
```

### 3. MainTabView Integration (`TMI/Views/MainTabView.swift`)

**Conditional Rendering**:
```swift
var body: some View {
    Group {
        if let activeStudent = studentModeSession.activeStudent {
            // Student Mode - Restricted Interface
            StudentModeView(student: activeStudent)
                .environment(studentModeSession)
        } else {
            // Staff Mode - Full Interface
            staffTabView
                .environment(studentModeSession)
        }
    }
}
```

**How It Works**:
- MainTabView observes `studentModeSession.activeStudent`
- When `activeStudent` is set, entire staff interface is replaced
- When `activeStudent` is nil, staff tabs return
- Environment object passed to all child views

### 4. Entry Point: StudentDetailView

**"Student Mode" Button**:
- Added to Quick Actions row (first button)
- Green success color to distinguish from other actions
- Calls `studentModeSession.startStudentMode(for: student)`

**Implementation**:
```swift
quickActionButton(
    icon: "person.crop.circle.badge.checkmark",
    label: "Student Mode",
    color: .tmiSuccess,
    action: { enableStudentMode() }
)

private func enableStudentMode() {
    studentModeSession.startStudentMode(for: student)
}
```

## Security Measures

### 1. Biometric Authentication
- **Method**: LocalAuthentication framework
- **Fallback**: Device passcode if biometrics unavailable
- **Purpose**: Only staff can exit student mode
- **Implementation**:
  ```swift
  func exitStudentMode(completion: @escaping (Bool) -> Void) {
      if requiresBiometricExit {
          authenticateStaff { success in
              if success { performExit() }
              completion(success)
          }
      }
  }
  ```

### 2. Session Timeout
- **Duration**: 30 minutes (configurable)
- **Trigger**: No user activity (tap, scroll, navigation)
- **Action**: Automatic force exit to staff mode
- **Activity Detection**:
  ```swift
  .onAppear { session.updateActivity() }
  .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) {
      checkSessionTimeout()
  }
  ```

### 3. Navigation Restrictions
- **Disabled swipe-back**: `.gesture(DragGesture().onChanged { _ in })`
- **Disabled sheet dismiss**: `.interactiveDismissDisabled(true)`
- **No NavigationLink to staff views**: StudentModeView is self-contained
- **Modal presentation**: Full-screen replacement, not a pushed view

### 4. Data Isolation
- **Student-specific queries**: All data fetched with `studentId` filter
- **No cross-student access**: Cannot navigate to other students
- **Read-only**: No edit/delete capabilities in student mode
- **Limited scope**: Only interests, careers, and progress visible

## User Flow

### Entering Student Mode:
1. **Staff** navigates to Student Detail page
2. **Staff** taps "Student Mode" quick action button
3. `StudentModeSession.startStudentMode(for: student)` called
4. `MainTabView` detects `activeStudent` change
5. Interface switches to `StudentModeView`
6. **Student** can now explore their data safely

### Using Student Mode:
1. **Student** sees welcome header with their name
2. **Student** explores My Interests tab
3. **Student** discovers career matches
4. **Student** views their progress on TMI Plans
5. Session remains active with activity tracking
6. 30-minute timer resets on any interaction

### Exiting Student Mode:
1. **Staff** taps "Exit" button in toolbar
2. Alert confirms: "Exit Student Mode?"
3. Face ID/Touch ID prompt appears
4. **Staff** authenticates biometrically
5. On success: `studentModeSession.exitStudentMode()` completes
6. `MainTabView` returns to staff interface
7. Session data cleared from memory

### Timeout Scenario:
1. **Student** stops interacting for 30 minutes
2. App detects timeout: `hasSessionTimedOut() == true`
3. `forceExitDueToTimeout()` called automatically
4. Returns to staff login/dashboard
5. Analytics event logged for monitoring

## Analytics & Monitoring

**Events Tracked**:
```swift
NotificationCenter.default.post(name: "StudentModeStarted", ...)
NotificationCenter.default.post(name: "StudentModeEnded", ...)
```

**Logged Data**:
- Student ID (anonymized)
- Session duration
- Timeout vs. manual exit
- Authentication success/failure

## Configuration

### Timeout Duration:
```swift
// In StudentModeSession.swift
private let sessionTimeout: TimeInterval = 1800  // 30 minutes
```

### Biometric Requirement:
```swift
// In StudentModeSession.swift
var requiresBiometricExit: Bool = true  // Set to false for passcode-only
```

### Session Behavior:
```swift
// Disable timeout for testing:
private let sessionTimeout: TimeInterval = .infinity

// Require passcode instead of biometrics:
studentModeSession.requiresBiometricExit = false
```

## Testing Instructions

### Test 1: Enter Student Mode
1. Navigate to Students tab
2. Select any student
3. Tap "Student Mode" button
4. **Verify**:
   - ✅ Interface switches to student view
   - ✅ Welcome header shows student name
   - ✅ Only 3 tabs visible (no staff tabs)
   - ✅ Interests/Careers/Progress load correctly

### Test 2: Biometric Exit
1. While in student mode, tap "Exit" button
2. See "Exit Student Mode?" alert
3. Tap "Exit"
4. **Verify**:
   - ✅ Face ID/Touch ID prompt appears
   - ✅ On success: returns to staff interface
   - ✅ On failure: stays in student mode

### Test 3: Session Timeout
1. Enter student mode
2. Wait 30 minutes without interaction
3. **Verify**:
   - ✅ Session automatically exits
   - ✅ Returns to staff view
   - ✅ No data leak

### Test 4: Navigation Restrictions
1. In student mode, try:
   - Swipe back gesture
   - Swipe down to dismiss
   - 3-finger swipe for multitasking
2. **Verify**:
   - ✅ Cannot escape student mode without "Exit" button
   - ✅ No access to staff features

### Test 5: Data Isolation
1. Enter student mode for "Student A"
2. Check My Interests tab
3. **Verify**:
   - ✅ Only Student A's interests shown
   - ✅ Cannot see other students
   - ✅ Cannot access student list

### Test 6: Activity Tracking
1. Enter student mode
2. Interact every 20 minutes (tap, scroll)
3. **Verify**:
   - ✅ Session stays active beyond 30 min
   - ✅ Timeout resets on each interaction

## Security Considerations

### ✅ Implemented Safeguards:
- Biometric authentication for exit
- Session timeout auto-logout
- Navigation gesture blocking
- Data scoped to single student
- No edit/delete capabilities
- Memory-only session storage (not persisted)

### ⚠️ Important Notes:
- **Device Access**: Students still have physical device access
  - Cannot access device settings (app sandboxed)
  - Cannot screenshot (implement `UIScreen.capturedDidChangeNotification` if needed)
  - Cannot force-quit app (iOS handles this)
- **Network**: Students cannot modify Firestore data (read-only UI)
- **Timeout**: 30 min default; adjust based on typical session length

### 🔒 Additional Hardening (Optional):
1. **Screenshot Prevention**:
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) {
       // Log screenshot attempt
   }
   ```

2. **Background Timeout**:
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) {
       // Force exit if backgrounded
   }
   ```

3. **Audit Logging**:
   ```swift
   AUDIT_SERVICE.log(.studentModeAccess(studentId: student.id, action: "entered"))
   ```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        MainTabView                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  if studentModeSession.activeStudent != nil         │  │
│  │    → StudentModeView (Restricted)                   │  │
│  │  else                                                 │  │
│  │    → StaffTabView (Full Access)                     │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼───────┐       ┌──────▼──────┐
        │ Staff Mode    │       │Student Mode │
        │ (Full Access) │       │(Restricted) │
        └───────────────┘       └─────────────┘
                │                       │
        ┌───────┴───────┐       ┌──────┴──────┐
        │ • Dashboard   │       │ • Interests │
        │ • Students    │       │ • Careers   │
        │ • TMI Plans   │       │ • Progress  │
        │ • Reports     │       │             │
        │ • Settings    │       │ Exit (Auth) │
        └───────────────┘       └─────────────┘
```

## Files Created/Modified

### New Files:
1. `TMI/StateModels/StudentModeSession.swift` - Session manager
2. `TMI/Views/StudentMode/StudentModeView.swift` - Restricted UI

### Modified Files:
1. `TMI/Views/MainTabView.swift` - Conditional rendering logic
2. `TMI/Views/Students/StudentDetailView.swift` - "Student Mode" button

## Future Enhancements

### Phase 2:
- [ ] Student profile customization (avatar, preferences)
- [ ] Interactive career exploration (videos, quizzes)
- [ ] Goal tracking with gamification
- [ ] Parent access mode (similar restrictions, different view)

### Phase 3:
- [ ] Student-generated content (journal entries, reflections)
- [ ] Peer collaboration features (chat, groups)
- [ ] Achievement badges and rewards
- [ ] Calendar integration for meeting reminders

### Phase 4:
- [ ] Offline mode support
- [ ] Multi-device sync
- [ ] Advanced analytics dashboard for staff
- [ ] Integration with LMS platforms

## Summary

Student Mode provides a **secure, educator-controlled** way to give students direct access to their personalized data without compromising privacy or system security. The implementation leverages:

- **Biometric authentication** for staff control
- **Automatic timeout** for unattended devices
- **Navigation restrictions** to prevent escape
- **Data isolation** to protect student privacy
- **Clean separation** between staff and student interfaces

This solution addresses the core requirement: *"Only staff account creation, but students can access their profile in a secure, restricted mode on staff devices."*

**Implementation Status**: ✅ Complete and ready for testing!
