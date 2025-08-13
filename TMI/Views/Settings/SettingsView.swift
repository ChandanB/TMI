//
//  SettingsView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import FirebaseAuth
import Foundation
import SwiftUI

struct SettingsView: View {
  @AppStorage("darkModeEnabled") private var darkModeEnabled = false
  @AppStorage("notificationsEnabled") private var notificationsEnabled = true

  @State private var showingLogoutAlert = false
  @State private var isLoggedOut = false

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Account")) {
          NavigationLink(destination: UserProfileView()) {
            HStack {
              Image(systemName: "person.circle")
                .foregroundColor(Color.tmiPrimary)
              Text("User Profile")
            }
          }

          if let user = Auth.auth().currentUser {
            HStack {
              Text("Email")
              Spacer()
              Text(user.email ?? "Not available")
                .foregroundColor(.secondary)
            }
          }
        }

        Section(header: Text("App Preferences")) {
          Toggle("Dark Mode", isOn: $darkModeEnabled)
          Toggle("Enable Notifications", isOn: $notificationsEnabled)
        }

        Section(header: Text("Data Management")) {
          Button("Export Data") {
            // Future: Implement comprehensive data export functionality
            print("Data export functionality coming soon")
            // This would export students, TMI plans, forms, and other user data
          }
          Button("Import Data") {
            // Future: Implement data import functionality
            print("Data import functionality coming soon")
            // This would allow importing CSV, JSON, or other data formats
          }
        }

        Section(header: Text("App Information")) {
          LabeledContent("Version", value: "1.0.0")
          LabeledContent("Build", value: "100")
          Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
          Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
        }

        Section {
          Button("Log Out", role: .destructive) {
            showingLogoutAlert = true
          }
        }
      }
      .navigationTitle("Settings")
      .alert("Log Out", isPresented: $showingLogoutAlert) {
        Button("Cancel", role: .cancel) {}
        Button("Log Out", role: .destructive) {
          logOut()
        }
      } message: {
        Text("Are you sure you want to log out?")
      }
      .fullScreenCover(isPresented: $isLoggedOut) {
        AuthenticationView()
      }
    }
  }

  private func logOut() {
    do {
      try FIREBASE_MANAGER.signOut()
      isLoggedOut = true
    } catch {
      print("Error signing out: \(error.localizedDescription)")
    }
  }
}

#Preview {
  SettingsView()
}
