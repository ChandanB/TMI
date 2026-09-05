import XCTest

@MainActor
final class PlanWorkflowUITests: XCTestCase {
    func testApprovalActivationAndExportAreReachable() {
        let app = launch("plan-workflow")
        XCTAssertTrue(app.staticTexts["planDetail.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["planDetail.transition.active"].exists)
        tap("planDetail.transition.pendingApproval", in: app)
        tap("planDetail.transition.approved", in: app)
        XCTAssertEqual(app.staticTexts["planDetail.status"].label, "Approved")
        tap("planDetail.transition.active", in: app)
        XCTAssertEqual(app.staticTexts["planDetail.status"].label, "Active")
        tap("planDetail.export.professionalPlan", in: app)
        let share = app.buttons["planDetail.sharePDF"]
        for _ in 0..<8 where !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Active plan with audited PDF sharing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        share.tap()
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 10))
    }

    func testFailedDetailsAreNotEmptyEvidence() {
        let app = launch("plan-details-failure")
        let retry = app.buttons["Retry loading details"]
        for _ in 0..<5 where !retry.isHittable { app.swipeUp() }
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["planDetail.export.professionalPlan"].exists)
        XCTAssertFalse(app.staticTexts["No progress recorded yet."].exists)
    }

    func testLargeTextKeepsPlanActionsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fixture", "plan-workflow", "-content-size", "accessibility5"]
        app.launch()
        tap("planDetail.transition.pendingApproval", in: app)
        XCTAssertTrue(app.buttons["planDetail.transition.approved"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Plan at largest Dynamic Type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func launch(_ fixture: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fixture", fixture, "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        return app
    }

    private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 10), id)
        for _ in 0..<8 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }
}
