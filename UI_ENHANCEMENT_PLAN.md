# TMI UI Enhancement Plan
## Trauma-Informed Design Principles

Based on TMI's mission to support trauma-affected students through tangible interventions, our UI should embody:

### Core Principles
1. **Clarity Over Complexity** - Reduce cognitive load for stressed educators
2. **Compassionate Design** - Warm, approachable, non-clinical aesthetics
3. **Quick Access to Care** - Fast paths to student support actions
4. **Progress Visibility** - Clear indicators of student growth and engagement
5. **Privacy & Dignity** - Respectful presentation of sensitive student data

---

## Phase 1: Immediate Enhancements (Today)

### 1.1 Dashboard Improvements

**Current Issues:**
- Trend indicator shows "No change" which is passive
- Empty engagement chart wastes space
- Stats lack context and actionability
- Missing quick insights about student needs

**Enhancements:**
```swift
// Add contextual insights
- Replace "No change" with actionable prompts
- Show "3 students need check-in" instead of static metrics
- Add quick action cards: "Students needing attention", "Plans due this week"
- Make chart collapsible when no data
```

**Impact:** Educators get actionable insights immediately, not just numbers

### 1.2 Students List Enhancements

**Current Issues:**
- Missing school names (only shows grade)
- No visual row separation
- FAB not visible
- Engagement badges could be more informative

**Enhancements:**
```swift
// Improve information density
- Add school name below grade: "Grade 12 • Lincoln High"
- Add subtle dividers between rows
- Make FAB always visible at bottom-right
- Add last interaction date: "Last contacted: 2 days ago"
- Color-code engagement badges: Green (High), Yellow (Med), Red (Low)
```

**Impact:** More context at-a-glance, faster decision making

### 1.3 Visual Polish

**Current Issues:**
- Cards blend together (low contrast)
- Buttons could be more prominent
- Empty states are generic

**Enhancements:**
```swift
// Improve visual hierarchy
- Add subtle shadows to cards for depth
- Make primary buttons more prominent (larger, brighter)
- Custom empty states with helpful guidance
- Add micro-interactions (subtle animations on tap)
```

---

## Phase 2: Feature Enhancements (This Week)

### 2.1 Student Detail View

**Add:**
- Timeline view of all interventions
- Quick communication button (email/message parent)
- Recent behavioral observations
- Interest-based conversation starters
- Trauma-sensitive flags (visible only to authorized staff)

### 2.2 TMI Plan Creation

**Enhance:**
- Visual model selector with student-facing descriptions
- Interest-based activity suggestions
- Resource attachment (from library)
- Collaboration features (share with other educators)

### 2.3 Dashboard Analytics

**Add:**
- Weekly engagement trends
- At-risk student alerts
- Success stories (positive outcomes)
- Recommended actions based on data

---

## Phase 3: Advanced Features (Next Sprint)

### 3.1 Parent Portal Views
- Student-specific parent views
- Progress sharing
- Resource recommendations
- Communication log

### 3.2 Counselor Tools
- Multi-student comparison
- Intervention effectiveness tracking
- Referral workflow
- Crisis response quick access

### 3.3 Admin Dashboard
- School-wide analytics
- Educator usage metrics
- Budget impact tracking
- Compliance reporting

---

## Design System Enhancements

### Color Psychology for Trauma-Informed Care

**Current:**
- Primary: Blue (neutral, professional)
- Success: Green (positive)
- Warning: Orange (caution)
- Error: Red (alert)

**Enhanced Palette:**
```swift
// Warm, approachable tones
.tmiCalm = Soft teal (#4ECDC4) - For positive interventions
.tmiSupport = Warm amber (#FFB84D) - For ongoing support
.tmiGrowth = Fresh green (#95E1D3) - For progress indicators
.tmiSafe = Gentle lavender (#B8A9C9) - For safe spaces/trust-building

// Engagement levels (visible, not alarming)
.tmiEngagedHigh = Vibrant green (#10B981)
.tmiEngagedMed = Gentle yellow (#FBBF24)
.tmiEngagedNeedsSupport = Soft orange (#FB923C) // Not "low" - "needs support"
```

### Typography Hierarchy

**Enhance for Scanability:**
```swift
.tmiHero = 34pt Bold - Dashboard key metrics
.tmiSectionHeader = 20pt Semibold - Section titles
.tmiCardTitle = 17pt Semibold - Card/row titles
.tmiBody = 15pt Regular - Body text
.tmiDetail = 13pt Regular - Metadata
.tmiCaption = 11pt Regular - Helper text
```

### Spacing & Breathing Room

**Trauma-Informed Spacing:**
- Generous padding around sensitive data
- Clear separation between students
- Ample touch targets (min 48pt)
- Whitespace to reduce overwhelm

---

## Implementation Roadmap

### Week 1: Foundation (Current)
- [x] Fix color contrast issues
- [x] Implement redesigned Dashboard/Students/Plans
- [ ] Add missing FAB to Students
- [ ] Show school names in Students list
- [ ] Improve empty states
- [ ] Add row separators

### Week 2: Enhancement
- [ ] Dashboard quick insights
- [ ] Student detail timeline
- [ ] Improved engagement indicators
- [ ] Resource integration
- [ ] Parent communication stubs

### Week 3: Advanced Features
- [ ] Analytics dashboard
- [ ] Multi-student views
- [ ] Export/reporting
- [ ] Collaboration tools

### Week 4: Polish & Testing
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] User testing with educators
- [ ] Performance optimization
- [ ] Documentation

---

## Success Metrics

**User Experience:**
- Time to add student: < 20s (currently ~28s)
- Time to create plan: < 45s (currently ~55s)
- Student lookup: < 5s
- Key info visible: 3 taps or less

**Engagement:**
- Daily active users (educators)
- Plans created per week
- Student check-in frequency
- Resource usage

**Impact:**
- Student engagement score improvement
- Educator confidence ratings
- Parent satisfaction
- Intervention success rate

---

## Next Actions

1. ✅ Fix FAB visibility in Students list
2. ✅ Add school names to student rows
3. ✅ Improve visual card separation
4. ✅ Enhance empty states with guidance
5. ✅ Make engagement badges more informative
6. Add quick action cards to Dashboard
7. Implement timeline view in student details

**Estimated Time:** 4-6 hours for Week 1 tasks

---

## Notes

- Prioritize educator efficiency - they're often overwhelmed
- Keep student privacy paramount - no sensitive data in screenshots/previews
- Use positive language: "needs support" not "low engagement"
- Make success visible - celebrate small wins
- Design for interruption - auto-save everything
- Consider offline mode - schools have connectivity issues

**Remember:** Every design decision should ask: "Does this help an educator better support a trauma-affected student?"
