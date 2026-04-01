//
//  StaffAssignmentListView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct StaffAssignmentListView: View {
  @Environment(\.authStateModel) private var authStateModel
  @State private var assignments: [FormAssignment] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingCreationSheet = false
  
  private let assignmentService = FormAssignmentService()

  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)
        
        if isLoading && assignments.isEmpty {
          ProgressView("Loading Assignments...")
        } else if assignments.isEmpty {
          emptyStateView
        } else {
          List(assignments) { assignment in
            NavigationLink(destination: StaffAnalyticsView(assignment: assignment)) {
              AssignmentRow(assignment: assignment)
            }
          }
          #if canImport(UIKit)
          .listStyle(.insetGrouped)
          #else
          .listStyle(.inset)
          #endif
          .refreshable {
              await loadAssignments()
          }
        }
      }
      .navigationTitle("Assignments")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showingCreationSheet = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .task {
        await loadAssignments()
      }
      .sheet(isPresented: $showingCreationSheet) {
          AssignmentCreationView()
      }
    }
  }
  
  // MARK: - Subviews
  
  private var emptyStateView: some View {
      VStack(spacing: 20) {
          Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 60))
              .foregroundColor(.secondary)
          Text("No Assignments Yet")
              .font(.title2)
              .fontWeight(.semibold)
          Text("Create an assignment to verify student understanding or collect feedback.")
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          
          Button("Create Assignment") {
              showingCreationSheet = true
          }
          .buttonStyle(.borderedProminent)
      }
  }
  
  private func loadAssignments() async {
      isLoading = true
      do {
          // Fetch assignments created by this user
          if let uid = authStateModel.currentUser?.userID {
              assignments = try await assignmentService.fetchAssignmentsCreatedBy(userId: uid)
          }
      } catch {
          errorMessage = error.localizedDescription
      }
      isLoading = false
  }
}

struct AssignmentRow: View {
    let assignment: FormAssignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(assignment.templateName)
                    .font(.headline)
                Spacer()
                if assignment.isActive {
                    Text("active")
                        .font(.caption)
                        .paddingbadge(color: .green)
                } else {
                    Text("archived")
                        .font(.caption)
                        .paddingbadge(color: .gray)
                }
            }
            
            HStack(spacing: 12) {
                Label(assignment.cohort.displayName, systemImage: "person.3")
                if let due = assignment.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
               HStack {
                   Text("Completion")
                   Spacer()
                   Text("\(assignment.totalSubmitted)/\(assignment.totalAssigned)")
               }
               .font(.caption2)
               
               ProgressView(value: Double(assignment.totalSubmitted), total: Double(max(1, assignment.totalAssigned)))
                   .tint(.blue)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

// Temporary modifier helper
extension View {
    func paddingbadge(color: Color) -> some View {
        self.padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
