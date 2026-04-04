//
//  DashboardAlignmentChartView.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//


import SwiftUI
import Charts

// MARK: - Alignment Chart View

struct LegacyAlignmentChartView: View {
    @Environment(\.dashboardStateModel) private var stateModel
    let alignmentData: [AlignmentData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interest Alignment Progress")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.tmiTextPrimary)
            
            Divider()
                .padding(.vertical, 4)
            
            // Main chart component
            AlignmentChart(
                alignmentData: alignmentData,
                selectedDataPoint: Binding(
                    get: { stateModel.selectedDataPoint },
                    set: { stateModel.selectedDataPoint = $0 }
                )
            )
            .frame(height: 250)
            
            // Summary statistics below chart
            ChartSummaryView()
                .padding(.top, 8)
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
}

// MARK: - Chart Component

struct AlignmentChart: View {
    let alignmentData: [AlignmentData]
    @Binding var selectedDataPoint: AlignmentData?
    
    var body: some View {
        Chart {
            ForEach(alignmentData) { dataPoint in
                LineMark(
                    x: .value("Period", dataPoint.timePeriod),
                    y: .value("Alignment", dataPoint.alignmentPercentage)
                )
                .foregroundStyle(Color.tmiPrimary.gradient)
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Period", dataPoint.timePeriod),
                    y: .value("Alignment", dataPoint.alignmentPercentage)
                )
                .foregroundStyle(Color.tmiPrimary)
                .symbolSize(selectedDataPoint?.timePeriod == dataPoint.timePeriod ? 100 : 50)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let stringValue = value.as(String.self) {
                        Text(stringValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            ChartOverlayView(proxy: proxy, alignmentData: alignmentData, selectedDataPoint: $selectedDataPoint)
        }
        .chartBackground { proxy in
            ChartBackgroundView(proxy: proxy, selectedDataPoint: selectedDataPoint)
        }
    }
}

// MARK: - Chart Overlay View

struct ChartOverlayView: View {
    let proxy: ChartProxy
    let alignmentData: [AlignmentData]
    @Binding var selectedDataPoint: AlignmentData?
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragGesture(value, geometry: geometry)
                        }
                        .onEnded { _ in
                            selectedDataPoint = nil
                        }
                )
        }
    }
    
    private func handleDragGesture(_ value: DragGesture.Value, geometry: GeometryProxy) {
        if let plotFrame = proxy.plotFrame {
            let xPosition = value.location.x - geometry[plotFrame].origin.x
            guard xPosition >= 0, xPosition <= geometry[plotFrame].width else {
                selectedDataPoint = nil
                return
            }
            
            let xValue = proxy.value(atX: xPosition, as: String.self)
            if let xValue = xValue,
               let dataPoint = alignmentData.first(where: { $0.timePeriod == xValue }) {
                selectedDataPoint = dataPoint
            }
        }
    }
}

// MARK: - Chart Background View

struct ChartBackgroundView: View {
    let proxy: ChartProxy
    let selectedDataPoint: AlignmentData?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                if let selectedDataPoint = selectedDataPoint,
                   let pointX = proxy.position(forX: selectedDataPoint.timePeriod),
                   let pointY = proxy.position(forY: selectedDataPoint.alignmentPercentage) {
                    
                    // Vertical line
                    VerticalLineView(
                        geometry: geometry,
                        proxy: proxy,
                        pointX: pointX
                    )
                    
                    if let plotFrame = proxy.plotFrame {
                        // Data point circle
                        Circle()
                            .fill(Color.tmiPrimary)
                            .frame(width: 12, height: 12)
                            .position(
                                x: geometry[plotFrame].origin.x + pointX,
                                y: geometry[plotFrame].origin.y + pointY
                            )
                    }
                   
                    // Tooltip
                    ChartTooltipView(
                        dataPoint: selectedDataPoint,
                        geometry: geometry,
                        proxy: proxy,
                        pointX: pointX,
                        pointY: pointY
                    )
                }
            }
        }
    }
}

// MARK: - Vertical Line View

struct VerticalLineView: View {
    let geometry: GeometryProxy
    let proxy: ChartProxy
    let pointX: CGFloat
    
    var body: some View {
        if let plotFrame = proxy.plotFrame {
            let lineHeight = geometry[plotFrame].height
            let xPosition = geometry[plotFrame].origin.x + pointX
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: lineHeight)
                .position(
                    x: xPosition,
                    y: geometry[plotFrame].origin.y + lineHeight / 2
                )
        }
        
    }
}

// MARK: - Chart Tooltip View

struct ChartTooltipView: View {
    let dataPoint: AlignmentData
    let geometry: GeometryProxy
    let proxy: ChartProxy
    let pointX: CGFloat
    let pointY: CGFloat
    
    var body: some View {
        if let plotFrame = proxy.plotFrame {
            let xPosition = geometry[plotFrame].origin.x + pointX
            let yPosition = geometry[plotFrame].origin.y + pointY
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dataPoint.timePeriod)
                    .font(.caption.bold())
                    .foregroundStyle(Color.tmiTextPrimary)
                
                Text("\(Int(dataPoint.alignmentPercentage * 100))% Aligned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .position(
                x: xPosition,
                y: max(yPosition - 50, geometry[plotFrame].origin.y + 40)
            )
        }
    }
}

// MARK: - Chart Summary View

struct ChartSummaryView: View {
    @Environment(\.dashboardStateModel) private var stateModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Average Alignment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(stateModel.averageAlignment())%")
                    .font(.title3.bold())
                    .foregroundStyle(Color.tmiTextPrimary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Trend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(stateModel.alignmentTrend())
                        .font(.title3.bold())
                        .foregroundStyle(Color.tmiTextPrimary)
                    Image(systemName: stateModel.trendIcon())
                        .foregroundStyle(stateModel.trendColor())
                }
            }
        }
    }
}
