//
//  StudentStatusWidget.swift
//  TMI
//
//  At-a-glance student engagement overview for educators
//

import SwiftUI
import Charts

// MARK: - Student Status Overview Widget

struct StudentStatusWidget: View {
    @State private var stateModel = StudentListStateModel()
    @State private var animateChart = false

    var engagementBreakdown: (engaged: Int, growing: Int, needsSupport: Int) {
        let students = stateModel.filteredStudents

        let engaged = students.filter { $0.engagementScore >= 0.7 }.count
        let growing = students.filter { $0.engagementScore >= 0.4 && $0.engagementScore < 0.7 }.count
        let needsSupport = students.filter { $0.engagementScore < 0.4 }.count

        return (engaged, growing, needsSupport)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Student Engagement")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Text("Current status overview")
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()
            }

            // Visualization
            switch stateModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TMISpacing.xl)

            case .loaded:
                if stateModel.filteredStudents.isEmpty {
                    emptyState
                } else {
                    engagementContent
                }

            case .error:
                errorState
            }
        }
        .tmiCard(style: .elevated)
        .task {
            await stateModel.fetch()
        }
    }

    // MARK: - Engagement Content

    private var engagementContent: some View {
        VStack(spacing: TMISpacing.md) {
            // Donut Chart
            Chart {
                SectorMark(
                    angle: .value("Engaged", animateChart ? engagementBreakdown.engaged : 0),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Color.tmiSuccess)

                SectorMark(
                    angle: .value("Growing", animateChart ? engagementBreakdown.growing : 0),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Color.tmiWarning)

                SectorMark(
                    angle: .value("Needs Support", animateChart ? engagementBreakdown.needsSupport : 0),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Color(hex: "#FB923C"))
            }
            .frame(height: 160)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    let frame = geometry[chartProxy.plotAreaFrame]
                    VStack(spacing: 2) {
                        Text("\(stateModel.filteredStudents.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)
                        Text("Students")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    animateChart = true
                }
            }

            // Legend with counts
            VStack(spacing: TMISpacing.sm) {
                engagementLegendRow(
                    label: "Engaged",
                    count: engagementBreakdown.engaged,
                    color: .tmiSuccess,
                    percentage: engagementPercentage(count: engagementBreakdown.engaged)
                )

                engagementLegendRow(
                    label: "Growing",
                    count: engagementBreakdown.growing,
                    color: .tmiWarning,
                    percentage: engagementPercentage(count: engagementBreakdown.growing)
                )

                engagementLegendRow(
                    label: "Needs Support",
                    count: engagementBreakdown.needsSupport,
                    color: Color(hex: "#FB923C"),
                    percentage: engagementPercentage(count: engagementBreakdown.needsSupport)
                )
            }
        }
    }

    private func engagementLegendRow(label: String, count: Int, color: Color, percentage: Int) -> some View {
        HStack(spacing: TMISpacing.sm) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            // Label
            Text(label)
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)

            Spacer()

            // Count and percentage
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.tmiTextPrimary)

                Text("(\(percentage)%)")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .padding(.horizontal, TMISpacing.sm)
        .padding(.vertical, TMISpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm)
                .fill(color.opacity(0.05))
        )
    }

    private func engagementPercentage(count: Int) -> Int {
        let total = stateModel.filteredStudents.count
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total)) * 100)
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: TMISpacing.sm) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.tmiTextTertiary)

            Text("No students yet")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)

            Text("Add your first student to see engagement data")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.xl)
    }

    private var errorState: some View {
        VStack(spacing: TMISpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.tmiError)

            Text("Unable to load student data")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)

            Button("Try Again") {
                Task {
                    await stateModel.fetch()
                }
            }
            .font(.tmiCaption)
            .foregroundColor(.tmiPrimary)
        }
        .padding(.vertical, TMISpacing.xl)
    }
}

// MARK: - Compact Status Bar

struct StudentStatusBar: View {
    let engaged: Int
    let growing: Int
    let needsSupport: Int

    var total: Int {
        engaged + growing + needsSupport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            // Labels
            HStack {
                statusLabel("Engaged", color: .tmiSuccess)
                Spacer()
                statusLabel("Growing", color: .tmiWarning)
                Spacer()
                statusLabel("Support", color: Color(hex: "#FB923C"))
            }
            .font(.tmiCaption)

            // Progress bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.tmiSuccess)
                        .frame(width: barWidth(count: engaged, total: total, totalWidth: geometry.size.width))

                    Rectangle()
                        .fill(Color.tmiWarning)
                        .frame(width: barWidth(count: growing, total: total, totalWidth: geometry.size.width))

                    Rectangle()
                        .fill(Color(hex: "#FB923C"))
                        .frame(width: barWidth(count: needsSupport, total: total, totalWidth: geometry.size.width))
                }
                .cornerRadius(4)
            }
            .frame(height: 8)

            // Counts
            HStack {
                statusCount(engaged, color: .tmiSuccess)
                Spacer()
                statusCount(growing, color: .tmiWarning)
                Spacer()
                statusCount(needsSupport, color: Color(hex: "#FB923C"))
            }
        }
    }

    private func statusLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundColor(color)
            .fontWeight(.medium)
    }

    private func statusCount(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.tmiCaption)
            .fontWeight(.bold)
            .foregroundColor(color)
    }

    private func barWidth(count: Int, total: Int, totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return (CGFloat(count) / CGFloat(total)) * (totalWidth - 4) // -4 for spacing
    }
}

// MARK: - Preview

#Preview("Widget") {
    ScrollView {
        VStack(spacing: TMISpacing.lg) {
            StudentStatusWidget()
                .padding()
        }
        .background(Color.tmiBackground)
    }
}

#Preview("Status Bar") {
    VStack {
        StudentStatusBar(engaged: 12, growing: 5, needsSupport: 3)
            .padding()
            .background(Color.tmiSurface)
            .cornerRadius(TMIRadius.md)
            .padding()
    }
    .background(Color.tmiBackground)
}
