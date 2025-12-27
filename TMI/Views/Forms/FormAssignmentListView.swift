//
//  FormAssignmentListView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct FormAssignmentListView: View {
  @State private var viewModel = FormAssignmentViewModel()
  @State private var showingCreateAssignment = false
  @State private var selectedAssignment: FormAssignment?

  var body: some View {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      if viewModel.isLoading && viewModel.assignments.isEmpty {
        ProgressView("Loading assignments...")
      } else {
        content
      }
    }
    .navigationTitle("Form Assignments")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      toolbarContent
    }
    .searchable(text: $viewModel.searchText, prompt: "Search assignments")
    .onChange(of: viewModel.searchText) { _, newValue in
      viewModel.updateSearch(newValue)
    }
    .sheet(isPresented: $showingCreateAssignment) {
      FormAssignmentCreateView(viewModel: viewModel)
    }
    .sheet(item: $selectedAssignment) { assignment in
      FormAssignmentDetailView(assignment: assignment, viewModel: viewModel)
    }
    .task {
      if !viewModel.hasAssignments {
        await viewModel.loadAssignments()
      }
    }
    .refreshable {
      await viewModel.refreshAssignments()
    }
    .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") {
        viewModel.errorMessage = nil
      }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
  }

  // MARK: - Content

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Filter section
        filterSection

        // Assignments list
        if viewModel.hasFilteredResults {
          assignmentsList
        } else {
          emptyState
        }
      }
      .padding()
    }
  }

  // MARK: - Filter Section

  private var filterSection: some View {
    HStack(spacing: 12) {
      Button {
        viewModel.toggleActiveFilter()
      } label: {
        Label(
          viewModel.showActiveOnly ? "Active Only" : "All",
          systemImage: viewModel.showActiveOnly ? "checkmark.circle.fill" : "circle"
        )
        .font(.subheadline)
        .foregroundColor(viewModel.showActiveOnly ? .blue : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
      }

      if !viewModel.searchText.isEmpty {
        Button {
          viewModel.clearFilters()
        } label: {
          Label("Clear", systemImage: "xmark.circle.fill")
            .font(.subheadline)
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
      }

      Spacer()
    }
  }

  // MARK: - Assignments List

  private var assignmentsList: some View {
    LazyVStack(spacing: 12) {
      ForEach(viewModel.filteredAssignments) { assignment in
        FormAssignmentCard(
          assignment: assignment,
          onTap: {
            selectedAssignment = assignment
          },
          onDelete: {
            Task {
              await viewModel.deleteAssignment(assignment)
            }
          },
          onDeactivate: {
            Task {
              await viewModel.deactivateAssignment(assignment)
            }
          }
        )
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("No Assignments Found")
        .font(.headline)

      Text("Create your first form assignment to get started")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        showingCreateAssignment = true
      } label: {
        Label("Create Assignment", systemImage: "plus.circle.fill")
          .font(.subheadline)
          .fontWeight(.medium)
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button {
        showingCreateAssignment = true
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 22))
      }
    }
  }
}

// MARK: - Assignment Card

struct FormAssignmentCard: View {
  let assignment: FormAssignment
  let onTap: () -> Void
  let onDelete: () -> Void
  let onDeactivate: () -> Void

  private var completionRate: Double {
    guard assignment.totalAssigned > 0 else { return 0 }
    return Double(assignment.totalSubmitted) / Double(assignment.totalAssigned) * 100
  }

  private var isOverdue: Bool {
    guard let dueDate = assignment.dueDate else { return false }
    return dueDate < Date() && assignment.isActive
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(assignment.templateName)
            .font(.headline)
            .lineLimit(2)

          Text(assignment.cohort.displayName)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        Menu {
          Button {
            onTap()
          } label: {
            Label("View Details", systemImage: "eye")
          }

          Divider()

          Button {
            onDeactivate()
          } label: {
            Label("Deactivate", systemImage: "pause.circle")
          }

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label("Delete", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .foregroundColor(.secondary)
        }
      }

      Divider()

      // Instructions
      if let instructions = assignment.instructions {
        Text(instructions)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }

      // Progress
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Completion")
            .font(.caption2)
            .foregroundColor(.secondary)

          Spacer()

          Text("\(Int(completionRate))%")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        ProgressView(value: completionRate, total: 100)
          .tint(completionRate >= 80 ? .green : completionRate >= 50 ? .orange : .red)
      }

      // Footer
      HStack {
        // Due date
        if let dueDate = assignment.dueDate {
          Label(
            dueDate.formatted(date: .abbreviated, time: .omitted),
            systemImage: isOverdue ? "exclamationmark.triangle.fill" : "calendar"
          )
          .font(.caption2)
          .foregroundColor(isOverdue ? .red : .secondary)
        }

        Spacer()

        // Stats
        Text("\(assignment.totalSubmitted)/\(assignment.totalAssigned) submitted")
          .font(.caption2)
          .foregroundColor(.secondary)

        if assignment.requiresReview {
          Text("\(assignment.totalReviewed) reviewed")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    .onTapGesture {
      onTap()
    }
  }
}

#Preview {
  NavigationStack {
    FormAssignmentListView()
  }
}
