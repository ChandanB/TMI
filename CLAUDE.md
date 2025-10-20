# CLAUDE.md

# Modern Swift Development

Write idiomatic SwiftUI code following Apple's latest architectural recommendations and best practices.

> **⚠️ REQUIRED READING**: Before writing any code, review [SWIFT_CODING_STANDARDS.md](./SWIFT_CODING_STANDARDS.md) for error prevention patterns and project-specific guidelines.

## Core Philosophy

- SwiftUI is the default UI paradigm for Apple platforms - embrace its declarative nature
- Avoid legacy UIKit patterns and unnecessary abstractions
- Focus on simplicity, clarity, and native data flow
- Let SwiftUI handle the complexity - don't fight the framework

## Architecture Guidelines

### 1. Embrace Native State Management

Use SwiftUI's built-in property wrappers appropriately:
- `@State` - Local, ephemeral view state
- `@Binding` - Two-way data flow between views
- `@Observable` - Shared state (iOS 17+)
- `@Environment` - Dependency injection for app-wide concerns

### 2. State Ownership Principles

- Views own their local state unless sharing is required
- State flows down, actions flow up
- Keep state as close to where it's used as possible
- Extract shared state only when multiple views need it

### 3. Modern Async Patterns

- Use `async/await` as the default for asynchronous operations
- Leverage `.task` modifier for lifecycle-aware async work
- Avoid Combine unless absolutely necessary
- Handle errors gracefully with try/catch

### 4. View Composition

- Build UI with small, focused views
- Extract reusable components naturally
- Use view modifiers to encapsulate common styling
- Prefer composition over inheritance

### 5. Code Organization

- Organize by feature, not by type (avoid Views/, Models/, ViewModels/ folders)
- Keep related code together in the same file when appropriate
- Use extensions to organize large files
- Follow Swift naming conventions consistently

## Implementation Patterns

### Simple State Example
```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { 
                count += 1 
            }
        }
    }
}
```

### Shared State with @Observable
```swift
@Observable
class UserSession {
    var isAuthenticated = false
    var currentUser: User?
    
    func signIn(user: User) {
        currentUser = user
        isAuthenticated = true
    }
}

struct MyApp: App {
    @State private var session = UserSession()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
```

### Async Data Loading
```swift
struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                ProfileContent(profile: profile)
            } else if let error {
                ErrorView(error: error)
            }
        }
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profile = try await ProfileService.fetch()
        } catch {
            self.error = error
        }
    }
}
```

## Best Practices

### DO:
- Write self-contained views when possible
- Use property wrappers as intended by Apple
- Test logic in isolation, preview UI visually
- Handle loading and error states explicitly
- Keep views focused on presentation
- Use Swift's type system for safety

### DON'T:
- Create ViewModels for every view
- Move state out of views unnecessarily
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Fight SwiftUI's update mechanism
- Overcomplicate simple features

## Testing Strategy

- Unit test business logic and data transformations
- Use SwiftUI Previews for visual testing
- Test @Observable classes independently
- Keep tests simple and focused
- Don't sacrifice code clarity for testability

## Modern Swift Features

- Use Swift Concurrency (async/await, actors)
- Leverage Swift 6 data race safety when available
- Utilize property wrappers effectively
- Embrace value types where appropriate
- Use protocols for abstraction, not just for testing

## Summary

Write SwiftUI code that looks and feels like SwiftUI. The framework has matured significantly - trust its patterns and tools. Focus on solving user problems rather than implementing architectural patterns from other platforms.

## Architecture Overview

### Core Application Structure

**TMI (Tangible Modification Intervention)** is a SwiftUI-based iOS educational application focused on trauma-informed interventions for students. The app follows an MVVM architecture with a service layer for Firebase integration.

### Key Architectural Components

#### 1. Authentication & User Management
- **AuthStateModel**: Central authentication state management using `@Observable`
- **TMIUser**: Comprehensive user model supporting 7+ user roles (student, teacher, counselor, administrator, socialWorker, legalGuardian, parent)
- **Multi-role permissions system** with role-based access controls
- **COPPA/FERPA compliance** with consent tracking and age verification

#### 2. Firebase Integration
- **FirebaseManager**: Singleton service managing Auth, Firestore, and Storage
- **User-scoped data architecture**: All data stored in `users/{uid}/...` collections
- **FirebaseConfigurationHelper**: Comprehensive setup validation and developer guidance
- **Offline-first approach** with automatic Firebase offline mode

#### 3. Data Models
- **Student**: Core educational entity with interests, hobbies, TMI plans, and engagement tracking
- **TMIPlan**: Educational intervention plans with 6 models (Chase Your Space, Acknowledge Interests, etc.)
- **Interest/Hobby**: Categorized student interest system with Firebase integration

#### 4. UI Architecture
- **MainTabView**: Role-based navigation with MVP focus on Students and TMI Plans tabs
- **TMIComponentLibrary**: Unified design system with 8 component types (backgrounds, cards, buttons, etc.)
- **State-driven UI**: Views use `@State` and `@Observable` for reactive updates

### Current MVP Status (Phase 1: The Core Loop)

The application is in MVP state focusing on the educator experience:

#### Available Features
1. **Authentication**: Firebase Auth with educator-focused registration
2. **Student Management**: Full CRUD operations with Firestore integration
3. **TMI Plan Creation**: Multi-step wizard with real-time data fetching
4. **Data Seeding**: Comprehensive sample data for new educators

#### Data Flow
```
User Authentication → AuthStateModel → MainTabView → [Students|TMIPlans]View → ViewModel → Firebase
```

### Environment Dependencies
- **SwiftUI**: iOS 26+ (uses latest SwiftUI features)
- **Firebase SDK 11.2.0**: Full Firebase suite including Auth, Firestore, Analytics
- **SDWebImageSwiftUI**: Image loading and caching
- **Charts**: SwiftUI Charts for data visualization

### Key Development Patterns

#### ViewModels
Use `@Observable` class-based ViewModels for complex data management:
```swift
@Observable
class StudentListViewModel {
    var students: [Student] = []
    var isLoading = false
    
    @MainActor
    func fetchStudents() async { ... }
}
```

#### Async/Await Firebase Operations
All Firebase operations use modern async/await patterns:
```swift
private func fetchStudentsFromFirestore(db: Firestore, uid: String) async throws -> [Student] {
    let collection = db.collection("users").document(uid).collection("students")
    let querySnapshot = try await collection.getDocuments()
    return querySnapshot.documents.compactMap { try? $0.data(as: Student.self) }
}
```

#### Component Usage
Use unified TMIComponentLibrary components instead of custom implementations:
```swift
// Use this
TMIBackgroundView(variant: .dashboard)
TMIButton(text: "Save", style: .primary, action: { ... })

// Instead of custom background/button implementations
```

### Important File Locations
- **Entry Point**: `TMI/App/TMIApp.swift`
- **Main Navigation**: `TMI/Views/MainTabView.swift`
- **Authentication**: `TMI/StateModels/AuthStateModel.swift`
- **Firebase Config**: `TMI/Services/FirebaseManager.swift`
- **Component Library**: `TMI/Views/Components/TMIComponentLibrary.swift`
- **Security Rules**: `firestore.rules` (project root)

### Development Guidelines

#### Firebase Integration
- Always check user authentication before Firebase operations
- Use user-scoped collections: `users/{uid}/collection`
- Implement proper error handling with fallback to sample data
- Include loading states for all async operations

#### Component Development
- Use TMIComponentLibrary for consistent UI
- Follow established animation parameters (0.3s spring response)
- Implement proper accessibility support
- Use role-based navigation in MainTabView

#### Data Management
- Use Codable for Firebase document mapping
- Include @DocumentID for Firestore document IDs
- Implement toFirestoreData() methods for complex models
- Use comprehensive sample data for development/testing

* Aim to build all functionality using SwiftUI.
* Design UI in a way that is idiomatic for the macOS platform and follows Apple Human Interface Guidelines.
* Use SF Symbols for iconography.
* Use the most modern macOS APIs. Since there is no backward compatibility constraint, this app can target the latest macOS version with the newest APIs.
* Use the most modern Swift language features and conventions. Target Swift 6 and use Swift concurrency (async/await, actors) and Swift macros where applicable.

## Visual Development

### Comprehensive Design Review
Invoke the `@design-review-agent.md` subagent for thorough design validation when:
- Completing significant UI/UX features
- Before finalizing PRs with visual changes
- Needing comprehensive accessibility and responsiveness testing
