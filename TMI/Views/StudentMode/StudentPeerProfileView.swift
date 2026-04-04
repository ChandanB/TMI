//
//  StudentPeerProfileView.swift
//  TMI
//
//  Student-safe peer profile showing common interests and connections
//

import SwiftUI

struct StudentPeerProfileView: View {
    let peerStudent: Student
    let currentStudent: Student

    @State private var commonInterests: [Interest] = []
    @State private var peerInterests: [Interest] = []
    @State private var isLoading = true
    @State private var peerTotalInterestCount = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.tmiPrimary)
            } else {
                ScrollView {
                    VStack(spacing: TMISpacing.xl) {
                        // Peer Header
                        peerHeader

                        // Common Interests Section
                        if !commonInterests.isEmpty {
                            commonInterestsSection
                        }

                        // Their Interests Section
                        if !peerInterests.isEmpty {
                            theirInterestsSection
                        }

                        // Connection Message
                        connectionMessage
                    }
                    .padding(TMISpacing.screenPadding)
                }
            }
        }
        .navigationTitle("Classmate")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInterests()
        }
    }

    // MARK: - Peer Header

    private var peerHeader: some View {
        TMICard(style: .default) {
            VStack(spacing: TMISpacing.lg) {
                // Avatar
                TMIAvatar(
                    initials: peerStudent.initials,
                    color: .tmiSecondary,
                    size: 100
                )

                VStack(spacing: 4) {
                    Text(peerStudent.firstName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.tmiTextPrimary)

                    Text("Grade \(peerStudent.grade)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                }

                // Quick Stats
                HStack(spacing: TMISpacing.xl) {
                    statBadge(
                        icon: "heart.fill",
                        count: peerTotalInterestCount,
                        label: "Interests"
                    )

                    statBadge(
                        icon: "person.2.fill",
                        count: commonInterests.count,
                        label: "In Common"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statBadge(icon: String, count: Int, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.tmiPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.tmiTextSecondary)
        }
    }

    // MARK: - Common Interests Section

    private var commonInterestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tmiSuccess)

                Text("You Both Like")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)
            }
            .padding(.horizontal, TMISpacing.xs)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: TMISpacing.sm) {
                ForEach(commonInterests) { interest in
                    CommonInterestCard(interest: interest)
                }
            }
        }
    }

    // MARK: - Their Interests Section

    private var theirInterestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.tmiWarning)

                Text("\(peerStudent.firstName)'s Other Interests")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)
            }
            .padding(.horizontal, TMISpacing.xs)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: TMISpacing.sm) {
                ForEach(peerInterests) { interest in
                    PeerInterestCard(interest: interest)
                }
            }
        }
    }

    // MARK: - Connection Message

    private var connectionMessage: some View {
        TMICard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiPrimary)

                VStack(spacing: 8) {
                    Text("Connect Over Shared Interests")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.tmiTextPrimary)

                    if !commonInterests.isEmpty {
                        Text("You and \(peerStudent.firstName) both love \(commonInterests.first?.name ?? "similar things")! Why not chat about it?")
                            .font(.system(size: 14))
                            .foregroundColor(.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Everyone has unique interests! Learning about \(peerStudent.firstName)'s interests might spark new ideas for you.")
                            .font(.system(size: 14))
                            .foregroundColor(.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(TMISpacing.md)
        }
    }

    // MARK: - Helpers

    private func loadInterests() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch interests for both students
            async let currentInterestsTask = currentStudent.fetchInterestsFromEdgeCollection()
            async let peerInterestsTask = peerStudent.fetchInterestsFromEdgeCollection()

            let (currentList, peerList) = try await (currentInterestsTask, peerInterestsTask)

            let currentMap = Set(currentList.map { $0.id })

            // Common interests
            commonInterests = peerList.filter { interest in
                guard let id = interest.id else { return false }
                return currentMap.contains(id)
            }

            // Peer's unique interests
            peerInterests = peerList.filter { interest in
                guard let id = interest.id else { return true }
                return !currentMap.contains(id)
            }

            peerTotalInterestCount = peerList.count

        } catch {
            print("Error loading peer interests: \(error)")
            // Fallback to empty states
            commonInterests = []
            peerInterests = []
            peerTotalInterestCount = 0
        }
    }
}

// MARK: - Common Interest Card

struct CommonInterestCard: View {
    let interest: Interest

    var body: some View {
        VStack(spacing: TMISpacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.tmiSuccess.opacity(0.3),
                                Color.tmiSuccess.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: interest.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.tmiSuccess)
            }

            VStack(spacing: 4) {
                Text(interest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.tmiTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Shared")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.tmiSuccess)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .stroke(Color.tmiSuccess.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Peer Interest Card

struct PeerInterestCard: View {
    let interest: Interest

    var body: some View {
        VStack(spacing: TMISpacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                interest.color.opacity(0.3),
                                interest.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: interest.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(interest.color)
            }

            VStack(spacing: 4) {
                Text(interest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.tmiTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("Their interest")
                    .font(.system(size: 11))
                    .foregroundColor(.tmiTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StudentPeerProfileView(
            peerStudent: Student.sampleStudents[1],
            currentStudent: Student.sampleStudents[0]
        )
    }
}
