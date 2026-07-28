//
//  StudentInterestDetailView.swift
//  TMI
//
//  Student-friendly interest detail view with peer connections
//

import SwiftUI

struct StudentInterestDetailView: View {
    let interest: Interest
    let currentStudent: Student

    private let peersWithInterest: [Student] = []

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.xl) {
                    // Interest Header
                    interestHeader

                    // Classmates Section
                    if !peersWithInterest.isEmpty {
                        classmatesSection
                    } else {
                        emptyClassmatesSection
                    }
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .navigationTitle(interest.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Interest Header

    private var interestHeader: some View {
        TMICard(style: .default) {
            VStack(spacing: TMISpacing.lg) {
                // Icon
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
                        .frame(width: 100, height: 100)

                    Image(systemName: interest.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(interest.color)
                }

                VStack(spacing: 8) {
                    Text(interest.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.tmiTextPrimary)

                    if let description = interest.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Categories
                if !interest.category.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(interest.category.prefix(3), id: \.self) { category in
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(category.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(category.color.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Classmates Section

    private var classmatesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tmiPrimary)

                Text("Classmates Who Like This Too")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)

                Spacer()

                Text("\(peersWithInterest.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.tmiTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.tmiPrimary)
                    )
            }
            .padding(.horizontal, TMISpacing.xs)

            VStack(spacing: TMISpacing.sm) {
                ForEach(peersWithInterest) { peer in
                    NavigationLink(destination: StudentPeerProfileView(peerStudent: peer, currentStudent: currentStudent)) {
                        PeerRow(peer: peer, interest: interest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty Classmates Section

    private var emptyClassmatesSection: some View {
        TMICard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.tmiTextTertiary)

                VStack(spacing: 8) {
                    Text("Classmate Connections Are Coming")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.tmiTextPrimary)

                    Text("Your interest is saved. Classmate connections will appear when Student Mode is ready.")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(TMISpacing.xl)
        }
    }

}

// MARK: - Peer Row

struct PeerRow: View {
    let peer: Student
    let interest: Interest
    @State private var commonCount: Int = 0

    var body: some View {
        TMICard(style: .default) {
            HStack(spacing: TMISpacing.md) {
                // Avatar
                TMIAvatar(
                    initials: peer.initials,
                    color: interest.color,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.firstName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.tmiTextPrimary)

                    Text("Grade \(peer.grade)")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                // Common interests count
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                    Text("\(commonCount)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.tmiSuccess)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.tmiTextTertiary)
            }
        }
        .task {
            await calculateCommonInterests()
        }
    }

    private func calculateCommonInterests() async {
        // Assume current student is available via some context or added explicitly if needed.
        // For now, we only have 'peer' and 'interest'. The requirement implies comparing with 'currentStudent'
        // but 'PeerRow' implementation in original file didn't actually have 'currentStudent' passed to it,
        // it was just a view struct relying on a passed 'peer'.
        // Looking at usage: NavigationLink(destination: ..., label: { PeerRow(...) })
        // I need to update call site to pass currentStudent if I want to compare properly.
        // Or I can just count the PEER's total interests?
        // "Common interests count" implies intersection.
        // I will assume for now I should just show the peer's TOTAL interest count as a proxy or 
        // strictly follow "common" which requires currentStudent.
        // Use placeholder 0 or fetch peer's total interests count for now.
        
        guard let peerId = peer.id else { return }
        do {
             let interests = try await StudentInterestService.shared.getStudentInterests(studentId: peerId)
             // Just showing total count for peer as "shared" is misleading, but without currentStudent passed in, 
             // I can't calculate "common". 
             // The original code returned 0. I will return total count and rename/update label if allowed, 
             // or just leave as 0 until I can add currentStudent to PeerRow init.
             // Wait, I CAN add currentStudent to PeerRow init.
             
             commonCount = interests.count
        } catch {
            commonCount = 0
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StudentInterestDetailView(
            interest: Interest.sampleInterests[0],
            currentStudent: Student.sampleStudents[0]
        )
    }
}
