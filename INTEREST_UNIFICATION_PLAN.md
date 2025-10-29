# Interest Management Unification Plan

## Current Problem

There are two separate flows for adding interests to students:

### 1. **Survey Flow** (StudentSurveyFlow → SurveyService)
- Uses InterestClusters from survey responses
- Converts clusters to basic Interest objects
- Saves to student document: `interests: interests.map { $0.toFirestoreData() }`
- **Location**: Line 340 in SurveyService.swift

### 2. **Manual Add Flow** (AddInterestToStudentView → StudentService)
- Uses PredefinedInterestsData with full Interest objects
- Directly appends to student.interests array
- Updates student document with complete Interest data
- **Location**: Lines 210-256 in AddInterestToStudentView.swift

## Issues

1. **Different Data Sources**:
   - Survey creates minimal Interest objects from clusters
   - Manual add uses rich PredefinedInterests with academic relevance, skills, pathways

2. **No Integration**:
   - Survey results don't use predefined interests database
   - Manual additions don't reference survey responses
   - Students can't easily add interests that complement survey results

3. **Duplication Risk**:
   - Same interest could be added twice (once from survey, once manually)
   - No deduplication logic

## Solution: Unified Interest Management

### Phase 1: Use Predefined Interests Everywhere ✅

**Change Survey Flow**:
```swift
// In SurveyService.swift line 461
private func convertClustersToInterests(_ clusters: [InterestCluster]) -> [Interest] {
    return clusters.compactMap { cluster in
        // NEW: Look up predefined interest by matching cluster name
        let predefinedInterest = PredefinedInterestsData.allPredefinedInterests.first { interest in
            interest.name.lowercased() == cluster.displayName.lowercased() ||
            interest.category.contains(where: { $0.rawValue.lowercased() == cluster.name.lowercased() })
        }

        if let existing = predefinedInterest {
            // Use full predefined interest data
            return existing
        } else {
            // Fallback: create basic interest (current behavior)
            return Interest(id: cluster.id.uuidString, name: cluster.displayName, ...)
        }
    }
}
```

**Benefits**:
- Survey results now include academic relevance, skills, career pathways
- Consistent data structure across both flows
- Rich interest data from day one

### Phase 2: Deduplication Logic ✅

**Add to StudentService**:
```swift
func addInterests(_ newInterests: [Interest], to student: Student) async throws -> Student {
    // Get existing interest IDs
    let existingIds = Set(student.interests.compactMap { $0.id })

    // Filter out duplicates
    let uniqueNewInterests = newInterests.filter { interest in
        !existingIds.contains(interest.id)
    }

    // Combine and save
    var updatedInterests = student.interests
    updatedInterests.append(contentsOf: uniqueNewInterests)

    let updatedStudent = student.copy(interests: updatedInterests)
    return try await updateStudent(updatedStudent)
}
```

**Benefits**:
- No duplicate interests
- Works for both survey and manual additions
- Maintains data integrity

### Phase 3: UI Integration ✅

**Enhance AddInterestToStudentView**:

Add section showing survey-based interests:
```swift
if !student.surveyResults.isEmpty {
    VStack {
        Text("From Your Survey")
        ForEach(surveyBasedInterests) { interest in
            InterestRow(interest: interest, badge: "Survey")
        }
    }

    Divider()

    Text("Add More Interests")
    // Existing manual add UI
}
```

**Enhance SurveyResultsView**:

Add "Add More Interests" button:
```swift
Button("Add More Interests") {
    showingAddInterests = true
}
.sheet(isPresented: $showingAddInterests) {
    AddInterestToStudentView(student: student) { updated in
        // Refresh view
    }
}
```

**Benefits**:
- Students see interests from both sources
- Easy to complement survey with manual additions
- Clear visual distinction

### Phase 4: Retake Survey Flow ✅

**Add to StudentDetailView**:
```swift
if student.hasSurveyResults {
    Button("Retake Interest Survey") {
        showRetakeConfirmation = true
    }
    .alert("Retake Survey?", isPresented: $showRetakeConfirmation) {
        Button("Cancel", role: .cancel) { }
        Button("Retake", role: .destructive) {
            // Clear survey-based interests, keep manual ones
            retakeSurvey()
        }
    }
}
```

**Benefits**:
- Students can update interests as they grow
- Preserves manually added interests
- Fresh start when needed

## Implementation Order

1. ✅ **Update `convertClustersToInterests()`** - Use predefined database
2. ✅ **Add deduplication** to StudentService
3. ✅ **Update AddInterestToStudentView** - Show survey vs manual
4. ✅ **Add "Add More"** button to SurveyResultsView
5. ✅ **Add "Retake Survey"** option to StudentDetailView

## Database Schema (No Changes Needed!)

Student document remains the same:
```json
{
  "interests": [
    {
      "id": "uuid",
      "name": "Basketball",
      "category": ["sports"],
      "academicRelevance": ["physicalEducation"],
      "skillsDeveloped": ["teamwork", "discipline"],
      ...
    }
  ]
}
```

The only change is ensuring ALL interests come from the predefined database, whether added via survey or manually.

## Testing Plan

1. **Test Survey Flow**:
   - Complete survey with various interests
   - Verify predefined interest data is saved
   - Check academic relevance, skills, pathways appear

2. **Test Manual Add**:
   - Add interest manually
   - Verify no duplication with survey interests
   - Confirm data structure matches

3. **Test Retake**:
   - Complete survey
   - Add manual interests
   - Retake survey
   - Verify manual interests preserved

## Benefits Summary

✅ **Single Source of Truth**: PredefinedInterestsData for all interests
✅ **Rich Data**: Academic relevance and career pathways from day one
✅ **No Duplicates**: Automatic deduplication
✅ **Flexible**: Survey + manual additions work together
✅ **User Control**: Retake survey while preserving manual additions
✅ **Consistent UX**: Same interest cards everywhere
