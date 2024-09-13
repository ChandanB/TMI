//
//  SettingsView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userRole") private var userRole: String = "Teacher"
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("User Profile")) {
                    TextField("Name", text: $userName)
                    Picker("Role", selection: $userRole) {
                        Text("Teacher").tag("Teacher")
                        Text("Administrator").tag("Administrator")
                        Text("Support Staff").tag("Support Staff")
                    }
                }
                
                Section(header: Text("App Preferences")) {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                Section(header: Text("Data Management")) {
                    Button("Export Data") {
                        // TODO: Implement data export functionality
                    }
                    Button("Import Data") {
                        // TODO: Implement data import functionality
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
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    // TODO: Implement logout functionality
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}

#Preview {
    SettingsView()
}
