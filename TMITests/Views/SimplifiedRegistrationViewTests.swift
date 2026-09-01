import Foundation
import Testing

@Suite("Simplified Registration View")
struct SimplifiedRegistrationViewTests {
    @Test("Application root owns registration presentation across auth routing")
    func applicationRootOwnsRegistrationPresentation() throws {
        let source = try source(at: "TMI/App/TMIApp.swift")
        let contentView = try sourceSection(
            in: source,
            startingAt: "struct ContentView: View {",
            endingAt: "// MARK: - Loading View"
        )

        #expect(contentView.contains("@State private var isRegistrationPresented = false"))
        #expect(contentView.contains("@State private var isRegistrationOperationActive = false"))
        #expect(contentView.contains("AuthenticationView(onCreateAccount:"))
        #expect(contentView.contains("isRegistrationPresented = true"))
        #expect(contentView.contains(".sheet(isPresented: $isRegistrationPresented)"))
        #expect(contentView.contains("SimplifiedRegistrationView("))
        #expect(contentView.contains("isPresented: self.$isRegistrationPresented"))
        #expect(
            contentView.contains(
                "isOperationActive: self.$isRegistrationOperationActive"
            )
        )
        #expect(contentView.contains(".tmiSheetStyle()"))
        #expect(
            contentView.contains(
                ".interactiveDismissDisabled(self.isRegistrationOperationActive)"
            )
        )

        let routingEnd = try #require(
            contentView.range(of: ".foregroundStyle(Color.tmiTextPrimary)")?.upperBound
        )
        let sheetStart = try #require(
            contentView.range(of: ".sheet(isPresented: $isRegistrationPresented)")?.lowerBound
        )
        #expect(sheetStart > routingEnd)
    }

    @Test("Authentication view delegates account creation without owning a sheet")
    func authenticationViewDelegatesRegistrationPresentation() throws {
        let source = try source(at: "TMI/Views/Authentication/AuthenticationView.swift")

        #expect(source.contains("let onCreateAccount: @MainActor () -> Void"))
        #expect(source.contains("init(onCreateAccount:"))
        #expect(source.contains("onCreateAccount()"))
        #expect(!source.contains("showingRegistration"))
        #expect(!source.contains("SimplifiedRegistrationView("))
        #expect(!source.contains(".sheet(isPresented:"))
    }

    @Test("Registration form uses the registration flow and exact published identity")
    func registrationUsesFlowAndExactPublishedIdentity() throws {
        let source = try source(
            at: "TMI/Views/Authentication/SimplifiedRegistrationView.swift"
        )

        #expect(source.contains("@Binding private var isPresented: Bool"))
        #expect(source.contains("@Binding private var isOperationActive: Bool"))
        #expect(source.contains("@State private var flow = StaffRegistrationFlow()"))
        #expect(
            source.contains(
                "if await self.flow.submit(request, using: authentication)"
            )
        )
        #expect(source.contains("self.flow.retryRecovery(using: authentication)"))
        #expect(
            source.contains("authStateModel.authenticatedSession?.profile.userID")
        )
        #expect(source.contains("flow.finishAuthorization("))
        #expect(source.contains("flow.acceptPublishedIdentity("))
        #expect(source.contains("authentication.registration.cancel"))
        #expect(source.contains("authentication.registration.retryRecovery"))
        #expect(!source.contains("@Environment(\\.dismiss)"))
        #expect(!source.contains("@State private var isRegistering"))
    }

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
        let registration = try source(
            at: "TMI/Views/Authentication/SimplifiedRegistrationView.swift"
        )
        let signIn = try source(at: "TMI/Views/Authentication/AuthenticationView.swift")
        let legacyRegistration = try source(
            at: "TMI/Views/Authentication/RegistrationView.swift"
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

    private func source(at path: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appending(path: path),
            encoding: .utf8
        )
    }

    private func sourceSection(
        in source: String,
        startingAt start: String,
        endingAt end: String
    ) throws -> String {
        let startIndex = try #require(source.range(of: start)?.lowerBound)
        let endIndex = try #require(
            source.range(of: end, range: startIndex..<source.endIndex)?.lowerBound
        )
        return String(source[startIndex..<endIndex])
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
