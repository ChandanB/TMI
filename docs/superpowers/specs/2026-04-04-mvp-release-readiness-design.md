# TMI MVP Release Readiness — App Store + District Rollout

**Date:** 2026-04-04
**Target:** App Store public release + independent district adoption
**Timeline:** ASAP (Approach A — Teacher-Only Launch)
**Deployment Target:** iOS 18

## Context

TMI is a teacher-facing tool for trauma-informed student interventions. There are no student accounts — teachers are the only users. They manage their own notes, plans, and observations about students. This significantly reduces compliance burden (no COPPA consent flows, no minor data collection).

The app has passed TestFlight review and has an active Apple Developer Program membership. Internal testing is complete; no structured external user feedback yet.

## Assessment Summary

**Verdict: Not yet ready, but close.** The core teacher workflow is solid. The gaps are legal/metadata (privacy policy, terms, App Store listing), a handful of technical blockers, and UI polish for placeholder states.

## What's Ready

- Firebase email/password authentication with educator-focused registration
- Student management: full CRUD with Firestore real-time listeners
- TMI Plan creation: multi-step wizard with 6 intervention models
- Teacher dashboard with next-best-action prioritization
- District dashboard with KPI cards and school-level breakdowns
- MVP-narrowed navigation (Dashboard, Students, TMI Plans, District for admins)
- Centralized empty-state guidance copy
- Unified TMIComponentLibrary design system

## Blockers

### Must Fix (Blocks App Store Submission)

1. **Privacy policy** — Must be hosted at a public URL and linked in App Store Connect. Standard teacher-tool policy covering: data collected (email, educator notes), storage (Firebase), third-party services.

2. **Terms of service** — Required for App Store listing.

3. **App Store metadata** — Screenshots, description, category (Education), age rating, support URL.

4. **iOS 18 deployment target** — Project currently has iOS 26.0 (beta) targets mixed with 17.5. Must be unified to iOS 18 production target.

5. **Replace 3 `fatalError` calls** — In ScheduleMeetingCoordinator and FirestorePaths. Must be replaced with graceful error handling. Apple reviewers will flag crash paths.

6. **Complete interest edge-collection migration** — ~60% done. Some views still read from old inline arrays, causing potential data inconsistency.

### Should Fix (Blocks District Adoption)

7. **Clean up visible TODO placeholder states** — Dashboard role-specific metrics (caseload count, upcoming meetings, staff count) show unimplemented placeholders. Survey delivery stub visible in StudentListView.

8. **Commit and merge all pending work** — 35+ modified files on `codex/teacher-district-mvp-focus` branch need to be committed and merged to main.

9. **Basic onboarding / first-run experience** — Teachers need some guidance on first launch so they aren't lost without hand-holding.

### Nice to Have (Fast Follow)

10. Integration tests for critical flows (registration, plan creation, plan approval)
11. Survey delivery implementation
12. Role-specific dashboard metrics (real data instead of placeholders)

## Approach

**Teacher-Only Launch (Approach A):** Ship as a teacher productivity tool. No student PII collection from minors. Teachers manage all data. This keeps the compliance surface small and the timeline short.

## Out of Scope

- Student accounts / student-facing features
- COPPA consent flows
- Student login or student app download
- App icon redesign
- Advanced compliance (FERPA data processing agreements — deferred until student data features)
- SSO/SAML integration
- LMS/SIS integrations

## Success Criteria

- App accepted on App Store (Education category)
- A district admin and 2-3 teachers can independently: register, add students, create TMI plans, view dashboard — without support
- No crash paths reachable through normal usage
- Privacy policy and terms accessible from within the app and App Store listing
