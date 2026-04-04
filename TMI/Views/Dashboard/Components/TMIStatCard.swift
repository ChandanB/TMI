//
//  TMIStatCard.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

// MARK: - Enhanced UI Components
import SwiftUI
import Charts

// MARK: - Card Components
struct TMIStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isAnimated = false
    
    var body: some View {
        HStack(spacing: TMISpacing.md) {
            // Icon container with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [color.opacity(0.2), color.opacity(0.1)]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.9)
            
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                Text(title)
                    .font(.tmiLabelMedium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.tmiHeading2)
                    .foregroundColor(.tmiTextPrimary)
                    .fontWeight(.bold)
                    .opacity(isAnimated ? 1.0 : 0.7)
            }
            
            Spacer()
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous)
                .fill(Color.tmiSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous)
                        .strokeBorder(color.opacity(0.1), lineWidth: 1)
                )
        )
        .tmiShadowSmall()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimated = true
            }
        }
    }
}

struct TMIActivityRow: View {
    let activity: RecentActivity
    @State private var isAnimated = false
    
    var body: some View {
        HStack(spacing: TMISpacing.md) {
            // Activity Icon
            ZStack {
                RoundedRectangle(cornerRadius: TMIRadius.sm, style: .continuous)
                    .fill(Color.tmiPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.tmiPrimary)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.9)
            
            // Activity Details
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                Text(activity.title)
                    .font(.tmiLabelLarge)
                    .foregroundColor(.tmiTextPrimary)
                
                Text(activity.description)
                    .font(.tmiBodySmall)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(activity.date, style: .time)
                    .font(.tmiLabelSmall)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            // Time indicator
            VStack(alignment: .trailing) {
                Text(timeAgo(from: activity.date))
                    .font(.tmiLabelSmall)
                    .foregroundColor(.tmiSecondary)
                    .padding(.horizontal, TMISpacing.xs)
                    .padding(.vertical, TMISpacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.tmiSecondary.opacity(0.1))
                    )
            }
        }
        .padding(TMISpacing.sm)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm, style: .continuous)
                .fill(Color.clear)
        )
        .onAppear {
            withAnimation(.easeOut(duration: TMIAnimation.standard).delay(0.1)) {
                isAnimated = true
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Header Component with dynamic background
struct TMIPageHeader: View {
    let title: String
    let subtitle: String
    let icon: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background with subtle pattern
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                Color.tmiPrimary.opacity(0.15),
                                Color.tmiPrimary.opacity(0.05)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    Canvas { context, size in
                        context.opacity = 0.3
                        for i in stride(from: 0, to: size.width, by: 20) {
                            for j in stride(from: 0, to: size.height, by: 20) {
                                let rect = CGRect(x: i, y: j, width: 1, height: 1)
                                context.fill(Path(rect), with: .color(.tmiPrimary))
                            }
                        }
                    }
                )
            
            // Header content
            VStack(alignment: .leading, spacing: TMISpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.tmiPrimary)
                        .padding(.bottom, TMISpacing.xxs)
                }
                
                Text(title)
                    .font(.tmiDisplay2)
                    .foregroundColor(.tmiTextPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.tmiBodyLarge)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(TMISpacing.md)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous))
        .tmiShadowSmall()
    }
}

// MARK: - Animated Chart Components
struct TMIAnimatedBarChart<Content: ChartContent>: View {
    let content: () -> Content
    @State private var animationProgress: CGFloat = 0.0
    
    var body: some View {
        Chart {
            content()
        }
        .chartYScale(domain: [0, 1.0])
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { value in
                if let doubleValue = value.as(Double.self) {
                    let scaledValue = doubleValue * animationProgress
                    AxisValueLabel {
                        Text("\(Int(scaledValue * 100))%")
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .animation(.easeInOut, value: animationProgress)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
}

struct TMIAnimatedLineChart<Content: ChartContent>: View {
    let content: () -> Content
    @State private var animationProgress: CGFloat = 0.0
    
    var body: some View {
        Chart {
            content()
        }
        .chartYScale(domain: [0, 1.0])
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { value in
                if let doubleValue = value.as(Double.self) {
                    let scaledValue = doubleValue * animationProgress
                    AxisValueLabel {
                        Text("\(Int(scaledValue * 100))%")
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .animation(.easeInOut, value: animationProgress)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Button Styles
struct TMIPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tmiLabelLarge)
            .padding(.vertical, TMISpacing.sm)
            .padding(.horizontal, TMISpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous)
                    .fill(
                        Color.tmiPrimary.opacity(configuration.isPressed ? 0.8 : 1.0)
                    )
            )
            .foregroundColor(Color.tmiTextPrimary)
            .tmiShadowSmall()
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct TMISecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tmiLabelLarge)
            .padding(.vertical, TMISpacing.sm)
            .padding(.horizontal, TMISpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous)
                    .fill(Color.tmiSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: TMIRadius.md, style: .continuous)
                            .strokeBorder(
                                Color.tmiPrimary.opacity(configuration.isPressed ? 0.5 : 0.8), 
                                lineWidth: 1.5
                            )
                    )
            )
            .foregroundColor(.tmiPrimary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func tmiPrimaryButton() -> some View {
        self.buttonStyle(TMIPrimaryButtonStyle())
    }
    
    func tmiSecondaryButton() -> some View {
        self.buttonStyle(TMISecondaryButtonStyle())
    }
}

// MARK: - Enhanced Tab View
struct TMITabView<Content: View>: View {
    let tabs: [String]
    @Binding var selection: Int
    @ViewBuilder let content: (Int) -> Content
    @State private var tabFrames: [CGRect] = []
    @State private var indicatorWidth: CGFloat = 0
    @State private var indicatorPosition: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab headers
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = index
                        }
                        TMIHaptics.lightImpact()
                    }) {
                        Text(tabs[index])
                            .font(.tmiLabelLarge)
                            .foregroundColor(selection == index ? .tmiPrimary : .secondary)
                            .padding(.vertical, TMISpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background {
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        if tabFrames.count <= index {
                                            tabFrames.append(geo.frame(in: .global))
                                        } else {
                                            tabFrames[index] = geo.frame(in: .global)
                                        }
                                        
                                        if selection == index {
                                            updateIndicator(index: index)
                                        }
                                    }
                                }
                            }
                    }
                }
            }
            
            // Tab indicator
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 2)
                
                Rectangle()
                    .fill(Color.tmiPrimary)
                    .frame(width: indicatorWidth, height: 2)
                    .offset(x: indicatorPosition)
            }
            
            // Content
            content(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selection) { _, newValue in
            updateIndicator(index: newValue)
        }
        .onChange(of: tabFrames) { _, _ in
            if !tabFrames.isEmpty {
                updateIndicator(index: selection)
            }
        }
    }
    
    private func updateIndicator(index: Int) {
        guard tabFrames.count > index else { return }
        
        if tabFrames.isEmpty { return }
        
        let frame = tabFrames[index]
        let firstFrame = tabFrames[0]
        
        indicatorWidth = frame.width
        indicatorPosition = frame.minX - firstFrame.minX
    }
}
