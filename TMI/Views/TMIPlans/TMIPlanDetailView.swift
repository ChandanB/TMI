// TMIPlanDetailView.swift

import Charts
import SwiftUI

struct TMIPlanDetailView: View {
  let plan: TMIPlan
  @Environment(\.dismiss) private var dismiss

  // Animation states
  @State private var headerAppeared = false
  @State private var chartAppeared = false
  @State private var contentAppeared = false
  @State private var isChartExpanded = false

  // UI States
  @State private var selectedChartTimeFrame: ChartTimeFrame = .monthly
  @State private var showingEditSheet = false
  @State private var showingDeleteAlert = false

  enum ChartTimeFrame: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { self.rawValue }
  }

  var body: some View {
    ZStack {
      // Background
      planDetailBackgroundView

      ScrollView {
        VStack(spacing: 24) {
          // Header View
          enhancedHeaderView
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .offset(y: headerAppeared ? 0 : -20)
            .opacity(headerAppeared ? 1 : 0)

          // Quick Stats
          enhancedQuickStatsView
            .padding(.horizontal, 20)
            .offset(y: headerAppeared ? 0 : -10)
            .opacity(headerAppeared ? 1 : 0)

          // Progress Chart
          enhancedProgressChartView
            .padding(.horizontal, 20)
            .offset(y: chartAppeared ? 0 : 30)
            .opacity(chartAppeared ? 1 : 0)

          // Content sections
          Group {
            enhancedInsightsSection
            enhancedStudentsSection
            enhancedInterestsAndHobbiesSection
            enhancedGoalsSection
            enhancedNotesSection
          }
          .padding(.horizontal, 20)
          .offset(y: contentAppeared ? 0 : 40)
          .opacity(contentAppeared ? 1 : 0)
        }
        .padding(.bottom, 40)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("TMI Plan Details")
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button(action: {
            showingEditSheet = true
          }) {
            Label("Edit Plan", systemImage: "pencil")
          }

          Button(action: {
            // Export action
          }) {
            Label("Export Plan", systemImage: "square.and.arrow.up")
          }

          Divider()

          Button(
            role: .destructive,
            action: {
              showingDeleteAlert = true
            }
          ) {
            Label("Delete Plan", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 22))
            .foregroundColor(.white)
        }
      }
    }
    .sheet(isPresented: $showingEditSheet) {
      EditTMIPlanView(plan: plan) { updatedPlan in
        // Handle the updated plan
        // In a real implementation, you would update the plan data
        // For now, we'll just dismiss
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .alert("Delete TMI Plan", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        deletePlan()
      }
    } message: {
      Text("Are you sure you want to delete this TMI plan? This action cannot be undone.")
    }
    .onAppear {
      animateViews()
    }
    .preferredColorScheme(.dark)
  }

  private func animateViews() {
    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
      headerAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
      chartAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
      contentAppeared = true
    }
  }
  
  private func deletePlan() {
    Task {
      do {
        try await TMIPlanService().deletePlan(plan)
        await MainActor.run {
          dismiss()
        }
      } catch {
        print("Error deleting TMI plan: \(error)")
      }
    }
  }

  // MARK: - Background

  private var planDetailBackgroundView: some View {
    // Using unified TMIBackgroundView with plan variant
    TMIBackgroundView(variant: .plans)
      .ignoresSafeArea()
  }

  // MARK: - Header View

  private var enhancedHeaderView: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        // Model badge
        VStack(alignment: .leading, spacing: 8) {
          ZStack {
            // Icon badge
            Circle()
              .fill(modelColor.opacity(0.15))
              .frame(width: 60, height: 60)

            Image(systemName: modelIcon)
              .font(.system(size: 24, weight: .semibold))
              .foregroundColor(modelColor)
          }

          // Model name and creation date
          VStack(alignment: .leading, spacing: 4) {
            Text(plan.model.rawValue)
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)

            Text("Created on \(formattedDate(plan.creationDate))")
              .font(.system(size: 14))
              .foregroundColor(.white.opacity(0.6))
          }
        }

        Spacer()

        // Progress circle
        ZStack {
          Circle()
            .stroke(
              Color.white.opacity(0.1),
              lineWidth: 8
            )
            .frame(width: 80, height: 80)

          Circle()
            .trim(from: 0, to: CGFloat(min(plan.progress, 1.0)))
            .stroke(
              LinearGradient(
                colors: [modelColor, modelColor.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
              ),
              style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .frame(width: 80, height: 80)
            .rotationEffect(.degrees(-90))

          VStack(spacing: 2) {
            Text("\(Int(plan.progress * 100))%")
              .font(.system(size: 20, weight: .bold, design: .rounded))
              .foregroundColor(.white)

            Text(progressStatus)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.7))
          }
        }
      }

      // Description
      Text(plan.model.description)
        .font(.system(size: 15))
        .foregroundColor(.white.opacity(0.8))
        .padding(.top, 8)
    }
  }

  // MARK: - Quick Stats View

  private var enhancedQuickStatsView: some View {
    HStack(spacing: 15) {
      // Last updated
      DetailStat(
        title: "Last Updated",
        value: timeAgo(from: plan.lastUpdated),
        icon: "calendar",
        color: .blue
      )

      // Student count
      DetailStat(
        title: "Students",
        value: "\(plan.students.count)",
        icon: "person.3",
        color: .green
      )

      // Interest count
      DetailStat(
        title: "Interests",
        value: "\(plan.interests.count)",
        icon: "heart",
        color: .pink
      )
    }
  }

  // MARK: - Progress Chart View

  private var enhancedProgressChartView: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header with time frame selector
      HStack {
        Text("Progress Tracking")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)

        Spacer()

        // Time frame selector
        HStack(spacing: 0) {
          ForEach(ChartTimeFrame.allCases) { timeFrame in
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedChartTimeFrame = timeFrame
              }
            } label: {
              Text(timeFrame.rawValue)
                .font(
                  .system(
                    size: 12, weight: selectedChartTimeFrame == timeFrame ? .semibold : .regular)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundColor(selectedChartTimeFrame == timeFrame ? .white : .white.opacity(0.6))
                .background(
                  selectedChartTimeFrame == timeFrame
                    ? Capsule().fill(modelColor.opacity(0.3)) : nil
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
        .background(
          Capsule()
            .fill(Color.white.opacity(0.05))
        )
      }

      // Chart
      VStack {
        enhancedProgressChart
          .frame(height: isChartExpanded ? 300 : 200)
          .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isChartExpanded)
          .gesture(
            TapGesture()
              .onEnded { _ in
                withAnimation {
                  isChartExpanded.toggle()
                }
              }
          )

        // Chart legend
        HStack(spacing: 20) {
          // Current period text
          Text(chartPeriodText)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.7))

          Spacer()

          // Legend items
          HStack(spacing: 16) {
            legendItem(color: modelColor, label: "Progress")
            legendItem(color: .gray.opacity(0.5), label: "Target")
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
      }
      .padding(.top, 8)
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white.opacity(0.03))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
    }
  }

  private var enhancedProgressChart: some View {
    Chart(progressData) { dataPoint in
      // Area fill
      AreaMark(
        x: .value("Period", dataPoint.date),
        y: .value("Progress", dataPoint.progress)
      )
      .foregroundStyle(areaGradient)
      .interpolationMethod(.catmullRom)
      
      // Target line
      LineMark(
        x: .value("Period", dataPoint.date),
        y: .value("Target", dataPoint.target)
      )
      .foregroundStyle(targetLineStyle)
      .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
      
      // Progress line
      LineMark(
        x: .value("Period", dataPoint.date),
        y: .value("Progress", dataPoint.progress)
      )
      .foregroundStyle(progressLineGradient)
      .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      .interpolationMethod(.catmullRom)
      
      // Progress points
      PointMark(
        x: .value("Period", dataPoint.date),
        y: .value("Progress", dataPoint.progress)
      )
      .foregroundStyle(modelColor)
      .symbolSize(64)
    }
    .chartYScale(domain: 0...1)
    .chartYAxis {
      AxisMarks(position: .leading, values: .stride(by: 0.25)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
          .foregroundStyle(Color.white.opacity(0.2))
        
        AxisValueLabel {
          if let doubleValue = value.as(Double.self) {
            Text("\(Int(doubleValue * 100))%")
              .font(.caption2)
              .foregroundColor(.white.opacity(0.7))
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 6)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
          .foregroundStyle(Color.white.opacity(0.1))
        
        AxisValueLabel {
          if let stringValue = value.as(String.self) {
            Text(stringValue)
              .font(.caption2)
              .foregroundColor(.white.opacity(0.7))
              .lineLimit(1)
          }
        }
      }
    }
    .accessibilityLabel("TMI Plan Progress Chart")
    .accessibilityValue("Shows progress over time compared to target")
  }
  
  private var areaGradient: LinearGradient {
    LinearGradient(
      colors: [modelColor.opacity(0.3), modelColor.opacity(0.05)],
      startPoint: .top,
      endPoint: .bottom
    )
  }
  
  private var progressLineGradient: LinearGradient {
    LinearGradient(
      colors: [modelColor, modelColor.opacity(0.8)],
      startPoint: .leading,
      endPoint: .trailing
    )
  }
  
  private var targetLineStyle: Color {
    Color.gray.opacity(0.6)
  }

  private func legendItem(color: Color, label: String) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)

      Text(label)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))
    }
  }

  // MARK: - Insights Section

  private var enhancedInsightsSection: some View {
    DetailSection(title: "Insights") {
      VStack(spacing: 16) {
        // Engagement trend
        DetailRow(
          icon: trendIcon,
          title: "Engagement Trend",
          value: engagementTrend(),
          valueColor: trendColor
        )

        // Last milestone
        DetailRow(
          icon: "flag.fill",
          title: "Last Milestone",
          value: "Week 4 Review"
        )

        // Next action
        DetailRow(
          icon: "arrow.right.circle.fill",
          title: "Next Action",
          value: "Schedule Progress Review"
        )
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Students Section

  private var enhancedStudentsSection: some View {
    DetailSection(title: "Associated Students") {
      VStack(alignment: .leading, spacing: 16) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(plan.students) { student in
              StudentDetailCard(student: student)
            }
          }
          .padding(.horizontal, 4)
          .padding(.vertical, 8)
        }
      }
    }
  }

  // MARK: - Interests and Hobbies Section

  private var enhancedInterestsAndHobbiesSection: some View {
    DetailSection(title: "Interests & Hobbies") {
      VStack(alignment: .leading, spacing: 20) {
        if !plan.interests.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Interests")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)

            WrapView(items: plan.interests) { interest in
              InterestTag(interest: interest)
            }
          }
        }

        if !plan.hobbies.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Hobbies")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)

            WrapView(items: plan.hobbies) { hobby in
              HobbyTag(hobby: hobby)
            }
          }
        }

        if plan.interests.isEmpty && plan.hobbies.isEmpty {
          Text("No interests or hobbies associated with this plan.")
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.6))
            .padding(.vertical, 8)
        }
      }
    }
  }

  // MARK: - Goals Section

  private var enhancedGoalsSection: some View {
    DetailSection(title: "Goals & Objectives") {
      VStack(alignment: .leading, spacing: 16) {
        if plan.goals.isEmpty {
          Text("No goals defined for this plan.")
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.6))
            .padding(.vertical, 8)
        } else {
          ForEach(plan.goals) { goal in
            GoalCard(goal: goal)
          }
        }

        Button {
          // Add goal action
        } label: {
          HStack {
            Image(systemName: "plus.circle")
              .font(.system(size: 14))

            Text("Add New Goal")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundColor(.white)
          .padding(.vertical, 8)
          .padding(.horizontal, 14)
          .background(
            Capsule()
              .fill(Color.white.opacity(0.1))
          )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 4)
      }
    }
  }

  // MARK: - Notes Section

  private var enhancedNotesSection: some View {
    DetailSection(title: "Notes") {
      VStack(alignment: .leading, spacing: 16) {
        if plan.notes.isEmpty {
          Text("No notes added to this plan.")
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.6))
            .padding(.vertical, 8)
        } else {
          Text(plan.notes)
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.9))
            .lineSpacing(4)
            .padding(.vertical, 8)
        }

        Button {
          // Add notes action
        } label: {
          HStack {
            Image(systemName: "plus.circle")
              .font(.system(size: 14))

            Text("Add Notes")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundColor(.white)
          .padding(.vertical, 8)
          .padding(.horizontal, 14)
          .background(
            Capsule()
              .fill(Color.white.opacity(0.1))
          )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 4)
      }
    }
  }

  // MARK: - Helper Properties

  private var modelIcon: String {
    switch plan.model {
    case .chaseYourSpace:
      return "rocket.fill"
    case .acknowledgeInterests:
      return "heart.fill"
    case .alignYourMind:
      return "brain.head.profile.fill"
    case .directAndCorrect:
      return "arrow.up.forward.circle.fill"
    case .bullyToBoss:
      return "person.fill.badge.plus"
    case .meekToProtector:
      return "person.fill.turn.up"
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

  private var progressStatus: String {
    if plan.progress >= 1.0 {
      return "Completed"
    } else if plan.progress >= 0.75 {
      return "Final Stage"
    } else if plan.progress >= 0.5 {
      return "Halfway"
    } else if plan.progress >= 0.25 {
      return "Initial Stage"
    } else {
      return "Just Started"
    }
  }

  private var trendIcon: String {
    let trend = engagementTrend()
    if trend == "Improving" {
      return "arrow.up.right.circle.fill"
    } else if trend == "Declining" {
      return "arrow.down.right.circle.fill"
    } else {
      return "arrow.right.circle.fill"
    }
  }

  private var trendColor: Color {
    let trend = engagementTrend()
    if trend == "Improving" {
      return .green
    } else if trend == "Declining" {
      return .red
    } else {
      return .orange
    }
  }

  private var chartPeriodText: String {
    switch selectedChartTimeFrame {
    case .weekly:
      return "Past 8 weeks"
    case .monthly:
      return "Past 6 months"
    case .yearly:
      return "Past 12 months"
    }
  }

  // MARK: - Helper Methods

  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private func timeAgo(from date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

    if let day = components.day, day > 0 {
      return day == 1 ? "Yesterday" : "\(day) days ago"
    } else if let hour = components.hour, hour > 0 {
      return "\(hour) hour\(hour == 1 ? "" : "s") ago"
    } else if let minute = components.minute, minute > 0 {
      return "\(minute) minute\(minute == 1 ? "" : "s") ago"
    } else {
      return "Just now"
    }
  }

  private func engagementTrend() -> String {
    let values = progressData.map { $0.progress }
    if values.first! < values.last! {
      return "Improving"
    } else if values.first! > values.last! {
      return "Declining"
    } else {
      return "Stable"
    }
  }

  private var progressData: [ProgressData] {
    switch selectedChartTimeFrame {
    case .weekly:
      return generateWeeklyProgressData()
    case .monthly:
      return generateMonthlyProgressData()
    case .yearly:
      return generateYearlyProgressData()
    }
  }
  
  // MARK: - Progress Data Generation
  
  private func generateWeeklyProgressData() -> [ProgressData] {
    let startDate = plan.creationDate
    let weeksElapsed = weeksFromDate(startDate)
    let currentProgress = plan.progress
    
    var data: [ProgressData] = []
    let maxWeeks = max(8, weeksElapsed + 1)
    
    for week in 1...maxWeeks {
      let _ = Calendar.current.date(byAdding: .weekOfYear, value: week - 1, to: startDate) ?? startDate
      let _ = week == weeksElapsed + 1
      let isFuture = week > weeksElapsed + 1
      
      let progress = calculateProgressForPeriod(
        current: currentProgress,
        totalPeriods: maxWeeks,
        currentPeriod: week,
        planStartDate: startDate
      )
      
      let target = Double(week) / Double(maxWeeks)
      
      data.append(ProgressData(
        date: "Week \(week)",
        progress: isFuture ? target * 0.9 : progress, // Future weeks show projected progress
        target: target
      ))
    }
    
    return data
  }
  
  private func generateMonthlyProgressData() -> [ProgressData] {
    let startDate = plan.creationDate
    let monthsElapsed = monthsFromDate(startDate)
    let currentProgress = plan.progress
    
    let calendar = Calendar.current
    var data: [ProgressData] = []
    let maxMonths = max(6, monthsElapsed + 1)
    
    for month in 1...maxMonths {
      let monthDate = calendar.date(byAdding: .month, value: month - 1, to: startDate) ?? startDate
      let monthName = DateFormatter().shortMonthSymbols[calendar.component(.month, from: monthDate) - 1]
      let isFuture = month > monthsElapsed + 1
      
      let progress = calculateProgressForPeriod(
        current: currentProgress,
        totalPeriods: maxMonths,
        currentPeriod: month,
        planStartDate: startDate
      )
      
      let target = Double(month) / Double(maxMonths)
      
      data.append(ProgressData(
        date: monthName,
        progress: isFuture ? target * 0.85 : progress,
        target: target
      ))
    }
    
    return data
  }
  
  private func generateYearlyProgressData() -> [ProgressData] {
    let startDate = plan.creationDate
    let quarterStart = Calendar.current.dateInterval(of: .quarter, for: startDate)?.start ?? startDate
    let quartersElapsed = quartersFromDate(quarterStart)
    let currentProgress = plan.progress
    
    var data: [ProgressData] = []
    let maxQuarters = 4
    
    for quarter in 1...maxQuarters {
      let isFuture = quarter > quartersElapsed + 1
      
      let progress = calculateProgressForPeriod(
        current: currentProgress,
        totalPeriods: maxQuarters,
        currentPeriod: quarter,
        planStartDate: startDate
      )
      
      let target = Double(quarter) / Double(maxQuarters)
      
      data.append(ProgressData(
        date: "Q\(quarter)",
        progress: isFuture ? target * 0.8 : progress,
        target: target
      ))
    }
    
    return data
  }
  
  // MARK: - Helper Methods
  
  private func calculateProgressForPeriod(current: Double, totalPeriods: Int, currentPeriod: Int, planStartDate: Date) -> Double {
    let timeBasedProgress = Double(currentPeriod - 1) / Double(totalPeriods - 1)
    
    // Factor in engagement score and goal completion
    let engagementFactor = plan.student.engagementScore
    let goalCompletionFactor = calculateGoalCompletionRate()
    let interestAlignmentFactor = calculateInterestAlignment()
    
    // Weighted combination of factors
    let calculatedProgress = (
      timeBasedProgress * 0.4 +
      current * 0.3 +
      engagementFactor * 0.15 +
      goalCompletionFactor * 0.1 +
      interestAlignmentFactor * 0.05
    )
    
    return min(1.0, max(0.0, calculatedProgress))
  }
  
  private func calculateGoalCompletionRate() -> Double {
    guard !plan.goals.isEmpty else { return 0.5 }
    let completedGoals = plan.goals.filter { $0.status == .completed }
    return Double(completedGoals.count) / Double(plan.goals.count)
  }
  
  private func calculateInterestAlignment() -> Double {
    // Higher alignment score if student has more interests that match the plan
    let alignmentScore = min(Double(plan.interests.count) / 3.0, 1.0)
    return alignmentScore
  }
  
  private func weeksFromDate(_ date: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.weekOfYear], from: date, to: Date())
    return max(0, components.weekOfYear ?? 0)
  }
  
  private func monthsFromDate(_ date: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.month], from: date, to: Date())
    return max(0, components.month ?? 0)
  }
  
  private func quartersFromDate(_ date: Date) -> Int {
    let monthsElapsed = monthsFromDate(date)
    return monthsElapsed / 3
  }
}

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)

      content()
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.03))
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
            )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    }
  }
}

struct DetailStat: View {
  var title: String
  var value: String
  var icon: String
  var color: Color

  @State private var isAnimated = false

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(color.opacity(0.1))
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundColor(color)
      }

      Text(value)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .lineLimit(1)

      Text(title)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.3)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
  }
}

struct DetailRow: View {
  var icon: String
  var title: String
  var value: String
  var valueColor: Color = .white

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundColor(valueColor)
        .frame(width: 24)

      Text(title)
        .font(.system(size: 15))
        .foregroundColor(.white.opacity(0.8))

      Spacer()

      Text(value)
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(valueColor)
    }
  }
}

struct StudentDetailCard: View {
  var student: Student

  @State private var isHovered = false

  var body: some View {
    VStack(spacing: 12) {
      // Avatar
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                student.avatarColor == .blue
                  ? Color.blue
                  : student.avatarColor == .green
                    ? Color.green
                    : student.avatarColor == .orange
                      ? Color.orange
                      : student.avatarColor == .purple
                        ? Color.purple
                        : student.avatarColor == .teal
                          ? Color.teal : student.avatarColor == .pink ? Color.pink : Color.indigo,
                Color.black.opacity(0.2),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 60, height: 60)

        Text(student.initials)
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.white)
      }

      // Name & details
      VStack(spacing: 4) {
        Text(student.name)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white)

        Text("Grade \(student.grade)")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.7))
      }

      // Engagement badge
      HStack(spacing: 4) {
        Circle()
          .fill(engagementColor)
          .frame(width: 8, height: 8)

        Text("\(Int(student.engagementScore * 100))% Engaged")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.9))
      }
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 14)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.3)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .scaleEffect(isHovered ? 1.03 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private var engagementColor: Color {
    if student.engagementScore >= 0.7 {
      return .green
    } else if student.engagementScore >= 0.4 {
      return .orange
    } else {
      return .red
    }
  }
}

struct InterestTag: View {
  var interest: Interest

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: interest.iconName)
        .font(.system(size: 12))
        .foregroundColor(interest.color)

      Text(interest.name)
        .font(.system(size: 13))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule()
        .fill(interest.color.opacity(0.15))
    )
    .overlay(
      Capsule()
        .stroke(interest.color.opacity(0.3), lineWidth: 1)
    )
  }
}

struct HobbyTag: View {
  var hobby: Hobby

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: hobby.iconName)
        .font(.system(size: 12))
        .foregroundColor(hobby.color)

      Text(hobby.name)
        .font(.system(size: 13))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule()
        .fill(hobby.color.opacity(0.15))
    )
    .overlay(
      Capsule()
        .stroke(hobby.color.opacity(0.3), lineWidth: 1)
    )
  }
}

struct WrapView<T: Identifiable, Content: View>: View {
  let items: [T]
  let content: (T) -> Content

  @State private var totalHeight: CGFloat = .zero

  var body: some View {
    GeometryReader { geometry in
      generateContent(in: geometry)
    }
    .frame(height: totalHeight)
  }

  private func generateContent(in geometry: GeometryProxy) -> some View {
    var width = CGFloat.zero
    var height = CGFloat.zero

    return ZStack(alignment: .topLeading) {
      ForEach(items) { item in
        content(item)
          .padding(.trailing, 8)
          .padding(.bottom, 8)
          .alignmentGuide(.leading) { dimension in
            if abs(width - dimension.width) > geometry.size.width {
              width = 0
              height -= dimension.height
            }
            let result = width
            if item.id == items.last?.id {
              width = 0
            } else {
              width -= dimension.width
            }
            return result
          }
          .alignmentGuide(.top) { _ in
            let result = height
            if item.id == items.last?.id {
              height = 0
            }
            return result
          }
      }
    }
    .background(
      GeometryReader { geometry in
        Color.clear.onAppear {
          totalHeight = geometry.size.height
        }
      }
    )
  }
}

struct GoalCard: View {
  var goal: Goal

  @State private var isHovered = false

  // Helper computed property to check completion status
  private var isCompleted: Bool {
    return goal.status == .completed
  }

  var body: some View {
    let cardContent = VStack(alignment: .leading, spacing: 12) {
      goalHeaderView

      // Description
      if !goal.description.isEmpty {
        Text(goal.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(3)
      }
    }
    .padding(16)

    let backgroundShape = RoundedRectangle(cornerRadius: 12)
      .fill(Color.white.opacity(0.05))
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(.ultraThinMaterial)
          .opacity(0.3)
      )

    let overlayGradient =
      isCompleted
      ? LinearGradient(
        colors: [Color.green.opacity(0.4), Color.green.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      : LinearGradient(
        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

    return
      cardContent
      .background(backgroundShape)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(overlayGradient, lineWidth: 1)
      )
      .scaleEffect(isHovered ? 1.02 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .onHover { hovering in
        isHovered = hovering
      }
  }

  private var goalHeaderView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(goal.description)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)

        if let dueDate = goal.dueDate {
          Text(formattedDate(dueDate))
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.6))
        }
      }

      Spacer()

      completionBadge
    }
  }

  private var completionBadge: some View {
    Text(goal.status.rawValue)
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(isCompleted ? .green : .orange)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(isCompleted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
      )
  }

  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return "Due: \(formatter.string(from: date))"
  }
}

struct TMIGoal: Identifiable {
  let id = UUID()
  let title: String
  let description: String
  let dueDate: Date
  let isCompleted: Bool
}

// MARK: - Preview

#Preview {
  TMIPlanDetailView(plan: TMIPlan.samplePlan)
}

// MARK: - Edit TMI Plan View

struct EditTMIPlanView: View {
  let plan: TMIPlan
  let onPlanUpdated: (TMIPlan) -> Void
  @Environment(\.dismiss) private var dismiss
  
  @State private var notes: String
  @State private var selectedInterests: [Interest]
  @State private var selectedHobbies: [Hobby]
  @State private var isUpdating = false
  
  init(plan: TMIPlan, onPlanUpdated: @escaping (TMIPlan) -> Void) {
    self.plan = plan
    self.onPlanUpdated = onPlanUpdated
    _notes = State(initialValue: plan.notes)
    _selectedInterests = State(initialValue: plan.interests)
    _selectedHobbies = State(initialValue: plan.hobbies)
  }
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
              Image(systemName: "pencil.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.tmiSecondary)
              
              Text("Edit TMI Plan")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
              
              Text("Update the plan details")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 20)
            
            // Plan Info (Read-only)
            TMIGlassCard(style: .default) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Plan Information")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                  HStack {
                    Text("Model:")
                      .foregroundColor(.white.opacity(0.7))
                    Text(plan.model.rawValue)
                      .foregroundColor(.white)
                      .fontWeight(.medium)
                  }
                  
                  HStack {
                    Text("Student:")
                      .foregroundColor(.white.opacity(0.7))
                    Text(plan.student.name)
                      .foregroundColor(.white)
                      .fontWeight(.medium)
                  }
                  
                  HStack {
                    Text("Progress:")
                      .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(plan.progress * 100))%")
                      .foregroundColor(.tmiSecondary)
                      .fontWeight(.medium)
                  }
                }
              }
            }
            
            // Notes Section
            TMIGlassCard(style: .default) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Notes")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                TextEditor(text: $notes)
                  .frame(minHeight: 100)
                  .scrollContentBackground(.hidden)
                  .background(Color.clear)
                  .foregroundColor(.white)
                  .font(.system(size: 16))
              }
            }
            
            // Interests Section
            TMIGlassCard(style: .default) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Associated Interests")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                  ForEach(Interest.expandedSampleInterests) { interest in
                    InterestToggleCard(
                      interest: interest,
                      isSelected: selectedInterests.contains(interest),
                      onToggle: { toggleInterest(interest) }
                    )
                  }
                }
              }
            }
            
            // Hobbies Section
            TMIGlassCard(style: .default) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Associated Hobbies")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                  ForEach(Hobby.expandedSampleHobbies) { hobby in
                    HobbyToggleCard(
                      hobby: hobby,
                      isSelected: selectedHobbies.contains(hobby),
                      onToggle: { toggleHobby(hobby) }
                    )
                  }
                }
              }
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("Edit Plan")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            updatePlan()
          }
          .foregroundColor(.tmiSecondary)
          .disabled(isUpdating)
        }
      }
      .preferredColorScheme(.dark)
    }
  
  private func toggleInterest(_ interest: Interest) {
    if selectedInterests.contains(interest) {
      selectedInterests.removeAll { $0.id == interest.id }
    } else {
      selectedInterests.append(interest)
    }
  }
  
  private func toggleHobby(_ hobby: Hobby) {
    if selectedHobbies.contains(hobby) {
      selectedHobbies.removeAll { $0.id == hobby.id }
    } else {
      selectedHobbies.append(hobby)
    }
  }
  
  private func updatePlan() {
    isUpdating = true
    
    Task {
      do {
        var updatedPlan = plan
        updatedPlan.notes = notes
        updatedPlan.interests = selectedInterests
        updatedPlan.hobbies = selectedHobbies
        updatedPlan.lastUpdated = Date()
        
        _ = try await TMIPlanService().updatePlan(updatedPlan)
        
        await MainActor.run {
          onPlanUpdated(updatedPlan)
          dismiss()
        }
      } catch {
        print("Error updating TMI plan: \(error)")
      }
      
      await MainActor.run {
        isUpdating = false
      }
    }
  }
}

// MARK: - Supporting Views for Edit

struct InterestToggleCard: View {
  let interest: Interest
  let isSelected: Bool
  let onToggle: () -> Void
  
  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 8) {
        Image(systemName: interest.iconName)
          .font(.system(size: 14))
          .foregroundColor(interest.color)
        
        Text(interest.name)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? interest.color.opacity(0.2) : Color.white.opacity(0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            isSelected ? interest.color.opacity(0.5) : Color.white.opacity(0.2),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }
}

struct HobbyToggleCard: View {
  let hobby: Hobby
  let isSelected: Bool
  let onToggle: () -> Void
  
  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 8) {
        Image(systemName: hobby.iconName)
          .font(.system(size: 14))
          .foregroundColor(hobby.color)
        
        Text(hobby.name)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.white)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? hobby.color.opacity(0.2) : Color.white.opacity(0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            isSelected ? hobby.color.opacity(0.5) : Color.white.opacity(0.2),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }
}

