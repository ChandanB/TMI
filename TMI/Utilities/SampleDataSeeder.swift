//
//  SampleDataSeeder.swift
//  TMI
//
//  Created for Phase 1: District Pilot
//

import FirebaseFirestore
import Foundation

#if DEBUG
@MainActor
@Observable
final class SampleDataSeeder {
  static let shared = SampleDataSeeder()
  private let db = Firestore.firestore()
  
  var isSeeding = false
  var seedingStatus: String = ""
  
  func seedDistrictData() async throws {
    guard !isSeeding else { return }
    
    isSeeding = true
    seedingStatus = "Starting seed process..."
    
    do {
      // 1. Create District
      seedingStatus = "Creating district..."
      let district = District.sampleDistrict
      try db.collection(FirestoreCollection.districts.rawValue)
        .document(district.id ?? "demo-district-001")
        .setData(from: district)
      
      // 2. Create Schools
      seedingStatus = "Creating schools..."
      for school in School.sampleSchools {
        let schoolRef = db.collection(FirestoreCollection.districts.rawValue)
          .document(district.id ?? "demo-district-001")
          .collection(FirestoreCollection.schools.rawValue)
          .document(school.id ?? UUID().uuidString)
        
        try schoolRef.setData(from: school)
      }
      
      // 3. Create District Admin User (if needed for testing)
      // Note: This would typically be done via Auth, this is just a Firestore doc placeholder
      // for local testing/emulator if Auth record exists.
      
      seedingStatus = "Seed complete!"
      try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay to read status
      isSeeding = false
      
    } catch {
      seedingStatus = "Error: \(error.localizedDescription)"
      isSeeding = false
      throw error
    }
  }
}
#endif
