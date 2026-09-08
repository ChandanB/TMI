#if DEBUG
import Foundation

// The Debug staff tenant (`district-debug`/`school-debug`) synthesizes its
// trusted claim and membership entirely on the client, so its Firebase ID token
// carries none of the custom claims the Firestore rules read. Any repository that
// reaches real Firestore therefore fails with "Missing or insufficient
// permissions" for a Debug session. Students, plans, and plan children are already
// served locally (DebugStudentRepository / DebugPlanRepository); these two wrappers
// close the remaining gaps — the resource library/links and career relationships —
// so the entire Debug tenant is served from memory and never touches Firestore.
//
// Storage is in-process (session-scoped), matching DebugPlanStore. Real tenants
// fall straight through to the injected Firebase delegate.

@MainActor
final class DebugResourceRepository: ResourceRepository {
    private let delegate: any ResourceRepository
    private var libraryByID: [String: Resource] = [:]
    private var resourceIDsByStudentID: [String: Set<String>] = [:]
    private var resourceIDsByPlanID: [String: Set<String>] = [:]

    init(delegate: any ResourceRepository) {
        self.delegate = delegate
    }

    func library(member: MembershipContext) async throws -> [Resource] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.library(member: member)
        }
        return Array(libraryByID.values)
    }

    func studentResources(
        studentID: String,
        member: MembershipContext
    ) async throws -> [Resource] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.studentResources(studentID: studentID, member: member)
        }
        return resources(for: resourceIDsByStudentID[studentID])
    }

    func create(_ resource: Resource, member: MembershipContext) async throws -> Resource {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.create(resource, member: member)
        }
        var stored = resource
        let id = resource.id ?? UUID().uuidString
        stored.id = id
        libraryByID[id] = stored
        return stored
    }

    func assign(
        resourceID: String,
        toStudent studentID: String,
        member: MembershipContext
    ) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.assign(resourceID: resourceID, toStudent: studentID, member: member)
        }
        resourceIDsByStudentID[studentID, default: []].insert(resourceID)
    }

    func linkToPlan(
        resourceID: String,
        planID: String,
        member: MembershipContext
    ) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.linkToPlan(resourceID: resourceID, planID: planID, member: member)
        }
        resourceIDsByPlanID[planID, default: []].insert(resourceID)
    }

    func planResources(planID: String, member: MembershipContext) async throws -> [Resource] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.planResources(planID: planID, member: member)
        }
        return resources(for: resourceIDsByPlanID[planID])
    }

    private func resources(for ids: Set<String>?) -> [Resource] {
        guard let ids else { return [] }
        return ids.compactMap { libraryByID[$0] }
    }
}

@MainActor
final class DebugCareerRelationshipRepository: CareerRelationshipProviding {
    private let delegate: any CareerRelationshipProviding
    private var relationshipsByStudentID: [String: [String: CareerRelationship]] = [:]

    init(delegate: any CareerRelationshipProviding) {
        self.delegate = delegate
    }

    func relationships(
        studentID: String,
        member: MembershipContext
    ) async throws -> [CareerRelationship] {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.relationships(studentID: studentID, member: member)
        }
        let stored = Array((relationshipsByStudentID[studentID] ?? [:]).values)
        return stored.sorted { left, right in
            if left.lastViewedAt == right.lastViewedAt {
                return left.careerID < right.careerID
            }
            return (left.lastViewedAt ?? .distantPast) > (right.lastViewedAt ?? .distantPast)
        }
    }

    func save(
        _ relationship: CareerRelationship,
        member: MembershipContext
    ) async throws {
        guard DebugPlanRepository.isDebug(member) else {
            return try await delegate.save(relationship, member: member)
        }
        relationshipsByStudentID[relationship.studentID, default: [:]][relationship.careerID] = relationship
    }
}
#endif
