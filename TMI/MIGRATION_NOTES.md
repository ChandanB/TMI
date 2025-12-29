# Student Interests Migration Notes

**Date:** December 2025
**Status:** Completed

## Overview
The handling of student interests in TMI has been migrated from a legacy inline array (`Student.interests`) to a scalable, edge-based model using `StudentInterestService` and Firestore subcollections. This change ensures that student records remain lightweight and allows for scalable querying of interest-based data (e.g., peer discovery, global stats).

## Key Changes

### 1. Data Model (`Student.swift`)
- The `interests` property on `Student` is now **deprecated**.
- Do not access `student.interests` directly. Instead, use:
  - `StudentInterestService.shared.getStudentInterests(studentId:)`
  - `student.fetchInterestsFromEdgeCollection()` (async extension method)
  - `student.getInterestCount()` (async extension method)

### 2. Service Layer
- **StudentInterestService:** The primary service for managing student interests. It now supports fetching interests for a student and finding students by interest (reverse lookup).
- **InterestLibraryService:** Manages the global definition of interests. All student interests must link back to a valid library ID.
- **StudentInterestSynchronizer:** Legacy logic that duplicated interests into TMI Plans or Student documents has been refactored. The source of truth is now the `studentInterests` subcollection.

### 3. UI Refactoring
- **DashboardView:** Updated to calculate "Interests Identified" using asynchronous fetching rather than synchronous reduction.
- **StudentModeView:** Updated to fetch "My Interests" from the edge collection asynchronously.
- **AddStudentView / AddStudentStateModel:** Updated to save interests to the edge collection after creating the student profile.
- **StudentPeerProfileView & StudentInterestDetailView:** Peer discovery features now query the edge collection to find students with shared interests.

## Developer Guidelines
- **Fetching Interests:** Always use `await student.fetchInterestsFromEdgeCollection()` in your views. Perform this fetch in `.task` modifiers or StateModels.
- **Saving Interests:** Use `StudentInterestService.shared.saveStudentInterest(...)`.
- **Counts:** Use `await student.getInterestCount()` for badge counts to avoid loading full objects.
- **Global Stats:** For dashboard stats, utilize parallel fetching with `TaskGroup` if necessary, or future backend aggregation functions.

## Deprecated Usages
- Any code referencing `student.interests` will trigger a compiler warning.
- `TMIPlan.interests` remains valid as it represents a snapshot of interests relevant to a specific plan context, distinct from the student's global interest profile.

## Verification
- Repository-wide search confirms zero remaining usages of `Student.interests` property for logic (deprecation warnings exist in the definition itself).
- All key views (Dashboard, Student Profile, Peer Profile, TMI Plans) have been verified to function with the new service.
