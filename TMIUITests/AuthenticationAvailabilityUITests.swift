import XCTest

@MainActor
final class AuthenticationAvailabilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRecoveryRetryHasVisibleOutcome() {
        let app = launch(fixture: "authentication-recovery")

        XCTAssertTrue(
            element("authentication.recovery.screen", in: app)
                .waitForExistence(timeout: 10)
        )

        let retry = app.buttons["authentication.recovery.retry"]
        XCTAssertTrue(retry.isHittable)

        retry.tap()

        XCTAssertTrue(
            element("authentication.accessSetup.screen", in: app)
                .waitForExistence(timeout: 10),
            "Retry must have a deterministic, visible recovery outcome."
        )
    }

    func testRecoverySignOutReturnsToSignIn() {
        let app = launch(fixture: "authentication-recovery")

        XCTAssertTrue(
            element("authentication.recovery.screen", in: app)
                .waitForExistence(timeout: 10)
        )
        let signOut = app.buttons["authentication.recovery.signOut"]
        XCTAssertTrue(signOut.isHittable)
        signOut.tap()

        XCTAssertTrue(
            element("authentication.signIn.screen", in: app)
                .waitForExistence(timeout: 10),
            "Signing out of recovery must return to the sign-in screen."
        )
    }

    func testExistingAccountCanCompleteAccessSetupAndReachRoster() {
        let app = launch(fixture: "authentication-access-setup")

        XCTAssertTrue(
            element("authentication.accessSetup.screen", in: app)
                .waitForExistence(timeout: 10)
        )
        enter(
            "Taylor Educator",
            into: "authentication.accessSetup.name",
            in: app
        )
        enter(
            "DISTRICT-INVITE-2026",
            into: "authentication.accessSetup.invitation",
            in: app
        )

        let submit = app.buttons["authentication.accessSetup.submit"]
        XCTAssertTrue(submit.isHittable)
        submit.tap()

        XCTAssertTrue(
            element("studentRoster.empty", in: app)
                .waitForExistence(timeout: 10),
            "A valid existing-account invitation must authorize the roster."
        )
        XCTAssertFalse(app.staticTexts["Verify Your Email"].exists)
    }

    private func launch(fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-fixture", fixture,
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
#if os(macOS)
        app.typeKey("n", modifierFlags: .command)
#endif
        return app
    }

    private func enter(
        _ value: String,
        into identifier: String,
        in app: XCUIApplication
    ) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(value)
    }

    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
