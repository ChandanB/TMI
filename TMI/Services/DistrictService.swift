//
//  DistrictService.swift
//  TMI
//
//  Created for Phase 1: District Pilot
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing district and school data operations with Firestore
@Observable
class DistrictService {
  private let db = Firestore.firestore()

  // MARK: - Collection References

  private var districtsCollection: CollectionReference {
    db.collection("districts")
  }

  private func schoolsCollection(for districtId: String) -> CollectionReference {
    districtsCollection.document(districtId).collection("schools")
  }

  // MARK: - District Operations

  /// Fetch a district by ID
  func fetchDistrict(id: String) async throws -> District {
    do {
      print("[DistrictService] Fetching district: \(id)")
      let document = try await districtsCollection.document(id).getDocument()

      guard document.exists else {
        throw DistrictServiceError.districtNotFound(id)
      }

      let district = try document.data(as: District.self)
      print("[DistrictService] Successfully fetched district: \(district.name)")
      return district
    } catch let error as DistrictServiceError {
      throw error
    } catch {
      print("[DistrictService] Error fetching district: \(error)")
      throw DistrictServiceError.fetchFailed(error.localizedDescription)
    }
  }

  /// Fetch all districts
  func fetchAllDistricts() async throws -> [District] {
    do {
      print("[DistrictService] Fetching all districts...")
      let querySnapshot = try await districtsCollection.getDocuments()

      let districts: [District] = try querySnapshot.documents.compactMap { document in
        try document.data(as: District.self)
      }

      print("[DistrictService] Successfully fetched \(districts.count) districts")
      return districts
    } catch {
      print("[DistrictService] Error fetching districts: \(error)")
      throw DistrictServiceError.fetchFailed(error.localizedDescription)
    }
  }

  /// Create a new district
  func createDistrict(_ district: District) async throws -> District {
    do {
      print("[DistrictService] Creating district: \(district.name)")

      let documentRef = try await districtsCollection.addDocument(data: [
        "name": district.name,
        "districtCode": district.districtCode,
        "state": district.state,
        "region": district.region ?? "",
        "createdAt": district.createdAt,
        "settings": [
          "schoolYearStart": district.settings.schoolYearStart ?? Date(),
          "gradeLevels": district.settings.gradeLevels,
          "allowDataSharing": district.settings.allowDataSharing,
          "requireApprovalForPlans": district.settings.requireApprovalForPlans
        ],
        "metadata": district.metadata
      ])

      print("[DistrictService] District created with ID: \(documentRef.documentID)")

      // Return district with updated ID
      var newDistrict = district
      newDistrict.id = documentRef.documentID
      return newDistrict
    } catch {
      print("[DistrictService] Error creating district: \(error)")
      throw DistrictServiceError.createFailed(error.localizedDescription)
    }
  }

  /// Update an existing district
  func updateDistrict(_ district: District) async throws {
    guard let id = district.id else {
      throw DistrictServiceError.invalidDistrict("District ID is missing")
    }

    do {
      print("[DistrictService] Updating district: \(id)")
      try await districtsCollection.document(id).setData([
        "name": district.name,
        "districtCode": district.districtCode,
        "state": district.state,
        "region": district.region ?? "",
        "settings": [
          "schoolYearStart": district.settings.schoolYearStart ?? Date(),
          "gradeLevels": district.settings.gradeLevels,
          "allowDataSharing": district.settings.allowDataSharing,
          "requireApprovalForPlans": district.settings.requireApprovalForPlans
        ],
        "metadata": district.metadata
      ], merge: true)

      print("[DistrictService] District updated successfully")
    } catch {
      print("[DistrictService] Error updating district: \(error)")
      throw DistrictServiceError.updateFailed(error.localizedDescription)
    }
  }

  // MARK: - School Operations

  /// Fetch all schools in a district
  func fetchSchools(for districtId: String) async throws -> [School] {
    do {
      print("[DistrictService] Fetching schools for district: \(districtId)")
      let querySnapshot = try await schoolsCollection(for: districtId).getDocuments()

      let schools: [School] = try querySnapshot.documents.compactMap { document in
        try document.data(as: School.self)
      }

      print("[DistrictService] Successfully fetched \(schools.count) schools")
      return schools
    } catch {
      print("[DistrictService] Error fetching schools: \(error)")
      throw DistrictServiceError.fetchFailed(error.localizedDescription)
    }
  }

  /// Fetch a specific school
  func fetchSchool(id: String, districtId: String) async throws -> School {
    do {
      print("[DistrictService] Fetching school: \(id) in district: \(districtId)")
      let document = try await schoolsCollection(for: districtId).document(id).getDocument()

      guard document.exists else {
        throw DistrictServiceError.schoolNotFound(id)
      }

      let school = try document.data(as: School.self)
      print("[DistrictService] Successfully fetched school: \(school.name)")
      return school
    } catch let error as DistrictServiceError {
      throw error
    } catch {
      print("[DistrictService] Error fetching school: \(error)")
      throw DistrictServiceError.fetchFailed(error.localizedDescription)
    }
  }

  /// Create a new school
  func createSchool(_ school: School) async throws -> School {
    do {
      print("[DistrictService] Creating school: \(school.name)")

      let documentRef = try await schoolsCollection(for: school.districtId).addDocument(data: [
        "name": school.name,
        "districtId": school.districtId,
        "schoolCode": school.schoolCode,
        "address": school.address ?? "",
        "principal": school.principal ?? "",
        "grades": school.grades,
        "studentCount": school.studentCount,
        "staffCount": school.staffCount,
        "createdAt": school.createdAt,
        "isActive": school.isActive
      ])

      print("[DistrictService] School created with ID: \(documentRef.documentID)")

      // Return school with updated ID
      var newSchool = school
      newSchool.id = documentRef.documentID
      return newSchool
    } catch {
      print("[DistrictService] Error creating school: \(error)")
      throw DistrictServiceError.createFailed(error.localizedDescription)
    }
  }

  /// Update an existing school
  func updateSchool(_ school: School) async throws {
    guard let id = school.id else {
      throw DistrictServiceError.invalidSchool("School ID is missing")
    }

    do {
      print("[DistrictService] Updating school: \(id)")
      try await schoolsCollection(for: school.districtId).document(id).setData([
        "name": school.name,
        "districtId": school.districtId,
        "schoolCode": school.schoolCode,
        "address": school.address ?? "",
        "principal": school.principal ?? "",
        "grades": school.grades,
        "studentCount": school.studentCount,
        "staffCount": school.staffCount,
        "isActive": school.isActive
      ], merge: true)

      print("[DistrictService] School updated successfully")
    } catch {
      print("[DistrictService] Error updating school: \(error)")
      throw DistrictServiceError.updateFailed(error.localizedDescription)
    }
  }

  /// Delete a school
  func deleteSchool(id: String, districtId: String) async throws {
    do {
      print("[DistrictService] Deleting school: \(id)")
      try await schoolsCollection(for: districtId).document(id).delete()
      print("[DistrictService] School deleted successfully")
    } catch {
      print("[DistrictService] Error deleting school: \(error)")
      throw DistrictServiceError.deleteFailed(error.localizedDescription)
    }
  }

  // MARK: - Helper Methods

  /// Seed sample district and schools for development
  func seedSampleData() async throws {
    print("[DistrictService] Seeding sample data...")

    // Create sample district
    let district = try await createDistrict(District.sampleDistrict)

    // Create sample schools
    for var school in School.sampleSchools {
      school.districtId = district.id ?? "demo-district-001"
      _ = try await createSchool(school)
    }

    print("[DistrictService] Sample data seeded successfully")
  }
}

// MARK: - Error Handling

enum DistrictServiceError: Error, LocalizedError {
  case districtNotFound(String)
  case schoolNotFound(String)
  case invalidDistrict(String)
  case invalidSchool(String)
  case fetchFailed(String)
  case createFailed(String)
  case updateFailed(String)
  case deleteFailed(String)

  var errorDescription: String? {
    switch self {
    case .districtNotFound(let id):
      return "District not found: \(id)"
    case .schoolNotFound(let id):
      return "School not found: \(id)"
    case .invalidDistrict(let reason):
      return "Invalid district: \(reason)"
    case .invalidSchool(let reason):
      return "Invalid school: \(reason)"
    case .fetchFailed(let message):
      return "Failed to fetch: \(message)"
    case .createFailed(let message):
      return "Failed to create: \(message)"
    case .updateFailed(let message):
      return "Failed to update: \(message)"
    case .deleteFailed(let message):
      return "Failed to delete: \(message)"
    }
  }
}
