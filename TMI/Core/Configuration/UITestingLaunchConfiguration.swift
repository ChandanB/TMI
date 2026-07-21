#if DEBUG
nonisolated struct UITestingLaunchConfiguration: Sendable, Equatable {
    nonisolated enum Fixture: String, Sendable, Equatable {
        case signedOut = "signed-out"
    }

    let fixture: Fixture?

    init(arguments: [String]) {
        guard arguments.contains("-uiTesting"),
              let fixtureFlagIndex = arguments.firstIndex(of: "-fixture") else {
            self.fixture = nil
            return
        }

        let fixtureValueIndex = arguments.index(after: fixtureFlagIndex)
        guard fixtureValueIndex < arguments.endIndex else {
            self.fixture = nil
            return
        }

        self.fixture = Fixture(rawValue: arguments[fixtureValueIndex])
    }
}
#endif
