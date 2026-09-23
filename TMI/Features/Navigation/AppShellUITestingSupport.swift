#if DEBUG
import SwiftUI

/// `-uiTesting -fixture app-shell`: the real staff shell (tabs on iPhone,
/// sidebar on iPad and Mac) signed in as a school administrator, backed by
/// in-memory roster and plan fixtures. No Firebase is touched.
struct AppShellUITestingContent: View {
    @State private var authStateModel: AuthStateModel
    @State private var studentContext = StudentContextStateModel()
    @State private var router = AppRouter()
    @State private var dashboardStateModel: DashboardStateModel
    @State private var hasSignedIn = false

    private let dependencies: AppDependencies

    init() {
        let students = StudentRosterUITestingData.populatedRepository()
        let plans = PlanWorkflowUITestingData.store()
        let membership = StaffShellUITestingSession.membership(
            role: .schoolAdministrator,
            capabilities: [.studentReadDetail, .studentWriteDetail, .planApprove, .reportExport, .staffManage]
        )
        let session = StaffShellUITestingSession.make(membership: membership) { membershipProvider, authentication in
            AppDependencies(
                runtime: .preview,
                flags: .production,
                membership: membershipProvider,
                authentication: authentication,
                studentRepository: students,
                studentDetailRepository: Release1StudentDetailRepository(students: students),
                planRepository: plans,
                planChildRepository: plans,
                planExportAuditing: PlanWorkflowUITestingData.auditing,
                logger: TMILogger(category: "AppShellUITesting")
            )
        }
        dependencies = session.dependencies
        _authStateModel = State(initialValue: session.auth)
        _dashboardStateModel = State(
            initialValue: DashboardStateModel(studentRepository: students, planRepository: plans)
        )
    }

    var body: some View {
        Group {
            if authStateModel.isLoggedIn {
                MainTabView()
            } else {
                LoadingView()
            }
        }
        .environment(\.appDependencies, dependencies)
        .environment(\.authStateModel, authStateModel)
        .environment(\.studentContext, studentContext)
        .environment(\.dashboardStateModel, dashboardStateModel)
        .environment(router)
        .task {
            guard !hasSignedIn else { return }
            hasSignedIn = true
            // Registers the identity listener that publishes the session.
            await authStateModel.fetch()
            authStateModel.updateEmail(StaffShellUITestingSession.email)
            authStateModel.updatePassword(StaffShellUITestingSession.password)
            await authStateModel.signIn()
        }
        .accessibilityIdentifier("appShell.fixture")
    }
}
#endif
