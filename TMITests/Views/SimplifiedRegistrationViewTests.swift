import Foundation
import Testing

@Suite("Simplified Registration View")
struct SimplifiedRegistrationViewTests {
    @Test("Registration sheet avoids oversized fixed minimum frame constraints")
    func avoidsOversizedFixedMinimumFrame() throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Authentication/SimplifiedRegistrationView.swift")
        let source = try String(contentsOf: sourceFileURL, encoding: .utf8)

        #expect(source.contains(".frame(minWidth: 900, minHeight: 900)") == false)
        #expect(source.contains("NavigationView {") == false)
    }

    @Test("Registration is invitation-only and uses injected authentication")
    func registrationUsesCanonicalRepository() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let registration = try String(
            contentsOf: root.appending(
                path: "TMI/Views/Authentication/SimplifiedRegistrationView.swift"
            ),
            encoding: .utf8
        )
        let signIn = try String(
            contentsOf: root.appending(
                path: "TMI/Views/Authentication/AuthenticationView.swift"
            ),
            encoding: .utf8
        )
        let legacyRegistration = try String(
            contentsOf: root.appending(
                path: "TMI/Views/Authentication/RegistrationView.swift"
            ),
            encoding: .utf8
        )

        #expect(registration.contains("invitationCode"))
        #expect(registration.contains("privacyPolicyVersion"))
        #expect(registration.contains("acceptableUsePolicyVersion"))
        #expect(registration.contains("dependencies.authentication"))
        #expect(!registration.contains("AuthenticationService.shared"))
        #expect(!legacyRegistration.contains("AuthenticationService.shared"))
        #expect(legacyRegistration.contains("SimplifiedRegistrationView()"))
        #expect(signIn.contains("I've Verified My Email"))
        #expect(signIn.contains("authentication.refresh()"))
        #expect(signIn.contains("authentication.sendVerification()"))
        #expect(!signIn.contains("TraumaInformedErrorView"))
        #expect(!signIn.contains("SupportResourcesView"))
    }
}
