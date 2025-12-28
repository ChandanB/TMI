# PR #6: TMI Plans - Approval Workflow

**Status:** ✅ COMPLETE
**Estimated Scope:** 8-10 files, ~1,200 lines
**Actual Scope:** 6 files, ~1,100 lines
**Dependencies:** PR #1 (District Infrastructure)

## Overview

PR #6 implements a comprehensive approval workflow for TMI plans, enabling counselors to submit plans for administrative review, and administrators to approve, reject, or request changes. The system includes full approval history tracking, plan export capabilities (PDF/Text), and a pending approvals widget for the district dashboard.

## Acceptance Criteria

✅ **Approval Status Tracking**
- TMIPlan enhanced with approval status enum (draft, pending, approved, rejected, changes_requested)
- Approval history with full audit trail
- Timestamps for submission and approval actions

✅ **Approval Workflow**
- Counselors can submit plans for approval
- Administrators can approve, reject, or request changes
- Role-based permissions (administrators, district admins, superintendents)
- Comment/feedback system for all approval actions

✅ **Plan Export**
- Export plans to PDF with professional formatting
- Export plans to plain text format
- Include all plan details: goals, students, interests, strategies, approval history
- Shareable exports via iOS share sheet

✅ **Approval UI**
- PlanApprovalView for reviewing pending approvals
- PlanApprovalDetailView for detailed review and action
- PendingApprovalsWidget for district dashboard
- Urgency indicators based on submission age

✅ **Audit Trail**
- Complete approval history with timestamps
- Action-by user tracking
- Comments preserved in history
- All actions logged immutably

## Files Created/Modified

### 1. TMIPlan Model (Enhanced, +70 lines)
**Path:** `TMI/Models/TMIPlan.swift`

**Added Fields:**
```swift
// Approval workflow fields
var approvalStatus: PlanApprovalStatus
var approvalHistory: [ApprovalHistoryEntry]
var submittedForApprovalAt: Date?
var approvedBy: String?
var approvedAt: Date?
var rejectionReason: String?
```

**Added Enums:**
```swift
enum PlanApprovalStatus: String, Codable, CaseIterable {
    case draft
    case pendingApproval
    case approved
    case rejected
    case changesRequested
}

enum ApprovalAction: String, Codable {
    case submitted
    case approved
    case rejected
    case changesRequested
    case resubmitted
}

struct ApprovalHistoryEntry: Codable, Sendable, Hashable {
    let action: ApprovalAction
    let actionBy: String
    let timestamp: Date
    let comment: String?
}
```

**Key Changes:**
- Init method updated with default values for approval fields
- toFirestoreData() updated to serialize approval data
- Status enum includes display names, icons, colors for UI

### 2. PlanApprovalService (350 lines)
**Path:** `TMI/Services/PlanApprovalService.swift`

**Purpose:** Service layer for approval workflow operations

**Key Methods:**
```swift
// Submission
func submitPlanForApproval(_ planId: String, createdBy: String) async throws

// Approval actions
func approvePlan(_ planId: String, createdBy: String, comment: String?) async throws
func rejectPlan(_ planId: String, createdBy: String, reason: String) async throws
func requestChanges(_ planId: String, createdBy: String, feedback: String) async throws

// Fetching
func fetchPendingApprovalPlans(districtId: String) async throws -> [TMIPlan]
func fetchPlansByStatus(_ status: PlanApprovalStatus, userId: String) async throws -> [TMIPlan]
func getApprovalStatistics(districtId: String) async throws -> PlanApprovalStatistics

// Permissions
func hasApprovalPermissions(_ userId: String) async throws -> Bool
func getUserInfo(_ userId: String) async throws -> (name: String, role: String)
```

**Features:**
- District-wide pending plan aggregation
- Role-based permission checking
- Approval statistics calculation
- Approval history tracking with FieldValue.arrayUnion
- User-scoped plan updates via createdBy parameter

**Statistics Model:**
```swift
struct PlanApprovalStatistics: Codable, Sendable {
    let totalPlans: Int
    let draftPlans: Int
    let pendingApprovalPlans: Int
    let approvedPlans: Int
    let rejectedPlans: Int
    let changesRequestedPlans: Int
    let approvalRate: Double
}
```

### 3. PlanExportService (280 lines)
**Path:** `TMI/Services/PlanExportService.swift`

**Purpose:** Export TMI plans to PDF and text formats

**Key Methods:**
```swift
// PDF Export
func exportPlanToPDF(_ plan: TMIPlan) async throws -> URL

// Text Export
func exportPlanToText(_ plan: TMIPlan) async throws -> URL

// Future: Bulk export
func exportMultiplePlans(_ plans: [TMIPlan], title: String) async throws -> URL
```

**PDF Features:**
- Professional multi-page layout using UIGraphicsPDFRenderer
- Automatic page breaks
- Sections: Title, Description, Students, Goals, Interests, Approval History
- Typography: Bold headings, body text, captions
- Metadata: Creator, title, date
- Footer with generation timestamp

**Text Features:**
- Well-formatted plain text output
- All plan details included
- ASCII separators for sections
- Readable date formatting
- Exportable to any text-compatible app

**Export Formats:**
- PDF: `PlanTitle_MM-DD-YYYY.pdf`
- Text: `PlanTitle_MM-DD-YYYY.txt`
- Both saved to temporary directory for iOS sharing

### 4. PlanApprovalView (220 lines)
**Path:** `TMI/Views/TMIPlan/PlanApprovalView.swift`

**Purpose:** Main view for administrators to review pending plans

**Features:**
- **Statistics Header**: Pending count, approved count, approval rate
- **Pending Plans List**: All plans awaiting approval in district
- **Plan Cards**: Show title, model, students, submission time, creator
- **Navigation**: Tap to view detail
- **Empty State**: "All caught up!" when no pending approvals
- **Refresh**: Pull to refresh pending plans

**UI Components:**
- TMIGlassCard with primary/secondary styles
- StatMetric component for KPIs
- PendingPlanCard for each plan
- Loading spinner with progress indicator

**Data Loading:**
- Fetches all pending plans for district
- Loads approval statistics
- Sorts by submission date (newest first)

### 5. PlanApprovalDetailView (370 lines)
**Path:** `TMI/Views/TMIPlan/PlanApprovalDetailView.swift`

**Purpose:** Detailed review and approval interface

**Sections:**
1. **Plan Header**
   - Title, model, approval status badge
   - Status color-coded (draft=gray, pending=orange, approved=green, rejected=red)

2. **Plan Details**
   - Description, students, goals with progress
   - Interests, creation/submission dates
   - Goal status icons and progress percentages

3. **Approval History**
   - Chronological list of all approval actions
   - Action icons and colors
   - Comments/feedback displayed
   - Timestamp for each action

4. **Action Section**
   - Comment text field (optional for approve, required for reject/changes)
   - **Approve Button** (green, full-width)
   - **Request Changes Button** (orange, half-width)
   - **Reject Button** (red, half-width)
   - Processing indicator during submission

**Export Actions:**
- Toolbar menu with "Export to PDF" and "Export to Text"
- Uses iOS share sheet (ActivityViewController)
- Exports include full plan details and approval history

**Validation:**
- Reject and Request Changes require comment
- Approve allows optional comment
- All actions disabled while processing

### 6. PendingApprovalsWidget (200 lines)
**Path:** `TMI/Views/District/PendingApprovalsWidget.swift`

**Purpose:** Dashboard widget showing pending plan approvals

**Features:**
- **Header**: Icon, title, pending count badge, "View All" link
- **Plans Preview**: Top 3 pending plans
- **Urgency Indicators**:
  - 🟡 Yellow: 0-3 days since submission (clock.fill)
  - 🟠 Orange: 3-7 days since submission (exclamationmark.2)
  - 🔴 Red: 7+ days since submission (exclamationmark.3)
- **Navigation**: Tap plan to view detail, tap "View All" for full list
- **Empty State**: Checkmark with "No pending approvals"
- **"+ N more" indicator** if more than 3 plans pending

**UI Design:**
- Compact card layout (fits in dashboard grid)
- Ultra-thin material background
- Color-coded urgency circles
- Relative time display ("2 days ago")

**Data Loading:**
- Auto-loads on appear
- Updates after approval actions
- Shows loading spinner during fetch

## Workflow Integration

### Complete Approval Flow

1. **Plan Creation (Counselor)**
   - Counselor creates TMIPlan in normal workflow
   - Plan starts with `approvalStatus: .draft`
   - createdBy field set to counselor's user ID

2. **Submit for Approval (Counselor)**
   - Counselor triggers "Submit for Approval" action
   - `PlanApprovalService.submitPlanForApproval()` called
   - Status changes to `.pendingApproval`
   - `submittedForApprovalAt` timestamp set
   - Approval history entry added (action: .submitted)

3. **Review Queue (Administrator)**
   - Administrator opens PlanApprovalView
   - Sees all pending plans for district
   - Urgency indicators show submission age
   - Taps plan to open PlanApprovalDetailView

4. **Review & Decision (Administrator)**
   - Reviews plan details, goals, students, interests
   - Reads approval history if resubmitted
   - Options:
     - **Approve**: Plan becomes active, status → `.approved`
     - **Request Changes**: Plan returned, status → `.changesRequested`
     - **Reject**: Plan blocked, status → `.rejected`
   - Adds comment/feedback
   - Action recorded in approval history

5. **Notification & Follow-up (Counselor)**
   - Counselor sees plan status update
   - If changes requested/rejected: reads feedback, makes edits
   - Resubmits plan (approval history entry: action .resubmitted)

6. **Export for Records (Any Approver)**
   - Export approved/rejected plans to PDF
   - Share via email, print, or save to files
   - PDF includes complete approval audit trail

### Permission Model

**Who Can Approve Plans:**
- `administrator` - School administrators
- `admin` - System administrators
- `district_admin` - District administrators
- `superintendent` - District superintendents

**Permission Check:**
```swift
func hasApprovalPermissions(_ userId: String) async throws -> Bool {
    let userDoc = try await db.collection("users").document(userId).getDocument()
    guard let userData = userDoc.data(),
          let roleString = userData["role"] as? String else {
        return false
    }
    return ["administrator", "admin", "district_admin", "superintendent"].contains(roleString)
}
```

**Who Can Submit Plans:**
- `counselor` - Primary plan creators
- `teacher` - Can create and submit plans
- `socialWorker` - Can create and submit plans

## Technical Integration

### Firebase Structure

**User-Scoped Plans with Global Visibility:**
```
users/{userId}/tmiPlans/{planId}
  - approvalStatus: "pending_approval"
  - approvalHistory: [...]
  - submittedForApprovalAt: Timestamp
  - createdBy: userId
```

**District-Wide Query:**
```swift
// Get all users in district
let usersSnapshot = try await db.collection("users")
    .whereField("districtId", isEqualTo: districtId)
    .getDocuments()

// Fetch pending plans for each user
for userDoc in usersSnapshot.documents {
    let plansSnapshot = try await db.collection("users")
        .document(userId)
        .collection("tmiPlans")
        .whereField("approvalStatus", isEqualTo: "pending_approval")
        .getDocuments()
}
```

### Approval History Tracking

**Array Union for Immutable History:**
```swift
try await db.collection("users")
    .document(createdBy)
    .collection("tmiPlans")
    .document(planId)
    .updateData([
        "approvalHistory": FieldValue.arrayUnion([
            [
                "action": "approved",
                "actionBy": currentUser.uid,
                "timestamp": Timestamp(date: Date()),
                "comment": "Looks great!"
            ]
        ])
    ])
```

**Benefits:**
- Immutable audit trail
- Preserves all actions
- Includes actor, timestamp, comment
- Queryable for compliance

### Export Integration

**PDF Generation:**
- Uses UIGraphicsPDFRenderer for iOS
- Multi-page support with automatic breaks
- Professional typography and layout
- Includes all plan data + approval history

**Text Generation:**
- Simple string concatenation
- ASCII formatting for readability
- Cross-platform compatible
- Suitable for email or printing

**Sharing:**
- ActivityViewController for iOS share sheet
- Supports: Email, Files, Print, AirDrop
- Temporary file cleanup handled by OS

## Usage Examples

### For Counselors: Submit Plan for Approval

```swift
struct PlanDetailView: View {
    let plan: TMIPlan
    let approvalService = PlanApprovalService()

    var body: some View {
        // ... plan details ...

        if plan.approvalStatus == .draft {
            Button("Submit for Approval") {
                Task {
                    try await approvalService.submitPlanForApproval(
                        plan.id!,
                        createdBy: plan.createdBy
                    )
                }
            }
        }
    }
}
```

### For Administrators: Review Pending Plans

```swift
struct AdminDashboard: View {
    var body: some View {
        NavigationStack {
            PlanApprovalView() // Shows all pending plans
        }
    }
}

// Or as a widget on district dashboard
struct DistrictDashboardView: View {
    let districtId: String

    var body: some View {
        ScrollView {
            PendingApprovalsWidget(districtId: districtId)
            // ... other widgets ...
        }
    }
}
```

### For Export: Generate PDF Report

```swift
let exportService = PlanExportService()

// Export single plan
let pdfURL = try await exportService.exportPlanToPDF(plan)

// Share via activity controller
let activityVC = UIActivityViewController(
    activityItems: [pdfURL],
    applicationActivities: nil
)
present(activityVC, animated: true)
```

## Key Architectural Decisions

### 1. User-Scoped Plans with District Aggregation
**Decision:** Keep plans in user-scoped collections, aggregate for district view

**Rationale:**
- Preserves existing data structure
- Clear ownership model
- Enables per-user permissions
- District queries aggregate across users

**Trade-off:**
- Requires iterating over users for district view
- Slightly more complex querying
- **Future optimization**: Pre-aggregate pending plans in district collection

### 2. Approval History as Array
**Decision:** Use Firestore array with FieldValue.arrayUnion

**Rationale:**
- Immutable audit trail
- Simple to query and display
- Preserves all historical actions
- No separate collection needed

**Alternative Considered:**
- Separate approvalHistory sub-collection
- **Rejected**: Adds query complexity, unnecessary for typical history size

### 3. Role-Based Permissions in Service Layer
**Decision:** Check permissions in PlanApprovalService, not Firestore rules

**Rationale:**
- Centralized permission logic
- Can fetch user role once
- More flexible for future requirements
- Firestore rules focus on user ownership

**Future Enhancement:**
- Add Firestore rules for server-side enforcement
- Currently relies on application-layer checks

### 4. Export to Temporary Directory
**Decision:** Generate exports in FileManager.default.temporaryDirectory

**Rationale:**
- iOS handles cleanup automatically
- No permission issues
- Works with share sheet
- User can save to Files if needed

**Alternative Considered:**
- Save to Documents directory
- **Rejected**: Clutters user storage, requires explicit cleanup

## Testing Recommendations

### Unit Tests

1. **PlanApprovalService**
   - Test approval status transitions
   - Verify permission checking
   - Test statistics calculation
   - Validate history entry creation

2. **PlanExportService**
   - Test PDF generation (verify file created)
   - Test text generation (verify content)
   - Test filename formatting

### Integration Tests

1. **Approval Workflow**
   - Submit plan → verify status change
   - Approve plan → verify timestamps and history
   - Reject plan → verify reason stored
   - Request changes → verify feedback preserved

2. **District Aggregation**
   - Create plans across multiple users
   - Submit some for approval
   - Verify district query returns all pending

### UI Tests

1. **Approval Views**
   - Load pending plans
   - Tap to view detail
   - Approve plan and verify success
   - Export plan and verify share sheet appears

## Next Steps

### PR #7: Meetings & Notes UI (Next)
- Complete meeting views
- Calendar integration
- Action items management

### PR #8: Compliance & Audit Logging
- Active audit logging
- Compliance settings UI
- Audit log viewer

## Summary

PR #6 successfully implements a complete approval workflow for TMI plans with:

**For Counselors:**
- Submit plans for administrative review
- See approval status (draft, pending, approved, rejected, changes requested)
- Read feedback and resubmit if needed
- Track approval history

**For Administrators:**
- Review pending plans across district
- Approve, reject, or request changes
- Provide feedback comments
- Track approval statistics (pending count, approval rate)
- See urgency indicators for overdue reviews
- Export plans to PDF or text for records

**For Districts:**
- District-wide approval visibility
- Pending approvals widget on dashboard
- Complete audit trail of all approval actions
- Board-ready plan exports
- Compliance-friendly record keeping

**Total PR #6 Impact:**
- 6 files (1 modified, 5 new)
- ~1,100 lines of code
- Complete approval workflow from submission to export
- Immutable audit trail with timestamps and comments
- Professional PDF export for board reporting
- Dashboard widget for at-a-glance pending approvals

The approval workflow ensures accountability, maintains quality standards, and provides district administrators with the oversight needed for effective TMI plan management.
