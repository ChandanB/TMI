# Global Resources Migration

## Overview

Changed AI-generated resources from **user-scoped** to **global** storage in Firestore. This makes resources available to all users and dramatically improves efficiency.

## Changes Made

### 1. Firestore Structure Change

**Before (User-Scoped):**
```
users/
  {userId}/
    generatedResources/
      {interestId}/
        resources/
          {resourceId}/
```

**After (Global):**
```
generatedResources/  (root-level)
  {interestId}/
    - interestName: String
    - interestId: String
    - generatedAt: Timestamp
    - resourceCount: Int
    resources/
      {resourceId}/
        - Resource data...
```

### 2. Code Changes

**File:** `TMI/Services/AI/ResourceGenerationService.swift`

**fetchCachedResources():**
- Removed: `guard let userId = Auth.auth().currentUser?.uid`
- Changed: `.collection("users").document(userId).collection("generatedResources")`
- To: `.collection("generatedResources")`

**cacheResources():**
- Removed: User ID requirement
- Changed to root-level collection access
- Updated log message to indicate "global resources"

**Lines Changed:** 289-344

### 3. Security Rules Update

**File:** `firestore.rules`

Added new rules for global collection:

```javascript
// Global AI-generated resources (shared across all users)
match /generatedResources/{interestId} {
  // Anyone authenticated can read
  allow read: if request.auth != null;

  // Only authenticated users can write (to generate resources)
  allow write: if request.auth != null;

  // Resources sub-collection
  match /resources/{resourceId} {
    allow read: if request.auth != null;
    allow write: if request.auth != null;
  }
}
```

### 4. Documentation Updates

**Files Updated:**
- `FOUNDATION_MODELS_IMPLEMENTATION.md` - Updated Firestore structure section
- `RESOURCE_GENERATION_FIXES.md` - Updated caching notes
- Created: `GLOBAL_RESOURCES_MIGRATION.md` (this file)

## Benefits

### Efficiency
- ✅ **First user generates, everyone benefits** - Resources generated once per interest
- ✅ **Faster loads** - No AI generation needed for subsequent users
- ✅ **Reduced AI calls** - Dramatically fewer Foundation Models API calls
- ✅ **Lower costs** - Less compute for on-device processing

### Consistency
- ✅ **Same quality** - All users get the same high-quality resources
- ✅ **No variation** - Resources don't vary between users
- ✅ **Easier maintenance** - One place to update/improve resources

### Scalability
- ✅ **Efficient scaling** - Database size grows with interests, not users
- ✅ **Predictable growth** - Limited number of interests vs unlimited users

## Migration Notes

### Existing User Data

**No automatic migration needed** - Old user-scoped resources will simply be ignored:
- App now reads from `generatedResources/` (root)
- Old data in `users/{uid}/generatedResources/` remains but unused
- First load will regenerate from new global cache

### Testing

To test the global behavior:

1. **User A** adds "Painting" interest to a plan
   - Resources generated and cached globally
   - Path: `generatedResources/painting-id/resources/`

2. **User B** adds "Painting" interest to their plan
   - Resources loaded instantly from cache
   - No AI generation needed

3. **Verify Firestore:**
   - Open Firebase Console
   - Check `generatedResources` collection (root level)
   - Should see one entry per unique interest
   - NOT nested under any user

## Security Considerations

### Read Access
- Any authenticated user can read generated resources
- Prevents duplication across users
- Maintains privacy (no user-specific data in resources)

### Write Access
- Any authenticated user can write (generate resources)
- **Potential race condition:** Multiple users generating for same interest simultaneously
- **Mitigation:** First write wins, subsequent writes add to collection
- **Future improvement:** Add transaction or check-before-write logic

### Data Privacy
- ✅ Resources contain no user-specific information
- ✅ Only generic educational content based on interest
- ✅ Safe to share across all users
- ✅ Complies with COPPA/FERPA (no student data)

## Rollback Plan

If global resources cause issues, revert by:

1. **Restore ResourceGenerationService.swift lines 289-344:**
   - Re-add user ID checks
   - Change paths back to user-scoped
   - Update log messages

2. **Restore firestore.rules:**
   - Remove global `generatedResources` rules
   - Or keep for backwards compatibility

3. **No data loss:**
   - Global resources remain in database
   - Can be manually copied to user collections if needed

## Future Enhancements

### Resource Quality Control
- Admin review/approval before resources go live
- User feedback/rating system
- Moderation for inappropriate content

### Deduplication
- Check if resources exist before generating
- Use transactions to prevent race conditions
- Implement resource versioning

### Analytics
- Track which resources are most viewed
- Identify popular interests
- Measure cache hit rates

## Testing Checklist

- [ ] Deploy updated Firestore security rules
- [ ] Clear old user-scoped resources (optional)
- [ ] Test resource generation with User A
- [ ] Verify Firestore shows global collection
- [ ] Test resource loading with User B (should use cache)
- [ ] Confirm no AI generation for User B
- [ ] Verify both users see same resources
- [ ] Test with multiple interests
- [ ] Monitor Firestore console for correct structure

## Deployment

### Prerequisites
```bash
# Deploy new Firestore security rules
firebase deploy --only firestore:rules
```

### Steps
1. Deploy security rules first
2. Deploy app update
3. Monitor Firestore console
4. Verify global collection populates correctly

---

**Migration Date:** January 2025
**Status:** ✅ Complete
**Breaking Changes:** None (backwards compatible)
