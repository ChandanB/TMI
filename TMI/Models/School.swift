//
//  School.swift
//  TMI
//
//  Created for Phase 1: District Pilot
//

import FirebaseFirestore
import Foundation

// MARK: - School Model

struct School: Codable, Identifiable, Equatable, Sendable {
  @DocumentID var id: String?
  var name: String
  var districtId: String
  var schoolCode: String
  var address: String?
  var principal: String?
  var grades: [String]
  var studentCount: Int
  var staffCount: Int
  var createdAt: Date
  var isActive: Bool

  init(
    id: String? = nil,
    name: String,
    districtId: String,
    schoolCode: String,
    address: String? = nil,
    principal: String? = nil,
    grades: [String] = [],
    studentCount: Int = 0,
    staffCount: Int = 0,
    createdAt: Date = Date(),
    isActive: Bool = true
  ) {
    self.id = id
    self.name = name
    self.districtId = districtId
    self.schoolCode = schoolCode
    self.address = address
    self.principal = principal
    self.grades = grades
    self.studentCount = studentCount
    self.staffCount = staffCount
    self.createdAt = createdAt
    self.isActive = isActive
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case districtId
    case schoolCode
    case address
    case principal
    case grades
    case studentCount
    case staffCount
    case createdAt
    case isActive
  }
}

// MARK: - School Type Helper

extension School {
  enum SchoolType: String, CaseIterable {
    case elementary = "Elementary"
    case middle = "Middle School"
    case high = "High School"
    case k8 = "K-8"
    case k12 = "K-12"

    static func type(for grades: [String]) -> SchoolType {
      let gradeSet = Set(grades)
      let hasElementary = gradeSet.contains(where: { ["K", "1", "2", "3", "4", "5"].contains($0) })
      let hasMiddle = gradeSet.contains(where: { ["6", "7", "8"].contains($0) })
      let hasHigh = gradeSet.contains(where: { ["9", "10", "11", "12"].contains($0) })

      if hasElementary && hasMiddle && hasHigh {
        return .k12
      } else if hasElementary && hasMiddle {
        return .k8
      } else if hasHigh {
        return .high
      } else if hasMiddle {
        return .middle
      } else {
        return .elementary
      }
    }
  }

  var schoolType: SchoolType {
    SchoolType.type(for: grades)
  }
}

// MARK: - Sample Data

extension School {
  static let sampleSchools: [School] = [
    School(
      id: "school-001",
      name: "Lincoln Elementary",
      districtId: "demo-district-001",
      schoolCode: "LES-001",
      address: "123 Main St, Demo City, CA 94000",
      principal: "Ms. Sarah Johnson",
      grades: ["K", "1", "2", "3", "4", "5"],
      studentCount: 450,
      staffCount: 35
    ),
    School(
      id: "school-002",
      name: "Washington Middle School",
      districtId: "demo-district-001",
      schoolCode: "WMS-001",
      address: "456 Oak Ave, Demo City, CA 94001",
      principal: "Mr. Michael Chen",
      grades: ["6", "7", "8"],
      studentCount: 600,
      staffCount: 48
    ),
    School(
      id: "school-003",
      name: "Jefferson High School",
      districtId: "demo-district-001",
      schoolCode: "JHS-001",
      address: "789 Elm Blvd, Demo City, CA 94002",
      principal: "Dr. Emily Rodriguez",
      grades: ["9", "10", "11", "12"],
      studentCount: 1200,
      staffCount: 95
    )
  ]
}
