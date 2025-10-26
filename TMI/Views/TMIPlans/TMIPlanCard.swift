//
//  TMIPlanCard.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import SwiftUI

struct TMIPlanCard: View {
  let plan: TMIPlan

  @State private var isHovered = false
  @State private var isAnimating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with model type and status indicator
      VStack(spacing: 16) {
        HStack(alignment: .top) {
          // Model icon and name
          HStack(spacing: 12) {
            ZStack {
              Circle()
                .fill(modelColor.opacity(0.15))
                .frame(width: 44, height: 44)

              Image(systemName: modelIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(modelColor)
            }

            VStack(alignment: .leading, spacing: 2) {
              Text(plan.model.rawValue)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

              Text("Updated \(timeAgo(from: plan.lastUpdated))")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            }
          }

          Spacer()

          // Progress indicator
          ZStack {
            Circle()
              .stroke(
                progressBackground,
                lineWidth: 4
              )
              .frame(width: 40, height: 40)

            Circle()
              .trim(from: 0, to: CGFloat(min(plan.calculatedProgress, 1.0)))
              .stroke(
                progressGradient,
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
              )
              .frame(width: 40, height: 40)
              .rotationEffect(.degrees(-90))

            Text("\(plan.progressPercentage)%")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white)
          }
        }

        // Progress bar
        ProgressView(value: plan.calculatedProgress)
          .tmiProgressStyle(color: modelColor)
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: plan.calculatedProgress)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 16)

      // Description & content area
      VStack(alignment: .leading, spacing: 16) {
        // Description
        Text(plan.model.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)
          .padding(.horizontal, 20)

        // Student avatars
        HStack(spacing: 0) {
          Text("Students:")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.trailing, 8)

          // Avatar stack
          HStack(spacing: -6) {
            ForEach(plan.students.prefix(3)) { student in
              StudentAvatarView(student: student, size: 26)
            }

            if plan.students.count > 3 {
              ZStack {
                Circle()
                  .fill(Color.black.opacity(0.3))
                  .frame(width: 26, height: 26)

                Text("+\(plan.students.count - 3)")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundColor(.white)
              }
            }
          }

          Spacer()

          // Plan stats as icons
          HStack(spacing: 12) {
            StatIcon(
              count: plan.interests.count,
              icon: "heart.fill",
              color: .pink.opacity(0.8)
            )

            StatIcon(
              count: plan.students.count,
              icon: "person.fill",
              color: .blue.opacity(0.8)
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.black.opacity(0.2))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.7)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          LinearGradient(
            colors: [
              .white.opacity(0.4),
              .white.opacity(0.1),
              .clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .scaleEffect(isHovered ? 1.02 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
        isAnimating = true
      }
    }
  }

  // MARK: - Helper Properties

  private var modelIcon: String {
    switch plan.model {
    case .chaseYourSpace:
      return "airplane.departure"
    case .acknowledgeInterests:
      return "heart.fill"
    case .alignYourMind:
      return "brain.head.profile"
    case .directAndCorrect:
      return "arrow.up.forward.circle.fill"
    case .bullyToBoss:
      return "person.fill.badge.plus"
    case .meekToProtector:
      return "shield.lefthalf.filled"
    }
  }

  private var modelColor: Color {
    switch plan.model {
    case .chaseYourSpace:
      return .blue
    case .acknowledgeInterests:
      return .pink
    case .alignYourMind:
      return .purple
    case .directAndCorrect:
      return .orange
    case .bullyToBoss:
      return .red
    case .meekToProtector:
      return .green
    }
  }

  private var progressBackground: Color {
    return Color.white.opacity(0.15)
  }

  private var progressGradient: LinearGradient {
    LinearGradient(
      colors: [
        modelColor,
        modelColor.opacity(0.8),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  // MARK: - Helper Functions

  private func timeAgo(from date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

    if let day = components.day, day > 0 {
      return day == 1 ? "yesterday" : "\(day) days ago"
    } else if let hour = components.hour, hour > 0 {
      return "\(hour) hour\(hour == 1 ? "" : "s") ago"
    } else if let minute = components.minute, minute > 0 {
      return "\(minute) minute\(minute == 1 ? "" : "s") ago"
    } else {
      return "just now"
    }
  }
}

// MARK: - Supporting Views

struct StudentAvatarView: View {
  let student: Student
  var size: CGFloat = 36

  var body: some View {
    if let photoURL = student.photoURL {
      // If there's a photo URL, attempt to load it
      AsyncImage(url: photoURL) { phase in
        switch phase {
        case .empty:
          placeholderAvatar
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
        case .failure:
          placeholderAvatar
        @unknown default:
          placeholderAvatar
        }
      }
    } else {
      placeholderAvatar
    }
  }

  private var placeholderAvatar: some View {
    ZStack {
      Circle()
        .fill(
          student.avatarColor == .blue
            ? Color.blue
            : student.avatarColor == .green
              ? Color.green
              : student.avatarColor == .orange
                ? Color.orange
                : student.avatarColor == .purple
                  ? Color.purple
                  : student.avatarColor == .teal
                    ? Color.teal : student.avatarColor == .pink ? Color.pink : Color.indigo
        )
        .frame(width: size, height: size)

      Text(student.initials)
        .font(.system(size: size * 0.4, weight: .bold))
        .foregroundColor(.white)
    }
  }
}

struct StatIcon: View {
  var count: Int
  var icon: String
  var color: Color

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundColor(color)

      Text("\(count)")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white)
    }
  }
}
