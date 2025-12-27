//
//  District.swift
//  TMI
//
//  Created for Phase 1: District Pilot
//

import FirebaseFirestore
import Foundation

// MARK: - District Model

struct District: Codable, Identifiable, Equatable, Sendable {
  @DocumentID var id: String?
  var name: String
  var districtCode: String
  var state: String
  var region: String?
  var createdAt: Date
  var settings: DistrictSettings
  var metadata: [String: String]

  init(
    id: String? = nil,
    name: String,
    districtCode: String,
    state: String,
    region: String? = nil,
    createdAt: Date = Date(),
    settings: DistrictSettings = DistrictSettings(),
    metadata: [String: String] = [:]
  ) {
    self.id = id
    self.name = name
    self.districtCode = districtCode
    self.state = state
    self.region = region
    self.createdAt = createdAt
    self.settings = settings
    self.metadata = metadata
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case districtCode
    case state
    case region
    case createdAt
    case settings
    case metadata
  }
}

// MARK: - District Settings

struct DistrictSettings: Codable, Equatable, Sendable {
  var schoolYearStart: Date?
  var gradeLevels: [String]
  var allowDataSharing: Bool
  var requireApprovalForPlans: Bool

  init(
    schoolYearStart: Date? = nil,
    gradeLevels: [String] = ["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"],
    allowDataSharing: Bool = true,
    requireApprovalForPlans: Bool = true
  ) {
    self.schoolYearStart = schoolYearStart
    self.gradeLevels = gradeLevels
    self.allowDataSharing = allowDataSharing
    self.requireApprovalForPlans = requireApprovalForPlans
  }
}

// MARK: - Sample Data

extension District {
  static let sampleDistrict = District(
    id: "demo-district-001",
    name: "Demo Unified School District",
    districtCode: "DUSD-001",
    state: "CA",
    region: "Bay Area",
    settings: DistrictSettings(
      schoolYearStart: Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 15))
    ),
    metadata: [
      "superintendent": "Dr. Jane Smith",
      "phone": "(555) 123-4567",
      "website": "https://demo-district.edu"
    ]
  )
}
