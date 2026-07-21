//
//  StudentInterestService.swift
//  TMI
//
//  Student Interest Edge Service
//  Manages student-interest relationships (edges between students and global interests)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class StudentInterestService {
    static let shared = StudentInterestService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum StudentInterestError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case userNotAuthenticated
        case invalidStudentId
        case invalidInterestId

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch student interests: \(message)"
            case .saveFailed(let message):
                return "Failed to save student interest: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete student interest: \(message)"
            case .userNotAuthenticated:
                return "User not authenticated"
            case .invalidStudentId:
                return "Invalid student ID"
            case .invalidInterestId:
                return "Invalid interest ID"
            }
        }
    }

    // MARK: - Collection Access

    private func studentInterestsCollection(for studentId: String) -> CollectionReference {
        db.collection("students").document(studentId).collection("studentInterests")
    }

    // MARK: - Fetch Operations

    /// Get all interests for a specific student
    func getStudentInterests(studentId: String) async throws -> [StudentInterest] {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        do {
            let interests = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                let querySnapshot = try await self.studentInterestsCollection(for: studentId).getDocuments()
                return querySnapshot.documents.compactMap { document -> StudentInterest? in
                    StudentInterest.fromFirestore(id: document.documentID, data: document.data())
                }
            }

            print("[StudentInterestService] Fetched \(interests.count) interests for student \(studentId)")
            return interests
        } catch {
            print("[StudentInterestService] Error fetching student interests: \(error.localizedDescription)")
            throw StudentInterestError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get a specific student interest edge
    func getStudentInterest(studentId: String, interestId: String) async throws -> StudentInterest? {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        guard !interestId.isEmpty else {
            throw StudentInterestError.invalidInterestId
        }

        do {
            return try await withTimeout(seconds: 10) { @MainActor @Sendable in
                let document = try await self.studentInterestsCollection(for: studentId)
                    .document(interestId)
                    .getDocument()

                guard document.exists, let data = document.data() else {
                    return nil
                }

                return StudentInterest.fromFirestore(id: document.documentID, data: data)
            }
        } catch {
            print("[StudentInterestService] Error fetching student interest: \(error.localizedDescription)")
            throw StudentInterestError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get high-affinity interests for a student (level 4-5)
    func getHighAffinityInterests(studentId: String) async throws -> [StudentInterest] {
        let allInterests = try await getStudentInterests(studentId: studentId)
        return allInterests.filter { $0.isHighAffinity }
    }

    /// Get all student IDs that have a specific interest (Collection Group Query)
    func getStudentIdsWithInterest(interestId: String) async throws -> [String] {
        guard !interestId.isEmpty else {
            throw StudentInterestError.invalidInterestId
        }
        
        do {
            // Use a collection group query to search across all studentInterests subcollections
            let studentIds = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                let querySnapshot = try await self.db.collectionGroup("studentInterests")
                    .whereField("interestId", isEqualTo: interestId)
                    .getDocuments()

                // Extract unique student IDs from the found documents
                return querySnapshot.documents.compactMap { document -> String? in
                    // The document data should contain studentId, or we can parse the parent path
                    if let data = try? document.data(as: StudentInterest.self) {
                        return data.studentId
                    }
                    // Fallback to parsing path if data is missing studentId (unlikely with this model)
                    let pathComponents = document.reference.path.components(separatedBy: "/")
                    if pathComponents.count >= 3 && pathComponents[pathComponents.count - 3] == "students" {
                        return pathComponents[pathComponents.count - 2]
                    }
                    return nil
                }
            }
            
            return Array(Set(studentIds)) // Return unique IDs
            
        } catch {
            print("[StudentInterestService] Error fetching students with interest: \(error.localizedDescription)")
            throw StudentInterestError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Write Operations

    /// Save survey results for a student
    /// Results format: [interestId: level]
    func saveSurveyResults(studentId: String, results: [String: Int]) async throws {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw StudentInterestError.userNotAuthenticated
        }

        print("[StudentInterestService] Saving survey results for student \(studentId): \(results.count) interests")

        var successCount = 0
        var failureCount = 0

        for (interestId, level) in results {
            do {
                let studentInterest = StudentInterest(
                    id: interestId,  // Use interestId as the document ID for easy lookup
                    studentId: studentId,
                    interestId: interestId,
                    level: level,
                    source: .survey,
                    updatedAt: Date(),
                    createdBy: uid
                )

                try await saveStudentInterest(studentInterest)
                successCount += 1
            } catch {
                print("[StudentInterestService] Failed to save interest \(interestId): \(error.localizedDescription)")
                failureCount += 1
            }
        }

        print("[StudentInterestService] Survey save complete: \(successCount) successful, \(failureCount) failed")

        if failureCount > 0 {
            throw StudentInterestError.saveFailed("\(failureCount) interests failed to save")
        }
    }

    /// Add or update a single student interest
    func addInterest(
        studentId: String,
        interestId: String,
        level: Int,
        source: StudentInterest.StudentInterestSource
    ) async throws {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        guard !interestId.isEmpty else {
            throw StudentInterestError.invalidInterestId
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw StudentInterestError.userNotAuthenticated
        }

        let studentInterest = StudentInterest(
            id: interestId,
            studentId: studentId,
            interestId: interestId,
            level: level,
            source: source,
            updatedAt: Date(),
            createdBy: uid
        )

        try await saveStudentInterest(studentInterest)
    }

    /// Update the level of a student interest
    func updateInterestLevel(studentId: String, interestId: String, level: Int) async throws {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        guard !interestId.isEmpty else {
            throw StudentInterestError.invalidInterestId
        }

        do {
            try await studentInterestsCollection(for: studentId)
                .document(interestId)
                .updateData([
                    "level": max(1, min(5, level)),
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[StudentInterestService] Updated interest level for \(interestId)")
        } catch {
            print("[StudentInterestService] Error updating interest level: \(error.localizedDescription)")
            throw StudentInterestError.saveFailed(error.localizedDescription)
        }
    }

    /// Remove a student interest
    func removeInterest(studentId: String, interestId: String) async throws {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        guard !interestId.isEmpty else {
            throw StudentInterestError.invalidInterestId
        }

        do {
            try await studentInterestsCollection(for: studentId)
                .document(interestId)
                .delete()

            print("[StudentInterestService] Removed interest \(interestId) from student \(studentId)")
        } catch {
            print("[StudentInterestService] Error removing interest: \(error.localizedDescription)")
            throw StudentInterestError.deleteFailed(error.localizedDescription)
        }
    }

    /// Clear all survey-generated interests while preserving manually added ones
    func clearSurveyInterests(studentId: String) async throws {
        guard !studentId.isEmpty else {
            throw StudentInterestError.invalidStudentId
        }

        print("[StudentInterestService] Clearing survey interests for student \(studentId)")

        do {
            // Query for survey-generated interests only
            let snapshot = try await studentInterestsCollection(for: studentId)
                .whereField("source", isEqualTo: StudentInterest.StudentInterestSource.survey.rawValue)
                .getDocuments()

            // Delete each survey interest
            for document in snapshot.documents {
                try await document.reference.delete()
            }

            print("[StudentInterestService] Cleared \(snapshot.documents.count) survey-generated interests")
        } catch {
            print("[StudentInterestService] Error clearing survey interests: \(error.localizedDescription)")
            throw StudentInterestError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Save or update a student interest edge
    private func saveStudentInterest(_ studentInterest: StudentInterest) async throws {
        do {
            let data = studentInterest.toFirestoreData()
            let docId = studentInterest.interestId  // Use interestId as document ID

            try await studentInterestsCollection(for: studentInterest.studentId)
                .document(docId)
                .setData(data, merge: true)

            print("[StudentInterestService] Saved student interest: \(studentInterest.interestId)")
        } catch {
            print("[StudentInterestService] Error saving student interest: \(error.localizedDescription)")
            throw StudentInterestError.saveFailed(error.localizedDescription)
        }
    }

}
