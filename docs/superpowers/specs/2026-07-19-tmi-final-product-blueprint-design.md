# TMI Final Product Blueprint Design

**Date:** 2026-07-19

**Status:** Approved product and architecture contract

**Platforms:** iOS 26+, iPadOS 26+, macOS 26+

**Delivery model:** Vertical release train

## 1. Authority and Precedence

This document is the master implementation contract for TMI. It supersedes earlier MVP, phase, architecture-complete, teacher-only, warm-light, and feature-status documents wherever they conflict.

The checked-in code and executable tests determine implementation truth. Historical Markdown claims do not establish that a feature is complete.

The following decisions are fixed:

- Deliver the complete final-product blueprint, not a teacher-only endpoint.
- Target iOS 26+, iPadOS 26+, and macOS 26+ using Swift 6.
- Use a vertical release train rather than postponing security, accessibility, and reliability to late horizontal phases.
- Keep AI optional and feature-flagged. The deterministic product must remain complete without it.
- Do not expose independent student, parent, guardian, or legal-guardian accounts at GA.
- Make educator-launched Student Mode the sole student experience at GA.
- Keep all six branded intervention-model names unchanged.
- Use standard professional language in staff and administrative experiences.
- Reserve age-appropriate, supportive, trauma-informed language for Student Mode.
- Replace the former warm-cream, blue, and gold palette with the approved Aubergine + Teal system.

## 2. Product Definition

TMI—Tangible Modification Intervention—is an educator-operated intervention platform that converts a student's interests, hobbies, strengths, needs, and aspirations into an actionable educational support plan.

The canonical loop is:

```text
Create Student
  -> Discover Interests
  -> Explore Careers
  -> Create TMI Plan
  -> Assign Goals and Actions
  -> Track Progress
  -> Review and Adjust
  -> Repeat without destroying history
```

Every feature must support that loop. Forms, resources, meetings, notes, recommendations, notifications, exports, and analytics are contextual capabilities, not disconnected destinations.

### Product principles

- Student-centered and educator-operated.
- Strength-based in decisions and student-facing experiences.
- Practical during a real school day.
- Every statistic derives from canonical stored events.
- Every recommendation identifies its inputs and rationale.
- Sensitive information is accessible only by permission and legitimate operational need.
- No dead controls, fabricated data, silent failures, duplicate workflows, or production sample-data fallbacks.
- Offline behavior is explicit per operation and never implies a save that has not occurred.

## 3. GA User Model

### Supported staff roles

| Canonical role | Default operational scope |
|---|---|
| Teacher | Assigned students and plans they own or collaborate on |
| Counselor | Assigned caseload; restricted support information only with an explicit permission |
| Social worker | Assigned students; sensitive records only when specifically authorized |
| School administrator | Aggregate school data; audited student drill-down only by explicit permission |
| District administrator | Aggregate district data; audited student drill-down only by explicit permission |

Legacy `administrator`, `admin`, `superintendent`, and `districtAdmin` values migrate to the canonical school- or district-administrator roles. Migration preserves the original value in an audit record.

### Disabled account roles

Student, parent, guardian, and legal-guardian account registration and sign-in routes are hidden by production feature flags. Existing records are not destroyed. Unsupported accounts receive no route into partially implemented experiences.

### Student Mode

Student Mode is launched by authorized staff for exactly one student and one bounded purpose. It supports:

- Assigned surveys and forms.
- Interest and hobby selection.
- Approved career exploration.
- Student-facing goals and next actions.
- Reflections and progress check-ins.
- A non-emergency request-help action routed to the supervising educator.

Student Mode cannot access staff notes, restricted records, risk indicators, approval discussions, other students, staff navigation, or administrative analytics.

## 4. Platform and Swift Architecture

- SwiftUI is the UI framework on every platform.
- Swift 6 strict concurrency is enabled for app and test targets.
- Views own local state with `@State` and receive shared observable dependencies through `@Environment`.
- UI-facing observable models are `@MainActor`.
- Domain repositories are the only client data-access path.
- Mutable background services use actors or otherwise demonstrate `Sendable` safety.
- Async work uses `async`/`await` and lifecycle-aware `.task` entry points.
- Combine and UIKit/AppKit bridges require a concrete platform capability that SwiftUI cannot provide.
- New global singletons are prohibited. Existing singletons are replaced as their domains enter a release slice.
- Feature code is organized by domain workflow, not by generic Views/Models/ViewModels layers.

This is an incremental strangler migration, not a rewrite. A domain moves behind its canonical repository, its callers migrate, and the obsolete implementation is removed before that slice exits.

## 5. Delivery Architecture

Security, accessibility, offline behavior, error states, logging hygiene, and tests are acceptance criteria in every release.

### Gate 0: Canonical foundation

- Pin this contract and record baseline build/test evidence.
- Make the iOS and macOS Release builds green under Swift 6.
- Repair the test target and establish working SPM-based CI.
- Replace self-editable authorization fields with trusted membership and claims.
- Add Firebase Emulator security-rule tests.
- Finalize the canonical schema and migration tooling.
- Make account deletion reachable, accurate, and retention-safe.
- Remove production paths that fabricate or silently substitute data.

### Release 1: Secure roster alpha

- Staff authentication and onboarding.
- Institution membership and role enforcement.
- Canonical navigation shell and account menu.
- Student roster, creation, editing, archive, detail, assignment, and duplicate prevention.
- Audit foundation and canonical empty/error/offline states.

### Release 2: Discovery classroom pilot

- Controlled Student Mode.
- One versioned interest-survey engine.
- Autosave, resume, immutable submission history, and staff/student result projections.
- Canonical student-interest relationships.
- Canonical career catalog, deterministic matching, explanation, save, dismiss, and compare.

### Release 3: Core intervention MVP

- All six approved intervention models.
- Plan creation, rationale, goals, actions, resources, schedule, and review date.
- Approval, activation, progress, pause, completion, revision, and history.
- Student reflection and a basic permission-safe export.
- The complete canonical product loop verified against real Firebase Emulator data and a staging project.

### Release 4: School collaboration

- Forms, resources, meetings, notes, person-owned follow-up tasks, notifications, and global search.
- Restricted-note boundaries and staff collaboration.
- School-administrator approval queues and exports.

### Release 5: District pilot

- School and staff administration.
- Staff/student assignments.
- District templates and resources.
- Canonical aggregate metrics, filters, drill-down authorization, reports, retention controls, and audit views.
- Independent security review and production-shaped district simulation.

### Release 6: Optional AI enhancement

- Remains disabled by default and does not block GA.
- May be enabled only after deterministic workflows pass their release gates.

### GA gate

- Clean install and existing-user migration rehearsals.
- Full regression, accessibility, offline/conflict, performance, privacy, archive, TestFlight, and pilot validation.
- Zero open critical or high-severity defects.

## 6. Canonical Data Architecture

```text
users/{uid}
  private/profile
  preferences/settings

districts/{districtId}
  schools/{schoolId}
  members/{uid}
    acknowledgements/{acknowledgementId}
  students/{studentId}
    interests/{interestId}
    careers/{careerId}
    resources/{relationshipId}
    surveys/{assignmentId}
    responses/{responseId}
    notes/{noteId}
    restrictedRecords/{recordId}
    consents/{consentId}
    progress/{entryId}
  plans/{planId}
    goals/{goalId}
    actions/{actionId}
    progress/{entryId}
    approvals/{approvalId}
    resources/{relationshipId}
    forms/{assignmentId}
    revisions/{revisionId}
  meetings/{meetingId}
  tasks/{taskId}
  formTemplates/{templateId}
  formAssignments/{assignmentId}
    respondents/{respondentId}
  resources/{resourceId}
  notifications/{notificationId}
  studentModeSessions/{sessionId}
  auditEvents/{eventId}
  metricSnapshots/{snapshotId}

catalogs/{catalogName}
  items/{itemId}
```

Canonical catalog names are `careers`, `interests`, `globalResources`, `tmiModels`, and `surveyDefinitions`.

### Data rules

- One canonical model and repository per concept.
- Stable opaque IDs and server timestamps.
- Every mutable aggregate root includes `schemaVersion`, `recordVersion`, `createdAt`, `createdBy`, `updatedAt`, and `updatedBy`.
- Relationship documents link canonical records; resources, careers, and interests are not copied into every student or plan.
- Submitted surveys/forms, approvals, revisions, audit events, and completed-plan history are append-only.
- Multi-document state transitions execute in trusted server transactions.
- Creates use client-generated operation IDs or equivalent server idempotency keys.
- Queries paginate and use checked-in Firestore indexes.
- Production builds never seed sample students or return demo metrics after a data failure.

## 7. Trusted Authorization and Backend Boundary

The current pattern of trusting role and district values in an editable user document is prohibited.

### Sources of authority

- Firebase Auth establishes identity.
- Server-managed custom claims identify the active tenant and coarse access class.
- `districts/{districtId}/members/{uid}` stores canonical role, school assignments, explicit permissions, activation state, and version.
- Clients may update only a whitelisted set of personal-profile and preference fields.
- Role, district, school, assignment, approval, retention, and audit mutations run through trusted server functions.

### Enforcement layers

1. SwiftUI hides or disables unauthorized controls.
2. Repositories require typed capabilities before issuing an operation.
3. Firestore and Storage rules reject unauthorized reads and writes.
4. Trusted functions revalidate membership and business prerequisites.

The same permission fixtures drive Swift authorization tests, rule tests, and server-function tests to detect policy drift.

### Administrative access

School and district administrators receive aggregate data by default. Student-level drill-down requires a named permission, a reason code, and an audit event. District administrators do not receive automatic cross-district access.

### Default permission matrix

| Capability | Teacher | Counselor | Social worker | School administrator | District administrator |
|---|---|---|---|---|---|
| Read assigned student detail | Yes | Yes | Yes | Explicit `student.read.detail` | Explicit `student.read.detail` |
| Create/edit student profile | Assigned scope | Assigned scope | No profile edit; assigned notes/interventions only | Explicit `student.write.detail` | Explicit `student.write.detail` |
| Assign/review surveys | Assigned scope | Assigned scope | No default | Explicit student-detail permission | Explicit student-detail permission |
| Create/edit/submit plans | Owned or collaborative | Owned or collaborative | Collaborative | Explicit plan assignment | Explicit plan assignment |
| Approve plans | No default | Explicit `plan.approve` | No default | Yes within school | Explicit `plan.approve` |
| Read restricted records | No default | Explicit `student.restricted.read` | Explicit `student.restricted.read` | No default | No default |
| Write restricted records | No default | Explicit `student.restricted.write` | Explicit `student.restricted.write` | No default | No default |
| Manage staff and assignments | No | No | No | Within school | Within district |
| View aggregate analytics | Assigned classroom | Assigned caseload | Assigned caseload | School | District |
| Export reports | Assigned scope | Assigned scope | Assigned scope | School | District |
| Read audit events | Own actions | Own actions | Own actions | School privileged events | District privileged events |

Every explicit permission is server-granted, tenant-bounded, versioned, and revocable. Assignment scope never implies access to restricted records.

### Audit integrity

Clients cannot create authoritative audit events directly. Trusted functions record privileged actions, sensitive-record reads, exports, role changes, approvals, deletions, and AI content incorporated into official records.

## 8. Student Mode Security

- Staff create a short-lived server-issued session for one student and an explicit assignment scope.
- Student Mode uses a separate Firebase authentication context with student-scoped claims; the staff session is retained separately.
- The session defaults to 30 minutes, cannot exceed 60 minutes, and locks after five minutes of inactivity.
- Returning from the background locks the session when its protected content was obscured for more than 30 seconds.
- Exiting Student Mode requires educator authentication with device owner authentication or the staff credential flow.
- Session reads use a student-safe projection. Writes are limited to assigned responses, interests, reflections, progress check-ins, career preference state, and help requests.
- Session creation, entry, lock, resume, submission, help request, and exit are audited.

Guardian-targeted forms use the same short-lived respondent-session infrastructure with a guardian-specific scope and no persistent guardian account.

## 9. Navigation and Context

### Staff navigation

- Dashboard.
- Students.
- TMI Plans.
- District for authorized administrators.
- Profile and Settings from the account menu.

Forms, interests, careers, resources, meetings, goals, notes, and recommendations are embedded in student or plan workflows.

A single typed router owns tab selection, navigation paths, deep links, state restoration, and active-student context. Every mutation screen displays the active student's name. Deep links validate authorization and context before navigation.

- iPhone uses native tabs and stacked navigation.
- iPad uses sidebar-adaptable navigation and list/detail layouts.
- macOS uses sidebar, toolbar, commands, keyboard navigation, resizable windows, and sensible minimum sizes.

## 10. Authentication and Onboarding

GA authentication includes:

- Email/password registration and sign-in.
- Password reset.
- Email verification before access to student records.
- Session restoration and token refresh.
- Recent reauthentication for destructive or sensitive actions.
- In-app account deletion.
- TOTP-based MFA for school and district administrators before privileged access.
- A disabled institutional-SSO adapter seam with no visible unfinished SSO control.

Staff onboarding is:

1. Create and verify the account.
2. Select the requested professional role.
3. Enter an institution or district invitation code.
4. Obtain server-side membership verification.
5. Review privacy and acceptable-use terms.
6. Set display name, school, and preferences.
7. Review the canonical TMI workflow.
8. Land on a purposeful dashboard whose empty state leads to adding the first student.

Registration rolls back the Firebase Auth account if profile or membership provisioning fails irrecoverably.

## 11. Dashboard and Canonical Metrics

The dashboard answers:

1. What requires attention?
2. What is the next concrete action?
3. Is intervention work improving?

The header provides a time-aware greeting, member name and role, school/district context, profile, notifications, sign-out, and visible sync/offline state.

Teacher, counselor, and social-worker dashboards show assigned students, students without interests or active plans, active plans, stale progress, pending forms/surveys, upcoming meetings, attention reasons, recent activity, engagement and completion trends, and contextual quick actions.

Administrative dashboards show students served, staff adoption, survey completion, plan lifecycle counts, approval queue, missing follow-up, model distribution, and school/grade/date filters without exposing unnecessary student detail.

Next Best Action uses deterministic ordered rules and opens the exact destination. Default priority is:

1. Unresolved help request.
2. Requested plan changes.
3. Plan awaiting the current user's approval.
4. Overdue meeting notes.
5. Overdue progress or plan review.
6. Completed survey awaiting review.
7. Student with interests but no active plan.
8. Student without captured interests.
9. Add the first student.

A versioned metric dictionary defines every formula, time window, exclusion, timezone, and minimum sample size. Dashboard and export code consume the same server-side calculation library.

Default formulas include:

- Assigned students: active, non-archived students linked to the current member.
- Staff adoption: active members with at least one meaningful workflow event in the trailing 30 days divided by active members.
- Survey completion: completed assignments divided by non-cancelled assignments due in the selected window.
- Active plans: plans whose canonical status is `active` at the query timestamp.
- Follow-up timeliness: due reviews or progress updates completed on or before their due timestamp divided by all due items.
- Student action completion: completed student-visible actions divided by actions due in the selected window.
- Engagement trend: current 28-day student-action completion minus the previous 28-day completion, shown only when both windows contain at least four due actions.

Needs-attention reasons are displayed as labels, not collapsed into a hidden score. Default reasons are an open help request, a review more than seven days overdue, a progress update overdue beyond the plan cadence plus seven days, or a completion decline of at least 20 percentage points across eligible comparison windows.

## 12. Student Management

### Roster

- Search by name or institutional student identifier.
- Filter by school, grade, assigned staff, plan status, survey status, and attention reason.
- Sort alphabetically, recently updated, engagement trend, or next action.
- Use list/grid adaptation by available width.
- Support authorized bulk assignment.
- Paginate in pages of 50.

### Create and edit

- Required: display name, school, grade, and student identifier when district policy requires it.
- Optional: photo, date of birth when required, pronouns, assigned staff, guardian references, cohort tags, and permission-appropriate support notes.
- Normalize values before validation.
- Detect likely duplicates by district, school, normalized name, grade, and institutional identifier.
- Disable repeated submission and use an idempotency key.
- Preserve form state after recoverable errors.
- Confirm success only after the canonical record exists.

### Student detail

Student detail is the operational hub. It includes overview, interests, surveys/forms, careers, resources, plans, meetings/notes, and progress. Contextual menu actions must be permission-backed and functional. Private staff notes and student-visible reflections are separate record types and separate queries.

- The header shows photo/initials, name, grade, school, assigned team, engagement reason/status, active-plan status, last interaction, Student Mode entry, edit, and authorized archive/delete actions.
- Interests record category, strength/rank, source, capture date, and merge history and support add, remove, merge, and reorder operations.
- Surveys show assigned, in-progress, submitted, reviewed, and overdue attempts without overwriting history.
- Careers show recommended, saved, dismissed, compared, and plan-linked state.
- Resources show recommendation source, assignment, completion, and reflection.
- Plans show current and historical cycles with owner, status, dates, progress, and next review.
- The timeline combines meetings, notes, progress, surveys, and plan revisions while respecting visibility boundaries.
- Progress identifies the source of every measure and never presents an opaque AI score as fact.

## 13. Canonical Interest Survey

There is one versioned survey engine and one destination. Dashboard, roster, and student-detail entry points deep-link into that destination.

The flow is:

1. Staff select a student and assignment.
2. A scoped Student Mode session opens.
3. The student completes short age-appropriate sections.
4. Answers autosave as a draft.
5. The student reviews and submits.
6. Submission becomes immutable.
7. Deterministic analysis creates interest-cluster results.
8. Staff review before canonical interest relationships change.
9. Approved interests persist to the correct student.
10. Career matches and separate student/staff result projections are generated.

Supported fields include single choice, multi-select, short text, rating, image choice, and versioned branching logic. Reassignment creates a new attempt and never overwrites a completed response.

## 14. Career Explorer

- Maintain one canonical `Career` model and one curated catalog.
- Deduplicate stable careers by canonical ID and normalized title.
- Search title, keyword, field, and related interest.
- Filter cluster, education, salary, environment, growth, and alignment.
- Preserve recently viewed, saved, dismissed, and comparison state per student relationship.
- Generate deterministic matches from approved interest relationships and survey clusters.
- Display the matching inputs and explanation.
- Separate catalog content from student career-selection state.
- Label externally sourced salary/outlook data with source and update date.
- Allow save, dismiss, compare, share, and attach-to-plan actions where permitted.

Career detail includes title, cluster, plain-language description, responsibilities, work environment, education/training, alternative pathways, certifications/apprenticeships/military routes where relevant, consistently formatted salary, outlook, skills, school subjects, related interests, entry steps, age-appropriate actions, and related resources.

## 15. TMI Plans

The six brand-fixed names are:

1. Chase Your Space.
2. Acknowledge Your Interests and Hobbies.
3. Align Your Mind.
4. Direct & Correct Negative Behavior.
5. From Bully to Boss.
6. From Meek to Promising Protector.

The TMI product owner approves each model's purpose, use cases, boundaries, activities, measures, meeting cadence, student explanation, and staff guidance before GA. The application does not invent clinical claims.

### Creation

1. Select student.
2. Review student signals and data sources.
3. Select a deterministic recommendation or choose manually.
4. Define the need in professional language.
5. Select relevant interests and careers.
6. Add one immediate next action.
7. Add goals, baselines, targets, and measurement methods.
8. Assign responsible staff.
9. Attach resources, activities, forms, and surveys.
10. Set start, review, and end dates plus meeting cadence.
11. Add student voice and authorized family collaboration.
12. Review, save draft, or submit for approval.

### Lifecycle

```text
Draft -> Pending approval -> Changes requested -> Draft
                          -> Approved -> Active <-> Paused
                                                -> Completed -> Archived
```

- Creators edit drafts and submit.
- A member with `plan.approve` approves or requests changes.
- Approval freezes that revision.
- The responsible owner activates an approved plan immediately or at its validated start date.
- Active and paused plans accept append-only progress entries.
- Completion records outcome evidence and freezes the completed revision.
- Archived is terminal.
- A completed plan may be duplicated into a new cycle with a new ID.
- Every transition is transactional, version-checked, timestamped, attributed, and audited.

### Exports

Support a professional plan PDF, MTSS/intervention summary, progress report, meeting summary, and district-safe aggregate report. Export fields are selected by authorization policy, not merely hidden in the view. Sensitive exports require online permission revalidation and create an audit event.

## 16. Forms, Resources, Meetings, Notes, and Tasks

### Forms

- Versioned draft/published/archived templates.
- Short text, long text, single choice, multiple choice, rating, yes/no, date, numeric, acknowledgment, conditional questions, and sections.
- Assign to one or many students, a plan, a due date, and a respondent type.
- Track not started, in progress, submitted, reviewed, and overdue.
- Autosave drafts and keep submitted responses immutable.
- Score only from an explicit versioned scoring definition.
- Support staff review comments and permission-safe response export.

### Resources

- Global curated, district/school, and personal scopes.
- Search by type, interest, career, grade, model, subject, accessibility, language, cost, and delivery mode.
- Store student/plan assignment and progress as relationship documents.
- Track completion, reflection, moderation, and broken-link reports.
- Never hardcode fake assigned resources into a production view.

### Meetings and notes

- Student, team, plan-review, family, and progress meetings.
- Participants, schedule, location/link, agenda, linked records, notes, decisions, follow-ups, and next meeting.
- A calendar adapter isolates EventKit integration; calendar writes require explicit user permission and never place sensitive student information in shared event text.
- Notes include author, timestamps, category, visibility, revision history, and linked records.
- Restricted records are physically separate and permission-gated.

### Goals and tasks

- Goals live within plans and include baseline, target, measurement method, due date, status, progress history, responsible staff, and student-facing wording.
- Follow-up tasks belong to people and link back to their source record.

## 17. Notifications and Search

- In-app notifications are the GA default.
- Notification types include survey completion, overdue form, upcoming meeting, missing notes, approval, requested changes, stale progress, explainable engagement decline, completed resource, and security events.
- Deep links resolve the exact authorized item.
- Duplicate notifications group by event key.
- Users control category preferences.
- Lock-screen text contains no sensitive student information.
- Push and email remain disabled until configured, consented, and privacy-reviewed.
- Global search covers authorized students, plans, careers, and resources.
- Search and navigation keep the active student visibly identified and prevent mutations against stale context.

## 18. District Administration

- Manage schools, invitations, staff activation, roles, permissions, and assignments through trusted functions.
- Manage district templates and approved resources.
- Configure retention and reporting policies.
- Review audit events.
- View schools, active staff, students served, survey completion, documented interests, plan status, model distribution, follow-up timeliness, approval time, and engagement/completion trends.
- Filter by school, grade band, and date.
- Export redacted district evidence reports.
- Default to aggregate metrics; student drill-down requires explicit permission and audit.

## 19. Aubergine + Teal Visual System

The previous warm-cream, blue, and gold direction is retired.

| Token | Value | Use |
|---|---:|---|
| Background | `#F7F6FA` | Page and window background |
| Surface | `#FFFFFF` | Cards, sheets, editors |
| Primary text | `#1F1A24` | Essential text |
| Secondary text | `#514A57` | Supporting text |
| Border | `#C7C0CF` | Visible structural separation |
| Aubergine | `#5B2A5B` | Brand, sidebar, selected navigation |
| Aubergine foreground | `#FFFFFF` | Content on aubergine |
| Teal | `#0F766E` | Primary actions, links, focus, progress |
| Teal foreground | `#FFFFFF` | Content on teal |
| Aubergine soft | `#EDE1ED` | Selected and contextual surfaces |
| Success surface/text | `#DFF3E7` / `#14532D` | Positive status with text/icon |
| Warning surface/text | `#F4E8C8` / `#6B4306` | Warning status with text/icon |
| Error surface/text | `#FCE8E6` / `#8F2118` | Destructive/error status |
| Information surface/text | `#DFF1EF` / `#0D5B55` | Informational status |

Verified contrast ratios include 15.85:1 for primary text on the background, 8.51:1 for secondary text on white, 10.90:1 for white on aubergine, and 5.47:1 for white on teal.

### Appearance rules

- Light-only at GA; remove the contradictory dark-mode preference.
- Solid surfaces and visible borders.
- No glass morphism, neon glow, particle effects, decorative blobs, or unnecessary gradients.
- No arbitrary colors outside the token system.
- Color is never the only carrier of meaning.
- Montserrat may be used where bundled and reliable; the system font is the fallback.
- Sentence-case headings and Dynamic Type throughout.

### Canonical components

Maintain one implementation each for background, card, button, field, search, picker, badge, avatar, progress, empty/loading/error/offline states, section header, accordion, dialog, sheet, banner, student row, plan row, stat card, and timeline item. Competing legacy components are migrated and removed.

## 20. Accessibility and Platform Adaptation

- Minimum 44-point touch targets.
- VoiceOver labels, hints, values, and logical focus order.
- Dynamic Type without truncating essential content.
- Reduce Motion support and no looping decorative animation.
- Accessible charts with a text summary and non-color encoding.
- Keyboard navigation and shortcuts on iPad and macOS.
- Hover never replaces focus.
- Resizable macOS windows with readable minimum sizes.
- Major visual slices receive a dedicated design review on iPhone, iPad, and macOS.

## 21. Privacy, Security, and Compliance

- Minimize student data and collect dates of birth, guardian references, and sensitive support information only when institutional policy requires them.
- Document FERPA-oriented operational controls and COPPA considerations for supervised Student Mode without claiming legal compliance from data models alone.
- Store ordinary student records, restricted records, telemetry, and protected audit events in distinct authorization domains.
- Require Firebase App Check where supported and maintain checked-in Firestore and Storage rules plus Emulator tests.
- Record consent and policy acknowledgments with document version and timestamp when required.
- Let districts configure retention within product-supported minimum and maximum bounds; server jobs enforce the active policy.
- Provide an authenticated personal-data export and the retention-safe in-app account-deletion flow.
- Provide authorized student archive/deletion workflows that preserve immutable institutional history according to district policy.
- Ship an accurate `PrivacyInfo.xcprivacy` manifest and App Store privacy disclosures.
- Verify publicly hosted Privacy Policy and Terms URLs plus a monitored support contact before archive submission; bundled local HTML alone does not satisfy the release gate.
- Complete an independent security review before any district production deployment.

## 22. AI Feature Flag and Governance

AI is disabled by default. Deterministic survey analysis, career matching, plan templates, metrics, and Next Best Action remain complete without it.

When enabled for an approved pilot, AI may summarize survey results, explain matches, suggest a model, draft goals, recommend resources, summarize progress, identify missing follow-up, or draft meeting/report text.

AI cannot diagnose, infer trauma/disability/criminality/family circumstances, invent facts, alter official records without confirmation, expose restricted data, create unexplained risk scores, or replace professional judgment.

Every AI result displays:

- The canonical records used.
- Why the suggestion was generated.
- A visible suggestion label.
- Edit, reject, and regenerate controls.
- The unchanged original during regeneration.
- An audit event when accepted into an official record.

On-device Foundation Models are preferred. Any network provider requires a separate privacy, retention, consent, evaluation, and data-processing approval before its flag can be enabled.

## 23. Offline and Conflict Policy

### Offline-capable

- Cached reads.
- Draft survey/form answers.
- Draft plan text that does not transition status.
- New notes, reflections, and independent progress entries.
- Personal view preferences.

Offline writes use stable operation IDs and show pending-sync state.

### Online-required

- Role, permission, membership, and assignment changes.
- Plan approval and audited lifecycle transitions.
- Student Mode session creation.
- Account deletion.
- Sensitive export generation.
- Destructive archive/delete operations affecting multiple records.

### Conflict handling

- Append-only events merge by stable ID.
- Mutable aggregate roots use record-version preconditions.
- Conflicts preserve both drafts and present an explicit resolution screen.
- Permission revocation prevents queued writes from syncing and explains the rejected operation.
- Reconnection shows pending, syncing, succeeded, and failed counts.

## 24. Reliability, Logging, and Performance

Every data-driven view supports initial loading, refreshing, empty, populated, recoverable error, permission denied, offline, successful save, disabled submission, and retry states.

- No `fatalError` in production paths.
- No remote-data force unwraps.
- No silent catch for consequential operations.
- No success UI before persistence confirmation.
- No duplicate writes or orphaned documents.
- No student PII in telemetry or console output.
- Use privacy-redacted structured logging and distinguish operational telemetry from protected audit records.

Default performance budgets on the current base-model iPhone and an Apple-silicon Mac are:

- Cached authenticated shell interactive within 2.0 seconds at p95.
- Cached student or plan detail visible within 1.0 second at p95.
- Loading feedback visible within 250 milliseconds of a network action.
- First online page complete within 3.0 seconds at p95 under the staging network profile.
- Roster/list queries fetch at most 50 primary records per page.
- District dashboards read precomputed metric snapshots rather than scanning student records on-device.
- Offline writes converge within 60 seconds at p95 after stable connectivity returns.

Performance failures are observable and block the applicable release gate.

Production recovery requirements are:

- Automated encrypted backups for canonical Firestore and Storage data, with access separated from routine application administration.
- A recovery-point objective of no more than 24 hours and a recovery-time objective of no more than eight hours for a district deployment.
- A documented restore runbook and a successful staging restore rehearsal before GA and at least annually thereafter.
- Restore verification covering record counts, referential integrity, restricted-record isolation, Storage links, and representative decoded records.
- Incident procedures that preserve audit evidence, notify affected institutions through the approved channel, and never expose student PII in operational tooling.

## 25. Migration and Deletion

### Schema migration

1. Inventory legacy paths, owners, IDs, counts, and references.
2. Map every legacy record to a district and school or quarantine it for manual ownership resolution.
3. Backfill canonical records with stable IDs and migration metadata.
4. Verify counts, required fields, referential integrity, and sampled decoded equality.
5. Enable canonical-first reads through a temporary migration adapter.
6. Freeze legacy writers and switch the domain writer once verification passes.
7. Observe error and reconciliation metrics.
8. Archive legacy paths according to retention policy after the rollback window.

The app may roll back UI/features without sending new writes to legacy storage. After canonical writes begin, rollback preserves the canonical writer and repairs forward.

### Account deletion

The in-app flow requires recent reauthentication and clearly distinguishes personal deletion from institutional retention.

Delete:

- Firebase Auth account.
- Personal profile and preferences.
- Personal notifications, recommendations, browsing/saved activity, and personal-only resources.
- Profile images and private local caches.

Preserve:

- Institution-owned student, plan, form, meeting, consent, audit, and compliance records.
- Required attribution as an opaque former-user identifier without a resolvable profile.

Cleanup is idempotent. Trusted cleanup completes before Firebase Auth deletion, which runs last.

## 26. Testing and CI

### Unit tests

- Validation, permissions, state transitions, metric formulas, interest analysis, career matching, recommendations, goals, scoring, formatting, and migrations.

### Repository and service tests

- Student CRUD and duplicate prevention.
- Survey assignment, autosave, immutable submission, and correct-student persistence.
- Interest/career/resource relationships.
- Plan creation, approval, activation, progress, completion, and history.
- Forms, meetings, tasks, notifications, exports, deletion, retries, and offline queues.

### Security tests

- Cross-user, cross-school, and cross-district denial.
- Self-promotion and protected-field denial.
- Student/guardian respondent-session restrictions.
- Restricted-note and administrative drill-down boundaries.
- Storage path and export redaction.

### UI automation

Automate registration/sign-in, student creation, Student Mode survey, interest persistence, career save/compare, plan creation, goal/action creation, approval, activation, progress, meeting completion, export, and account deletion.

### Visual and accessibility validation

- iPhone portrait and supported landscape.
- iPad compact/regular and split views.
- macOS minimum/default/expanded windows.
- Dynamic Type, VoiceOver, keyboard navigation, focus order, Reduce Motion, and all data states.

### CI

- Use the checked-in Xcode project and Swift Package Manager.
- Build iOS and macOS Release configurations.
- Run unit/integration tests on supported iPhone and iPad simulators plus macOS.
- Run Firebase Emulator rules and function tests.
- Archive test results and code coverage.
- Reject compile warnings that are Swift 6 errors.
- Do not reference nonexistent workspaces, test plans, or targets.

## 27. Repository Cleanup Contract

Completion requires removal or migration of:

- Duplicate authentication services and unsafe account-management paths.
- Duplicate career, survey, interest, resource, and plan representations.
- Fragmented form components and obsolete inherited component families.
- Legacy warm-cream, blue/gold, dark, glass, neon, and arbitrary-color styling.
- Unused navigation coordinators, orphaned screens, and disabled top-level feature tabs.
- Mixed user-scoped, top-level, and district-scoped Firebase paths after migration.
- Naming differences such as ViewModel versus StateModel when they do not communicate a real responsibility difference.
- Giant views when their release slice touches them; extracted units must have one clear purpose and interface.
- Multiple survey engines or duplicate student-creation routes.
- Hardcoded resources, fake metrics, sample-data production fallbacks, broken menu actions, missing assets, and deprecated Firebase paths.
- Internal planning Markdown and development artifacts copied into the application bundle.

Superseded planning documents remain historical records but must carry a clear superseded marker or move to a documentation archive so they cannot be mistaken for current implementation status.

## 28. Final Definition of Done

TMI is complete only when:

- A new educator understands the workflow without external instruction.
- A student moves from no profile to an active intervention plan through one connected experience.
- Survey selections reliably persist to the correct student.
- Career recommendations use canonical student data and show their rationale.
- Every saved career, resource, form, note, meeting, task, and goal appears in its expected context.
- Plans can be created, approved, activated, measured, paused, completed, archived, revised as a new cycle, and permission-safely exported.
- District users see reconciled aggregate evidence and no unauthorized detail.
- Every role and respondent session sees only authorized records.
- Offline-capable changes synchronize without duplication or loss.
- Online-required actions clearly block while offline.
- Every visible control works.
- Every metric is defined, truthful, and shared with reporting.
- Every screen uses the Aubergine + Teal system and passes the accessibility matrix.
- No production mock data, placeholder flow, dead route, contradictory implementation, or deprecated Firebase path remains.
- Critical workflows have unit, integration, security, and UI coverage.
- iOS 26+, iPadOS 26+, and macOS 26+ Release builds are clean under Swift 6.
- Clean install, migration rehearsal, App Store archive, TestFlight smoke test, security review, and district-pilot simulation pass.
- No critical or high-severity defects remain open.

## 29. Verified Starting Baseline

The implementation begins from these verified facts on `main` at `0a73da7`:

- The iOS 26.5 Simulator Release build succeeds.
- The test target does not compile because `AccessibilityManagerTests` has an ambiguous `ContentSizeCategory` initializer; zero tests execute.
- The project declares Swift 5 rather than Swift 6.
- Firestore rules trust authorization fields that users can edit and permit unsafe audit/shared-data writes.
- Client paths mix user-scoped, top-level, and district-scoped storage.
- Account deletion is unreachable from shipped Profile navigation and currently deletes institution-owned students and plans.
- CI targets an obsolete Xcode/iOS matrix, creates a nonexistent CocoaPods workspace, and references absent test infrastructure.
- Production code contains sample-data fallbacks, incomplete workflows, and extensive unredacted debug logging.

These are Gate 0 defects, not accepted product behavior.
