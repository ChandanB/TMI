#if DEBUG
import SwiftUI

/// `-uiTesting -fixture dashboard`: Today inside the real shell, signed in as
/// a counselor who can approve plans, backed by in-memory fixtures.
struct DashboardUITestingContent: View {
    var body: some View {
        AppShellUITestingContent(role: .counselor)
            .accessibilityIdentifier("dashboard.fixture")
    }
}
#endif
