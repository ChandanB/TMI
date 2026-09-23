#if DEBUG
import SwiftUI

/// `-uiTesting -fixture dashboard`: the Today screen with in-memory data.
/// Owned by the Dashboard work package, which replaces this placeholder.
struct DashboardUITestingContent: View {
    var body: some View {
        NavigationStack {
            TMIEmptyState(
                icon: "sun.horizon",
                title: "Dashboard fixture",
                message: "The Today screen fixture is not wired up yet."
            )
            .navigationTitle("Today")
        }
        .accessibilityIdentifier("dashboard.fixture")
    }
}
#endif
