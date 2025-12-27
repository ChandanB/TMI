//
//  StudentsNeedingAttentionList.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import SwiftUI

struct StudentsNeedingAttentionList: View {
  let alerts: [StudentNeedAlert]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Students Needing Attention")
          .font(.headline)
        Spacer()
        if !alerts.isEmpty {
          Text("\(alerts.count)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(8)
        }
      }
      .padding(.horizontal)

      if alerts.isEmpty {
        emptyState
      } else {
        ForEach(alerts.prefix(5)) { alert in
          alertCard(for: alert)
        }

        if alerts.count > 5 {
          Button {
            // Navigate to full list
          } label: {
            Text("View All \(alerts.count) Alerts")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.blue)
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color(UIColor.secondarySystemBackground))
          .cornerRadius(12)
          .padding(.horizontal)
        }
      }
    }
    .padding(.vertical)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundColor(.green)

      Text("All Students On Track")
        .font(.headline)

      Text("No students require immediate attention")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(12)
    .padding(.horizontal)
  }

  private func alertCard(for alert: StudentNeedAlert) -> some View {
    HStack(spacing: 12) {
      // Severity indicator
      Circle()
        .fill(severityColor(for: alert.severity))
        .frame(width: 8, height: 8)

      // Alert icon
      Image(systemName: alert.alertType.icon)
        .foregroundColor(severityColor(for: alert.severity))
        .frame(width: 24)

      // Alert content
      VStack(alignment: .leading, spacing: 4) {
        Text(alert.studentName)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(alert.alertMessage)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)

        HStack {
          Text(alert.schoolName)
            .font(.caption2)
            .foregroundColor(.secondary)

          Spacer()

          Text(alert.alertType.displayName)
            .font(.caption2)
            .foregroundColor(severityColor(for: alert.severity))
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    .padding(.horizontal)
  }

  private func severityColor(for severity: StudentNeedAlert.Severity) -> Color {
    switch severity {
    case .low: return .blue
    case .medium: return .yellow
    case .high: return .orange
    case .critical: return .red
    }
  }
}

#Preview {
  ScrollView {
    StudentsNeedingAttentionList(alerts: StudentNeedAlert.sampleAlerts)
  }
  .background(Color(UIColor.secondarySystemBackground))
}
