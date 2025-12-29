# Phase 6: District Curation & Legacy Interest Migration

## Overview

Phase 6 completes the unified Interests/Careers/Resources architecture by:
1. Creating district curation models (schema-only for future implementation)
2. Deprecating the legacy `Student.interests` array
3. Providing migration tools and documentation

## What Was Implemented

### 1. District Curation Models (Schema Only)

Created `/TMI/Models/District/DistrictCuration.swift` with four schema-only models for future district content curation features:

#### DistrictInterestCuration
Allows districts to approve/hide global interests:
```swift
struct DistrictInterestCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let interestId: String
    let status: CurationStatus  // approved, hidden, flagged
    let curatedBy: String
    let curatedAt: Date
    let notes: String?
}
```

**Collection Path**: `districts/{districtId}/interestCurations`

#### DistrictCareerCuration
Allows districts to approve/hide/feature global careers:
```swift
struct DistrictCareerCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let careerId: String
    let status: CurationStatus  // approved, hidden, featured, flagged
    let curatedBy: String
    let curatedAt: Date
    let notes: String?
    let priority: Int?  // Optional priority ranking
}
```

**Collection Path**: `districts/{districtId}/careerCurations`

#### DistrictResourceCuration
Allows districts to approve/hide/customize global resources:
```swift
struct DistrictResourceCuration: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let resourceId: String
    let status: CurationStatus  // approved, hidden, featured, required, flagged
    let curatedBy: String
    let curatedAt: Date
    let notes: String?
    let customDescription: String?  // District-specific override
    let requiredForRoles: [String]?  // Optional role requirements
}
```

**Collection Path**: `districts/{districtId}/resourceCurations`

#### DistrictContentPolicy
District-wide content approval policies:
```swift
struct DistrictContentPolicy: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    let districtId: String
    let policyType: PolicyType  // interest_approval, career_approval, resource_approval, ai_content_review
    let setting: PolicySetting  // auto_approve, require_review, moderate_ai
    let updatedBy: String
    let updatedAt: Date
}
```

**Collection Path**: `districts/{districtId}/contentPolicies`

### 2. Student.interests Deprecation

Updated `/TMI/Models/Student.swift` to deprecate the inline interests array:

#### Deprecation Markers
```swift
// DEPRECATED: Use StudentInterestService.getStudentInterests() instead
@available(*, deprecated, message: "Use StudentInterestService.getStudentInterests(studentId:) to fetch interests from edge collection")
var interests: [Interest]

@available(*, deprecated, message: "Use StudentInterestService.getStudentInterests(studentId:) and extract categories from the result")
var primaryInterestCategories: [InterestCategory] { ... }
```

#### Firestore Write Behavior
```swift
// toFirestoreData() now writes empty array for backward compatibility
data["interests"] = []  // No longer stores interests inline
```

### 3. Migration Tools

#### Student+InterestMigration.swift
Created helper extension with migration-friendly methods:

```swift
// Fetch interests from edge collection
func fetchInterestsFromEdgeCollection() async throws -> [Interest]

// Lightweight queries
func getInterestCount() async throws -> Int
func hasInterest(interestId: String) async throws -> Bool

// CRUD operations
func addInterest(_ interest: Interest, level: Int = 3) async throws
func removeInterest(interestId: String) async throws

// Advanced queries
func getHighAffinityInterests() async throws -> [StudentInterest]
func fetchInterestCategories() async throws -> [InterestCategory]
```

#### INTEREST_MIGRATION_GUIDE.md
Comprehensive migration documentation including:

- **Architecture Benefits**: Single source of truth, scope-based filtering, efficient queries
- **Migration Patterns**: 5 common patterns with before/after examples
- **Service Updates**: List of 5 services requiring updates
- **View Updates**: List of 10 views requiring updates
- **Testing Strategy**: Unit, integration, UI, and data migration tests
- **Deprecation Timeline**: Phased approach (Phase 6 → 7 → 8)

### 4. Bug Fixes

Fixed closure capture semantics errors:

**CareerLibraryService.swift:55**
```swift
// Before:
try await globalCollection.getDocuments()

// After:
try await self.globalCollection.getDocuments()
```

**InterestLibraryService.swift:58**
```swift
// Before:
try await globalCollection.getDocuments()

// After:
try await self.globalCollection.getDocuments()
```

## Architecture Benefits

### Single Source of Truth
- **Global Libraries**: Canonical definitions in `interests/{id}`, `careers/{id}`, `resources/{id}`
- **Edge Collections**: Lightweight relationships in `students/{studentId}/studentInterests/{interestId}`
- **No Duplication**: Interest details stored once, referenced by ID

### Backward Compatibility
- Deprecated fields still work for existing code
- New writes don't save inline interests (writes empty array)
- Migration can proceed incrementally

### Future District Features
- Schema-only models allow future implementation without breaking changes
- Clear curation workflow: approved → hidden → featured → required → flagged
- District-specific policies: auto-approve, require review, moderate AI content

## Files Modified

1. `/TMI/Models/Student.swift` - Deprecated interests field
2. `/TMI/Services/Library/CareerLibraryService.swift` - Fixed closure capture
3. `/TMI/Services/Library/InterestLibraryService.swift` - Fixed closure capture

## Files Created

1. `/TMI/Models/District/DistrictCuration.swift` - District curation schemas
2. `/TMI/Models/Student+InterestMigration.swift` - Migration helper extension
3. `/INTEREST_MIGRATION_GUIDE.md` - Comprehensive migration documentation
4. `/PHASE_6_SUMMARY.md` - This file

## Migration Impact

### Affected Services (5)
1. **StudentService** - Lines 123, 137, 498, 520
2. **AICareerGenerator** - Lines 60, 557, 689
3. **AIPromptBuilder** - Lines 81, 138, 222, 241, 262
4. **StudentInterestSynchronizer** - Lines 129, 130
5. **CareerService** - Lines 155, 246, 509, 565

### Affected Views (10+)
1. **StudentInterestProfileView** - Lines 100, 120, 143, 419
2. **InterestDetailView** - Lines 686, 891, 896
3. **NewTMIPlanView** - Lines 32, 34, 69, 136, 307
4. **AddInterestToStudentView** - Lines 32, 37, 172, 173
5. **StudentProgressView** - Line 100
6. **EditStudentView** - Line 639
7. **StudentListView** - Line 288
8. **RecommendationsView** - Lines 107, 111
9. **StudentModeView** - Lines 285, 399, 401
10. **StudentInterestDetailView** - Line 176

## Next Steps

### Phase 7: View Migration
Migrate all views to use the new edge-based architecture:
1. Update views with deprecation warnings
2. Replace `student.interests` with `student.fetchInterestsFromEdgeCollection()`
3. Use lightweight queries where possible (count, hasInterest)
4. Test thoroughly with sample data

### Phase 8: Service Migration
Migrate all services to use edge collections:
1. Update AIPromptBuilder to fetch interests via StudentInterestService
2. Update AICareerGenerator to use edge collections
3. Update CareerService interest matching logic
4. Update StudentInterestSynchronizer to sync edge data

### Phase 9: Final Cleanup
Remove deprecated fields entirely:
1. Remove `Student.interests` field
2. Remove `Student.primaryInterestCategories` computed property
3. Remove backward compatibility code
4. Archive migration helpers

## Testing Recommendations

### Unit Tests
```swift
func testFetchInterestsFromEdgeCollection() async throws {
    let student = Student(...)
    let interests = try await student.fetchInterestsFromEdgeCollection()
    XCTAssertGreaterThan(interests.count, 0)
}
```

### Integration Tests
```swift
func testAddInterestCreatesEdge() async throws {
    let student = Student(...)
    let interest = Interest(...)
    try await student.addInterest(interest, level: 4)

    let hasInterest = try await student.hasInterest(interestId: interest.id!)
    XCTAssertTrue(hasInterest)
}
```

### Data Migration Script
```swift
// Pseudo-code for migration script
func migrateInlineInterestsToEdges() async throws {
    let students = try await studentService.fetchAllStudents()

    for student in students {
        guard let studentId = student.id else { continue }

        // For each inline interest, create edge
        for interest in student.interests {
            guard let interestId = interest.id else { continue }

            // Check if edge already exists
            let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
            if edges.contains(where: { $0.interestId == interestId }) {
                continue  // Skip if already migrated
            }

            // Create edge
            try await StudentInterestService.shared.addInterest(
                studentId: studentId,
                interestId: interestId,
                level: 3  // Default level
            )
        }

        // Clear inline interests (optional, can be done in Phase 9)
        // var updatedStudent = student
        // updatedStudent.interests = []
        // try await studentService.updateStudent(updatedStudent)
    }
}
```

## District Curation Future Implementation

When implementing district curation features:

1. **Create DistrictCurationService**
   - CRUD operations for curation records
   - Bulk approve/hide operations
   - Policy management

2. **Create District Admin UI**
   - Content review dashboard
   - Curation status filters
   - Bulk actions interface

3. **Update Library Services**
   - Filter by district curation status
   - Apply district policies
   - Handle required resources

4. **Update Firestore Rules**
   ```javascript
   match /districts/{districtId}/interestCurations/{curationId} {
     allow read: if isAuthenticated();
     allow write: if isDistrictAdmin(districtId);
   }
   ```

## Summary

Phase 6 successfully:
- ✅ Created district curation schema models
- ✅ Deprecated Student.interests array
- ✅ Provided comprehensive migration tools
- ✅ Fixed closure capture semantics errors
- ✅ Maintained backward compatibility

The TMI app now has a complete foundation for the unified architecture with clear migration path forward.
