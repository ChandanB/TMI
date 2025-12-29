//
//  StudentCareerService.swift
//  TMI
//
//  Student Career State Edge Service
//  Manages student-career relationships (edges between students and global careers)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class StudentCareerService {
    static let shared = StudentCareerService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum StudentCareerError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case userNotAuthenticated
        case invalidStudentId
        case invalidCareerId

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch student careers: \(message)"
            case .saveFailed(let message):
                return "Failed to save student career: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete student career: \(message)"
            case .userNotAuthenticated:
                return "User not authenticated"
            case .invalidStudentId:
                return "Invalid student ID"
            case .invalidCareerId:
                return "Invalid career ID"
            }
        }
    }

    // MARK: - Collection Access

    private func studentCareersCollection(for studentId: String) -> CollectionReference {
        db.collection("students").document(studentId).collection("careerState")
    }

    // MARK: - Fetch Operations

    /// Get all careers for a specific student
    func getStudentCareers(studentId: String) async throws -> [StudentCareerState] {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        do {
            let querySnapshot = try await withTimeout(seconds: 10) {
                try await self.studentCareersCollection(for: studentId).getDocuments()
            }

            let careers = querySnapshot.documents.compactMap { document -> StudentCareerState? in
                StudentCareerState.fromFirestore(id: document.documentID, data: document.data())
            }

            print("[StudentCareerService] Fetched \(careers.count) careers for student \(studentId)")
            return careers
        } catch {
            print("[StudentCareerService] Error fetching student careers: \(error.localizedDescription)")
            throw StudentCareerError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get a specific student career state
    func getStudentCareer(studentId: String, careerId: String) async throws -> StudentCareerState? {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            let document = try await withTimeout(seconds: 10) {
                try await self.studentCareersCollection(for: studentId).document(careerId).getDocument()
            }

            guard document.exists, let data = document.data() else {
                return nil
            }

            return StudentCareerState.fromFirestore(id: document.documentID, data: data)
        } catch {
            print("[StudentCareerService] Error fetching student career: \(error.localizedDescription)")
            throw StudentCareerError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get favorite careers for a student
    func getFavoriteCareers(studentId: String) async throws -> [StudentCareerState] {
        let allCareers = try await getStudentCareers(studentId: studentId)
        return allCareers.filter { $0.isFavorite }
    }

    /// Get careers by status for a student
    func getCareers(studentId: String, status: StudentCareerState.CareerStatus) async throws -> [StudentCareerState] {
        let allCareers = try await getStudentCareers(studentId: studentId)
        return allCareers.filter { $0.status == status }
    }

    /// Get actively pursued careers (interested or pursuing)
    func getActiveCareers(studentId: String) async throws -> [StudentCareerState] {
        let allCareers = try await getStudentCareers(studentId: studentId)
        return allCareers.filter { $0.isActivePursuit }
    }

    // MARK: - Write Operations

    /// Add or update a student career state
    func addCareer(
        studentId: String,
        careerId: String,
        status: StudentCareerState.CareerStatus,
        progress: Double = 0.0,
        isFavorite: Bool = false
    ) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw StudentCareerError.userNotAuthenticated
        }

        let careerState = StudentCareerState(
            id: careerId,
            studentId: studentId,
            careerId: careerId,
            status: status,
            progress: progress,
            isFavorite: isFavorite,
            lastViewedAt: Date(),
            addedAt: Date(),
            updatedAt: Date(),
            createdBy: uid
        )

        try await saveStudentCareer(careerState)
    }

    /// Update career status
    func updateCareerStatus(studentId: String, careerId: String, status: StudentCareerState.CareerStatus) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            try await studentCareersCollection(for: studentId)
                .document(careerId)
                .updateData([
                    "status": status.rawValue,
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[StudentCareerService] Updated career status for \(careerId)")
        } catch {
            print("[StudentCareerService] Error updating career status: \(error.localizedDescription)")
            throw StudentCareerError.saveFailed(error.localizedDescription)
        }
    }

    /// Update career progress
    func updateCareerProgress(studentId: String, careerId: String, progress: Double) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            let clampedProgress = max(0.0, min(1.0, progress))
            try await studentCareersCollection(for: studentId)
                .document(careerId)
                .updateData([
                    "progress": clampedProgress,
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[StudentCareerService] Updated career progress for \(careerId)")
        } catch {
            print("[StudentCareerService] Error updating career progress: \(error.localizedDescription)")
            throw StudentCareerError.saveFailed(error.localizedDescription)
        }
    }

    /// Toggle favorite status for a career
    func toggleFavorite(studentId: String, careerId: String) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            // Get current state
            let currentState = try await getStudentCareer(studentId: studentId, careerId: careerId)
            let newFavoriteState = !(currentState?.isFavorite ?? false)

            try await studentCareersCollection(for: studentId)
                .document(careerId)
                .updateData([
                    "isFavorite": newFavoriteState,
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[StudentCareerService] Toggled favorite for \(careerId): \(newFavoriteState)")
        } catch {
            print("[StudentCareerService] Error toggling favorite: \(error.localizedDescription)")
            throw StudentCareerError.saveFailed(error.localizedDescription)
        }
    }

    /// Update last viewed timestamp
    func markAsViewed(studentId: String, careerId: String) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            try await studentCareersCollection(for: studentId)
                .document(careerId)
                .updateData([
                    "lastViewedAt": Timestamp(date: Date()),
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[StudentCareerService] Marked career \(careerId) as viewed")
        } catch {
            print("[StudentCareerService] Error marking as viewed: \(error.localizedDescription)")
            throw StudentCareerError.saveFailed(error.localizedDescription)
        }
    }

    /// Remove a student career
    func removeCareer(studentId: String, careerId: String) async throws {
        guard !studentId.isEmpty else {
            throw StudentCareerError.invalidStudentId
        }

        guard !careerId.isEmpty else {
            throw StudentCareerError.invalidCareerId
        }

        do {
            try await studentCareersCollection(for: studentId)
                .document(careerId)
                .delete()

            print("[StudentCareerService] Removed career \(careerId) from student \(studentId)")
        } catch {
            print("[StudentCareerService] Error removing career: \(error.localizedDescription)")
            throw StudentCareerError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Save or update a student career state
    private func saveStudentCareer(_ careerState: StudentCareerState) async throws {
        do {
            let data = careerState.toFirestoreData()
            let docId = careerState.careerId  // Use careerId as document ID

            try await studentCareersCollection(for: careerState.studentId)
                .document(docId)
                .setData(data, merge: true)

            print("[StudentCareerService] Saved student career: \(careerState.careerId)")
        } catch {
            print("[StudentCareerService] Error saving student career: \(error.localizedDescription)")
            throw StudentCareerError.saveFailed(error.localizedDescription)
        }
    }

    /// Timeout wrapper for async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw StudentCareerError.fetchFailed("Operation timed out after \(seconds) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
