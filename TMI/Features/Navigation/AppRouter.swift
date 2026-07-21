import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard {
        didSet {
            guard availableTabs.contains(selectedTab) else {
                selectedTab = oldValue
                return
            }
            if selectedTab != oldValue {
                path.removeAll()
            }
        }
    }
    var path: [AppRoute] = []
    private(set) var activeStudentID: String?
    private(set) var activeStudentName: String?
    private(set) var activeStudent: Student?
    private(set) var activePlanID: String?
    private(set) var activePlan: TMIPlan?
    private(set) var pendingDeepLink: AppRoute?
    var presentedSheet: AppSheet?
    private var policy: AppNavigationPolicy

    init(policy: AppNavigationPolicy = AppNavigationPolicy(role: nil)) {
        self.policy = policy
    }

    var availableTabs: [AppTab] {
        policy.availableTabs
    }

    func updatePolicy(_ policy: AppNavigationPolicy) {
        guard self.policy != policy else { return }

        let preservesColdLaunchDeepLink = self.policy.role == nil && policy.role != nil
        let queuedDeepLink = preservesColdLaunchDeepLink ? pendingDeepLink : nil
        self.policy = policy
        path.removeAll()
        activeStudentID = nil
        activeStudentName = nil
        activeStudent = nil
        activePlanID = nil
        activePlan = nil
        pendingDeepLink = queuedDeepLink
        presentedSheet = nil

        if !availableTabs.contains(selectedTab) {
            selectedTab = .dashboard
        }
    }

    func select(_ tab: AppTab) throws {
        guard availableTabs.contains(tab) else {
            throw NavigationError.unavailableTab
        }

        selectedTab = tab
        path.removeAll()
    }

    func open(_ route: AppRoute) throws {
        try validate(route)

        if let tab = route.tab {
            guard availableTabs.contains(tab) else {
                throw NavigationError.unavailableTab
            }
            selectedTab = tab
        }

        if case .student(let studentID) = route {
            if activeStudentID != studentID {
                activeStudentName = nil
                activeStudent = nil
            }
            activeStudentID = studentID
        }

        if case .plan(let planID) = route {
            activePlanID = planID
            if activePlan?.id != planID {
                activePlan = nil
            }
        }

        path.append(route)
    }

    func open(_ student: Student) throws {
        guard let studentID = student.id,
              TrustedIdentifier.isValid(studentID) else {
            throw NavigationError.invalidIdentifier
        }
        guard policy.canReadStudent(student) else {
            throw NavigationError.unauthorizedRoute
        }

        selectedTab = .students
        activeStudentID = studentID
        activeStudentName = student.displayName
        activeStudent = student
        activePlanID = nil
        activePlan = nil
        path.append(.student(studentID))
    }

    func open(_ plan: TMIPlan) throws {
        guard let planID = plan.id, TrustedIdentifier.isValid(planID) else {
            throw NavigationError.invalidIdentifier
        }
        guard policy.canReadPlan(plan) else {
            throw NavigationError.unauthorizedRoute
        }

        selectedTab = .plans
        activePlanID = planID
        activePlan = plan
        path.append(.plan(planID))
    }

    func openDeepLink(_ url: URL) throws {
        guard let route = DeepLinkRouter.route(for: url) else {
            throw NavigationError.unsupportedDeepLink
        }

        try open(route)
    }

    func enqueueDeepLink(_ url: URL) throws {
        guard let route = DeepLinkRouter.route(for: url) else {
            throw NavigationError.unsupportedDeepLink
        }

        pendingDeepLink = route
        try resumePendingDeepLink()
    }

    func resumePendingDeepLink() throws {
        guard policy.role != nil, let route = pendingDeepLink else {
            return
        }

        defer { pendingDeepLink = nil }
        try open(route)
    }

    @discardableResult
    func setActiveStudent(id: String, displayName: String) -> Bool {
        let studentName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard TrustedIdentifier.isValid(id), policy.canReadStudent(id) else {
            clearActiveStudent()
            return false
        }

        activeStudentID = id
        activeStudentName = studentName.isEmpty ? nil : studentName
        if activeStudent?.id != id {
            activeStudent = nil
        }
        activePlanID = nil
        activePlan = nil
        return true
    }

    @discardableResult
    func setActiveStudent(_ student: Student) -> Bool {
        guard let studentID = student.id,
              TrustedIdentifier.isValid(studentID),
              policy.canReadStudent(student) else {
            clearActiveStudent()
            return false
        }

        activeStudentID = studentID
        activeStudentName = student.displayName
        activeStudent = student
        activePlanID = nil
        activePlan = nil
        return true
    }

    func setActivePlan(id: String?) {
        guard let id else {
            activePlanID = nil
            activePlan = nil
            return
        }

        guard TrustedIdentifier.isValid(id) else {
            activePlanID = nil
            activePlan = nil
            return
        }
        activePlanID = id
        if activePlan?.id != id {
            activePlan = nil
        }
    }

    func clearActiveStudent() {
        activeStudentID = nil
        activeStudentName = nil
        activeStudent = nil
        activePlanID = nil
        activePlan = nil
    }

    func present(_ sheet: AppSheet) throws {
        if sheet == .workspace {
            let mayReadStudent = if let activeStudent {
                policy.canReadStudent(activeStudent)
            } else if let activeStudentID {
                policy.canReadStudent(activeStudentID)
            } else {
                false
            }
            guard mayReadStudent else {
                throw NavigationError.unauthorizedRoute
            }
        }
        presentedSheet = sheet
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func reset() {
        selectedTab = .dashboard
        path.removeAll()
        clearActiveStudent()
        pendingDeepLink = nil
        presentedSheet = nil
    }

    private func validate(_ route: AppRoute) throws {
        switch route {
        case .student(let studentID):
            let identifier = try validIdentifier(studentID)
            guard policy.canReadStudent(identifier) else {
                throw NavigationError.unauthorizedRoute
            }

        case .editStudent(let studentID):
            let identifier = try validIdentifier(studentID)
            guard let activeStudentID else {
                throw NavigationError.missingStudentContext
            }
            guard activeStudentID == identifier else {
                throw NavigationError.staleStudentContext
            }
            let mayEdit = if let activeStudent {
                policy.canEditStudent(activeStudent)
            } else {
                policy.canEditStudent(identifier)
            }
            guard mayEdit else {
                throw NavigationError.unauthorizedRoute
            }

        case .plan(let planID):
            let identifier = try validIdentifier(planID)
            guard policy.canReadPlan(identifier) else {
                throw NavigationError.unauthorizedRoute
            }

        case .profile, .settings:
            guard policy.role != nil else {
                throw NavigationError.unauthorizedRoute
            }
        }
    }

    private func validIdentifier(_ identifier: String) throws -> String {
        guard TrustedIdentifier.isValid(identifier) else {
            throw NavigationError.invalidIdentifier
        }
        return identifier
    }
}
