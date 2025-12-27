//
//  DistrictDashboardView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import SwiftUI

struct DistrictDashboardView: View {
  @State private var viewModel = DistrictDashboardViewModel()
  @State private var showingExportSheet = false
  @State private var showingFilterSheet = false
  @Environment(\.authStateModel) private var authStateModel

  var body: some View {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      if viewModel.isLoading {
        VStack(spacing: 20) {
          ProgressView()
            .scaleEffect(1.5)
          Text(viewModel.loadingMessage)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      } else {
        ScrollView {
          VStack(spacing: 24) {
            // Header
            headerSection

            // KPI Cards
            kpiSection

            // Charts Section (Placeholder for now)
            // chartSection

            // Students Needing Attention
            StudentsNeedingAttentionList(alerts: viewModel.studentsNeedingAttention)

            // AI Insights
            DistrictInsightsSummary(insights: viewModel.insights)

            // School Breakdown
            schoolBreakdownSection
          }
          .padding()
        }
        .refreshable {
          await viewModel.refreshDashboard()
        }
      }
    }
    .navigationTitle(viewModel.districtName)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        Button {
          showingFilterSheet = true
        } label: {
          Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }

        Button {
          showingExportSheet = true
        } label: {
          Label("Export", systemImage: "square.and.arrow.up")
        }
      }
    }
    .sheet(isPresented: $showingExportSheet) {
      exportSheet
    }
    .sheet(isPresented: $showingFilterSheet) {
      DistrictSchoolFilter(filter: viewModel.filter) { newFilter in
        Task {
          await viewModel.applyFilter(newFilter)
        }
      }
    }
    .task {
      // Load sample data for demo purposes
      // In production, get districtId from authStateModel.currentUser.districtId
      if viewModel.districtId == nil {
        if let districtId = authStateModel.currentUser?.districtId {
          await viewModel.loadDashboard(districtId: districtId)
        } else {
          // Demo mode: load sample data
          viewModel.loadSampleData()
        }
      }
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

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("District Overview")
            .font(.title2)
            .fontWeight(.bold)
          Text("Last updated: \(Date().formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }

  // MARK: - KPI Section

  private var kpiSection: some View {
    VStack(spacing: 16) {
      // Row 1: Primary metrics
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        DistrictKPICard(
          title: "Total Students",
          value: "\(viewModel.metrics.totalStudents)",
          icon: "person.3.fill",
          color: .blue
        )

        DistrictKPICard(
          title: "Engagement Rate",
          value: viewModel.metrics.engagementPercentage,
          icon: "chart.line.uptrend.xyaxis",
          color: .green
        )
      }

      // Row 2: Plan metrics
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        DistrictKPICard(
          title: "Active Plans",
          value: "\(viewModel.metrics.activePlansCount)",
          icon: "doc.text.fill",
          color: .orange
        )

        DistrictKPICard(
          title: "Plan Completion",
          value: viewModel.metrics.planCompletionPercentage,
          icon: "checkmark.circle.fill",
          color: .green
        )
      }

      // Row 3: Form & Alerts
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        DistrictKPICard(
          title: "Form Completion",
          value: viewModel.metrics.formCompletionPercentage,
          icon: "list.clipboard.fill",
          color: .purple
        )

        DistrictKPICard(
          title: "Needs Attention",
          value: "\(viewModel.metrics.flaggedStudentsCount)",
          icon: "exclamationmark.triangle.fill",
          color: viewModel.metrics.flaggedStudentsCount > 0 ? .red : .gray
        )
      }
    }
  }

  // MARK: - School Breakdown Section

  private var schoolBreakdownSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("School Performance")
        .font(.headline)
        .padding(.horizontal)

      ForEach(viewModel.schoolMetrics, id: \.schoolId) { school in
        schoolCard(for: school)
      }
    }
    .padding(.vertical)
  }

  private func schoolCard(for school: SchoolMetrics) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(school.schoolName)
            .font(.headline)
          Text("\(school.studentCount) students")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        if let topSchool = viewModel.topPerformingSchool, school.schoolId == topSchool.schoolId {
          Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        }
      }

      Divider()

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        metricItem(label: "Engagement", value: String(format: "%.0f%%", school.engagementRate * 100))
        metricItem(label: "Plans", value: "\(school.totalPlansCount)")
        metricItem(label: "Alerts", value: "\(school.flaggedStudentsCount)")
      }
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(12)
    .padding(.horizontal)
  }

  private func metricItem(label: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.title3)
        .fontWeight(.semibold)
      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Export Sheet

  private var exportSheet: some View {
    NavigationStack {
      List {
        Section {
          Button {
            Task {
              await viewModel.exportToPDF()
              if viewModel.exportedFileURL != nil {
                showingExportSheet = false
              }
            }
          } label: {
            Label("Export as PDF (Board-Ready)", systemImage: "doc.richtext")
          }

          Button {
            Task {
              await viewModel.exportToCSV()
              if viewModel.exportedFileURL != nil {
                showingExportSheet = false
              }
            }
          } label: {
            Label("Export as CSV (Spreadsheet)", systemImage: "tablecells")
          }

          Button {
            Task {
              await viewModel.exportToJSON()
              if viewModel.exportedFileURL != nil {
                showingExportSheet = false
              }
            }
          } label: {
            Label("Export as JSON (Data)", systemImage: "curlybraces")
          }
        } header: {
          Text("Export Format")
        }
      }
      .navigationTitle("Export Report")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showingExportSheet = false
          }
        }
      }
      .overlay {
        if viewModel.isExporting {
          ProgressView("Exporting...")
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    DistrictDashboardView()
  }
}
