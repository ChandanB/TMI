//
//  InsightsView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI
import Charts

struct InsightsView: View {
    @State private var selectedInsight: InsightType = .performance
    @State private var timeFrame: TimeFrame = .month
    @State private var isInsightSelectorExpanded = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                if sizeClass == .regular {
                    regularInsightSelector
                } else {
                    compactInsightSelector
                }
                
                timeFramePicker
                
                switch selectedInsight {
                case .performance:
                    PerformanceInsightView(timeFrame: timeFrame)
                case .engagement:
                    EngagementInsightView(timeFrame: timeFrame)
                case .interests:
                    InterestsInsightView(timeFrame: timeFrame)
                case .tmiEffectiveness:
                    TMIEffectivenessView(timeFrame: timeFrame)
                }
                
                recommendationsSection
            }
            .padding()
        }
        .background(Color.tmiBackground.ignoresSafeArea())
        .navigationTitle("Insights")
    }
    
    private var regularInsightSelector: some View {
        Picker(selectedInsight.rawValue, selection: $selectedInsight) {
            ForEach(InsightType.allCases, id: \.self) { insight in
                Text(insight.rawValue).tag(insight)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var compactInsightSelector: some View {
        CollapsibleList(
            title: selectedInsight.rawValue,
            expanded: $isInsightSelectorExpanded,
            content: {
                ForEach(InsightType.allCases, id: \.self) { insight in
                    Button(action: {
                        selectedInsight = insight
                        isInsightSelectorExpanded = false
                    }) {
                        HStack {
                            Text(insight.rawValue)
                            Spacer()
                            if selectedInsight == insight {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.tmiPrimary)
                            }
                        }
                    }
                    .foregroundColor(.tmiText)
                    .padding(.vertical, 8)
                }
            }
        )
        .padding(.horizontal)
    }
    

    private var timeFramePicker: some View {
        Picker("Time Range", selection: $timeFrame) {
            ForEach(TimeFrame.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommendations")
                .font(.headline)
                .foregroundColor(.tmiText)
            
            ForEach(getRecommendations(), id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.tmiText)
                }
            }
        }
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func getRecommendations() -> [String] {
        switch selectedInsight {
        case .performance:
            return [
                "Focus on improving math performance for 10th grade students.",
                "Consider additional support for students struggling with science subjects."
            ]
        case .engagement:
            return [
                "Increase interactive activities in history classes to boost engagement.",
                "Implement peer-led study groups to enhance collaborative learning."
            ]
        case .interests:
            return [
                "Incorporate more tech-related projects in science classes.",
                "Consider adding an art therapy program based on growing interest."
            ]
        case .tmiEffectiveness:
            return [
                "Adjust TMI plans for students showing decreased engagement.",
                "Celebrate and share success stories of students with significant improvements."
            ]
        }
    }
}

struct CollapsibleList<Content: View>: View {
    let title: String
    @Binding var expanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading) {
            Button(action: { expanded.toggle() }) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .padding()
                .background(Color.tmiSecondary.opacity(0.1))
                .cornerRadius(10)
            }
            .foregroundColor(.tmiText)

            if expanded {
                VStack(alignment: .leading) {
                    content()
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct PerformanceInsightView: View {
    let timeFrame: TimeFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Academic Performance")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Chart {
                ForEach(performanceData) { dataPoint in
                    BarMark(
                        x: .value("Subject", dataPoint.subject),
                        y: .value("Score", dataPoint.score)
                    )
                    .foregroundStyle(by: .value("Subject", dataPoint.subject))
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                    AxisTick()
                    AxisGridLine()
                }
            }
            
            Text("Key Observations:")
                .font(.headline)
                .foregroundColor(.tmiText)
            
            VStack(alignment: .leading, spacing: 5) {
                ObservationRow(text: "Math scores have improved by 15% this \(timeFrame.rawValue)")
                ObservationRow(text: "Science performance shows a slight decline")
                ObservationRow(text: "English and History maintain consistent high scores")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct EngagementInsightView: View {
    let timeFrame: TimeFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Student Engagement")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Chart {
                ForEach(engagementData) { dataPoint in
                    LineMark(
                        x: .value("Week", dataPoint.week),
                        y: .value("Engagement", dataPoint.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary.gradient)
                    
                    AreaMark(
                        x: .value("Week", dataPoint.week),
                        y: .value("Engagement", dataPoint.engagement)
                    )
                    .foregroundStyle(Color.tmiPrimary.opacity(0.1).gradient)
                }
            }
            .frame(height: 300)
            
            Text("Key Observations:")
                .font(.headline)
                .foregroundColor(.tmiText)
            
            VStack(alignment: .leading, spacing: 5) {
                ObservationRow(text: "Overall engagement has increased by 20% this \(timeFrame.rawValue)")
                ObservationRow(text: "Peak engagement observed in week 3, correlating with new TMI implementations")
                ObservationRow(text: "Slight dip in engagement during week 5, possibly due to midterm exams")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct InterestsInsightView: View {
    let timeFrame: TimeFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Student Interests")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Chart {
                ForEach(interestData) { dataPoint in
                    SectorMark(
                        angle: .value("Value", dataPoint.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", dataPoint.category))
                }
            }
            .frame(height: 300)
            
            Text("Key Observations:")
                .font(.headline)
                .foregroundColor(.tmiText)
            
            VStack(alignment: .leading, spacing: 5) {
                ObservationRow(text: "Technology remains the top interest among students")
                ObservationRow(text: "Growing interest in arts and music this \(timeFrame.rawValue)")
                ObservationRow(text: "Sports and outdoor activities show consistent engagement")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct TMIEffectivenessView: View {
    let timeFrame: TimeFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("TMI Program Effectiveness")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)
            
            Chart {
                ForEach(tmiEffectivenessData) { dataPoint in
                    BarMark(
                        x: .value("Category", dataPoint.category),
                        y: .value("Improvement", dataPoint.improvement)
                    )
                    .foregroundStyle(by: .value("Category", dataPoint.category))
                }
            }
            .frame(height: 300)
            
            Text("Key Observations:")
                .font(.headline)
                .foregroundColor(.tmiText)
            
            VStack(alignment: .leading, spacing: 5) {
                ObservationRow(text: "Academic performance shows the highest improvement")
                ObservationRow(text: "Significant boost in student motivation")
                ObservationRow(text: "Positive impact on attendance and participation")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct ObservationRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .foregroundColor(.tmiPrimary)
                .font(.system(size: 8))
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.tmiText)
        }
    }
}

enum InsightType: String, CaseIterable {
    case performance = "Performance"
    case engagement = "Engagement"
    case interests = "Interests"
    case tmiEffectiveness = "TMI Effectiveness"
}

struct PerformanceData: Identifiable {
    let id = UUID()
    let subject: String
    let score: Double
}

let performanceData: [PerformanceData] = [
    PerformanceData(subject: "Math", score: 85),
    PerformanceData(subject: "Science", score: 78),
    PerformanceData(subject: "English", score: 92),
    PerformanceData(subject: "History", score: 88)
]

struct EngagementData: Identifiable {
    let id = UUID()
    let day: String
    let week: String
    let engagement: Double
}

struct InterestData: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
}

let interestData: [InterestData] = [
    InterestData(category: "Technology", value: 35),
    InterestData(category: "Arts", value: 25),
    InterestData(category: "Sports", value: 20),
    InterestData(category: "Science", value: 15),
    InterestData(category: "Literature", value: 5)
]

struct TMIEffectivenessData: Identifiable {
    let id = UUID()
    let category: String
    let improvement: Double
}

let tmiEffectivenessData: [TMIEffectivenessData] = [
    TMIEffectivenessData(category: "Academic", improvement: 25),
    TMIEffectivenessData(category: "Motivation", improvement: 30),
    TMIEffectivenessData(category: "Attendance", improvement: 15),
    TMIEffectivenessData(category: "Participation", improvement: 20)
]

#Preview {
    InsightsView()
}
