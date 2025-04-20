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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    private let transitionID = "InsightTransition"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                
                if sizeClass == .regular {
                    regularInsightSelector
                } else {
                    compactInsightSelector
                }
                
                timeFramePicker
                
                insightContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedInsight)
                    .id(selectedInsight) // Force full view replacement on change
                
                recommendationsSection
            }
            .padding()
        }
        .background(
            Color.tmiBackground
                .opacity(0.7)
                .ignoresSafeArea()
        )
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TMI Insights")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.tmiPrimary, .tmiPrimary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Discover patterns and opportunities to improve student engagement")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    private var regularInsightSelector: some View {
        HStack(spacing: 0) {
            ForEach(InsightType.allCases, id: \.self) { insight in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedInsight = insight
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: iconFor(insight))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(selectedInsight == insight ? .white : .tmiPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedInsight == insight ? .tmiPrimary : .tmiPrimary.opacity(0.1))
                            )
                        
                        Text(insight.rawValue)
                            .font(.footnote)
                            .fontWeight(selectedInsight == insight ? .semibold : .regular)
                            .foregroundStyle(selectedInsight == insight ? .tmiPrimary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                selectedInsight == insight
                                ? .tmiPrimary.opacity(0.1)
                                : colorScheme == .dark ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selectedInsight == insight ? .tmiPrimary.opacity(0.3) : .clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var compactInsightSelector: some View {
        DisclosureGroup(
            isExpanded: $isInsightSelectorExpanded,
            content: {
                VStack(spacing: 0) {
                    ForEach(InsightType.allCases, id: \.self) { insight in
                        if insight != selectedInsight {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedInsight = insight
                                    isInsightSelectorExpanded = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: iconFor(insight))
                                        .foregroundStyle(.tmiPrimary)
                                    
                                    Text(insight.rawValue)
                                        .foregroundStyle(.tmiText)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            
                            if insight != InsightType.allCases.last && insight != selectedInsight {
                                Divider()
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            },
            label: {
                HStack {
                    Image(systemName: iconFor(selectedInsight))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.tmiPrimary)
                        )
                    
                    Text(selectedInsight.rawValue)
                        .font(.headline)
                        .foregroundStyle(.tmiText)
                    
                    Spacer()
                }
            }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.tmiPrimary.opacity(0.2), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInsightSelectorExpanded)
    }
    
    private var timeFramePicker: some View {
        Picker("Time Range", selection: $timeFrame) {
            ForEach(TimeFrame.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var insightContent: some View {
        switch selectedInsight {
        case .performance:
            PerformanceInsightView(timeFrame: timeFrame)
        case .interests:
            InterestsInsightView(timeFrame: timeFrame)
        case .interestAlignment:
            InterestAlignmentInsightView(timeFrame: timeFrame)
        case .tmiEffectiveness:
            TMIEffectivenessView(timeFrame: timeFrame)
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.headline)
                .foregroundStyle(.tmiText)
            
            VStack(spacing: 16) {
                ForEach(getRecommendations(), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.yellow.opacity(0.2))
                            )
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundStyle(.tmiText)
                            .fixedSize(horizontal: false, vertical: true)
                            .alignmentGuide(.leading) { _ in 0 }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                    )
                }
            }
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
    }
    
    private func iconFor(_ insight: InsightType) -> String {
        switch insight {
        case .performance:
            return "chart.bar.fill"
        case .interests:
            return "star.fill"
        case .interestAlignment:
            return "arrow.up.and.down.and.arrow.left.and.right"
        case .tmiEffectiveness:
            return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func getRecommendations() -> [String] {
        switch selectedInsight {
        case .performance:
            return [
                "Focus on improving math performance for 10th grade students.",
                "Consider additional support for students struggling with science subjects."
            ]
        case .interests:
            return [
                "Incorporate more tech-related projects in science classes.",
                "Consider adding an art therapy program based on growing interest."
            ]
        case .interestAlignment:
            return [
                "Encourage students to complete their interest surveys to enhance alignment data.",
                "Introduce mentorship programs to help students align their hobbies with academic subjects.",
                "Provide more resources related to emerging student interests such as coding and digital arts."
            ]
        case .tmiEffectiveness:
            return [
                "Adjust TMI plans for students showing decreased engagement.",
                "Celebrate and share success stories of students with significant improvements."
            ]
        }
    }
}

struct PerformanceInsightView: View {
    let timeFrame: TimeFrame
    @State private var animateChart = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Academic Performance")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tmiText)
            
            Divider()
                .padding(.vertical, 4)
            
            Chart {
                ForEach(Array(performanceData.enumerated()), id: \.element.id) { index, dataPoint in
                    BarMark(
                        x: .value("Subject", dataPoint.subject),
                        y: .value("Score", animateChart ? dataPoint.score : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.tmiPrimary,
                                colorFor(subject: dataPoint.subject)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if animateChart {
                            Text("\(Int(dataPoint.score))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(colorFor(subject: dataPoint.subject))
                                .transition(.opacity.animation(.easeIn.delay(Double(index) * 0.1)))
                        }
                    }
                }
                
                RuleMark(y: .value("Average", 80))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.gray.opacity(0.5))
                    .annotation(position: .leading) {
                        Text("Avg")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let subject = value.as(String.self) {
                            Text(subject)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let score = value.as(Double.self) {
                            Text("\(Int(score))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 300)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                    animateChart = true
                }
            }
            
            observations
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
    }
    
    private var observations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Observations")
                .font(.headline)
                .foregroundStyle(.tmiText)
            
            VStack(alignment: .leading, spacing: 12) {
                ObservationRow(
                    text: "Math scores have improved by 15% this \(timeFrame.rawValue)",
                    color: colorFor(subject: "Math")
                )
                
                ObservationRow(
                    text: "Science performance shows a slight decline",
                    color: colorFor(subject: "Science")
                )
                
                ObservationRow(
                    text: "English and History maintain consistent high scores",
                    color: colorFor(subject: "English")
                )
            }
        }
    }
    
    private func colorFor(subject: String) -> Color {
        switch subject {
        case "Math":
            return .blue
        case "Science":
            return .green
        case "English":
            return .purple
        case "History":
            return .orange
        default:
            return .tmiPrimary
        }
    }
}

struct InterestAlignmentInsightView: View {
    let timeFrame: TimeFrame
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateChart = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interest Alignment Progress")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tmiText)
            
            Divider()
                .padding(.vertical, 4)
            
            Chart {
                ForEach(alignmentData) { dataPoint in
                    LineMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", animateChart ? dataPoint.alignmentPercentage : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .tmiPrimary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    
                    AreaMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", animateChart ? dataPoint.alignmentPercentage : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .tmiPrimary.opacity(0.3),
                                .blue.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value("Time Period", dataPoint.timePeriod),
                        y: .value("Alignment %", animateChart ? dataPoint.alignmentPercentage : 0)
                    )
                    .symbolSize(animateChart ? 100 : 0)
                    .foregroundStyle(Color.white)
                    .shadow(color: .tmiPrimary.opacity(0.5), radius: 2, x: 0, y: 1)
                    .annotation(position: .top) {
                        if animateChart {
                            Text("\(Int(dataPoint.alignmentPercentage * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tmiPrimary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .transition(.opacity.animation(.easeIn))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                    AxisTick()
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                        }
                    }
                    AxisTick()
                    AxisGridLine()
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 300)
            .onAppear {
                withAnimation(.spring(response: 1, dampingFraction: 0.7).delay(0.3)) {
                    animateChart = true
                }
            }
            
            observations
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
    }
    
    private var observations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Observations")
                .font(.headline)
                .foregroundStyle(.tmiText)
            
            VStack(alignment: .leading, spacing: 12) {
                ObservationRow(
                    text: "Interest alignment increased by 30% over the past \(timeFrame.rawValue).",
                    color: .blue
                )
                
                ObservationRow(
                    text: "Week 4 showed the highest improvement, correlating with new resource implementations.",
                    color: .green
                )
                
                ObservationRow(
                    text: "Alignment progress shows consistency among students interested in technology and arts.",
                    color: .purple
                )
            }
        }
    }
}

struct InterestsInsightView: View {
    let timeFrame: TimeFrame
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateChart = false
    @State private var selectedCategory: String?
    
    private let interestColors: [String: Color] = [
        "Technology": .blue,
        "Arts": .purple,
        "Sports": .green,
        "Science": .orange,
        "Literature": .red
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Student Interests")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tmiText)
            
            Divider()
                .padding(.vertical, 4)
            
            Chart {
                ForEach(interestData) { dataPoint in
                    SectorMark(
                        angle: .value("Value", animateChart ? dataPoint.value : 0),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .opacity(selectedCategory == nil || selectedCategory == dataPoint.category ? 1 : 0.4)
                    .foregroundStyle(by: .value("Category", dataPoint.category))
                    .annotation(position: .overlay) {
                        if animateChart {
                            VStack {
                                Text(dataPoint.category)
                                    .font(.caption.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                
                                Text("\(Int(dataPoint.value))%")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.animation(.easeIn))
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: interestData.map { $0.category },
                range: interestData.map { interestColors[$0.category] ?? .tmiPrimary }
            )
            .frame(height: 300)
            .chartLegend(position: .bottom, alignment: .center, spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(interestData) { dataPoint in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = selectedCategory == dataPoint.category ? nil : dataPoint.category
                            }
                        }) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(interestColors[dataPoint.category] ?? .tmiPrimary)
                                    .frame(width: 12, height: 12)
                                
                                Text(dataPoint.category)
                                    .font(.caption)
                                    .foregroundStyle(selectedCategory == dataPoint.category ? .tmiText : .secondary)
                                    .fontWeight(selectedCategory == dataPoint.category ? .bold : .regular)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selectedCategory == dataPoint.category ?
                                          (interestColors[dataPoint.category] ?? .tmiPrimary).opacity(0.1) :
                                          Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                    animateChart = true
                }
            }
            
            observations
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
    }
    
    private var observations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Observations")
                .font(.headline)
                .foregroundStyle(.tmiText)
            
            VStack(alignment: .leading, spacing: 12) {
                ObservationRow(
                    text: "Technology remains the top interest among students",
                    color: interestColors["Technology"] ?? .tmiPrimary
                )
                
                ObservationRow(
                    text: "Growing interest in arts and music this \(timeFrame.rawValue)",
                    color: interestColors["Arts"] ?? .tmiPrimary
                )
                
                ObservationRow(
                    text: "Sports and outdoor activities show consistent engagement",
                    color: interestColors["Sports"] ?? .tmiPrimary
                )
            }
        }
    }
}

struct TMIEffectivenessView: View {
    let timeFrame: TimeFrame
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateChart = false
    
    private let categoryColors: [String: Color] = [
        "Academic": .blue,
        "Motivation": .purple,
        "Attendance": .green,
        "Participation": .orange
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TMI Program Effectiveness")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tmiText)
            
            Divider()
                .padding(.vertical, 4)
            
            Chart {
                ForEach(Array(tmiEffectivenessData.enumerated()), id: \.element.id) { index, dataPoint in
                    BarMark(
                        x: .value("Category", dataPoint.category),
                        y: .value("Improvement", animateChart ? dataPoint.improvement : 0)
                    )
                    .cornerRadius(8)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                categoryColors[dataPoint.category] ?? .tmiPrimary,
                                (categoryColors[dataPoint.category] ?? .tmiPrimary).opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .annotation(position: .top) {
                        if animateChart {
                            Text("\(Int(dataPoint.improvement))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(categoryColors[dataPoint.category] ?? .tmiPrimary)
                                .transition(.opacity.animation(.easeIn.delay(Double(index) * 0.1)))
                        }
                    }
                }
                
                RuleMark(y: .value("Target", 25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.gray.opacity(0.5))
                    .annotation(position: .trailing) {
                        Text("Target")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: 0...40)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let category = value.as(String.self) {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let improvement = value.as(Double.self) {
                            Text("\(Int(improvement))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 300)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                    animateChart = true
                }
            }
            
            observations
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
    }
    
    private var observations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Observations")
                .font(.headline)
                .foregroundStyle(.tmiText)
            
            VStack(alignment: .leading, spacing: 12) {
                ObservationRow(
                    text: "Academic performance shows the highest improvement",
                    color: categoryColors["Academic"] ?? .tmiPrimary
                )
                
                ObservationRow(
                    text: "Significant boost in student motivation",
                    color: categoryColors["Motivation"] ?? .tmiPrimary
                )
                
                ObservationRow(
                    text: "Positive impact on attendance and participation",
                    color: categoryColors["Attendance"] ?? .tmiPrimary
                )
            }
        }
    }
}

struct ObservationRow: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.tmiText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum InsightType: String, CaseIterable {
    case performance = "Performance"
    case interests = "Interests"
    case interestAlignment = "Interest Alignment"
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
