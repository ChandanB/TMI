import XCTest

/// Opt-in design review captures: set `TMI_UI_SNAPSHOTS=1` for the test runner
/// (for example `TEST_RUNNER_TMI_UI_SNAPSHOTS=1 xcodebuild test …`). Each
/// fixture is launched and its screenshot is kept as an attachment in the
/// result bundle, in light and dark. Skipped in normal runs.
@MainActor
final class DesignSnapshotUITests: XCTestCase {
    private let fixtures = [
        "signed-out",
        "app-shell",
        "dashboard",
        "roster-populated",
        "student-detail-populated",
        "plan-workflow",
        "district-report",
        "staff-administration",
        "career-discovery",
        "student-mode-survey",
    ]

    func testCaptureDesignSnapshots() throws {
        guard ProcessInfo.processInfo.environment["TMI_UI_SNAPSHOTS"] == "1" else {
            throw XCTSkip("Set TMI_UI_SNAPSHOTS=1 to capture design snapshots.")
        }
        for appearance in ["light", "dark"] {
            for fixture in fixtures {
                let app = XCUIApplication()
                app.launchArguments = [
                    "-uiTesting", "-fixture", fixture,
                    "-appearance", appearance,
                    "-ApplePersistenceIgnoreState", "YES",
                ]
                app.launch()
                _ = app.windows.firstMatch.waitForExistence(timeout: 10)
                Thread.sleep(forTimeInterval: 4)
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "\(fixture)-\(appearance)"
                attachment.lifetime = .keepAlways
                add(attachment)
                app.terminate()
            }
            captureAccountScreens(appearance: appearance)
        }
    }

    /// Settings and Profile are reached through the shell's account menu.
    private func captureAccountScreens(appearance: String) {
        for destination in ["Settings", "Profile"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-uiTesting", "-fixture", "app-shell",
                "-appearance", appearance,
                "-ApplePersistenceIgnoreState", "YES",
            ]
            app.launch()
            let account = app.buttons["Account"].firstMatch
            guard account.waitForExistence(timeout: 10) else { continue }
            account.tap()
            let item = app.buttons[destination].firstMatch
            guard item.waitForExistence(timeout: 3) else { continue }
            item.tap()
            Thread.sleep(forTimeInterval: 3)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(destination.lowercased())-\(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
