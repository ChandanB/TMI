//
//  UIComponents.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import Charts
import Combine
import Foundation
import SwiftUI

// MARK: - Premium Glass Tab Bar

struct PremiumGlassTabBar: View {
  @Binding var selectedTab: MainTabView.Tab
  @Binding var previousTab: MainTabView.Tab
  let availableTabs: [MainTabView.Tab]
  @Namespace private var tabAnimation

  // MVP shows only Students and TMI Plans tabs
  private var displayedTabs: [MainTabView.Tab] {
    return availableTabs
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(displayedTabs) { tab in
        tabButton(for: tab)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 30)
        .fill(Color.black.opacity(0.2))
        .background(
          RoundedRectangle(cornerRadius: 30)
            .fill(.ultraThinMaterial)
            .opacity(0.8)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 30)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    )
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
  }

  private func tabButton(for tab: MainTabView.Tab) -> some View {
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        previousTab = selectedTab
        selectedTab = tab
      }
    } label: {
      VStack(spacing: 4) {
        ZStack {
          if selectedTab == tab {
            RoundedRectangle(cornerRadius: 16)
              .fill(
                LinearGradient(
                  colors: [
                    Color.tmiSecondary.opacity(0.4),
                    Color.tmiSecondary.opacity(0.2),
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .matchedGeometryEffect(id: "TabBackground", in: tabAnimation)
              .frame(height: 40)
          }

          HStack(spacing: 8) {
            Image(systemName: iconName(for: tab))
              .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
              .symbolEffect(
                .bounce,
                options: .speed(1.5),
                value: selectedTab == tab && previousTab != tab
              )

            if selectedTab == tab {
              Text(shortTabLabel(for: tab))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
          }
          .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.6))
          .frame(height: 40)
          .padding(.horizontal, selectedTab == tab ? 14 : 0)
        }
      }
      .frame(maxWidth: selectedTab == tab ? .infinity : 50)
    }
    .buttonStyle(.plain)
  }

  private func shortTabLabel(for tab: MainTabView.Tab) -> String {
    switch tab {
    case .students: return "Students"
    case .tmiPlans: return "Plans"
    case .dashboard: return "Dashboard"
    case .districtDashboard: return "District"
    case .forms: return "Forms"
    case .careerExplorer: return "Careers"
    case .interests: return "Interests"
    case .resources: return "Resources"
    case .settings: return "Settings"
    }
  }

  private func iconName(for tab: MainTabView.Tab) -> String {
    switch tab {
    case .students: return "person.3.fill"
    case .tmiPlans: return "doc.text.fill"
    case .dashboard: return "chart.bar.fill"
    case .districtDashboard: return "building.2.fill"
    case .forms: return "list.clipboard.fill"
    case .careerExplorer: return "briefcase.fill"
    case .interests: return "heart.fill"
    case .resources: return "books.vertical.fill"
    case .settings: return "gearshape.fill"
    }
  }
}

// MARK: - Premium Sidebar List

struct PremiumSidebarList: View {
  @Binding var selectedTab: MainTabView.Tab
  let availableTabs: [MainTabView.Tab]
  @Namespace private var sidebarAnimation

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        ForEach(availableTabs, id: \.id) { tab in
          sidebarButton(for: tab)
            .padding(.horizontal, 16)
        }
      }
      .padding(.bottom, 20)
    }
  }

  private func sidebarButton(for tab: MainTabView.Tab) -> some View {
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        selectedTab = tab
      }
    } label: {
      HStack(spacing: 16) {
        // Icon
        ZStack {
          Circle()
            .fill(selectedTab == tab ? Color.tmiSecondary.opacity(0.2) : Color.clear)
            .frame(width: 36, height: 36)

          Image(systemName: iconName(for: tab))
            .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
            .foregroundColor(selectedTab == tab ? Color.tmiSecondary : Color.white.opacity(0.6))
        }

        // Label
        Text(tabLabel(for: tab))
          .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
          .foregroundColor(selectedTab == tab ? Color.white : Color.white.opacity(0.7))

        Spacer()

        // Selection indicator
        if selectedTab == tab {
          Circle()
            .fill(Color.tmiSecondary)
            .frame(width: 6, height: 6)
            .matchedGeometryEffect(id: "SidebarSelection", in: sidebarAnimation)
        }
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(selectedTab == tab ? Color.white.opacity(0.05) : Color.clear)
          .background(
            selectedTab == tab
              ? RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0.1)
              : RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            selectedTab == tab
              ? LinearGradient(
                colors: [Color.white.opacity(0.3), Color.clear, Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(SidebarButtonStyle())
  }

  private func tabLabel(for tab: MainTabView.Tab) -> String {
    switch tab {
    case .students: return "Students"
    case .tmiPlans: return "TMI Plans"
    case .dashboard: return "Dashboard"
    case .districtDashboard: return "District"
    case .forms: return "Forms"
    case .careerExplorer: return "Career Explorer"
    case .interests: return "Interests & Hobbies"
    case .resources: return "Resources"
    case .settings: return "Settings"
    }
  }

  private func iconName(for tab: MainTabView.Tab) -> String {
    switch tab {
    case .students: return "person.3.fill"
    case .tmiPlans: return "doc.text.fill"
    case .dashboard: return "chart.bar.fill"
    case .districtDashboard: return "building.2.fill"
    case .forms: return "list.clipboard.fill"
    case .careerExplorer: return "briefcase.fill"
    case .interests: return "heart.fill"
    case .resources: return "books.vertical.fill"
    case .settings: return "gearshape.fill"
    }
  }
}

struct StatCircle: View {
  var value: String
  var title: String
  var color: Color
  var icon: String

  @State private var isAnimated = false

  var body: some View {
    VStack(spacing: 10) {
      ZStack {
        Circle()
          .stroke(color.opacity(0.2), lineWidth: 8)
          .frame(width: 80, height: 80)

        Circle()
          .trim(from: 0, to: isAnimated ? 0.75 : 0)
          .stroke(
            color,
            style: StrokeStyle(lineWidth: 8, lineCap: .round)
          )
          .frame(width: 80, height: 80)
          .rotationEffect(Angle(degrees: -90))
          .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)

        VStack(spacing: 2) {
          Text(value)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)

          Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
        }
      }

      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.8))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
        isAnimated = true
      }
    }
  }
}

// MARK: - Sidebar Button Style

struct SidebarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
  }
}

// MARK: - Loading Animation View

struct LottieLoadingView: View {
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      // Outer circle
      Circle()
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [
              Color.tmiSecondary.opacity(0),
              Color.tmiSecondary,
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
          ),
          lineWidth: 6
        )
        .frame(width: 80, height: 80)
        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
        .animation(
          Animation.linear(duration: 2)
            .repeatForever(autoreverses: false),
          value: isAnimating
        )

      // Inner pulsing circle
      Circle()
        .fill(Color.tmiSecondary.opacity(0.3))
        .frame(width: 60, height: 60)
        .scaleEffect(isAnimating ? 0.8 : 0.6)
        .opacity(isAnimating ? 0.6 : 0.3)
        .animation(
          Animation.easeInOut(duration: 1)
            .repeatForever(autoreverses: true),
          value: isAnimating
        )

      // TMI logo
      Image(systemName: "brain.head.profile")
        .font(.system(size: 24, weight: .medium))
        .foregroundColor(.white)
    }
    .onAppear {
      isAnimating = true
    }
  }
}

struct RecommendationRow: View {
  var recommendation: InsightRecommendation

  @State private var isHovered = false

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: recommendation.icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(recommendation.color)
        .frame(width: 30, height: 30)
        .padding(4)
        .background(
          Circle()
            .fill(recommendation.color.opacity(0.1))
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(recommendation.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)

        Text(recommendation.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(isHovered ? nil : 2)
      }

      Spacer()
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: - Custom Time Frame Selector

struct TimeFrameSelector: View {
  @Binding var selection: TimeFrame

  @Namespace private var animation

  var body: some View {
    HStack(spacing: 0) {
      ForEach(TimeFrame.allCases) { timeFrame in
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selection = timeFrame
          }
        } label: {
          Text(timeFrame.rawValue)
            .font(.system(size: 13, weight: selection == timeFrame ? .semibold : .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(selection == timeFrame ? .white : .white.opacity(0.6))
            .background(
              ZStack {
                if selection == timeFrame {
                  RoundedRectangle(cornerRadius: 8)
                    .fill(
                      LinearGradient(
                        colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    )
                    .matchedGeometryEffect(id: "TimeFrameBackground", in: animation)
                }
              }
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.white.opacity(0.05))
    )
  }
}

// MARK: - Insights Card

struct InsightsButtonView: View {
  var action: () -> Void

  @State private var isHovered = false
  @State private var isPressed = false

  var body: some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.1)) {
        isPressed = true
      }

      // Slight delay to show press effect
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeInOut(duration: 0.1)) {
          isPressed = false
        }
        action()
      }
    }) {
      HStack(spacing: 16) {
        Image(systemName: "lightbulb.fill")
          .font(.system(size: 18, weight: .semibold))
          .symbolEffect(.pulse, options: .repeating, value: isHovered)

        Text("View Detailed Insights")
          .font(.system(size: 16, weight: .semibold))

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .opacity(0.8)
          .offset(x: isHovered ? 3 : 0)
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(
            LinearGradient(
              colors: [
                Color.tmiSecondary,
                Color.tmiSecondary.opacity(0.8),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(
            color: Color.tmiSecondary.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 12 : 8,
            x: 0, y: isHovered ? 8 : 5)
      )
      .foregroundStyle(.white)
      .scaleEffect(isPressed ? 0.98 : 1.0)
      .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: -  Alignment Chart

struct DashboardAlignmentChartView: View {
  var alignmentData: [AlignmentData]
  @State private var selectedDataPoint: AlignmentData?
  @State private var isAnimating = false

  var body: some View {
    TMIGlassCard(style: .dashboard) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Alignment Performance")
              .font(.title2.weight(.semibold))
              .foregroundColor(.white)

            Text("Student-Interest alignment trends")
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.7))
          }

          Spacer()

          HStack(spacing: 15) {
            ChartStatistic(
              title: "Average",
              value: String(
                format: "%.1f%%",
                (alignmentData.map { $0.alignmentPercentage }.reduce(0, +)
                  / Double(alignmentData.count)) * 100),
              trend: .neutral
            )

            ChartStatistic(
              title: "Highest",
              value: String(
                format: "%.1f%%", (alignmentData.map { $0.alignmentPercentage }.max() ?? 0) * 100),
              trend: .positive
            )
          }
        }

        Divider()
          .background(Color.white.opacity(0.2))

        chart
          .frame(height: 250)
          .padding(.top, 8)
      }
    }
  }

  @State private var selectedTimePeriod: String?

  // MARK: - Chart Components
  
  private var areaGradient: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: Color.tmiSecondary.opacity(0.3), location: 0),
        .init(color: Color.tmiSecondary.opacity(0.1), location: 1),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
  
  private var lineStyle: StrokeStyle {
    StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
  }
  
  private var chart: some View {
    Chart {
      ForEach(alignmentData) { data in
        createAreaMark(for: data)
        createLineMark(for: data)
        createPointMark(for: data)
        
        if shouldShowAnnotation(for: data) {
          createAnnotationMark(for: data)
        }
      }
    }
    .chartYScale(domain: 0...1)
    .modifier(ChartAxisModifier())
    .modifier(ChartAccessibilityModifier())
    .modifier(ChartInteractionModifier(selectedDataPoint: $selectedDataPoint, alignmentData: alignmentData))
    .animation(.easeInOut(duration: 0.3), value: selectedDataPoint)
  }
  
  private func createAreaMark(for data: AlignmentData) -> some ChartContent {
    AreaMark(
      x: .value("Time Period", data.timePeriod),
      y: .value("Alignment Percentage", data.alignmentPercentage)
    )
    .foregroundStyle(areaGradient)
    .interpolationMethod(.catmullRom)
  }
  
  private func createLineMark(for data: AlignmentData) -> some ChartContent {
    LineMark(
      x: .value("Time Period", data.timePeriod),
      y: .value("Alignment Percentage", data.alignmentPercentage)
    )
    .lineStyle(lineStyle)
    .foregroundStyle(Color.tmiSecondary)
    .interpolationMethod(.catmullRom)
  }
  
  private func createPointMark(for data: AlignmentData) -> some ChartContent {
    PointMark(
      x: .value("Time Period", data.timePeriod),
      y: .value("Alignment Percentage", data.alignmentPercentage)
    )
    .symbolSize(selectedDataPoint?.id == data.id ? 120 : 80)
    .foregroundStyle(selectedDataPoint?.id == data.id ? Color.white : Color.tmiSecondary)
    .opacity(selectedDataPoint?.id == data.id ? 1.0 : 0.8)
  }
  
  private func shouldShowAnnotation(for data: AlignmentData) -> Bool {
    guard let selectedDataPoint = selectedDataPoint else { return false }
    return selectedDataPoint.id == data.id
  }
  
  private func createAnnotationMark(for data: AlignmentData) -> some ChartContent {
    PointMark(
      x: .value("Time Period", data.timePeriod),
      y: .value("Alignment Percentage", data.alignmentPercentage)
    )
    .annotation(position: .top, alignment: .center, spacing: 8) {
      createAnnotationLabel(for: data)
    }
  }
  
  private func createAnnotationLabel(for data: AlignmentData) -> some View {
    Text("\(Int(data.alignmentPercentage * 100))%")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.tmiSecondary)
          .shadow(radius: 2)
      )
  }
}

// MARK: - Chart Modifiers

struct ChartAxisModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .chartYAxis {
        AxisMarks(preset: .aligned, position: .leading, values: .automatic(desiredCount: 5)) { value in
          AxisGridLine(
            centered: true,
            stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
          )
          .foregroundStyle(Color.white.opacity(0.2))
          
          AxisValueLabel {
            if let doubleValue = value.as(Double.self) {
              Text("\(Int(doubleValue * 100))%")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.8))
            }
          }
        }
      }
      .chartXAxis {
        AxisMarks(preset: .aligned, values: .automatic) { value in
          AxisGridLine(
            centered: true,
            stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
          )
          .foregroundStyle(Color.white.opacity(0.1))

          AxisValueLabel {
            if let stringValue = value.as(String.self) {
              Text(stringValue)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.8))
            }
          }
        }
      }
  }
}

struct ChartAccessibilityModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .accessibilityLabel("Alignment Performance Chart")
      .accessibilityValue("Shows student-interest alignment trends over time periods")
      .accessibilityHint("Swipe to explore data points")
  }
}

struct ChartInteractionModifier: ViewModifier {
  @Binding var selectedDataPoint: AlignmentData?
  let alignmentData: [AlignmentData]
  
  func body(content: Content) -> some View {
    content
      .chartBackground { _ in
        Rectangle().fill(Color.clear)
      }
      .chartPlotStyle { plotArea in
        plotArea.background(Color.clear)
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateSelectedDataPoint(at: value.location)
          }
          .onEnded { _ in
            selectedDataPoint = nil
          }
      )
  }
  
  private func updateSelectedDataPoint(at location: CGPoint) {
    // Simplified version - in practice you'd use ChartProxy
    if let closestDataPoint = alignmentData.first {
      selectedDataPoint = closestDataPoint
    }
  }
}

struct ChartStatistic: View {
  enum Trend {
    case positive
    case negative
    case neutral
  }

  var title: String
  var value: String
  var trend: Trend

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundColor(.white.opacity(0.6))

      HStack(alignment: .bottom, spacing: 4) {
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundColor(.white)

        Image(systemName: trendIcon)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(trendColor)
          .padding(3)
          .background(trendColor.opacity(0.2))
          .cornerRadius(4)
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
    )
  }

  private var trendIcon: String {
    switch trend {
    case .positive:
      return "arrow.up.right"
    case .negative:
      return "arrow.down.right"
    case .neutral:
      return "arrow.right"
    }
  }

  private var trendColor: Color {
    switch trend {
    case .positive:
      return .green
    case .negative:
      return .red
    case .neutral:
      return .orange
    }
  }
}

// MARK: -  Stat Card

struct StatCard: View {
  var title: String
  var value: String
  var icon: String
  var color: Color

  @State private var isAnimated = false
  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(color.opacity(0.15))
          .frame(width: 50, height: 50)

        Image(systemName: icon)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(color)
          .rotationEffect(Angle(degrees: isAnimated ? 5 : 0))
          .animation(
            Animation.easeInOut(duration: 2)
              .repeatForever(autoreverses: true),
            value: isAnimated
          )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white.opacity(0.7))

        Text(value)
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .foregroundColor(.white)
          .contentTransition(.numericText())
      }

      Spacer()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(color.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial.opacity(0.4))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(
          LinearGradient(
            colors: [color.opacity(0.4), color.opacity(0.1)],
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
      isAnimated = true
    }
  }
}


//struct StatCard: View {
//    let title: String
//    let value: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            HStack {
//                Image(systemName: icon)
//                    .foregroundColor(color)
//                Spacer()
//            }
//            Text(value)
//                .font(.title2)
//                .fontWeight(.bold)
//                .frame(maxWidth: .infinity, alignment: .leading)
//            Text(title)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .padding()
//        .background(Color(UIColor.secondarySystemBackground))
//        .cornerRadius(12)
//    }
//}

