# Phase 1: District Pilot - PR Implementation Plan

## Overview
Break Phase 1 into 8 shippable PRs, each independently testable and deployable.

---

## PR #1: District & Schools Infrastructure + RBAC Enhancement
**Estimated Scope**: 6-8 files, ~1200 lines
**Dependencies**: None
**Priority**: Highest (foundation for all other PRs)

### Changes
1. **Models**
   - `District.swift` - New model
   - `School.swift` - New model
   - `TMIUser.swift` - Add `districtId`, `schoolId` fields
   - `UserRole.swift` - Add `superintendent`, `districtAdmin` roles

2. **Services**
   - `DistrictService.swift` - CRUD for districts and schools
   - `FirestoreConstants.swift` - Add district/school collection constants

3. **Seeding**
   - `SampleDataSeeder.swift` - Add district/school sample data

4. **Security**
   - Update Firestore rules (in `firestore.rules`)
   - `RBACManager.swift` - Enhance with district-level checks

5. **MainTabView**
   - Update tab allowed roles to include `superintendent`

### Acceptance Criteria
- [ ] `UserRole` enum includes `.superintendent` and `.districtAdmin`
- [ ] `District` and `School` models are Codable with Firestore methods
- [ ] `DistrictService` can create/read/update districts and schools
- [ ] Sample data includes 1 district with 3 schools
- [ ] Firestore rules enforce district-scoped access
- [ ] Superintendent can see Dashboard, Students, TMI Plans, Settings tabs
- [ ] Unit tests for District and School models
- [ ] App builds and runs with new roles

---

## PR #2: District Cockpit Dashboard
**Estimated Scope**: 10-12 files, ~1800 lines
**Dependencies**: PR #1
**Priority**: Highest (superintendent "wow" feature)

### Changes
1. **Models**
   - `DistrictMetrics.swift` - KPI data model
   - `DistrictAnalytics.swift` - Analytics aggregation model

2. **Services**
   - `DistrictAnalyticsService.swift` - Fetch/compute district metrics
   - `DistrictExportService.swift` - Generate reports (PDF/CSV)

3. **View Models**
   - `DistrictDashboardViewModel.swift` - Dashboard state + data fetching

4. **Views** (new directory: `Views/District/`)
   - `DistrictDashboardView.swift` - Main dashboard
   - `DistrictKPICard.swift` - KPI display component
   - `DistrictSchoolFilter.swift` - Filter by school/grade
   - `StudentsNeedingAttentionList.swift` - Flagged students
   - `DistrictInsightsSummary.swift` - AI insights for district

5. **MainTabView**
   - Add `.districtDashboard` tab (only for superintendent/districtAdmin)

### Acceptance Criteria
- [ ] District dashboard shows 6 KPIs: engagement rate, active plans, plan completion %, form completion %, flagged students, total students
- [ ] Filters work: school, grade, date range
- [ ] "Students needing attention" list shows students with low engagement or overdue items
- [ ] AI insights summary uses existing `AIInsightsService` patterns
- [ ] Export to PDF generates board-ready report with district logo/header
- [ ] Export to CSV generates metrics spreadsheet
- [ ] Dashboard loads within 2 seconds with sample data
- [ ] Works offline with cached data
- [ ] Superintendent can access; other roles cannot

---

## PR #3: Forms & Surveys - Template Management
**Estimated Scope**: 8-10 files (refactor existing + new), ~1400 lines
**Dependencies**: PR #1
**Priority**: High (forms foundation)

### Changes
1. **Models**
   - `FormTemplate.swift` - Enhance with `isPublic`, `districtId`, `version`
   - `FormSection.swift` - Already exists, no changes
   - `FormField.swift` - Already exists, no changes

2. **Services**
   - `FormTemplateService.swift` - CRUD, JSON import/export, district-wide sharing
   - Update Firestore path: `users/{uid}/formTemplates/{templateId}`

3. **View Models**
   - `FormTemplateLibraryViewModel.swift` - Template browsing state

4. **Views** (refactor existing `Views/Forms/`)
   - `FormTemplateLibraryView.swift` - Browse templates
   - `FormTemplateDetailView.swift` - Preview template
   - `FormTemplateImportView.swift` - JSON import
   - `FormTemplateExportView.swift` - JSON export

5. **Sample Data**
   - Enhance existing Parental Incarceration template with new fields
   - Add 3 more sample templates

### Acceptance Criteria
- [ ] Template library shows personal + district-wide templates
- [ ] Preview shows full template structure (sections, fields, validation rules)
- [ ] Import JSON creates new template
- [ ] Export JSON downloads template file
- [ ] Templates persist to Firestore correctly
- [ ] District-wide templates visible to all staff in district
- [ ] No "Coming Soon" or TODO placeholders
- [ ] Unit tests for FormTemplateService

---

## PR #4: Forms & Surveys - Assignment & Completion Workflow
**Estimated Scope**: 12-14 files, ~2000 lines
**Dependencies**: PR #3
**Priority**: High (forms end-to-end)

### Changes
1. **Models**
   - `FormAssignment.swift` - New model
   - `FormSubmission.swift` - Enhance existing

2. **Services**
   - `FormAssignmentService.swift` - Assign forms to cohorts
   - `FormSubmissionService.swift` - Submit, review, score

3. **View Models**
   - `FormAssignmentViewModel.swift` - Assignment state
   - `FormSubmissionViewModel.swift` - Submission state

4. **Views** (refactor/enhance existing)
   - `FormAssignmentView.swift` - Assign form to cohort
   - `FormCompletionView.swift` - Student-facing form
   - `FormSubmissionsListView.swift` - Staff view submissions
   - `FormSubmissionDetailView.swift` - View individual submission
   - `FormAnalyticsView.swift` - Completion rates, score aggregation

5. **Student Mode**
   - `StudentModeFormsView.swift` - Assigned forms for student

### Acceptance Criteria
- [ ] Staff can assign a template to: all students, specific school, specific grade, specific students
- [ ] Assignment tracks status: assigned → in-progress → submitted → overdue
- [ ] Student Mode shows assigned forms with completion status
- [ ] Student can complete form and submit
- [ ] Staff can view all submissions by template or by student
- [ ] Analytics show completion rates per school/grade
- [ ] Basic score aggregation (if form has scored fields)
- [ ] Export submissions to CSV
- [ ] No "Coming Soon" placeholders
- [ ] Works offline (submissions queued)

---

## PR #5: Interests → Career Explorer → Resources (Connected Workflow)
**Estimated Scope**: 10-12 files (mostly enabling existing), ~1000 lines
**Dependencies**: PR #1
**Priority**: Medium (enables 3 tabs)

### Changes
1. **Models**
   - `CareerRecommendation.swift` - Enhance Career model with match metadata

2. **Services**
   - `CareerRecommendationService.swift` - Generate recommendations from interests
   - `ResourceRecommendationService.swift` - Recommend resources based on career/interests

3. **Views**
   - Enable `.interests` tab in MainTabView
   - Enable `.careerExplorer` tab in MainTabView
   - Enable `.resources` tab in MainTabView
   - `InterestProfileView.swift` - Student interest summary page (printable)
   - `CareerRecommendationsView.swift` - Personalized career list
   - `CareerDetailView.swift` - Enhance with "why this matches" explanation
   - `ResourceAssignmentView.swift` - Staff assigns resource to student
   - `StudentResourcesView.swift` - Student-facing assigned resources

4. **Student Detail**
   - Add "Interest Profile" button to `StudentDetailView.swift`
   - Add "Career Recommendations" section
   - Add "Assigned Resources" section

### Acceptance Criteria
- [ ] Interests tab enabled for teacher, counselor, administrator, superintendent
- [ ] Student can self-report interests (in Student Mode)
- [ ] Staff can add/edit interests for students
- [ ] Interest Profile page shows categories, TMI relevance, career pathways, skills
- [ ] Career Explorer generates recommendations from student interests + survey results
- [ ] Career detail shows: recommended careers, skills match, "why this matches" explanation
- [ ] Recommended resources appear based on career/interest alignment
- [ ] Staff can assign a resource to a student with due date
- [ ] Student can view assigned resources and mark as completed
- [ ] Resource library tab shows categories, search, bookmark
- [ ] No "Coming Soon" placeholders in enabled tabs
- [ ] Existing TODOs resolved for these features

---

## PR #6: TMI Plans - Approval Workflow & Enhanced Tracking
**Estimated Scope**: 8-10 files, ~1200 lines
**Dependencies**: PR #1
**Priority**: High (core educator workflow)

### Changes
1. **Models**
   - `TMIPlan.swift` - Add `approvalStatus`, `approvalHistory[]`, `assignedCounselor`, `lastReviewDate`, `nextReviewDate`
   - Fix `createdBy` to use actual `AuthStateModel.currentUser.userID`

2. **Services**
   - `TMIPlanService.swift` - Add approval methods (submit, approve, reject)
   - Update create/update to use real user ID

3. **View Models**
   - `TMIPlanDetailViewModel.swift` - Add approval state

4. **Views**
   - `TMIPlanDetailView.swift` - Add approval section (draft/submitted/approved badges)
   - `TMIPlanApprovalView.swift` - Counselor/admin approval interface
   - `TMIPlanHistoryView.swift` - Show approval history
   - `TMIPlanExportView.swift` - Export plan summary (PDF/text)

5. **Dashboard**
   - Add "Plans Pending Approval" widget to `DashboardView.swift`

### Acceptance Criteria
- [ ] Staff can create plan (status: draft)
- [ ] Staff can submit plan for approval (status: submitted)
- [ ] Counselor/administrator can approve or reject with notes
- [ ] Approval history shows all actions with timestamps
- [ ] Plan shows assigned counselor, last review date, next review date
- [ ] Progress tracking shows milestones and notes
- [ ] Export generates PDF summary (or shareable text)
- [ ] Dashboard shows "Pending Approval" count
- [ ] `createdBy` uses actual user ID (not "current_user" placeholder)
- [ ] No placeholders or TODOs

---

## PR #7: Meetings & Notes - Complete UI Implementation
**Estimated Scope**: 10-12 files, ~1600 lines
**Dependencies**: PR #1
**Priority**: Medium (backend exists, add UI)

### Changes
1. **Models**
   - `Meeting.swift` - Already complete, add `notes` and `actionItems[]` fields
   - `StudentNote.swift` - Already in Student model, no changes

2. **Services**
   - `MeetingService.swift` - Already complete, add note methods

3. **View Models**
   - `MeetingListViewModel.swift` - Meeting list state
   - `MeetingDetailViewModel.swift` - Meeting detail state

4. **Views** (NEW directory: `Views/Meetings/`)
   - `MeetingsListView.swift` - View all meetings (calendar view + list view)
   - `MeetingDetailView.swift` - Meeting detail with participants, agenda, notes
   - `CreateMeetingView.swift` - Schedule new meeting
   - `EditMeetingView.swift` - Edit meeting
   - `MeetingNotesView.swift` - Take/view meeting notes
   - `MeetingActionItemsView.swift` - Manage action items

5. **Student Detail**
   - `StudentNotesView.swift` - View student notes (already embedded, extract to own view)
   - Link meeting notes to student profile

6. **MainTabView**
   - Add `.meetings` tab (optional, or accessible via Dashboard quick action)

### Acceptance Criteria
- [ ] "View All Meetings" accessible (tab or dashboard link)
- [ ] Calendar view shows meetings by week/month
- [ ] List view shows upcoming and past meetings
- [ ] Create meeting: title, type, date/time, participants, related students
- [ ] Meeting detail shows: info, participants (with RSVP status), notes, action items
- [ ] Meeting notes show correct author (from `AuthStateModel.currentUser`)
- [ ] Action items can be created, assigned, and marked complete
- [ ] Student profile shows related meetings
- [ ] Student notes show correct author and category
- [ ] No "Coming Soon" placeholders

---

## PR #8: Compliance & Audit Logging
**Estimated Scope**: 6-8 files, ~1000 lines
**Dependencies**: PR #1, PR #2
**Priority**: Medium (compliance for district procurement)

### Changes
1. **Models**
   - `AuditEvent.swift` - Audit log entry model

2. **Services**
   - `AuditService.swift` - Already exists, verify active usage and enhance
   - Add audit calls to sensitive operations:
     - Viewing student sensitive data
     - Exporting data (district dashboard, forms, plans)
     - Editing TMI plans
     - Approving plans

3. **Views**
   - `SettingsView.swift` - Add "Privacy & Compliance" section
   - `ConsentManagementView.swift` - Display consent records clearly
   - `DataRetentionSettingsView.swift` - Show data retention policies
   - `AuditLogView.swift` - Administrator view of audit logs (read-only)

4. **Firestore**
   - Implement audit log writes to `districts/{districtId}/auditLogs/{logId}`
   - Ensure audit logs capture: eventType, actor, targetType, targetId, timestamp, ipAddress, dataClassification

### Acceptance Criteria
- [ ] Settings shows "Privacy & Compliance" section with:
   - [ ] User's consent records
   - [ ] Data retention policy explanation
   - [ ] Link to audit log (administrators only)
- [ ] Audit log captures:
   - [ ] Viewing student data (with data classification)
   - [ ] Exporting any data (district reports, forms, plans)
   - [ ] Editing TMI plans
   - [ ] Approving plans
- [ ] Audit log view shows filtered log entries (by date, user, event type)
- [ ] Audit entries include all required fields per FERPA/COPPA
- [ ] No sensitive data in audit log messages (only IDs)
- [ ] Administrators can view logs; other roles cannot

---

## Summary Table

| PR # | Feature Area | Files | Lines | Priority | Dependencies |
|------|-------------|-------|-------|----------|--------------|
| 1 | District Infrastructure + RBAC | 6-8 | ~1200 | Highest | None |
| 2 | District Cockpit Dashboard | 10-12 | ~1800 | Highest | PR #1 |
| 3 | Forms: Templates | 8-10 | ~1400 | High | PR #1 |
| 4 | Forms: Assignment & Completion | 12-14 | ~2000 | High | PR #3 |
| 5 | Interests → Career → Resources | 10-12 | ~1000 | Medium | PR #1 |
| 6 | TMI Plans: Approval Workflow | 8-10 | ~1200 | High | PR #1 |
| 7 | Meetings & Notes UI | 10-12 | ~1600 | Medium | PR #1 |
| 8 | Compliance & Audit | 6-8 | ~1000 | Medium | PR #1, #2 |
| **TOTAL** | **All Features** | **70-96** | **~11,200** | - | - |

## Implementation Order

### Week 1: Foundation
- PR #1: District Infrastructure

### Week 2: Core District Features
- PR #2: District Dashboard
- PR #6: TMI Plan Approvals

### Week 3: Forms End-to-End
- PR #3: Form Templates
- PR #4: Form Assignment & Completion

### Week 4: Connections & Compliance
- PR #5: Interests → Career → Resources
- PR #7: Meetings & Notes
- PR #8: Compliance & Audit

## Testing Strategy

### Unit Tests (Minimum)
- All service methods (happy path + error cases)
- Model validation logic
- RBAC permission checks

### Integration Tests
- Firebase connectivity
- Firestore CRUD operations
- Offline mode behavior

### UI Smoke Test
- App launches without crash
- Superintendent can view district dashboard
- Student can complete assigned form
- Staff can create and approve TMI plan

## Notes
- Each PR is independently shippable and testable
- PRs can be parallelized after PR #1 completes (e.g., PR #3 and PR #6 can run concurrently)
- No "TODO" or "Coming Soon" placeholders allowed in Phase 1 features
- All acceptance criteria must pass before merging
