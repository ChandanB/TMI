//
//  MainTabView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: String, CaseIterable, Identifiable {
        case dashboard, students, tmiPlans, interestsAndHobbies, settings
        var id: Self { self }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                destinationView(for: tab)
            }
        }
        .frame(maxHeight: .infinity)
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(.tmiPrimary)
        .tint(.tmiPrimary)
    }
    
    @ViewBuilder
    func destinationView(for tab: Tab) -> some View {
        Group {
            switch tab {
            case .dashboard:
                DashboardView() 
                    .tabItem {
                        Label(tab.rawValue.capitalized, systemImage: iconName(for: tab))
                    }
            case .students:
                StudentListView()
                    .tabItem {
                        Label(tab.rawValue.capitalized, systemImage: iconName(for: tab))
                    }
            case .tmiPlans:
                TMIPlanListView(tmiPlans: [TMIPlan.samplePlan])
                    .tabItem {
                        Label("TMI Plans", systemImage: iconName(for: tab))
                    }
            case .interestsAndHobbies:
                InterestsAndHobbiesView(interests: Interest.sampleInterests, hobbies: Hobby.sampleHobbies)
                    .tabItem {
                        Label("Interests", systemImage: iconName(for: tab))
                    }
            case .settings:
                SettingsView()
                    .tabItem {
                        Label(tab.rawValue.capitalized, systemImage: iconName(for: tab))
                    }
            }
        }
        .tag(tab)
    }
    
    func iconName(for tab: Tab) -> String {
        switch tab {
        case .dashboard: return "square.grid.2x2"
        case .students: return "person.3"
        case .tmiPlans: return "doc.text"
        case .interestsAndHobbies: return "heart"
        case .settings: return "gear"
        }
    }
}

#Preview {
    Group {
        MainTabView()
    }
}
