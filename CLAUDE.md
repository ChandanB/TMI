# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the Project
```bash
# Build the project (use xcodebuild since this is an iOS app)
xcodebuild -project TMI.xcodeproj -scheme TMI -configuration Debug build

# Build for specific platform
xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build

# Clean build folder
xcodebuild -project TMI.xcodeproj -scheme TMI clean
```

### Firebase Setup
The project uses Firebase extensively. Ensure `GoogleService-Info.plist` is present in the project root for Firebase to work properly. The app has a comprehensive Firebase configuration helper that will log detailed setup instructions if configuration is missing.

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

### Security Rules
Firestore security implemented in `firestore.rules` with user-scoped data access:
```javascript
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
  match /students/{studentId} { allow read, write: if request.auth.uid == userId; }
  match /tmiPlans/{planId} { allow read, write: if request.auth.uid == userId; }
}
```

### Environment Dependencies
- **SwiftUI**: iOS 15+ (uses latest SwiftUI features)
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

### Recent Major Changes
1. **Component Unification**: Consolidated 22+ duplicate components into 8 unified types
2. **MVP Implementation**: Simplified to educator-focused Students + TMI Plans experience  
3. **Firebase Integration**: Complete migration from sample data to real Firestore operations
4. **Authentication Overhaul**: Multi-role system with compliance tracking