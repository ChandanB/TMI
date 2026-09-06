//
//  RecommendationsStateModelTests.swift
//  TMITests
//
//  Verifies RecommendationsService (and the RecommendationsStateModel that
//  wraps it) derives the district scope from the trusted authorization
//  session (mirroring MeetingService/FormTemplateService) instead of reading
//  users/{uid}/recommendations.
//

import FirebaseFirestore
import Foundation
import Testing
@testable import TMI

@Suite("RecommendationsService/RecommendationsStateModel district scoping")
struct RecommendationsStateModelTests {
    private let districtID = "district-1"
    private let userID = "teacher-1"

    private func makeSession(userID: String = "teacher-1", districtID: String = "district-1") -> AuthenticatedSession {
        let user = TMIUser(
            id: userID,
            email: "teacher@example.com",
            displayName: "Test Teacher",
            requestedRole: .teacher,
            profileCreatedDate: .distantPast
        )
        let claim = TrustedTenantClaim(
            userID: userID,
            districtID: districtID,
            accessClass: .staff,
            membershipVersion: 1
        )
        let membership = MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: ["school-1"],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: ["student-1"],
            isActive: true,
            version: 1
        )
        return AuthenticatedSession(profile: user, claim: claim, membership: membership)
    }

    private func makeRecommendation(id: String = "rec-1", studentId: String = "s1", planId: String? = nil) -> Recommendation {
        Recommendation(
            id: id,
            type: .resource,
            title: "Explore robotics",
            description: "Based on your interests.",
            rationale: "Interest match.",
            status: .pending,
            priority: .medium,
            createdAt: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 500),
            studentId: studentId,
            planId: planId,
            linkedInterestIds: [],
            linkedCareerIds: [],
            linkedResourceIds: [],
            linkedGoalIds: [],
            actionType: .viewContent,
            actionPayload: nil,
            feedback: nil
        )
    }

    @Test("fetchRecommendations(forStudentId:) queries the district recommendations path")
    func fetchByStudentIdQueriesDistrictPath() async throws {
        let store = FakeRecommendationStore()
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = RecommendationsService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        _ = try await service.fetchRecommendations(forStudentId: "s1")

        #expect(store.queryCalls.count == 1)
        let call = try #require(store.queryCalls.first)
        #expect(call.path == FirestorePaths.recommendations(districtID: districtID))
        #expect(call.field == "studentId")
        #expect(call.value == "s1")
        #expect(!call.path.contains("users/"))
    }

    @Test("saveRecommendation writes to the district recommendations path")
    func saveRecommendationWritesDistrictPath() async throws {
        let store = FakeRecommendationStore()
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = RecommendationsService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        try await service.saveRecommendation(makeRecommendation())

        #expect(store.setCalls.count == 1)
        let call = try #require(store.setCalls.first)
        #expect(call.path == FirestorePaths.recommendations(districtID: districtID))
        #expect(call.id == "rec-1")
        #expect(!call.path.contains("users/"))
    }

    @Test("deleteRecommendation deletes at the district recommendations path")
    func deleteRecommendationDeletesDistrictPath() async throws {
        let store = FakeRecommendationStore()
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = RecommendationsService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        try await service.deleteRecommendation(id: "rec-1")

        #expect(store.deleteCalls.count == 1)
        let call = try #require(store.deleteCalls.first)
        #expect(call.path == FirestorePaths.recommendations(districtID: districtID))
        #expect(call.id == "rec-1")
    }

    @Test("No trusted session throws and performs no store writes")
    func noSessionThrowsWithoutWriting() async throws {
        let store = FakeRecommendationStore()
        let sessions = FakeAuthorizationSessionProvider(session: nil)
        let service = RecommendationsService(store: store, authorizationSessions: sessions, currentUserID: { userID })

        await #expect(throws: RecommendationsServiceError.userNotAuthenticated) {
            try await service.saveRecommendation(self.makeRecommendation())
        }

        #expect(store.setCalls.isEmpty)
    }

    @Test("RecommendationsStateModel.setContext loads recommendations from the district-scoped service")
    @MainActor
    func stateModelLoadsFromDistrictScopedService() async throws {
        let store = FakeRecommendationStore()
        store.seed(
            atCollectionPath: FirestorePaths.recommendations(districtID: districtID),
            id: "rec-1",
            recommendation: makeRecommendation(id: "rec-1", studentId: "s1")
        )
        let sessions = FakeAuthorizationSessionProvider(session: makeSession())
        let service = RecommendationsService(store: store, authorizationSessions: sessions, currentUserID: { userID })
        let model = RecommendationsStateModel(recommendationsService: service)

        await model.setContext(studentId: "s1", planId: nil)

        #expect(store.queryCalls.count == 1)
        let call = try #require(store.queryCalls.first)
        #expect(call.path == FirestorePaths.recommendations(districtID: districtID))
        #expect(!call.path.contains("users/"))
        #expect(model.recommendations.count == 1)
        #expect(model.recommendations.first?.id == "rec-1")
    }
    @Test("Plan recommendations retain the selected student boundary on shared plans")
    @MainActor
    func sharedPlanDoesNotMixStudents() async {
        let store = FakeRecommendationStore()
        for student in ["s1", "s2"] {
            store.seed(atCollectionPath: FirestorePaths.recommendations(districtID: districtID),
                id: student, recommendation: makeRecommendation(id: student, studentId: student, planId: "shared"))
        }
        let service = RecommendationsService(store: store,
            authorizationSessions: FakeAuthorizationSessionProvider(session: makeSession()), currentUserID: { userID })
        let model = RecommendationsStateModel(recommendationsService: service)
        await model.setContext(studentId: "s1", planId: "shared")
        #expect(model.recommendations.map(\.studentId) == ["s1"])
    }

    @Test("Clearing recommendation context removes the previous student's results")
    @MainActor
    func clearingContextRemovesPrivateResults() async {
        let store = FakeRecommendationStore()
        store.seed(atCollectionPath: FirestorePaths.recommendations(districtID: districtID),
            id: "rec-1", recommendation: makeRecommendation())
        let service = RecommendationsService(store: store,
            authorizationSessions: FakeAuthorizationSessionProvider(session: makeSession()), currentUserID: { userID })
        let model = RecommendationsStateModel(recommendationsService: service)
        await model.setContext(studentId: "s1", planId: nil)
        #expect(model.recommendations.count == 1)
        await model.setContext(studentId: nil, planId: nil)
        #expect(model.recommendations.isEmpty)
        #expect(model.pendingRecommendations.isEmpty)
    }
}

// MARK: - Test doubles

private final class FakeAuthorizationSessionProvider: AuthorizationSessionProviding, @unchecked Sendable {
    private let session: AuthenticatedSession?

    init(session: AuthenticatedSession?) {
        self.session = session
    }

    func session(authenticatedUserID: String?) -> AuthenticatedSession? {
        session
    }
}

private final class FakeRecommendationStore: RecommendationStore, @unchecked Sendable {
    private(set) var setCalls: [(path: String, id: String, data: [String: Any], merge: Bool)] = []
    private(set) var updateCalls: [(path: String, id: String, data: [String: Any])] = []
    private(set) var deleteCalls: [(path: String, id: String)] = []
    private(set) var queryCalls: [(path: String, field: String, value: String)] = []

    private var seeded: [String: [(id: String, data: [String: Any])]] = [:]

    func seed(atCollectionPath path: String, id: String, recommendation: Recommendation) {
        let data = recommendation.toFirestoreData()
        seeded[path, default: []].append((id: id, data: data))
    }

    func documents(
        atCollectionPath path: String,
        whereField field: String,
        equals value: String
    ) async throws -> [(id: String, data: [String: Any])] {
        queryCalls.append((path: path, field: field, value: value))
        return (seeded[path] ?? []).filter { ($0.data[field] as? String) == value }
    }

    func setDocument(
        atCollectionPath path: String,
        id: String,
        data: [String: Any],
        merge: Bool
    ) async throws {
        setCalls.append((path: path, id: id, data: data, merge: merge))
    }

    func updateDocument(atCollectionPath path: String, id: String, data: [String: Any]) async throws {
        updateCalls.append((path: path, id: id, data: data))
    }

    func deleteDocument(atCollectionPath path: String, id: String) async throws {
        deleteCalls.append((path: path, id: id))
    }
}
