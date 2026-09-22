import Foundation
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

/// Configures Firebase once, before any service is touched.
///
/// Every callable enforces App Check, so the provider factory must be installed
/// before `FirebaseApp.configure()`. DEBUG builds use the App Check debug
/// provider: the first launch logs a debug token that must be registered in
/// Firebase console → App Check → Manage debug tokens. Release builds use
/// DeviceCheck, which needs the DeviceCheck key registered for the app.
enum FirebaseBootstrap {
    @MainActor
    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
#if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
#endif
        FirebaseApp.configure()
#if DEBUG
        FirebaseEnvironment.current.applyIfNeeded()
#endif
    }

    /// The Firebase project the app is configured against.
    @MainActor
    static var projectID: String {
        FirebaseApp.app()?.options.projectID ?? "unconfigured"
    }
}

#if DEBUG
/// DEBUG-only choice between the live project and the local Emulator Suite.
/// Applied at launch, so switching requires a relaunch. Start the emulators with
/// the app's project ID so requests are accepted:
/// `firebase emulators:start --project tmi-education` (from the repo root).
nonisolated struct FirebaseEnvironment: Equatable, Sendable {
    enum Target: String, CaseIterable, Sendable {
        case live
        case emulator
    }

    var target: Target
    var emulatorHost: String

    static let defaultsKey = "debug.firebase.environment"
    static let hostKey = "debug.firebase.emulatorHost"

    static var current: FirebaseEnvironment {
        get {
            let defaults = UserDefaults.standard
            return FirebaseEnvironment(
                target: Target(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .live,
                emulatorHost: defaults.string(forKey: hostKey) ?? "127.0.0.1"
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.target.rawValue, forKey: defaultsKey)
            defaults.set(newValue.emulatorHost, forKey: hostKey)
        }
    }

    @MainActor
    func applyIfNeeded() {
        guard target == .emulator else { return }
        Auth.auth().useEmulator(withHost: emulatorHost, port: 9099)
        let settings = Firestore.firestore().settings
        settings.host = "\(emulatorHost):8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        Functions.functions(region: "us-central1").useEmulator(withHost: emulatorHost, port: 5001)
        Storage.storage().useEmulator(withHost: emulatorHost, port: 9199)
    }
}
#endif
