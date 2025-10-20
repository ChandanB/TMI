# Swift Coding Standards & Error Prevention Guide

**Project**: TMI (Tangible Modification Intervention)
**Last Updated**: January 2025
**Purpose**: Prevent common Swift compilation errors and maintain code quality

> **IMPORTANT**: All AI assistants and developers MUST review this document before writing any code for this project.

---

## Table of Contents
1. [Closure Capture Semantics](#1-closure-capture-semantics)
2. [Concurrency and Swift 6](#2-concurrency-and-swift-6)
3. [SwiftUI Best Practices](#3-swiftui-best-practices)
4. [Firebase Integration](#4-firebase-integration)
5. [Error Handling](#5-error-handling)
6. [Memory Management](#6-memory-management)
7. [Type Safety](#7-type-safety)

---

## 1. Closure Capture Semantics

### ❌ Error: Implicit capture in closures
```swift
// WRONG - Will cause: "Reference to property 'service' in closure requires explicit use of 'self'"
let result = try await withTimeout(seconds: 10) {
    try await service.fetch()
}
```

### ✅ Solution: Always use explicit `self` in closures
```swift
// CORRECT
let result = try await withTimeout(seconds: 10) {
    try await self.service.fetch()
}
```

### Rule:
- **ALWAYS** use explicit `self.` when referencing instance properties or methods inside closures
- This applies to all closure types: `@escaping`, `@Sendable`, trailing closures, etc.
- Even if the compiler doesn't initially complain, always be explicit for future Swift 6 compatibility

### Common locations where this occurs:
- Task closures: `Task { ... }`
- Async operation wrappers: `withTimeout { ... }`, `withThrowingTaskGroup { ... }`
- Button actions: `Button(action: { ... })`
- Animation blocks: `withAnimation { ... }`
- Map/filter/reduce operations on collections

---

## 2. Concurrency and Swift 6

### Actor Isolation Rules

#### ❌ Error: Non-isolated access to actor-isolated property
```swift
// WRONG
class ViewModel {
    @MainActor var data: String = ""

    func update() {  // Not marked with @MainActor
        data = "new value"  // Error!
    }
}
```

#### ✅ Solution: Match actor context
```swift
// CORRECT
class ViewModel {
    @MainActor var data: String = ""

    @MainActor
    func update() {
        data = "new value"
    }
}
```

### `@MainActor` Guidelines
- Mark entire classes with `@MainActor` if they primarily interact with UI
- Mark individual methods with `@MainActor` if they need to update UI state
- Use `await MainActor.run { }` when you need to switch to main actor in the middle of a function

### `Sendable` Conformance
- All types passed across actor boundaries must conform to `Sendable`
- Use `@unchecked Sendable` only when you're certain the type is thread-safe
- Structs with all `Sendable` properties automatically conform
- Classes must be carefully evaluated for thread safety

---

## 3. SwiftUI Best Practices

### State Management

#### Use the right property wrapper:
```swift
// Local, private state
@State private var count = 0

// Shared state from environment
@Environment(\.authStateModel) var authState

// Two-way binding to parent
@Binding var isPresented: Bool

// Observable objects (iOS 17+)
@Observable class ViewModel { }
```

### Environment Injection

#### ❌ Error: Missing environment object
```swift
// WRONG - View expects environment but it's not provided
struct MyView: View {
    @Environment(\.customModel) var model
    // ...
}

// In parent:
MyView()  // Crash at runtime!
```

#### ✅ Solution: Always provide environment values
```swift
// CORRECT
MyView()
    .environment(\.customModel, CustomModel())
```

### View Updates
- Only update state from main thread
- Use `@MainActor` for view models that update `@Published` or `@State`
- Avoid heavy computation in view body - use computed properties or view models

---

## 4. Firebase Integration

### Authentication State
```swift
// ALWAYS check authentication before Firebase operations
guard let uid = Auth.auth().currentUser?.uid else {
    throw AuthError.notAuthenticated
}
```

### Firestore Operations
```swift
// Use user-scoped collections
let collection = db.collection("users")
    .document(uid)
    .collection("students")

// ALWAYS use async/await, not completion handlers
let snapshot = try await collection.getDocuments()

// ALWAYS include timeout protection
let data = try await withTimeout(seconds: 10) {
    try await self.fetchFromFirestore()
}
```

### Offline Handling
- **ALWAYS** provide fallback data when Firestore is unreachable
- Use timeout protection (10 seconds recommended)
- Gracefully handle connection errors
- Enable offline persistence: `db.settings.isPersistenceEnabled = true`

---

## 5. Error Handling

### Async Error Handling Pattern
```swift
@MainActor
func fetchData() async {
    updateState(.loading)

    do {
        let result = try await service.fetch()
        updateState(.loaded(result))
    } catch is TimeoutError {
        print("[Service] Timeout, using fallback")
        updateState(.loaded(fallbackData))
    } catch {
        print("[Service] Error: \(error)")
        handleError(error)
    }
}
```

### Custom Error Types
```swift
enum ServiceError: LocalizedError {
    case notAuthenticated
    case networkFailure(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
```

---

## 6. Memory Management

### Weak Self in Closures
```swift
// Use [weak self] for escaping closures that might outlive the owner
Auth.auth().addStateDidChangeListener { [weak self] _, user in
    guard let self = self else { return }

    Task { @MainActor in
        await self.handleAuthStateChange(user)
    }
}
```

### Avoid Retain Cycles
- Use `[weak self]` in escaping closures
- Use `[unowned self]` only when you're certain self will outlive the closure
- Be especially careful with:
  - Observers and listeners
  - Completion handlers
  - Animation blocks

---

## 7. Type Safety

### Optional Handling
```swift
// Prefer optional chaining over force unwrapping
let name = user?.displayName ?? "Guest"

// Use guard for early returns
guard let uid = user?.uid else {
    return
}

// NEVER force unwrap unless you have a clear reason
// let uid = user!.uid  // ❌ AVOID
```

### Type Inference
```swift
// Be explicit when type inference is ambiguous
let data = InterestsAndHobbiesData(interests: interests)  // ✅
let data: InterestsAndHobbiesData = .init(interests: interests)  // ✅
let data = .init(interests: interests)  // ❌ May be ambiguous
```

---

## Quick Reference Checklist

Before committing code, verify:

- [ ] All closures use explicit `self.` for instance members
- [ ] All `@MainActor` methods accessing UI state are properly marked
- [ ] All Firebase operations have timeout protection
- [ ] All Firebase operations have error handling with fallback
- [ ] No force unwrapping (`!`) without documented justification
- [ ] All escaping closures that capture self use `[weak self]` or `[unowned self]`
- [ ] All environment values injected in views are provided by parent
- [ ] All async operations use `async/await`, not completion handlers
- [ ] All state updates happen on `@MainActor`
- [ ] No debug print statements in production code

---

## Common Error Messages and Solutions

### "Reference to property X in closure requires explicit use of 'self'"
**Solution**: Add `self.` before the property: `self.property`

### "Call to main actor-isolated property X in a synchronous nonisolated context"
**Solution**: Mark the calling function with `@MainActor` or use `await MainActor.run { }`

### "Type X does not conform to the 'Sendable' protocol"
**Solution**: Add `@unchecked Sendable` to struct/class definition or ensure all properties are Sendable

### "Cannot assign to property: 'self' is immutable"
**Solution**: Change `struct` to `class` or make method `mutating`

### "Missing argument for parameter X in call"
**Solution**: Check function signature - parameter might have been renamed or reordered

---

## Project-Specific Patterns

### State Models
All state models in this project inherit from `BaseStateModel`:
```swift
@Observable
final class MyStateModel: BaseStateModel<DataType, ErrorType> {
    @MainActor
    override func fetch() async {
        updateState(.loading)
        // ... implementation
    }
}
```

### Service Layer
Services should be actor-isolated or use explicit concurrency:
```swift
class MyService {
    func fetch() async throws -> Data {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ServiceError.notAuthenticated
        }

        // Always use timeout
        return try await withTimeout(seconds: 10) {
            try await self.performFetch(uid)
        }
    }
}
```

### View Updates
All UI updates must happen on the main actor:
```swift
@MainActor
func updateUI() {
    // Safe to update @State or @Published here
    self.isLoading = false
    self.data = newData
}
```

---

## Enforcement

This document should be:
1. ✅ Reviewed by all developers before starting work
2. ✅ Referenced during code review
3. ✅ Updated when new patterns or errors are discovered
4. ✅ Consulted by AI assistants before generating code

**When in doubt, refer to this document first, then Apple's Swift documentation.**

---

*Document maintained by: Development Team*
*Version: 1.0*
*Last Reviewed: January 2025*
