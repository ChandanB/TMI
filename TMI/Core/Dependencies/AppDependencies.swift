import SwiftUI

struct AppDependencies: Sendable, Equatable {
    let flags: FeatureFlags

    static let production = AppDependencies(flags: .production)
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies = .production
}
