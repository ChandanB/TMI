import XCTest

@MainActor
final class StudentRosterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPopulatedRosterOpensEditorAndPreventsEmptySubmission() {
        let app = launchRosterFixture("roster-populated")

        XCTAssertTrue(element("studentRoster.screen", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["studentRoster.addStudent"].exists)
        XCTAssertTrue(app.buttons["studentRoster.filters"].exists)
#if os(macOS)
        XCTAssertTrue(app.menuButtons["Sort"].exists)
#else
        XCTAssertTrue(app.buttons["studentRoster.sort"].exists)
#endif
        XCTAssertTrue(app.buttons["studentRoster.student.student-ava"].exists)

        app.buttons["studentRoster.addStudent"].tap()

        XCTAssertTrue(element("studentEditor.screen", in: app).waitForExistence(timeout: 5))
        let saveButton = app.buttons["studentEditor.save"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled, "An empty editor must not allow submission.")
    }

    func testEmptyRosterOffersFirstStudentAction() {
        let app = launchRosterFixture("roster-empty")

        XCTAssertTrue(element("studentRoster.empty", in: app).waitForExistence(timeout: 10))
        let addStudent = app.buttons["Add first student"]
        XCTAssertTrue(addStudent.waitForExistence(timeout: 5))
        addStudent.tap()
        XCTAssertTrue(
            element("studentEditor.screen", in: app).waitForExistence(timeout: 5),
            "The empty-state action should open the shared student editor."
        )
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "trauma-informed")
        ).firstMatch.exists)
    }

    func testOfflineRosterLabelsCachedContentAndDisablesArchive() {
        let app = launchRosterFixture("roster-offline")

        XCTAssertTrue(element("studentRoster.offline", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["studentRoster.student.student-ava"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "Actions for Ava Stone")
            ).firstMatch.exists,
            "Offline records must not expose online-only edit or archive actions."
        )
        XCTAssertFalse(
            app.buttons["studentRoster.archive.student-ava"].exists,
            "Archive is online-only and must not be exposed as available offline."
        )
    }

    func testPermissionDeniedRosterProvidesNoMutationControls() {
        let app = launchRosterFixture("roster-permission-denied")

        XCTAssertTrue(
            element("studentRoster.permissionDenied", in: app).waitForExistence(timeout: 10)
        )
        XCTAssertFalse(app.buttons["studentRoster.addStudent"].exists)
        XCTAssertFalse(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "studentRoster.archive.")
        ).firstMatch.exists)
    }

    func testAccessibilitySizeRosterRetainsCompleteRecordSummary() {
        let app = launchRosterFixture(
            "roster-populated",
            contentSize: "accessibility5"
        )

        let record = app.buttons["studentRoster.student.student-ava"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        XCTAssertTrue(record.label.localizedCaseInsensitiveContains("student identifier 0012"))
        XCTAssertTrue(record.label.localizedCaseInsensitiveContains("1 assigned staff"))
    }

    func testArchivedRecordSummaryAnnouncesArchivedStatus() {
        let app = launchRosterFixture("roster-archived")

        let record = app.buttons["studentRoster.student.student-ava"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        XCTAssertTrue(record.label.localizedCaseInsensitiveContains("archived"))
    }

    func testQueuedCreateLocksSaveAndOffersDone() {
        let app = launchRosterFixture("roster-create-queued")
        openCreateEditorAndEnterRequiredFields(in: app)

        let save = app.buttons["studentEditor.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        expectation(
            for: NSPredicate(format: "enabled == false"),
            evaluatedWith: save
        )
        waitForExpectations(timeout: 5)
        XCTAssertFalse(save.isEnabled)
        let done = app.buttons["studentEditor.cancel"]
        expectation(
            for: NSPredicate(format: "label == %@", "Done"),
            evaluatedWith: done
        )
        waitForExpectations(timeout: 5)
        XCTAssertEqual(done.label, "Done")
        XCTAssertTrue(done.isEnabled)
        XCTAssertFalse(app.textFields["studentEditor.name"].isEnabled)
    }

    func testDuplicateCreateLocksRepeatSubmission() {
        let app = launchRosterFixture("roster-create-duplicate")
        openCreateEditorAndEnterRequiredFields(in: app)

        let save = app.buttons["studentEditor.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        expectation(
            for: NSPredicate(format: "enabled == false"),
            evaluatedWith: save
        )
        waitForExpectations(timeout: 5)
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.buttons["studentEditor.cancel"].isEnabled)
    }

    func testCancelIsDisabledWhileServerSaveIsInFlight() {
        let app = launchRosterFixture("roster-create-saving")
        openCreateEditorAndEnterRequiredFields(in: app)

        app.buttons["studentEditor.save"].tap()

        let cancel = app.buttons["studentEditor.cancel"]
        expectation(
            for: NSPredicate(format: "enabled == false"),
            evaluatedWith: cancel
        )
        waitForExpectations(timeout: 5)
        XCTAssertFalse(cancel.isEnabled)
    }

    private func launchRosterFixture(
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

    private func openCreateEditorAndEnterRequiredFields(in app: XCUIApplication) {
        XCTAssertTrue(element("studentRoster.empty", in: app).waitForExistence(timeout: 10))
        app.buttons["Add first student"].tap()
        XCTAssertTrue(element("studentEditor.screen", in: app).waitForExistence(timeout: 5))

        let name = app.textFields["studentEditor.name"]
        XCTAssertTrue(name.exists)
        name.tap()
        name.typeText("Ava Stone")

        let grade = app.textFields["studentEditor.grade"]
        XCTAssertTrue(grade.exists)
        grade.tap()
        grade.typeText("7")
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
