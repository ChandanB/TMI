import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class Release1AcceptanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCredentialSignInSubmitsEnteredCredentials() {
        let app = launch(fixture: "authentication-acceptance")

        let email = app.textFields["authentication.signIn.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("educator@example.org")

        let password = app.secureTextFields["authentication.signIn.password"]
        XCTAssertTrue(password.exists)
#if os(macOS)
        password.tap()
        typeSecureText(
            "release-one-password",
            into: "authentication.signIn.password",
            in: app
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
#else
        pasteSecureText(
            "release-one-password",
            into: "authentication.signIn.password",
            in: app
        )
#endif

        app.buttons["authentication.signIn.logIn"].tap()

        XCTAssertTrue(
            element("studentRoster.empty", in: app)
                .waitForExistence(timeout: 10),
            "Valid credentials must authorize the staff product workspace."
        )
#if !os(macOS)
        XCTAssertTrue(app.navigationBars["Students"].waitForExistence(timeout: 5))
#endif
    }

    func testInvitationOnboardingSubmitsTheStaffInvitation() {
        let app = launch(fixture: "authentication-acceptance")

        app.buttons["authentication.signIn.createAccount"].tap()
        XCTAssertTrue(
            app.textFields["authentication.registration.name"]
                .waitForExistence(timeout: 5)
        )

        enter("Taylor Educator", into: "authentication.registration.name", in: app)
        enter("taylor@example.org", into: "authentication.registration.email", in: app)
        enter("DISTRICT-INVITE-2026", into: "authentication.registration.invitation", in: app)
        pasteSecureText(
            "release-one-password",
            into: "authentication.registration.password",
            in: app
        )
#if os(macOS)
        let registrationScrollViews = app.scrollViews
        XCTAssertGreaterThan(registrationScrollViews.count, 0)
        let registrationScrollView = registrationScrollViews.element(
            boundBy: registrationScrollViews.count - 1
        )
        registrationScrollView.swipeUp()
#endif
        pasteSecureText(
            "release-one-password",
            into: "authentication.registration.confirmPassword",
            in: app
        )
        app.secureTextFields["authentication.registration.confirmPassword"]
            .typeText("\n")

        XCTAssertFalse(
            app.staticTexts["Verify Your Email"].exists,
            "Trusted invitation provisioning must not introduce an email refresh gate."
        )
        XCTAssertTrue(
            element("studentRoster.empty", in: app)
                .waitForExistence(timeout: 10),
            "A valid staff invitation must authorize the staff product workspace."
        )
#if !os(macOS)
        XCTAssertTrue(app.navigationBars["Students"].waitForExistence(timeout: 5))
#endif
    }

    func testConfirmedCreateAppearsInTheRoster() {
        let app = launch(fixture: "roster-create-confirmed")

        XCTAssertTrue(
            element("studentRoster.empty", in: app).waitForExistence(timeout: 10)
        )
        app.buttons["Add first student"].tap()
        enter("Jordan Lee", into: "studentEditor.name", in: app)
        enter("8", into: "studentEditor.grade", in: app)

        app.buttons["studentEditor.save"].tap()

        let created = app.buttons["studentRoster.student.student-created"]
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        XCTAssertTrue(created.label.localizedCaseInsensitiveContains("Jordan Lee"))
        XCTAssertTrue(created.label.localizedCaseInsensitiveContains("grade 8"))
    }

    func testDuplicateCreateShowsCandidateWarningAndRecoveryCopy() {
        let app = launch(fixture: "roster-create-duplicate")

        XCTAssertTrue(
            element("studentRoster.empty", in: app).waitForExistence(timeout: 10)
        )
        app.buttons["Add first student"].tap()
        enter("Ava Stone", into: "studentEditor.name", in: app)
        enter("7", into: "studentEditor.grade", in: app)

        app.buttons["studentEditor.save"].tap()

        let warning = element("studentEditor.duplicates", in: app)
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.label.contains("1 possible duplicate record found"))
        XCTAssertTrue(
            warning.label.contains(
                "Cancel and search the roster by name or identifier before saving."
            )
        )
    }

    func testEditAndSaveUpdatesTheVisibleRosterRecord() {
        let app = launch(fixture: "roster-workflow")

        XCTAssertTrue(
            app.buttons["studentRoster.student.student-ava"].waitForExistence(timeout: 10)
        )
        openActions(for: "Ava Stone", in: app)
        tapRosterAction(
            identifier: "studentRoster.edit.student-ava",
            title: "Edit Student",
            in: app
        )

        let name = app.textFields["studentEditor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        replaceText(
            in: name,
            with: "Ava Stone Updated",
            app: app
        )
        app.buttons["studentEditor.save"].tap()

        let updated = app.buttons["studentRoster.student.student-ava"]
        XCTAssertTrue(
            expectation(
                for: NSPredicate(format: "label CONTAINS[c] %@", "Ava Stone Updated"),
                evaluatedWith: updated
            ).wait(timeout: 5)
        )
    }

    func testSearchFilterAndPaginationShowMatchingResults() {
        let paginationApp = launch(fixture: "roster-workflow")
        XCTAssertTrue(
            paginationApp.buttons["studentRoster.student.student-ava"]
                .waitForExistence(timeout: 10)
        )
        let nextPageStudent =
            paginationApp.buttons["studentRoster.student.student-zoe"]
        for _ in 0..<12 where !nextPageStudent.exists {
            scrollRoster(in: paginationApp)
        }
        XCTAssertTrue(
            nextPageStudent.waitForExistence(timeout: 5),
            "Scrolling the first page should load and reveal the next page."
        )
        paginationApp.terminate()

        let searchApp = launch(fixture: "roster-workflow")
        let search = searchApp.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Mia")
        XCTAssertTrue(
            searchApp.buttons["studentRoster.student.student-mia"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(searchApp.buttons["studentRoster.student.student-ava"].exists)
        searchApp.terminate()

        let filterApp = launch(fixture: "roster-workflow")
        XCTAssertTrue(
            filterApp.buttons["studentRoster.filters"].waitForExistence(timeout: 10)
        )
        filterApp.buttons["studentRoster.filters"].tap()
        enter("8", into: "studentRoster.filter.grade", in: filterApp)
#if os(macOS)
        filterApp.typeKey(.return, modifierFlags: [])
#else
        let applyFilter = filterApp.buttons["studentRoster.filter.apply"]
        applyFilter.tap()
#endif
        XCTAssertTrue(
            filterApp.buttons["studentRoster.student.student-mia"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(filterApp.buttons["studentRoster.student.student-ava"].exists)
    }

    func testArchiveRequiresConfirmationAndRemovesTheActiveRecord() {
        let app = launch(fixture: "roster-workflow")

        XCTAssertTrue(
            app.buttons["studentRoster.student.student-ava"].waitForExistence(timeout: 10)
        )
        openActions(for: "Ava Stone", in: app)
        tapRosterAction(
            identifier: "studentRoster.archive.student-ava",
            title: "Archive Student",
            in: app
        )

        XCTAssertTrue(app.staticTexts["Archive Ava Stone?"].waitForExistence(timeout: 5))
        let destructive = app.buttons.matching(
            NSPredicate(format: "label == %@", "Archive Student")
        ).firstMatch
        XCTAssertTrue(destructive.waitForExistence(timeout: 5))
        destructive.tap()

        let archived = app.buttons["studentRoster.student.student-ava"]
        expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: archived
        )
        waitForExpectations(timeout: 5)
        XCTAssertFalse(archived.exists)
    }

    func testPrimedCacheRestoresOfflineAfterRelaunch() {
        let app = launch(fixture: "roster-cache-prime", resetAcceptanceCache: true)

        XCTAssertTrue(
            app.buttons["studentRoster.student.student-cached"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertFalse(element("studentRoster.offline", in: app).exists)

        app.terminate()
        app.launchArguments = launchArguments(fixture: "roster-cache-offline")
        app.launch()
#if os(macOS)
        app.typeKey("n", modifierFlags: .command)
#endif

        XCTAssertTrue(
            element("studentRoster.offline", in: app).waitForExistence(timeout: 10)
        )
        let cached = app.buttons["studentRoster.student.student-cached"]
        XCTAssertTrue(cached.exists)
        XCTAssertTrue(cached.label.localizedCaseInsensitiveContains("Casey Cached"))
    }

    private func launch(
        fixture: String,
        resetAcceptanceCache: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            fixture: fixture,
            resetAcceptanceCache: resetAcceptanceCache
        )
        app.launch()
#if os(macOS)
        app.typeKey("n", modifierFlags: .command)
#endif
        return app
    }

    private func launchArguments(
        fixture: String,
        resetAcceptanceCache: Bool = false
    ) -> [String] {
        var arguments = [
            "-uiTesting",
            "-fixture", fixture,
            "-ApplePersistenceIgnoreState", "YES",
        ]
        if resetAcceptanceCache {
            arguments.append("-reset-release1-acceptance-cache")
        }
        return arguments
    }

    private func enter(
        _ value: String,
        into identifier: String,
        secure: Bool = false,
        in app: XCUIApplication
    ) {
        let field = secure
            ? app.secureTextFields[identifier]
            : app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(identifier)")
        field.tap()
        if secure {
            typeSecureText(value, into: identifier, in: app)
        } else {
            field.typeText(value)
        }
    }

    private func typeSecureText(
        _ value: String,
        into identifier: String,
        in app: XCUIApplication
    ) {
        // SwiftUI secure fields can discard characters when XCTest delivers a
        // complete string faster than the binding can publish each update.
        // Send to the focused application so a SwiftUI accessibility-element
        // replacement cannot redirect the remaining characters to a stale
        // SecureField instance.
        for character in value {
            XCTAssertTrue(
                app.secureTextFields[identifier].exists,
                "Secure field \(identifier) disappeared while typing."
            )
            app.typeText(String(character))
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func pasteSecureText(
        _ value: String,
        into identifier: String,
        in app: XCUIApplication
    ) {
        let field = app.secureTextFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(identifier)")
        field.tap()
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        app.typeKey("v", modifierFlags: .command)
#else
        UIPasteboard.general.string = value
        field.press(forDuration: 1)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3), "Paste menu did not appear.")
        paste.tap()
        let allowPaste = app.alerts.buttons["Allow Paste"]
        if allowPaste.waitForExistence(timeout: 1) {
            allowPaste.tap()
        }
#endif
    }

    private func replaceText(
        in field: XCUIElement,
        with value: String,
        app: XCUIApplication
    ) {
#if os(macOS)
        app.typeKey("a", modifierFlags: .command)
        field.typeText(value)
#else
        let currentValue = (field.value as? String) ?? ""
        field.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        )
        field.typeText(value)
#endif
    }

    private func openActions(for studentName: String, in app: XCUIApplication) {
        let label = "Actions for \(studentName)"
#if os(macOS)
        let menu = app.menuButtons[label]
#else
        let menu = app.buttons[label]
#endif
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
    }

    private func tapRosterAction(
        identifier: String,
        title: String,
        in app: XCUIApplication
    ) {
#if os(macOS)
        let action = app.menuItems[identifier]
#else
        let action = app.buttons[title]
#endif
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    private func scrollRoster(in app: XCUIApplication) {
#if os(macOS)
        let rosterScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(rosterScrollView.exists)
        rosterScrollView.swipeUp()
#else
        app.swipeUp()
#endif
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}

private extension XCTestExpectation {
    func wait(timeout: TimeInterval) -> Bool {
        XCTWaiter.wait(for: [self], timeout: timeout) == .completed
    }
}
