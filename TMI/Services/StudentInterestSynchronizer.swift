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

    private let planService = TMIPlanService()
    private let studentService = StudentService()

    private init() {}

    /// Synchronize student interests across all their TMI Plans
    /// - Parameters:
    ///   - studentId: The ID of the student whose interests changed
    ///   - newInterests: The updated list of interests for the student
    /// - Throws: Firestore or network errors
    func synchronizeInterests(for studentId: String, newInterests: [Interest]) async throws {
        print("[StudentInterestSync] 🔄 Starting synchronization for student: \(studentId)")
        print("[StudentInterestSync] 📝 New interests count: \(newInterests.count)")

        // 1. Fetch all plans containing this student
        let allPlans = try await planService.fetchPlans()
        let studentPlans = allPlans.filter { plan in
            plan.students.contains(where: { $0.id == studentId })
        }

        print("[StudentInterestSync] 📋 Found \(studentPlans.count) plans to update")

        guard !studentPlans.isEmpty else {
            print("[StudentInterestSync] ⚠️ No plans found for student")
            return
        }

        // 2. Update each plan's interests
        for plan in studentPlans {
            do {
                var updatedPlan = plan

                // Strategy: Merge new interests with existing plan-specific interests
                // This preserves any interests manually added to the plan
                let existingInterestIds = Set(plan.interests.compactMap { $0.id })
                let newUniqueInterests = newInterests.filter { interest in
                    guard let interestId = interest.id else { return false }
                    return !existingInterestIds.contains(interestId)
                }

                // Add new interests to the plan
                updatedPlan.interests = plan.interests + newUniqueInterests
                updatedPlan.lastUpdated = Date()

                print("[StudentInterestSync] ✏️ Updating plan '\(plan.title)' - adding \(newUniqueInterests.count) new interests")

                // Save updated plan to Firestore
                _ = try await planService.updatePlan(updatedPlan)

                print("[StudentInterestSync] ✅ Successfully updated plan '\(plan.title)'")

            } catch {
                print("[StudentInterestSync] ❌ Error updating plan '\(plan.title)': \(error.localizedDescription)")
                // Continue with other plans even if one fails
            }
        }

        // 3. Post notification for UI refresh
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentInterestsUpdated"),
            object: nil,
            userInfo: ["studentId": studentId, "interestCount": newInterests.count]
        )

        print("[StudentInterestSync] 🎉 Synchronization complete - posted notification")
    }

    /// Removes an interest from all plans associated with a student
    /// - Parameters:
    ///   - interest: The interest to remove
    ///   - studentId: The student whose plans should be updated
    func removeInterest(_ interest: Interest, fromPlansFor studentId: String) async throws {
        print("[StudentInterestSync] 🗑️ Removing interest '\(interest.name)' for student: \(studentId)")

        guard let interestId = interest.id else {
            print("[StudentInterestSync] ⚠️ Interest has no ID, cannot remove")
            return
        }

        // Fetch all plans for this student
        let allPlans = try await planService.fetchPlans()
        let studentPlans = allPlans.filter { plan in
            plan.students.contains(where: { $0.id == studentId })
        }

        // Remove the interest from each plan
        for plan in studentPlans {
            var updatedPlan = plan
            updatedPlan.interests.removeAll { $0.id == interestId }
            updatedPlan.lastUpdated = Date()

            _ = try await planService.updatePlan(updatedPlan)
            print("[StudentInterestSync] ✅ Removed interest from plan '\(plan.title)'")
        }

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("StudentInterestsUpdated"),
            object: nil,
            userInfo: ["studentId": studentId, "action": "remove"]
        )
    }

    /// Fetch current interests for a student directly from Firestore
    /// This ensures we always have the latest data
    /// - Parameter studentId: The student ID
    /// - Returns: Array of current interests
    func fetchCurrentStudentInterests(for studentId: String) async throws -> [Interest] {
        guard let student = try await studentService.getStudent(by: studentId) else {
            print("[StudentInterestSync] ⚠️ Student not found: \(studentId)")
            return []
        }

        print("[StudentInterestSync] 📖 Fetched \(student.interests.count) interests for student '\(student.name)'")
        return student.interests
    }

    /// Get all students for a specific plan with their current interests
    /// - Parameter planId: The plan ID
    /// - Returns: Array of students with up-to-date interests
    func fetchStudentsWithCurrentInterests(for planId: String) async throws -> [Student] {
        guard let plan = try await planService.fetchPlan(byId: planId) else {
            print("[StudentInterestSync] ⚠️ Plan not found: \(planId)")
            return []
        }

        var studentsWithCurrentInterests: [Student] = []

        for student in plan.students {
            guard let studentId = student.id else { continue }

            if let currentStudent = try await studentService.getStudent(by: studentId) {
                studentsWithCurrentInterests.append(currentStudent)
            } else {
                // Fall back to the student data stored in the plan
                studentsWithCurrentInterests.append(student)
            }
        }

        print("[StudentInterestSync] 📖 Fetched \(studentsWithCurrentInterests.count) students with current interests")
        return studentsWithCurrentInterests
    }
}
