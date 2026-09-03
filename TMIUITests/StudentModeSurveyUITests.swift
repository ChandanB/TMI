import XCTest

@MainActor
final class StudentModeSurveyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStudentCompletesCanonicalSurveyJourneyWithoutStaffContent() {
        let app = launchSurveyFixture()

        XCTAssertTrue(app.staticTexts["Welcome, Taylor"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Staff notes"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)

        app.buttons["studentSurvey.begin"].tap()
        XCTAssertTrue(element("studentSurvey.progress", in: app).exists)
        app.buttons["studentSurvey.option.create"].tap()
        app.buttons["studentSurvey.next"].tap()

        XCTAssertTrue(app.staticTexts["What do you like to create?"].exists)
        app.buttons["studentSurvey.option.art"].tap()
        app.buttons["studentSurvey.back"].tap()
        let nextAfterBack = app.buttons["studentSurvey.next"]
        XCTAssertTrue(waitForEnabled(nextAfterBack))
        nextAfterBack.tap()
        XCTAssertTrue(app.staticTexts["What do you like to create?"].exists)

        app.buttons["studentSurvey.saveLater"].tap()
        XCTAssertTrue(app.staticTexts["Your answers are saved."].waitForExistence(timeout: 5))
        app.buttons["studentSurvey.resume"].tap()

        app.buttons["studentSurvey.next"].tap()
        app.buttons["studentSurvey.option.yes"].tap()
        app.buttons["studentSurvey.next"].tap()
        XCTAssertTrue(app.staticTexts["When do you most enjoy helping?"].exists)
        app.buttons["studentSurvey.option.team"].tap()
        app.buttons["studentSurvey.next"].tap()

        XCTAssertTrue(app.staticTexts["Check your answers"].exists)
        XCTAssertTrue(app.staticTexts["Art or designs"].exists)
        app.buttons["studentSurvey.submit"].tap()
        XCTAssertTrue(app.staticTexts["Nice work!"].waitForExistence(timeout: 5))

        app.buttons["studentSurvey.help"].tap()
        XCTAssertTrue(app.staticTexts["Your educator will check in with you."].exists)

        app.buttons["studentMode.testLock"].tap()
        XCTAssertTrue(element("studentMode.locked", in: app).exists)
        app.buttons["studentMode.exit"].tap()
        app.buttons["Exit"].tap()
        XCTAssertTrue(element("studentMode.staffReturned", in: app).waitForExistence(timeout: 5))
    }

    private func launchSurveyFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-fixture", "student-mode-survey",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

}
