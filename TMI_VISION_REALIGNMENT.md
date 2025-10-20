# TMI Application - Vision Realignment Plan

## 🎯 The Core Disconnect

### What We Have Now:
- Generic student roster management
- TMI plans as **afterthought** (just another plan type)
- Interests/hobbies treated as **tags** (not drivers)
- No career exploration or CEP focus
- Heavy on administrative views, light on student experience

### What We Should Have:
- **Interest-first experience** (survey → careers → CEP → resources)
- TMI plans as the **foundation** (6 trauma-informed models)
- Careers and pathways **auto-suggested** from interests
- Rich resource library **mapped to every interest**
- **Student-facing** with educator support tools

---

## 🔄 Transformation Roadmap

### Phase 1: Core Flow Rebuild (Priority 1)

#### 1.1 Student Survey/Questionnaire (NEW - Primary Entry Point)
**Purpose:** Capture interests/hobbies → Generate CEP

**File:** `TMI/Views/Survey/StudentSurveyFlow.swift`

```swift
// Multi-step survey flow
- Welcome screen (warm, friendly)
- Interest categories (Audio/Media, Health, Tech, Sports, Arts, etc.)
- Learning style questions
- Career curiosity prompts
- Results → Auto-generate CEP template
```

**Key Features:**
- Mobile-first, 10-12 minute completion
- Progress indicator (not just % - "You're 80% to your goal!")
- Branching logic (if "Podcasting" → ask about audio experience)
- Confetti/celebration on completion
- Immediate CEP preview

#### 1.2 Career Exploration Dashboard (NEW - Core View)
**Purpose:** Show auto-suggested careers from interests

**File:** `TMI/Views/Careers/CareerExplorationView.swift`

```swift
// Career tiles based on survey results
- Top 3 interest clusters → Career matches
- "Podcaster Path" → detailed breakdown
- "Media Producer" → skills/resources needed
- "Audio Engineer" → educational pathway
```

**Visual:**
```
┌─────────────────────────────────────────┐
│  Your Career Matches                    │
│                                         │
│  🎙️ Podcaster                          │
│  Based on: Audio/Media, Storytelling    │
│  [ Explore Path ]                       │
│                                         │
│  🎬 Video Editor                        │
│  Based on: Media, Technology            │
│  [ Explore Path ]                       │
│                                         │
│  📻 Radio Host                          │
│  Based on: Audio, Communication         │
│  [ Explore Path ]                       │
└─────────────────────────────────────────┘
```

#### 1.3 CEP Builder (Redesign Existing TMI Plans)
**Purpose:** Transform TMI Plan creation into CEP generation

**File:** `TMI/Views/CEP/CEPBuilderView.swift`

**New Structure:**
1. **Auto-template from survey** (e.g., "Podcaster CEP")
2. **Drag-drop modules:**
   - Goal → Strategies → Activities → Assessments → Reflection
3. **TMI model integration:**
   - Chase Your Space (starter module)
   - Acknowledge Interests (auto-populated from survey)
   - Align Your Mind (coping skills)
   - Direct & Correct (behavior strategies)
   - Bully to Boss (leadership rechanneling)
   - Meek to Protector (confidence building)
4. **Smart suggestions:**
   - "Add audio editing resource?" (for podcasting)
   - "Include script writing activity?"
   - "Pair with School News Club?"

---

### Phase 2: Resource Library Overhaul (Priority 2)

#### 2.1 Tag-Based Resource System (NEW)
**File:** `TMI/Views/Resources/ResourceLibraryView.swift`

**Tag Dimensions:**
- **Interest:** Podcasting, Esports, Cosmetology, STEM, etc.
- **Skill:** Scriptwriting, Audio Editing, Video Production
- **Level:** Beginner → Intermediate → Advanced
- **Format:** Video, Article, Course, Tool
- **Time:** 5min, 15min, 30min, 1hr+

**Visual:**
```
┌─────────────────────────────────────────┐
│  Resources for: Podcasting              │
│                                         │
│  Beginner (3)                           │
│  ├─ 🎥 "Your First Podcast" (5min)     │
│  ├─ 📄 Script Template                 │
│  └─ 🎧 "Mic Basics" (10min)            │
│                                         │
│  Intermediate (5)                       │
│  ├─ 🎵 "DAW Tutorial: Audacity"        │
│  ├─ 🎨 "Show Logo Design"              │
│  └─ 📊 "Analytics 101"                 │
│                                         │
│  [ Assign to Student ] [ Add to CEP ]  │
└─────────────────────────────────────────┘
```

#### 2.2 One-Click Assignment
**Feature:** Assign resource → student/group with due date + reflection prompt

```swift
// Quick assign modal
TMIResourceAssignment(
    resource: resource,
    assignTo: .student(student) | .group(students),
    dueDate: Date(),
    reflectionPrompt: "What did you learn from this?"
)
```

---

### Phase 3: Student-Facing Experience (Priority 3)

#### 3.1 Student Dashboard (NEW - Primary Student View)
**File:** `TMI/Views/Student/StudentDashboardView.swift`

**Components:**
- My CEP (current goals, progress %)
- Assigned Activities (due dates)
- Career Path (visual progress tree)
- Resource Library (assigned + browse)
- Check-ins (mood tracker)
- Reflection Journal

**Visual:**
```
┌─────────────────────────────────────────┐
│  Hi Jamal! 👋                           │
│                                         │
│  Your Podcaster Path        [75% ✓]    │
│  Next: Complete script writing          │
│                                         │
│  📚 Assigned Activities (2)             │
│  ├─ Write 5-min script (Due: Friday)   │
│  └─ Record test episode (Due: Mon)     │
│                                         │
│  🎯 Career Progress                     │
│  Beginner ━━━━━━━●━━━ Intermediate      │
│                                         │
│  💭 How are you feeling today?          │
│  [ 😊 😐 😢 😡 😰 ]                    │
└─────────────────────────────────────────┘
```

#### 3.2 Check-ins & Well-being (NEW)
**File:** `TMI/Views/CheckIns/StudentCheckInView.swift`

**Quick Check-ins:**
- Mood slider (visual faces)
- "What helped you this week?"
- Coping skills picker (breathing, journaling, etc.)
- Escalation detection (counselor alert if distress signals)

---

### Phase 4: Educator Support Tools (Priority 4)

#### 4.1 Educator Dashboard (Redesign Current Dashboard)
**File:** `TMI/Views/Educator/EducatorDashboardView.swift`

**Morning View:**
```
┌─────────────────────────────────────────┐
│  Good morning, Ms. Johnson! ☀️          │
│                                         │
│  🔔 Alerts (3)                          │
│  • 2 students need follow-up            │
│  • 1 assignment overdue                 │
│                                         │
│  📊 Quick Stats                         │
│  • 85% survey completion                │
│  • 12 active CEPs                       │
│  • 3 check-ins flagged                  │
│                                         │
│  🎯 Today's Focus                       │
│  [ Assign Podcasting Resources ]        │
│  [ Review Jamie's CEP ]                 │
│  [ Run Weekly Report ]                  │
└─────────────────────────────────────────┘
```

#### 4.2 Trauma-Informed Coaching (NEW)
**File:** `TMI/Views/Educator/TraumaInformedGuide.swift`

**Contextual Prompts:**
- Student shows distress → "Try acknowledging their interests first"
- Behavior incident → "Consider 'Direct & Correct' module"
- Low engagement → "Suggest coping skills toolkit"

---

### Phase 5: Concrete Pathways (Priority 5)

#### 5.1 "Podcaster Path" Template (Example Implementation)
**File:** `TMI/Data/Templates/PodcasterCEPTemplate.swift`

```swift
struct PodcasterCEPTemplate: CEPTemplate {
    var name = "Podcaster Path"
    var interests = ["Audio/Media", "Storytelling", "Technology"]

    var beginnerGoals = [
        Goal(title: "Plan a show concept",
             activities: ["Brainstorm topics", "Choose format"],
             resources: ["Show Concept Worksheet", "Podcast Examples"]),
        Goal(title: "Write a 5-minute script",
             activities: ["Script template", "Peer review"],
             resources: ["Scriptwriting 101", "Sample Scripts"])
    ]

    var intermediateGoals = [
        Goal(title: "Learn basic audio editing",
             activities: ["Audacity tutorial", "Record test episode"],
             resources: ["DAW Basics Video", "Free Sound Effects"]),
        Goal(title: "Create show branding",
             activities: ["Logo design", "Intro music"],
             resources: ["Canva Tutorial", "Royalty-Free Music"])
    ]

    var advancedGoals = [
        Goal(title: "Publish 3-episode series",
             activities: ["Upload to platform", "Write show notes"],
             resources: ["Distribution Guide", "SEO Tips"]),
        Goal(title: "Analyze and improve",
             activities: ["Review analytics", "Listener feedback"],
             resources: ["Analytics Dashboard", "Growth Strategies"])
    ]

    var tmiModules = [
        .chaseYourSpace,        // Explore podcasting freely
        .acknowledgeInterests,   // Audio/Media interests
        .alignYourMind          // Focus/discipline for editing
    ]
}
```

---

## 🏗️ Implementation Priority

### Week 1-2: Foundation
- [ ] Create `StudentSurveyFlow.swift` (10-12 min questionnaire)
- [ ] Build `CareerExplorationView.swift` (career matching logic)
- [ ] Design interest → career mapping algorithm

### Week 3-4: CEP Transformation
- [ ] Redesign TMI Plan → CEP Builder
- [ ] Implement drag-drop module system
- [ ] Create template library (Podcaster, STEM Explorer, etc.)
- [ ] Auto-suggest TMI modules based on needs

### Week 5-6: Resources & Assignment
- [ ] Build tag-based resource library
- [ ] Implement one-click assignment
- [ ] Create reflection prompt system
- [ ] Add due date management

### Week 7-8: Student Experience
- [ ] Student dashboard with CEP progress
- [ ] Activity completion tracking
- [ ] Check-in/mood tracking
- [ ] Reflection journal

### Week 9-10: Educator Tools
- [ ] Redesign educator dashboard (morning alerts)
- [ ] Trauma-informed coaching prompts
- [ ] Weekly report generator
- [ ] Group assignment tools

---

## 🎨 Design System Updates

### Color Palette (Light Theme Default)
```swift
// Warm, welcoming school-safe colors
static let tmiBackground = Color(hex: "#F8F9FA")      // Soft off-white
static let tmiPrimary = Color(hex: "#4A90E2")         // Gentle blue
static let tmiSuccess = Color(hex: "#7CB342")         // Friendly green
static let tmiWarm = Color(hex: "#FF9F43")            // Warm orange
static let tmiText = Color(hex: "#2C3E50")            // High contrast text

// Career category colors
static let audioMedia = Color(hex: "#9B59B6")         // Purple
static let health = Color(hex: "#16A085")             // Teal
static let tech = Color(hex: "#3498DB")               // Blue
static let arts = Color(hex: "#E74C3C")               // Red
static let sports = Color(hex: "#F39C12")             // Orange
```

### Typography (Dyslexia-Friendly Option)
```swift
// Default: SF Pro (Apple standard)
// Optional: OpenDyslexic font for accessibility

static let dyslexiaFont: Font = .custom("OpenDyslexic", size: 17)
```

### Micro-Interactions
```swift
// Progress ring during survey
ProgressRing(progress: surveyProgress, color: .tmiPrimary)
    .animation(.spring(response: 0.6, dampingFraction: 0.8))

// Confetti on CEP completion
ConfettiView(trigger: cepCompleted)

// "You're 80% to your goal!" nudge
NudgeNotification(
    message: "You're 80% to your Podcaster goal!",
    icon: "🎉"
)
```

---

## 📊 Data Model Updates

### New Models Required:

```swift
// Survey Response
struct SurveyResponse: Codable {
    let studentId: String
    let responses: [String: Any]
    let interestClusters: [InterestCluster]
    let completedAt: Date
}

// Interest Cluster
struct InterestCluster: Codable {
    let id: UUID
    let name: String // "Audio/Media", "Health", "Tech"
    let weight: Double // 0.0 - 1.0
    let relatedCareers: [Career]
}

// Career
struct Career: Codable {
    let id: UUID
    let title: String // "Podcaster", "Audio Engineer"
    let description: String
    let pathway: CareerPathway
    let requiredInterests: [String]
    let resources: [Resource]
}

// Career Pathway
struct CareerPathway: Codable {
    let beginner: [Goal]
    let intermediate: [Goal]
    let advanced: [Goal]
}

// CEP (Career Educational Plan) - Replaces TMIPlan
struct CEP: Codable {
    let id: UUID
    let studentId: String
    let careerGoal: Career
    let tmiModules: [TMIPlanModel] // Align Your Mind, etc.
    let goals: [Goal]
    let resources: [Resource]
    let progress: Double
    let reflections: [Reflection]
}

// Resource (Enhanced)
struct Resource: Codable {
    let id: UUID
    let title: String
    let type: ResourceType // video, article, course, tool
    let tags: ResourceTags
    let url: String
    let duration: TimeInterval
    let level: SkillLevel
}

struct ResourceTags: Codable {
    let interests: [String] // "Podcasting", "Esports"
    let skills: [String]    // "Scriptwriting", "Audio Editing"
    let format: String      // "video", "article"
    let time: String        // "5min", "15min"
}

// Check-in
struct CheckIn: Codable {
    let id: UUID
    let studentId: String
    let timestamp: Date
    let mood: MoodLevel
    let notes: String
    let copingSkillsUsed: [String]
    let escalationFlag: Bool // Alert counselor
}

// Reflection
struct Reflection: Codable {
    let id: UUID
    let activityId: String
    let prompt: String
    let response: String
    let submittedAt: Date
}
```

---

## 🔐 Role-Based Views

### Student Role:
- Student Dashboard
- Survey Flow
- Career Exploration
- My CEP
- Assigned Resources
- Check-ins
- Reflection Journal

### Teacher Role:
- Educator Dashboard
- CEP Builder
- Resource Library
- Assignment Tools
- Progress Reports
- Trauma-Informed Guides

### Counselor Role:
- All Teacher views +
- Check-in Monitoring
- Coping Skills Toolkit
- Confidential Notes
- Escalation Alerts
- Support Module Assignment

### Admin Role:
- Template Studio
- Resource Collection Management
- Reporting Suite
- User/Permission Management
- Data Export Tools

---

## 🚀 Next Steps

### Immediate Actions:
1. **Pause current work** - stop building generic admin features
2. **Build Survey Flow** - this is the true entry point
3. **Create Career Matching Logic** - interests → careers algorithm
4. **Redesign TMI Plans as CEPs** - career-focused, not admin-focused

### Key Mindset Shift:
- **FROM:** "Track students and plans"
- **TO:** "Help students discover careers through interests and provide pathways"

---

## 💡 Why This Matters

Your current app feels administrative because it's built from the **educator perspective first**. The TMI vision is **student-centered** - the survey drives everything, careers emerge from interests, and educators support the journey.

The app should feel like:
- **For students:** "This app helps me explore what I love and turn it into a career"
- **For educators:** "This app gives me the tools to guide interest-based learning"
- **For counselors:** "This app helps me support whole-student well-being"

**Not:**
- "This is a student roster system with some plan features"

---

## 🎯 Success Vision (6 Months)

A student (Jamal) experience:
1. Takes 10-min survey → discovers "Podcasting" matches his interests
2. Views "Podcaster Path" CEP → auto-generated with beginner goals
3. Teacher assigns "Script Writing 101" video → completes it
4. Reflects: "I learned structure matters" → logged in portfolio
5. Progresses to intermediate → "Audio Editing Basics"
6. Creates 3-episode podcast → showcases at school assembly
7. Explores "Audio Engineering" career → sees college pathway
8. Completes "Align Your Mind" TMI module → gains focus skills
9. Teacher sees progress report → shares with counselor
10. Jamal's confidence grows → "From Meek to Protector" completed

**This is the TMI vision.** 🎯
