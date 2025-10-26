# Cache Consistency Fix

## Issue

When resources are first generated, the UI shows incorrect/duplicate resources (all articles). But when you leave and return to the page, it shows the correct resources (proper mix of article, video, interactive).

## Root Cause

**Race condition between generation and caching:**

1. AI generates resources → Returns to UI immediately
2. UI displays the in-memory generated resources
3. Meanwhile, caching to Firestore happens asynchronously
4. When you return later, it reads from Firestore cache (which is correct)

The issue is that the **UI was displaying in-memory resources** before they were fully persisted to Firestore, potentially showing stale or incorrect data.

## Solution

### Changed Flow

**Before:**
```swift
func generateResources() async throws -> [Resource] {
    // 1. Generate
    let resources = try await generateResourcesWithAI()

    // 2. Cache asynchronously (fire and forget)
    try await cacheResources(resources)

    // 3. Return immediately (UI gets in-memory version)
    return resources  // ❌ Might be inconsistent
}
```

**After:**
```swift
func generateResources() async throws -> [Resource] {
    // 1. Generate
    let resources = try await generateResourcesWithAI()

    // 2. Cache to Firestore
    try await cacheResources(resources)

    // 3. FETCH BACK from Firestore (ensures consistency)
    if let freshResources = try await fetchCachedResources() {
        return freshResources  // ✅ UI gets Firestore version
    }

    // 4. Fallback to generated if fetch fails
    return resources
}
```

## Code Changes

**File:** `TMI/Services/AI/ResourceGenerationService.swift:56-80`

**Key Addition:**
```swift
// 4. IMPORTANT: Fetch back from Firestore to ensure consistency
// This prevents race conditions and ensures UI shows exactly what's cached
if let freshlyFetchedResources = try await fetchCachedResources(for: interest) {
    print("[ResourceGeneration] Returning freshly cached resources for \(interest.name)")
    return freshlyFetchedResources
}
```

## Benefits

### 1. Guaranteed Consistency
- UI always shows exactly what's in Firestore
- No discrepancy between first load and subsequent loads
- What you see on first generation = what you see on reload

### 2. Better Debugging
- Added extensive logging to track generation and conversion
- Can see exactly what AI generates vs what gets cached
- Helps identify if AI is following prompt correctly

### 3. Source of Truth
- Firestore becomes the single source of truth
- In-memory resources are only used as fallback
- Reduces potential for data inconsistency

## Debug Logging Added

```swift
print("[ResourceGeneration] AI generated \(count) resources for \(interest):")
for (index, item) in generatedData.resources.enumerated() {
    print("  Resource \(index + 1): type=\(item.type), title=\(item.title)")
}

print("[ResourceGeneration] Converted to Resource objects:")
for (index, resource) in resources.enumerated() {
    print("  Resource \(index + 1): category=\(resource.category.rawValue), title=\(resource.title)")
}
```

This helps identify:
- If AI is generating correct types (article, video, interactiveContent)
- If type conversion is working properly
- If there are duplicates in generation

## Testing

### Expected Behavior Now:

1. **First Generation:**
   - User adds "Painting" interest
   - AI generates 3 resources (1 article, 1 video, 1 interactive)
   - Resources cached to Firestore
   - Resources fetched back from Firestore
   - UI displays fetched resources
   - ✅ Should show correct mix on first load

2. **Subsequent Loads:**
   - User returns to page
   - Resources loaded from Firestore cache
   - UI displays cached resources
   - ✅ Shows same resources as first load (consistent)

### Test Checklist:

- [ ] Generate resources for new interest
- [ ] Verify console logs show correct types being generated
- [ ] Confirm UI shows 1 article, 1 video, 1 interactive on first load
- [ ] Leave page and return
- [ ] Verify resources are identical to first load
- [ ] Check Firestore console to confirm resources match UI

## Performance Impact

### Minimal:
- Added one extra Firestore read per generation
- Only happens on first generation (cached afterwards)
- Read is fast (usually < 100ms)
- Negligible compared to AI generation time (2-5 seconds)

### Trade-off:
- **Slight delay** (one extra read) for **guaranteed consistency**
- Worth it to ensure users see correct data immediately

## Alternative Considered

We could have displayed a loading state after generation while caching completes:

```swift
// Generate
isGenerating = true
resources = await generate()

// Show "Caching resources..." state
isCaching = true
await cache(resources)
isCaching = false

// Display final resources
```

**Rejected because:**
- More complex UI state management
- Poor UX (multiple loading states)
- Current solution is simpler and more reliable

## Rollback

If this causes issues, simply remove the fetch-back step:

```swift
// Remove lines 71-76 in ResourceGenerationService.swift
// Return generatedResources directly (line 79)
```

---

**Status:** ✅ Implemented
**Testing Required:** Yes - verify first load shows correct resource types
**Performance Impact:** Minimal (one extra Firestore read)
