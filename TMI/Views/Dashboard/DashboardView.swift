//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI
import Charts
import Combine

@Observable
class DashboardViewModel {
    var engagementData: [EngagementData] = []
    var totalStudents: Int = 0
    var activeTMIPlans: Int = 0
    var interestsIdentified: Int = 0
    var surveysCompleted: Int = 0
    var plansAligned: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchDashboardData()
    }
    
    func fetchDashboardData() {
        // Implement your data fetching logic here
        // This could involve Firestore queries or other data sources
        // Update the published properties with the fetched data
    }
}

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var selectedDataPoint: AlignmentData?
    @State private var showingInsightsSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    recentsView
                    alignmentChartView
                    insightsButton
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(
                Color.tmiBackground
                    .opacity(0.7)
                    .ignoresSafeArea()
            )
            .navigationTitle("TMI Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("View Profile", action: { })
                        Button("Settings", action: { })
                        Divider()
                        Button("Log Out", role: .destructive, action: { })
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(Color.tmiPrimary)
                            .contentTransition(.symbolEffect(.automatic))
                    }
                }
            }
            .sheet(isPresented: $showingInsightsSheet) {
                InsightsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Educator!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.tmiPrimary)
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var recentsView: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 20) {
                quickStatsView
                    .frame(maxWidth: .infinity)
                recentActivitiesView
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 20) {
                quickStatsView
                recentActivitiesView
            }
        }
    }
    
    private var quickStatsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Stats")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.tmiText)
                
                Spacer()
                
                Picker("Time Frame", selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases) { timeFrame in
                        Text(timeFrame.rawValue).tag(timeFrame)
                    }
                }
                .pickerStyle(.menu)
                .fontWeight(.medium)
                .tint(Color.tmiPrimary)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(spacing: 16) {
                StatCard(title: "Total Students", value: "\(viewModel.totalStudents)", icon: "person.3", color: .blue)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                
                StatCard(title: "Surveys Completed", value: "\(viewModel.surveysCompleted)", icon: "checkmark.circle", color: .green)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                
                StatCard(title: "Plans Aligned", value: "\(viewModel.plansAligned)", icon: "star", color: .orange)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTimeFrame)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.tmiPrimary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var recentActivitiesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activities")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.tmiText)
                
                Spacer()
                
                Button(action: {}) {
                    Label("View All", systemImage: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.tmiPrimary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(RecentActivity.sampleRecentActivities) { activity in
                    if RecentActivity.sampleRecentActivities[0].id != activity.id {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    ActivityRow(activity: activity)
                        .contentTransition(.interpolate)
                }
            }
        }
        .padding()
        .frame(maxHeight: 350)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.tmiPrimary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var alignmentChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interest Alignment Progress")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.tmiText)
            
            Divider()
                .padding(.vertical, 4)
            
            Chart {
                ForEach(alignmentData) { dataPoint in
                    LineMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", dataPoint.alignmentPercentage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.tmiPrimary, .tmiPrimary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    AreaMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", dataPoint.alignmentPercentage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .tmiPrimary.opacity(0.3),
                                .tmiPrimary.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", dataPoint.alignmentPercentage)
                    )
                    .foregroundStyle(Color.white)
                    .shadow(color: .tmiPrimary.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                
                if let selected = selectedDataPoint {
                    RuleMark(x: .value("Time Period", selected.timePeriod))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(Int(selected.alignmentPercentage * 100))%")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(Color.tmiPrimary)
                                
                                Text(selected.timePeriod)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.tmiPrimary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    
                    PointMark(
                        x: .value("Time Period", selected.timePeriod),
                        y: .value("Alignment %", selected.alignmentPercentage)
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .tmiPrimary, radius: 3, x: 0, y: 0)
                    .symbolSize(250)
                    
                    PointMark(
                        x: .value("Time Period", selected.timePeriod),
                        y: .value("Alignment %", selected.alignmentPercentage)
                    )
                    .foregroundStyle(Color.tmiPrimary)
                    .symbolSize(150)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.gray.opacity(0.5))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.gray.opacity(0.5))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...1)
            .chartLegend(.hidden)
            .frame(height: 250)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if let plotFrame = proxy.plotFrame {
                                        let currentX = value.location.x - geometry[plotFrame].origin.x
                                        guard currentX >= 0, currentX < proxy.plotSize.width else {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                selectedDataPoint = nil
                                            }
                                            return
                                        }
                                        
                                        guard let timePeriod: String = proxy.value(atX: currentX) else { return }
                                        
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            selectedDataPoint = alignmentData.first { $0.timePeriod == timePeriod }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        selectedDataPoint = nil
                                    }
                                }
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Insights")
                    .font(.headline)
                    .foregroundStyle(Color.tmiText)
                
                HStack(alignment: .top, spacing: 20) {
                    insightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Average",
                        value: "\(averageAlignment())%",
                        color: .blue
                    )
                    
                    insightCard(
                        icon: "arrow.up.forward",
                        title: "Highest",
                        value: "\(highestAlignment())%",
                        subtitle: "in \(highestAlignmentPeriod())",
                        color: .green
                    )
                    
                    insightCard(
                        icon: trendIcon(),
                        title: "Trend",
                        value: alignmentTrend(),
                        color: trendColor()
                    )
                }
            }
            .padding(.top, 10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.tmiPrimary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func insightCard(icon: String, title: String, value: String, subtitle: String? = nil, color: Color) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.tmiText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func trendIcon() -> String {
        let trend = alignmentTrend()
        if trend == "Increasing" {
            return "arrow.up.right"
        } else if trend == "Decreasing" {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    private func trendColor() -> Color {
        let trend = alignmentTrend()
        if trend == "Increasing" {
            return .green
        } else if trend == "Decreasing" {
            return .red
        } else {
            return .orange
        }
    }
    
    private var insightsButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showingInsightsSheet = true
            }
        }) {
            Label("View Detailed Insights", systemImage: "lightbulb.fill")
                .symbolEffect(.pulse, options: .repeating, value: showingInsightsSheet)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.tmiPrimary, .tmiPrimary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .tmiPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.scale)
    }
    
    private func averageAlignment() -> String {
        let average = alignmentData.map { $0.alignmentPercentage }.reduce(0, +) / Double(alignmentData.count)
        return String(format: "%.1f", average * 100)
    }
    
    private func highestAlignment() -> String {
        let highest = alignmentData.map { $0.alignmentPercentage }.max() ?? 0
        return String(format: "%.1f", highest * 100)
    }
    
    private func highestAlignmentPeriod() -> String {
        alignmentData.max { $0.alignmentPercentage < $1.alignmentPercentage }?.timePeriod ?? "N/A"
    }
    
    private func alignmentTrend() -> String {
        let values = alignmentData.map { $0.alignmentPercentage }
        if let first = values.first, let last = values.last {
            if first < last {
                return "Increasing"
            } else if first > last {
                return "Decreasing"
            } else {
                return "Stable"
            }
        }
        return "No Data"
    }
}

struct AlignmentData: Identifiable {
    let id = UUID()
    let timePeriod: String  // e.g., "Week 1", "Month 1"
    let alignmentPercentage: Double  // Value between 0 and 1
}

let alignmentData: [AlignmentData] = [
    AlignmentData(timePeriod: "Week 1", alignmentPercentage: 0.25),
    AlignmentData(timePeriod: "Week 2", alignmentPercentage: 0.40),
    AlignmentData(timePeriod: "Week 3", alignmentPercentage: 0.55),
    AlignmentData(timePeriod: "Week 4", alignmentPercentage: 0.70),
    AlignmentData(timePeriod: "Week 5", alignmentPercentage: 0.85),
]

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}

#Preview {
    DashboardView()
}
