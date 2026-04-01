//
//  CareerLibraryService.swift
//  TMI
//
//  Global Career Library Service
//  Manages the canonical career library collection (including AI-cached careers)
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
final class CareerLibraryService {
    static let shared = CareerLibraryService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum CareerLibraryError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case invalidCareer

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch careers: \(message)"
            case .saveFailed(let message):
                return "Failed to save career: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete career: \(message)"
            case .invalidCareer:
                return "Invalid career data"
            }
        }
    }

    // MARK: - Global Collection Access

    private var globalCollection: CollectionReference {
        db.collection("careers")
    }

    // MARK: - Fetch Operations

    /// Fetch all careers from the global library (optionally filtered by district)
    func fetchAllCareers(districtId: String? = nil) async throws -> [Career] {
        do {
            let querySnapshot = try await withTimeout(seconds: 10) {
                try await self.globalCollection.getDocuments()
            }

            var careers = querySnapshot.documents.compactMap { document -> Career? in
                try? document.data(as: Career.self)
            }

            // Filter by district if needed
            if let districtId = districtId {
                careers = careers.filter { career in
                    (career.scope == .district && career.districtId == districtId) ||
                    career.scope == .global
                }
            }

            print("[CareerLibraryService] Fetched \(careers.count) careers from global library")
            return careers
        } catch {
            print("[CareerLibraryService] Error fetching careers: \(error.localizedDescription)")
            throw CareerLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch a single career by ID
    func fetchCareer(id: String) async throws -> Career? {
        do {
            let document = try await withTimeout(seconds: 10) {
                try await self.globalCollection.document(id).getDocument()
            }

            guard document.exists else {
                return nil
            }

            return try? document.data(as: Career.self)
        } catch {
            print("[CareerLibraryService] Error fetching career \(id): \(error.localizedDescription)")
            throw CareerLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Search careers by title, field, or tags
    func searchCareers(query: String) async throws -> [Career] {
        let allCareers = try await fetchAllCareers()
        let lowercasedQuery = query.lowercased()

        return allCareers.filter { career in
            career.title.lowercased().contains(lowercasedQuery) ||
            career.field.lowercased().contains(lowercasedQuery) ||
            career.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }
    }

    /// Fetch all careers from library (previously "AI-generated" filter removed)
    func fetchAIGeneratedCareers() async throws -> [Career] {
        return try await fetchAllCareers()
    }

    // MARK: - Write Operations

    /// Cache an AI-generated career to the global library
    func cacheAICareer(_ career: Career) async throws -> Career {
        do {
            // Check for duplicates by title + field
            let existing = try await checkDuplicateCareer(title: career.title, field: career.field)
            if let existingCareer = existing {
                print("[CareerLibraryService] Career '\(career.title)' already exists, returning existing")
                return existingCareer
            }

            // Save new career
            var updatedCareer = career
            let data = try Firestore.Encoder().encode(career)
            let docRef = try await globalCollection.addDocument(data: data)
            updatedCareer.id = docRef.documentID

            print("[CareerLibraryService] Cached AI career: \(updatedCareer.title)")
            return updatedCareer
        } catch {
            print("[CareerLibraryService] Error caching AI career: \(error.localizedDescription)")
            throw CareerLibraryError.saveFailed(error.localizedDescription)
        }
    }

    /// Save or update a career in the global library
    func saveCareer(_ career: Career) async throws -> Career {
        do {
            var updatedCareer = career

            if let id = career.id {
                // Update existing
                try await globalCollection.document(id).setData(from: career, merge: true)
                updatedCareer.id = id
            } else {
                // Create new
                let data = try Firestore.Encoder().encode(career)
                let docRef = try await globalCollection.addDocument(data: data)
                updatedCareer.id = docRef.documentID
            }

            print("[CareerLibraryService] Saved career: \(updatedCareer.title)")
            return updatedCareer
        } catch {
            print("[CareerLibraryService] Error saving career: \(error.localizedDescription)")
            throw CareerLibraryError.saveFailed(error.localizedDescription)
        }
    }

    /// Delete a career from the global library
    func deleteCareer(id: String) async throws {
        do {
            try await globalCollection.document(id).delete()
            print("[CareerLibraryService] Deleted career: \(id)")
        } catch {
            print("[CareerLibraryService] Error deleting career: \(error.localizedDescription)")
            throw CareerLibraryError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Check for duplicate career by title and field
    private func checkDuplicateCareer(title: String, field: String) async throws -> Career? {
        let allCareers = try await fetchAllCareers()
        return allCareers.first { career in
            career.title.lowercased() == title.lowercased() &&
            career.field.lowercased() == field.lowercased()
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
                throw CareerLibraryError.fetchFailed("Operation timed out after \(seconds) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
