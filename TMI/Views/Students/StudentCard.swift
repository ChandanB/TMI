// StudentCard.swift

import SwiftUI

struct StudentCard: View {
  let student: Student

  var body: some View {
    TMICard(style: .default) {
      VStack(spacing: 10) {
        // Avatar Image with async loading
        if let photoURL = student.photoURL {
          AsyncImage(url: photoURL) { phase in
            switch phase {
            case .empty:
              ZStack {
                Circle()
                  .fill(avatarTintColor.opacity(0.15))
                ProgressView()
                  .tint(avatarTintColor)
              }
              .frame(width: 80, height: 80)
            case .success(let image):
              image
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(radius: 3)
                .transition(.opacity)
            case .failure:
              initialsAvatar
            @unknown default:
              EmptyView()
            }
          }
        } else {
          initialsAvatar
        }

        // Student Name and chevron row
        HStack {
          Spacer()
          Text(student.name)
            .font(.headline)
            .foregroundColor(Color.tmiTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.tmiTextTertiary)
        }

        // Grade
        Text("Grade \(student.grade)")
          .font(.subheadline)
          .foregroundColor(Color.tmiTextSecondary)

        // Engagement Score Indicator
        EngagementBar(engagementScore: student.engagementScore)
      }
    }
  }

  private var initialsAvatar: some View {
    Text(studentInitials)
      .font(.system(size: 32, weight: .bold))
      .foregroundColor(avatarTintColor)
      .frame(width: 80, height: 80)
      .background(avatarTintColor.opacity(0.15))
      .clipShape(Circle())
  }

  private var avatarTintColor: Color {
    switch student.avatarColor {
    case .blue: return .blue
    case .green: return .green
    case .orange: return .orange
    case .purple: return .purple
    case .teal: return .teal
    case .pink: return .pink
    case .indigo: return .indigo
    }
  }

  // Generate initials from student name
  private var studentInitials: String {
    let components = student.name.components(separatedBy: " ")
    let initials = components.compactMap { $0.first }.prefix(2)
    return String(initials).uppercased()
  }
}

struct EngagementBar: View {
  let engagementScore: Double  // Expected to be between 0 and 1

  var body: some View {
    HStack {
      Text("Engagement")
        .font(.caption)
        .foregroundColor(Color.tmiTextSecondary)
      Spacer()

      ProgressView(value: engagementScore)
        .tmiProgressStyle(color: engagementColor, height: 8)
        .frame(width: 60)
    }
  }

  private var engagementColor: Color {
    switch engagementScore {
    case 0..<0.3:
      return .red
    case 0.3..<0.7:
      return .yellow
    default:
      return .green
    }
  }
}

#Preview {
  StudentCard(student: Student.sampleStudent)
}
