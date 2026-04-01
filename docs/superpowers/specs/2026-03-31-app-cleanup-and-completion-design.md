# App Cleanup & Feature Completion

**Date:** 2026-03-31
**Status:** Approved

## Overview

Five coordinated changes to clean up the TMI app: remove AI from careers, fix survey data persistence, add sheet minimum sizes, clean up Settings, and make Edit Profile functional.

---

## 1. Remove AI from Career System

### Delete

| File | Reason |
|------|--------|
| `TMI/Services/AI/AICareerGenerator.swift` | Rule-based AI career generation |
| `TMI/Services/AI/FoundationModelsService.swift` | Apple Foundation Models integration |
| `TMI/Services/AIInsightsService.swift` | Unified AI service orchestrator |
| `TMI/Services/AI/AIPromptBuilder.swift` | Prompt generation for Foundation Models |
| Any `FallbackFoundationModelsService` | Fallback AI service |
| Any `Generable` career/insight types | Foundation Models structured output types |

### Replace With

- **`CareerMatchingService`** becomes the sole career data source. It already contains 32 careers across 8 categories:
  - Audio & Media, Technology, Creative Arts, Health & Wellness, Sports & Athletics, Business & Entrepreneurship, Education, Social Services
- **Career search** becomes a filter over the static catalog matching by title, field, and skills keywords.
- **Personalized recommendations** become deterministic: student interest clusters map to career categories, matched careers sorted by relevance score.

### CareerExplorerView Changes

- Search filters the static career list instead of calling AI services.
- Remove "Trending careers" or replace with a curated featured section.
- Remove discovery insights section (was AI-generated).
- Remove any "AI-generated" badges, timestamps, or metadata from the Career model.

### CareerExplorerStateModel Changes

- Remove all AI service dependencies.
- `performSearch()` filters `CareerMatchingService` data instead of calling `AIInsightsService`.
- `loadPersonalizedRecommendations()` uses deterministic interest-to-career mapping.

---

## 2. Fix Survey Data Persistence Pipeline

### Problem

The survey UI collects data correctly through 6 steps, but selections don't persist or propagate. Interests don't appear on the student profile after completion. Career matches don't reflect actual selections. Saving a career doesn't persist anywhere.

### Fix Points

#### 2a. Interest Selections → Student Profile

- After survey completion, `convertClustersToInterests()` creates `Interest` objects.
- Ensure these are written to the student's Firestore edge collection via `StudentInterestService.saveSurveyResults()`.
- Verify the student detail view reads from this same collection to display interests.
- After completing the survey and returning to student detail, the interests section must immediately reflect selections.

#### 2b. Career Matches → Reflect Actual Selections

- Feed the actual selected interest clusters (with proper weights from the survey) into `CareerMatchingService.matchCareers()`.
- With AI removed, matching becomes: selected interest categories → filter 32-career static database → sort by relevance score based on interest alignment.

#### 2c. Career Selection → Persistence

- When a user saves a career from results, persist to `users/{uid}/students/{studentId}/savedCareers` collection in Firestore.
- Display saved careers on the student detail view in the existing careers section.

#### 2d. Remove Survey Delivery Service Placeholders

- Remove `SurveyDeliveryService.deliverViaNotification()` placeholder.
- Remove `extractGuardianEmail()` placeholder.
- Remove placeholder email delivery. Surveys are in-app only for now.

---

## 3. Sheet Minimum Sizes

### Approach

Create a shared `ViewModifier` in `TMIComponentLibrary`:

```swift
struct TMISheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 500, minHeight: 400)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func tmiSheetStyle() -> some View {
        modifier(TMISheetStyle())
    }
}
```

### Application

- Apply `.tmiSheetStyle()` to all ~83 sheet presentations across the app.
- Sheets with existing custom sizing that still makes sense keep their constraints.
- Sheets with existing sizing that conflicts adopt the new default.

### Files to Update

All files presenting `.sheet()` modifiers, including but not limited to:
- Forms views (13+ sheets)
- TMI Plans views (10+ sheets)
- Career & Student views (8+ sheets)
- Meetings views (6+ sheets)
- Settings & Admin views (6+ sheets)
- Authentication views (4 sheets)
- Resources & Surveys (6+ sheets)
- Components (5+ sheets)

---

## 4. Settings Cleanup

### Remove from `SettingsView.swift`

**Staff Settings section (entire section):**
- Student Mode Settings
- Notification Preferences
- Meeting Defaults

**Support & Legal section (entire section):**
- Help Center
- Contact Support
- Privacy Policy
- Terms of Service
- App Version

### What Remains

- Account section (Edit Profile button)
- District Administration (district admins only)
- My Settings (students only)
- Parent Settings (parents/guardians only)
- Account Actions (Log Out, Delete Account)

---

## 5. Edit Profile

### Wire Up Navigation

- Connect the "Edit Profile" button in Settings (currently empty action handler at line ~362) to navigate to `UserProfileView`.

### Expand UserProfileView

Add the following fields:

| Field | Type | Behavior |
|-------|------|----------|
| Display Name | Editable text field | Existing — saves to Firestore |
| Email | Change email flow | Existing — `ChangeEmailView` sheet |
| Password | Change password flow | Existing — `ChangePasswordView` navigation |
| Role | Read-only display | New — shows user's current role(s) from `TMIUser` |
| Profile Photo | Photo picker | New — upload/change avatar, stored in Firebase Storage at `users/{uid}/profile.jpg`, displayed via `SDWebImageSwiftUI` |
| School/Organization | Editable text field | New — user's school or organization name |

### Model Changes

Add missing fields to `TMIUser`/`UserProfileData` if not already present:
- `photoURL: String?` — URL to profile photo in Firebase Storage
- `organization: String?` — school or organization name

### Save Behavior

- All changes save to Firestore on the existing "Save" button tap.
- Profile photo uploads to Firebase Storage, URL saved to user document.
