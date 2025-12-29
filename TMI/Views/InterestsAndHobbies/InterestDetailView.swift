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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var associatedData: InterestAssociatedData?
    @State private var isLoadingData = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingConnectStudent = false

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
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            Task {
                await loadAssociatedData()
            }
        }) {
            EditInterestSheet(interest: interest)
        }
        .sheet(isPresented: $showingConnectStudent) {
            ConnectStudentSheet(interest: interest, onConnect: { student in
                Task {
                    await connectStudentToInterest(student)
                }
            })
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
            DetailStatsCard(
                icon: "person.2.fill",
                value: studentCount,
                label: "Students",
                color: interest.color,
                index: 0
            )

            DetailStatsCard(
                icon: "chart.line.uptrend.xyaxis.fill",
                value: averageEngagement,
                label: "Avg Engagement",
                color: interest.color,
                index: 1
            )

            DetailStatsCard(
                icon: "doc.fill",
                value: planCount,
                label: "TMI Plans",
                color: interest.color,
                index: 2
            )
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
        VStack(spacing: 10) {
            ForEach(Array(students.prefix(3))) { student in
                NavigationLink {
                    StudentDetailView(student: student)
                } label: {
                    StudentRowView(student: student, color: interest.color)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if students.count > 3 {
                NavigationLink {
                    StudentsListView(filterBy: interest)
                } label: {
                    HStack {
                        Text("View All \(students.count) Students")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(interest.color)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(interest.color)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(interest.color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(interest.color.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .padding(.top, 4)
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
        VStack(spacing: 10) {
            ForEach(Array(plans.prefix(3))) { plan in
                NavigationLink {
                    TMIPlanDetailView(plan: plan)
                } label: {
                    PlanRowView(plan: plan, color: interest.color)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if plans.count > 3 {
                NavigationLink {
                    TMIPlansListView(filterBy: interest)
                } label: {
                    HStack {
                        Text("View All \(plans.count) Plans")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(interest.color)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(interest.color)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(interest.color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(interest.color.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .padding(.top, 4)
            }
        }
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
                    showingConnectStudent = true
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
                await MainActor.run {
                    dismiss()
                }
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

        let studentCount = data.associatedStudents.count

        // Determine trend based on student count thresholds
        switch studentCount {
        case 0...2:
            return "→ Emerging"
        case 3...5:
            return "→ Stable"
        case 6...10:
            return "↗ Growing"
        default:
            return "↗↗ Trending"
        }
    }

    private var successRate: String {
        guard let data = associatedData else { return "—" }

        // Calculate success rate based on TMI plan completion
        let completedPlans = data.connectedTMIPlans.filter { $0.calculatedProgress >= 0.8 }.count
        let totalPlans = data.connectedTMIPlans.count

        guard totalPlans > 0 else { return "No data" }

        let successPercentage = (Double(completedPlans) / Double(totalPlans)) * 100
        return "\(Int(successPercentage))%"
    }

    private var bestSeason: String {
        guard let data = associatedData else { return "—" }

        // Analyze when this interest was most popular based on creation dates
        let calendar = Calendar.current
        let seasonCounts = data.associatedStudents.reduce(into: [String: Int]()) { counts, student in
            // Use the student's last interaction date or current date as proxy
            let date = student.lastInteractionDate ?? Date()
            let month = calendar.component(.month, from: date)

            let season: String
            switch month {
            case 12, 1, 2:
                season = "Winter"
            case 3, 4, 5:
                season = "Spring"
            case 6, 7, 8:
                season = "Summer"
            case 9, 10, 11:
                season = "Fall"
            default:
                season = "Year-round"
            }

            counts[season, default: 0] += 1
        }

        // Find the season with the most students
        if let mostPopularSeason = seasonCounts.max(by: { $0.value < $1.value })?.key {
            return mostPopularSeason
        }

        return "Year-round"
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

    // MARK: - Student Connection

    @MainActor
    private func connectStudentToInterest(_ student: Student) async {
        guard let studentId = student.id, let interestId = interest.id else {
            print("Failed to connect: Missing student or interest ID")
            return
        }

        // Check if the student already has this interest using edge collection
        do {
            let hasInterest = try await student.hasInterest(interestId: interestId)

            if !hasInterest {
                // Add interest to student via edge collection
                try await student.addInterest(interest, level: 3, source: .staff)

                // Refresh the associated data to show the newly connected student
                await loadAssociatedData()
            }
        } catch {
            print("Failed to connect student to interest: \(error)")
        }
    }
}

// Note: HobbyDetailView removed - now using unified InterestDetailView

// MARK: - Edit Sheets

struct EditInterestSheet: View {
    let interest: Interest
    @Environment(\.dismiss) var dismiss
    @Environment(\.interestsStateModel) var stateModel

    @State private var name: String
    @State private var selectedCategories: Set<InterestCategory>
    @State private var description: String
    @State private var selectedAcademicSubjects: Set<AcademicSubject>
    @State private var selectedInterventionModels: Set<InterventionModel>
    @State private var academicBenefits: String
    @State private var behavioralBenefits: String
    @State private var isFeatured: Bool
    @State private var isSaving = false

    init(interest: Interest) {
        self.interest = interest
        _name = State(initialValue: interest.name)
        _selectedCategories = State(initialValue: Set(interest.category))
        _description = State(initialValue: interest.description ?? "")
        _selectedAcademicSubjects = State(initialValue: Set(interest.academicRelevance))
        _selectedInterventionModels = State(initialValue: Set(interest.interventionModels))
        _academicBenefits = State(initialValue: interest.academicBenefits ?? "")
        _behavioralBenefits = State(initialValue: interest.behavioralBenefits ?? "")
        _isFeatured = State(initialValue: interest.isFeatured)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Interest Name", text: $name)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Categories") {
                    ForEach(InterestCategory.allCases.filter { $0 != .other }, id: \.self) { category in
                        Toggle(isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { isSelected in
                                if isSelected {
                                    selectedCategories.insert(category)
                                } else {
                                    selectedCategories.remove(category)
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: category.iconName)
                                    .foregroundColor(category.color)
                                Text(category.rawValue)
                            }
                        }
                    }
                }

                Section("Academic Relevance") {
                    ForEach(AcademicSubject.allCases, id: \.self) { subject in
                        Toggle(isOn: Binding(
                            get: { selectedAcademicSubjects.contains(subject) },
                            set: { isSelected in
                                if isSelected {
                                    selectedAcademicSubjects.insert(subject)
                                } else {
                                    selectedAcademicSubjects.remove(subject)
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: subject.iconName)
                                Text(subject.rawValue)
                            }
                        }
                    }
                }

                Section("TMI Intervention Models") {
                    ForEach(InterventionModel.allCases, id: \.self) { model in
                        Toggle(isOn: Binding(
                            get: { selectedInterventionModels.contains(model) },
                            set: { isSelected in
                                if isSelected {
                                    selectedInterventionModels.insert(model)
                                } else {
                                    selectedInterventionModels.remove(model)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.rawValue)
                                    .font(.body)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Benefits") {
                    TextField("Academic Benefits", text: $academicBenefits, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Behavioral Benefits", text: $behavioralBenefits, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Toggle("Featured Interest", isOn: $isFeatured)
                }
            }
            .navigationTitle("Edit Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveInterest()
                        }
                    }
                    .disabled(name.isEmpty || selectedCategories.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
        }
    }

    private func saveInterest() async {
        isSaving = true
        defer { isSaving = false }

        let updatedInterest = Interest(
            id: interest.id,
            name: name,
            category: Array(selectedCategories),
            description: description.isEmpty ? nil : description,
            academicRelevance: Array(selectedAcademicSubjects),
            interventionModels: Array(selectedInterventionModels),
            popularityScore: interest.popularityScore,
            isFeatured: isFeatured,
            createdAt: interest.createdAt,
            academicBenefits: academicBenefits.isEmpty ? nil : academicBenefits,
            careerPathways: interest.careerPathways,
            educationalActivities: interest.educationalActivities,
            behavioralBenefits: behavioralBenefits.isEmpty ? nil : behavioralBenefits,
            skillsDeveloped: interest.skillsDeveloped,
            tierRelevance: interest.tierRelevance,
            relatedInterests: interest.relatedInterests,
            relatedStudents: interest.relatedStudents,
            schemaVersion: interest.schemaVersion
        )

        await stateModel.updateInterest(updatedInterest)
        dismiss()
    }
}

// Note: EditHobbySheet removed - now using unified EditInterestSheet

// MARK: - Connect Student Sheet

struct ConnectStudentSheet: View {
    let interest: Interest
    let onConnect: (Student) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var studentService = StudentService()
    @State private var students: [Student] = []
    @State private var filteredStudents: [Student] = []
    @State private var isLoading = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading students...")
                } else if filteredStudents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(searchText.isEmpty ? "No students available" : "No students found")
                            .font(.headline)

                        Text(searchText.isEmpty ?
                            "All students already have this interest" :
                            "Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List(filteredStudents) { student in
                        Button(action: {
                            onConnect(student)
                            dismiss()
                        }) {
                            HStack {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(student.avatarColor.color)
                                        .frame(width: 40, height: 40)

                                    Text(student.initials)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(student.name)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    Text("Grade \(student.grade)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.tmiPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Search students")
                }
            }
            .navigationTitle("Connect Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStudents()
            }
            .onChange(of: searchText) { _, _ in
                filterStudents()
            }
        }
    }

    @MainActor
    private func loadStudents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load all students
            students = try await studentService.fetchStudents()

            // Filter out students who already have this interest
            guard let interestId = interest.id else {
                filteredStudents = students
                return
            }

            // Check each student asynchronously
            var studentsWithoutInterest: [Student] = []
            for student in students {
                guard let studentId = student.id else { continue }

                do {
                    let hasInterest = try await student.hasInterest(interestId: interestId)
                    if !hasInterest {
                        studentsWithoutInterest.append(student)
                    }
                } catch {
                    // If we can't check, include the student to be safe
                    studentsWithoutInterest.append(student)
                }
            }

            filteredStudents = studentsWithoutInterest
        } catch {
            print("[ConnectStudentSheet] Failed to load students: \(error)")
            students = []
            filteredStudents = []
        }
    }

    @MainActor
    private func filterStudents() {
        // Start with all students (not filtered students, since we need to re-apply search)
        Task {
            guard let interestId = interest.id else {
                filteredStudents = students
                return
            }

            // Check each student asynchronously and apply search filter
            var studentsWithoutInterest: [Student] = []
            for student in students {
                // Apply search filter first
                if !searchText.isEmpty && !student.name.localizedCaseInsensitiveContains(searchText) {
                    continue
                }

                guard let studentId = student.id else { continue }

                do {
                    let hasInterest = try await student.hasInterest(interestId: interestId)
                    if !hasInterest {
                        studentsWithoutInterest.append(student)
                    }
                } catch {
                    // If we can't check, include the student to be safe
                    studentsWithoutInterest.append(student)
                }
            }

            filteredStudents = studentsWithoutInterest
        }
    }
}

extension AvatarColor {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
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

// MARK: - Detail Stats Card

struct DetailStatsCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let index: Int

    @State private var isHovered = false
    @State private var hasAppeared = false

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .scaleEffect(isHovered ? 1.15 : 1.0)
                        .blur(radius: isHovered ? 4 : 0)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(color)
                        .symbolEffect(.bounce, options: .speed(0.5), value: isHovered)
                }

                VStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.vertical, 12)
        }
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .shadow(
            color: isHovered ? color.opacity(0.4) : Color.clear,
            radius: isHovered ? 16 : 0,
            y: isHovered ? 6 : 0
        )
        .scaleEffect(hasAppeared ? 1.0 : 0.7)
        .opacity(hasAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1)) {
                hasAppeared = true
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Student Row View

struct StudentRowView: View {
    let student: Student
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(String(student.name.prefix(1)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(student.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 10))
                        .foregroundColor(color.opacity(0.7))

                    Text("Grade \(student.grade)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .offset(x: isHovered ? 4 : 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isHovered
                        ? color.opacity(0.1)
                        : Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isHovered
                                ? color.opacity(0.3)
                                : Color.white.opacity(0.1),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? color.opacity(0.2) : Color.clear,
            radius: isHovered ? 10 : 0,
            y: isHovered ? 4 : 0
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Plan Row View

struct PlanRowView: View {
    let plan: TMIPlan
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.model.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: 80 * plan.calculatedProgress, height: 6)
                    }

                    Text("\(plan.progressPercentage)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .offset(x: isHovered ? 4 : 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isHovered
                        ? color.opacity(0.1)
                        : Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isHovered
                                ? color.opacity(0.3)
                                : Color.white.opacity(0.1),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? color.opacity(0.2) : Color.clear,
            radius: isHovered ? 10 : 0,
            y: isHovered ? 4 : 0
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
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
