# TMI Release 2 Discovery Classroom Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an educator securely launch Student Mode, complete one versioned interest survey, approve canonical interests, and explore explainable career matches.

**Architecture:** A trusted function issues a short-lived respondent session scoped to one student and assignment. One survey engine stores mutable drafts and immutable submissions; staff approval creates canonical student-interest relationships; a deterministic matcher ranks a curated career catalog and emits auditable explanations without AI.

**Tech Stack:** Swift 6.2, SwiftUI, Firebase Auth custom tokens, Firestore, Cloud Functions, Swift Testing, XCTest UI automation, LocalAuthentication

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Features/StudentMode/StudentModeSession.swift` | Scoped session, expiry, inactivity, lock state |
| Create | `TMI/Features/StudentMode/StudentModeRepository.swift` | Issue/refresh/end respondent sessions |
| Replace | `TMI/Views/StudentMode/StudentModeView.swift` | Student-safe shell |
| Create | `TMI/Features/Surveys/SurveyDefinition.swift` | Versioned definition and branching |
| Create | `TMI/Features/Surveys/SurveyAssignment.swift` | Student assignment and state |
| Create | `TMI/Features/Surveys/SurveyResponse.swift` | Draft and immutable submission |
| Create | `TMI/Features/Surveys/SurveyRepository.swift` | Assignment, autosave, submit, review |
| Replace | `TMI/Views/Survey/StudentSurveyFlow.swift` | One canonical survey destination |
| Replace | `TMI/Views/Survey/SurveyResultsView.swift` | Student/staff result projections |
| Create | `TMI/Features/Interests/StudentInterest.swift` | Canonical student-interest edge |
| Create | `TMI/Features/Interests/InterestAnalysis.swift` | Deterministic versioned clusters |
| Create | `TMI/Features/Careers/Career.swift` | Canonical catalog model |
| Create | `TMI/Features/Careers/CareerRelationship.swift` | Recommended/saved/dismissed/compared state |
| Create | `TMI/Features/Careers/CareerMatcher.swift` | Deterministic score and explanation |
| Replace | `TMI/Views/Career Explorer/CareerExplorerView.swift` | Search/filter/save/compare workflow |
| Replace | `TMI/Views/Career Explorer/CareerDetailView.swift` | Complete sourced career detail |
| Create | `TMITests/Features/StudentMode/StudentModeSessionTests.swift` | Scope, timeout, lock, exit |
| Create | `TMITests/Features/Surveys/SurveyEngineTests.swift` | Autosave, branch, immutable submit |
| Create | `TMITests/Features/Interests/InterestAnalysisTests.swift` | Stable cluster results |
| Create | `TMITests/Features/Careers/CareerMatcherTests.swift` | Ranking and explanations |
| Create | `firebase/test/student-mode.test.ts` | Claims/rules/function boundary |
| Create | `firebase/fixtures/release2.json` | Survey, interest, career migration |

## Task 1: Implement secure Student Mode sessions

**Status: done.** Landed across the Student Mode survey commits through `30886cc`.

**Files:**
- Create: `TMI/Features/StudentMode/StudentModeSession.swift`
- Create: `TMI/Features/StudentMode/StudentModeRepository.swift`
- Modify: `firebase/src/index.ts`
- Create: `firebase/test/student-mode.test.ts`
- Create: `TMITests/Features/StudentMode/StudentModeSessionTests.swift`

- [ ] **Step 1: Write failing session-state tests**

```swift
@Test func sessionDefaultsToThirtyMinutesAndCapsAtSixty() throws {
    let session = StudentModeSession.fixture(requestedDuration: .seconds(90 * 60))
    let issuedAt = try #require(session.issuedAt)
    let expiresAt = try #require(session.expiresAt)
    #expect(expiresAt.timeIntervalSince(issuedAt) == 60 * 60)
}

@Test func inactivityLocksAfterFiveMinutes() {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = StudentModeSession.fixture(lastActivityAt: now.addingTimeInterval(-301))
    session.evaluate(at: now)
    #expect(session.state == .locked)
}
```

Also test one-student/one-assignment scope, 30-second protected background lock, five failed exit attempts, expiry, and revoked assignment.

- [ ] **Step 2: Implement the session value and repository**

```swift
struct StudentModeScope: Codable, Sendable, Equatable {
    let districtID: String
    let studentID: String
    let assignmentIDs: Set<String>
    let allowedOperations: Set<StudentModeOperation>
}

@MainActor @Observable
final class StudentModeSession {
    enum State: Equatable { case inactive, active, locked, expired }
    private(set) var token: String?
    private(set) var scope: StudentModeScope?
    private(set) var issuedAt: Date?
    private(set) var expiresAt: Date?
    private(set) var lastActivityAt: Date?
}
```

The callable validates staff assignment/capability and returns a Firebase custom token with respondent claims, maximum 60-minute expiry, and an opaque session ID. Store staff Auth separately; exit requires device-owner authentication or staff credential reauthentication.

- [ ] **Step 3: Lock rules to student-safe projections**

Allow respondent reads only from the assigned survey/form, student-safe profile projection, approved career catalog, student-visible goals/actions, and student-visible resources. Allow writes only to drafts, submissions, interests, reflections, check-ins, career state, and help requests in scope. Deny notes, restricted records, audit, approvals, staff navigation, and other students.

- [ ] **Step 4: Run Swift/emulator tests and commit**

```bash
git add TMI/Features/StudentMode TMITests/Features/StudentMode firebase
git commit -m "feat: secure educator-launched Student Mode"
```

## Task 2: Build the single versioned survey engine

**Status: done.** `SurveyDefinition`, `SurveyResponse` and the survey engine tests.

**Files:**
- Create: `TMI/Features/Surveys/SurveyDefinition.swift`
- Create: `TMI/Features/Surveys/SurveyAssignment.swift`
- Create: `TMI/Features/Surveys/SurveyResponse.swift`
- Create: `TMI/Features/Surveys/SurveyRepository.swift`
- Create: `TMITests/Features/Surveys/SurveyEngineTests.swift`

- [ ] **Step 1: Write failing domain tests**

Test single choice, multi-select, short text, rating, image choice, versioned branching, required validation, autosave operation idempotency, resume, immutable submission, reassignment creating a new attempt, and correct-student persistence.

```swift
enum SurveyAnswer: Codable, Sendable, Equatable {
    case single(String)
    case multiple(Set<String>)
    case text(String)
    case rating(Int)
}

enum SurveyResponseState: String, Codable, Sendable {
    case draft, submitted, reviewed
}
```

- [ ] **Step 2: Implement immutable/versioned records**

Definitions are published with a version and never edited in place. Draft responses carry `recordVersion`; submission runs in a trusted transaction, validates definition version and required visible questions, changes state once, records server time, and rejects subsequent answer edits.

- [ ] **Step 3: Add offline autosave behavior**

Draft answers persist locally with stable operation IDs and visible pending-sync state. Submission is online-required because it freezes history and starts analysis. Revoked assignment rejects queued writes and explains the result.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Surveys TMITests/Features/Surveys firebase/src/index.ts
git commit -m "feat: add canonical survey engine"
```

## Task 3: Build the Student Mode survey experience

**Status: done.** `StudentSurveyFlow` and the survey step views; persistence lives in the flow, not the results screen.

**Files:**
- Replace: `TMI/Views/StudentMode/StudentModeView.swift`
- Replace: `TMI/Views/Survey/StudentSurveyFlow.swift`
- Replace: `TMI/Views/Survey/SurveyStepViews.swift`
- Replace: `TMI/Views/Survey/SurveyResultsView.swift`
- Create: `TMIUITests/StudentModeSurveyUITests.swift`

- [ ] **Step 1: Write the failing UI journey**

Automate educator entry, student-safe welcome, section progress, autosave interruption/resume, branching, review, submit, student result projection, help request, automatic lock, and authenticated exit. Assert staff notes/navigation are absent.

- [ ] **Step 2: Implement age-appropriate views**

Use supportive Student Mode language, one decision cluster per screen, visible progress, large targets, plain instructions, `Back` without data loss, `Save and finish later`, review before submit, and non-emergency `Ask for help`. Staff screens retain standard professional language.

- [ ] **Step 3: Make all entry points deep-link to one flow**

Dashboard, roster, and student detail create/select an assignment and open the same `StudentSurveyFlow`. Remove duplicate survey engines and routes after migration.

- [ ] **Step 4: Run UI/accessibility tests and commit**

```bash
git add TMI/Views/StudentMode TMI/Views/Survey TMIUITests/StudentModeSurveyUITests.swift
git commit -m "feat: deliver Student Mode interest survey"
```

## Task 4: Implement deterministic interest analysis and staff approval

**Status: done** (`ad3e7a6`). Approval derives every interest server-side from the immutable submission; direct writes to interest edges are denied. It cannot complete until the callable is deployed, which `eedbc5c` reports to the reviewer rather than failing opaquely.

**Files:**
- Create: `TMI/Features/Interests/StudentInterest.swift`
- Create: `TMI/Features/Interests/InterestAnalysis.swift`
- Modify: `TMI/Views/Survey/SurveyResultsView.swift`
- Modify: `TMI/Views/Students/Sections/StudentInterestsSection.swift`
- Create: `TMITests/Features/Interests/InterestAnalysisTests.swift`

- [ ] **Step 1: Write failing analysis tests**

Use fixed survey fixtures to assert exact cluster ranks, ties, empty optional answers, source response/version, and deterministic repeatability.

```swift
struct InterestAnalysisResult: Codable, Sendable, Equatable {
    let algorithmVersion: Int
    let responseID: String
    let clusters: [InterestClusterScore]
    let rationale: [String]
}
```

- [ ] **Step 2: Implement the versioned scorer**

Map published option IDs to weighted catalog interest IDs. Sort by score descending, then stable catalog ID. Never infer trauma, diagnosis, risk, disability, criminality, or family conditions.

- [ ] **Step 3: Implement staff review**

Staff sees the response inputs, proposed interests, cluster rationale, and student projection. Approval transaction creates/updates `districts/{districtId}/students/{studentId}/interests/{interestId}` with category, strength/rank, source, capture date, and merge history. Rejecting a proposal leaves the immutable submission unchanged.

- [ ] **Step 4: Run tests and commit**

```bash
git add TMI/Features/Interests TMI/Views/Survey/SurveyResultsView.swift TMI/Views/Students/Sections/StudentInterestsSection.swift TMITests/Features/Interests
git commit -m "feat: approve canonical student interests"
```

## Task 5: Consolidate the career catalog and deterministic matcher

**Status: mostly done.** Stable career identity (`07116fa`), the matcher and relationship state (`05a50ac`), and the canonical catalog reader (`8506bbb`).

Step 3 is now **done** (`a98cabf`). The duplicate types went once the legacy views were retired in `68be25a`. `CareerPath`, `SalaryRange` and `EducationLevel` remain as the shape of the bundled catalog data and retire with Task 7's migration.

Open decision: the bundled catalog states salary for all 537 careers with no source and no date. Canonical records carry no figure until someone sources them, so salary is absent from `CareerRecord` today.

**Files:**
- Create: `TMI/Features/Careers/Career.swift`
- Create: `TMI/Features/Careers/CareerRelationship.swift`
- Create: `TMI/Features/Careers/CareerMatcher.swift`
- Create: `TMI/Features/Careers/CareerRepository.swift`
- Create: `TMITests/Features/Careers/CareerMatcherTests.swift`

- [ ] **Step 1: Write failing catalog/matcher tests**

Test canonical ID/title deduplication, normalization, sourced salary/outlook update date, interest/cluster scoring, deterministic ties, minimum explanation inputs, saved/dismissed/compared state separation, and no match when canonical interests are absent.

```swift
struct CareerMatch: Identifiable, Sendable, Equatable {
    let id: String
    let careerID: String
    let score: Int
    let matchedInterestIDs: [String]
    let reasons: [String]
    let algorithmVersion: Int
}
```

- [ ] **Step 2: Implement the matcher**

Score only approved student-interest relationships and published survey clusters. Cap score inputs, sort deterministically, and emit plain-language reasons naming the matched interests/subjects. Recommendations are not persisted as facts; relationship documents store saved, dismissed, compared, recently viewed, and plan-linked state.

- [ ] **Step 3: Consolidate the catalog**

Map current career data files into one canonical `Career` decoder and catalog repository. Deduplicate by stable ID and normalized title. Require source/update date for salary and outlook. Remove duplicate `CareerModels` types after all callers compile.

- [ ] **Step 4: Run matcher/repository tests and commit**

```bash
git add TMI/Features/Careers TMITests/Features/Careers
git commit -m "feat: add explainable career matching"
```

## Task 6: Build career discovery, detail, and comparison

**Status: steps 1-2 done** (`2f98925`). Canonical discovery, detail and comparison are built on `CareerRecord` and reached from the student's Careers tab. Discovery, filter and comparison rules live in `CareerDiscoveryState` with tests.

Step 3 is now **done** (`68be25a`). The legacy career views were retired together with the legacy plan stack, which is what they were entangled with.

Not yet done: `TMIUITests/CareerExplorerUITests.swift`. It needs a career fixture in `UITestingLaunchConfiguration` alongside the existing student-detail fixtures.

**Files:**
- Replace: `TMI/Views/Career Explorer/CareerExplorerView.swift`
- Replace: `TMI/Views/Career Explorer/CareerDetailView.swift`
- Modify: `TMI/Views/Students/Sections/StudentCareersSection.swift`
- Create: `TMI/Features/Careers/CareerComparisonView.swift`
- Create: `TMIUITests/CareerExplorerUITests.swift`

- [ ] **Step 1: Write failing UI tests**

Automate search, each filter group, rationale disclosure, save, dismiss, recently viewed, select up to three careers, compare, share, and attach-to-plan disabled until Release 3. Verify active student is always visible.

- [ ] **Step 2: Build focused views**

Career detail includes title, cluster, description, responsibilities, environment, education/training, alternative pathways, certification/apprenticeship/military routes when relevant, formatted salary, outlook/source date, skills, school subjects, interests, entry steps, age-appropriate actions, and resources.

- [ ] **Step 3: Split legacy giant views**

Move search/filter state, result grid, match explanation, detail sections, and comparison table to focused files. Remove nested duplicate career types and legacy saved-career stores.

- [ ] **Step 4: Run UI/accessibility tests and commit**

```bash
git add 'TMI/Views/Career Explorer' TMI/Views/Students/Sections/StudentCareersSection.swift TMI/Features/Careers/CareerComparisonView.swift TMIUITests/CareerExplorerUITests.swift
git commit -m "feat: deliver career discovery workflow"
```

## Task 7: Migrate discovery data and remove duplicate engines

**Status: not started.** The 537-entry catalog is still compiled into the app and mapped by `BundledCareerCatalog`. Moving it to `catalogs/careers/items/{id}` needs a seeding script and a Firestore-backed `CareerCatalogProviding`.

Worth knowing before starting: `CareerLibraryService` used to read a root-level `careers` collection that no rule matches, so every read was refused by the deny-all fallback. It was retired in `a98cabf`. Any new reader must use the canonical `catalogs/` path.

**Files:**
- Modify: `firebase/src/migrationManifest.ts`
- Create: `firebase/fixtures/release2.json`
- Remove after migration: `TMI/Services/SurveyService.swift`
- Remove after migration: `TMI/StateModels/CareerExplorerStateModel.swift`
- Remove after migration: duplicate survey/career models and services with no callers

- [ ] **Step 1: Add migration fixtures and transforms**

Cover user-scoped survey attempts, embedded student survey results, top-level interests/careers, saved career arrays, duplicate career titles, and already-canonical edges. Preserve completed attempts immutably.

- [ ] **Step 2: Apply twice and reconcile**

Expected: second apply is zero-write; response/student/source links reconcile; duplicates map to one canonical career ID.

- [ ] **Step 3: Remove legacy writers/routes**

```bash
rg -n 'SurveyService|CareerExplorerStateModel|interestSurveys|savedCareers|careerBookmarks|careerExplorations' TMI
```

Expected after removal: matches only in migration adapters or the canonical relationship importer.

- [ ] **Step 4: Commit**

```bash
git add -A TMI firebase
git commit -m "refactor: retire duplicate discovery engines"
```

## Task 8: Release 2 acceptance

**Status: not started.** Depends on Task 7, and on the unsourced-salary decision below.

**Files:**
- Create: `docs/release-evidence/release-2.md`

- [ ] **Step 1: Run the universal gate and complete classroom journey**

With Emulator/staging data, launch Student Mode for one assigned student, interrupt/resume, submit, review, approve interests, view explainable matches, save/dismiss/compare careers, request help, lock, and exit. Attempt every forbidden cross-student/staff-note operation.

- [ ] **Step 2: Record evidence, commit, and tag**

```bash
git add docs/release-evidence/release-2.md
git commit -m "docs: record Release 2 acceptance"
git tag -a tmi-release-2-accepted -m "TMI Release 2 accepted"
```
