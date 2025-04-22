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
extension EnvironmentValues {
    @Entry var dashboardStateModel: DashboardStateModel = DashboardStateModel()
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



// MARK: -  Activity Row

struct DashboardActivityRow: View {
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
        .foregroundColor(.white)
        .foregroundStyle(.white)
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
            DashboardInsightsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
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
                TimeFrameSelector(selection: binding(stateModel, \.selectedTimeFrame))
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
                DashboardAlignmentChartView(alignmentData: alignmentData)
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
                    StatCard(
                        title: "Total Students",
                        value: "\(data.totalStudents)",
                        icon: "person.3.fill",
                        color: Color.blue
                    )
                    
                    StatCard(
                        title: "Surveys Completed",
                        value: "\(data.surveysCompleted)",
                        icon: "checkmark.circle.fill",
                        color: Color.green
                    )
                    
                    StatCard(
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
                            DashboardActivityRow(activity: activity)
                            
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


// MARK: - Preview

#Preview {
    DashboardView()
        .preferredColorScheme(.light)
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}

