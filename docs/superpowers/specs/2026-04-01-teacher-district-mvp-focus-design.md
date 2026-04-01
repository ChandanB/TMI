# Teacher-District MVP Focus Design

**Date:** 2026-04-01
**Scope:** Product-shaping spec for a compelling pilot MVP serving teachers first and district admins second

## Problem Summary

The app already contains a broad set of product surfaces, including district analytics, forms, meetings, resources, compliance, career exploration, approvals, exports, and student-mode experiences. That breadth creates a product risk for MVP: the app can appear capable without making the core teacher workflow feel fast, obvious, and repeatable.

The target pilot outcome is not "more features shipped." The target outcome is:

1. Teachers can create meaningful interventions faster.
2. Students receive clear, relevant next steps that improve engagement.
3. District admins can verify adoption and early outcomes from teacher usage.

The MVP therefore needs a sharper product center of gravity. The teacher workflow must be the primary product experience, while the district admin experience should function as a lightweight evidence layer over teacher activity.

## Primary Personas

### Teacher

The teacher is the primary operational user for MVP. They need to move quickly from concern identification to action. Their core questions are:

- Which student needs support now?
- What intervention should I create?
- What should the student do next?
- Is the student engaging, or do I need to follow up?

### District Admin

The district admin is a secondary but important MVP persona. Their value comes after teacher usage exists. Their core questions are:

- Are teachers adopting the system?
- How many students have active interventions?
- Which schools, teachers, or students need attention?
- Is there any early signal that student engagement is improving?

## Product Thesis

The MVP should make TMI feel like an intervention accelerator for teachers, not a broad educational platform. District value should be legible from the same data the teacher workflow generates.

The teacher workflow is the product. The district dashboard is the proof.

## Recommended Approach

### Option 1: Teacher-First Operational MVP (Recommended)

Center the app on a teacher's end-to-end intervention workflow, then expose only the district views needed to measure usage and student follow-through.

**Why this is recommended**

- It directly serves the stated pilot goals of faster planning and stronger engagement.
- It matches the dependency chain: district reporting is only credible if teachers are actively using the product.
- It reduces cognitive load and navigation complexity during pilot rollout.
- It gives the team a clear standard for deciding what to hide, defer, or simplify.

### Option 2: Balanced Teacher + District MVP

Give teachers the core workflow while also surfacing a richer district cockpit, approvals, reporting, and administrative oversight from the start.

**Trade-offs**

- Better enterprise storytelling in demos.
- Higher product surface area and higher risk of distracting from teacher speed.
- More chance of polish debt across multiple partially complete flows.

### Option 3: Engagement-First Assessment MVP

Lead with surveys, student interest profiling, student-facing engagement, and recommendation systems, with intervention planning following those flows.

**Trade-offs**

- Could produce strong personalization stories.
- Weaker fit for the primary outcome of faster teacher intervention planning.
- Adds more steps before the teacher reaches action.

## MVP Scope

The MVP should be defined as five connected capabilities.

### 1. Fast Teacher Onboarding

Teachers should be able to begin using the system immediately with:

- clear sign-in and role handling
- sample or seeded data for demos and first-run understanding
- a low-friction path to add or import a first student
- immediate calls to action after onboarding

### 2. Unified Student Profile

The student profile should become the operational hub for teacher action. It should combine:

- basic student context
- interests and relevant strengths
- current concerns or intervention reason
- active plans
- assigned next steps
- recent engagement or completion status

Teachers should not need to bounce between disconnected feature areas to understand or act on a student.

### 3. Faster Intervention Planning

This is the highest-priority product improvement. Intervention planning should feel like guided decision support, not record entry. The flow should:

- start from student need and student interests
- suggest an intervention type, template, or recommended plan structure
- prefill reasonable goals, activities, or first actions
- keep required inputs intentionally minimal
- end with one clear actionable next step for the student

The workflow should optimize for speed, confidence, and editability.

### 4. Visible Student Engagement Loop

Student engagement must be visible and measurable in the MVP. The app should support a simple loop:

1. Teacher assigns a next step, resource, or check-in.
2. Student views, responds to, or completes it.
3. Teacher sees updated status and whether follow-up is needed.
4. District admins see aggregate usage and engagement signals.

This loop is more important than adding many kinds of student-facing experiences. One reliable engagement loop is more valuable than several shallow ones.

### 5. Lightweight District Evidence Layer

District admins should have a concise dashboard showing:

- teacher adoption and active usage
- active students with plans
- engagement or completion trend indicators
- students needing attention
- school-level filtering if already stable

The district experience should emphasize legibility and trustworthiness over exhaustiveness.

## MVP Cuts and Demotions

Any feature that does not directly shorten teacher planning time or improve student follow-through should be hidden, deferred, or folded into the core flow.

For MVP, the following should be demoted from primary navigation or deferred:

- forms as a top-level destination
- broad resource-library browsing as a standalone activity
- deep career explorer as a primary tab
- prominent compliance and administrative settings surfaces
- complex approval workflows unless they are required for pilot operations
- secondary or orphaned feature areas that are not part of the teacher loop

These capabilities may still exist technically, but they should not compete with the main workflow in the product experience.

## UX Direction

### Navigation

`MainTabView` should present a smaller, clearer set of surfaces for MVP:

- `Dashboard`
- `Students`
- `Plans`
- `District` for applicable admin roles
- `Settings` kept slim and secondary

The user should understand the app's primary action model within seconds.

### Student Detail as Command Center

The student detail view should become the place where a teacher can:

- quickly understand the student
- see what is active now
- create or revise an intervention
- assign a next action
- check whether the student responded

This view should absorb responsibility currently spread across multiple disconnected screens.

### Progressive Disclosure

Advanced features should appear only when they support the current job to be done. Teachers should not need to choose among unrelated modules before they can act.

### Strong Defaults

The MVP should rely on defaults, templates, sample data, and clear calls to action. A blank or ambiguous first-run experience will weaken pilot credibility more than missing advanced capability.

## Architecture Direction

The implementation should favor a narrower, more reliable product flow over preserving every existing surface equally.

### Workflow Consolidation

Interests, recommendations, resources, and planning should feed the same teacher decision flow rather than existing as separate destinations with separate mental models.

### State and Data Reliability

The app already includes relevant services and state models for students, plans, resources, forms, district analytics, and recommendations. For MVP, the priority should be to reduce disconnected flows and ensure the teacher loop has a small set of trustworthy read/write paths:

- student profile and context
- plan creation and editing
- assignment of next actions/resources
- engagement/progress status
- district rollups derived from those actions

### Pilot Clarity Over Platform Completeness

Architecture decisions should support the pilot experience:

- fewer dead-end screens
- fewer duplicate entry points
- clearer empty, loading, and error states
- a more obvious relationship between teacher actions and district reporting

## Success Criteria

The MVP should be considered compelling if it demonstrates the following:

### Teacher Outcomes

- A teacher can create a meaningful first intervention quickly.
- The intervention workflow reduces decision fatigue and data entry.
- The student detail view makes follow-up obvious.

### Student Outcomes

- Each plan results in a clear next step the student can engage with.
- Engagement status is visible, current, and actionable.

### District Outcomes

- District admins can see whether teachers are adopting the system.
- District admins can identify active plans, engagement signals, and students needing attention without deep drilling.

### Product Outcomes

- Users are not exposed to unfinished or nonessential areas during the pilot.
- Seeded data and empty states make the app easy to demo and evaluate.

## Testing Focus

Testing for this MVP should emphasize the core promise rather than broad feature coverage.

### Functional Validation

- Teachers can add students, create plans, and assign next steps without dead ends.
- Suggested or templated planning paths materially reduce input burden.
- Engagement updates propagate correctly to teacher and district surfaces.
- District summary metrics reflect teacher behavior accurately.

### UX Validation

- A first-time teacher can complete the core workflow without explanation.
- A district admin can understand adoption and risk signals from a single screen.
- First-run and empty-state experiences are legible and useful.

## Phased Recommendation

### Phase A: MVP Tightening

- reduce primary navigation to teacher-critical surfaces
- make student detail the center of action
- simplify plan creation around strong defaults and templates
- expose a single visible engagement loop

### Phase B: District Readout

- refine the district dashboard around adoption, activity, and students needing attention
- keep filtering and exports only where the underlying data is stable and easy to trust

### Phase C: Post-MVP Expansion

Once the pilot loop is working and users can reliably create and follow through on interventions, re-evaluate broader surfaces such as forms, deeper resource workflows, career exploration depth, approvals, and additional administrative tooling.

## Out of Scope for This Spec

- Detailed UI wireframes for each screen
- Implementation sequencing at the task level
- Full technical refactor plan for every existing feature area
- Redesigning compliance strategy or enterprise administration workflows

Those belong in the follow-up implementation planning stage.
