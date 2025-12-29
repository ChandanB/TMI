import FirebaseFirestore
import SwiftUI

// MARK: - Models

// Resource struct moved to Models/Resource.swift

// MARK: - Main View

struct ResourcesView: View {
  // State Model
  @State private var stateModel = ResourcesStateModel()
  
  // Student integration
  @State private var selectedStudent: Student?
  @State private var studentRecommendations: [Resource] = []
  @State private var showStudentRecommendations = false
  @State private var showingStudentPicker = false
  @State private var showingAllRecommendations = false
  
  // Animation states
  @State private var isLoaded = false

  private var showSearchBar: Bool { true }

  // Break up the complex body to fix compiler timeout
  private var mainContent: some View {
    VStack(spacing: 0) {
      // Search bar - appears when scrolled
      if showSearchBar {
        searchBarView
          .transition(.move(edge: .top).combined(with: .opacity))
      }

      // Scrollable content
      scrollableContent
    }
  }
  
  private var scrollableContent: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Student recommendations section
        if showStudentRecommendations && selectedStudent != nil {
          studentRecommendationsSection
            .opacity(isLoaded ? 1 : 0)
            .offset(y: isLoaded ? 0 : 20)
            .animation(
              .spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: isLoaded)
        }
        
        // Featured resources section
        if hasFeaturedResources {
          featuredResourcesSection
            .opacity(isLoaded ? 1 : 0)
            .offset(y: isLoaded ? 0 : 20)
            .animation(
              .spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isLoaded)
        }

        // Category filter
        categoryPickerView
          .padding(.horizontal, 20)
          .opacity(isLoaded ? 1 : 0)
          .offset(y: isLoaded ? 0 : 20)
          .animation(
            .spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: isLoaded)

        // Resources grid
        resourcesContentView
      }
      .padding(.top, 20)
    }
    .coordinateSpace(name: "scroll")
    .safeAreaInset(
      edge: .top,
      content: {
        searchBarView
          .opacity(showSearchBar ? 0 : 1)
      })
  }
  
  private var resourcesContentView: some View {
    Group {
      if stateModel.filteredResources.isEmpty {
        emptyStateView
          .opacity(isLoaded ? 1 : 0)
          .offset(y: isLoaded ? 0 : 30)
          .animation(
            .spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: isLoaded)
      } else {
        resourcesGridView
      }
    }
  }
  
  private var floatingAddButton: some View {
    VStack {
      Spacer()

      HStack {
        Spacer()

        TMIButton(
          text: "plus",
          style: .floating,
          action: { stateModel.showingAddResource = true }
        )
        .padding(24)
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 100)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isLoaded)
      }
    }
  }
  
  private var studentPickerButton: some View {
    Menu {
      Button("Select Student for Recommendations") {
        showingStudentPicker = true
      }
      
      if selectedStudent != nil {
        Button("View All Recommendations") {
          showingAllRecommendations = true
        }
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "person.circle")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
        if selectedStudent != nil {
          Text((selectedStudent?.name.components(separatedBy: " ").first) ?? "Student")
            .font(.system(size: 12))
            .foregroundColor(.white)
        }
      }
      .frame(height: 36)
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 18)
          .fill(selectedStudent != nil ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.1))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            selectedStudent != nil ? Color.tmiSecondary.opacity(0.5) : Color.white.opacity(0.2),
            lineWidth: 1
          )
      )
    }
  }

  var body: some View {
    ZStack {
      // Background
      resourceBackgroundView

      ZStack {
        // Main content
        mainContent

        // Floating Add Button
        floatingAddButton
      }
      .navigationTitle("Resource Library")
      .foregroundColor(.white)
      .navigationBarTitleDisplayMode(.large)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          studentPickerButton
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button(action: {
              stateModel.showingAddResource = true
            }) {
                Image(systemName: "plus")
            }

            Button(action: {
              // Implement import function
            }) {
              Label("Import Resources", systemImage: "square.and.arrow.down")
            }

            Button(action: {
              // Implement filtering options
            }) {
              Label("Filter Options", systemImage: "line.3.horizontal.decrease.circle")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .font(.system(size: 20))
              .foregroundColor(.white)
          }
        }
      }
      .sheet(isPresented: $stateModel.showingAddResource) {
        AddResourceView(onResourceAdded: { resource in
          Task {
            await stateModel.addResource(resource)
          }
        })
      }
    }
    .onAppear {
      Task {
        await stateModel.fetch()
        await loadStudentRecommendations()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation {
          isLoaded = true
        }
      }
    }
    .sheet(isPresented: $showingStudentPicker) {
      StudentPickerSheet(
        selectedStudent: $selectedStudent,
        onStudentSelected: { student in
          selectedStudent = student
          showStudentRecommendations = true
          showingStudentPicker = false
          // Load personalized resource recommendations
          Task {
            await loadPersonalizedRecommendations(for: student)
          }
        }
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingAllRecommendations) {
      if let student = selectedStudent {
        AllStudentResourcesSheet(
          student: student,
          recommendations: studentRecommendations
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Background

  private var resourceBackgroundView: some View {
    TMIBackgroundView(variant: .default)
  }

  // MARK: - Search Bar

  private var searchBarView: some View {
    TMITextField(
      icon: "magnifyingglass",
      placeholder: "Search resources",
      text: $stateModel.searchText
    )
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
  }

  // MARK: - Category Picker

  private var categoryPickerView: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Categories")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          CategoryButton(
            title: "All",
            icon: "square.grid.2x2.fill",
            isSelected: stateModel.selectedCategory == nil,
            color: .blue
          ) {
            withAnimation {
              stateModel.selectedCategory = nil
            }
          }

          ForEach(Resource.ResourceCategory.allCases, id: \.self) { category in
            CategoryButton(
              title: category.rawValue.capitalized,
              icon: category.icon,
              isSelected: stateModel.selectedCategory == category,
              color: category.color
            ) {
              withAnimation {
                stateModel.selectedCategory = category
              }
            }
          }
        }
        .padding(.bottom, 8)
      }
    }
  }

  // MARK: - Featured Resources

  private var hasFeaturedResources: Bool {
    stateModel.resources.contains(where: { $0.isFeatured })
  }

  private var featuredResourcesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Featured")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(stateModel.featuredResources) { resource in
            NavigationLink(destination: ResourceDetailView(resource: resource, onDelete: {
              Task {
                await stateModel.deleteResource(resource)
              }
            })) {
              FeaturedResourceCard(resource: resource)
                .frame(width: 300, height: 180)
            }
            .buttonStyle(ScaleButtonStyle())
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }

  // MARK: - Resources Grid

  private var resourcesGridView: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
      spacing: 16
    ) {
      ForEach(stateModel.filteredResources) { resource in
        NavigationLink(
          destination: ResourceDetailView(resource: resource, onDelete: {
            Task {
              await stateModel.deleteResource(resource)
            }
          })
        ) {
          ResourceCard(resource: resource)
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 30)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isLoaded)
        .contextMenu {
          Button(role: .destructive) {
            Task {
              await stateModel.deleteResource(resource)
            }
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 100)  // Extra padding for FAB
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 24) {
      // Empty illustration
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.2), Color.clear]),
              center: .center,
              startRadius: 1,
              endRadius: 100
            )
          )
          .frame(width: 200, height: 200)

        Image(systemName: "books.vertical.fill")
          .font(.system(size: 80))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.top, 40)

      Text("No Resources Found")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)

      if stateModel.searchText.isEmpty && stateModel.selectedCategory == nil {
        Text("Add your first resource to build your library")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)

        Button {
          stateModel.showingAddResource = true
        } label: {
          HStack {
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .semibold))

            Text("Add Resource")
              .font(.system(size: 16, weight: .semibold))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.tmiSecondary)
          )
          .foregroundColor(.white)
        }
        .padding(.top, 10)
      } else {
        Text("Try changing your search or filter")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)

        Button {
          stateModel.searchText = ""
          stateModel.selectedCategory = nil
        } label: {
          HStack {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 16, weight: .semibold))

            Text("Reset Filters")
              .font(.system(size: 16, weight: .semibold))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.tmiSecondary)
          )
          .foregroundColor(.white)
        }
        .padding(.top, 10)
      }
    }
    .padding(.vertical, 40)
    .padding(.horizontal, 20)
  }

  // MARK: - Student Recommendations Section

  private var studentRecommendationsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "star.fill")
          .foregroundColor(.yellow)

        Text("For \((selectedStudent?.name.components(separatedBy: " ").first) ?? "You")")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)

        Spacer()

        Button("View All") {
          showingAllRecommendations = true
        }
        .font(.caption)
        .foregroundColor(.tmiSecondary)
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(studentRecommendations.prefix(5), id: \.id) { resource in
            NavigationLink(destination: ResourceDetailView(resource: resource, onDelete: {
              Task {
                await stateModel.deleteResource(resource)
              }
            })) {
              PersonalizedResourceCard(resource: resource)
                .frame(width: 280, height: 160)
            }
            .buttonStyle(ScaleButtonStyle())
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }

  // MARK: - Data Loading
  
  private func loadStudentRecommendations() async {
    guard let student = selectedStudent else { return }
    
    let careerService = CareerService.shared
    studentRecommendations = await careerService.getRecommendedResources(for: student)
    showStudentRecommendations = !studentRecommendations.isEmpty
  }
}



// MARK: - Category Button

struct CategoryButton: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 14))

        Text(title)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(
            isSelected ? color.opacity(0.5) : Color.white.opacity(0.1),
            lineWidth: 1
          )
      )
      .foregroundColor(isSelected ? color : .white.opacity(0.7))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Featured Resource Card

struct FeaturedResourceCard: View {
  let resource: Resource

  @State private var isHovered = false

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      // Background with gradient overlay
      RoundedRectangle(cornerRadius: 16)
        .fill(
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: resource.category.color.opacity(0.5), location: 0),
              .init(color: Color.black.opacity(0.8), location: 1),
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
        )

      // Category icon (watermarked)
      Image(systemName: resource.category.icon)
        .font(.system(size: 80))
        .foregroundColor(.white.opacity(0.1))
        .offset(x: -20, y: -20)
        .rotationEffect(.degrees(-15))

      // Content
      VStack(alignment: .leading, spacing: 10) {
        // Category pill
        Text(resource.category.rawValue.capitalized)
          .font(.system(size: 12, weight: .semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            Capsule()
              .fill(resource.category.color.opacity(0.3))
          )
          .foregroundColor(resource.category.color)

        // Title
        Text(resource.title)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.white)

        // Description
        Text(resource.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)

        // Tags
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(resource.tags.prefix(3), id: \.self) { tag in
              Text(tag)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.white.opacity(0.9))
            }

            if resource.tags.count > 3 {
              Text("+\(resource.tags.count - 3)")
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                  RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.white.opacity(0.9))
            }
          }
        }
      }
      .padding(16)
    }
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.02))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.3)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          LinearGradient(
            colors: [
              resource.category.color.opacity(0.5), .clear, resource.category.color.opacity(0.2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .scaleEffect(isHovered ? 1.03 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - Resource Card



// MARK: - Add Resource View



// MARK: - Helper Views

// MARK: - Extensions

extension View {
  func placeholder<Content: View>(
    when shouldShow: Bool,
    alignment: Alignment = .leading,
    @ViewBuilder placeholder: () -> Content
  ) -> some View {
    ZStack(alignment: alignment) {
      placeholder().opacity(shouldShow ? 1 : 0)
      self
    }
  }
}

// MARK: - Preview

// MARK: - Personalized Resource Card

struct PersonalizedResourceCard: View {
  let resource: Resource
  @State private var isHovered = false

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      // Background with enhanced gradient overlay
      RoundedRectangle(cornerRadius: 16)
        .fill(
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: resource.category.color.opacity(0.6), location: 0),
              .init(color: Color.black.opacity(0.8), location: 1),
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
        )

      // Personalization indicator (top right)
      VStack {
        HStack {
          Spacer()
          
          HStack(spacing: 4) {
            Image(systemName: "star.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.yellow)

            Text("Recommended")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.yellow)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(Color.yellow.opacity(0.2))
          )
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
        
        Spacer()
      }

      // Category icon (watermarked)
      Image(systemName: resource.category.icon)
        .font(.system(size: 60))
        .foregroundColor(.white.opacity(0.1))
        .offset(x: -15, y: -15)
        .rotationEffect(.degrees(-10))

      // Content
      VStack(alignment: .leading, spacing: 8) {
        // Category pill
        Text(resource.category.rawValue.capitalized)
          .font(.system(size: 11, weight: .semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(resource.category.color.opacity(0.3))
          )
          .foregroundColor(resource.category.color)

        // Title
        Text(resource.title)
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(2)

        // Description
        Text(resource.description)
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)

        // Tags (top 2)
        HStack(spacing: 6) {
          ForEach(resource.tags.prefix(2), id: \.self) { tag in
            Text(tag)
              .font(.system(size: 10))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(Color.white.opacity(0.15))
              )
              .foregroundColor(.white.opacity(0.9))
          }

          if resource.tags.count > 2 {
            Text("+\(resource.tags.count - 2)")
              .font(.system(size: 10))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(Color.white.opacity(0.15))
              )
              .foregroundColor(.white.opacity(0.9))
          }
        }
      }
      .padding(16)
    }
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.02))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.3)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          LinearGradient(
            colors: [
              Color.yellow.opacity(0.4), .clear, resource.category.color.opacity(0.3),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .scaleEffect(isHovered ? 1.02 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - Helper Extensions

extension ResourcesView {
  private func loadPersonalizedRecommendations(for student: Student) async {
    // In a real implementation, this would fetch personalized recommendations
    // For now, we'll create sample recommendations based on student interests
    await MainActor.run {
      // Create sample resource recommendations
      self.studentRecommendations = [
        Resource(
          title: "Understanding Student Interests",
          description: "A guide for educators on identifying and nurturing student interests",
          category: .article,
          url: "https://example.com/interests",
          createdAt: Date(),
          updatedAt: Date(),
          tags: ["interests", "student-engagement"],
          recommendedFor: [student.grade],
          isFeatured: false,
          scope: .global,
          districtId: nil,
          ownerUid: nil
        )
      ]
    }
  }
}

// MARK: - All Student Resources Sheet

struct AllStudentResourcesSheet: View {
  let student: Student
  let recommendations: [Resource]
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .default)
        
        if recommendations.isEmpty {
          VStack(spacing: 20) {
            Image(systemName: "books.vertical")
              .font(.system(size: 50))
              .foregroundColor(.white.opacity(0.3))
            
            Text("No Recommendations")
              .font(.title2)
              .foregroundColor(.white)
            
            Text("We haven't found specific resource recommendations for \(student.name) yet. Check back after adding more student interests and assessment data.")
              .font(.body)
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 16) {
              ForEach(recommendations) { resource in
                ResourceCard(resource: resource)
                  .padding(.horizontal)
              }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
          }
        }
      }
      .navigationTitle("Resources for \(student.name)")
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

#Preview {
  ResourcesView()
}

