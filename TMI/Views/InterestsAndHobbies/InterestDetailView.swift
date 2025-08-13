//
//  EnhancedInterestDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import SwiftUI

struct InterestDetailView: View {
  let interest: Interest
  @State private var associatedStudents: [Student] = []
  @State private var connectedTMIPlans: [TMIPlan] = []
  @State private var isLoading = false

  @State private var headerAppeared = false
  @State private var contentAppeared = false

  // Computed properties to simplify complex expressions
  private var studentCount: String {
    "\(associatedStudents.count)"
  }

  private var averageEngagement: String {
    guard !associatedStudents.isEmpty else { return "0%" }
    let totalEngagement = associatedStudents.map { $0.engagementScore }.reduce(0, +)
    let average = totalEngagement / Double(associatedStudents.count)
    let percentage = Int(average * 100)
    return "\(percentage)%"
  }

  private var planCount: String {
    "\(connectedTMIPlans.count)"
  }

  var body: some View {
    ZStack {
      // Background
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.08, green: 0.08, blue: 0.15),
          Color(red: 0.14, green: 0.14, blue: 0.25),
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      // Animated blob
      InterestDetailBlob(color: interest.color)

      ScrollView {
        VStack(spacing: 24) {
          // Header
          VStack(spacing: 16) {
            ZStack {
              Circle()
                .fill(interest.color.opacity(0.15))
                .frame(width: 100, height: 100)

              Image(systemName: interest.iconName)
                .font(.system(size: 40))
                .foregroundColor(interest.color)
            }

            VStack(spacing: 8) {
              Text(interest.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

              Text(interest.category.first?.rawValue ?? "General")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                  Capsule()
                    .fill(interest.color.opacity(0.15))
                )
            }
          }
          .padding(.top, 40)
          .offset(y: headerAppeared ? 0 : -30)
          .opacity(headerAppeared ? 1 : 0)

          // Stats
          HStack(spacing: 20) {
            DetailStatCard(
              value: studentCount,
              label: "Students",
              icon: "person.2.fill",
              color: interest.color
            )

            DetailStatCard(
              value: averageEngagement,
              label: "Avg Engagement",
              icon: "chart.line.uptrend.xyaxis.fill",
              color: interest.color
            )

            DetailStatCard(
              value: planCount,
              label: "TMI Plans",
              icon: "doc.fill",
              color: interest.color
            )
          }
          .padding(.horizontal, 20)
          .offset(y: contentAppeared ? 0 : 30)
          .opacity(contentAppeared ? 1 : 0)

          // Content
          VStack(spacing: 20) {
            // Associated Students
            IHDetailSection(title: "Associated Students", color: interest.color) {
              if isLoading {
                ProgressView()
                  .foregroundColor(.white)
                  .padding(.vertical, 12)
              } else if associatedStudents.isEmpty {
                Text(
                  "No students have expressed this interest yet. Add students or connect this interest to student profiles."
                )
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .padding(.vertical, 12)
              } else {
                VStack(spacing: 8) {
                  ForEach(associatedStudents.prefix(3)) { student in
                    StudentPreviewCard(student: student, color: interest.color)
                  }

                  if associatedStudents.count > 3 {
                    Button("View All \(associatedStudents.count) Students") {
                      // Navigate to students tab with interest filter
                      // For now, just navigate to students tab
                      // Future: Could pass filter parameters
                      // NavigationCoordinator.shared.navigate(to: .students(filter: interest))
                      print("Show students with interest: \(interest.name)")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(interest.color)
                    .padding(.top, 4)
                  }
                }
                .padding(.vertical, 8)
              }
            }

            // Connected TMI Plans
            IHDetailSection(title: "Connected TMI Plans", color: interest.color) {
              if connectedTMIPlans.isEmpty {
                Text(
                  "No TMI plans are currently using this interest. Create new plans or connect existing ones to track student progress."
                )
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .padding(.vertical, 12)
              } else {
                VStack(spacing: 8) {
                  ForEach(connectedTMIPlans.prefix(3)) { plan in
                    TMIPlanPreviewCard(plan: plan, color: interest.color)
                  }

                  if connectedTMIPlans.count > 3 {
                    Button("View All \(connectedTMIPlans.count) Plans") {
                      // Navigate to TMI Plans tab with interest filter
                      // For now, just navigate to plans tab
                      // Future: Could pass filter parameters
                      // NavigationCoordinator.shared.navigate(to: .tmiPlans(filter: interest))
                      print("Show TMI plans with interest: \(interest.name)")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(interest.color)
                    .padding(.top, 4)
                  }
                }
                .padding(.vertical, 8)
              }
            }

            // Interest Insights
            IHDetailSection(title: "Interest Insights", color: interest.color) {
              VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                  icon: "chart.bar.fill",
                  title: "Popularity Trend",
                  value: associatedStudents.count > 5 ? "↗ Trending" : "→ Stable",
                  color: interest.color
                )

                InsightRow(
                  icon: "target",
                  title: "Success Rate",
                  value: "\(Int.random(in: 75...95))%",
                  color: interest.color
                )

                InsightRow(
                  icon: "calendar",
                  title: "Best Season",
                  value: ["Fall", "Spring", "Winter", "Summer"].randomElement() ?? "Year-round",
                  color: interest.color
                )
              }
              .padding(.vertical, 8)
            }
          }
          .padding(.horizontal, 20)
          .offset(y: contentAppeared ? 0 : 50)
          .opacity(contentAppeared ? 1 : 0)
        }
        .padding(.bottom, 40)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Interest Details")
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button(action: {
            // Edit action
          }) {
            Label("Edit Interest", systemImage: "pencil")
          }

          Button(action: {
            // Connect student action
          }) {
            Label("Connect Student", systemImage: "person.badge.plus")
          }

          Divider()

          Button(
            role: .destructive,
            action: {
              // Delete action
            }
          ) {
            Label("Delete Interest", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 22))
            .foregroundColor(.white)
        }
      }
    }
    .task {
      await loadInterestData()
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
        headerAppeared = true
      }

      withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
        contentAppeared = true
      }
    }
  }

  private func loadInterestData() async {
    isLoading = true

    // Simulate loading associated data
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay

    // In a real app, these would be actual Firebase queries
    // For now, use sample data filtered by interest
    associatedStudents = Student.sampleStudents.filter { student in
      student.interests.contains { $0.name == interest.name }
    }

    // Mock TMI plans - in real app, would query plans that use this interest
    connectedTMIPlans = TMIPlan.samplePlans.filter { plan in
      // Check if plan involves this interest (mock logic)
      plan.student.interests.contains { $0.name == interest.name }
    }

    isLoading = false
  }
}
