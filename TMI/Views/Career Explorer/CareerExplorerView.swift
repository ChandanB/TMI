import SwiftUI

struct CareerExplorerView: View {
  @State private var careers: [Career] = []
  @State private var trendingCareers: [Career] = []
  @State private var searchText = ""
  @State private var selectedField: String?
  @State private var isFilterSheetPresented = false
  @State private var salaryFilter: ClosedRange<Double> = 30000...150000
  @State private var selectedSkills: Set<String> = []
  @State private var animateCards = false
  @State private var isLoading = false
  @State private var error: Error?
  @State private var careerStatistics: CareerStatistics?
  @State private var showTrendingSection = true

  // Animation states
  @State private var headerAppeared = false
  @State private var filtersAppeared = false
  @State private var searchAppeared = false
  @State private var statsAppeared = false
  
  // Student selection and personalization
  @State private var selectedStudent: Student? = nil
  @State private var personalizedRecommendations: [Career] = []
  @State private var careerInsights: CareerDiscoveryInsights? = nil
  @State private var showPersonalizedSection = false
  @State private var showingStudentPicker = false
  @State private var showingInsightsSheet = false

  private let careerService = CareerService.shared

  // Get all unique skills across careers
  private var allSkills: [String] {
    Array(Set(careers.flatMap { $0.skills })).sorted()
  }
  
  // Break up the complex body expression to fix compiler timeout
  private var mainContent: some View {
    VStack(spacing: 0) {
      // Search bar with enhanced design
      enhancedSearchBar
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .opacity(searchAppeared ? 1 : 0)
        .offset(y: searchAppeared ? 0 : -20)
        .animation(
          .spring(response: 0.6, dampingFraction: 0.7).delay(0.2),
          value: searchAppeared)

      // Enhanced career field picker
      enhancedCareerFieldPicker
        .padding(.bottom, 16)
        .opacity(filtersAppeared ? 1 : 0)
        .offset(y: filtersAppeared ? 0 : -15)
        .animation(
          .spring(response: 0.6, dampingFraction: 0.7).delay(0.3),
          value: filtersAppeared)

      scrollableContent
    }
  }
  
  private var scrollableContent: some View {
    ZStack {
      // Main content with glass morphism effect
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if isLoading {
            // Loading state
            loadingView
          } else if !filteredCareers.isEmpty {
            careerContent
          } else {
            // Enhanced empty state
            enhancedEmptyStateView
          }
        }
        .padding(20)
      }
    }
    .background(glassMorphismBackground)
    .cornerRadius(28, corners: [.topLeft, .topRight])
  }
  
  private var careerContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Personalized recommendations section (only show if student selected)
      if showPersonalizedSection && searchText.isEmpty
        && selectedField == nil && selectedSkills.isEmpty
      {
        personalizedRecommendationsSection
      }

      // Trending careers section (only show if not filtering)
      if showTrendingSection && searchText.isEmpty
        && selectedField == nil && selectedSkills.isEmpty
      {
        trendingCareersSection
      }

      // Career statistics summary with enhanced design
      enhancedCareerStatsSummary
        .opacity(statsAppeared ? 1 : 0)
        .offset(y: statsAppeared ? 0 : 15)
        .animation(
          .spring(response: 0.6, dampingFraction: 0.7).delay(0.4),
          value: statsAppeared)

      // Career grid with enhanced cards
      careerGrid
    }
  }
  
  private var careerGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 170), spacing: 16)],
      spacing: 20
    ) {
      ForEach(filteredCareers.indices, id: \.self) { index in
        let career = filteredCareers[index]
        NavigationLink(
          destination: CareerDetailView(career: career)
        ) {
          PremiumCareerCard(career: career)
            .scaleEffect(animateCards ? 1 : 0.9)
            .opacity(animateCards ? 1 : 0)
            .animation(
              .spring(response: 0.4, dampingFraction: 0.7)
                .delay(Double(index % 6) * 0.05 + 0.2),
              value: animateCards
            )
            .onTapGesture {
              Task {
                try? await careerService
                  .trackCareerExploration(
                    career: career,
                    action: .viewed
                  )
              }
            }
        }
      }
    }
  }
  
  private var glassMorphismBackground: some View {
    RoundedRectangle(cornerRadius: 28, style: .continuous)
      .fill(Color.white.opacity(0.05))
      .background(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(.ultraThinMaterial)
          .opacity(0.9)
      )
      .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
      .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
          )
      )
  }

  private var studentPickerBackground: some View {
    RoundedRectangle(cornerRadius: 18)
      .fill((selectedStudent != nil) ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.1))
      .background(
        RoundedRectangle(cornerRadius: 18)
          .fill(.ultraThinMaterial)
          .opacity(0.3)
      )
  }
  
  private var studentPickerOverlay: some View {
    RoundedRectangle(cornerRadius: 18)
      .stroke(
        (selectedStudent != nil) ? Color.tmiSecondary.opacity(0.5) : Color.white.opacity(0.2),
        lineWidth: 1
      )
  }
  
  private var studentPickerMenu: some View {
    Menu {
      Button("Select Student for Recommendations") {
        showingStudentPicker = true
      }
      
      if selectedStudent != nil {
        Button("View Career Insights") {
          showingInsightsSheet = true
        }
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "person.circle")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
        if let student = selectedStudent {
          Text(student.name.components(separatedBy: " ").first ?? "Student")
            .font(.system(size: 12))
            .foregroundColor(.white)
        }
      }
      .frame(height: 36)
      .padding(.horizontal, 12)
      .background(studentPickerBackground)
      .overlay(studentPickerOverlay)
    }
  }
  
  private var filterButtonBackground: some View {
    Circle()
      .fill(
        hasActiveFilters
          ? Color.tmiSecondary.opacity(0.3)
          : Color.white.opacity(0.1)
      )
      .background(
        Circle()
          .fill(.ultraThinMaterial)
          .opacity(0.3)
      )
  }
  
  private var filterButtonOverlay: some View {
    Circle()
      .stroke(
        hasActiveFilters
          ? Color.tmiSecondary.opacity(0.5)
          : Color.white.opacity(0.2),
        lineWidth: 1
      )
  }
  
  private var filterButton: some View {
    Button(action: {
      isFilterSheetPresented = true
    }) {
      HStack(spacing: 6) {
        if hasActiveFilters {
          Text("\(activeFiltersCount)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Color.tmiSecondary))
        }

        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 36, height: 36)
          .background(filterButtonBackground)
          .overlay(filterButtonOverlay)
          .contentShape(Circle())
      }
    }
    .buttonStyle(.plain)
  }

  private var navigationView: some View {
    ZStack {
        // Animated background - using unified TMIBackgroundView
        TMIBackgroundView(variant: .career)
          .ignoresSafeArea()

        mainContent
      }
      .navigationTitle("Career Explorer")
      .navigationBarTitleDisplayMode(.large)
      .foregroundColor(.white)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          studentPickerMenu
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          filterButton
        }
      }
  }

  var body: some View {
    viewWithSheets
  }
  
  private var viewWithSheets: some View {
    navigationView
      .sheet(isPresented: $isFilterSheetPresented) {
        filterSheet
      }
      .sheet(isPresented: $showingStudentPicker) {
        studentPickerSheet
      }
      .sheet(isPresented: $showingInsightsSheet) {
        insightsSheet
      }
      .preferredColorScheme(.dark)
      .task {
        await loadCareerData()
      }
      .onAppear {
        performAppearAnimation()
      }
      .refreshable {
        await loadCareerData(forceRefresh: true)
      }
  }
  
  private var filterSheet: some View {
    EnhancedFilterSheet(
      salaryFilter: $salaryFilter,
      selectedSkills: $selectedSkills,
      allSkills: allSkills
    )
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(30)
  }
  
  private var studentPickerSheet: some View {
    StudentPickerSheet(
      selectedStudent: $selectedStudent,
      onStudentSelected: { student in
        selectedStudent = student
        showPersonalizedSection = true
        showingStudentPicker = false
        // Load personalized recommendations
        Task {
          // Load personalized recommendations based on student interests  
          personalizedRecommendations = Array(careers.prefix(5))
          
          // Generate simple insights - using placeholder data
          careerInsights = CareerDiscoveryInsights(
            totalCareersExplored: 5,
            personalizedRecommendations: 5,
            topInterestCategory: "Technology",
            strongestCareerFields: ["Technology", "Business"],
            emergingOpportunities: [],
            skillGaps: [],
            nextSteps: []
          )
        }
      }
    )
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
  
  @ViewBuilder
  private var insightsSheet: some View {
    if let insights = careerInsights {
      CareerInsightsSheet(insights: insights, student: selectedStudent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }
  
  private func performAppearAnimation() {
    // Animate elements sequentially when view appears
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      headerAppeared = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      searchAppeared = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      filtersAppeared = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      statsAppeared = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      animateCards = true
    }
  }

  // MARK: - Data Loading

  @MainActor
  private func loadCareerData(forceRefresh: Bool = false) async {
    isLoading = true
    error = nil

    do {
      async let careersLoad = careerService.fetchAllCareers(forceRefresh: forceRefresh)
      async let trendingLoad = careerService.fetchTrendingCareers()
      async let statisticsLoad = careerService.getCareerStatistics()

      careers = try await careersLoad
      trendingCareers = try await trendingLoad
      careerStatistics = try await statisticsLoad
      
      // Load personalized recommendations if student is selected
      if let student = selectedStudent {
        personalizedRecommendations = try await careerService.getCareerRecommendations(for: student)
        careerInsights = try await careerService.getCareerDiscoveryInsights(for: student)
        showPersonalizedSection = !personalizedRecommendations.isEmpty
      } else {
        showPersonalizedSection = false
        personalizedRecommendations = []
        careerInsights = nil
      }
    } catch {
      self.error = error
      // Fallback to sample data
      careers = Career.sampleCareers
      trendingCareers = Array(Career.sampleCareers.prefix(5))
      showPersonalizedSection = false
      personalizedRecommendations = []
      careerInsights = nil
    }

    isLoading = false
  }

  // MARK: - UI Components
  
  // MARK: - Personalized Recommendations Section
  
  private var personalizedRecommendationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "star.fill")
          .foregroundColor(.yellow)

        Text("For \((selectedStudent?.name.components(separatedBy: " ").first) ?? "You")")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.white)

        Spacer()

        Button("View Insights") {
          showingInsightsSheet = true
        }
        .font(.caption)
        .foregroundColor(.tmiSecondary)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(personalizedRecommendations.prefix(5), id: \.id) { career in
            NavigationLink(destination: CareerDetailView(career: career)) {
              PersonalizedCareerCard(career: career)
            }
          }
        }
        .padding(.horizontal, 20)
      }
      .padding(.horizontal, -20)
    }
    .padding(.bottom, 8)
  }

  // Loading view
  private var loadingView: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(1.5)
        .tint(.white)

      Text("Discovering careers...")
        .font(.headline)
        .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, 60)
  }

  // Trending careers section
  private var trendingCareersSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "flame.fill")
          .foregroundColor(.tmiSecondary)

        Text("Trending Careers")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.white)

        Spacer()

        Button("See All") {
          // Action to see all trending careers
        }
        .font(.caption)
        .foregroundColor(.tmiSecondary)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(trendingCareers, id: \.id) { career in
            NavigationLink(destination: CareerDetailView(career: career)) {
              TrendingCareerCard(career: career)
            }
          }
        }
        .padding(.horizontal, 20)
      }
      .padding(.horizontal, -20)
    }
    .padding(.bottom, 8)
  }

  // MARK: - Enhanced Search Bar

  private var enhancedSearchBar: some View {
    TMITextField(
      icon: "magnifyingglass",
      placeholder: "Search careers...",
      text: $searchText
    )
    .onChange(of: searchText) { _, newValue in
      // Perform real-time search
      if !newValue.isEmpty {
        Task {
          // Add debouncing for search
          try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
          if searchText == newValue {  // Check if search text hasn't changed
            // Could add live search results here
          }
        }
      }
    }
  }

  // MARK: - Enhanced Career Field Picker

  private var uniqueCareerFields: [String] {
    Array(Set(careers.map { $0.field })).sorted()
  }
  
  private var allFieldsButton: some View {
    TMIButton(
      text: "All Fields",
      icon: "square.grid.2x2.fill",
      style: .filter(isSelected: selectedField == nil),
      action: {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          selectedField = nil
        }
      }
    )
  }
  
  private var fieldButtons: some View {
    ForEach(uniqueCareerFields, id: \.self) { field in
      TMIButton(
        text: field,
        icon: getFieldIcon(field: field),
        style: .filter(isSelected: selectedField == field),
        action: {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedField = selectedField == field ? nil : field
          }
        }
      )
    }
  }

  private var enhancedCareerFieldPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        allFieldsButton
        fieldButtons
      }
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Enhanced Career Stats Summary

  private var enhancedCareerStatsSummary: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Exploring \(filteredCareers.count) careers")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)

          if let selectedField = selectedField {
            HStack(spacing: 6) {
              Image(systemName: getFieldIcon(field: selectedField))
                .font(.system(size: 14))
                .foregroundColor(Color.tmiSecondary)

              Text("Field: \(selectedField)")
                .font(.system(size: 14))
                .foregroundColor(Color.tmiSecondary)
            }
          }

          if !selectedSkills.isEmpty {
            HStack(spacing: 6) {
              Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.tmiSecondary)

              Text("Skills: \(selectedSkills.joined(separator: ", "))")
                .font(.system(size: 14))
                .foregroundColor(Color.tmiSecondary)
                .lineLimit(1)
            }
          }

          // Show additional statistics if available
          if let stats = careerStatistics {
            HStack(spacing: 16) {
              VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.uniqueFields)")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.white)
                Text("Fields")
                  .font(.system(size: 12))
                  .foregroundColor(.white.opacity(0.7))
              }

              VStack(alignment: .leading, spacing: 2) {
                Text("$\(Int(stats.averageSalary/1000))k")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.white)
                Text("Avg Salary")
                  .font(.system(size: 12))
                  .foregroundColor(.white.opacity(0.7))
              }

              VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.highGrowthCareers)")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.green)
                Text("High Growth")
                  .font(.system(size: 12))
                  .foregroundColor(.white.opacity(0.7))
              }
            }
            .padding(.top, 4)
          }
        }

        Spacer()

        // Salary range badge if filtered
        if salaryFilter.lowerBound > 30000 || salaryFilter.upperBound < 150000 {
          VStack(alignment: .center, spacing: 4) {
            Text("Salary Range")
              .font(.system(size: 12))
              .foregroundColor(.white.opacity(0.7))

            Text(
              "$\(Int(salaryFilter.lowerBound)/1000)k-$\(Int(salaryFilter.upperBound)/1000)k"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.tmiSecondary.opacity(0.2))
          )
        }
      }

      Divider()
        .background(Color.white.opacity(0.2))
        .padding(.vertical, 4)
    }
  }

  // MARK: - Enhanced Empty State View

  private var enhancedEmptyStateView: some View {
    VStack(spacing: 24) {
      // Animated empty state illustration
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [
                Color.tmiSecondary.opacity(0.3), Color.clear,
              ]),
              center: .center,
              startRadius: 1,
              endRadius: 100
            )
          )
          .frame(width: 180, height: 180)

        Image(systemName: "briefcase.fill")
          .font(.system(size: 60))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.top, 40)

      Text("No matching careers found")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)

      Text("Try adjusting your search terms or filters to explore more career options")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Button(action: {
        searchText = ""
        selectedField = nil
        selectedSkills = []
        salaryFilter = 30000...150000
      }) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 16, weight: .semibold))

          Text("Reset All Filters")
            .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
          LinearGradient(
            colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .foregroundColor(.white)
        .cornerRadius(14)
        .shadow(color: Color.tmiSecondary.opacity(0.4), radius: 8, x: 0, y: 4)
      }
      .buttonStyle(ScaleButtonStyle())
      .padding(.top, 10)

      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
  }

  // MARK: - Filtered Careers

  private var filteredCareers: [Career] {
    careers.filter { career in
      let matchesSearch =
        searchText.isEmpty || career.title.lowercased().contains(searchText.lowercased())
        || career.description.lowercased().contains(searchText.lowercased())
        || career.skills.contains { $0.lowercased().contains(searchText.lowercased()) }

      let matchesField = selectedField == nil || career.field == selectedField

      let matchesSalary = career.salaryRange.overlaps(salaryFilter)

      let matchesSkills =
        selectedSkills.isEmpty || !selectedSkills.isDisjoint(with: Set(career.skills))

      return matchesSearch && matchesField && matchesSalary && matchesSkills
    }
  }

  // MARK: - Filter State

  private var hasActiveFilters: Bool {
    selectedField != nil || !selectedSkills.isEmpty || salaryFilter.lowerBound > 30000
      || salaryFilter.upperBound < 150000
  }

  private var activeFiltersCount: Int {
    var count = 0
    if selectedField != nil { count += 1 }
    if !selectedSkills.isEmpty { count += 1 }
    if salaryFilter.lowerBound > 30000 || salaryFilter.upperBound < 150000 { count += 1 }
    return count
  }

  // MARK: - Helper Functions

  private func getFieldIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }
}

// MARK: - Premium Career Card

// MARK: - Career Card Header
struct CareerCardHeader: View {
  let field: String
  let title: String
  let iconName: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        // Field icon
        FieldIconView(iconName: iconName)

        Spacer()

        // Field badge
        FieldBadgeView(field: field)
      }

      // Career title
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(1)
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [Color.tmiSecondary.opacity(0.4), Color.tmiSecondary.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }
}

// MARK: - Field Icon View
struct FieldIconView: View {
  let iconName: String

  var body: some View {
    Image(systemName: iconName)
      .font(.system(size: 20))
      .foregroundColor(.white)
      .frame(width: 36, height: 36)
      .background(
        Circle()
          .fill(Color.tmiSecondary.opacity(0.3))
      )
  }
}

// MARK: - Field Badge View
struct FieldBadgeView: View {
  let field: String

  var body: some View {
    Text(field)
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(.white.opacity(0.8))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.1))
      )
  }
}

// MARK: - Career Description View
struct CareerDescriptionView: View {
  let description: String

  var body: some View {
    Text(description)
      .font(.system(size: 13))
      .foregroundColor(.white.opacity(0.8))
      .lineLimit(3)
      .frame(height: 60, alignment: .top)
  }
}

// MARK: - Career Skills View
struct CareerSkillsView: View {
  let skills: [String]

  var body: some View {
    if !skills.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(skills.prefix(3), id: \.self) { skill in
            SkillBadgeView(skill: skill)
          }

          if skills.count > 3 {
            SkillBadgeView(skill: "+\(skills.count - 3)")
          }
        }
      }
    }
  }
}

// MARK: - Skill Badge View
struct SkillBadgeView: View {
  let skill: String

  var body: some View {
    Text(skill)
      .font(.system(size: 11))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.1))
      )
      .foregroundColor(.white.opacity(0.9))
  }
}

// MARK: - Salary View
struct SalaryView: View {
  let salaryRange: ClosedRange<Double>

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "dollarsign.circle")
        .font(.system(size: 11))

      Text("$\(salaryRange.lowerBound/1000)k - $\(salaryRange.upperBound/1000)k")
        .font(.system(size: 12, weight: .medium))
    }
    .foregroundColor(.white.opacity(0.8))
  }
}

// MARK: - Growth Badge View
struct GrowthBadgeView: View {
  let jobOutlook: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: getGrowthIcon(outlook: jobOutlook))
        .font(.system(size: 11))

      Text(getGrowthCategory(outlook: jobOutlook))
        .font(.system(size: 12, weight: .medium))
    }
    .foregroundColor(getGrowthColor(outlook: jobOutlook))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(getGrowthColor(outlook: jobOutlook).opacity(0.2))
    )
  }

  // Helper functions
  private func getGrowthCategory(outlook: String) -> String {
    if outlook.contains("rapid") || outlook.contains("fast") {
      return "High Growth"
    } else if outlook.contains("steady") || outlook.contains("stable") {
      return "Stable"
    } else if outlook.contains("decline") || outlook.contains("slow") {
      return "Limited"
    } else {
      return "Moderate"
    }
  }

  private func getGrowthIcon(outlook: String) -> String {
    if outlook.contains("rapid") || outlook.contains("fast") {
      return "arrow.up.right"
    } else if outlook.contains("steady") || outlook.contains("stable") {
      return "arrow.right"
    } else if outlook.contains("decline") || outlook.contains("slow") {
      return "arrow.down.right"
    } else {
      return "arrow.right"
    }
  }

  private func getGrowthColor(outlook: String) -> Color {
    if outlook.contains("rapid") || outlook.contains("fast") {
      return .green
    } else if outlook.contains("steady") || outlook.contains("stable") {
      return .blue
    } else if outlook.contains("decline") || outlook.contains("slow") {
      return .red
    } else {
      return .orange
    }
  }
}

// MARK: - Career Card Content
struct CareerCardContent: View {
  let career: Career

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Description
      CareerDescriptionView(description: career.description)

      // Skills preview
      CareerSkillsView(skills: career.skills)

      Divider()
        .background(Color.white.opacity(0.2))

      // Salary and growth
      HStack(alignment: .center) {
        SalaryView(salaryRange: career.salaryRange)

        Spacer()

        // Growth badge
        GrowthBadgeView(jobOutlook: career.jobOutlook)
      }
    }
    .padding(16)
    .background(Color.clear)
  }
}

// MARK: - Career Card Background
struct CareerCardBackground: View {
  let isHovered: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color.white.opacity(0.05))
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(.ultraThinMaterial)
          .opacity(0.7)
      )
      .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
          )
      )
      .scaleEffect(isHovered ? 1.03 : 1.0)
      .shadow(
        color: isHovered ? Color.tmiSecondary.opacity(0.3) : Color.clear, radius: 10, x: 0,
        y: 5
      )
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
  }
}

// MARK: - Refactored Premium Career Card
struct PremiumCareerCard: View {
  let career: Career
  @State private var isHovered = false

  var body: some View {
    ZStack {
      // Background
      CareerCardBackground(isHovered: isHovered)

      // Content
      VStack(alignment: .leading, spacing: 0) {
        // Header
        CareerCardHeader(
          field: career.field,
          title: career.title,
          iconName: getCareerIcon(field: career.field)
        )

        // Details
        CareerCardContent(career: career)
      }
    }
    .onHover { hovering in
      isHovered = hovering
    }
  }

  // Helper function for career icon
  private func getCareerIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }
}

// MARK: - Enhanced Filter Sheet

// MARK: - Section Header
struct FilterSectionHeader: View {
  let title: String
  let iconName: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: iconName)
        .font(.system(size: 18))
        .foregroundColor(.white)

      Text(title)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)
    }
  }
}

// MARK: - Salary Range Display
struct SalaryRangeDisplay: View {
  let lowerBound: Double
  let upperBound: Double

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Min")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.6))

        Text("$\(Int(lowerBound))")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text("Max")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.6))

        Text("$\(Int(upperBound))")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
      }
    }
  }
}

// MARK: - Filter Section Container
struct FilterSectionContainer<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
  }
}

// MARK: - Skill Selection Button
struct SkillSelectionButton: View {
  let skill: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(skill)
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
        .background(
          RoundedRectangle(cornerRadius: 18)
            .fill(
              isSelected
                ? LinearGradient(
                  colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
                : LinearGradient(
                  colors: [Color.white.opacity(0.05)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
            )
            .background(
              isSelected
                ? RoundedRectangle(cornerRadius: 18)
                  .fill(.ultraThinMaterial)
                  .opacity(0)
                : RoundedRectangle(cornerRadius: 18)
                  .fill(.ultraThinMaterial)
                  .opacity(0.1)
            )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .stroke(
              isSelected
                ? LinearGradient(
                  colors: [Color.clear],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
                : LinearGradient(
                  colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
              lineWidth: 1
            )
        )
        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
    }
    .buttonStyle(ScaleButtonStyle())
  }
}

// MARK: - Filter Action Button
struct FilterActionButton: View {
  let title: String
  let iconName: String?
  let isPrimary: Bool
  let action: () -> Void

  init(
    title: String, iconName: String? = nil, isPrimary: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.iconName = iconName
    self.isPrimary = isPrimary
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let iconName = iconName {
          Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
        }

        Text(title)
          .font(.system(size: 16, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        Group {
          if isPrimary {
            LinearGradient(
              colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            .cornerRadius(16)
          } else {
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.white.opacity(0.3), lineWidth: 1)
              .background(Color.clear)
          }
        }
      )
      .foregroundColor(.white)
      .cornerRadius(isPrimary ? 16 : 0)
      .shadow(
        color: isPrimary ? Color.tmiSecondary.opacity(0.4) : Color.clear, radius: 8, x: 0,
        y: 4)
    }
    .buttonStyle(ScaleButtonStyle())
  }
}

// MARK: - Salary Range Section
struct SalaryRangeSection: View {
  @Binding var salaryFilter: ClosedRange<Double>

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      FilterSectionHeader(title: "Salary Range", iconName: "dollarsign.circle.fill")

      FilterSectionContainer {
        VStack(spacing: 12) {
          SalaryRangeDisplay(
            lowerBound: salaryFilter.lowerBound,
            upperBound: salaryFilter.upperBound
          )

          EnhancedRangeSlider(range: $salaryFilter, bounds: 20000...200000)
            .frame(height: 40)
        }
      }
    }
  }
}

// MARK: - Skills Selection Section
struct SkillsSelectionSection: View {
  @Binding var selectedSkills: Set<String>
  let allSkills: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      FilterSectionHeader(title: "Skills", iconName: "star.fill")

      FilterSectionContainer {
        SkillsSelectionGrid(skills: allSkills, selectedSkills: $selectedSkills)
      }
    }
  }
}

// MARK: - Filter Background
struct FilterBackground: View {
  var body: some View {
    LinearGradient(
      gradient: Gradient(colors: [
        Color(red: 0.08, green: 0.08, blue: 0.15),
        Color(red: 0.14, green: 0.14, blue: 0.25),
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

struct EnhancedFilterSheet: View {
  @Binding var salaryFilter: ClosedRange<Double>
  @Binding var selectedSkills: Set<String>
  var allSkills: [String]

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        // Background
        FilterBackground()

        // Content
        ScrollView {
          VStack(spacing: 24) {
            // Salary range section
            SalaryRangeSection(salaryFilter: $salaryFilter)

            // Skills section
            SkillsSelectionSection(
              selectedSkills: $selectedSkills,
              allSkills: allSkills
            )

            // Reset button
            FilterActionButton(
              title: "Reset All Filters",
              iconName: "arrow.counterclockwise",
              isPrimary: false,
              action: {
                withAnimation {
                  salaryFilter = 30000...150000
                  selectedSkills = []
                }
              }
            )

            // Apply button
            FilterActionButton(
              title: "Apply Filters",
              isPrimary: true,
              action: {
                dismiss()
              }
            )
          }
          .padding(24)
        }
      }
      .navigationTitle("Filter Careers")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}

// MARK: - Slider Components

struct SliderTrackBackground: View {
  var body: some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [Color.white.opacity(0.1), Color.white.opacity(0.2)],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(height: 6)
  }
}

struct SliderSelectedTrack: View {
  let width: CGFloat
  let offsetX: CGFloat

  var body: some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: width, height: 6)
      .offset(x: offsetX)
  }
}

struct SliderThumb: View {
  let isActive: Bool
  let position: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.white.opacity(0.05))
        .frame(width: 24, height: 24)
        .background(
          Circle()
            .fill(.ultraThinMaterial)
            .opacity(0.9)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)

      Circle()
        .fill(isActive ? Color.tmiSecondary : Color.white)
        .frame(width: 12, height: 12)
    }
    .overlay(
      Circle()
        .stroke(Color.white.opacity(0.5), lineWidth: 1)
        .frame(width: 24, height: 24)
    )
    .scaleEffect(isActive ? 1.2 : 1.0)
    .offset(x: position)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
  }
}
// MARK: - Skills Grid
struct SkillsSelectionGrid: View {
  let skills: [String]
  @Binding var selectedSkills: Set<String>

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
      ForEach(skills, id: \.self) { skill in
        SkillSelectionButton(
          skill: skill,
          isSelected: selectedSkills.contains(skill),
          action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              if selectedSkills.contains(skill) {
                selectedSkills.remove(skill)
              } else {
                selectedSkills.insert(skill)
              }
            }
          }
        )
      }
    }
  }
}

struct SalaryAndGrowthRow: View {
  let career: Career

  var body: some View {
    HStack(spacing: 16) {
      // Salary information
      VStack(alignment: .leading, spacing: 4) {
        Text("Salary")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.6))

        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text("$\(Int(career.salaryRange.lowerBound)/1000)k")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)

          Text("-")
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.7))

          Text("$\(Int(career.salaryRange.upperBound)/1000)k")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Divider
      Rectangle()
        .fill(Color.white.opacity(0.2))
        .frame(width: 1, height: 30)

      // Growth information
      VStack(alignment: .leading, spacing: 4) {
        Text("Growth")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.6))

        HStack(spacing: 4) {
          Text("\(Int(career.growthRate * 100))%")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(growthColor(rate: career.growthRate))

          Image(systemName: growthIcon(rate: career.growthRate))
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(growthColor(rate: career.growthRate))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // Helper functions to determine growth color and icon
  private func growthColor(rate: Double) -> Color {
    if rate >= 0.1 {
      return .green
    } else if rate >= 0 {
      return .yellow
    } else {
      return .red
    }
  }

  private func growthIcon(rate: Double) -> String {
    if rate >= 0.1 {
      return "arrow.up.right"
    } else if rate >= 0 {
      return "arrow.right"
    } else {
      return "arrow.down.right"
    }
  }
}

// MARK: - Enhanced Range Slider

struct EnhancedRangeSlider: View {
  @Binding var range: ClosedRange<Double>
  let bounds: ClosedRange<Double>

  @State private var lowerThumbIsActive = false
  @State private var upperThumbIsActive = false

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Track background
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.1), Color.white.opacity(0.2)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(height: 6)

        // Selected range track
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: width(in: geometry), height: 6)
          .offset(x: offsetX(in: geometry))

        // Lower thumb
        ZStack {
          Circle()
            .fill(Color.white.opacity(0.05))
            .frame(width: 24, height: 24)
            .background(
              Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.9)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)

          Circle()
            .fill(lowerThumbIsActive ? Color.tmiSecondary : Color.white)
            .frame(width: 12, height: 12)
        }
        .overlay(
          Circle()
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
            .frame(width: 24, height: 24)
        )
        .scaleEffect(lowerThumbIsActive ? 1.2 : 1.0)
        .offset(x: lowerThumbPosition(in: geometry) - 12)
        .gesture(
          DragGesture()
            .onChanged { value in
              lowerThumbIsActive = true
              updateLowerBound(value: value, in: geometry)
            }
            .onEnded { _ in
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                lowerThumbIsActive = false
              }
            }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lowerThumbIsActive)

        // Upper thumb
        ZStack {
          Circle()
            .fill(Color.white.opacity(0.05))
            .frame(width: 24, height: 24)
            .background(
              Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.9)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)

          Circle()
            .fill(upperThumbIsActive ? Color.tmiSecondary : Color.white)
            .frame(width: 12, height: 12)
        }
        .overlay(
          Circle()
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
            .frame(width: 24, height: 24)
        )
        .scaleEffect(upperThumbIsActive ? 1.2 : 1.0)
        .offset(x: upperThumbPosition(in: geometry) - 12)
        .gesture(
          DragGesture()
            .onChanged { value in
              upperThumbIsActive = true
              updateUpperBound(value: value, in: geometry)
            }
            .onEnded { _ in
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                upperThumbIsActive = false
              }
            }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: upperThumbIsActive)
      }
      .frame(height: 24)
      .padding(.horizontal, 12)
    }
  }

  private func lowerThumbPosition(in geometry: GeometryProxy) -> CGFloat {
    let position =
      (range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
    return position * geometry.size.width
  }

  private func upperThumbPosition(in geometry: GeometryProxy) -> CGFloat {
    let position =
      (range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
    return position * geometry.size.width
  }

  private func offsetX(in geometry: GeometryProxy) -> CGFloat {
    lowerThumbPosition(in: geometry)
  }

  private func width(in geometry: GeometryProxy) -> CGFloat {
    upperThumbPosition(in: geometry) - lowerThumbPosition(in: geometry)
  }

  private func updateLowerBound(value: DragGesture.Value, in geometry: GeometryProxy) {
    let ratio = value.location.x / geometry.size.width
    let newLowerBound = bounds.lowerBound + ratio * (bounds.upperBound - bounds.lowerBound)

    // Ensure the lower bound doesn't exceed the upper bound and stays within bounds
    if newLowerBound < range.upperBound - 10000 && newLowerBound >= bounds.lowerBound {
      range = max(newLowerBound, bounds.lowerBound)...range.upperBound
    }
  }

  private func updateUpperBound(value: DragGesture.Value, in geometry: GeometryProxy) {
    let ratio = value.location.x / geometry.size.width
    let newUpperBound = bounds.lowerBound + ratio * (bounds.upperBound - bounds.lowerBound)

    // Ensure the upper bound doesn't go below the lower bound and stays within bounds
    if newUpperBound > range.lowerBound + 10000 && newUpperBound <= bounds.upperBound {
      range = range.lowerBound...min(newUpperBound, bounds.upperBound)
    }
  }
}

// MARK: - Trending Career Card

struct TrendingCareerCard: View {
  let career: Career

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: getFieldIcon(field: career.field))
          .font(.system(size: 16))
          .foregroundColor(.tmiSecondary)

        Spacer()

        // Growth indicator
        HStack(spacing: 4) {
          Image(systemName: "arrow.up.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.green)

          Text("+\(Int(career.growthRate * 100))%")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          Capsule()
            .fill(Color.green.opacity(0.1))
        )
      }

      Text(career.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      Text(career.field)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))

      HStack {
        Text("$\(Int(career.salaryRange.lowerBound/1000))k+")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.tmiSecondary)

        Spacer()

        Image(systemName: "arrow.right")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.5))
      }
    }
    .padding(12)
    .frame(width: 140, height: 120)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.8)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    )
  }

  private func getFieldIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }
}

// MARK: - Personalized Career Card

struct PersonalizedCareerCard: View {
  let career: Career
  @State private var isHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: getFieldIcon(field: career.field))
          .font(.system(size: 16))
          .foregroundColor(.tmiSecondary)

        Spacer()

        // Personalization indicator
        HStack(spacing: 4) {
          Image(systemName: "star.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.yellow)

          Text("Match")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.yellow)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          Capsule()
            .fill(Color.yellow.opacity(0.1))
        )
      }

      Text(career.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      Text(career.field)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))

      HStack {
        Text("$\(Int(career.salaryRange.lowerBound/1000))k+")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.tmiSecondary)

        Spacer()

        Image(systemName: "arrow.right")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.5))
      }
    }
    .padding(12)
    .frame(width: 140, height: 120)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.8)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.clear, Color.yellow.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    )
    .scaleEffect(isHovered ? 1.05 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private func getFieldIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }
}

// MARK: - Student Picker Sheet

struct StudentPickerSheet: View {
  @Binding var selectedStudent: Student?
  let onStudentSelected: (Student) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var studentService = StudentService()
  @State private var students: [Student] = []
  @State private var isLoading = false
  
  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .default)
        
        if isLoading {
          VStack {
            ProgressView()
              .scaleEffect(1.5)
              .foregroundColor(.white)
            Text("Loading Students...")
              .foregroundColor(.white.opacity(0.7))
              .padding(.top)
          }
        } else if students.isEmpty {
          VStack(spacing: 20) {
            Image(systemName: "person.3")
              .font(.system(size: 50))
              .foregroundColor(.white.opacity(0.3))
            
            Text("No Students Available")
              .font(.title2)
              .foregroundColor(.white)
            
            Text("Add students first to get personalized career recommendations")
              .font(.body)
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(students) { student in
                Button {
                  onStudentSelected(student)
                } label: {
                  HStack {
                    VStack(alignment: .leading) {
                      Text(student.name)
                        .font(.headline)
                        .foregroundColor(.white)
                      Text(student.grade)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle")
                      .foregroundColor(.tmiSecondary)
                  }
                  .padding()
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(Color.white.opacity(0.1))
                  )
                }
                .buttonStyle(ScaleButtonStyle())
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle("Select Student")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
    .task {
      isLoading = true
      do {
        students = try await studentService.fetchStudents()
      } catch {
        print("Failed to load students: \(error)")
      }
      isLoading = false
    }
  }
}

// MARK: - Career Insights Sheet

struct CareerInsightsSheet: View {
  let insights: CareerDiscoveryInsights
  let student: Student?
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .career)
        
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Header
            if let student = student {
              VStack(alignment: .leading, spacing: 8) {
                Text("Career Insights for \(student.name)")
                  .font(.title2.bold())
                  .foregroundColor(.white)
                
                Text("Based on interests and personality assessment")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.7))
              }
              .padding(.horizontal)
            }
            
            // Stats
            VStack(spacing: 16) {
              HStack {
                InsightCard(
                  title: "Careers Explored",
                  value: "\(insights.totalCareersExplored)",
                  icon: "briefcase"
                )
                
                InsightCard(
                  title: "Recommendations",
                  value: "\(insights.personalizedRecommendations)",
                  icon: "star.circle"
                )
              }
              
              if !insights.strongestCareerFields.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                  Text("Top Career Fields")
                    .font(.headline)
                    .foregroundColor(.white)
                  
                  LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                  ], spacing: 8) {
                    ForEach(insights.strongestCareerFields, id: \.self) { field in
                      Text(field)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                          Capsule()
                            .fill(Color.tmiSecondary.opacity(0.2))
                        )
                        .foregroundColor(.tmiSecondary)
                    }
                  }
                }
                .padding(.horizontal)
              }
            }
            .padding(.horizontal)
          }
          .padding(.bottom, 40)
        }
      }
      .navigationTitle("Career Insights")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}

// MARK: - Insight Card

struct InsightCard: View {
  let title: String
  let value: String
  let icon: String
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(.tmiSecondary)
      
      Text(value)
        .font(.title.bold())
        .foregroundColor(.white)
      
      Text(title)
        .font(.caption)
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.1))
    )
  }
}

// MARK: - Preview

#Preview {
  CareerExplorerView()
}

