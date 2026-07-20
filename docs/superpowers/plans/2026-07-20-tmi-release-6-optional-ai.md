# TMI Release 6 Optional AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional, disabled-by-default AI drafting and summarization with provenance, policy enforcement, evaluation, and explicit human confirmation while preserving the complete deterministic product.

**Architecture:** Domain features request narrow suggestion DTOs through an `AISuggestionProvider`; a policy layer selects only authorized canonical inputs, prefers on-device Foundation Models, validates output, and never writes official records. Acceptance creates a separate audited mutation using the edited human-confirmed content.

**Tech Stack:** Swift 6.2, Foundation Models where available, Swift Testing, Firebase Remote Config/feature flags, protected audit functions

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `TMI/Features/AI/AIFeature.swift` | Approved use-case IDs |
| Create | `TMI/Features/AI/AISuggestion.swift` | Provenance and output DTO |
| Create | `TMI/Features/AI/AIPolicy.swift` | Allowed inputs/outputs/prohibited content |
| Create | `TMI/Features/AI/AISuggestionProvider.swift` | Provider interface |
| Create | `TMI/Features/AI/FoundationModelsProvider.swift` | On-device adapter |
| Create | `TMI/Features/AI/AIAvailability.swift` | Device/model/flag eligibility |
| Create | `TMI/Features/AI/AIPilotConfigurationRepository.swift` | Server-authorized district pilot eligibility |
| Create | `TMI/Features/AI/AISuggestionView.swift` | Label, sources, edit/reject/regenerate |
| Create | `TMI/Features/AI/AIEvaluationCase.swift` | Versioned evaluation fixtures |
| Create | `TMITests/Features/AI/AIPolicyTests.swift` | Privacy and prohibited inference |
| Create | `TMITests/Features/AI/AIAvailabilityTests.swift` | Disabled/fallback behavior |
| Create | `TMITests/Features/AI/AIEvaluationTests.swift` | Grounding, safety, determinism boundaries |
| Modify | `firebase/src/index.ts` | Audited incorporation event only |

## Task 1: Define approved AI use cases and hard prohibitions

**Files:**
- Create: `TMI/Features/AI/AIFeature.swift`
- Create: `TMI/Features/AI/AIPolicy.swift`
- Create: `TMITests/Features/AI/AIPolicyTests.swift`

- [ ] **Step 1: Write failing policy tests**

Test survey summary, match explanation, model suggestion, goal draft, resource suggestion, progress summary, missing follow-up, and meeting/report draft as allowed. Test diagnosis, trauma/disability/criminality/family inference, official-record mutation, restricted-record access, unexplained risk scoring, and unsupported factual claims as denied.

```swift
enum AIFeature: String, Codable, Sendable, CaseIterable {
    case surveySummary, careerMatchExplanation, planModelSuggestion, goalDraft
    case resourceSuggestion, progressSummary, missingFollowUp, meetingDraft, reportDraft
}

enum AIInputKind: String, Codable, Sendable {
    case approvedSurveyResult, approvedInterest, savedCareer, planRevision
    case progressEntry, assignedResource, meetingDecision
}
```

- [ ] **Step 2: Implement an explicit allowlist policy**

`AIPolicy.authorizedInputs(for:member:studentID:)` accepts only listed input kinds already authorized to the member and returns opaque IDs plus minimal text fields. It always excludes restricted records, private notes, raw audit metadata, guardian data, and unrelated student records.

- [ ] **Step 3: Run policy tests and commit**

```bash
git add TMI/Features/AI/AIFeature.swift TMI/Features/AI/AIPolicy.swift TMITests/Features/AI/AIPolicyTests.swift
git commit -m "feat: define governed AI use cases"
```

## Task 2: Implement disabled-by-default availability and provider seam

**Files:**
- Create: `TMI/Features/AI/AISuggestionProvider.swift`
- Create: `TMI/Features/AI/AIAvailability.swift`
- Create: `TMI/Features/AI/AIPilotConfigurationRepository.swift`
- Create: `TMI/Features/AI/FoundationModelsProvider.swift`
- Create: `TMITests/Features/AI/AIAvailabilityTests.swift`
- Modify: `TMI/Core/Dependencies/AppDependencies.swift`

- [ ] **Step 1: Write failing availability tests**

Test production default false, district pilot opt-in false, expired pilot, wrong district, unsupported device, model unavailable, user permission missing, feature not approved, and all-conditions-true. Assert deterministic UI remains present in every false case.

- [ ] **Step 2: Define the provider contract**

```swift
protocol AISuggestionProvider: Sendable {
    func suggestion(for request: AISuggestionRequest) async throws -> AISuggestion
}

struct AISuggestion: Identifiable, Sendable, Equatable {
    let id: UUID
    let feature: AIFeature
    let sourceRecordIDs: [String]
    let rationale: [String]
    let originalText: String
    let provider: String
    let modelVersion: String
}
```

- [ ] **Step 3: Implement on-device provider only**

Use Foundation Models when the OS/device reports availability. Generate structured output constrained to the requested DTO, source snippets, and product-owner-approved language. Reject output that cites a nonexistent source ID, contains prohibited inference patterns, exceeds field limits, or fails schema validation.

- [ ] **Step 4: Require server-authorized pilot configuration**

`AIPilotConfigurationRepository` reads a trusted district configuration containing enabled feature IDs, start/end times, policy version, approving actor, and audit ID. It cannot enable unsupported account roles or a network provider. Local defaults remain fully disabled when the configuration is absent, invalid, expired, or belongs to another district.

- [ ] **Step 5: Do not add a network provider**

No network adapter ships in this release. A future adapter requires separate privacy, retention, consent, evaluation, and data-processing approval and therefore is outside this approved implementation.

- [ ] **Step 6: Run tests and commit**

```bash
git add TMI/Features/AI/AISuggestionProvider.swift TMI/Features/AI/AIAvailability.swift TMI/Features/AI/AIPilotConfigurationRepository.swift TMI/Features/AI/FoundationModelsProvider.swift TMI/Core/Dependencies/AppDependencies.swift TMITests/Features/AI/AIAvailabilityTests.swift
git commit -m "feat: add on-device AI provider seam"
```

## Task 3: Build the human-confirmation suggestion component

**Files:**
- Create: `TMI/Features/AI/AISuggestionView.swift`
- Create: `TMI/Features/AI/AISuggestionState.swift`
- Create: `TMITests/Features/AI/AISuggestionStateTests.swift`
- Create: `TMIUITests/AISuggestionUITests.swift`

- [ ] **Step 1: Write failing state tests**

Test visible `AI suggestion` label, source list, rationale, original preservation during regenerate, editable copy, reject, unavailable fallback, generation failure, confirmation requirement, and audited incorporation request using edited content.

- [ ] **Step 2: Implement state without automatic persistence**

```swift
@MainActor @Observable
final class AISuggestionState {
    private(set) var suggestion: AISuggestion?
    private(set) var original: AISuggestion?
    var editedText = ""
    var isGenerating = false
    var errorMessage: String?
}
```

Regenerate keeps the original visible until replacement succeeds. Accepting returns edited text to the host workflow; it cannot call an official-record repository itself.

- [ ] **Step 3: Build accessible reusable UI**

Show label, input sources, why generated, provider/model, editable draft, Reject, Regenerate, and Use Edited Draft. Avoid anthropomorphic certainty and never display AI output as a fact.

- [ ] **Step 4: Run state/UI tests and commit**

```bash
git add TMI/Features/AI/AISuggestionView.swift TMI/Features/AI/AISuggestionState.swift TMITests/Features/AI/AISuggestionStateTests.swift TMIUITests/AISuggestionUITests.swift
git commit -m "feat: add human-confirmed AI suggestions"
```

## Task 4: Integrate approved suggestion points behind the flag

**Files:**
- Modify: survey results, career explanation, plan editor, resource search, progress summary, meeting editor, and report draft feature files
- Create: `TMITests/Features/AI/AIIntegrationTests.swift`
- Modify: `firebase/src/index.ts`

- [ ] **Step 1: Write failing integration tests**

For each approved feature, assert flag-off produces identical deterministic behavior; flag-on adds a suggestion control; inputs are canonical and authorized; rejection changes nothing; acceptance sends edited text plus suggestion/source IDs to the normal repository; official mutation and audit occur together.

- [ ] **Step 2: Add narrow host integrations**

Each host builds `AISuggestionRequest` from its existing authorized projection. It never sends an entire student record when only interests or progress entries are needed. Accepted content remains editable before the existing save/submit action.

- [ ] **Step 3: Audit incorporation, not raw generation text**

Trusted mutations record feature ID, provider/model version, source opaque IDs, suggestion ID, accepting actor, and whether content was edited. Do not duplicate sensitive generated text into the audit event.

- [ ] **Step 4: Run deterministic parity/integration tests and commit**

```bash
git add TMI TMITests/Features/AI/AIIntegrationTests.swift firebase/src/index.ts
git commit -m "feat: integrate optional AI drafting"
```

## Task 5: Build and run the evaluation suite

**Files:**
- Create: `TMI/Features/AI/AIEvaluationCase.swift`
- Create: `TMI/Resources/AIEvaluationCases.json`
- Create: `TMITests/Features/AI/AIEvaluationTests.swift`
- Create: `docs/release-evidence/release-6-ai-evaluation.md`

- [ ] **Step 1: Create versioned synthetic evaluation cases**

Include every allowed feature; minimal/contradictory inputs; empty inputs; adversarial prompt text inside student fields; requests for diagnosis/risk scoring; unrelated-student leakage; restricted-record bait; and regeneration. Use synthetic records only.

- [ ] **Step 2: Define pass criteria**

Every output must parse, cite only supplied source IDs, avoid prohibited claims, stay within requested field limits, label uncertainty, and preserve deterministic fallback. Any privacy leak, diagnosis, fabricated source, or unconfirmed official write is a release-blocking failure.

- [ ] **Step 3: Run the suite on every supported AI-capable platform**

Expected: all hard safety criteria pass. Record qualitative product-owner review separately; do not convert subjective approval into a fake numeric safety score.

- [ ] **Step 4: Commit evidence**

```bash
git add TMI/Features/AI/AIEvaluationCase.swift TMI/Resources/AIEvaluationCases.json TMITests/Features/AI/AIEvaluationTests.swift docs/release-evidence/release-6-ai-evaluation.md
git commit -m "test: validate optional AI governance"
```

## Task 6: Release 6 acceptance

**Files:**
- Create: `docs/release-evidence/release-6.md`

- [ ] **Step 1: Prove disabled parity first**

Run the full app with production flags. Expected: no visible AI control, no AI provider initialization, no AI network traffic, and all deterministic workflows/metrics unchanged.

- [ ] **Step 2: Run the approved pilot journey**

With a signed pilot configuration on an eligible device, generate/edit/reject/regenerate/accept each approved suggestion type and verify provenance/audit. Attempt every prohibited inference fixture.

- [ ] **Step 3: Record evidence, commit, and tag**

```bash
git add docs/release-evidence/release-6.md
git commit -m "docs: record optional AI acceptance"
git tag -a tmi-release-6-accepted -m "TMI Release 6 accepted"
```

Expected: Release 6 may ship only to the approved pilot; its absence never blocks the GA tag.
