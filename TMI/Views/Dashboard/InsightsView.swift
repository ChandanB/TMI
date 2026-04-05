//
//  InsightsView.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI
import Charts

struct PerformanceInsightView: View {
    let timeFrame: TimeFrame
    @State private var animateChart = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Academic Performance")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.tmiTextPrimary)

            Divider()
                .padding(.vertical, 4)

            Chart(performanceData) { dataPoint in
                BarMark(
                    x: .value("Academic Subject", dataPoint.subject),
                    y: .value("Performance Score", animateChart ? dataPoint.score : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            colorFor(subject: dataPoint.subject),
                            colorFor(subject: dataPoint.subject).opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(8)
                .opacity(animateChart ? 1.0 : 0.0)
                
                // Reference line for average
                RuleMark(y: .value("Class Average", 80))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundStyle(.primary.opacity(0.6))
                    .annotation(position: .topLeading, alignment: .leading) {
                        Text("Class Avg (80%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.tmiSurface)
                            )
                    }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .automatic) { value in
                    AxisValueLabel {
                        if let subject = value.as(String.self) {
                            Text(subject)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    AxisGridLine(centered: true)
                        .foregroundStyle(.quaternary)
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisTick(centered: true, length: 4)
                        .foregroundStyle(.tertiary)
                    AxisValueLabel {
                        if let score = value.as(Double.self) {
                            Text("\(Int(score))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .accessibilityLabel("Academic Performance Chart")
            .accessibilityValue("Bar chart showing performance scores by subject")
            .accessibilityHint("Each bar represents performance in a different academic subject")
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
                .fill(Color.tmiSurface)
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                    .foregroundStyle(Color.tmiSurface)
                    .shadow(color: .tmiPrimary.opacity(0.5), radius: 2, x: 0, y: 1)
                    .annotation(position: .top) {
                        if animateChart {
                            Text("\(Int(dataPoint.alignmentPercentage * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.tmiPrimary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.tmiSurface)
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
                .fill(Color.tmiSurface)
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                                    .foregroundStyle(Color.tmiTextPrimary)
                                
                                Text("\(Int(dataPoint.value))%")
                                    .font(.caption2)
                                    .foregroundStyle(Color.tmiTextSecondary)
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
                                    .foregroundStyle(selectedCategory == dataPoint.category ? Color.tmiTextPrimary : Color.secondary)
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
                .fill(Color.tmiSurface)
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                .fill(Color.tmiSurface)
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
                .foregroundStyle(Color.tmiTextPrimary)
            
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
                .foregroundStyle(Color.tmiTextPrimary)
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