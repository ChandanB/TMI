#if DEBUG
import Testing
@testable import TMI

@Suite("UI testing launch configuration")
struct UITestingLaunchConfigurationTests {
    @Test("Explicit UI testing arguments select the signed-out fixture")
    func explicitArgumentsSelectSignedOutFixture() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-uiTesting", "-fixture", "signed-out"]
        )

        #expect(configuration.isUITesting)
        #expect(configuration.fixture == .signedOut)
        #expect(configuration.contentSize == nil)
    }

    @Test("Explicit UI testing arguments select the largest accessibility text size")
    func explicitArgumentsSelectLargestAccessibilityTextSize() {
        let configuration = UITestingLaunchConfiguration(
            arguments: [
                "TMI",
                "-uiTesting",
                "-fixture", "signed-out",
                "-content-size", "accessibility5",
            ]
        )

        #expect(configuration.fixture == .signedOut)
        #expect(configuration.contentSize == .accessibility5)
    }

    @Test("Explicit UI testing arguments select deterministic roster fixtures")
    func explicitArgumentsSelectRosterFixtures() {
        let fixtures: [(String, UITestingLaunchConfiguration.Fixture)] = [
            ("roster-populated", .rosterPopulated),
            ("roster-empty", .rosterEmpty),
            ("roster-offline", .rosterOffline),
            ("roster-permission-denied", .rosterPermissionDenied),
            ("roster-create-queued", .rosterCreateQueued),
            ("roster-create-saving", .rosterCreateSaving),
            ("roster-archived", .rosterArchived),
            ("roster-create-duplicate", .rosterCreateDuplicate),
        ]

        for (rawValue, expected) in fixtures {
            let configuration = UITestingLaunchConfiguration(
                arguments: ["TMI", "-uiTesting", "-fixture", rawValue]
            )

            #expect(configuration.fixture == expected)
        }
    }

    @Test("Fixture arguments are ignored outside UI testing")
    func fixtureRequiresUITestingMarker() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-fixture", "signed-out"]
        )

        #expect(!configuration.isUITesting)
        #expect(configuration.fixture == nil)
        #expect(configuration.contentSize == nil)
    }

    @Test("Unknown fixtures fail closed")
    func unknownFixtureFailsClosed() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-uiTesting", "-fixture", "unknown"]
        )

        #expect(configuration.isUITesting)
        #expect(configuration.fixture == nil)
        #expect(configuration.contentSize == nil)
    }

    @Test("A missing fixture remains a fail-closed UI testing launch")
    func missingFixtureFailsClosed() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-uiTesting"]
        )

        #expect(configuration.isUITesting)
        #expect(configuration.fixture == nil)
    }
}
#endif
