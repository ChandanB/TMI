import FirebaseAuth
import FirebaseCore

/// Safe accessors for the signed-in Firebase user.
///
/// `Auth.auth()` traps when no FirebaseApp is configured, which is the case in
/// UI-test fixtures and SwiftUI previews. Default arguments that read the
/// current user must go through here.
nonisolated enum FirebaseSession {
    static func currentUserID() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser?.uid
    }
}
