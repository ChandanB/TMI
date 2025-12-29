//
//  DistrictDashboardViewModel.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import Foundation
import Observation

@Observable
@MainActor
class DistrictDashboardViewModel {
  // Services
  private let analyticsService = DistrictAnalyticsService.shared
  private let exportService = DistrictExportService.shared
  private let districtService = DistrictService.shared

  // State
  var districtId: String?
  var districtName: String = "District"
  var metrics: DistrictMetrics = DistrictMetrics()
  var schoolMetrics: [SchoolMetrics] = []
  var studentsNeedingAttention: [StudentNeedAlert] = []
  var insights: [String] = []

  // UI State
  var isLoading = false
  var loadingMessage = ""
  var errorMessage: String?
  var filter = DistrictFilter()

  // Export state
  var isExporting = false
  var exportedFileURL: URL?

  // MARK: - Data Fetching

  func loadDashboard(districtId: String) async {
    self.districtId = districtId
    isLoading = true
    loadingMessage = "Loading dashboard..."
    errorMessage = nil

    do {
      // Fetch district info
      let district = try await districtService.fetchDistrict(id: districtId)
      self.districtName = district.name

      // Fetch metrics
      loadingMessage = "Computing metrics..."
      metrics = try await analyticsService.computeMetrics(for: districtId, filter: filter)

      // Fetch school metrics
      loadingMessage = "Analyzing schools..."
      schoolMetrics = try await analyticsService.computeSchoolMetrics(for: districtId)

      // Fetch students needing attention
      loadingMessage = "Checking student alerts..."
      studentsNeedingAttention = try await analyticsService.fetchStudentsNeedingAttention(for: districtId, limit: 20)

      // Generate insights
      loadingMessage = "Generating insights..."
      insights = await analyticsService.generateInsights(for: metrics, schoolMetrics: schoolMetrics)

      print("[DistrictDashboardViewModel] Dashboard loaded successfully")
    } catch {
      errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
      print("[DistrictDashboardViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
    loadingMessage = ""
  }

  func refreshDashboard() async {
    guard let districtId = districtId else { return }
    await loadDashboard(districtId: districtId)
  }

  func applyFilter(_ newFilter: DistrictFilter) async {
    self.filter = newFilter
    await refreshDashboard()
  }

  // MARK: - Sample Data Loading

  func loadSampleData() {
    districtId = "demo-district-001"
    districtName = "Demo Unified School District"
    metrics = analyticsService.getSampleMetrics()
    schoolMetrics = analyticsService.getSampleSchoolMetrics()
    studentsNeedingAttention = analyticsService.getSampleAlerts()
    insights = [
      "Jefferson High School shows 12% improvement in engagement over last month",
      "3 students across the district require immediate counselor attention",
      "Form completion rate increased to 78% from 72% last quarter",
      "Lincoln Elementary has highest plan completion rate at 70%"
    ]
    print("[DistrictDashboardViewModel] Sample data loaded")
  }

  // MARK: - Export Functions

  func exportToCSV() async {
    await performExport { exportService in
      try await exportService.exportCSV(
        metrics: self.metrics,
        schoolMetrics: self.schoolMetrics,
        districtName: self.districtName
      )
    }
  }

  func exportToPDF() async {
    await performExport { exportService in
      try await exportService.exportPDF(
        metrics: self.metrics,
        schoolMetrics: self.schoolMetrics,
        insights: self.insights,
        districtName: self.districtName
      )
    }
  }

  func exportToJSON() async {
    await performExport { exportService in
      try await exportService.exportJSON(
        metrics: self.metrics,
        schoolMetrics: self.schoolMetrics,
        insights: self.insights,
        districtName: self.districtName
      )
    }
  }

  private func performExport(_ exportFunction: (DistrictExportService) async throws -> URL) async {
    isExporting = true
    errorMessage = nil

    do {
      let url = try await exportFunction(exportService)
      exportedFileURL = url
      print("[DistrictDashboardViewModel] Export successful: \(url.path)")
    } catch {
      errorMessage = "Export failed: \(error.localizedDescription)"
      print("[DistrictDashboardViewModel] Export error: \(errorMessage ?? "Unknown")")
    }

    isExporting = false
  }

  // MARK: - Computed Properties

  var hasData: Bool {
    metrics.totalStudents > 0
  }

  var criticalAlerts: [StudentNeedAlert] {
    studentsNeedingAttention.filter { $0.severity == .critical }
  }

  var highPriorityAlerts: [StudentNeedAlert] {
    studentsNeedingAttention.filter { $0.severity == .high || $0.severity == .critical }
  }

  var topPerformingSchool: SchoolMetrics? {
    schoolMetrics.max(by: { $0.engagementRate < $1.engagementRate })
  }

  var lowestPerformingSchool: SchoolMetrics? {
    schoolMetrics.min(by: { $0.engagementRate < $1.engagementRate })
  }
}
