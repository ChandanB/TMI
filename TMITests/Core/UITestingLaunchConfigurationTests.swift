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

        #expect(configuration.fixture == .signedOut)
    }

    @Test("Fixture arguments are ignored outside UI testing")
    func fixtureRequiresUITestingMarker() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-fixture", "signed-out"]
        )

        #expect(configuration.fixture == nil)
    }

    @Test("Unknown fixtures fail closed")
    func unknownFixtureFailsClosed() {
        let configuration = UITestingLaunchConfiguration(
            arguments: ["TMI", "-uiTesting", "-fixture", "unknown"]
        )

        #expect(configuration.fixture == nil)
    }
}
#endif
