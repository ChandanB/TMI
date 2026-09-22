//
//  District.swift
//  TMI
//
//  Created for Phase 1: District Pilot
//

@preconcurrency import FirebaseFirestore
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
  var organizationKind: OrganizationKind
  /// Organization-wide default program; sites may override it.
  var programType: ProgramType

  init(
    id: String? = nil,
    name: String,
    districtCode: String,
    state: String,
    region: String? = nil,
    createdAt: Date = Date(),
    settings: DistrictSettings = DistrictSettings(),
    metadata: [String: String] = [:],
    organizationKind: OrganizationKind = .schoolDistrict,
    programType: ProgramType = .k12
  ) {
    self.id = id
    self.name = name
    self.districtCode = districtCode
    self.state = state
    self.region = region
    self.createdAt = createdAt
    self.settings = settings
    self.metadata = metadata
    self.organizationKind = organizationKind
    self.programType = programType
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
    case organizationKind
    case programType
  }

  private enum CanonicalKeys: String, CodingKey {
    case districtID
    case updatedAt
  }

  /// Decodes both the legacy shape and the canonical server-written shape
  /// (`{districtID, name, organizationKind?, programType?, updatedAt}`).
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let canonical = try decoder.container(keyedBy: CanonicalKeys.self)
    _id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
    let districtID = try canonical.decodeIfPresent(String.self, forKey: .districtID)
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? districtID ?? ""
    districtCode = try container.decodeIfPresent(String.self, forKey: .districtCode) ?? districtID ?? ""
    state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
    region = try container.decodeIfPresent(String.self, forKey: .region)
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
      ?? canonical.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    settings = (try? container.decodeIfPresent(DistrictSettings.self, forKey: .settings)) ?? DistrictSettings()
    metadata = (try? container.decodeIfPresent([String: String].self, forKey: .metadata)) ?? [:]
    organizationKind = (try? container.decodeIfPresent(OrganizationKind.self, forKey: .organizationKind)) ?? .schoolDistrict
    programType = (try? container.decodeIfPresent(ProgramType.self, forKey: .programType)) ?? .k12
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
