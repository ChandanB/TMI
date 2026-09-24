import XCTest

@MainActor
final class MeetingsUITests: XCTestCase {
    func testMeetingOpensDetailAndActionItemsToggle() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fixture", "meetings", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let row = app.buttons.containing(.staticText, identifier: "Weekly check-in with Kai").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Past"].exists)
        row.tap()

        XCTAssertTrue(app.navigationBars["Meeting"].waitForExistence(timeout: 5))
        let item = app.buttons.containing(.staticText, identifier: "Bring the sketchbook").firstMatch
        for _ in 0..<6 where !item.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["0 of 2 done"].exists)
        item.tap()
        XCTAssertTrue(app.staticTexts["1 of 2 done"].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Meeting detail"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Done"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
