//
//  CareerExplorerHelpers.swift
//  TMI
//
//  Created by Antigravity on 12/26/25.
//

import SwiftUI

// MARK: - Environment Keys

private struct CareerExplorerStateModelKey: EnvironmentKey {
    @MainActor static let defaultValue = CareerExplorerStateModel()
}

extension EnvironmentValues {
    var careerExplorerStateModel: CareerExplorerStateModel {
        get { self[CareerExplorerStateModelKey.self] }
        set { self[CareerExplorerStateModelKey.self] = newValue }
    }
}
