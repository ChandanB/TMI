//
//  StudentMainView.swift
//  TMI
//
//  Student-focused interface showing their interests, progress, and activities
//

import SwiftUI

struct StudentMainView: View {
    @Environment(\.authStateModel) private var authStateModel
    @State private var selectedTab: StudentTab = .myInterests
    @State private var showingProfile = false
    @State private var showingSignOutConfirmation = false

    enum StudentTab: String, CaseIterable, Identifiable {
        case myInterests = "My Interests"
        case myProgress = "My Progress"
        case activities = "Activities"
        case profile = "Profile"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .myInterests: return "star.fill"
            case .myProgress: return "chart.line.uptrend.xyaxis"
            case .activities: return "list.bullet.clipboard"
            case .profile: return "person.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(StudentTab.allCases) { tab in
                NavigationStack {
                    destinationView(for: tab)
                        .navigationTitle(tab.rawValue)
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    Button {
                                        showingProfile = true
                                    } label: {
                                        Label("My Profile", systemImage: "person.crop.circle")
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
                                        .foregroundColor(Color.tmiTextPrimary)
                                }
                            }
                        }
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(.tmiPrimary)
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    authStateModel.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    @ViewBuilder
    private func destinationView(for tab: StudentTab) -> some View {
        switch tab {
        case .myInterests:
            MyInterestsTabView()
        case .myProgress:
            MyProgressTabView()
        case .activities:
            MyActivitiesTabView()
        case .profile:
            MyProfileTabView()
        }
    }
}

// MARK: - My Interests Tab

struct MyInterestsTabView: View {
    var body: some View {
        // InterestsAndHobbiesView already handles its own data fetching
        // No need to wrap it or call fetch again
        InterestsAndHobbiesView()
    }
}

// MARK: - My Progress Tab

struct MyProgressTabView: View {
    @Environment(\.authStateModel) private var authStateModel

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Progress")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.tmiTextPrimary)

                        Text("Track your growth and achievements")
                            .font(.system(size: 16))
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Progress content placeholder
                    TMICard(style: .default) {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 50))
                                .foregroundColor(.tmiPrimary)

                            Text("Your Progress")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            Text("View your achievements and track your goals here.")
                                .font(.caption)
                                .foregroundColor(Color.tmiTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - My Activities Tab

struct MyActivitiesTabView: View {
    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Activities")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.tmiTextPrimary)

                        Text("Recommended activities based on your interests")
                            .font(.system(size: 16))
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Activities placeholder
                    TMICard(style: .default) {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 50))
                                .foregroundColor(.tmiSecondary)

                            Text("Your Activities")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            Text("Discover activities tailored to your interests.")
                                .font(.caption)
                                .foregroundColor(Color.tmiTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - My Profile Tab

struct MyProfileTabView: View {
    @Environment(\.authStateModel) private var authStateModel

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack(spacing: 16) {
                        TMIAvatar(
                            initials: authStateModel.currentUser?.displayName.prefix(2).uppercased() ?? "ST",
                            color: .tmiPrimary,
                            size: 100
                        )

                        Text(authStateModel.currentUser?.displayName ?? "Student")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(authStateModel.currentUser?.email ?? "")
                            .font(.system(size: 16))
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                    .padding(.top, 40)

                    // Profile info cards
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About Me")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)

                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.tmiPrimary)
                                Text("Student")
                                    .foregroundColor(Color.tmiTextSecondary)
                            }

                            if let email = authStateModel.currentUser?.email {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.tmiPrimary)
                                    Text(email)
                                        .foregroundColor(Color.tmiTextSecondary)
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    StudentMainView()
        .environment(\.authStateModel, AuthStateModel())
        .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
}
