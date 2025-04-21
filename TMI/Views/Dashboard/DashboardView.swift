//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import FirebaseFirestore
import SwiftUI
import Observation
import Combine
import Charts

// MARK: - Dashboard Data Model

struct DashboardData: Equatable {
    var engagementData: [EngagementData] = []
    var totalStudents: Int = 0
    var activeTMIPlans: Int = 0
    var interestsIdentified: Int = 0
    var surveysCompleted: Int = 0
    var plansAligned: Int = 0
}

// MARK: - Environment Key

struct DashboardStateModelKey: EnvironmentKey {
    static let defaultValue: DashboardStateModel = DashboardStateModel()
}

extension EnvironmentValues {
    var dashboardStateModel: DashboardStateModel {
        get { self[DashboardStateModelKey.self] }
        set { self[DashboardStateModelKey.self] = newValue }
    }
}

// MARK: - State Model

@Observable
final class DashboardStateModel: BaseStateModel<DashboardData, IdentifiableError> {
    // MARK: - Dependencies
    // Add any repositories or services here
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Initialize UI state
        ui.set("selectedTimeFrame", value: TimeFrame.week)
        ui.set("selectedDataPoint", value: nil as AlignmentData?)
        ui.set("showingInsightsSheet", value: false)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Data Fetching
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // In a real implementation, this would fetch from a repository
            let dashboardData = DashboardData(
                engagementData: [],
                totalStudents: 125,
                activeTMIPlans: 87,
                interestsIdentified: 342,
                surveysCompleted: 98,
                plansAligned: 76
            )
            
            updateState(.loaded(dashboardData))
        } catch {
            handleError(error, userFriendlyMessage: "Failed to load dashboard data")
        }
    }
    
    @MainActor
    override func refresh() async {
        await fetch()
    }
    
    // MARK: - UI State Accessors
    
    var selectedTimeFrame: TimeFrame {
        get { return ui.get("selectedTimeFrame") ?? .week }
        set { ui.set("selectedTimeFrame", value: newValue) }
    }
    
    var selectedDataPoint: AlignmentData? {
        get { return ui.get("selectedDataPoint") }
        set { ui.set("selectedDataPoint", value: newValue) }
    }
    
    var showingInsightsSheet: Bool {
        get { return ui.get("showingInsightsSheet") ?? false }
        set { ui.set("showingInsightsSheet", value: newValue) }
    }
    
    // MARK: - Helper Methods
    
    func averageAlignment() -> String {
        let average = alignmentData.map { $0.alignmentPercentage }.reduce(0, +) / Double(alignmentData.count)
        return String(format: "%.1f", average * 100)
    }
    
    func highestAlignment() -> String {
        let highest = alignmentData.map { $0.alignmentPercentage }.max() ?? 0
        return String(format: "%.1f", highest * 100)
    }
    
    func highestAlignmentPeriod() -> String {
        alignmentData.max { $0.alignmentPercentage < $1.alignmentPercentage }?.timePeriod ?? "N/A"
    }
    
    func alignmentTrend() -> String {
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
    
    func trendIcon() -> String {
        let trend = alignmentTrend()
        if trend == "Increasing" {
            return "arrow.up.right"
        } else if trend == "Decreasing" {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    func trendColor() -> Color {
        let trend = alignmentTrend()
        if trend == "Increasing" {
            return .green
        } else if trend == "Decreasing" {
            return .red
        } else {
            return .orange
        }
    }
}


// MARK: - Dynamic Background Components

struct DashboardBackgroundView: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated overlays
            Circle()
                .fill(Color.tmiPrimary.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150, y: animateGradient ? -200 : -250)
                .animation(
                    Animation.easeInOut(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: animateGradient
                )
            
            Circle()
                .fill(Color.tmiSecondary.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 170, y: animateGradient ? 200 : 300)
                .animation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: animateGradient
                )
            
            // Particle effect
            ParticleEffect()
                .opacity(0.3)
        }
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - Enhanced Glass Card

struct DashboardGlassCard<Content: View>: View {
    var content: Content
    var hasBorder: Bool = true
    var padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    
    @State private var isHovered = false
    
    init(hasBorder: Bool = true,
         padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasBorder = hasBorder
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        hasBorder ?
                        LinearGradient(
                            colors: [.white.opacity(0.6), .clear, .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : LinearGradient(colors: [.clear], startPoint: .center, endPoint: .center),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Enhanced Stat Card

struct EnhancedStatCard: View {
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

// MARK: - Enhanced Activity Row

struct EnhancedActivityRow: View {
    var activity: RecentActivity
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Activity Icon
            ZStack {
                Circle()
                    .fill(activity.iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(activity.iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(activity.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.timeAgo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                if activity.showProgress {
                    ProgressView(value: activity.progressValue)
                        .progressViewStyle(
                            GlowingProgressViewStyle(color: activity.iconColor)
                        )
                        .frame(width: 50)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovered ? 0.05 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Glowing Progress View Style

struct GlowingProgressViewStyle: ProgressViewStyle {
    var color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: geometry.size.width, height: 4)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 4)
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Enhanced Alignment Chart

struct EnhancedAlignmentChartView: View {
    var alignmentData: [AlignmentData]
    @State private var selectedDataPoint: AlignmentData?
    @State private var isAnimating = false
    
    var body: some View {
        DashboardGlassCard {
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
                            value: String(format: "%.1f%%", (alignmentData.map { $0.alignmentPercentage }.reduce(0, +) / Double(alignmentData.count)) * 100),
                            trend: .neutral
                        )
                        
                        ChartStatistic(
                            title: "Highest",
                            value: String(format: "%.1f%%", (alignmentData.map { $0.alignmentPercentage }.max() ?? 0) * 100),
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

    private var chart: some View {
        Chart {
            ForEach(alignmentData) { data in
                LineMark(
                    x: .value("Period", data.timePeriod),
                    y: .value("Alignment", data.alignmentPercentage)
                )
                .lineStyle(StrokeStyle(lineWidth: 3))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.tmiSecondary, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.blue.opacity(0.5), radius: 4, y: 2)
                
                AreaMark(
                    x: .value("Period", data.timePeriod),
                    y: .value("Alignment", data.alignmentPercentage)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.tmiSecondary.opacity(0.3), location: 0),
                            .init(color: Color.tmiSecondary.opacity(0.05), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                PointMark(
                    x: .value("Period", data.timePeriod),
                    y: .value("Alignment", data.alignmentPercentage)
                )
                .symbolSize(selectedDataPoint?.id == data.id ? 150 : 100)
                .foregroundStyle(
                    selectedDataPoint?.id == data.id ? Color.white : Color.tmiSecondary
                )
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel() {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.1))
                
                AxisValueLabel {
                    Text(value.as(String.self) ?? "")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
        }
        .chartYScale(domain: 0...1)
        .chartXSelection(value: $selectedTimePeriod)
        .chartBackground { _ in
            Color.clear
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let plotFrame = proxy.plotFrame {
                                    let x = value.location.x - geo[plotFrame].origin.x
                                    if let index = proxy.value(atX: x, as: String.self),
                                       let matchedDataPoint = alignmentData.first(where: { $0.timePeriod == index }) {
                                        selectedDataPoint = matchedDataPoint
                                    }
                                }
                            }
                            .onEnded { _ in
                                selectedDataPoint = nil
                            }
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDataPoint)
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

// MARK: - Custom Time Frame Selector

struct EnhancedTimeFrameSelector: View {
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
                                Color.tmiSecondary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.tmiSecondary.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 8 : 5)
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

// MARK: - Enhanced Insights View

struct EnhancedInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.08, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Student Insights")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Advanced analytics and recommendations")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(8)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)
                    
                    // Insights content
                    DashboardGlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Performance Overview")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                StatCircle(
                                    value: "78%",
                                    title: "Survey\nCompletion",
                                    color: .green,
                                    icon: "chart.bar.fill"
                                )
                                
                                StatCircle(
                                    value: "65%",
                                    title: "Interest\nAlignment",
                                    color: Color.tmiSecondary,
                                    icon: "person.fill.checkmark"
                                )
                                
                                StatCircle(
                                    value: "82%",
                                    title: "Plan\nEffectiveness",
                                    color: .orange,
                                    icon: "star.fill"
                                )
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    
                    // Recommendations
                    DashboardGlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Recommendations")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                            
                            ForEach(InsightRecommendation.sampleRecommendations) { recommendation in
                                RecommendationRow(recommendation: recommendation)
                                
                                if recommendation.id != InsightRecommendation.sampleRecommendations.last!.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                }
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            // Schedule meeting action
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Schedule Meeting")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button {
                            // Export report action
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Report")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
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
            
            Button {
                // Action for recommendation
            } label: {
                Text("Apply")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(recommendation.color.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .strokeBorder(recommendation.color.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .foregroundColor(recommendation.color)
            }
            .buttonStyle(ScaleButtonStyle())
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

// MARK: - Redesigned Dashboard View

struct DashboardView: View {
    @Environment(\.dashboardStateModel) var stateModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingInsightsSheet = false
    @State private var headerAnimation = false
    @State private var cardsAnimation = false
    @State private var chartAnimation = false
    @State private var buttonAnimation = false
    
    var body: some View {
        ZStack {
            // Dynamic background
            DashboardBackgroundView()
            
            Group {
                switch stateModel.state {
                case .idle, .loading:
                    loadingView
                    
                case .loaded(let dashboardData):
                    dashboardContent(dashboardData)
                    
                case .error(let error):
                    errorView(error)
                }
            }
        }
        .navigationTitle("TMI Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Profile menu action
                } label: {
                    HStack(spacing: 8) {
                        Text("Educator")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.tmiSecondary.opacity(0.8), Color.tmiSecondary.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .padding(-4)
                            )
                    }
                    .padding(8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial.opacity(0.5))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $showingInsightsSheet) {
            EnhancedInsightsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await stateModel.fetch()
        }
        .refreshable {
            await stateModel.refresh()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            LottieLoadingView()
                .frame(width: 100, height: 100)
            
            Text("Loading your dashboard")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: IdentifiableError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
            
            Text("Unable to Load Dashboard")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(error.message)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await stateModel.fetch()
                }
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSecondary)
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Dashboard Content
    
    @ViewBuilder
    private func dashboardContent(_ data: DashboardData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header
                welcomeHeader
                    .padding(.top, 16)
                    .offset(y: headerAnimation ? 0 : -20)
                    .opacity(headerAnimation ? 1 : 0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
                        value: headerAnimation
                    )
                
                // Time frame selector
                EnhancedTimeFrameSelector(selection: binding(stateModel, \.selectedTimeFrame))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .opacity(headerAnimation ? 1 : 0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.2),
                        value: headerAnimation
                    )
                
                // Dashboard cards
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        quickStatsView(data)
                            .frame(maxWidth: .infinity)
                        recentActivitiesView
                            .frame(maxWidth: .infinity)
                    }
                    .opacity(cardsAnimation ? 1 : 0)
                    .offset(y: cardsAnimation ? 0 : 30)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.3),
                        value: cardsAnimation
                    )
                } else {
                    VStack(spacing: 20) {
                        quickStatsView(data)
                        recentActivitiesView
                    }
                    .opacity(cardsAnimation ? 1 : 0)
                    .offset(y: cardsAnimation ? 0 : 30)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.3),
                        value: cardsAnimation
                    )
                }
                
                // Alignment chart
                EnhancedAlignmentChartView(alignmentData: alignmentData)
                    .opacity(chartAnimation ? 1 : 0)
                    .offset(y: chartAnimation ? 0 : 30)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.4),
                        value: chartAnimation
                    )
                
                // Insights button
                InsightsButtonView {
                    showingInsightsSheet = true
                }
                .opacity(buttonAnimation ? 1 : 0)
                .offset(y: buttonAnimation ? 0 : 20)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7).delay(0.5),
                    value: buttonAnimation
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                headerAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                cardsAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                chartAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                buttonAnimation = true
            }
        }
    }
    
    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back,")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Educator!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Date display
            VStack(alignment: .trailing, spacing: 4) {
                Text(Date(), style: .date)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(Date(), style: .time)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private func quickStatsView(_ data: DashboardData) -> some View {
        DashboardGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Stats")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    EnhancedStatCard(
                        title: "Total Students",
                        value: "\(data.totalStudents)",
                        icon: "person.3.fill",
                        color: Color.blue
                    )
                    
                    EnhancedStatCard(
                        title: "Surveys Completed",
                        value: "\(data.surveysCompleted)",
                        icon: "checkmark.circle.fill",
                        color: Color.green
                    )
                    
                    EnhancedStatCard(
                        title: "Plans Aligned",
                        value: "\(data.plansAligned)",
                        icon: "star.fill",
                        color: Color.orange
                    )
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stateModel.selectedTimeFrame)
            }
        }
    }
    
    private var recentActivitiesView: some View {
        DashboardGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Recent Activities")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // View all activities
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.system(size: 14, weight: .medium))
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color.tmiSecondary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                if RecentActivity.sampleActivities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No recent activities")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(RecentActivity.sampleActivities) { activity in
                            EnhancedActivityRow(activity: activity)
                            
                            if activity.id != RecentActivity.sampleActivities.last!.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
        }
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
                            Color.tmiSecondary
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

// MARK: - Helper Types & Extensions

struct InsightRecommendation: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var icon: String
    var color: Color
    
    static let sampleRecommendations: [InsightRecommendation] = [
        InsightRecommendation(
            title: "Increase survey completion rate",
            description: "25 students haven't completed their interest surveys. Consider sending a reminder notification.",
            icon: "bell.fill",
            color: .orange
        ),
        InsightRecommendation(
            title: "Review alignment scores",
            description: "Several students show low alignment between interests and academic performance. Schedule individual meetings.",
            icon: "person.2.fill",
            color: .blue
        ),
        InsightRecommendation(
            title: "New career path identified",
            description: "5 students have shown consistent interest in medical fields. Consider organizing a healthcare career workshop.",
            icon: "heart.text.square.fill",
            color: .pink
        )
    ]
}


extension TimeFrame {
    public static var allCases: [TimeFrame] {
        [.day, .week, .month, .year]
    }
}


// Helper functions to create bindings from state model
func binding<T>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<Bool> {
    Binding(
        get: { stateModel.ui.get(key) ?? false },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

func binding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<V> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) ?? (false as! V) },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

// For optional values
func optionalBinding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<V?> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) as V? },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

// For values with a default
func binding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String, defaultValue: V) -> Binding<V> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) ?? defaultValue },
        set: { stateModel.ui.set(key, value: $0) }
    )
}


// MARK: - Preview

#Preview {
    DashboardView()
        .preferredColorScheme(.light)
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}

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

struct AlignmentData: Identifiable, Equatable {
    var id = UUID()
    var timePeriod: String
    var alignmentPercentage: Double
}

// MARK: - Sample Data

let alignmentData: [AlignmentData] = [
    AlignmentData(timePeriod: "Jan", alignmentPercentage: 0.45),
    AlignmentData(timePeriod: "Feb", alignmentPercentage: 0.52),
    AlignmentData(timePeriod: "Mar", alignmentPercentage: 0.48),
    AlignmentData(timePeriod: "Apr", alignmentPercentage: 0.60),
    AlignmentData(timePeriod: "May", alignmentPercentage: 0.55),
    AlignmentData(timePeriod: "Jun", alignmentPercentage: 0.72),
    AlignmentData(timePeriod: "Jul", alignmentPercentage: 0.68)
]
