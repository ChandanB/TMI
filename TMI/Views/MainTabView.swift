//
//  MainTabView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation state
    @State private var previousTab: Tab = .dashboard
    @State private var tabBarVisible = false
    
    enum Tab: String, CaseIterable, Identifiable {
        case dashboard, students, tmiPlans, interestsAndHobbies, surveys, resources, careerExplorer, settings
        var id: Self { self }
    }
    
    var body: some View {
        ZStack {
            // Background - same style as we used in other views
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content based on device
            Group {
                if sizeClass == .compact {
                    enhancedIOSTabView
                } else {
                    enhancedIPadOSMacOSView
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Animate tab bar appearance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                tabBarVisible = true
            }
        }
    }
    
    // MARK: - iOS Enhanced Tab View
    
    var enhancedIOSTabView: some View {
        ZStack(alignment: .bottom) {
            // Tab Content Area - each view will provide its own navigation title
            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    destinationView(for: tab)
                        .tag(tab)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Gives space for our custom tab bar
                Spacer().frame(height: 70)
            }
            
            // Custom Tab Bar
            PremiumGlassTabBar(
                selectedTab: $selectedTab,
                previousTab: $previousTab
            )
            .offset(y: tabBarVisible ? 0 : 100)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
        }
    }
    
    // MARK: - iPadOS/macOS Enhanced View
    
    var enhancedIPadOSMacOSView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ZStack {
                // Background gradient for sidebar
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.13),
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo and title
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(Color.tmiSecondary)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .opacity(0.8)
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.tmiSecondary.opacity(0.6), .clear, .tmiSecondary.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        
                        Text("TMI")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    
                    // Navigation Menu
                    PremiumSidebarList(selectedTab: $selectedTab)
                        .padding(.top, 10)
                }
            }
        } detail: {
            destinationView(for: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Helper Methods
    
    @ViewBuilder
    func destinationView(for tab: Tab) -> some View {
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
        case .dashboard: return "square.grid.2x2.fill"
        case .students: return "person.3.fill"
        case .tmiPlans: return "doc.text.fill"
        case .interestsAndHobbies: return "heart.fill"
        case .surveys: return "list.clipboard.fill"
        case .resources: return "book.fill"
        case .careerExplorer: return "briefcase.fill"
        case .settings: return "gear"
        }
    }
}

// MARK: - Premium Glass Tab Bar

struct PremiumGlassTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var previousTab: MainTabView.Tab
    @Namespace private var tabAnimation
    
    // Show only the important tabs to avoid crowding on smaller screens
    private let displayedTabs: [MainTabView.Tab] = [
        .dashboard, .students, .tmiPlans, .surveys, .settings
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(displayedTabs) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.2))
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private func tabButton(for tab: MainTabView.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                previousTab = selectedTab
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.tmiSecondary.opacity(0.4),
                                        Color.tmiSecondary.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .matchedGeometryEffect(id: "TabBackground", in: tabAnimation)
                            .frame(height: 40)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                            .symbolEffect(
                                .bounce,
                                options: .speed(1.5),
                                value: selectedTab == tab && previousTab != tab
                            )
                        
                        if selectedTab == tab {
                            Text(shortTabLabel(for: tab))
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.6))
                    .frame(height: 40)
                    .padding(.horizontal, selectedTab == tab ? 14 : 0)
                }
            }
            .frame(maxWidth: selectedTab == tab ? .infinity : 50)
        }
        .buttonStyle(.plain)
    }
    
    private func shortTabLabel(for tab: MainTabView.Tab) -> String {
        switch tab {
        case .tmiPlans: return "Plans"
        case .interestsAndHobbies: return "Interests"
        case .careerExplorer: return "Careers"
        default: return tab.rawValue.capitalized
        }
    }
    
    private func iconName(for tab: MainTabView.Tab) -> String {
        switch tab {
        case .dashboard: return "square.grid.2x2.fill"
        case .students: return "person.3.fill"
        case .tmiPlans: return "doc.text.fill"
        case .interestsAndHobbies: return "heart.fill"
        case .surveys: return "list.clipboard.fill"
        case .resources: return "book.fill"
        case .careerExplorer: return "briefcase.fill"
        case .settings: return "gear"
        }
    }
}

// MARK: - Premium Sidebar List

struct PremiumSidebarList: View {
    @Binding var selectedTab: MainTabView.Tab
    @Namespace private var sidebarAnimation
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(MainTabView.Tab.allCases) { tab in
                    sidebarButton(for: tab)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private func sidebarButton(for tab: MainTabView.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(selectedTab == tab ? Color.tmiSecondary.opacity(0.2) : Color.clear)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName(for: tab))
                        .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? Color.tmiSecondary : Color.white.opacity(0.6))
                }
                
                // Label
                Text(tabLabel(for: tab))
                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? Color.white : Color.white.opacity(0.7))
                
                Spacer()
                
                // Selection indicator
                if selectedTab == tab {
                    Circle()
                        .fill(Color.tmiSecondary)
                        .frame(width: 6, height: 6)
                        .matchedGeometryEffect(id: "SidebarSelection", in: sidebarAnimation)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedTab == tab ? Color.white.opacity(0.05) : Color.clear)
                    .background(
                        selectedTab == tab ?
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .opacity(0.1) : RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .opacity(0)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selectedTab == tab ?
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.clear, Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(SidebarButtonStyle())
    }
    
    private func tabLabel(for tab: MainTabView.Tab) -> String {
        switch tab {
        case .tmiPlans: return "TMI Plans"
        case .interestsAndHobbies: return "Interests & Hobbies"
        case .careerExplorer: return "Career Explorer"
        default: return tab.rawValue.capitalized
        }
    }
    
    private func iconName(for tab: MainTabView.Tab) -> String {
        switch tab {
        case .dashboard: return "square.grid.2x2.fill"
        case .students: return "person.3.fill"
        case .tmiPlans: return "doc.text.fill"
        case .interestsAndHobbies: return "heart.fill"
        case .surveys: return "list.clipboard.fill"
        case .resources: return "book.fill"
        case .careerExplorer: return "briefcase.fill"
        case .settings: return "gear"
        }
    }
}

// MARK: - Sidebar Button Style

struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("iPhone") {
    MainTabView()
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("iPad") {
    MainTabView()
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}
