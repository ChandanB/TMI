import XCTest

@MainActor
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignedOutFixtureShowsSignInScreen() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-fixture", "signed-out",
            "-ApplePersistenceIgnoreState", "YES",
        ]

        app.launch()
#if os(macOS)
        // A macOS UI-testing host can restore the application with no open
        // windows. Open the WindowGroup explicitly so the fixture is visible.
        app.typeKey("n", modifierFlags: .command)
#endif

        XCTAssertTrue(
            app.staticTexts["authentication.signIn.screen"].waitForExistence(timeout: 10),
            "Expected the deterministic signed-out fixture to show the sign-in screen."
        )
    }
}
