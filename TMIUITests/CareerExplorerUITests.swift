import XCTest

@MainActor
final class CareerExplorerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCareerDiscoveryKeepsStudentVisibleAndPersistsCoreChoices() {
        let app = launchFixture()
        XCTAssertTrue(element("careerDiscovery.screen", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Careers for Ava Stone"].exists)

        let firstCareer = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Frontend Developer")
        ).firstMatch
        XCTAssertTrue(firstCareer.waitForExistence(timeout: 5))
        app.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Remove saved"].firstMatch.waitForExistence(timeout: 5))

        let compareButtons = app.buttons.matching(
            NSPredicate(format: "label == %@", "Compare")
        )
        compareButtons.firstMatch.tap()
        compareButtons.element(boundBy: 1).tap()
        let compareSelected = app.buttons["Compare 2"]
        XCTAssertTrue(compareSelected.isEnabled)
        compareSelected.tap()
        XCTAssertTrue(element("careerComparison.screen", in: app).waitForExistence(timeout: 5))
    }

    func testDetailSharesAndAttachesCareerToStudentPlan() {
        let app = launchFixture(named: "career-detail")
        XCTAssertTrue(app.buttons["Share career"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Attach to a plan"].isEnabled)
        app.buttons["Attach to a plan"].tap()

        XCTAssertTrue(element("careerAttachment.sheet", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Frontend Developer for Ava Stone"].exists)
        element("careerAttachment.plan.plan-a", in: app).tap()
        XCTAssertTrue(
            app.staticTexts["Frontend Developer was attached to Technology confidence plan."]
                .waitForExistence(timeout: 5)
        )
    }

    private func launchFixture(named fixture: String = "career-discovery") -> XCUIApplication {
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

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
