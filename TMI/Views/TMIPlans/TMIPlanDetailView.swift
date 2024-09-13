// TMIPlanDetailView.swift

import SwiftUI
import Charts

struct TMIPlanDetailView: View {
    let plan: TMIPlan

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                progressChartView
                insightsSection
                associatedStudentsView
                interestsAndHobbiesSection
                notesSection
                Spacer()
            }
            .padding()
        }
        .background(Color.tmiBackground.ignoresSafeArea())
        .navigationTitle("TMI Plan Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(plan.model.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                Text("Created on \(formattedDate(plan.creationDate))")
                    .font(.subheadline)
                    .foregroundColor(.tmiSecondary)
            }
            Spacer()
            Menu {
                Button("Edit Plan") { /* Implement edit functionality */ }
                Button("Delete Plan", role: .destructive) { /* Implement delete functionality */ }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title)
                    .foregroundColor(.tmiPrimary)
            }
        }
    }

    // MARK: - Progress Chart View

    private var progressChartView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Progress Overview")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)

            Chart {
                ForEach(progressData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Progress", dataPoint.progress)
                    )
                    .foregroundStyle(Color.tmiPrimary.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Progress", dataPoint.progress)
                    )
                    .foregroundStyle(Color.tmiPrimary.opacity(0.1).gradient)
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 250)
            .background(Color.tmiSecondary.opacity(0.1))
            .cornerRadius(15)
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key Insights")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)

            VStack(alignment: .leading, spacing: 8) {
                InsightRow(title: "Current Progress", value: "\(Int(plan.progress * 100))%")
                InsightRow(title: "Last Updated", value: formattedDate(plan.lastUpdated))
                InsightRow(title: "Engagement Trend", value: engagementTrend())
            }
        }
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
    }

    // MARK: - Associated Students View

    private var associatedStudentsView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Associated Students")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(plan.students) { student in
                        StudentCard(student: student)
                            .padding()
                    }
                }
            }
        }
    }

    // MARK: - Interests and Hobbies Section

    private var interestsAndHobbiesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Interests & Hobbies")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)

            if plan.interests.isEmpty && plan.hobbies.isEmpty {
                Text("No interests or hobbies specified.")
                    .font(.body)
                    .foregroundColor(.tmiSecondary)
            } else {
                if !plan.interests.isEmpty {
                    Text("Interests")
                        .font(.headline)
                        .foregroundColor(.tmiText)
                    WrapView(items: plan.interests.map { $0.name }) { item in
                        TagView(title: item)
                    }
                }

                if !plan.hobbies.isEmpty {
                    Text("Hobbies")
                        .font(.headline)
                        .foregroundColor(.tmiText)
                    WrapView(items: plan.hobbies.map { $0.name }) { item in
                        TagView(title: item)
                    }
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Notes")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.tmiText)

            if plan.notes.isEmpty {
                Text("No notes added.")
                    .font(.body)
                    .foregroundColor(.tmiSecondary)
            } else {
                Text(plan.notes)
                    .font(.body)
                    .foregroundColor(.tmiText)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func engagementTrend() -> String {
        let values = progressData.map { $0.progress }
        if values.first! < values.last! {
            return "Improving"
        } else if values.first! > values.last! {
            return "Declining"
        } else {
            return "Stable"
        }
    }

    private var progressData: [ProgressData] {
        return [
            ProgressData(date: "Week 1", progress: 0.2),
            ProgressData(date: "Week 2", progress: 0.35),
            ProgressData(date: "Week 3", progress: 0.5),
            ProgressData(date: "Week 4", progress: 0.65),
            ProgressData(date: "Week 5", progress: plan.progress)
        ]
    }
}

// MARK: - Custom Components
struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.tmiText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.tmiSecondary)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .foregroundColor(.white)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct ProgressBar: View {
    let progress: Double   // Value between 0 and 1
    var showPercentage: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                Capsule()
                    .frame(height: 10)
                    .foregroundColor(Color.white.opacity(0.3))
                Capsule()
                    .frame(width: progressWidth, height: 10)
                    .foregroundColor(progressColor)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            if showPercentage {
                Text("\(Int(progress * 100))% Complete")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var progressWidth: CGFloat {
        // Assuming a default width of 300 for calculation; adjust as needed
        return CGFloat(300 * progress)
    }

    private var progressColor: Color {
        switch progress {
        case 0..<0.3:
            return .red
        case 0.3..<0.7:
            return .yellow
        default:
            return .green
        }
    }
}

struct AvatarView: View {
    let student: Student

    var body: some View {
        ZStack {
            if let avatarImage = studentAvatar {
                avatarImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            } else {
                Text(student.initials)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
        
    }

    private var studentAvatar: Image? {
        // Implement avatar retrieval if available
        return nil
    }
}

struct TagView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
    }
}

struct WrapView<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { dimension in
                        if (abs(width - dimension.width) > geometry.size.width) {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        width -= dimension.width
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    self.totalHeight = abs(height)
                }
            }
        )
    }
}

struct FlowLayout<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewHeightKey.self, value: geometry.size.height)
        }
        .onPreferenceChange(ViewHeightKey.self) { binding.wrappedValue = $0 }
    }

    private struct ViewHeightKey: PreferenceKey {
        static var defaultValue: CGFloat {
            return 0
        }

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
}

#Preview {
    TMIPlanDetailView(plan: TMIPlan.samplePlan)
}
