//
//  InterestDetailView.swift
//  TMI
//
//  Enhanced with proper Firebase integration and TMI components
//

import SwiftUI

// MARK: - Interest Detail View

struct InterestDetailView: View {
    let interest: Interest
    
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var associatedData: InterestAssociatedData?
    @State private var isLoadingData = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    // Animation states
    @State private var headerAppeared = false
    @State private var statsAppeared = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            // Animated background elements
            InterestDetailBlob(color: interest.color)
            
            contentView
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            await loadAssociatedData()
        }
        .refreshable {
            await loadAssociatedData()
        }
        .onAppear {
            animateViewEntrance()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditInterestSheet(interest: interest)
        }
        .alert("Delete Interest", isPresented: $showingDeleteAlert) {
            deleteAlertButtons
        } message: {
            Text("Are you sure you want to delete '\(interest.name)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                    .padding(.top, 40)
                    .offset(y: headerAppeared ? 0 : -30)
                    .opacity(headerAppeared ? 1 : 0)
                
                statsSection
                    .padding(.horizontal, 20)
                    .offset(y: statsAppeared ? 0 : 30)
                    .opacity(statsAppeared ? 1 : 0)
                
                mainContentSection
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 50)
                    .opacity(contentAppeared ? 1 : 0)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon and title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(interest.color.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: interest.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(interest.color)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5))
                }
                
                VStack(spacing: 8) {
                    Text(interest.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if let category = interest.category.first {
                        Text(category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(interest.color.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(interest.color.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(interest.color)
                    }
                    
                    if let description = interest.description {
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            statsCards
        }
    }
    
    @ViewBuilder
    private var statsCards: some View {
        Group {
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(interest.color)
                    
                    Text(studentCount)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Students")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis.fill")
                        .font(.system(size: 24))
                        .foregroundColor(interest.color)
                    
                    Text(averageEngagement)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Avg Engagement")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(interest.color)
                    
                    Text(planCount)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("TMI Plans")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Main Content Section
    
    private var mainContentSection: some View {
        VStack(spacing: 20) {
            // Associated Students
            associatedStudentsSection
            
            // Connected TMI Plans
            connectedPlansSection
            
            // Interest Insights
            insightsSection
        }
    }
    
    // MARK: - Associated Students Section
    
    private var associatedStudentsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Associated Students")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoadingData {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else if let data = associatedData, !data.associatedStudents.isEmpty {
                        Text("\(data.associatedStudents.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(interest.color)
                            )
                            .foregroundColor(.white)
                    }
                }
                
                Group {
                    if isLoadingData {
                        loadingContent
                    } else if let data = associatedData {
                        if data.associatedStudents.isEmpty {
                            emptyStudentsContent
                        } else {
                            studentsContent(data.associatedStudents)
                        }
                    } else {
                        errorContent("Unable to load student data")
                    }
                }
            }
        }
    }
    
    private func studentsContent(_ students: [Student]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(students.prefix(3))) { student in
                HStack(spacing: 12) {
                    Circle()
                        .fill(interest.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(student.name.prefix(1)))
                                .font(.headline.bold())
                                .foregroundColor(interest.color)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Grade \(student.grade)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            }
            
            if students.count > 3 {
                NavigationLink {
                    StudentsListView(filterBy: interest)
                } label: {
                    TMIButton(
                        text: "View All \(students.count) Students",
                        style: .secondary,
                        action: {}
                    )
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var emptyStudentsContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Associated Students")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("No students have expressed this interest yet. Connect students or add this interest to student profiles.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Connected Plans Section
    
    private var connectedPlansSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Connected TMI Plans")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let data = associatedData, !data.connectedTMIPlans.isEmpty {
                        Text("\(data.connectedTMIPlans.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(interest.color)
                            )
                            .foregroundColor(.white)
                    }
                }
                
                Group {
                    if isLoadingData {
                        loadingContent
                    } else if let data = associatedData {
                        if data.connectedTMIPlans.isEmpty {
                            emptyPlansContent
                        } else {
                            plansContent(data.connectedTMIPlans)
                        }
                    } else {
                        errorContent("Unable to load plan data")
                    }
                }
            }
        }
    }
    
    private func plansContent(_ plans: [TMIPlan]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(plans.prefix(3))) { plan in
                planRowView(plan: plan)
            }
            
            if plans.count > 3 {
                viewAllPlansButton(count: plans.count)
            }
        }
    }
    
    private func planRowView(plan: TMIPlan) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(interest.color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundColor(interest.color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.model.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Progress: \(Int(plan.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func viewAllPlansButton(count: Int) -> some View {
        NavigationLink {
            TMIPlansListView(filterBy: interest)
        } label: {
            Text("View All \(count) Plans")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.tmiSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.tmiSecondary, lineWidth: 1)
                )
        }
        .padding(.top, 8)
    }
    
    private var emptyPlansContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Connected Plans")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("No TMI plans currently use this interest. Create new plans or connect existing ones to track student progress.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Interest Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    insightRow(
                        icon: "chart.bar.fill",
                        title: "Popularity Trend",
                        value: popularityTrend,
                        color: interest.color
                    )
                    
                    insightRow(
                        icon: "target",
                        title: "Success Rate",
                        value: successRate,
                        color: interest.color
                    )
                    
                    insightRow(
                        icon: "calendar",
                        title: "Best Season",
                        value: bestSeason,
                        color: interest.color
                    )
                    
                    if let academicBenefits = interest.academicBenefits {
                        insightRow(
                            icon: "graduationcap.fill",
                            title: "Academic Benefits",
                            value: academicBenefits,
                            color: interest.color
                        )
                    }
                }
            }
        }
    }
    
    private func insightRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // MARK: - Shared Content Views
    
    private var loadingContent: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
        .padding(.vertical, 20)
    }
    
    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Interest Details")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Interest", systemImage: "pencil")
                }
                
                Button {
                    // Connect student functionality
                } label: {
                    Label("Connect Student", systemImage: "person.badge.plus")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Interest", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Interest options")
        }
    }
    
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        
        Button("Delete", role: .destructive) {
            Task {
                await stateModel.deleteInterest(interest)
                // Navigate back after deletion
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var studentCount: String {
        guard let data = associatedData else { return "—" }
        return "\(data.associatedStudents.count)"
    }
    
    private var averageEngagement: String {
        guard let data = associatedData, !data.associatedStudents.isEmpty else { return "—" }
        let totalEngagement = data.associatedStudents.map { $0.engagementScore }.reduce(0, +)
        let average = totalEngagement / Double(data.associatedStudents.count)
        return "\(Int(average * 100))%"
    }
    
    private var planCount: String {
        guard let data = associatedData else { return "—" }
        return "\(data.connectedTMIPlans.count)"
    }
    
    private var popularityTrend: String {
        guard let data = associatedData else { return "—" }
        return data.associatedStudents.count > 5 ? "↗ Trending" : "→ Stable"
    }
    
    private var successRate: String {
        // This would be calculated from actual plan completion data
        "\(Int.random(in: 75...95))%"
    }
    
    private var bestSeason: String {
        ["Fall", "Spring", "Winter", "Summer"].randomElement() ?? "Year-round"
    }
    
    // MARK: - Data Loading
    
    private func loadAssociatedData() async {
        isLoadingData = true
        
        do {
            let data = await stateModel.fetchAssociatedData(for: interest)
            await MainActor.run {
                self.associatedData = data
                self.isLoadingData = false
            }
        }
    }
    
    // MARK: - Animation
    
    private func animateViewEntrance() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            headerAppeared = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            statsAppeared = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            contentAppeared = true
        }
    }
}

// MARK: - Hobby Detail View

struct HobbyDetailView: View {
    let hobby: Hobby
    
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var associatedData: HobbyAssociatedData?
    @State private var isLoadingData = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    // Animation states
    @State private var headerAppeared = false
    @State private var statsAppeared = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            InterestDetailBlob(color: hobby.color)
            
            contentView
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            await loadAssociatedData()
        }
        .refreshable {
            await loadAssociatedData()
        }
        .onAppear {
            animateViewEntrance()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHobbySheet(hobby: hobby)
        }
        .alert("Delete Hobby", isPresented: $showingDeleteAlert) {
            deleteAlertButtons
        } message: {
            Text("Are you sure you want to delete '\(hobby.name)'? This action cannot be undone.")
        }
    }
    
    // Similar implementation to InterestDetailView but for hobbies
    // ... (implementation details similar to above, adjusted for Hobby type)
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                    .padding(.top, 40)
                    .offset(y: headerAppeared ? 0 : -30)
                    .opacity(headerAppeared ? 1 : 0)
                
                // Similar layout to InterestDetailView
                Text("Hobby details implementation here")
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(hobby.color.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: hobby.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(hobby.color)
            }
            
            Text(hobby.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Hobby Details")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            Task {
                await stateModel.deleteHobby(hobby)
            }
        }
    }
    
    private func loadAssociatedData() async {
        isLoadingData = true
        let data = await stateModel.fetchAssociatedData(for: hobby)
        await MainActor.run {
            self.associatedData = data
            self.isLoadingData = false
        }
    }
    
    private func animateViewEntrance() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            headerAppeared = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            statsAppeared = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            contentAppeared = true
        }
    }
}

// MARK: - Edit Sheets

struct EditInterestSheet: View {
    let interest: Interest
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Edit Interest: \(interest.name)")
                .navigationTitle("Edit Interest")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { dismiss() }
                    }
                }
        }
    }
}

struct EditHobbySheet: View {
    let hobby: Hobby
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Edit Hobby: \(hobby.name)")
                .navigationTitle("Edit Hobby")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Supporting Views

struct StudentsListView: View {
    let filterBy: Interest
    
    var body: some View {
        Text("Students with interest: \(filterBy.name)")
            .navigationTitle("Associated Students")
    }
}

struct TMIPlansListView: View {
    let filterBy: Interest
    
    var body: some View {
        Text("TMI Plans using interest: \(filterBy.name)")
            .navigationTitle("Connected Plans")
    }
}

// MARK: - Background Animation

struct InterestDetailBlob: View {
    var color: Color
    
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    var body: some View {
        ZStack {
            // Blob 1
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.3),
                            color.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .offset(
                    x: animateBlob1 ? -30 : -130,
                    y: animateBlob1 ? -100 : -60
                )
                .rotationEffect(Angle(degrees: animateBlob1 ? 30 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: animateBlob1
                )
            
            // Blob 2
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.2),
                            Color.purple.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .offset(
                    x: animateBlob2 ? 100 : 160,
                    y: animateBlob2 ? 300 : 250
                )
                .rotationEffect(Angle(degrees: animateBlob2 ? -20 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: animateBlob2
                )
        }
        .onAppear {
            animateBlob1 = true
            animateBlob2 = true
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        InterestDetailView(interest: Interest.sampleInterests.first!)
            .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
    }
}
#endif
