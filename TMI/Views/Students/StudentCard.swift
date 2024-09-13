// StudentCard.swift

import SwiftUI

struct StudentCard: View {
    let student: Student

    var body: some View {
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
                Text(student.initials)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.tmiPrimary)
                    .clipShape(Circle())
            }

            // Student Name
            Text(student.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Grade
            Text("Grade \(student.grade)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Engagement Score Indicator
            EngagementBar(engagementScore: student.engagementScore)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 3)
    }

    // Helper to retrieve student's avatar image
    private var studentAvatar: Image? {
        // If you have avatar image data, implement the retrieval here.
        // For this example, we'll return nil to use the initials instead.
        return nil
    }
}

struct EngagementBar: View {
    let engagementScore: Double  // Expected to be between 0 and 1

    var body: some View {
        HStack {
            Text("Engagement")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            ZStack(alignment: .leading) {
                Capsule()
                    .frame(width: 60, height: 8)
                    .foregroundColor(Color.gray.opacity(0.2))
                Capsule()
                    .frame(width: CGFloat(60 * engagementScore), height: 8)
                    .foregroundColor(engagementColor)
            }
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
