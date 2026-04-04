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
                  .fill(Color.tmiSecondary.opacity(0.3))
                ProgressView()
                  .tint(.white)
              }
              .frame(width: 80, height: 80)
            case .success(let image):
              image
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.tmiPrimary, lineWidth: 2))
                .shadow(radius: 3)
                .transition(.opacity)
            case .failure:
              Text(studentInitials)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color.tmiTextPrimary)
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
            @unknown default:
              EmptyView()
            }
          }
        } else {
          Text(studentInitials)
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(Color.tmiTextPrimary)
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
          .foregroundColor(Color.tmiTextPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        // Grade
        Text("Grade \(student.grade)")
          .font(.subheadline)
          .foregroundColor(Color.tmiTextSecondary)

        // Engagement Score Indicator
        EngagementBar(engagementScore: student.engagementScore)
      }
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
