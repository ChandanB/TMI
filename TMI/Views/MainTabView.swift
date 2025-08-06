//
//  MainTabView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct MainTabView: View {
  @State private var selectedTab: Tab = .students
  @State private var columnVisibility = NavigationSplitViewVisibility.automatic
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.authStateModel) private var authStateModel

  // Animation state
  @State private var previousTab: Tab = .students
  @State private var tabBarVisible = false

  enum Tab: String, CaseIterable, Identifiable {
    case students, tmiPlans
    var id: Self { self }
    
    // Define which roles can access each tab - MVP focuses on educators
    var allowedRoles: Set<UserRole> {
      switch self {
      case .students:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker]
      case .tmiPlans:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker]
      }
    }
    
    // Check if tab is accessible by current user role
    func isAccessible(for role: UserRole?) -> Bool {
      guard let role = role else { return false }
      return allowedRoles.contains(role)
    }
  }
  
  // Computed property to get tabs accessible to current user
  var availableTabs: [Tab] {
    let currentRole = authStateModel.currentUser?.role
    return Tab.allCases.filter { tab in
      tab.isAccessible(for: currentRole)
      
      // Future enhancement: Additional verification checks could be added here
      // For example:
      // && (!tab.requiresAdvancedVerification || authStateModel.currentUser?.canAccessAdvancedFeatures() == true)
      // This would hide tabs requiring additional verification until the user completes it
    }
  }
  
  // Default tab for MVP - always starts with students
  var defaultTab: Tab {
    return .students
  }

  var body: some View {
    ZStack {
      // Background - same style as we used in other views
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.08, green: 0.08, blue: 0.15),
          Color(red: 0.14, green: 0.14, blue: 0.25),
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
      .tabViewStyle(.sidebarAdaptable)
    }
    .preferredColorScheme(.dark)
    .foregroundColor(.white)
    .foregroundStyle(.white)
    .onAppear {
      // Set appropriate default tab for user role
      if availableTabs.contains(defaultTab) && selectedTab != defaultTab {
        selectedTab = defaultTab
      }
      
      // Animate tab bar appearance
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
        tabBarVisible = true
      }
    }
  }

  // MARK: - iOS  Tab View

  var enhancedIOSTabView: some View {
    ZStack(alignment: .bottom) {
      // Tab Content Area - each view will provide its own navigation title
      TabView(selection: $selectedTab) {
        ForEach(availableTabs, id: \.id) { tab in
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
        previousTab: $previousTab,
        availableTabs: availableTabs
      )
      .offset(y: tabBarVisible ? 0 : 100)
    }
    .onChange(of: selectedTab) { oldValue, newValue in
      previousTab = oldValue
    }
  }

  // MARK: - iPadOS/macOS  View

  var enhancedIPadOSMacOSView: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      ZStack {
        // Background gradient for sidebar
        LinearGradient(
          gradient: Gradient(colors: [
            Color(red: 0.06, green: 0.06, blue: 0.13),
            Color(red: 0.1, green: 0.1, blue: 0.2),
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
          PremiumSidebarList(selectedTab: $selectedTab, availableTabs: availableTabs)
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
    case .students:
      StudentListView()
    case .tmiPlans:
      TMIPlanListView()
    }
  }

  func tabLabel(for tab: Tab) -> String {
    switch tab {
    case .students: return "Students"
    case .tmiPlans: return "TMI Plans"
    }
  }

  func iconName(for tab: Tab) -> String {
    switch tab {
    case .students: return "person.3.fill"
    case .tmiPlans: return "doc.text.fill"
    }
  }
}

// MARK: - Preview

#Preview("iPhone") {
  MainTabView()
}

#Preview("iPad") {
  MainTabView()
}

