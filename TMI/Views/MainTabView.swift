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
        case dashboard, students, tmiPlans, interestsAndHobbies, surveys, resources, careerExplorer, settings
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
            case .students:
                StudentListView()
            case .tmiPlans:
                TMIPlanListView(tmiPlans: [TMIPlan.samplePlan])
            case .interestsAndHobbies:
                InterestsAndHobbiesView(interests: Interest.sampleInterests, hobbies: Hobby.sampleHobbies)
            case .surveys:
                FormsAndSurveysView()
            case .resources:
                ResourcesView()
            case .careerExplorer:
                CareerExplorerView()
            case .settings:
                SettingsView()
            }
        }
        .tabItem {
            Label(tabLabel(for: tab), systemImage: iconName(for: tab))
        }
        .tag(tab)
    }
    
    func tabLabel(for tab: Tab) -> String {
        switch tab {
        case .tmiPlans: return "TMI Plans"
        case .interestsAndHobbies: return "Interests & Hobbies"
        case .careerExplorer: return "Career Explorer"
        default: return tab.rawValue.capitalized
        }
    }
    
    func iconName(for tab: Tab) -> String {
        switch tab {
        case .dashboard: return "square.grid.2x2"
        case .students: return "person.3"
        case .tmiPlans: return "doc.text"
        case .interestsAndHobbies: return "heart"
        case .surveys: return "list.clipboard"
        case .resources: return "book"
        case .careerExplorer: return "briefcase"
        case .settings: return "gear"
        }
    }
}

#Preview {
    MainTabView()
}
