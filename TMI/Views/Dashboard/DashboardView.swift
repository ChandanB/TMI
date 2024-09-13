//
//  DashboardView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI
import Charts

struct DashboardView: View {
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var selectedDataPoint: EngagementData?
    @State private var showingInsightsSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack(root: {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    recentsView
                    engagementChartView
                    insightsButton
                }
                .padding()
            }
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationTitle("TMI Dashboard")
            .sheet(isPresented: $showingInsightsSheet) {
                InsightsView()
            }
        })
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Welcome back,")
                    .font(.headline)
                    .foregroundColor(.tmiSecondary)
                Text("Educator!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
            }
            Spacer()
            Menu {
                Button("View Profile") { }
                Button("Settings") { }
                Button("Log Out") { }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.largeTitle)
                    .foregroundColor(.tmiPrimary)
            }
        }
    }
    
    @ViewBuilder
    private var recentsView: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 20) {
                quickStatsView
                recentActivitiesView
            }
        } else {
            VStack(spacing: 20) {
                quickStatsView
                recentActivitiesView
            }
        }
    }
    
    private var quickStatsView: some View {
        VStack(spacing: 15) {
            Text("Quick Stats")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Picker("Time Frame", selection: $selectedTimeFrame) {
                ForEach(TimeFrame.allCases) { timeFrame in
                    Text(timeFrame.rawValue).tag(timeFrame)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(spacing: 15) {
                StatCard(title: "Total Students", value: "150", icon: "person.3", color: .blue)
                StatCard(title: "Active TMI Plans", value: "75", icon: "doc.text", color: .green)
                StatCard(title: "Interests Identified", value: "250", icon: "star", color: .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var recentActivitiesView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 15) {
                Text("Recent Activities")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiText)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(RecentActivity.sampleRecentActivities) { activity in
                            if RecentActivity.sampleRecentActivities[0].id != activity.id {
                                Divider()
                            }
                            ActivityRow(activity: activity)
                        }
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 350)
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
        
    }
    
    private var engagementChartView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Student Engagement")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Chart {
                ForEach(engagementData) { dataPoint in
                    LineMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Engagement", dataPoint.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Engagement", dataPoint.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary.opacity(0.1).gradient)
                    
                    PointMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Engagement", dataPoint.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary)
                }
                
                if let selected = selectedDataPoint {
                    RuleMark(x: .value("Day", selected.day))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    PointMark(
                        x: .value("Day", selected.day),
                        y: .value("Engagement", selected.engagement)
                    )
                    .foregroundStyle(.white)
                    .symbol(.circle)
                    .symbolSize(100)
                    
                    PointMark(
                        x: .value("Day", selected.day),
                        y: .value("Engagement", selected.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary)
                    .symbol(.circle)
                    .symbolSize(60)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                        }
                    }
                }
            }
            .chartYScale(domain: 0...1)
            .chartLegend(position: .bottom, alignment: .center)
            .frame(height: 250)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if let plotFrame = proxy.plotFrame {
                                        let currentX = value.location.x - geometry[plotFrame].origin.x
                                        guard currentX >= 0, currentX < proxy.plotSize.width else { return }
                                        guard let day: String = proxy.value(atX: currentX) else { return }
                                        selectedDataPoint = engagementData.first { $0.day == day }
                                    } else {
                                        let currentX = value.location.x
                                        guard currentX >= 0, currentX < proxy.plotSize.width else { return }
                                        guard let day: String = proxy.value(atX: currentX) else { return }
                                        selectedDataPoint = engagementData.first { $0.day == day }
                                    }
                                }
                                .onEnded { _ in selectedDataPoint = nil }
                        )
                }
            }
            
            if let selected = selectedDataPoint {
                HStack {
                    Text("Day: \(selected.day)")
                    Spacer()
                    Text("Engagement: \(Int(selected.engagement * 100))%")
                }
                .padding(.top, 8)
                .foregroundColor(.tmiText)
                .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Key Insights:")
                    .font(.headline)
                    .foregroundColor(.tmiText)
                Text("• Average engagement: \(averageEngagement())%")
                Text("• Highest engagement: \(highestEngagement())% on \(highestEngagementDay())")
                Text("• Trend: \(engagementTrend())")
            }
            .font(.subheadline)
            .foregroundColor(.tmiText)
            .padding(.top, 10)
        }
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func averageEngagement() -> String {
        let average = engagementData.map { $0.engagement }.reduce(0, +) / Double(engagementData.count)
        return String(format: "%.1f", average * 100)
    }
    
    private func highestEngagement() -> String {
        let highest = engagementData.map { $0.engagement }.max() ?? 0
        return String(format: "%.1f", highest * 100)
    }
    
    private func highestEngagementDay() -> String {
        engagementData.max { $0.engagement < $1.engagement }?.day ?? "N/A"
    }
    
    private func engagementTrend() -> String {
        let values = engagementData.map { $0.engagement }
        if values.first! < values.last! {
            return "Increasing"
        } else if values.first! > values.last! {
            return "Decreasing"
        } else {
            return "Stable"
        }
    }
    
    private var insightsButton: some View {
        Button(action: { showingInsightsSheet = true }) {
            Label("View Insights", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.tmiPrimary)
                .cornerRadius(10)
        }
    }
}


// MARK: - Sample Data

let engagementData: [EngagementData] = [
    EngagementData(day: "Mon", week: "Week 1", engagement: 0.5),
    EngagementData(day: "Tue", week: "Week 2", engagement: 0.6),
    EngagementData(day: "Wed", week: "Week 3", engagement: 0.8),
    EngagementData(day: "Thu", week: "Week 4", engagement: 0.7),
    EngagementData(day: "Fri", week: "Week 5", engagement: 0.9),
    EngagementData(day: "Sat", week: "Week 6", engagement: 0.4),
    EngagementData(day: "Sun", week: "Week 7", engagement: 0.3)
]

#Preview {
    DashboardView()
}
