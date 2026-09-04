import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

nonisolated enum CareerRelationshipRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case invalidRecord
    case permissionDenied
    case unavailable
}

@MainActor
protocol CareerRelationshipProviding: Sendable {
    func relationships(
        studentID: String,
        member: MembershipContext
    ) async throws -> [CareerRelationship]

    func save(
        _ relationship: CareerRelationship,
        member: MembershipContext
    ) async throws
}

/// Persists only a person's relationship to a canonical career.
///
/// Match scores and recommendations remain derived values. They never become
/// facts in this collection, so changing the matching algorithm cannot rewrite
/// what a student or educator actually saved, dismissed, compared, or viewed.
@MainActor
final class CareerRelationshipRepository: CareerRelationshipProviding {
    private let firestore: Firestore
    private let currentUserID: @Sendable () -> String?

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = {
            Auth.auth().currentUser?.uid
        }
    ) {
        self.firestore = firestore
        self.currentUserID = currentUserID
    }

    func relationships(
        studentID: String,
        member: MembershipContext
    ) async throws -> [CareerRelationship] {
        do {
            let snapshot = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await self.collection(
                    districtID: member.districtID,
                    studentID: studentID
                ).getDocuments()
            }
            return snapshot.documents.compactMap { document in
                Self.record(
                    id: document.documentID,
                    data: document.data(),
                    expectedDistrictID: member.districtID,
                    expectedStudentID: studentID
                )
            }
            .sorted { left, right in
                if left.lastViewedAt == right.lastViewedAt {
                    return left.careerID < right.careerID
                }
                return (left.lastViewedAt ?? .distantPast) > (right.lastViewedAt ?? .distantPast)
            }
        } catch ConcurrencyError.timeout {
            throw CareerRelationshipRepositoryError.unavailable
        } catch {
            throw Self.mapped(error)
        }
    }

    func save(
        _ relationship: CareerRelationship,
        member: MembershipContext
    ) async throws {
        guard let userID = currentUserID(),
              relationship.updatedBy == userID,
              !relationship.careerID.isEmpty,
              !relationship.careerID.contains("/") else {
            throw CareerRelationshipRepositoryError.notAuthenticated
        }
        do {
            try await withTimeout(seconds: 10) { @MainActor @Sendable in
                var data = Self.fields(
                    relationship,
                    districtID: member.districtID
                )
                data["updatedAt"] = FieldValue.serverTimestamp()
                if relationship.recordVersion == 1 {
                    data["createdAt"] = FieldValue.serverTimestamp()
                }
                try await self.collection(
                    districtID: member.districtID,
                    studentID: relationship.studentID
                )
                .document(relationship.careerID)
                .setData(
                    data,
                    merge: false
                )
            }
        } catch ConcurrencyError.timeout {
            throw CareerRelationshipRepositoryError.unavailable
        } catch {
            throw Self.mapped(error)
        }
    }

    private func collection(
        districtID: String,
        studentID: String
    ) -> CollectionReference {
        firestore
            .collection("districts").document(districtID)
            .collection("students").document(studentID)
            .collection("careers")
    }

    private static func mapped(_ error: Error) -> CareerRelationshipRepositoryError {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else { return .invalidRecord }
        switch FirestoreErrorCode.Code(rawValue: nsError.code) {
        case .permissionDenied: return .permissionDenied
        case .unavailable: return .unavailable
        default: return .invalidRecord
        }
    }
}

nonisolated extension CareerRelationshipRepository {
    static func fields(
        _ relationship: CareerRelationship,
        districtID: String
    ) -> [String: Any] {
        [
            "districtID": districtID,
            "studentID": relationship.studentID,
            "careerID": relationship.careerID,
            "isSaved": relationship.isSaved,
            "isDismissed": relationship.isDismissed,
            "isCompared": relationship.isCompared,
            "linkedPlanIDs": relationship.linkedPlanIDs.sorted(),
            "lastViewedAt": relationship.lastViewedAt.map { Timestamp(date: $0) } ?? NSNull(),
            "schemaVersion": 1,
            "recordVersion": relationship.recordVersion,
            "createdAt": Timestamp(date: relationship.createdAt),
            "createdBy": relationship.createdBy,
            "updatedAt": Timestamp(date: relationship.updatedAt),
            "updatedBy": relationship.updatedBy,
        ]
    }

    static func record(
        id: String,
        data: [String: Any],
        expectedDistrictID: String? = nil,
        expectedStudentID: String? = nil
    ) -> CareerRelationship? {
        guard let districtID = data["districtID"] as? String,
              expectedDistrictID == nil || districtID == expectedDistrictID,
              let studentID = data["studentID"] as? String,
              expectedStudentID == nil || studentID == expectedStudentID,
              let careerID = data["careerID"] as? String,
              careerID == id,
              !careerID.isEmpty,
              !careerID.contains("/"),
              let isSaved = data["isSaved"] as? Bool,
              let isDismissed = data["isDismissed"] as? Bool,
              !(isSaved && isDismissed),
              let isCompared = data["isCompared"] as? Bool,
              let linkedPlanIDs = data["linkedPlanIDs"] as? [String],
              data["schemaVersion"] as? Int == 1,
              let recordVersion = data["recordVersion"] as? Int,
              recordVersion > 0,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let createdBy = data["createdBy"] as? String,
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue(),
              let updatedBy = data["updatedBy"] as? String else {
            return nil
        }
        let lastViewedAt = (data["lastViewedAt"] as? Timestamp)?.dateValue()
        return CareerRelationship(
            studentID: studentID,
            careerID: careerID,
            isSaved: isSaved,
            isDismissed: isDismissed,
            isCompared: isCompared,
            linkedPlanIDs: linkedPlanIDs,
            lastViewedAt: lastViewedAt,
            updatedAt: updatedAt,
            updatedBy: updatedBy,
            recordVersion: recordVersion,
            createdAt: createdAt,
            createdBy: createdBy
        )
    }
}
