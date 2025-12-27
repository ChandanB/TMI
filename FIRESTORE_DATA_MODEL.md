# Firestore Data Model - Phase 1: District Pilot

## Overview
This document defines the Firestore collections and document structures required for Phase 1 district pilot features.

## Current Architecture Pattern
- **User-scoped collections**: All data under `users/{uid}/...` for privacy
- **Offline-first**: Firebase offline mode enabled
- **No cross-user aggregation**: Current structure prevents district-wide queries

## Phase 1 Extensions

### 1. District & Schools Collections

```
districts/
  {districtId}/                         # District document
    - name: string
    - districtCode: string              # e.g., "DISTRICT-001"
    - state: string
    - region: string
    - createdAt: timestamp
    - settings: map
      - schoolYearStart: timestamp
      - gradelevels: array<string>
    - metadata: map

    schools/                            # Sub-collection
      {schoolId}/
        - name: string
        - districtId: string            # Denormalized for queries
        - schoolCode: string            # e.g., "SCH-001"
        - address: string
        - principal: string
        - grades: array<string>         # ["K", "1", "2", ...]
        - studentCount: number
        - staffCount: number
        - createdAt: timestamp
        - isActive: boolean
```

### 2. Enhanced User Document

```
users/
  {uid}/
    - displayName: string
    - email: string
    - role: string                      # Add: "superintendent", "districtAdmin"
    - districtId: string               # NEW: Links user to district
    - schoolId: string                 # NEW: Links user to school (optional for district admins)
    - permissions: array<string>
    - institutionID: string            # EXISTING (keep for backward compat)
    - institutionName: string          # EXISTING
    - createdAt: timestamp
    - lastLoginAt: timestamp

    # Existing sub-collections remain unchanged
    students/{studentId}/
    tmiPlans/{planId}/
    interests/{interestId}/
    meetings/{meetingId}/
    resources/{resourceId}/
```

### 3. Form Templates & Assignments

```
users/{uid}/
  formTemplates/                        # ENHANCED from existing Form model
    {templateId}/
      - name: string
      - description: string
      - category: string
      - sections: array<FormSection>
      - isActive: boolean
      - isPublic: boolean              # NEW: Can be shared across district
      - districtId: string             # NEW: For district-wide templates
      - schoolId: string               # NEW: For school-wide templates
      - createdBy: string              # uid
      - createdAt: timestamp
      - version: number                # NEW: Template versioning
      - tags: array<string>

  formAssignments/                      # NEW collection
    {assignmentId}/
      - templateId: string
      - assignedBy: string             # uid
      - assignedTo: map                # Cohort definition
        - type: string                 # "all" | "school" | "grade" | "class" | "students"
        - schoolIds: array<string>     # If type: "school"
        - grades: array<string>        # If type: "grade"
        - classIds: array<string>      # If type: "class"
        - studentIds: array<string>    # If type: "students"
      - dueDate: timestamp
      - status: string                 # "active" | "completed" | "overdue"
      - createdAt: timestamp
      - completionStats: map
        - total: number
        - completed: number
        - inProgress: number
        - notStarted: number

  formSubmissions/                      # NEW collection
    {submissionId}/
      - assignmentId: string
      - templateId: string
      - studentId: string
      - submittedBy: string            # uid (student or staff on behalf)
      - data: map<string, any>         # Form field responses
      - submittedAt: timestamp
      - status: string                 # "draft" | "submitted" | "reviewed"
      - reviewedBy: string             # uid (optional)
      - reviewedAt: timestamp          # (optional)
      - score: number                  # (optional, if scorable)
      - feedback: string               # (optional)
```

### 4. Interests & Career Data (Student-Scoped)

```
users/{uid}/
  students/{studentId}/
    - interests: array<string>          # EXISTING: Interest IDs
    - hobbies: array<string>            # EXISTING: Deprecated, merged into interests
    - surveyResults: array<SurveyResult> # EXISTING

    - careerRecommendations: map       # NEW
      - careers: array<CareerMatch>
        - careerId: string
        - title: string
        - matchScore: number           # 0-100
        - matchReasons: array<string>
        - skillsAlignment: array<string>
        - generatedAt: timestamp
      - lastUpdated: timestamp

    - assignedResources: array<map>    # NEW
      - resourceId: string
      - assignedBy: string             # uid
      - assignedAt: timestamp
      - status: string                 # "assigned" | "viewed" | "completed"
      - completedAt: timestamp
      - feedback: string
```

### 5. TMI Plans (Enhanced)

```
users/{uid}/
  tmiPlans/{planId}/
    - title: string                     # EXISTING
    - model: string                     # EXISTING
    - students: array<string>           # EXISTING: Student IDs
    - goals: array<Goal>                # EXISTING
    - progress: number                  # EXISTING

    - approvalStatus: string           # NEW: "draft" | "submitted" | "approved" | "rejected"
    - approvalHistory: array<map>      # NEW
      - reviewedBy: string             # uid
      - action: string                 # "submitted" | "approved" | "rejected" | "revised"
      - timestamp: timestamp
      - notes: string

    - createdBy: string                # ENHANCED: Use actual uid (not "current_user")
    - assignedCounselor: string        # NEW: uid
    - lastReviewDate: timestamp        # NEW
    - nextReviewDate: timestamp        # NEW
```

### 6. Meetings (Complete Implementation)

```
users/{uid}/
  meetings/{meetingId}/
    - title: string                     # EXISTING
    - description: string               # EXISTING
    - startTime: timestamp              # EXISTING
    - endTime: timestamp                # EXISTING
    - meetingType: string               # EXISTING: 6 types
    - status: string                    # EXISTING: 5 states
    - organizer: string                 # uid
    - participants: array<MeetingParticipant> # EXISTING
    - relatedStudentIds: array<string>  # EXISTING
    - relatedPlanId: string             # EXISTING

    - notes: string                    # NEW: Meeting notes (different from StudentNote)
    - action items: array<map>          # NEW
      - description: string
      - assignedTo: string             # uid
      - dueDate: timestamp
      - completed: boolean

    - attachments: array<map>          # NEW
      - name: string
      - url: string                    # Firebase Storage URL
      - uploadedBy: string             # uid
      - uploadedAt: timestamp
```

### 7. Audit Logs (Compliance)

```
districts/{districtId}/
  auditLogs/                            # NEW collection
    {logId}/
      - eventType: string               # "view_student" | "export_data" | "edit_plan" | etc.
      - actor: string                   # uid
      - actorRole: string
      - targetType: string              # "student" | "plan" | "form_submission"
      - targetId: string
      - action: string
      - timestamp: timestamp
      - ipAddress: string
      - metadata: map                   # Additional context
      - dataClassification: string      # For sensitive data access
```

### 8. District Aggregations (For Reporting)

```
districts/{districtId}/
  analytics/                            # NEW collection (daily aggregations)
    {date}/                             # Document per day (YYYY-MM-DD)
      - date: timestamp
      - schools: map<schoolId, SchoolMetrics>
        - studentCount: number
        - activePlansCount: number
        - completedPlansCount: number
        - engagementRate: number
        - formCompletionRate: number
        - flaggedStudentsCount: number

      - districtTotals: map
        - totalStudents: number
        - totalActivePlans: number
        - avgEngagementRate: number
        - avgFormCompletionRate: number
        - totalFlaggedStudents: number

      - topInsights: array<string>      # AI-generated district insights
      - generatedAt: timestamp
```

## Firestore Security Rules Updates

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    function getUserDistrictId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.districtId;
    }

    function isDistrictAdmin() {
      return getUserRole() in ['superintendent', 'districtAdmin', 'administrator'];
    }

    function isSameDistrict(districtId) {
      return getUserDistrictId() == districtId;
    }

    // User documents (existing, enhanced)
    match /users/{userId} {
      allow read: if isAuthenticated() && (
        request.auth.uid == userId ||
        isDistrictAdmin()  // District admins can view users in their district
      );
      allow write: if request.auth.uid == userId;

      // Sub-collections (existing, user-scoped)
      match /students/{studentId} {
        allow read, write: if request.auth.uid == userId;
      }

      match /tmiPlans/{planId} {
        allow read: if request.auth.uid == userId || isDistrictAdmin();
        allow write: if request.auth.uid == userId;
      }

      match /interests/{interestId} {
        allow read, write: if request.auth.uid == userId;
      }

      // Form templates
      match /formTemplates/{templateId} {
        allow read: if request.auth.uid == userId ||
                       (resource.data.isPublic == true && isSameDistrict(resource.data.districtId));
        allow write: if request.auth.uid == userId;
      }

      // Form assignments
      match /formAssignments/{assignmentId} {
        allow read: if request.auth.uid == userId || isDistrictAdmin();
        allow write: if request.auth.uid == userId;
      }

      // Form submissions
      match /formSubmissions/{submissionId} {
        allow read: if request.auth.uid == userId ||
                       request.auth.uid == resource.data.submittedBy ||
                       isDistrictAdmin();
        allow create: if isAuthenticated();
        allow update: if request.auth.uid == userId || request.auth.uid == resource.data.submittedBy;
      }

      // Meetings
      match /meetings/{meetingId} {
        allow read: if request.auth.uid == userId ||
                       request.auth.uid in resource.data.participants;
        allow write: if request.auth.uid == userId;
      }

      // Resources
      match /resources/{resourceId} {
        allow read, write: if request.auth.uid == userId;
      }
    }

    // Districts (NEW)
    match /districts/{districtId} {
      allow read: if isAuthenticated() && isSameDistrict(districtId);
      allow write: if isDistrictAdmin() && isSameDistrict(districtId);

      // Schools
      match /schools/{schoolId} {
        allow read: if isAuthenticated() && isSameDistrict(districtId);
        allow write: if isDistrictAdmin() && isSameDistrict(districtId);
      }

      // Audit logs (read-only for most, write via server-side only recommended)
      match /auditLogs/{logId} {
        allow read: if isDistrictAdmin() && isSameDistrict(districtId);
        allow write: if isAuthenticated(); // Server triggers preferred
      }

      // Analytics aggregations
      match /analytics/{date} {
        allow read: if isDistrictAdmin() && isSameDistrict(districtId);
        allow write: if false; // Server-side only (Cloud Functions)
      }
    }

    // Global AI-generated resources (existing, shared)
    match /generatedResources/{interestId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
  }
}
```

## Firestore Indexes Required

```yaml
# firestore.indexes.json

indexes:
  # Form assignments by user and status
  - collectionGroup: formAssignments
    queryScope: COLLECTION
    fields:
      - fieldPath: assignedBy
        order: ASCENDING
      - fieldPath: status
        order: ASCENDING
      - fieldPath: dueDate
        order: DESCENDING

  # Form submissions by student and assignment
  - collectionGroup: formSubmissions
    queryScope: COLLECTION
    fields:
      - fieldPath: studentId
        order: ASCENDING
      - fieldPath: assignmentId
        order: ASCENDING
      - fieldPath: submittedAt
        order: DESCENDING

  # Meetings by organizer and start time
  - collectionGroup: meetings
    queryScope: COLLECTION
    fields:
      - fieldPath: organizer
        order: ASCENDING
      - fieldPath: startTime
        order: ASCENDING

  # Audit logs by district and timestamp
  - collectionGroup: auditLogs
    queryScope: COLLECTION
    fields:
      - fieldPath: districtId
        order: ASCENDING
      - fieldPath: timestamp
        order: DESCENDING

  # Plans by approval status
  - collectionGroup: tmiPlans
    queryScope: COLLECTION
    fields:
      - fieldPath: approvalStatus
        order: ASCENDING
      - fieldPath: lastReviewDate
        order: DESCENDING
```

## Migration Strategy

### 1. Backward Compatibility
- Existing user-scoped collections remain unchanged
- New fields added to existing documents are optional
- Legacy data structures continue to work

### 2. Data Migration Steps
1. Add `districtId` and `schoolId` to existing users (optional, can be null)
2. Create sample district and school documents
3. Migrate existing form templates to new structure (add `isPublic: false` by default)
4. No changes needed for students, interests, or resources

### 3. Seeding Sample Data
```swift
// Create sample district
{
  "districtId": "demo-district-001",
  "name": "Demo Unified School District",
  "districtCode": "DUSD-001",
  "state": "CA",
  "region": "Bay Area"
}

// Create sample schools
[
  {
    "schoolId": "school-001",
    "name": "Lincoln Elementary",
    "schoolCode": "LES-001",
    "grades": ["K", "1", "2", "3", "4", "5"]
  },
  {
    "schoolId": "school-002",
    "name": "Washington Middle School",
    "schoolCode": "WMS-001",
    "grades": ["6", "7", "8"]
  },
  {
    "schoolId": "school-003",
    "name": "Jefferson High School",
    "schoolCode": "JHS-001",
    "grades": ["9", "10", "11", "12"]
  }
]
```

## Performance Considerations

### 1. Pagination
- All list queries use pagination (limit + startAfter cursor)
- Default page size: 20 items
- Maximum page size: 100 items

### 2. Caching Strategy
- District analytics: Cache for 1 hour
- Form templates: Cache for 30 minutes
- Student data: Cache for 5 minutes (more dynamic)

### 3. Offline Support
- Firebase offline persistence enabled globally
- All queries work offline with cached data
- Write operations queued and synced when online

### 4. Aggregation Strategy
- District analytics pre-aggregated via Cloud Functions (daily)
- Real-time metrics calculated client-side with caching
- Avoid N+1 queries: use batched reads where possible

## Notes
- This model supports multi-tenant (district) architecture while maintaining user-scoped privacy
- Audit logging positioned for FERPA/COPPA compliance
- Analytics pre-aggregation prevents expensive cross-document queries
- Firestore rules enforce district-level data isolation
