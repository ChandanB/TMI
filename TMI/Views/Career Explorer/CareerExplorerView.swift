import SwiftUI
import Foundation

struct CareerExplorerView: View {
  @Environment(\.careerExplorerStateModel) private var stateModel
  @Environment(\.studentContext) private var studentContext
  @Environment(\.studentAccessMode) private var accessMode

  // Animation states
  @State private var headerAppeared = false
  @State private var searchBoxAppeared = false
  @State private var resultsAppeared = false
  @State private var showingSuggestions = false
  @State private var showingStudentPicker = false
  // Legacy animation states (mapped to new ones or kept if needed)
  @State private var searchAppeared = false
  @State private var filtersAppeared = false
  @State private var statsAppeared = false
  @State private var animateCards = false

  @State private var lastSearchQuery = ""
  @State private var searchSuggestions: [String] = [
    "Software Engineer", "Nurse", "Teacher", "Doctor", "Designer",
    "Technology", "Healthcare", "Education", "Business", "Arts",
    "Biology", "Mathematics", "Psychology", "Computer Science", "Art"
  ]

  // Context awareness
  private var isStudentContext: Bool {
    studentContext.hasActiveStudent
  }

  private var contextCareerState: StudentCareerState? {
    studentContext.prefetchedCareerState
  }

  private var canBookmark: Bool {
    StudentAccessPolicy.canBookmarkCareers(in: accessMode)
  }

  // Computed properties mapping to StateModel
  private var searchText: String {
      get { stateModel.searchText }
      nonmutating set { stateModel.searchText = newValue }
  }

  private var searchTextBinding: Binding<String> {
      Binding(get: { stateModel.searchText }, set: { stateModel.searchText = $0 })
  }

  private var searchResults: [Career] { stateModel.searchResults }
  private var hasSearched: Bool { stateModel.hasSearched }
  private var isSearching: Bool { stateModel.isSearching }
  private var selectedStudent: Student? { stateModel.selectedStudent }
  private var personalizedRecommendations: [Career] { stateModel.personalizedRecommendations }
  private var trendingCareers: [Career] { stateModel.trendingCareers }

  // Wrappers for direct service access if needed, though mostly StateModel should handle
  private var careerService: CareerService { CareerService.shared }

  // Legacy/Compatibility stubs
  private var careers: [Career] { stateModel.careers }
  private var filteredCareers: [Career] { stateModel.filteredCareers }
  private var selectedField: String? { stateModel.selectedField }
  @State private var selectedSkills: Set<String> = []
  private var careerStatistics: CareerStatistics? { nil }
  private var isLoading: Bool { stateModel.isLoading }
  private var error: Error? { stateModel.error }
  private var showPersonalizedSection: Bool { stateModel.showPersonalizedSection }
  private var showTrendingSection: Bool { true }
  private var hasActiveFilters: Bool { stateModel.hasActiveFilters }
  private var activeFiltersCount: Int { hasActiveFilters ? 1 : 0 }

  // Get all unique skills across careers
  private var allSkills: [String] {
    Array(Set(careers.flatMap { $0.skills })).sorted()
  }
  
  // Simplified body for search-first interface
  private var legacyCareerContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if isLoading {
          loadingView
        } else if !filteredCareers.isEmpty {
          careerContent
        } else {
          enhancedEmptyStateView
        }
      }
      .padding(20)
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
      ForEach(Array(filteredCareers.enumerated()), id: \.element.id) { index, career in
        NavigationLink(
          destination: CareerDetailView(career: career, student: selectedStudent)
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

  // Remove legacy student picker styling
  
  // Remove legacy student picker menu
  
  // Remove legacy filter button styling
  
  // Remove legacy filter button

  // Remove legacy navigation view

  var body: some View {
    ZStack {
      // Background
      TMIBackgroundView(variant: .career)
        .ignoresSafeArea()
      
      if !hasSearched {
        // Initial search-focused view
        searchHomeView
      } else {
        // Results view
        searchResultsView
      }
    }
    .navigationTitle("Career Explorer")
    .navigationBarTitleDisplayMode(.large)
    .foregroundColor(.white)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        studentPickerButton
      }
      
      if hasSearched {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("New Search") {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
              resetSearch()
            }
          }
          .foregroundColor(.white)
        }
      }
    }
    .sheet(isPresented: $showingStudentPicker) {
      studentPickerSheet
    }
    .preferredColorScheme(.dark)
    .onAppear {
      performInitialAnimation()
      stateModel.fetch()
    }
  }
  
  // MARK: - Search Home View
  
  private var searchHomeView: some View {
    VStack(spacing: 0) {
      Spacer()
      
      VStack(spacing: 40) {
        // Header
        VStack(spacing: 16) {
          Text("Discover Your Career Path")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : -20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: headerAppeared)
          
          Text("Search for any career, field, or subject to explore your options")
            .font(.system(size: 18))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .opacity(headerAppeared ? 1 : 0)
            .offset(y: headerAppeared ? 0 : -15)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: headerAppeared)
        }
        .padding(.horizontal, 40)
        
        // Main search box
        VStack(spacing: 20) {
          ZStack {
            RoundedRectangle(cornerRadius: 24)
              .fill(Color.white.opacity(0.1))
              .background(
                RoundedRectangle(cornerRadius: 24)
                  .fill(.ultraThinMaterial)
                  .opacity(0.6)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 24)
                  .stroke(
                    LinearGradient(
                      colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                  )
              )
              .frame(height: 60)
            
            HStack(spacing: 16) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.7))
              
              TextField("Search careers, fields, or subjects...", text: searchTextBinding)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .onSubmit {
                  performSearch()
                }
                .onTapGesture {
                  showingSuggestions = true
                }
              
              if isSearching {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              } else if !searchText.isEmpty {
                Button(action: performSearch) {
                  Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.tmiSecondary)
                }
                .buttonStyle(ScaleButtonStyle())
              }
            }
            .padding(.horizontal, 20)
          }
          .opacity(searchBoxAppeared ? 1 : 0)
          .offset(y: searchBoxAppeared ? 0 : 30)
          .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: searchBoxAppeared)
          
          // Search suggestions
          if showingSuggestions && searchText.isEmpty {
            searchSuggestionsView
              .transition(.move(edge: .top).combined(with: .opacity))
          }
        }
        .padding(.horizontal, 30)
      }
      
      Spacer()
      Spacer()
    }
  }
  
  // MARK: - Search Results View
  
  private var searchResultsView: some View {
    VStack(spacing: 0) {
      // Search bar at top
      VStack(spacing: 16) {
        HStack(spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 16)
              .fill(Color.white.opacity(0.1))
              .background(
                RoundedRectangle(cornerRadius: 16)
                  .fill(.ultraThinMaterial)
                  .opacity(0.3)
              )
              .frame(height: 44)
            
            HStack(spacing: 12) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
              
              TextField("Search careers...", text: searchTextBinding)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .onSubmit {
                  performSearch()
                }
              
              if isSearching {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.7)
              }
            }
            .padding(.horizontal, 16)
          }
          
          Button("Search") {
            performSearch()
          }
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(
            LinearGradient(
              colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .foregroundColor(.white)
          .cornerRadius(16)
          .disabled(isSearching)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        
        // Results header
        if !searchResults.isEmpty {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Results for \"\(lastSearchQuery)\"")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

              Text("\(searchResults.count) careers found")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
          }
          .padding(.horizontal, 20)
        }
      }
      
      // Results content
      if isSearching {
        Spacer()
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
          Text("Loading careers for \"\(searchText)\"...")
            .font(.headline)
            .foregroundColor(.white)
        }
        Spacer()
      } else if searchResults.isEmpty && hasSearched {
        emptySearchResults
      } else {
        ScrollView {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 170), spacing: 16)],
            spacing: 20
          ) {
            ForEach(searchResults, id: \.id) { career in
                NavigationLink(destination: CareerDetailView(career: career, student: selectedStudent)) {
                  PremiumCareerCard(career: career)
                    .opacity(resultsAppeared ? 1 : 0)
                    .offset(y: resultsAppeared ? 0 : 20)
                    .animation(
                      .spring(response: 0.4, dampingFraction: 0.7)
                        // Use a safe index calculation or just a fixed delay if index isn't available
                        .delay(Double(searchResults.firstIndex(where: { $0.id == career.id }) ?? 0) * 0.05),
                      value: resultsAppeared
                    )
                }
                .buttonStyle(PlainButtonStyle())
              }
          }
          .padding(20)
          .padding(.bottom, 80)
        }
      }
    }
  }
  
  // MARK: - Supporting Views
  
  private var searchSuggestionsView: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Popular Searches")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 20)
      
      LazyVGrid(columns: [
        GridItem(.adaptive(minimum: 140), spacing: 8)
      ], spacing: 8) {
        ForEach(searchSuggestions, id: \.self) { suggestion in
          Button(action: {
            searchText = suggestion
            showingSuggestions = false
            performSearch()
          }) {
            Text(suggestion)
              .font(.system(size: 14))
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.white.opacity(0.1))
              )
              .foregroundColor(.white.opacity(0.9))
          }
          .buttonStyle(ScaleButtonStyle())
        }
      }
      .padding(.horizontal, 20)
    }
    .padding(.vertical, 16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.3)
        )
    )
    .padding(.horizontal, 30)
  }
  
  private var emptySearchResults: some View {
    VStack(spacing: 24) {
      Spacer()
      
      Image(systemName: "magnifyingglass")
        .font(.system(size: 60))
        .foregroundColor(.white.opacity(0.5))
      
      Text("No careers found")
        .font(.system(size: 22, weight: .semibold))
        .foregroundColor(.white)
      
      Text("Try searching for a different career, field, or subject")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      
      Button("Try Again") {
        searchText = ""
        showingSuggestions = true
      }
      .font(.system(size: 16, weight: .semibold))
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
      .background(
        LinearGradient(
          colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundColor(.white)
      .cornerRadius(14)
      
      Spacer()
    }
  }
  
  private var studentPickerButton: some View {
    Button {
      showingStudentPicker = true
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
      .background(
        RoundedRectangle(cornerRadius: 18)
          .fill((selectedStudent != nil) ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.1))
          .background(
            RoundedRectangle(cornerRadius: 18)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            (selectedStudent != nil) ? Color.tmiSecondary.opacity(0.5) : Color.white.opacity(0.2),
            lineWidth: 1
          )
      )
    }
  }
  
  // MARK: - Actions
  
  private func performSearch() {
    stateModel.performSearch()
    withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
      resultsAppeared = true
    }
  }
  
  private func resetSearch() {
    stateModel.clearSearch()
    resultsAppeared = false
    showingSuggestions = false
  }
  
  private func performInitialAnimation() {
    withAnimation(.easeInOut(duration: 0.6).delay(0.1)) {
      headerAppeared = true
    }
    
    withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
      searchBoxAppeared = true
    }
  }
  
  // Remove legacy view with sheets
  
  // Remove legacy filter sheet
  
  private var studentPickerSheet: some View {
    StudentPickerSheet(
      selectedStudent: Binding(get: { stateModel.selectedStudent }, set: { stateModel.selectedStudent = $0 }),
      onStudentSelected: { student in
        stateModel.selectedStudent = student
        showingStudentPicker = false
        stateModel.loadPersonalizedRecommendations()
      }
    )
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
  
  // Remove legacy insights sheet
  
  // Remove legacy animation function

  // MARK: - Data Loading (simplified for search-first interface)
  
  @MainActor
  private func loadBasicCareerData() async {
    // Legacy data loading is now handled by stateModel.fetch() called in .task()
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
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(personalizedRecommendations.prefix(5), id: \.id) { career in
            NavigationLink(destination: CareerDetailView(career: career, student: selectedStudent)) {
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

      Text("Loading careers...")
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
            NavigationLink(destination: CareerDetailView(career: career, student: selectedStudent)) {
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
      text: searchTextBinding
    )
    .onChange(of: stateModel.searchText) { newValue in
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
          stateModel.selectedField = nil
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
            stateModel.selectedField = stateModel.selectedField == field ? nil : field
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
        stateModel.selectedField = nil
        selectedSkills = []
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

          RangeSlider(range: $salaryFilter, bounds: 20000...200000)
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

struct FilterSheet: View {
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

// MARK: - Range Slider

struct RangeSlider: View {
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


// MARK: - Preview

#Preview {
  CareerExplorerView()
}

