# TMI Redesign Migration Checklist

## Phase 1: Foundation (Week 1)

### Day 1-2: Design Tokens
- [ ] Add color assets to `Assets.xcassets`
  - [ ] Create "Background" color set (white → dark navy)
  - [ ] Create "Surface" color set (light gray → lighter navy)
  - [ ] Create "Primary" color set (blue → light blue)
  - [ ] Create "TextPrimary" color set (near black → near white)
  - [ ] Create "TextSecondary" color set (gray → light gray)
- [ ] Update `TMIDesignTokens.swift` to reference asset colors
- [ ] Test color switching in light/dark mode

### Day 3-4: Component Library
- [ ] Build and test all components in `TMIComponents.swift`
- [ ] Create preview file: `TMIComponentsPreviews.swift`
- [ ] Test components in isolation
- [ ] Verify accessibility (VoiceOver, Dynamic Type)

### Day 5-7: Asset Cleanup
- [ ] Audit existing views for custom components
- [ ] Document components to deprecate:
  - [ ] `TMIGlassCard` → `TMICard`
  - [ ] `TMIParticleEffect` → Remove
  - [ ] `DynamicBackgroundView` → `Color.tmiBackground`
  - [ ] Custom buttons → `TMIButton`

---

## Phase 2: Core Screens (Week 2)

### Dashboard
- [ ] Update `MainTabView.swift` to import `DashboardViewRedesigned`
- [ ] Test dashboard with live data
- [ ] Verify chart rendering
- [ ] Test pull-to-refresh
- [ ] Check empty state
- [ ] Verify "Add Student" navigation

### Students List
- [ ] Replace `StudentListView` with `StudentListViewRedesigned` in navigation
- [ ] Test search functionality
- [ ] Test filter chips (Grade, Engagement)
- [ ] Verify list scrolling performance
- [ ] Test FAB placement and animation
- [ ] Check empty state + CTA

### Student Detail
- [ ] Update navigation to use `StudentDetailViewRedesigned`
- [ ] Test collapsible sections
- [ ] Verify quick actions work
- [ ] Test engagement chart rendering
- [ ] Check academic performance display
- [ ] Verify notes/history display

---

## Phase 3: Flows (Week 3)

### Add Student Flow
- [ ] Replace `AddStudentView` with `AddStudentViewRedesigned`
- [ ] Test 3-field validation
- [ ] Test advanced section collapse/expand
- [ ] Verify Firebase save operation
- [ ] Test error handling
- [ ] Check success callback

### Create Plan Flow
- [ ] Replace `NewTMIPlanView` with `NewTMIPlanViewRedesigned`
- [ ] Test smart model suggestion logic
- [ ] Verify model selection UI
- [ ] Test interest chip multi-select
- [ ] Verify Firebase save operation
- [ ] Test navigation from student detail

### Plans List
- [ ] Replace `TMIPlanListView` with `TMIPlanListViewRedesigned`
- [ ] Test Active/Completed tabs
- [ ] Verify search functionality
- [ ] Test progress circle rendering
- [ ] Check model icons and colors
- [ ] Test FAB → New Plan flow

---

## Phase 4: Polish & Testing (Week 4)

### Accessibility Audit
- [ ] Run VoiceOver on all screens
- [ ] Test with largest Dynamic Type size
- [ ] Verify 44pt minimum touch targets
- [ ] Check contrast ratios (use Accessibility Inspector)
- [ ] Test with Reduce Motion enabled
- [ ] Verify keyboard navigation (iPad)

### Performance Testing
- [ ] Profile app with Instruments
- [ ] Check view hierarchy depth
- [ ] Verify smooth 60fps scrolling
- [ ] Test with large datasets (100+ students)
- [ ] Measure cold start time
- [ ] Check memory usage

### Edge Cases
- [ ] Test with no internet (offline mode)
- [ ] Test with empty Firebase data
- [ ] Test with very long student names
- [ ] Test with special characters
- [ ] Verify date edge cases (leap years, etc.)
- [ ] Test rapid navigation (prevent crashes)

### User Testing
- [ ] Conduct hallway usability test (5 users)
- [ ] Time task completion:
  - [ ] Add Student (target: ≤30s)
  - [ ] Create Plan (target: ≤60s)
  - [ ] Find Student (target: ≤10s)
- [ ] Collect qualitative feedback
- [ ] Identify pain points
- [ ] Document requested features

---

## Phase 5: Deployment Prep

### Code Cleanup
- [ ] Remove deprecated components:
  - [ ] Delete `TMIGlassCard` if unused
  - [ ] Delete `TMIParticleEffect`
  - [ ] Remove old background views
- [ ] Update all references to new components
- [ ] Remove unused imports
- [ ] Run SwiftLint and fix warnings

### Documentation
- [ ] Update README with new screenshots
- [ ] Document design system in wiki
- [ ] Create component usage guide
- [ ] Update CLAUDE.md with new patterns
- [ ] Add migration notes for team

### Testing
- [ ] Run full test suite
- [ ] Add UI tests for critical flows
- [ ] Test on physical devices:
  - [ ] iPhone SE (small screen)
  - [ ] iPhone 15 Pro (standard)
  - [ ] iPhone 15 Pro Max (large)
  - [ ] iPad (if supported)
- [ ] Test on iOS 17 and iOS 18
- [ ] Verify light/dark mode switching

### Release
- [ ] Create feature branch: `redesign/light-mode`
- [ ] Submit PR with before/after screenshots
- [ ] Request design review
- [ ] Request code review
- [ ] Address feedback
- [ ] Merge to main
- [ ] Tag release: `v2.0.0-redesign`
- [ ] Deploy to TestFlight
- [ ] Monitor crash reports
- [ ] Gather beta feedback

---

## Quick Start (Immediate Testing)

To test the redesign immediately:

1. **Update Dashboard:**
   ```swift
   // In MainTabView.swift
   DashboardViewRedesigned()
       .tabItem {
           Label("Dashboard", systemImage: "chart.bar")
       }
   ```

2. **Update Students:**
   ```swift
   NavigationStack {
       StudentListViewRedesigned()
   }
   .tabItem {
       Label("Students", systemImage: "person.2")
   }
   ```

3. **Update Plans:**
   ```swift
   NavigationStack {
       TMIPlanListViewRedesigned()
   }
   .tabItem {
       Label("Plans", systemImage: "doc.text")
   }
   ```

4. **Build and Run**
   - Set scheme to iPhone 15 Pro
   - Build and run (⌘R)
   - Test in Simulator
   - Toggle Appearance: Dark/Light (⌘⇧A)

---

## Rollback Plan

If issues arise:

1. **Revert Navigation:**
   ```swift
   // Switch back to old views
   DashboardView()
   StudentListView()
   TMIPlanListView()
   ```

2. **Keep New Files:**
   - Don't delete redesigned files
   - Tag commit for reference
   - Document issues found

3. **Iterative Migration:**
   - Migrate one screen at a time
   - Test thoroughly before next screen
   - Use feature flags if needed

---

## Success Criteria

Before marking complete:

- [ ] All screens load without errors
- [ ] No visual glitches or layout issues
- [ ] Accessibility score ≥95% (Xcode Accessibility Inspector)
- [ ] Task completion times meet targets
- [ ] User satisfaction ≥4/5 in testing
- [ ] Zero critical bugs
- [ ] Performance metrics maintained or improved

---

## Notes

- Keep old views intact during migration (append `Legacy` suffix)
- Document any breaking changes
- Update analytics to track new vs. old flows
- Consider A/B testing if gradual rollout is needed

**Estimated Total Time:** 4 weeks (1 engineer)
**Risk Level:** Medium (comprehensive testing required)
**Impact:** High (complete visual overhaul)
