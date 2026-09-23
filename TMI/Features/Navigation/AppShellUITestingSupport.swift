#if DEBUG
import SwiftUI

/// `-uiTesting -fixture app-shell`: the staff shell (tabs / sidebar) with
/// in-memory data. Owned by the Shell work package, which replaces this placeholder.
struct AppShellUITestingContent: View {
    var body: some View {
        NavigationStack {
            TMIEmptyState(
                icon: "sidebar.left",
                title: "App shell fixture",
                message: "The staff shell fixture is not wired up yet."
            )
        }
        .accessibilityIdentifier("appShell.fixture")
    }
}
#endif
