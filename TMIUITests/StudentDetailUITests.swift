import XCTest

@MainActor
final class StudentDetailUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPopulatedHubShowsCanonicalHeaderAndPermissionBackedActions() {
        let app = launchDetailFixture("student-detail-populated")

        XCTAssertTrue(element("studentDetail.screen", in: app).waitForExistence(timeout: 10))
        let header = element("studentDetail.header.student-a", in: app)
        XCTAssertTrue(header.exists)
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("Ava Stone"))
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("grade 7"))
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("2 assigned staff"))

        let studentMode = app.buttons["studentDetail.studentMode"]
        XCTAssertTrue(studentMode.exists)
        XCTAssertFalse(studentMode.isEnabled)
        XCTAssertTrue(app.buttons["studentDetail.edit"].exists)
        XCTAssertTrue(app.buttons["studentDetail.archive"].exists)
        XCTAssertFalse(app.buttons["studentDetail.delete"].exists)
    }

    func testTimelineKeepsPrivateNotesAndStudentReflectionsDistinct() {
        let app = launchDetailFixture("student-detail-populated")
        XCTAssertTrue(element("studentDetail.screen", in: app).waitForExistence(timeout: 10))

        app.buttons["studentDetail.destination.meetingsAndNotes"].tap()

        XCTAssertTrue(
            element("studentDetail.timeline.privateNote.note-a", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("studentDetail.timeline.studentReflection.reflection-a", in: app)
                .waitForExistence(timeout: 5)
        )
    }

    func testRelease1TimelineShowsRelease4UnavailableInsteadOfEmpty() {
        let app = launchDetailFixture("student-detail-release1")
        XCTAssertTrue(element("studentDetail.screen", in: app).waitForExistence(timeout: 10))

        app.buttons["studentDetail.destination.meetingsAndNotes"].tap()

        let unavailable = app.staticTexts[
            "Timeline available in Release 4"
        ]
        XCTAssertTrue(
            unavailable.waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertFalse(element("studentDetail.timeline.empty", in: app).exists)
    }

    func testOfflineHubLabelsSavedContentAndHidesMutations() {
        let app = launchDetailFixture("student-detail-offline")

        XCTAssertTrue(
            element("studentDetail.offline", in: app).waitForExistence(timeout: 10)
        )
        XCTAssertTrue(element("studentDetail.header.student-a", in: app).exists)
        XCTAssertFalse(app.buttons["studentDetail.edit"].exists)
        XCTAssertFalse(app.buttons["studentDetail.archive"].exists)
        XCTAssertFalse(app.buttons["studentDetail.delete"].exists)
    }

    func testPermissionDeniedHubFailsClosed() {
        let app = launchDetailFixture("student-detail-permission-denied")

        XCTAssertTrue(
            app.staticTexts["Student Access Changed"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(element("studentDetail.header.student-a", in: app).exists)
        XCTAssertFalse(app.buttons["studentDetail.edit"].exists)
        XCTAssertFalse(app.buttons["studentDetail.archive"].exists)
    }

    func testAccessibilitySizePreservesCompleteHeaderAndReachableSections() {
        let app = launchDetailFixture(
            "student-detail-populated",
            contentSize: "accessibility5"
        )

        let header = element("studentDetail.header.student-a", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("school school-a"))
        XCTAssertTrue(header.label.localizedCaseInsensitiveContains("no active plans"))
        let overview = app.buttons["studentDetail.destination.overview"]
        for _ in 0..<4 where !overview.exists {
            app.swipeUp()
        }
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
    }

    private func launchDetailFixture(
        _ fixture: String,
        contentSize: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-fixture", fixture,
            "-ApplePersistenceIgnoreState", "YES",
        ]
        if let contentSize {
            app.launchArguments += ["-content-size", contentSize]
        }
        app.launch()
#if os(macOS)
        app.typeKey("n", modifierFlags: .command)
#endif
        return app
    }

    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
