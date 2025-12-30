//
//  StudentInterestSynchronizer.swift
//  TMI
//
//  Synchronizes student interests across all associated TMI Plans
//  Ensures plans always reflect current student interests
//

import Foundation

/// Service responsible for synchronizing student interests across all their TMI Plans
@MainActor
final class StudentInterestSynchronizer {
    static let shared = StudentInterestSynchronizer()

    // MARK: - Dependencies
    private let planService = TMIPlanService.shared
    private let studentService = StudentService()
    private let studentInterestService = StudentInterestService.shared
    private let interestLibraryService = InterestLibraryService.shared

    private init() {}

    /// Deprecated: Student interests are no longer synced to TMI Plans.
    /// This function now only posts a notification for UI updates.
    @available(*, deprecated, message: "Interests are no longer duplicated to Plans. Use StudentInterestService directly.")
    func synchronizeInterests(for studentId: String, newInterests: [Interest]) async throws {
        print("[StudentInterestSync] 🔄 Sync requested for student: \(studentId) (Deprecated - No-op on Plans)")
        
        // Post notification for UI refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentInterestsUpdated"),
            object: nil,
            userInfo: ["studentId": studentId, "interestCount": newInterests.count]
        )
    }

    /// Deprecated: Student interests are no longer synced to TMI Plans.
    func removeInterest(_ interest: Interest, fromPlansFor studentId: String) async throws {
         print("[StudentInterestSync] 🗑️ Remove interest requested (Deprecated - No-op)")
         // Logic removed to prevent modifying plans based on student interest changes
         
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentInterestsUpdated"),
            object: nil,
            userInfo: ["studentId": studentId, "action": "remove"]
        )
    }

    /// Fetch current interests for a student from Edge Collection + Global Library
    /// - Parameter studentId: The student ID
    /// - Returns: Array of current interests
    func fetchCurrentStudentInterests(for studentId: String) async throws -> [Interest] {
        guard !studentId.isEmpty else { return [] }
        
        do {
            let edges = try await studentInterestService.getStudentInterests(studentId: studentId)
            var interests: [Interest] = []
            
            for edge in edges {
                if let interest = try await interestLibraryService.fetchInterest(id: edge.interestId) {
                    interests.append(interest)
                }
            }
            
            print("[StudentInterestSync] 📖 Fetched \(interests.count) interests for student \(studentId) from edges")
            return interests
        } catch {
            print("[StudentInterestSync] Error fetching interests: \(error)")
            return []
        }
    }

    /// Get all students for a specific plan.
    /// Note: Does NOT modify student objects to include interests (as Student.interests is deprecated).
    /// UI should fetch interests using StudentInterestService.
    func fetchStudentsWithCurrentInterests(for planId: String) async throws -> [Student] {
        guard let plan = try await planService.fetchPlan(byId: planId) else {
            print("[StudentInterestSync] ⚠️ Plan not found: \(planId)")
            return []
        }

        var students: [Student] = []

        for student in plan.students {
            guard let studentId = student.id else { continue }
            // Refresh student data which might include updated engagement/etc, but NOT interests
            if let currentStudent = try await studentService.getStudent(by: studentId) {
                students.append(currentStudent)
            } else {
                students.append(student)
            }
        }
        
        return students
    }
}
