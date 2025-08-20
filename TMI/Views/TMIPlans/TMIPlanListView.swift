// TMIPlanListView.swift

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// MARK: - TMI Plan List View Model (Legacy - use TMIPlanListStateModel instead)

struct TMIPlanListView: View {
  @State private var stateModel = TMIPlanListStateModel()
  @Environment(\.dashboardStateModel) var dashboardStateModel

  // Animation states
  @State private var headerAppeared = false
  @State private var searchAppeared = false
  @State private var plansAppeared = false
  @State private var fabAppeared = false
  
  // Sheet states
  @State private var showingFormBuilder = false
  @State private var showingAnalytics = false
  @State private var showingImportPlans = false

  var body: some View {
    ZStack {
      // Background
      planBackgroundView

        ZStack(alignment: .bottomTrailing) {
          // Content
          ScrollView {
            VStack(spacing: 24) {
              enhancedHeaderView
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .offset(y: headerAppeared ? 0 : -20)
                .opacity(headerAppeared ? 1 : 0)

              enhancedSearchAndFilterView
                .padding(.horizontal, 20)
                .offset(y: searchAppeared ? 0 : -20)
                .opacity(searchAppeared ? 1 : 0)

              contentView
                .offset(y: plansAppeared ? 0 : 20)
                .opacity(plansAppeared ? 1 : 0)
            }
            .padding(.bottom, 100)
          }

          // Floating action button
          Button {
            stateModel.showNewPlan()
          } label: {
            Image(systemName: "plus")
              .font(.system(size: 24, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(
                Circle()
                  .fill(
                    LinearGradient(
                      colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
              )
              .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
          }
          .buttonStyle(ScaleButtonStyle())
          .padding(.trailing, 20)
          .padding(.bottom, 20)
          .offset(y: fabAppeared ? 0 : 100)
          .opacity(fabAppeared ? 1 : 0)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text("TMI Plans")
              .font(.system(size: 20, weight: .bold, design: .rounded))
              .foregroundColor(.white)
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
              Button(action: {
                // Show form template picker for creating TMI plans
                showingFormBuilder = true
              }) {
                Label("Create from Template", systemImage: "doc.badge.plus")
              }

              Button(action: {
                // Show import plans interface
                showingImportPlans = true
              }) {
                Label("Import Plans", systemImage: "square.and.arrow.down")
              }

              Divider()

              Button(action: {
                // Navigate to dashboard insights with real data
                showingAnalytics = true
              }) {
                Label("View Analytics", systemImage: "chart.bar.xaxis")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundColor(.white)
            }
          }
        }
        .sheet(isPresented: $stateModel.showingNewPlan) {
          NewTMIPlanView { savedPlan in
            // Plan is already saved in NewTMIPlanView, just update the state
            stateModel.addExistingPlan(savedPlan)
            stateModel.hideNewPlan()
          }
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
          .presentationCornerRadius(30)
        }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      animateViews()
      Task {
        // Fetch data if not already loaded or if it's been a while
        if case .idle = stateModel.state {
          await stateModel.fetch()
        } else if case .loaded = stateModel.state {
          // Refresh to ensure we have the latest data
          await stateModel.fetch()
        }
      }
    }
    .sheet(isPresented: $showingFormBuilder) {
      FormTemplateBuilderView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingAnalytics) {
      Group {
        if case .loaded(let dashboardData) = dashboardStateModel.state {
          DashboardInsightsView(dashboardData: dashboardData)
        } else {
          // Fallback while loading
          ProgressView("Loading Analytics...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.08, green: 0.08, blue: 0.15))
            .task {
              await dashboardStateModel.fetch()
            }
        }
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingImportPlans) {
      ImportPlansView { importedPlans in
        // Handle imported plans
        for plan in importedPlans {
          stateModel.addExistingPlan(plan)
        }
        showingImportPlans = false
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    // The alert now uses a Binding to stateModel.hasError and calls clearError()
    .alert("Error", isPresented: Binding(
      get: { stateModel.hasError },
      set: { newValue in if !newValue { stateModel.clearError() } }
    ), actions: {
      Button("OK") {
        stateModel.clearError()
      }
    }, message: {
      if let error = stateModel.currentError {
          Text(error.userFriendlyMessage ?? "Error")
      }
    })
  }
  
  // MARK: - Views
  
  @ViewBuilder
  private var contentView: some View {
    switch stateModel.state {
    case .loading:
      loadingView
    case .loaded(_):
      if stateModel.filteredPlans.isEmpty {
        enhancedEmptyStateView
      } else {
        enhancedPlanGridView
      }
    case .error(_):
      errorView
    case .idle:
        loadingView
    }
  }
  
  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.5)
        .foregroundColor(.white)
      
      Text("Loading TMI Plans...")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }
  
  private var errorView: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 50))
        .foregroundColor(.orange)
      
      Text("Unable to Load Plans")
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.white)
      
      if let error = stateModel.currentError {
          Text(error.userFriendlyMessage ?? "Error")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
      }
      
      Button("Try Again") {
        Task {
          await stateModel.fetch()
        }
      }
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
      .cornerRadius(12)
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
  }

  private func animateViews() {
    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
      headerAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
      searchAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
      plansAppeared = true
    }

    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
      fabAppeared = true
    }
  }

  // MARK: - Background

  private var planBackgroundView: some View {
    // Using unified TMIBackgroundView
    TMIBackgroundView(variant: .plans)
      .ignoresSafeArea()
  }

  // MARK: - Header View

  private var enhancedHeaderView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Your TMI Plans")
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .foregroundColor(.white)

      Text("Manage and track student progress")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Search and Filter View

  private var enhancedSearchAndFilterView: some View {
    HStack(spacing: 16) {
      // Search Field
      ZStack(alignment: .leading) {
        if stateModel.searchText.isEmpty {
          HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white.opacity(0.5))

            Text("Search plans or students")
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.5))
          }
          .padding(.leading, 12)
        }

        TextField("", text: $stateModel.searchText)
          .font(.system(size: 16))
          .padding(12)
          .foregroundColor(.white)
          .autocorrectionDisabled()
      }
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 14)
              .fill(.ultraThinMaterial)
              .opacity(0.5)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )

      // Filter Menu
      Menu {
        ForEach(PlanFilter.allCases) { filter in
          Button {
            stateModel.selectedFilter = filter
          } label: {
            HStack {
              Text(filter.rawValue)
              if stateModel.selectedFilter == filter {
                Image(systemName: "checkmark")
              }
            }
          }
        }
      } label: {
        HStack(spacing: 8) {
          if stateModel.selectedFilter != .all {
            Text(stateModel.selectedFilter.rawValue)
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.white)
          }

          Image(systemName: "line.3.horizontal.decrease.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(
              stateModel.selectedFilter != .all ? Color.white : Color.white.opacity(0.7)
            )
            .symbolRenderingMode(.hierarchical)
        }
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(stateModel.selectedFilter == .all ? Color.clear : Color.tmiSecondary.opacity(0.3))
        )
      }
      .buttonStyle(ScaleButtonStyle())
    }
  }

  // MARK: - Plan Grid View

  private var enhancedPlanGridView: some View {
    LazyVStack(spacing: 20) {
      // Plan Stats Summary
      planStatsSummary
        .padding(.horizontal, 20)

      // Plans Grid
      ForEach(stateModel.filteredPlans) { plan in
        NavigationLink(destination: TMIPlanDetailView(plan: plan)) {
          TMIPlanCard(plan: plan)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.top, 10)
    }
  }

  private var planStatsSummary: some View {
    HStack(spacing: 15) {
      PlanStat(
        count: stateModel.totalPlans,
        label: "Total",
        icon: "doc.text.fill",
        color: .blue
      )

      PlanStat(
        count: stateModel.inProgressPlans,
        label: "In Progress",
        icon: "clock.fill",
        color: .orange
      )

      PlanStat(
        count: stateModel.completedPlans,
        label: "Completed",
        icon: "checkmark.circle.fill",
        color: .green
      )
    }
  }

  // MARK: - Empty State View

  private var enhancedEmptyStateView: some View {
    VStack(spacing: 24) {
      Spacer()

      ZStack {
        // Glowing background
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.3), Color.clear]),
              center: .center,
              startRadius: 5,
              endRadius: 100
            )
          )
          .frame(width: 200, height: 200)
          .blur(radius: 10)

        Image(systemName: "doc.text.magnifyingglass")
          .font(.system(size: 70))
          .foregroundColor(.white.opacity(0.7))
      }

      Text("No Plans Found")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundColor(.white)

      Text(emptyStateMessage)
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Button {
        stateModel.showNewPlan()
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 18, weight: .semibold))

          Text("Create New Plan")
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
        .cornerRadius(12)
        .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
      }
      .buttonStyle(ScaleButtonStyle())
      .padding(.top, 10)

      Spacer()
    }
    .padding()
    .frame(minHeight: 500)
  }

  private var emptyStateMessage: String {
    if !stateModel.searchText.isEmpty {
      return "No plans match your search criteria. Try different keywords or clear your search."
    } else if stateModel.selectedFilter != .all {
      return
        "No plans found with the filter '\(stateModel.selectedFilter.rawValue)'. Try selecting a different filter."
    } else {
      return "Create your first TMI plan to start tracking student progress and development."
    }
  }

}

// MARK: - Supporting Components

struct PlanStat: View {
  var count: Int
  var label: String
  var icon: String
  var color: Color

  @State private var isAnimated = false

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(color.opacity(0.1))
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundColor(color)
          .scaleEffect(isAnimated ? 1.1 : 1.0)
          .animation(
            Animation.easeInOut(duration: 1.5)
              .repeatForever(autoreverses: true),
            value: isAnimated
          )
      }

      Text("\(count)")
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .contentTransition(.numericText())

      Text(label)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
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
    .onAppear {
      isAnimated = true
    }
  }
}

// MARK: - Filter View

struct PlanFilterView: View {
  @Binding var selectedFilter: PlanFilter
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
        // Background
        Color(red: 0.08, green: 0.08, blue: 0.15)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          Text("Select a filter to view specific TMI plans.")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

          ForEach(PlanFilter.allCases) { filter in
            TMIPlanFilterOptionCard(
              filter: filter,
              isSelected: false,
              action: {
                withAnimation {
                  dismiss()
                }
              }
            )
          }
        }
        .padding(20)
      }
      .navigationTitle("Filter Plans")
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
}

struct TMIPlanFilterOptionCard: View {
  let filter: PlanFilter
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        // Icon
        filterIcon
          .padding(14)
          .background(
            Circle()
              .fill(isSelected ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.05))
          )

        // Label
        VStack(alignment: .leading, spacing: 4) {
          Text(filter.rawValue)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)

          Text(filterDescription)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(1)
        }

        Spacer()

        // Selection indicator
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(Color.tmiSecondary)
            .font(.system(size: 22))
        }
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected
              ? LinearGradient(
                colors: [Color.tmiSecondary.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .shadow(
        color: isSelected ? Color.tmiSecondary.opacity(0.2) : Color.clear, radius: 10, x: 0, y: 5
      )
      .scaleEffect(isHovered ? 1.02 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private var filterIcon: some View {
    let iconName: String
    let iconColor: Color

    switch filter {
    case .all:
      iconName = "doc.text.fill"
      iconColor = .blue
    case .inProgress:
      iconName = "clock.fill"
      iconColor = .orange
    case .completed:
      iconName = "checkmark.circle.fill"
      iconColor = .green
    }

    return Image(systemName: iconName)
      .font(.system(size: 20))
      .foregroundColor(iconColor)
  }

  private var filterDescription: String {
    switch filter {
    case .all:
      return "View all TMI plans"
    case .inProgress:
      return "Plans that are currently in progress"
    case .completed:
      return "Plans that have been fully completed"
    }
  }
}

#Preview {
  TMIPlanListView()
}

// MARK: - Import Plans View

struct ImportPlansView: View {
  let onImport: ([TMIPlan]) -> Void
  @Environment(\.dismiss) private var dismiss
  
  @State private var selectedFileURL: URL?
  @State private var isImporting = false
  @State private var importError: String?
  @State private var showingFilePicker = false
  
  var body: some View {
    ZStack {
      TMIBackgroundView(variant: .default)
          .ignoresSafeArea()
        
        VStack(spacing: 24) {
          // Header
          VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.fill")
              .font(.system(size: 50))
              .foregroundColor(.tmiSecondary)
            
            Text("Import TMI Plans")
              .font(.title.bold())
              .foregroundColor(.white)
            
            Text("Select a JSON file containing TMI plans to import into your system.")
              .font(.body)
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }
          .padding(.top, 40)
          
          // File selection
          TMIGlassCard(style: .default) {
            VStack(spacing: 16) {
              if let fileURL = selectedFileURL {
                HStack {
                  Image(systemName: "doc.fill")
                    .foregroundColor(.green)
                  
                  VStack(alignment: .leading, spacing: 2) {
                    Text(fileURL.lastPathComponent)
                      .font(.headline)
                      .foregroundColor(.white)
                    
                    Text("File selected")
                      .font(.caption)
                      .foregroundColor(.white.opacity(0.7))
                  }
                  
                  Spacer()
                  
                  Button("Change") {
                    showingFilePicker = true
                  }
                  .foregroundColor(.tmiSecondary)
                }
              } else {
                VStack(spacing: 16) {
                  Image(systemName: "doc.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
                  
                  Text("No file selected")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                }
              }
              
              Button {
                showingFilePicker = true
              } label: {
                Text(selectedFileURL == nil ? "Select File" : "Change File")
                  .font(.headline)
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(Color.tmiSecondary)
                  )
              }
              .buttonStyle(.plain)
            }
          }
          
          // Error message
          if let importError = importError {
            TMIGlassCard(style: .default) {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                  Text("Import Error")
                    .font(.headline)
                    .foregroundColor(.white)
                  
                  Text(importError)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
              }
            }
          }
          
          Spacer()
          
          // Action buttons
          HStack(spacing: 16) {
            Button("Cancel") {
              dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            Button {
              if selectedFileURL != nil {
                Task {
                  await performImport()
                }
              }
            } label: {
              Group {
                if isImporting {
                  HStack {
                    ProgressView()
                      .scaleEffect(0.8)
                      .tint(.white)
                    Text("Importing...")
                  }
                } else {
                  Text("Import Plans")
                }
              }
              .font(.headline)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(selectedFileURL != nil ? Color.tmiSecondary : Color.gray)
              )
            }
            .disabled(selectedFileURL == nil || isImporting)
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
      }
      .navigationTitle("Import Plans")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
      .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: [.json],
      onCompletion: { result in
        switch result {
        case .success(let url):
          selectedFileURL = url
          importError = nil
        case .failure(let error):
          importError = error.localizedDescription
        }
      }
    )
  }
  
  @MainActor
  private func performImport() async {
    guard let fileURL = selectedFileURL else { return }
    
    isImporting = true
    importError = nil
    
    do {
      let data = try Data(contentsOf: fileURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      
      let importedPlans = try decoder.decode([TMIPlan].self, from: data)
      
      // Validate imported plans
      guard !importedPlans.isEmpty else {
        importError = "No valid TMI plans found in the file."
        isImporting = false
        return
      }
      
      // Success - call the completion handler
      onImport(importedPlans)
      
    } catch {
      importError = "Failed to import plans: \(error.localizedDescription)"
    }
    
    isImporting = false
  }
}
