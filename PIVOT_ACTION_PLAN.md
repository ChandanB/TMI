# TMI Application - Pivot Action Plan

## 🎯 Current State vs. Vision State

### What We Have (Current):
```
App Structure:
├── Dashboard (admin-focused metrics)
├── Students (roster management)
├── TMI Plans (afterthought, not central)
├── Interests & Hobbies (tags, not drivers)
└── Resources (basic list)

Flow: Add Student → Create Plan → Assign Resources
Focus: Administrative efficiency
User: Primarily educators/staff
```

### What We Need (Vision):
```
App Structure:
├── Student Survey (PRIMARY ENTRY POINT)
├── Career Exploration (interest → careers)
├── CEP Builder (career pathways with TMI modules)
├── Resource Library (tagged, assignable, rich)
├── Check-ins & Reflections (student well-being)
└── Educator Dashboard (support tools)

Flow: Survey → Career Match → CEP → Resources → Reflections
Focus: Student career discovery with trauma support
User: Students first, educators support
```

---

## 📋 Immediate Pivot Steps

### Step 1: Build the Survey Flow (HIGHEST PRIORITY)
**Why:** This is the true entry point - everything flows from here

**Create:**
`TMI/Views/Survey/StudentSurveyFlow.swift`

```swift
struct StudentSurveyFlow: View {
    @State private var currentStep = 0
    @State private var responses: [String: Any] = [:]
    @State private var interestClusters: [InterestCluster] = []

    let steps = [
        SurveyStep(
            id: "welcome",
            title: "Let's discover what you love!",
            type: .intro,
            content: "This survey helps us understand your interests and match you with exciting careers."
        ),
        SurveyStep(
            id: "interests",
            title: "What excites you?",
            type: .multiSelect,
            options: [
                "Audio & Media (Podcasting, Radio, Music)",
                "Health & Wellness (Fitness, Nutrition, Medical)",
                "Technology (Coding, Gaming, Apps)",
                "Creative Arts (Design, Photography, Film)",
                "Sports & Athletics",
                "Business & Entrepreneurship"
            ]
        ),
        SurveyStep(
            id: "hobbies",
            title: "What do you do for fun?",
            type: .openEnded,
            placeholder: "Tell us about your favorite activities..."
        ),
        SurveyStep(
            id: "learning_style",
            title: "How do you like to learn?",
            type: .singleSelect,
            options: [
                "Watching videos",
                "Reading articles",
                "Hands-on practice",
                "Working with others"
            ]
        ),
        SurveyStep(
            id: "career_curiosity",
            title: "Ever dreamed of being a...",
            type: .dreamJob,
            placeholder: "Podcaster? Game Designer? Chef?"
        )
    ]

    var body: some View {
        VStack {
            // Progress indicator
            ProgressBar(current: currentStep, total: steps.count)
                .padding()

            // Current step
            steps[currentStep].view(response: $responses)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                Button(currentStep == steps.count - 1 ? "Finish" : "Next") {
                    if currentStep == steps.count - 1 {
                        // Generate CEP
                        generateCEP()
                    } else {
                        currentStep += 1
                    }
                }
            }
            .padding()
        }
    }

    func generateCEP() {
        // Analyze responses → create interest clusters
        // Match to careers
        // Auto-generate CEP template
        // Show results with confetti!
    }
}
```

### Step 2: Career Matching Algorithm
**Create:**
`TMI/Services/CareerMatchingService.swift`

```swift
struct CareerMatchingService {
    // Interest → Career mapping
    static let careerMap: [String: [Career]] = [
        "Audio & Media": [
            Career(title: "Podcaster",
                   pathway: PodcasterPathway(),
                   requiredInterests: ["Audio & Media", "Storytelling"]),
            Career(title: "Radio Host",
                   pathway: RadioHostPathway(),
                   requiredInterests: ["Audio & Media", "Communication"]),
            Career(title: "Audio Engineer",
                   pathway: AudioEngineerPathway(),
                   requiredInterests: ["Audio & Media", "Technology"])
        ],
        "Technology": [
            Career(title: "Game Developer",
                   pathway: GameDevPathway(),
                   requiredInterests: ["Technology", "Gaming"]),
            Career(title: "App Designer",
                   pathway: AppDesignPathway(),
                   requiredInterests: ["Technology", "Creative Arts"])
        ]
        // ... more mappings
    ]

    func matchCareers(from interests: [String]) -> [Career] {
        var matches: [Career] = []
        for interest in interests {
            if let careers = Self.careerMap[interest] {
                matches.append(contentsOf: careers)
            }
        }
        return matches.sorted { $0.relevanceScore(for: interests) > $1.relevanceScore(for: interests) }
    }
}
```

### Step 3: CEP Template System
**Create:**
`TMI/Data/Templates/CareerPathwayTemplates.swift`

```swift
protocol CareerPathway {
    var name: String { get }
    var beginnerGoals: [CEPGoal] { get }
    var intermediateGoals: [CEPGoal] { get }
    var advancedGoals: [CEPGoal] { get }
    var tmiModules: [TMIPlanModel] { get }
    var resources: [Resource] { get }
}

struct PodcasterPathway: CareerPathway {
    let name = "Podcaster Path"

    let beginnerGoals = [
        CEPGoal(
            title: "Plan a show concept",
            strategies: [
                "Brainstorm topic ideas",
                "Choose format (interview, solo, narrative)",
                "Define target audience"
            ],
            activities: [
                Activity(title: "Concept Worksheet", duration: 15),
                Activity(title: "Listen to 3 podcasts", duration: 60)
            ],
            assessment: "Completed show concept document",
            reflectionPrompt: "What makes your show idea unique?"
        ),
        CEPGoal(
            title: "Write your first script",
            strategies: [
                "Use script template",
                "Practice reading aloud",
                "Get peer feedback"
            ],
            activities: [
                Activity(title: "5-minute script", duration: 30),
                Activity(title: "Peer review session", duration: 20)
            ],
            assessment: "Polished 5-minute script",
            reflectionPrompt: "What was challenging about scriptwriting?"
        )
    ]

    let intermediateGoals = [
        CEPGoal(
            title: "Learn audio editing basics",
            strategies: [
                "Download free DAW (Audacity/GarageBand)",
                "Complete editing tutorial",
                "Record and edit test episode"
            ],
            activities: [
                Activity(title: "Audacity Tutorial Video", duration: 20),
                Activity(title: "Record test episode", duration: 30),
                Activity(title: "Edit with transitions", duration: 45)
            ],
            assessment: "Completed edited audio file",
            reflectionPrompt: "How did editing change your episode?"
        )
    ]

    let advancedGoals = [
        CEPGoal(
            title: "Publish 3-episode series",
            strategies: [
                "Choose platform (Anchor, Buzzsprout)",
                "Create show artwork",
                "Write show notes and description"
            ],
            activities: [
                Activity(title: "Platform setup", duration: 30),
                Activity(title: "Upload episodes", duration: 20),
                Activity(title: "Promote on social", duration: 15)
            ],
            assessment: "Live podcast with 3 episodes",
            reflectionPrompt: "What did you learn from listener feedback?"
        )
    ]

    let tmiModules: [TMIPlanModel] = [
        .chaseYourSpace,        // Explore podcasting freely
        .acknowledgeInterests,   // Audio/Media interests
        .alignYourMind,         // Focus for editing work
        .directAndCorrect       // Handle criticism constructively
    ]

    let resources = [
        Resource(title: "Podcast Planning Worksheet",
                 type: .document,
                 tags: ResourceTags(interests: ["Podcasting"],
                                   skills: ["Planning"],
                                   level: .beginner,
                                   duration: "15min")),
        Resource(title: "Audacity Basics Video",
                 type: .video,
                 tags: ResourceTags(interests: ["Podcasting", "Audio"],
                                   skills: ["Audio Editing"],
                                   level: .intermediate,
                                   duration: "20min"))
    ]
}
```

---

## 🏗️ Architectural Changes

### 1. Rename Core Models
```swift
// OLD: TMIPlan
// NEW: CEP (Career Educational Plan)

struct CEP: Codable, Identifiable {
    let id: UUID
    let studentId: String

    // Career focus (NEW)
    let targetCareer: Career
    let careerPathway: CareerPathway

    // TMI integration (ENHANCED)
    let tmiModules: [TMIPlanModel]  // Keep existing models
    let traumaSupports: [TraumaSupport] // NEW - coping skills

    // Goals (RESTRUCTURED)
    let goals: [CEPGoal]  // Now career-aligned
    let completedGoals: [CEPGoal]
    let progress: Double  // Auto-calculated

    // Resources (ENHANCED)
    let assignedResources: [Resource]
    let recommendedResources: [Resource] // Auto-suggested

    // Reflections (NEW)
    let reflections: [Reflection]

    // Timeline
    let createdFrom: SurveyResponse  // Link to survey
    let createdAt: Date
    let lastUpdated: Date
    let targetCompletionDate: Date?
}
```

### 2. Interest-Driven Architecture
```swift
// Interest is now PRIMARY, not secondary

struct Student: Codable {
    let id: UUID
    let name: String

    // Interest profile (PRIMARY)
    let surveyResponse: SurveyResponse?
    let interestClusters: [InterestCluster]
    let topInterests: [String]  // Top 3

    // Career exploration (NEW)
    let matchedCareers: [Career]
    let activeCEP: CEP?
    let careerProgress: CareerProgress

    // Demographics (SECONDARY)
    let grade: String
    let school: String

    // Support (ENHANCED)
    let traumaSupports: [TraumaSupport]
    let checkIns: [CheckIn]

    // Legacy fields...
}
```

### 3. View Hierarchy Restructuring
```
OLD Structure:
MainTabView
├── Dashboard (admin)
├── Students (roster)
├── TMI Plans (list)
└── Resources (basic)

NEW Structure:
MainTabView
├── Survey (STUDENT ENTRY)
├── Careers (exploration)
├── My CEP (student view)
├── Resources (tagged library)
├── Check-ins (well-being)
└── Educator Dashboard (support)

Role-based tabs:
- Student sees: Survey, Careers, My CEP, Resources, Check-ins
- Teacher sees: Dashboard, Students, CEPs, Resources, Reports
- Counselor sees: All + Trauma Supports + Escalations
```

---

## 🎯 Week-by-Week Implementation

### Week 1: Survey Foundation
**Goal:** Students can complete interest survey

- [ ] Create `StudentSurveyFlow.swift`
- [ ] Build `SurveyStep` components
- [ ] Implement `SurveyResponse` model
- [ ] Add progress indicator
- [ ] Add confetti on completion
- [ ] Store responses in Firebase

### Week 2: Career Matching
**Goal:** Survey results show career matches

- [ ] Create `CareerMatchingService.swift`
- [ ] Build career → interest mappings
- [ ] Create `CareerExplorationView.swift`
- [ ] Display top 3 career matches
- [ ] Add "Explore Path" action

### Week 3: CEP Generation
**Goal:** Auto-generate CEP from career selection

- [ ] Rename `TMIPlan` → `CEP`
- [ ] Create `CareerPathway` templates
- [ ] Build `PodcasterPathway` (example)
- [ ] Implement auto-CEP generation
- [ ] Show CEP preview to student

### Week 4: Resource Library
**Goal:** Rich, tagged resource system

- [ ] Enhance `Resource` model with tags
- [ ] Create tag-based filtering
- [ ] Build `ResourceLibraryView.swift`
- [ ] Implement one-click assignment
- [ ] Add reflection prompts

### Week 5: Student Dashboard
**Goal:** Student sees their CEP progress

- [ ] Create `StudentDashboardView.swift`
- [ ] Show active CEP with progress
- [ ] Display assigned resources
- [ ] Add upcoming activities
- [ ] Show career progress tree

### Week 6: Check-ins & Reflections
**Goal:** Student well-being tracking

- [ ] Create `StudentCheckInView.swift`
- [ ] Build mood tracker
- [ ] Add coping skills picker
- [ ] Implement reflection journal
- [ ] Add escalation alerts (counselor)

### Week 7: Educator Dashboard Redesign
**Goal:** Support student success, not just track

- [ ] Redesign educator dashboard
- [ ] Add morning alerts
- [ ] Show CEP completion stats
- [ ] Add quick-assign tools
- [ ] Trauma-informed prompts

### Week 8: Reports & Exports
**Goal:** Data for meetings and portfolios

- [ ] Build report generator
- [ ] CEP progress reports
- [ ] Resource usage analytics
- [ ] Student portfolio export
- [ ] PDF/CSV exports

---

## 🚨 Critical Path Items

### Must-Haves for MVP:
1. **Student Survey Flow** - without this, nothing works
2. **Career Matching** - the core value proposition
3. **CEP Auto-Generation** - from survey to plan
4. **Resource Assignment** - connect learning to pathways
5. **Student Dashboard** - show progress and next steps

### Can Wait (Phase 2):
- Advanced reporting
- Multi-school admin
- Template studio
- Parent portal
- Mobile apps (PWA first)

---

## 🔄 Migration Strategy

### For Existing Data:
1. **Keep existing TMI Plans** - migrate to CEP structure
2. **Add career field** - default to "General Skills" pathway
3. **Backfill interest data** - have students retake survey
4. **Preserve reflections** - move to new reflection system
5. **Legacy view** - admin can still see old structure

### For Existing Users:
1. **Educators** - training on new flow (survey → career → CEP)
2. **Students** - exciting new experience (career discovery)
3. **Counselors** - enhanced trauma support tools
4. **Admins** - template library for pathways

---

## 💡 Quick Wins (This Week)

To immediately align with vision:

### 1. Rename Navigation (30 minutes)
```swift
// In MainTabView.swift
case .plans:
    Label("Career Plans", systemImage: "map") // was "TMI Plans"

case .interests:
    Label("Survey", systemImage: "doc.text.magnifyingglass") // was "Interests"
```

### 2. Add "Take Survey" CTA (1 hour)
```swift
// In Dashboard, prominent placement
VStack {
    if !student.hasSurveyResponse {
        TMICard {
            VStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                Text("Discover Your Path!")
                    .font(.title2)
                Text("Take our 10-minute survey to unlock career possibilities")
                TMIButton(text: "Start Survey", action: { showingSurvey = true })
            }
        }
    }
}
```

### 3. Mock Career Cards (2 hours)
```swift
// Quick visual of what's coming
struct CareerCard: View {
    let career: String
    let interests: [String]

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(career)
                    .font(.title3)
            }
            Text("Based on: \(interests.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Explore Path") {}
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// Show in Dashboard
HStack {
    CareerCard(career: "Podcaster", interests: ["Audio", "Storytelling"])
    CareerCard(career: "Game Developer", interests: ["Tech", "Gaming"])
}
```

---

## 🎯 Success Criteria

After this pivot, the app should feel like:

**For Students:**
> "I took a survey, discovered I could be a podcaster, got a plan with activities, and I'm already recording my first episode!"

**For Educators:**
> "The survey shows me what students love, suggests careers, builds the plan for me, and gives me resources to assign. It's like magic."

**For Counselors:**
> "I can see well-being signals, assign coping skills, and support students based on their interests—trauma-informed and effective."

---

## 📊 Metrics to Track

### Student Engagement:
- Survey completion rate
- Career exploration clicks
- CEP progress %
- Resource completion
- Reflection submissions

### Educator Effectiveness:
- Time to create CEP (should be <5 min with auto-gen)
- Resource assignment rate
- Report usage
- Trauma-informed prompt engagement

### System Health:
- CEPs auto-generated from surveys
- Career-resource alignment
- TMI module integration rate
- Check-in response time

---

## 🚀 Let's Start

**The #1 priority right now:**

Build the Student Survey Flow. Everything else flows from this.

Once students have interest profiles, careers emerge, CEPs generate, resources align, and the whole vision comes together.

**Action:** Create `TMI/Views/Survey/StudentSurveyFlow.swift` and let's build the foundation of the real TMI experience.

---

*This pivot transforms TMI from a student tracking system into a career discovery platform with trauma-informed support—exactly as intended.* 🎯
