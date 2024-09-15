//
//  DashboardViewModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import SwiftUI
import Combine

class DashboardViewModel: ObservableObject {
    @Published var engagementData: [EngagementData] = []
    @Published var totalStudents: Int = 0
    @Published var activeTMIPlans: Int = 0
    @Published var interestsIdentified: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchDashboardData()
    }
    
    func fetchDashboardData() {
        // Implement your data fetching logic here
        // This could involve Firestore queries or other data sources
        // Update the published properties with the fetched data
    }
}
