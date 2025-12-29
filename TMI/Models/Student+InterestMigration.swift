//
//  Student+InterestMigration.swift
//  TMI
//
//  Migration helpers for transitioning from inline interests to edge-based architecture
//  These helpers provide backward compatibility during the migration period
//

import Foundation

// MARK: - Student Interest Migration Helpers

extension Student {

    /// Fetch student interests from edge collection
    /// This is the preferred method for accessing student interests
    @MainActor
    func fetchInterestsFromEdgeCollection() async throws -> [Interest] {
        guard let studentId = id else {
            throw StudentInterestError.invalidStudentId
        }

        // Fetch edge relationships
        let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)

        // Resolve to full Interest objects from global library
        let interests = try await withThrowingTaskGroup(of: Interest?.self) { group in
            for edge in edges {
                group.addTask {
                    try? await InterestLibraryService.shared.fetchInterest(id: edge.interestId)
                }
            }

            var results: [Interest] = []
            for try await interest in group {
                if let interest = interest {
                    results.append(interest)
                }
            }
            return results
        }

        return interests
    }

    /// Get count of student interests (lightweight, ID-only query)
    @MainActor
    func getInterestCount() async throws -> Int {
        guard let studentId = id else {
            return 0
        }

        let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
        return edges.count
    }

    /// Check if student has a specific interest (lightweight, ID-only query)
    @MainActor
    func hasInterest(interestId: String) async throws -> Bool {
        guard let studentId = id else {
            return false
        }

        let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
        return edges.contains { $0.interestId == interestId }
    }

    /// Add an interest to this student's edge collection
    @MainActor
    func addInterest(
        _ interest: Interest,
        level: Int = 3,
        source: StudentInterest.StudentInterestSource = .staff
    ) async throws {
        guard let studentId = id else {
            throw StudentInterestError.invalidStudentId
        }

        guard let interestId = interest.id else {
            throw StudentInterestError.invalidInterestId
        }

        try await StudentInterestService.shared.addInterest(
            studentId: studentId,
            interestId: interestId,
            level: level,
            source: source
        )
    }

    /// Remove an interest from this student's edge collection
    @MainActor
    func removeInterest(interestId: String) async throws {
        guard let studentId = id else {
            throw StudentInterestError.invalidStudentId
        }

        try await StudentInterestService.shared.removeInterest(
            studentId: studentId,
            interestId: interestId
        )
    }

    /// Get high-affinity interests for this student (level >= 3)
    @MainActor
    func getHighAffinityInterests() async throws -> [StudentInterest] {
        guard let studentId = id else {
            throw StudentInterestError.invalidStudentId
        }

        return try await StudentInterestService.shared.getHighAffinityInterests(studentId: studentId)
    }

    /// Get interest categories from edge collection
    @MainActor
    func fetchInterestCategories() async throws -> [InterestCategory] {
        let interests = try await fetchInterestsFromEdgeCollection()
        let categories = interests.flatMap { $0.category }
        let uniqueCategories = Set(categories)
        return uniqueCategories.sorted()
    }
}

// MARK: - Error Types

enum StudentInterestError: Error, LocalizedError {
    case invalidStudentId
    case invalidInterestId

    var errorDescription: String? {
        switch self {
        case .invalidStudentId:
            return "Student ID is required"
        case .invalidInterestId:
            return "Interest ID is required"
        }
    }
}
