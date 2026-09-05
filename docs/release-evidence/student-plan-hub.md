# Student plan hub integration

Date: September 5, 2026
Base: `5a88ba8` (includes the latest Debug teacher plan access changes)

## Product behavior

The production student hub now reads district-scoped interests, career relationships, and plans. Only the selected student's plans contribute to the hub. Active counts require both active lifecycle status and recorded approval. Completed and archived plans remain in history. Failed or malformed reads fail explicitly instead of becoming zero counts; unavailable interaction timestamps remain unknown.

The student's Plans destination presents an embedded, non-scrolling list inside the existing student scroll view. Creating a plan selects this destination and refreshes the hub. Rows open canonical plan detail. Membership changes reload the list, and an older read cannot replace a newer request's result. Changing students recreates the list state.

The existing Debug workspace continues using its in-memory plan repository. Production continues using canonical Firebase repositories. No production sample fallback was introduced. Aubergine and teal remain unchanged.

## Regression coverage

- Hub aggregation excludes other students and other districts, separates open/history records, and counts only approved active plans.
- Related-read failures do not publish an empty summary; mismatched student responses are rejected.
- A filtered plan list never exposes another student's plan, including when completed records are shown.
- A UI fixture embeds the actual plan list in a student-style scroll view and opens actual plan detail.
- Plan approval, activation, audited PDF share-sheet presentation, child-read failure, and largest Dynamic Type are exercised.
- The unauthorized student-context regression now uses a counselor without an assignment, matching current school-wide teacher read policy.

## Verification

Unit verification passed: 568 Swift Testing cases in 67 suites; 164 XCTest cases with 3 existing skips and no unit failures. Result bundle: `/tmp/TMI-StudentHub-Final.xcresult`; log: `/tmp/TMI-StudentHub-Final.log`. That combined run exposed a UI-only accessibility identifier inheritance issue in the embedded plan list. The parent identifier was removed so each row retains its own identifier.

Final UI verification passed: all 4 plan workflow tests. Evidence: `/tmp/TMI-StudentHub-UI-Final.xcresult` and `/tmp/TMI-StudentHub-UI-Final.log`. The embedded list was visually inspected on iPhone 17; `/tmp/TMI-Student-Plan-List.png` shows the selected-student heading, readable plan row, status, and toggle without clipping.

macOS Release build passed, including final confirmation after the embedded-list accessibility/title edits (`/tmp/TMI-StudentHub-Mac-Final.log`, exit 0, BUILD SUCCEEDED). Signing was disabled for this local macOS build; distribution signing and notarization are not verified.

Firebase emulator regression passed: 258 tests across 14 files (`npm --prefix firebase test`). Log: `/tmp/TMI-StudentHub-Firebase.log`. This ran locally and did not deploy rules or Functions.

An initial unsigned simulator run failed keychain-dependent tests. Normal simulator signing restored those tests. The PDF-share assertion was corrected from a button to the native share sheet's observed Copy cell; the share sheet itself opened successfully.

## Remaining release gates

This is a verified increment toward the full application, not a GA completion claim. Supporting collaboration workflows, district reporting, migration validation, deployment, and institutional pilot acceptance still require completion against the current approved specification. This change does not deploy Firebase or publish the app.
