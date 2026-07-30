#if DEBUG
nonisolated struct UITestingLaunchConfiguration: Sendable, Equatable {
    nonisolated enum Fixture: String, Sendable, Equatable {
        case signedOut = "signed-out"
        case authenticationAcceptance = "authentication-acceptance"
        case authenticationRecovery = "authentication-recovery"
        case authenticationAccessSetup = "authentication-access-setup"
        case rosterPopulated = "roster-populated"
        case rosterEmpty = "roster-empty"
        case rosterOffline = "roster-offline"
        case rosterPermissionDenied = "roster-permission-denied"
        case rosterCreateQueued = "roster-create-queued"
        case rosterCreateSaving = "roster-create-saving"
        case rosterArchived = "roster-archived"
        case rosterCreateDuplicate = "roster-create-duplicate"
        case rosterCreateConfirmed = "roster-create-confirmed"
        case rosterWorkflow = "roster-workflow"
        case rosterCachePrime = "roster-cache-prime"
        case rosterCacheOffline = "roster-cache-offline"
        case studentDetailPopulated = "student-detail-populated"
        case studentDetailRelease1 = "student-detail-release1"
        case studentDetailOffline = "student-detail-offline"
        case studentDetailPermissionDenied = "student-detail-permission-denied"
    }

    nonisolated enum ContentSize: String, Sendable, Equatable {
        case accessibility5
    }

    let isUITesting: Bool
    let fixture: Fixture?
    let contentSize: ContentSize?

    init(arguments: [String]) {
        guard arguments.contains("-uiTesting") else {
            self.isUITesting = false
            self.fixture = nil
            self.contentSize = nil
            return
        }
        self.isUITesting = true

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
