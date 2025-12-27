//
//  DistrictAnalytics.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import FirebaseFirestore
import Foundation

// MARK: - District Analytics (Daily Aggregation)

struct DistrictAnalytics: Codable, Identifiable, Equatable, Sendable {
  @DocumentID var id: String?
  var districtId: String
  var date: Date
  var metrics: DistrictMetrics
  var schoolMetrics: [String: SchoolMetrics] // schoolId -> metrics
  var topInsights: [String]
  var generatedAt: Date

  init(
    id: String? = nil,
    districtId: String,
    date: Date = Date(),
    metrics: DistrictMetrics = DistrictMetrics(),
    schoolMetrics: [String: SchoolMetrics] = [:],
    topInsights: [String] = [],
    generatedAt: Date = Date()
  ) {
    self.id = id
    self.districtId = districtId
    self.date = date
    self.metrics = metrics
    self.schoolMetrics = schoolMetrics
    self.topInsights = topInsights
    self.generatedAt = generatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case districtId
    case date
    case metrics
    case schoolMetrics
    case topInsights
    case generatedAt
  }
}

// MARK: - District Filter

struct DistrictFilter: Equatable, Sendable {
  var schoolId: String?
  var grade: String?
  var dateRange: DateRange?

  enum DateRange: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisQuarter = "This Quarter"
    case thisYear = "This Year"
    case custom = "Custom"

    var startDate: Date {
      let calendar = Calendar.current
      let now = Date()

      switch self {
      case .today:
        return calendar.startOfDay(for: now)
      case .thisWeek:
        return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
      case .thisMonth:
        return calendar.dateInterval(of: .month, for: now)?.start ?? now
      case .thisQuarter:
          let month = calendar.component(.month, from: now)
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: now)
        components.month = quarterMonth
        components.day = 1
        return calendar.date(from: components) ?? now
      case .thisYear:
        return calendar.dateInterval(of: .year, for: now)?.start ?? now
      case .custom:
        return now
      }
    }

    var endDate: Date {
      Date()
    }
  }
}

// MARK: - Export Format

enum DistrictExportFormat: String, CaseIterable {
  case pdf = "PDF"
  case csv = "CSV"
  case json = "JSON"

  var icon: String {
    switch self {
    case .pdf: return "doc.richtext"
    case .csv: return "tablecells"
    case .json: return "curlybraces"
    }
  }

  var fileExtension: String {
    switch self {
    case .pdf: return "pdf"
    case .csv: return "csv"
    case .json: return "json"
    }
  }
}

// MARK: - Sample Data

extension DistrictAnalytics {
  static let sample = DistrictAnalytics(
    id: "2024-01-15",
    districtId: "demo-district-001",
    date: Date(),
    metrics: .sample,
    schoolMetrics: Dictionary(uniqueKeysWithValues: SchoolMetrics.sampleSchools.map { ($0.schoolId, $0) }),
    topInsights: [
      "Jefferson High School shows 12% improvement in engagement over last month",
      "3 students across the district require immediate counselor attention",
      "Form completion rate increased to 78% from 72% last quarter",
      "Lincoln Elementary has highest plan completion rate at 70%"
    ],
    generatedAt: Date()
  )
}
