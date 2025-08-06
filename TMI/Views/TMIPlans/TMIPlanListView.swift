// TMIPlanListView.swift

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// MARK: - TMI Plan List View Model

@Observable
class TMIPlanListViewModel {
  var tmiPlans: [TMIPlan] = []
  var isLoading = false
  private var db = FirebaseManager.shared.firestore

  private var userPlansCollection: CollectionReference? {
    guard let uid = Auth.auth().currentUser?.uid else {
      print("Error: User not logged in.")
      return nil
    }
    return db.collection("users").document(uid).collection("tmiPlans")
  }

  @MainActor
  func fetchPlans() async {
    guard let collection = userPlansCollection else { return }
    
    isLoading = true
    
    do {
      let querySnapshot = try await collection.getDocuments()
      tmiPlans = querySnapshot.documents.compactMap { document -> TMIPlan? in
        try? document.data(as: TMIPlan.self)
      }
      print("Fetched \(tmiPlans.count) TMI plans")
    } catch {
      print("Error getting TMI plans: \(error.localizedDescription)")
    }
    
    isLoading = false
  }

  func addPlan(_ plan: TMIPlan) async -> Bool {
    guard let collection = userPlansCollection else { return false }
    
    do {
      _ = try collection.addDocument(from: plan)
      await fetchPlans() // Refresh the list after adding
      return true
    } catch {
      print("Error adding TMI plan: \(error.localizedDescription)")
      return false
    }
  }

  func deletePlan(_ plan: TMIPlan) {
    guard let id = plan.id, let collection = userPlansCollection else { return }
    
    Task {
      do {
        try await collection.document(id).delete()
        await fetchPlans() // Refresh the list after deleting
      } catch {
        print("Error deleting TMI plan: \(error.localizedDescription)")
      }
    }
  }
}

struct TMIPlanListView: View {
  @State private var viewModel = TMIPlanListViewModel()
  @State private var showingNewPlanSheet = false
  @State private var searchText = ""
  @State private var showingFilterSheet = false
  @State private var selectedFilter: PlanFilter = .all
  @State private var isSearchFocused = false

  // Animation states
  @State private var headerAppeared = false
  @State private var searchAppeared = false
  @State private var plansAppeared = false
  @State private var fabAppeared = false

  enum PlanFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inProgress = "In Progress"
    case completed = "Completed"

    var id: String { self.rawValue }
  }

  var body: some View {
    ZStack {
      // Background
      planBackgroundView

      NavigationStack {
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

              if viewModel.isLoading {
                ProgressView()
                  .scaleEffect(1.5)
                  .frame(maxWidth: .infinity, minHeight: 200)
                  .foregroundColor(.white)
              } else if filteredPlans.isEmpty {
                enhancedEmptyStateView
                  .offset(y: plansAppeared ? 0 : 20)
                  .opacity(plansAppeared ? 1 : 0)
              } else {
                enhancedPlanGridView
                  .offset(y: plansAppeared ? 0 : 20)
                  .opacity(plansAppeared ? 1 : 0)
              }
            }
            .padding(.bottom, 100)
          }

          // Floating action button - Using unified TMIButton
          TMIButton(
            text: "plus",
            style: .floating,
            action: { showingNewPlanSheet = true }
          )
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
                // Actions menu
              }) {
                Label("Create from Template", systemImage: "doc.badge.plus")
              }

              Button(action: {
                // Import action
              }) {
                Label("Import Plans", systemImage: "square.and.arrow.down")
              }

              Divider()

              Button(action: {
                // Analytics action
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
        .sheet(isPresented: $showingNewPlanSheet) {
          NewTMIPlanView { newPlan in
            Task {
              let success = await viewModel.addPlan(newPlan)
              if success {
                showingNewPlanSheet = false
              }
            }
          }
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
          .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showingFilterSheet) {
          PlanFilterView(selectedFilter: $selectedFilter)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      animateViews()
      Task {
        await viewModel.fetchPlans()
      }
    }
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
        if searchText.isEmpty && !isSearchFocused {
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

        TextField("", text: $searchText)
          .font(.system(size: 16))
          .padding(12)
          .foregroundColor(.white)
          .autocorrectionDisabled()
          .onTapGesture {
            isSearchFocused = true
          }
          .onSubmit {
            isSearchFocused = false
          }
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
            isSearchFocused
              ? LinearGradient(
                colors: [Color.tmiSecondary.opacity(0.7)],
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
      .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

      // Filter Button
      Button {
        showingFilterSheet = true
      } label: {
        HStack(spacing: 8) {
          if selectedFilter != .all {
            Text(selectedFilter.rawValue)
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.white)
          }

          Image(systemName: "line.3.horizontal.decrease.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(
              selectedFilter != .all ? Color.white : Color.white.opacity(0.7)
            )
            .symbolRenderingMode(.hierarchical)
        }
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(selectedFilter == .all ? Color.clear : Color.tmiSecondary.opacity(0.3))
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
      ForEach(filteredPlans) { plan in
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
        count: filteredPlans.count,
        label: "Total",
        icon: "doc.text.fill",
        color: .blue
      )

      PlanStat(
        count: filteredPlans.filter({ $0.progress < 1.0 }).count,
        label: "In Progress",
        icon: "clock.fill",
        color: .orange
      )

      PlanStat(
        count: filteredPlans.filter({ $0.progress >= 1.0 }).count,
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
        showingNewPlanSheet = true
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
    if !searchText.isEmpty {
      return "No plans match your search criteria. Try different keywords or clear your search."
    } else if selectedFilter != .all {
      return
        "No plans found with the filter '\(selectedFilter.rawValue)'. Try selecting a different filter."
    } else {
      return "Create your first TMI plan to start tracking student progress and development."
    }
  }

  // MARK: - Filtering Logic

  private var filteredPlans: [TMIPlan] {
    viewModel.tmiPlans.filter { plan in
      (searchText.isEmpty || plan.model.rawValue.localizedCaseInsensitiveContains(searchText)
        || planContainsStudentName(plan, searchText))
        && (selectedFilter == .all || matchesFilter(plan: plan))
    }
  }

  private func planContainsStudentName(_ plan: TMIPlan, _ searchText: String) -> Bool {
    return plan.students.contains { student in
      student.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  private func matchesFilter(plan: TMIPlan) -> Bool {
    switch selectedFilter {
    case .all:
      return true
    case .inProgress:
      return plan.progress < 1.0
    case .completed:
      return plan.progress >= 1.0
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
  @Binding var selectedFilter: TMIPlanListView.PlanFilter
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
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

          ForEach(TMIPlanListView.PlanFilter.allCases) { filter in
            TMIPlanFilterOptionCard(
              filter: filter,
              isSelected: selectedFilter == filter,
              action: {
                withAnimation {
                  selectedFilter = filter
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
}

struct TMIPlanFilterOptionCard: View {
  let filter: TMIPlanListView.PlanFilter
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
