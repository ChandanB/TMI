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

    @State private var peersWithInterest: [Student] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

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
                    } else if !isLoading {
                        emptyClassmatesSection
                    }
                }
                .padding(TMISpacing.screenPadding)
            }
        }
        .navigationTitle(interest.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPeersWithInterest()
        }
    }

    // MARK: - Interest Header

    private var interestHeader: some View {
        TMIGlassCard(style: .default) {
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
                        .foregroundColor(.white)

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
                    .foregroundColor(.white)

                Spacer()

                Text("\(peersWithInterest.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
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
        TMIGlassCard(style: .default) {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.tmiTextTertiary)

                VStack(spacing: 8) {
                    Text("You're the First!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("None of your classmates have shared this interest yet. You're a pioneer!")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(TMISpacing.xl)
        }
    }

    // MARK: - Helpers

    private func loadPeersWithInterest() async {
        isLoading = true
        defer { isLoading = false }

        // In a real implementation, this would fetch from Firestore
        // For now, use sample data filtering
        peersWithInterest = Student.sampleStudents.filter { student in
            student.id != currentStudent.id && // Exclude current student
            student.interests.contains(where: { $0.id == interest.id }) // Has this interest
        }
    }
}

// MARK: - Peer Row

struct PeerRow: View {
    let peer: Student
    let interest: Interest

    var body: some View {
        TMIGlassCard(style: .default) {
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
                        .foregroundColor(.white)

                    Text("Grade \(peer.grade)")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                // Common interests count
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                    Text("\(commonInterestsCount(with: peer))")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.tmiSuccess)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.tmiTextTertiary)
            }
        }
    }

    private func commonInterestsCount(with peer: Student) -> Int {
        let currentInterestIds = Set(Student.sampleStudents[0].interests.map { $0.id })
        let peerInterestIds = Set(peer.interests.map { $0.id })
        return currentInterestIds.intersection(peerInterestIds).count
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StudentInterestDetailView(
            interest: Student.sampleStudents[0].interests[0],
            currentStudent: Student.sampleStudents[0]
        )
    }
}
