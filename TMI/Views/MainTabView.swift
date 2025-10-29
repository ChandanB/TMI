//
//  MainTabView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct MainTabView: View {
  @State private var selectedTab: Tab = .dashboard
  @Environment(\.authStateModel) private var authStateModel

  // Student Mode
  @State private var studentModeSession = StudentModeSession()

  // Sheet state
  @State private var showingUserProfile = false
  @State private var showingSignOutConfirmation = false

  // State models
  @State private var interestsStateModel = InterestsAndHobbiesStateModel()

  enum Tab: String, CaseIterable, Identifiable {
    case dashboard, students, tmiPlans, forms, careerExplorer, interests, resources, settings
    var id: Self { self }
    
    // Define which roles can access each tab - MVP focuses on educators
    var allowedRoles: Set<UserRole> {
      switch self {
      case .dashboard:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .parent, .legalGuardian]
      case .students:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker]
      case .tmiPlans:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker]
      case .forms:
        return [] // Temporarily disabled for MVP
      case .careerExplorer:
        return [] // Temporarily disabled for MVP
      case .interests:
        return [] // Temporarily disabled for MVP - [.teacher, .counselor, .administrator, .admin, .socialWorker, .student]
      case .resources:
        return [] // Temporarily disabled for MVP - [.teacher, .counselor, .administrator, .admin, .socialWorker, .parent, .legalGuardian]
      case .settings:
        return [.teacher, .counselor, .administrator, .admin, .socialWorker, .parent, .legalGuardian, .student]
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
  
  // Default tab for MVP - always starts with dashboard
  var defaultTab: Tab {
    return .dashboard
  }

  var body: some View {
    Group {
      if let activeStudent = studentModeSession.activeStudent {
        // Student Mode - Restricted Interface
        StudentModeView(student: activeStudent)
          .environment(\.studentModeSession, studentModeSession)
          .onAppear {
            print("[MainTabView] 🎓 Switched to Student Mode for: \(activeStudent.name)")
          }
      } else {
        // Staff Mode - Full Interface
        staffTabView
          .environment(\.studentModeSession, studentModeSession)
          .onAppear {
            print("[MainTabView] 👨‍💼 In Staff Mode")
          }
      }
    }
  }

  // MARK: - Staff Tab View

  private var staffTabView: some View {
    TabView(selection: $selectedTab) {
      ForEach(availableTabs, id: \.self) { tab in
        NavigationStack {
          destinationView(for: tab)
            .navigationTitle(tabLabel(for: tab))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
              ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                  Button {
                    showingUserProfile = true
                  } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                  }
                  
                  Divider()
                  
                  Button(role: .destructive) {
                    showingSignOutConfirmation = true
                  } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                  }
                } label: {
                  Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                }
              }
            }
        }
        .tabItem {
          Label(tabLabel(for: tab), systemImage: iconName(for: tab))
        }
        .tag(tab)
      }
    }
    .accentColor(.tmiSecondary)
    .sheet(isPresented: $showingUserProfile) {
      UserProfileView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }
    .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
      Button("Sign Out", role: .destructive) {
        authStateModel.signOut()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to sign out?")
    }
    .onAppear {
      // Set appropriate default tab for user role
      if availableTabs.contains(defaultTab) && selectedTab != defaultTab {
        selectedTab = defaultTab
      }
    }
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
      TMIPlanListView()
    case .forms:
      FormsAndSurveysView()
    case .careerExplorer:
      CareerExplorerView()
    case .interests:
        InterestsAndHobbiesView()
            .environment(\.interestsStateModel, interestsStateModel)
    case .resources:
      ResourcesView()
    case .settings:
      SettingsView()
    }
  }

  func tabLabel(for tab: Tab) -> String {
    switch tab {
    case .dashboard: return "Dashboard"
    case .students: return "Students"
    case .tmiPlans: return "TMI Plans"
    case .forms: return "Forms & Surveys"
    case .careerExplorer: return "Career Explorer"
    case .interests: return "Interests & Hobbies"
    case .resources: return "Resources"
    case .settings: return "Settings"
    }
  }

  func iconName(for tab: Tab) -> String {
    switch tab {
    case .dashboard: return "chart.bar.fill"
    case .students: return "person.3.fill"
    case .tmiPlans: return "doc.text.fill"
    case .forms: return "list.clipboard.fill"
    case .careerExplorer: return "briefcase.fill"
    case .interests: return "heart.fill"
    case .resources: return "books.vertical.fill"
    case .settings: return "gearshape.fill"
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

