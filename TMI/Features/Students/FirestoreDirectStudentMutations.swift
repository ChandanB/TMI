import CryptoKit
import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Writes canonical student records straight to Firestore.
///
/// The trusted callables in `firebase/src/index.ts` remain the preferred path
/// and stay authoritative wherever Cloud Functions are deployed. This backend
/// exists because Functions require a billing plan the project does not have,
/// which would otherwise leave every roster mutation unreachable. Firestore
/// rules carry the same authorization boundary, so the write is checked
/// server-side either way; what is lost is the server's ability to maintain
/// `membership.assignedStudentIDs`, which rules no longer depend on.
///
/// Document shape, search normalization, and identifier derivation mirror
/// `studentDocumentFields` and `studentIDForCreate` so records written here are
/// indistinguishable from records written by the callable.
nonisolated struct FirestoreDirectStudentMutationBackend: StudentTrustedMutationBackend {
    private let firestore: Firestore
    private let currentUserID: @Sendable () -> String?

    init(
        firestore: Firestore,
        currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.firestore = firestore
        self.currentUserID = currentUserID
    }

    func createStudent(
        _ request: StudentCreateMutationRequest
    ) async throws -> StudentMutationResult {
        let userID = try requireUserID()
        let studentID = Self.studentID(
            districtID: request.base.districtID,
            idempotencyKey: request.base.idempotencyKey
        )
        let reference = documentReference(
            districtID: request.base.districtID,
            studentID: studentID
        )

        let existing = try await getDocument(reference)
        if existing.exists {
            // The callable is idempotent on the derived identifier; match it
            // instead of failing a retried create.
            let version = (existing.data()?["recordVersion"] as? Int) ?? 1
            return StudentMutationResult(
                studentID: studentID,
                recordVersion: version,
                replayed: true,
                membership: try await membership(
                    districtID: request.base.districtID,
                    userID: userID,
                    assigning: studentID
                )
            )
        }

        let now = Date()
        var fields = Self.documentFields(
            districtID: request.base.districtID,
            schoolID: request.schoolID,
            displayName: request.displayName,
            grade: request.grade,
            studentIdentifier: request.studentIdentifier,
            dateOfBirth: request.dateOfBirth,
            pronouns: request.pronouns,
            assignedMemberIDs: request.assignedMemberIDs
        )
        fields["isArchived"] = false
        fields["schemaVersion"] = 1
        fields["recordVersion"] = 1
        fields["createdAt"] = Timestamp(date: now)
        fields["createdBy"] = userID
        fields["updatedAt"] = Timestamp(date: now)
        fields["updatedBy"] = userID

        try await setData(fields, on: reference)

        return StudentMutationResult(
            studentID: studentID,
            recordVersion: 1,
            replayed: false,
            membership: try await membership(
                districtID: request.base.districtID,
                userID: userID,
                assigning: studentID
            )
        )
    }

    func updateStudent(
        _ request: StudentUpdateMutationRequest
    ) async throws -> StudentMutationResult {
        let userID = try requireUserID()
        let reference = documentReference(
            districtID: request.base.districtID,
            studentID: request.studentID
        )

        var fields = Self.documentFields(
            districtID: request.base.districtID,
            schoolID: request.schoolID,
            displayName: request.displayName,
            grade: request.grade,
            studentIdentifier: request.studentIdentifier,
            dateOfBirth: request.dateOfBirth,
            pronouns: request.pronouns,
            assignedMemberIDs: request.assignedMemberIDs
        )
        let nextVersion = request.base.expectedRecordVersion + 1
        fields["recordVersion"] = nextVersion
        fields["updatedAt"] = Timestamp(date: Date())
        fields["updatedBy"] = userID
        // Fields the caller cleared must be removed rather than left stale.
        for key in ["studentIdentifier", "normalizedStudentIdentifier", "dateOfBirth", "pronouns"]
        where fields[key] == nil {
            fields[key] = FieldValue.delete()
        }

        try await updateData(fields, on: reference, expecting: request.base.expectedRecordVersion)

        return StudentMutationResult(
            studentID: request.studentID,
            recordVersion: nextVersion,
            replayed: false,
            membership: try await membership(
                districtID: request.base.districtID,
                userID: userID,
                assigning: request.studentID
            )
        )
    }

    func archiveStudent(
        _ request: StudentArchiveMutationRequest
    ) async throws -> StudentMutationResult {
        let userID = try requireUserID()
        let reference = documentReference(
            districtID: request.base.districtID,
            studentID: request.studentID
        )
        let nextVersion = request.base.expectedRecordVersion + 1

        try await updateData(
            [
                "isArchived": true,
                "recordVersion": nextVersion,
                "updatedAt": Timestamp(date: Date()),
                "updatedBy": userID
            ],
            on: reference,
            expecting: request.base.expectedRecordVersion
        )

        return StudentMutationResult(
            studentID: request.studentID,
            recordVersion: nextVersion,
            replayed: false,
            membership: try await membership(
                districtID: request.base.districtID,
                userID: userID,
                assigning: request.studentID
            )
        )
    }

    // MARK: - Document shaping

    /// Mirrors `normalizeSearchText` in `firebase/src/index.ts`.
    static func normalizeSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    /// Mirrors `studentIDForCreate` so a retry through either path collides.
    static func studentID(districtID: String, idempotencyKey: String) -> String {
        let digest = SHA256.hash(data: Data("\(districtID):\(idempotencyKey)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "student_\(String(hex.prefix(32)))"
    }

    private static func documentFields(
        districtID: String,
        schoolID: String,
        displayName: String,
        grade: String,
        studentIdentifier: String?,
        dateOfBirth: Date?,
        pronouns: String?,
        assignedMemberIDs: Set<String>
    ) -> [String: Any] {
        var fields: [String: Any] = [
            "districtId": districtID,
            "schoolId": schoolID,
            "displayName": displayName,
            "normalizedDisplayName": normalizeSearchText(displayName),
            "grade": grade,
            "assignedMemberIDs": assignedMemberIDs.sorted()
        ]
        if let studentIdentifier {
            fields["studentIdentifier"] = studentIdentifier
            fields["normalizedStudentIdentifier"] = normalizeSearchText(studentIdentifier)
        }
        if let dateOfBirth {
            fields["dateOfBirth"] = Timestamp(date: dateOfBirth)
        }
        if let pronouns {
            fields["pronouns"] = pronouns
        }
        return fields
    }

    // MARK: - Firestore access

    private func documentReference(districtID: String, studentID: String) -> DocumentReference {
        firestore
            .collection("districts")
            .document(districtID)
            .collection("students")
            .document(studentID)
    }

    private func requireUserID() throws -> String {
        guard let userID = currentUserID(), TrustedIdentifier.isValid(userID) else {
            throw StudentMutationBackendError.permissionDenied
        }
        return userID
    }

    private func membership(
        districtID: String,
        userID: String,
        assigning studentID: String
    ) async throws -> StudentMutationMembership {
        let reference = firestore
            .collection("districts")
            .document(districtID)
            .collection("members")
            .document(userID)
        let snapshot = try await getDocument(reference)
        guard let data = snapshot.data(),
              let role = (data["role"] as? String).flatMap(StaffRole.init(rawValue:)),
              let version = data["version"] as? Int,
              data["isActive"] as? Bool == true else {
            throw StudentMutationBackendError.invalidResponse
        }
        let schoolIDs = Set((data["schoolIDs"] as? [String]) ?? [])
        let capabilities = Set(
            ((data["capabilities"] as? [String]) ?? []).compactMap(Capability.init(rawValue:))
        )
        // Only the Admin SDK can write assignedStudentIDs. Reflect the record
        // the caller just touched so the in-memory session stays coherent; the
        // authorization decision itself no longer depends on this field.
        var assigned = Set((data["assignedStudentIDs"] as? [String]) ?? [])
        assigned.insert(studentID)

        return StudentMutationMembership(
            districtID: districtID,
            schoolIDs: schoolIDs,
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assigned,
            isActive: true,
            version: version
        )
    }

    private func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot {
        do {
            return try await reference.getDocument()
        } catch {
            throw Self.mapped(error)
        }
    }

    private func setData(_ fields: [String: Any], on reference: DocumentReference) async throws {
        do {
            try await reference.setData(fields)
        } catch {
            throw Self.mapped(error)
        }
    }

    private func updateData(
        _ fields: [String: Any],
        on reference: DocumentReference,
        expecting expectedRecordVersion: Int
    ) async throws {
        // Rules independently require recordVersion to advance by exactly one,
        // so a stale write is rejected server-side regardless. Reading first
        // only turns that denial into a precise conflict for the caller.
        let snapshot = try await getDocument(reference)
        guard let data = snapshot.data() else {
            throw StudentMutationBackendError.invalidResponse
        }
        let actual = (data["recordVersion"] as? Int) ?? 0
        guard actual == expectedRecordVersion else {
            throw StudentMutationBackendError.versionConflict(
                expected: expectedRecordVersion,
                actual: actual
            )
        }
        do {
            try await reference.updateData(fields)
        } catch {
            throw Self.mapped(error)
        }
    }

    private static func mapped(_ error: Error) -> Error {
        if let backendError = error as? StudentMutationBackendError {
            return backendError
        }
        switch FirestoreErrorCode.Code(rawValue: (error as NSError).code) {
        case .permissionDenied:
            return StudentMutationBackendError.permissionDenied
        case .notFound:
            return StudentMutationBackendError.invalidResponse
        case .unavailable, .deadlineExceeded:
            return StudentMutationBackendError.transportUnavailable
        default:
            return StudentMutationBackendError.invalidResponse
        }
    }
}

/// Direct writes never mint a new custom claim, so there is nothing to refresh.
/// The membership read back from Firestore is merged into the existing session.
nonisolated struct DirectStudentMutationAuthorityRefresher: StudentMutationAuthorityRefreshing {
    func refresh(
        membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext {
        guard membership.districtID == previous.districtID else {
            throw StudentMutationAuthorityRefreshError.invalidResponse
        }
        return MembershipContext(
            userID: previous.userID,
            districtID: membership.districtID,
            schoolIDs: membership.schoolIDs,
            role: membership.role,
            capabilities: membership.capabilities,
            assignedStudentIDs: membership.assignedStudentIDs,
            isActive: membership.isActive,
            version: max(membership.version, previous.version)
        )
    }
}
