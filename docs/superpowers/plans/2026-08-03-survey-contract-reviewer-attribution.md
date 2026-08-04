# Survey Contract and Reviewer Attribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Swift survey-definition validation exactly match the Firebase contract and make reviewed responses use only the backend-authenticated reviewer identity.

**Architecture:** Keep the canonical definition constraints as named constants in Swift and matching constants in TypeScript, with boundary tests in both runtimes. Extend the review callable result with `reviewerUserID`; decode that exact result in Swift and pass it to the response transition instead of trusting caller-supplied staff identity.

**Tech Stack:** Swift 6, Swift Testing, Firebase callable functions, TypeScript, Vitest, Firestore emulator.

---

### Task 1: Canonical definition bounds

**Files:**
- Modify: `TMI/Features/Surveys/SurveyDefinition.swift`
- Modify: `TMITests/Features/Surveys/SurveyEngineTests.swift`
- Modify: `firebase/src/index.ts`
- Modify: `firebase/test/survey.test.ts`

- [ ] **Step 1: Write failing Swift boundary tests**

Add accepted-at-limit and rejected-over-limit cases for 100 questions, 200 rules, 100 options, 4,000-character text limits, multi-select limits, UTF-8 byte limits, trimming, control characters, and reserved identifier segments.

- [ ] **Step 2: Verify Swift RED**

Run the `SurveyDefinitionTests` suite and confirm failures identify missing Swift bounds or normalization.

- [ ] **Step 3: Write failing TypeScript boundary tests**

Exercise the same accepted/rejected limits through `saveDraft`, including exact 128-byte identifiers, 500-byte prompts/image references, and 200-byte labels.

- [ ] **Step 4: Verify TypeScript RED**

Run the Firebase test suite and confirm only the new boundary expectations fail.

- [ ] **Step 5: Implement the shared contract**

Add named Swift constants and validation helpers mirroring Firebase's explicit limits; replace TypeScript numeric literals with matching named constants without changing its accepted domain.

- [ ] **Step 6: Verify GREEN**

Run `SurveyDefinitionTests`, Firebase lint/build, and the Firebase tests.

### Task 2: Canonical reviewer attribution

**Files:**
- Modify: `firebase/src/index.ts`
- Modify: `firebase/test/survey.test.ts`
- Modify: `TMI/Features/Surveys/SurveyRepository.swift`
- Modify: `TMITests/Features/Surveys/SurveyEngineTests.swift`

- [ ] **Step 1: Write failing backend result tests**

Assert first review and exact replay return `reviewerUserID` equal to the authenticated callable user.

- [ ] **Step 2: Write failing Swift decoder tests**

Assert the review-result decoder requires the exact operation/version/replay/timestamp/reviewer schema and that a stale injected `staffIdentity.userID` cannot become `reviewedBy`.

- [ ] **Step 3: Verify RED**

Run the focused Swift and Firebase tests and confirm the missing reviewer result causes the expected failures.

- [ ] **Step 4: Implement trusted reviewer propagation**

Return the authenticated reviewer from the backend for both first execution and replay. Decode and validate it in Swift, then use it in `markReviewed` instead of caller attribution.

- [ ] **Step 5: Verify GREEN and commit**

Run the four-suite Swift gate, Firebase lint/build/full tests, `git diff --check`, then commit all scoped files with a new commit.
