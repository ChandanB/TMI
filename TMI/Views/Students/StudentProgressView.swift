//
//  StudentProgressView.swift
//  TMI
//
//  Comprehensive progress view for a student showing engagement, plan progress, and trends
//

import SwiftUI
import Charts

struct StudentProgressView: View {
    let student: Student
    let plans: [TMIPlan]

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    // Header
                    headerSection

                    // Overall Metrics
                    overallMetricsSection

                    // Plan Progress
                    if !plans.isEmpty {
                        planProgressSection
                    }

                    // Engagement Chart
//                    if let engagementHistory = student.engagementHistory, !engagementHistory.isEmpty {
//                        engagementChartSection(engagementHistory)
//                    }

                    // Academic Performance
                    if let academic = student.academicPerformance {
                        academicSection(academic)
                    }
                }
                .padding(.horizontal, TMISpacing.screenPadding)
                .padding(.vertical, TMISpacing.md)
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: TMISpacing.md) {
            TMIAvatar(
                initials: student.initials,
                color: avatarColor,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(student.name)
                    .font(.tmiTitle2)
                    .foregroundColor(.tmiTextPrimary)

                Text("Grade \(student.grade) • \(student.school)")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()
        }
        .tmiCard()
    }

    // MARK: - Overall Metrics

    private var overallMetricsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Overall Metrics")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            HStack(spacing: TMISpacing.md) {
                metricCard(
                    value: "\(Int(student.engagementScore * 100))%",
                    label: "Engagement",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .tmiPrimary
                )

                metricCard(
                    value: "\(plans.count)",
                    label: "Active Plans",
                    icon: "doc.text",
                    color: .blue
                )

                metricCard(
                    value: "\(student.interests.count)",
                    label: "Interests",
                    icon: "heart.fill",
                    color: .pink
                )
            }
        }
        .tmiCard()
    }

    private func metricCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)

            Text(label)
                .font(.tmiFootnote)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(TMIRadius.sm)
    }

    // MARK: - Plan Progress

    private var planProgressSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("TMI Plan Progress")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                Text("\(Int(averagePlanProgress * 100))% Avg")
                    .font(.tmiCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.tmiPrimary)
            }

            VStack(spacing: TMISpacing.sm) {
                ForEach(plans) { plan in
                    planProgressRow(plan)
                }
            }
        }
        .tmiCard()
    }

    private func planProgressRow(_ plan: TMIPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: planModelIcon(for: plan.model))
                        .font(.system(size: 14))
                        .foregroundColor(planModelColor(for: plan.model))

                    Text(plan.title)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(Int(plan.progress * 100))%")
                    .font(.tmiCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(planModelColor(for: plan.model))
            }

            ProgressView(value: plan.progress)
                .tmiProgressStyle(color: planModelColor(for: plan.model))
        }
        .padding(.vertical, TMISpacing.sm)
    }

    private var averagePlanProgress: Double {
        guard !plans.isEmpty else { return 0 }
        return plans.reduce(0) { $0 + $1.progress } / Double(plans.count)
    }

    // MARK: - Engagement Chart

    private func engagementChartSection(_ history: [EngagementRecord]) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Engagement Over Time")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                if let trend = engagementTrend(history) {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : trend < 0 ? "arrow.down.right" : "arrow.right")
                            .font(.system(size: 12))
                        Text(String(format: "%.1f%%", abs(trend)))
                            .font(.tmiCaption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(trend > 0 ? .green : trend < 0 ? .red : .gray)
                }
            }

            Chart(history.indices, id: \.self) { index in
                let record = history[index]
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score * 100)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.tmiPrimary, .tmiPrimary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                AreaMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score * 100)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.tmiPrimary.opacity(0.3), .tmiPrimary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score * 100)
                )
                .foregroundStyle(Color.tmiPrimary)
                .symbolSize(50)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
            .chartYScale(domain: 0...100)
        }
        .tmiCard()
    }

    private func engagementTrend(_ history: [EngagementRecord]) -> Double? {
        guard history.count >= 2 else { return nil }
        let recent = history.suffix(3)
        let older = history.dropLast(min(3, history.count))

        guard !older.isEmpty else { return nil }

        let recentAvg = recent.reduce(0) { $0 + $1.score } / Double(recent.count)
        let olderAvg = older.reduce(0) { $0 + $1.score } / Double(older.count)

        return ((recentAvg - olderAvg) / olderAvg) * 100
    }

    // MARK: - Academic Section

    private func academicSection(_ academic: AcademicPerformance) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Academic Performance")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                if let gpa = academic.gpa {
                    HStack(spacing: 4) {
                        Text("GPA:")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                        Text(String(format: "%.2f", gpa))
                            .font(.tmiLabelLarge)
                            .foregroundColor(.tmiPrimary)
                    }
                }
            }

            VStack(spacing: TMISpacing.sm) {
                ForEach(academic.subjects, id: \.name) { subject in
                    HStack {
                        Text(subject.name)
                            .font(.tmiBody)
                            .foregroundColor(.tmiTextPrimary)

                        Spacer()

                        Text(subject.grade)
                            .font(.tmiLabelLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(gradeColor(subject.grade))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(gradeColor(subject.grade).opacity(0.1))
                            .cornerRadius(TMIRadius.sm)
                    }
                    .padding(.vertical, 8)

                    if subject.name != academic.subjects.last?.name {
                        TMIDivider()
                    }
                }
            }
        }
        .tmiCard()
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased().prefix(1) {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D", "F": return .red
        default: return .gray
        }
    }

    // MARK: - Helpers

    private var avatarColor: Color {
        switch student.avatarColor {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }

    private func planModelIcon(for model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: return "airplane.departure"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.lefthalf.filled"
        }
    }

    private func planModelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }
}

#Preview {
    NavigationStack {
        StudentProgressView(
            student: Student.sampleStudent,
            plans: TMIPlan.samplePlans
        )
    }
}
