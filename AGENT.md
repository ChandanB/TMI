# AGENT.md

## Build/Test Commands
- **Build**: `xcodebuild -project TMI.xcodeproj -scheme TMI -configuration Debug build`
- **Simulator Build**: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build`
- **Clean**: `xcodebuild -project TMI.xcodeproj -scheme TMI clean`
- **Test Single File**: Use Xcode Test Navigator or `xcodebuild test -project TMI.xcodeproj -scheme TMI -destination 'platform=iOS Simulator,name=iPhone 16'`

## Architecture
**TMI** is a SwiftUI iOS app for trauma-informed educational interventions. MVVM architecture with:
- **Core**: AuthStateModel, TMIUser (7+ roles), Firebase integration via FirebaseManager
- **Data**: User-scoped Firestore collections (`users/{uid}/students`, `users/{uid}/tmiPlans`)
- **Key Models**: Student, TMIPlan, Interest/Hobby with Codable + @DocumentID
- **Navigation**: MainTabView with role-based access, Students/TMI Plans MVP focus

## Code Style
- **ViewModels**: Use `@Observable` classes with async/await Firebase operations
- **Components**: Use TMIComponentLibrary (8 unified types) instead of custom implementations
- **Firebase**: Always check auth, user-scoped collections, include loading states
- **Naming**: Swift conventions, descriptive names for models/views
- **Error Handling**: Try/catch with fallback to sample data, comprehensive logging
- **Imports**: Group Foundation/SwiftUI/Firebase, then internal imports
- **Types**: Explicit types for models, optional chaining for Firebase data
