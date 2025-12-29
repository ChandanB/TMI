//
//  InterestLibraryService.swift
//  TMI
//
//  Global Interest Library Service
//  Manages the canonical interest library collection
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
final class InterestLibraryService {
    static let shared = InterestLibraryService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum InterestLibraryError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case seedingFailed(String)
        case invalidInterest

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch interests: \(message)"
            case .saveFailed(let message):
                return "Failed to save interest: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete interest: \(message)"
            case .seedingFailed(let message):
                return "Failed to seed interests: \(message)"
            case .invalidInterest:
                return "Invalid interest data"
            }
        }
    }

    // MARK: - Global Collection Access

    private var globalCollection: CollectionReference {
        db.collection("interests")
    }

    // MARK: - Fetch Operations

    /// Fetch all interests from the global library
    func fetchAllInterests() async throws -> [Interest] {
        do {
            let querySnapshot = try await withTimeout(seconds: 10) {
                try await self.globalCollection.getDocuments()
            }

            let interests = querySnapshot.documents.compactMap { document -> Interest? in
                Interest.fromFirestore(id: document.documentID, data: document.data())
            }

            print("[InterestLibraryService] Fetched \(interests.count) interests from global library")
            return interests
        } catch {
            print("[InterestLibraryService] Error fetching interests: \(error.localizedDescription)")
            throw InterestLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Fetch a single interest by ID
    func fetchInterest(id: String) async throws -> Interest? {
        do {
            let document = try await withTimeout(seconds: 10) {
                try await self.globalCollection.document(id).getDocument()
            }

            guard document.exists, let data = document.data() else {
                return nil
            }

            return Interest.fromFirestore(id: document.documentID, data: data)
        } catch {
            print("[InterestLibraryService] Error fetching interest \(id): \(error.localizedDescription)")
            throw InterestLibraryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Search interests by name or tags
    func searchInterests(query: String) async throws -> [Interest] {
        let allInterests = try await fetchAllInterests()
        let lowercasedQuery = query.lowercased()

        return allInterests.filter { interest in
            interest.name.lowercased().contains(lowercasedQuery) ||
            interest.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) ||
            (interest.description?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    /// Fetch interests filtered by scope
    func fetchInterests(scope: InterestScope) async throws -> [Interest] {
        let allInterests = try await fetchAllInterests()
        return allInterests.filter { $0.scope == scope }
    }

    /// Fetch interests for a specific district
    func fetchDistrictInterests(districtId: String) async throws -> [Interest] {
        let allInterests = try await fetchAllInterests()
        return allInterests.filter { interest in
            (interest.scope == .district || interest.scope == .global) &&
            (interest.districtId == districtId || interest.scope == .global)
        }
    }

    // MARK: - Write Operations

    /// Add or update an interest in the global library
    func saveInterest(_ interest: Interest) async throws -> Interest {
        do {
            let updatedInterest = interest
            let data = updatedInterest.toFirestoreData()

            if let id = interest.id {
                // Update existing
                try await globalCollection.document(id).setData(data, merge: true)
                updatedInterest.id = id
            } else {
                // Create new
                let docRef = try await globalCollection.addDocument(data: data)
                updatedInterest.id = docRef.documentID
            }

            print("[InterestLibraryService] Saved interest: \(updatedInterest.name)")
            return updatedInterest
        } catch {
            print("[InterestLibraryService] Error saving interest: \(error.localizedDescription)")
            throw InterestLibraryError.saveFailed(error.localizedDescription)
        }
    }

    /// Delete an interest from the global library
    func deleteInterest(id: String) async throws {
        do {
            try await globalCollection.document(id).delete()
            print("[InterestLibraryService] Deleted interest: \(id)")
        } catch {
            print("[InterestLibraryService] Error deleting interest: \(error.localizedDescription)")
            throw InterestLibraryError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Seeding

    /// Seed predefined interests into the global library (one-time migration)
    func seedPredefinedInterests() async throws {
        print("[InterestLibraryService] Starting seed of predefined interests...")

        do {
            let predefinedInterests = PredefinedInterestsData.allPredefinedInterests

            // Check if already seeded
            let existingInterests = try await fetchAllInterests()
            if existingInterests.count >= predefinedInterests.count {
                print("[InterestLibraryService] Library already seeded with \(existingInterests.count) interests")
                return
            }

            var successCount = 0
            var failureCount = 0

            for predefinedInterest in predefinedInterests {
                do {
                    // Check if interest already exists
                    if let existingInterest = try await fetchInterest(id: predefinedInterest.id ?? "") {
                        print("[InterestLibraryService] Interest '\(existingInterest.name)' already exists, skipping")
                        successCount += 1
                        continue
                    }

                    // Save new interest
                    _ = try await saveInterest(predefinedInterest)
                    successCount += 1
                } catch {
                    print("[InterestLibraryService] Failed to seed interest '\(predefinedInterest.name)': \(error.localizedDescription)")
                    failureCount += 1
                }
            }

            print("[InterestLibraryService] Seeding complete: \(successCount) successful, \(failureCount) failed")

            if failureCount > 0 {
                throw InterestLibraryError.seedingFailed("\(failureCount) interests failed to seed")
            }
        } catch {
            print("[InterestLibraryService] Seeding error: \(error.localizedDescription)")
            throw InterestLibraryError.seedingFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Timeout wrapper for async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw InterestLibraryError.fetchFailed("Operation timed out after \(seconds) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
