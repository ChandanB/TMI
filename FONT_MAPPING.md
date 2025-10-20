# Font Mapping Reference

## Redesign → Existing Fonts

Use these existing fonts from `FontConstants.swift` instead of the redesign names:

### In Redesigned Views, Replace:

```swift
// OLD (Redesign)          →  NEW (Existing)
.font(.tmiTitle1)          →  .font(.tmiHeadlineLarge)  // 28pt bold
.font(.tmiTitle2)          →  .font(.tmiHeadlineMedium) // 22pt semibold
.font(.tmiTitle3)          →  .font(.tmiHeadlineSmall)  // 18pt semibold
.font(.tmiBody)            →  .font(.tmiBody)           // 16pt (exists)
.font(.tmiBodyBold)        →  .font(.tmiBody).bold()
.font(.tmiCaption)         →  .font(.tmiCaption)        // 12pt (exists)
.font(.tmiFootnote)        →  .font(.tmiCaptionSmall)   // 10pt
```

### Quick Fix Commands:

Run these find-replace operations in redesigned view files:

1. `.font(.tmiTitle1)` → `.font(.tmiHeadlineLarge)`
2. `.font(.tmiTitle2)` → `.font(.tmiHeadlineMedium)`
3. `.font(.tmiTitle3)` → `.font(.tmiHeadlineSmall)`
4. `.font(.tmiBodyBold)` → `.font(.tmiBody).weight(.semibold)`
5. `.font(.tmiFootnote)` → `.font(.tmiCaptionSmall)`
