import XCTest

@MainActor
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignedOutFixtureShowsSignInScreen() {
        let app = launchSignedOutFixture()

        XCTAssertTrue(
            app.staticTexts["authentication.signIn.screen"].waitForExistence(timeout: 10),
            "Expected the deterministic signed-out fixture to show the sign-in screen."
        )
        XCTAssertFalse(
            app.keyboards.firstMatch.exists,
            "The sign-in screen should not obscure its actions by opening the keyboard at launch."
        )
        attachScreenshot(of: app, named: "signed-out-default")
    }

    func testSignedOutFixtureAtLargestAccessibilityTextSize() {
        let app = launchSignedOutFixture(contentSize: "accessibility5")

        let heading = app.staticTexts["authentication.signIn.screen"]
        XCTAssertTrue(
            heading.waitForExistence(timeout: 10),
            "Expected the sign-in heading at the largest accessibility text size."
        )
        XCTAssertGreaterThan(
            heading.frame.height,
            36,
            "Expected the accessibility fixture to materially enlarge the sign-in heading."
        )
        let logInButton = app.buttons["authentication.signIn.logIn"]
        XCTAssertTrue(
            logInButton.waitForExistence(timeout: 10),
            "Expected the primary sign-in action at the largest accessibility text size."
        )
        XCTAssertFalse(
            app.keyboards.firstMatch.exists,
            "The accessibility-size sign-in screen should not open with the keyboard obscuring its actions."
        )
        attachScreenshot(of: app, named: "signed-out-accessibility5-top")
        scrollToHittable(logInButton, in: app)
        XCTAssertTrue(
            logInButton.isHittable,
            "Expected the primary sign-in action to remain reachable at the largest accessibility text size."
        )
        XCTAssertTrue(
            app.windows.firstMatch.frame.contains(logInButton.frame),
            "Expected the primary sign-in action to be fully visible at the largest accessibility text size."
        )

        let createAccountButton = app.buttons["authentication.signIn.createAccount"]
        XCTAssertTrue(
            createAccountButton.waitForExistence(timeout: 10),
            "Expected the create-account action at the largest accessibility text size."
        )
        scrollToHittable(createAccountButton, in: app)
        XCTAssertTrue(
            createAccountButton.isHittable
                && app.windows.firstMatch.frame.contains(createAccountButton.frame),
            "Expected the create-account action to remain fully reachable at the largest accessibility text size."
        )
        XCTAssertEqual(
            app.state,
            .runningForeground,
            "Accessibility scrolling must keep the application in the foreground."
        )
        attachScreenshot(of: app, named: "signed-out-accessibility5-actions")
    }

    private func launchSignedOutFixture(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-fixture", "signed-out",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        if let contentSize {
            app.launchArguments += ["-content-size", contentSize]
        }

        app.launch()
#if os(macOS)
        // A macOS UI-testing host can restore the application with no open
        // windows. Open the WindowGroup explicitly so the fixture is visible.
        app.typeKey("n", modifierFlags: .command)
        XCTAssertGreaterThanOrEqual(
            app.windows.firstMatch.frame.height,
            700,
            "Expected the default macOS window to accommodate large-text workflows."
        )
#endif
        return app
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Expected the sign-in screen to provide a scroll container.")
        let viewport = app.windows.firstMatch
        XCTAssertTrue(viewport.exists, "Expected the sign-in screen to provide an application window.")

        for _ in 0..<5 where !element.isHittable || !viewport.frame.contains(element.frame) {
            scrollView.swipeUp()
        }
    }
}
