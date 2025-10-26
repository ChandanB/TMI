# Foundation Models Implementation Guide

## Overview

This document explains the AI-powered resource generation feature using Apple's on-device Foundation Models in TMI.

## Architecture

### Components

1. **ResourceGenerationService** (`Services/AI/ResourceGenerationService.swift`)
   - Actor-based service for thread-safe AI operations
   - Manages `LanguageModelSession` for on-device generation
   - Handles Firestore caching of generated resources

2. **TMIPlanDetailView** (Updated)
   - Displays AI-generated resources in the "Personalized Resources" section
   - Shows loading state during generation
   - Falls back to quality default resources if AI unavailable

3. **AIGeneratedResourceCard** (New Component)
   - Custom SwiftUI view for displaying AI-generated resources
   - Features sparkles badge indicating AI generation
   - Clickable resource links that open in browser

## How It Works

### 1. Resource Generation Flow

```
TMIPlanDetailView opens
    ↓
.task { await generateResourcesForInterests() }
    ↓
Check if Foundation Models available (iOS 26+)
    ↓
For each interest in plan:
    ├─ Check Firestore cache
    ├─ If cached: Load from database
    └─ If not cached:
        ├─ Build context-aware prompt
        ├─ Generate with LanguageModelSession
        ├─ Parse AI response into Resources
        └─ Upload to Firestore
    ↓
Display in AIGeneratedResourceCard
```

### 2. API Usage

#### Guided Generation with @Generable Macro

The service uses Apple's @Generable macro for type-safe, structured output:

```swift
// Define the structure with @Generable macro
// IMPORTANT: All nested types must also be marked @Generable
@Generable
struct GeneratedResourceList {
    @Generable
    struct ResourceItem {
        let title: String
        let type: String
        let url: String
        let description: String
        let tags: [String]
    }
    let resources: [ResourceItem]
}

// Initialize session
let session = try await LanguageModelSession()

// Generate structured data - returns Response<GeneratedResourceList>
let response = try await session.respond(to: prompt, generating: GeneratedResourceList.self)

// Access the generated content from the response
let data = response.content

// Use the typed data
for resource in data.resources {
    print(resource.title)
    print(resource.url)
}
```

#### Key APIs Used

- `LanguageModelSession()` - Creates on-device language model session
- `@Generable` macro - Defines the structure for AI output
- `session.respond(to:generating:)` - Generates typed data directly
- No manual parsing required - type-safe output

### 3. Prompt Engineering

The service builds detailed prompts including:

```swift
"""
Generate 3 high-quality educational resources for a student interested in \(interest.name).

Context:
- Student: \(studentName) (Grade: \(grade))
- Interest: \(interest.name)
- Description: \(interest.description)
- TMI Model: \(modelType)
- Academic Relevance: \(academicSubjects)

Requirements:
- Age-appropriate for grade \(grade)
- Mix of article, video, and interactive content
- Connect interest to academic learning
- Real, accessible URLs (Khan Academy, PBS, National Geographic)
- Engaging titles and descriptions

Format each resource as:
RESOURCE 1:
Title: [Engaging title]
Type: [article/video/interactiveContent]
URL: [Real URL]
Description: [What they'll learn]
Tags: [3-4 relevant tags]
"""
```

### 4. Firestore Caching Structure (Global)

```
generatedResources/  (root-level collection)
  {interestId}/
    - interestName: String
    - interestId: String
    - generatedAt: Timestamp
    - resourceCount: Int
    resources/
      {resourceId}/
        - title: String
        - description: String
        - category: String
        - url: String
        - tags: [String]
        - createdAt: Timestamp
        - updatedAt: Timestamp
        - recommendedFor: [String]
```

**Benefits:**
- Resources generated once per interest globally
- Shared across ALL users for the same interest
- Dramatically reduces AI generation calls
- Fast loads for all users after first generation
- Consistent resource quality across all users

## iOS Version Compatibility

### iOS 26+ (Foundation Models Available)

```swift
if #available(iOS 26.0, *) {
    let service = ResourceGenerationService.shared
    if await service.checkAvailability() {
        // Use AI generation
        let resources = try await service.generateResources(for: interest, plan: plan)
    } else {
        // Use fallback
        generateFallbackResources()
    }
}
```

### iOS < 26 (Fallback Resources)

High-quality fallback resources are provided:

```swift
[
    Resource(
        title: "Exploring \(interest.name): Beginner's Guide",
        category: .article,
        url: "https://www.khanacademy.org",
        tags: [interest.name, "beginner", "guide"]
    ),
    Resource(
        title: "Career Paths in \(interest.name)",
        category: .video,
        url: "https://www.pbs.org/education",
        tags: [interest.name, "career", "exploration"]
    ),
    Resource(
        title: "\(interest.name) Interactive Activities",
        category: .interactiveContent,
        url: "https://www.nationalgeographic.org/education",
        tags: [interest.name, "interactive", "activities"]
    )
]
```

## Privacy & Safety

### On-Device Processing

✅ **All AI generation happens on-device**
- No data sent to external servers
- Complies with COPPA/FERPA requirements
- Student data never leaves the device

### Content Safety

✅ **Built-in safety features**
- Foundation Models include content filtering
- Age-appropriate prompts
- Educational domain URLs only
- Reviewed output parsing

### Data Storage

✅ **Global resource storage**
- All resources stored in root-level Firestore collection
- Shared across all users for efficiency
- One generation per interest benefits all users
- Firestore security rules control write access (educators only)

## UI/UX Features

### Loading States

```swift
if isGeneratingResources {
    VStack {
        ProgressView().tint(.tmiSuccess)
        Text("Generating personalized resources...")
    }
}
```

### AI Badge

Resources display a sparkles badge:

```swift
HStack(spacing: 4) {
    Image(systemName: "sparkles")
    Text("AI")
}
.foregroundColor(.tmiPrimary)
```

### Clickable Resources

Each resource opens its URL when tapped:

```swift
.onTapGesture {
    if let url = URL(string: resource.url) {
        UIApplication.shared.open(url)
    }
}
```

## Error Handling

### Graceful Degradation

1. **Foundation Models unavailable** → Use fallback resources
2. **Generation fails for one interest** → Use fallback for that interest only
3. **Parsing fails** → Return empty array, fallback used
4. **Firestore upload fails** → Resources still displayed, just not cached

### User Experience

- **No error dialogs** - Users never see errors
- **Always get resources** - Either AI or fallback
- **Consistent UI** - Same card design for AI and fallback

## Performance Optimization

### Context Window Management

According to [TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window):

- Reuse `LanguageModelSession` across multiple generations
- Keep prompts concise (< 1024 tokens)
- Clear context when switching between unrelated topics

**Implementation:**

```swift
// Session persists in actor
private var languageModelSession: LanguageModelSession?

// Reused across multiple interest generations
if languageModelSession == nil {
    languageModelSession = try await LanguageModelSession()
}
```

### Caching Strategy

- **First view**: Generate resources (3-5 seconds)
- **Subsequent views**: Load from Firestore (< 1 second)
- **Shared interests**: Multiple plans reuse same resources

## Testing

### Manual Testing Checklist

- [ ] Create TMI Plan with 3+ interests
- [ ] Verify loading indicator appears
- [ ] Confirm AI badge shows on generated resources
- [ ] Tap resources to verify URLs open
- [ ] Close and reopen plan (verify cached load)
- [ ] Test on iOS 25 (verify fallback)
- [ ] Test with no internet (verify on-device generation still works)

### Expected Behavior

| Scenario | Expected Result |
|----------|----------------|
| iOS 26 + Foundation Models | AI-generated resources with sparkles badge |
| iOS 26 without Foundation Models | Fallback resources, no badge |
| iOS < 26 | Fallback resources, no badge |
| No interests in plan | "Add student interests..." message |
| Generation error | Fallback resources displayed |
| Cached resources exist | Instant load, no generation |

## Future Enhancements

### Planned

1. **Resource Rating System**
   - Let educators rate AI-generated resources
   - Use ratings to improve future prompts

2. **Custom Resource Addition**
   - Manual resource entry alongside AI
   - Educator-curated content

3. **Regenerate Button**
   - Allow refresh with updated models
   - "Try again" for better results

4. **Analytics**
   - Track which resources get clicked
   - Measure engagement

5. **Batch Generation**
   - Pre-generate on plan creation
   - Background processing

### Advanced

1. **Tool Calling**
   - Use Foundation Models tool calling to fetch real-time data
   - Verify URL validity before returning

2. **Enhanced Guided Generation**
   - Use @Guide macro for field-level instructions
   - Add validation constraints to @Generable structs
   - Stream responses with streamResponse(to:generating:)

3. **Multi-turn Conversations**
   - Refine resources based on feedback
   - Iterative improvement

## Troubleshooting

### "Foundation Models not available"

**Causes:**
- Running on simulator (not supported)
- iOS version < 26
- Device doesn't support Foundation Models

**Solution:**
- Test on physical device with iOS 26+
- Fallback will be used automatically

### Resources not generating

**Debug steps:**
1. Check console for `[ResourceGeneration]` logs
2. Verify `checkAvailability()` returns true
3. Ensure interests have valid IDs
4. Check Firestore permissions

### Parsing errors

**Symptoms:**
- Empty resource arrays
- Fallback always used

**Debug:**
1. Print raw AI response
2. Verify prompt format
3. Check parsing logic in `parseResourceResponse`

## References

- [FoundationModels Framework](https://developer.apple.com/documentation/foundationmodels)
- [LanguageModelSession](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession)
- [Generable Macro](https://developer.apple.com/documentation/foundationmodels/generable)
- [Generating Swift Data Structures with Guided Generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [GenerationOptions](https://developer.apple.com/documentation/FoundationModels/GenerationOptions)
- [TN3193: Managing Context Window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)

## Support

For issues or questions:
1. Check console logs with `[ResourceGeneration]` prefix
2. Verify iOS version and device capabilities
3. Test fallback path works correctly
4. Review Firestore security rules

---

**Last Updated:** January 2025
**iOS Version:** 26.0+
**Status:** ✅ Production Ready
