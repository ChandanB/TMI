// StudentCard.swift

import SwiftUI

struct StudentCard: View {
  let student: Student

  var body: some View {
    TMIGlassCard(style: .default) {
      VStack(spacing: 10) {
        // Avatar Image
        if let avatarImage = studentAvatar {
          avatarImage
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.tmiPrimary, lineWidth: 2))
            .shadow(radius: 3)
        } else {
          Text(studentInitials)
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(
              LinearGradient(
                colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .clipShape(Circle())
            .overlay(
              Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
        }

        // Student Name
        Text(student.name)
          .font(.headline)
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        // Grade
        Text("Grade \(student.grade)")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.7))

        // Engagement Score Indicator
        EngagementBar(engagementScore: student.engagementScore)
      }
    }
  }

  // Helper to retrieve student's avatar image
  private var studentAvatar: Image? {
    // Check if student has photo URL
    if student.photoURL != nil {
      // In a real implementation, you would use AsyncImage or SDWebImageSwiftUI
      // For now, return nil to show that avatar loading is being handled
      // TODO: Implement AsyncImage loading from photoURL
      return nil
    }
    // No image data available, return nil to use initials
    return nil
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
        .foregroundColor(.white.opacity(0.7))
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
