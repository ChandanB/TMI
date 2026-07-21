#if DEBUG
nonisolated struct UITestingLaunchConfiguration: Sendable, Equatable {
    nonisolated enum Fixture: String, Sendable, Equatable {
        case signedOut = "signed-out"
    }

    nonisolated enum ContentSize: String, Sendable, Equatable {
        case accessibility5
    }

    let fixture: Fixture?
    let contentSize: ContentSize?

    init(arguments: [String]) {
        guard arguments.contains("-uiTesting") else {
            self.fixture = nil
            self.contentSize = nil
            return
        }

        func value(after flag: String) -> String? {
            guard let flagIndex = arguments.firstIndex(of: flag) else {
                return nil
            }
            let valueIndex = arguments.index(after: flagIndex)
            guard valueIndex < arguments.endIndex else {
                return nil
            }
            return arguments[valueIndex]
        }

        self.fixture = value(after: "-fixture").flatMap(Fixture.init(rawValue:))
        self.contentSize = value(after: "-content-size").flatMap(ContentSize.init(rawValue:))
    }
}
#endif
