//
//  PlanResourceLinkService.swift
//  TMI
//
//  Plan Resource Link Service
//  Manages resources added to TMI plans (different from resource assignments)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@Observable
final class PlanResourceLinkService {
    static let shared = PlanResourceLinkService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Error Types

    enum PlanResourceLinkError: Error, LocalizedError {
        case fetchFailed(String)
        case saveFailed(String)
        case deleteFailed(String)
        case userNotAuthenticated
        case invalidPlanId
        case invalidResourceId

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch plan resources: \(message)"
            case .saveFailed(let message):
                return "Failed to save plan resource: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete plan resource: \(message)"
            case .userNotAuthenticated:
                return "User not authenticated"
            case .invalidPlanId:
                return "Invalid plan ID"
            case .invalidResourceId:
                return "Invalid resource ID"
            }
        }
    }

    // MARK: - Collection Access

    private func planResourcesCollection(for planId: String) -> CollectionReference {
        db.collection("plans").document(planId).collection("planResources")
    }

    // MARK: - Fetch Operations

    /// Get all resources linked to a specific plan
    func getPlanResources(planId: String) async throws -> [PlanResourceLink] {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        do {
            let links = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                let querySnapshot = try await self.planResourcesCollection(for: planId)
                    .order(by: "orderIndex", descending: false)
                    .getDocuments()
                return querySnapshot.documents.compactMap { document -> PlanResourceLink? in
                    PlanResourceLink.fromFirestore(id: document.documentID, data: document.data())
                }
            }

            print("[PlanResourceLinkService] Fetched \(links.count) resources for plan \(planId)")
            return links
        } catch {
            print("[PlanResourceLinkService] Error fetching plan resources: \(error.localizedDescription)")
            throw PlanResourceLinkError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get a specific plan resource link
    func getPlanResource(planId: String, resourceId: String) async throws -> PlanResourceLink? {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        guard !resourceId.isEmpty else {
            throw PlanResourceLinkError.invalidResourceId
        }

        do {
            return try await withTimeout(seconds: 10) { @MainActor @Sendable in
                let document = try await self.planResourcesCollection(for: planId)
                    .document(resourceId)
                    .getDocument()

                guard document.exists, let data = document.data() else {
                    return nil
                }

                return PlanResourceLink.fromFirestore(id: document.documentID, data: data)
            }
        } catch {
            print("[PlanResourceLinkService] Error fetching plan resource: \(error.localizedDescription)")
            throw PlanResourceLinkError.fetchFailed(error.localizedDescription)
        }
    }

    /// Check if a resource is already in the plan
    func isResourceInPlan(planId: String, resourceId: String) async throws -> Bool {
        let link = try await getPlanResource(planId: planId, resourceId: resourceId)
        return link != nil
    }

    // MARK: - Write Operations

    /// Add a resource to a plan
    func addResourceToPlan(
        planId: String,
        resourceId: String,
        notes: String? = nil,
        orderIndex: Int? = nil
    ) async throws {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        guard !resourceId.isEmpty else {
            throw PlanResourceLinkError.invalidResourceId
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw PlanResourceLinkError.userNotAuthenticated
        }

        // Check if already exists
        if try await isResourceInPlan(planId: planId, resourceId: resourceId) {
            print("[PlanResourceLinkService] Resource \(resourceId) already in plan \(planId)")
            return
        }

        let link = PlanResourceLink(
            id: resourceId,  // Use resourceId as document ID
            planId: planId,
            resourceId: resourceId,
            addedBy: uid,
            addedAt: Date(),
            updatedAt: Date(),
            notes: notes,
            orderIndex: orderIndex
        )

        try await savePlanResourceLink(link)
    }

    /// Update notes for a plan resource
    func updateResourceNotes(planId: String, resourceId: String, notes: String?) async throws {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        guard !resourceId.isEmpty else {
            throw PlanResourceLinkError.invalidResourceId
        }

        do {
            var updateData: [String: Any] = [
                "updatedAt": Timestamp(date: Date())
            ]

            if let notes = notes {
                updateData["notes"] = notes
            }

            try await planResourcesCollection(for: planId)
                .document(resourceId)
                .updateData(updateData)

            print("[PlanResourceLinkService] Updated notes for resource \(resourceId)")
        } catch {
            print("[PlanResourceLinkService] Error updating resource notes: \(error.localizedDescription)")
            throw PlanResourceLinkError.saveFailed(error.localizedDescription)
        }
    }

    /// Update order index for a plan resource
    func updateResourceOrder(planId: String, resourceId: String, orderIndex: Int) async throws {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        guard !resourceId.isEmpty else {
            throw PlanResourceLinkError.invalidResourceId
        }

        do {
            try await planResourcesCollection(for: planId)
                .document(resourceId)
                .updateData([
                    "orderIndex": orderIndex,
                    "updatedAt": Timestamp(date: Date())
                ])

            print("[PlanResourceLinkService] Updated order for resource \(resourceId)")
        } catch {
            print("[PlanResourceLinkService] Error updating resource order: \(error.localizedDescription)")
            throw PlanResourceLinkError.saveFailed(error.localizedDescription)
        }
    }

    /// Remove a resource from a plan
    func removeResourceFromPlan(planId: String, resourceId: String) async throws {
        guard !planId.isEmpty else {
            throw PlanResourceLinkError.invalidPlanId
        }

        guard !resourceId.isEmpty else {
            throw PlanResourceLinkError.invalidResourceId
        }

        do {
            try await planResourcesCollection(for: planId)
                .document(resourceId)
                .delete()

            print("[PlanResourceLinkService] Removed resource \(resourceId) from plan \(planId)")
        } catch {
            print("[PlanResourceLinkService] Error removing resource: \(error.localizedDescription)")
            throw PlanResourceLinkError.deleteFailed(error.localizedDescription)
        }
    }

    /// Reorder all resources in a plan
    func reorderPlanResources(planId: String, resourceIds: [String]) async throws {
        for (index, resourceId) in resourceIds.enumerated() {
            do {
                try await updateResourceOrder(planId: planId, resourceId: resourceId, orderIndex: index)
            } catch {
                print("[PlanResourceLinkService] Failed to reorder resource \(resourceId): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Save or update a plan resource link
    private func savePlanResourceLink(_ link: PlanResourceLink) async throws {
        do {
            let data = link.toFirestoreData()
            let docId = link.resourceId  // Use resourceId as document ID

            try await planResourcesCollection(for: link.planId)
                .document(docId)
                .setData(data, merge: true)

            print("[PlanResourceLinkService] Saved plan resource: \(link.resourceId)")
        } catch {
            print("[PlanResourceLinkService] Error saving plan resource: \(error.localizedDescription)")
            throw PlanResourceLinkError.saveFailed(error.localizedDescription)
        }
    }

}
