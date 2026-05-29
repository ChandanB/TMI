//
//  DashboardStatsView.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct DashboardStatsView: View {
    let data: DashboardData
    let onNavigateToStudents: () -> Void
    let onNavigateToPlans: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Key Stats")
                .font(.tmiTitle3.bold())
                .foregroundColor(.tmiTextPrimary)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TMISpacing.md) {
                    MetricPill(
                        icon: "person.2.fill",
                        tint: .blue,
                        value: "\(data.totalStudents)",
                        label: "Students",
                        subtitle: "Total Enrolled",
                        action: onNavigateToStudents
                    )

                    MetricPill(
                        icon: "doc.fill",
                        tint: .purple,
                        value: "\(data.activeTMIPlans)",
                        label: "Active Plans",
                        subtitle: "In Progress",
                        action: onNavigateToPlans
                    )

                    MetricPill(
                        icon: "checkmark.circle.fill",
                        tint: .green,
                        value: "\(data.surveysCompleted)",
                        label: "Surveys",
                        subtitle: "Completed",
                        action: onNavigateToStudents
                    )

                    MetricPill(
                        icon: "lightbulb.fill",
                        tint: .orange,
                        value: "\(data.interestsIdentified)",
                        label: "Interests",
                        subtitle: "Identified",
                        action: onNavigateToStudents
                    )
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }
        }
    }
}
