# Student Interest Migration Guide

## Overview

As of Phase 6, the TMI app has migrated from storing student interests as an inline array (`Student.interests`) to a modern edge-based architecture using dedicated services and global libraries.

## What Changed?

### Before (Deprecated)
```swift
// ❌ Old pattern - DO NOT USE
let student = try await studentService.getStudent(by: studentId)
let interests = student.interests  // Deprecated field
```

### After (Current)
```swift
// ✅ New pattern - USE THIS
let studentInterestEdges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)

// Resolve to full Interest objects from global library
let interests = try await withThrowingTaskGroup(of: Interest?.self) { group in
    for edge in studentInterestEdges {
        group.addTask {
            try? await InterestLibraryService.shared.fetchInterest(id: edge.interestId)
        }
    }

    var results: [Interest] = []
    for try await interest in group {
        if let interest = interest {
            results.append(interest)
        }
    }
    return results
}
```

## Architecture Benefits

### Single Source of Truth
- **Global Library**: Canonical interest definitions in `interests/{id}` collection
- **Edge Collections**: Lightweight relationship data in `students/{studentId}/studentInterests/{interestId}`
- **No Duplication**: Interest details stored once, referenced by ID

### Better Data Management
- **Scope-based Filtering**: Global, district, and personal interests
- **Centralized Updates**: Update interest once, affects all references
- **Efficient Queries**: Fetch only what you need (IDs vs full objects)

## Migration Patterns

### Pattern 1: Display Student Interest Count

**Before:**
```swift
Text("\(student.interests.count) interests")
```

**After:**
```swift
@State private var interestCount = 0

// In task or onAppear:
let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
interestCount = edges.count

Text("\(interestCount) interests")
```

### Pattern 2: Display Interest Names

**Before:**
```swift
ForEach(student.interests) { interest in
    Text(interest.name)
}
```

**After:**
```swift
@State private var interests: [Interest] = []

// In task:
let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
let resolved = try await resolveInterests(from: edges)
interests = resolved

ForEach(interests) { interest in
    Text(interest.name)
}

// Helper function:
func resolveInterests(from edges: [StudentInterest]) async throws -> [Interest] {
    try await withThrowingTaskGroup(of: Interest?.self) { group in
        for edge in edges {
            group.addTask {
                try? await InterestLibraryService.shared.fetchInterest(id: edge.interestId)
            }
        }

        var results: [Interest] = []
        for try await interest in group {
            if let interest = interest {
                results.append(interest)
            }
        }
        return results
    }
}
```

### Pattern 3: Add Interest to Student

**Before:**
```swift
var updatedStudent = student
updatedStudent.interests.append(newInterest)
try await studentService.updateStudent(updatedStudent)
```

**After:**
```swift
// First ensure interest exists in global library
let savedInterest = try await InterestLibraryService.shared.saveInterest(newInterest)

// Then create edge relationship
try await StudentInterestService.shared.addInterest(
    studentId: studentId,
    interestId: savedInterest.id!,
    level: 3
)
```

### Pattern 4: Remove Interest from Student

**Before:**
```swift
var updatedStudent = student
updatedStudent.interests.removeAll { $0.id == interestId }
try await studentService.updateStudent(updatedStudent)
```

**After:**
```swift
try await StudentInterestService.shared.removeInterest(
    studentId: studentId,
    interestId: interestId
)
```

### Pattern 5: Check if Student Has Interest

**Before:**
```swift
let hasInterest = student.interests.contains { $0.id == interestId }
```

**After:**
```swift
let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
let hasInterest = edges.contains { $0.interestId == interestId }
```

## AI Service Migration

### AIPromptBuilder

**Before:**
```swift
- Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
```

**After:**
```swift
// Add helper method to fetch and format
private func formatStudentInterests(_ studentId: String) async -> String {
    guard let edges = try? await StudentInterestService.shared.getStudentInterests(studentId: studentId) else {
        return "No interests recorded"
    }

    let interests = try? await resolveInterests(from: edges)
    return interests?.map { $0.name }.joined(separator: ", ") ?? "No interests"
}

// In prompt:
let interestsText = await formatStudentInterests(student.id!)
- Interests: \(interestsText)
```

### AICareerGenerator

**Before:**
```swift
let queries = student.interests.map { $0.name }
```

**After:**
```swift
let edges = try await StudentInterestService.shared.getStudentInterests(studentId: student.id!)
let interests = try await resolveInterests(from: edges)
let queries = interests.map { $0.name }
```

## Services Affected

The following services need updates:

1. **StudentService** ✅ (Lines 123, 137, 498, 520)
2. **AICareerGenerator** (Lines 60, 557, 689)
3. **AIPromptBuilder** (Lines 81, 138, 222, 241, 262)
4. **StudentInterestSynchronizer** (Lines 129, 130)
5. **CareerService** (Lines 155, 246, 509, 565)

## Views Affected

The following views need updates:

1. **StudentInterestProfileView** (Lines 100, 120, 143, 419)
2. **InterestDetailView** (Lines 686, 891, 896)
3. **NewTMIPlanView** (Lines 32, 34, 69, 136, 307)
4. **AddInterestToStudentView** (Lines 32, 37, 172, 173)
5. **StudentProgressView** (Line 100)
6. **EditStudentView** (Line 639)
7. **StudentListView** (Line 288)
8. **RecommendationsView** (Lines 107, 111)
9. **StudentModeView** (Lines 285, 399, 401)
10. **StudentInterestDetailView** (Line 176)

## Deprecation Timeline

- **Phase 6 (Current)**: `Student.interests` marked as deprecated, still functional
- **Phase 7 (Next)**: Views migrated to use StudentInterestService
- **Phase 8 (Future)**: `Student.interests` field removed entirely

## Testing Strategy

When migrating code:

1. **Unit Tests**: Test with StudentInterestService directly
2. **Integration Tests**: Verify data flows through edge collections
3. **UI Tests**: Ensure views display interests correctly
4. **Data Migration**: Write script to migrate existing inline interests to edge collections

## Backward Compatibility

The `Student.interests` field is maintained during migration:

- **Reading**: Still works for existing code
- **Writing**: `toFirestoreData()` now writes empty array
- **New Data**: All new interest relationships use edge collections

## Questions?

For implementation questions or migration support, refer to:
- `TMI/Services/StudentData/StudentInterestService.swift`
- `TMI/Services/Library/InterestLibraryService.swift`
- `TMI/Models/Edges/StudentInterest.swift`
