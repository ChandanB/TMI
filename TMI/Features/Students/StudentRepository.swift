import Foundation
import CryptoKit
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions

// MARK: - Public repository contract

nonisolated protocol StudentRepository: Sendable {
    func page(_ request: StudentPageRequest, member: MembershipContext) async throws -> StudentPage
    func student(id: String, member: MembershipContext) async throws -> StudentRecord
    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord
    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord]
    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord
    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws
}

nonisolated enum StudentRecordStatusFilter: String, Codable, Sendable, Hashable {
    case active
    case archived
    case all
}

nonisolated public enum StudentRosterSort: String, Codable, Sendable, Equatable, Hashable {
    case alphabetical
    case recentlyUpdated
}

nonisolated struct StudentPageCursor: Codable, Sendable, Hashable {
    let token: String
    let sort: StudentRosterSort
    let sortValue: String?
    let updatedAt: Date?
    let queryFingerprint: String?

    init(
        token: String,
        sort: StudentRosterSort = .alphabetical,
        sortValue: String? = nil,
        updatedAt: Date? = nil,
        queryFingerprint: String? = nil
    ) {
        self.token = token
        self.sort = sort
        self.sortValue = sortValue
        self.updatedAt = updatedAt
        self.queryFingerprint = queryFingerprint
    }
}

nonisolated struct StudentPageRequest: Sendable, Equatable {
    static let maximumPageSize = 50
    static let first = StudentPageRequest()

    var search: String?
    var schoolID: String?
    var grade: String?
    var assignedMemberID: String?
    var status: StudentRecordStatusFilter
    var sort: StudentRosterSort
    var cursor: StudentPageCursor?
    var limit: Int

    init(
        search: String? = nil,
        schoolID: String? = nil,
        grade: String? = nil,
        assignedMemberID: String? = nil,
        status: StudentRecordStatusFilter = .active,
        sort: StudentRosterSort = .alphabetical,
        cursor: StudentPageCursor? = nil,
        limit: Int = StudentPageRequest.maximumPageSize
    ) {
        self.search = search
        self.schoolID = schoolID
        self.grade = grade
        self.assignedMemberID = assignedMemberID
        self.status = status
        self.sort = sort
        self.cursor = cursor
        self.limit = limit
    }
}

nonisolated enum StudentPageSource: Sendable, Equatable {
    case server
    case cache
}

nonisolated struct StudentPage: Sendable, Equatable {
    let records: [StudentRecord]
    let nextCursor: StudentPageCursor?
    let source: StudentPageSource
}

nonisolated enum StudentRepositoryError: Error, Equatable {
    case invalidRequest
    case invalidDraft
    case notFound
    case permissionDenied
    case schoolFilterRequired
    case staleMembership
    case duplicate(candidateIDs: [String])
    case versionConflict(expected: Int, actual: Int)
    case idempotencyKeyReused
    case createQueued(operationID: UUID)
    case onlineRequired
    case unavailable
    case invalidResponse
}

// MARK: - Canonical Firestore DTO and read boundary

/// The Firestore payload intentionally omits document identity. The document ID
/// is supplied separately by `FirebaseStudentSnapshot` and becomes
/// `StudentRecord.id` only after decoding and validation.
nonisolated struct FirebaseStudentDocument: Codable, Sendable, Equatable {
    let districtId: String
    let schoolId: String
    let displayName: String
    let grade: String
    let studentIdentifier: String?
    let dateOfBirth: Date?
    let pronouns: String?
    let assignedMemberIDs: Set<String>
    let isArchived: Bool
    let schemaVersion: Int
    let recordVersion: Int
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date
    let updatedBy: String
}

nonisolated struct FirebaseStudentSnapshot: Codable, Sendable, Equatable {
    let documentID: String
    let document: FirebaseStudentDocument

    func record() throws -> StudentRecord {
        guard TrustedIdentifier.isValid(documentID),
              TrustedIdentifier.isValid(document.districtId),
              TrustedIdentifier.isValid(document.schoolId),
              document.assignedMemberIDs.allSatisfy(TrustedIdentifier.isValid),
              document.schemaVersion > 0,
              document.recordVersion > 0,
              TrustedIdentifier.isValid(document.createdBy),
              TrustedIdentifier.isValid(document.updatedBy) else {
            throw StudentRepositoryError.invalidResponse
        }

        let draft = StudentDraft(
            displayName: document.displayName,
            schoolID: document.schoolId,
            grade: document.grade,
            studentIdentifier: document.studentIdentifier,
            dateOfBirth: document.dateOfBirth,
            pronouns: document.pronouns,
            assignedMemberIDs: document.assignedMemberIDs
        )
        guard StudentValidation.issues(
            for: draft,
            districtID: document.districtId,
            policy: .standard
        ).isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }

        return StudentRecord(
            id: documentID,
            districtID: document.districtId,
            schoolID: document.schoolId,
            displayName: document.displayName,
            grade: document.grade,
            studentIdentifier: document.studentIdentifier,
            dateOfBirth: document.dateOfBirth,
            pronouns: document.pronouns,
            assignedMemberIDs: document.assignedMemberIDs,
            isArchived: document.isArchived,
            metadata: CanonicalRecordMetadata(
                schemaVersion: document.schemaVersion,
                recordVersion: document.recordVersion,
                createdAt: document.createdAt,
                createdBy: document.createdBy,
                updatedAt: document.updatedAt,
                updatedBy: document.updatedBy
            )
        )
    }
}

nonisolated enum StudentStoreReadSource: Sendable, Equatable {
    case server
}

nonisolated enum StudentStoreQueryScope: Sendable, Equatable, Hashable {
    case assigned(memberID: String, schoolID: String)
    case school(schoolID: String)
    case district
}

nonisolated enum StudentSearchPredicate: Codable, Sendable, Equatable, Hashable {
    case normalizedNamePrefix(String)
    case normalizedStudentIdentifier(String)
}

nonisolated struct StudentStorePageRequest: Sendable, Equatable {
    let districtID: String
    let scope: StudentStoreQueryScope
    let search: StudentSearchPredicate?
    let schoolID: String?
    let grade: String?
    let assignedMemberID: String?
    let status: StudentRecordStatusFilter
    let sort: StudentRosterSort
    let cursor: StudentPageCursor?
    let limit: Int
    let source: StudentStoreReadSource

    init(
        districtID: String,
        scope: StudentStoreQueryScope,
        search: StudentSearchPredicate?,
        schoolID: String?,
        grade: String?,
        assignedMemberID: String?,
        status: StudentRecordStatusFilter,
        sort: StudentRosterSort = .alphabetical,
        cursor: StudentPageCursor?,
        limit: Int,
        source: StudentStoreReadSource
    ) {
        self.districtID = districtID
        self.scope = scope
        self.search = search
        self.schoolID = schoolID
        self.grade = grade
        self.assignedMemberID = assignedMemberID
        self.status = status
        self.sort = sort
        self.cursor = cursor
        self.limit = limit
        self.source = source
    }
}

nonisolated struct StudentStoreRecordRequest: Sendable, Equatable {
    let districtID: String
    let studentID: String
    let source: StudentStoreReadSource
}

nonisolated struct StudentStorePage: Codable, Sendable, Equatable {
    let documents: [FirebaseStudentSnapshot]
    let nextCursor: StudentPageCursor?
}

nonisolated enum StudentRecordStoreError: Error, Equatable {
    case transportUnavailable
    case permissionDenied
    case invalidResponse
}

nonisolated protocol StudentRecordStore: Sendable {
    func page(for request: StudentStorePageRequest) async throws -> StudentStorePage
    func student(for request: StudentStoreRecordRequest) async throws -> FirebaseStudentSnapshot?
}

nonisolated enum StudentFirestoreOrderField: String, Codable, Sendable, Equatable {
    case normalizedDisplayName
    case updatedAtDescending
    case documentID
}

nonisolated enum StudentFirestoreCursorValue: Sendable, Equatable {
    case string(String)
    case timestamp(Date)
}

nonisolated private struct StudentFirestoreFingerprintBasis: Codable, Sendable {
    let districtID: String
    let schoolID: String?
    let assignedMemberID: String?
    let grade: String?
    let status: StudentRecordStatusFilter
    let search: StudentSearchPredicate?
    let sort: StudentRosterSort
    let order: [StudentFirestoreOrderField]
    let limit: Int
}

/// A Firebase-independent description of the complete server query. The cursor
/// fingerprint prevents a continuation token from being replayed against a
/// different tenant, authorization scope, predicate, ordering, or page size.
nonisolated struct StudentFirestoreQueryPlan: Sendable, Equatable {
    let districtID: String
    let schoolID: String?
    let assignedMemberID: String?
    let grade: String?
    let status: StudentRecordStatusFilter
    let search: StudentSearchPredicate?
    let sort: StudentRosterSort
    let order: [StudentFirestoreOrderField]
    let limit: Int
    let fingerprint: String
    let startAfter: [StudentFirestoreCursorValue]?

    init(request: StudentStorePageRequest) throws {
        guard request.source == .server,
              TrustedIdentifier.isValid(request.districtID),
              request.limit > 0,
              request.limit <= StudentPageRequest.maximumPageSize else {
            throw StudentRepositoryError.invalidRequest
        }

        let scopedSchoolID: String?
        let scopedMemberID: String?
        switch request.scope {
        case .assigned(let memberID, let schoolID):
            scopedSchoolID = schoolID
            scopedMemberID = memberID
        case .school(let schoolID):
            scopedSchoolID = schoolID
            scopedMemberID = request.assignedMemberID
        case .district:
            scopedSchoolID = request.schoolID
            scopedMemberID = request.assignedMemberID
        }

        guard scopedSchoolID.map(TrustedIdentifier.isValid) ?? true,
              scopedMemberID.map(TrustedIdentifier.isValid) ?? true,
              request.schoolID.map({ $0 == scopedSchoolID }) ?? true,
              request.assignedMemberID.map({ $0 == scopedMemberID }) ?? true else {
            throw StudentRepositoryError.invalidRequest
        }

        if request.sort == .recentlyUpdated,
           case .normalizedNamePrefix = request.search {
            throw StudentRepositoryError.invalidRequest
        }

        let order: [StudentFirestoreOrderField]
        switch request.sort {
        case .alphabetical:
            order = [.normalizedDisplayName, .documentID]
        case .recentlyUpdated:
            order = [.updatedAtDescending, .documentID]
        }
        guard let fingerprint = Self.fingerprint(
            districtID: request.districtID,
            schoolID: scopedSchoolID,
            assignedMemberID: scopedMemberID,
            grade: request.grade,
            status: request.status,
            search: request.search,
            sort: request.sort,
            order: order,
            limit: request.limit
        ) else {
            throw StudentRepositoryError.invalidRequest
        }

        let startAfter: [StudentFirestoreCursorValue]?
        if let cursor = request.cursor {
            guard cursor.sort == request.sort,
                  cursor.queryFingerprint == fingerprint else {
                throw StudentRepositoryError.invalidRequest
            }
            switch request.sort {
            case .alphabetical:
                guard let sortValue = cursor.sortValue, !sortValue.isEmpty else {
                    throw StudentRepositoryError.invalidRequest
                }
                startAfter = [.string(sortValue), .string(cursor.token)]
            case .recentlyUpdated:
                guard let updatedAt = cursor.updatedAt else {
                    throw StudentRepositoryError.invalidRequest
                }
                startAfter = [.timestamp(updatedAt), .string(cursor.token)]
            }
        } else {
            startAfter = nil
        }

        self.districtID = request.districtID
        self.schoolID = scopedSchoolID
        self.assignedMemberID = scopedMemberID
        self.grade = request.grade
        self.status = request.status
        self.search = request.search
        self.sort = request.sort
        self.order = order
        self.limit = request.limit
        self.fingerprint = fingerprint
        self.startAfter = startAfter
    }

    func nextCursor(
        documentID: String,
        normalizedDisplayName: String?,
        updatedAt: Date? = nil
    ) throws -> StudentPageCursor {
        guard TrustedIdentifier.isValid(documentID) else {
            throw StudentRepositoryError.invalidResponse
        }
        switch sort {
        case .alphabetical:
            guard let normalizedDisplayName, !normalizedDisplayName.isEmpty else {
                throw StudentRepositoryError.invalidResponse
            }
            return StudentPageCursor(
                token: documentID,
                sort: sort,
                sortValue: normalizedDisplayName,
                queryFingerprint: fingerprint
            )
        case .recentlyUpdated:
            guard let updatedAt else {
                throw StudentRepositoryError.invalidResponse
            }
            return StudentPageCursor(
                token: documentID,
                sort: sort,
                updatedAt: updatedAt,
                queryFingerprint: fingerprint
            )
        }
    }

    private static func fingerprint(
        districtID: String,
        schoolID: String?,
        assignedMemberID: String?,
        grade: String?,
        status: StudentRecordStatusFilter,
        search: StudentSearchPredicate?,
        sort: StudentRosterSort,
        order: [StudentFirestoreOrderField],
        limit: Int
    ) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let basis = StudentFirestoreFingerprintBasis(
            districtID: districtID,
            schoolID: schoolID,
            assignedMemberID: assignedMemberID,
            grade: grade,
            status: status,
            search: search,
            sort: sort,
            order: order,
            limit: limit
        )
        return try? encoder.encode(basis).base64EncodedString()
    }
}

struct FirebaseStudentRecordStore: StudentRecordStore, @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func page(for request: StudentStorePageRequest) async throws -> StudentStorePage {
        let plan: StudentFirestoreQueryPlan
        do {
            plan = try StudentFirestoreQueryPlan(request: request)
        } catch {
            throw StudentRecordStoreError.invalidResponse
        }

        var query: Query = firestore
            .collection("districts")
            .document(plan.districtID)
            .collection("students")

        if let schoolID = plan.schoolID {
            query = query.whereField("schoolId", isEqualTo: schoolID)
        }
        if let assignedMemberID = plan.assignedMemberID {
            query = query.whereField("assignedMemberIDs", arrayContains: assignedMemberID)
        }
        if let grade = plan.grade {
            query = query.whereField("grade", isEqualTo: grade)
        }
        switch plan.status {
        case .active:
            query = query.whereField("isArchived", isEqualTo: false)
        case .archived:
            query = query.whereField("isArchived", isEqualTo: true)
        case .all:
            break
        }
        switch plan.search {
        case .normalizedNamePrefix(let prefix):
            query = query
                .whereField("normalizedDisplayName", isGreaterThanOrEqualTo: prefix)
                .whereField("normalizedDisplayName", isLessThan: prefix + "\u{f8ff}")
        case .normalizedStudentIdentifier(let identifier):
            query = query.whereField("normalizedStudentIdentifier", isEqualTo: identifier)
        case nil:
            break
        }

        for orderField in plan.order {
            switch orderField {
            case .normalizedDisplayName:
                query = query.order(by: "normalizedDisplayName")
            case .updatedAtDescending:
                query = query.order(by: "updatedAt", descending: true)
            case .documentID:
                query = query.order(by: FieldPath.documentID())
            }
        }
        if let startAfter = plan.startAfter {
            let cursorValues: [Any] = startAfter.map { value in
                switch value {
                case .string(let string):
                    string
                case .timestamp(let date):
                    date
                }
            }
            query = query.start(after: cursorValues)
        }
        query = query.limit(to: plan.limit)

        do {
            let snapshot = try await query.getDocuments(source: .server)
            let documents = try snapshot.documents.map { snapshot in
                FirebaseStudentSnapshot(
                    documentID: snapshot.documentID,
                    document: try snapshot.data(as: FirebaseStudentDocument.self)
                )
            }
            let nextCursor: StudentPageCursor?
            if snapshot.documents.count == plan.limit,
               let last = snapshot.documents.last,
               let lastDocument = documents.last?.document {
                nextCursor = try plan.nextCursor(
                    documentID: last.documentID,
                    normalizedDisplayName: last.data()["normalizedDisplayName"] as? String,
                    updatedAt: lastDocument.updatedAt
                )
            } else {
                nextCursor = nil
            }
            return StudentStorePage(documents: documents, nextCursor: nextCursor)
        } catch {
            throw Self.storeError(from: error)
        }
    }

    func student(for request: StudentStoreRecordRequest) async throws -> FirebaseStudentSnapshot? {
        guard request.source == .server else {
            throw StudentRecordStoreError.invalidResponse
        }
        do {
            let snapshot = try await firestore
                .collection("districts")
                .document(request.districtID)
                .collection("students")
                .document(request.studentID)
                .getDocument(source: .server)
            guard snapshot.exists else { return nil }
            return FirebaseStudentSnapshot(
                documentID: snapshot.documentID,
                document: try snapshot.data(as: FirebaseStudentDocument.self)
            )
        } catch {
            throw Self.storeError(from: error)
        }
    }

    private static func storeError(from error: any Error) -> StudentRecordStoreError {
        if let error = error as? StudentRecordStoreError {
            return error
        }
        let code = FirestoreErrorCode.Code(rawValue: (error as NSError).code)
        switch code {
        case .unavailable, .deadlineExceeded, .cancelled:
            return .transportUnavailable
        case .permissionDenied, .unauthenticated:
            return .permissionDenied
        default:
            return .invalidResponse
        }
    }
}

// MARK: - Cache and offline create outbox

nonisolated struct StudentCacheAuthority: Sendable, Hashable {
    let districtID: String
    let userID: String
}

nonisolated struct StudentPageCacheKey: Codable, Sendable, Hashable {
    let districtID: String
    let userID: String
    let membershipVersion: Int
    let search: StudentSearchPredicate?
    let schoolID: String?
    let grade: String?
    let assignedMemberID: String?
    let status: StudentRecordStatusFilter
    let sort: StudentRosterSort
    let cursor: StudentPageCursor?
    let limit: Int
}

nonisolated protocol StudentPageCache: Sendable {
    func page(for key: StudentPageCacheKey) async -> StudentStorePage?
    func save(_ page: StudentStorePage, for key: StudentPageCacheKey) async
    func invalidate(authority: StudentCacheAuthority) async
}

actor InMemoryStudentPageCache: StudentPageCache {
    private var pages: [StudentPageCacheKey: StudentStorePage] = [:]

    func page(for key: StudentPageCacheKey) -> StudentStorePage? {
        pages[key]
    }

    func save(_ page: StudentStorePage, for key: StudentPageCacheKey) {
        pages[key] = page
    }

    func invalidate(authority: StudentCacheAuthority) {
        pages = pages.filter { key, _ in
            key.districtID != authority.districtID || key.userID != authority.userID
        }
    }
}

nonisolated protocol StudentPageCachePersistence: Sendable {
    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws
    func restore<T: Codable & Sendable>(_ type: T.Type, for key: String) async throws -> T
    func remove(for key: String) throws
}

nonisolated extension SecureStorage: StudentPageCachePersistence {
    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws {
        try await store(object, for: key)
    }

    func restore<T: Codable & Sendable>(_ type: T.Type, for key: String) async throws -> T {
        try await retrieve(type, for: key)
    }

    func remove(for key: String) throws {
        try delete(for: key)
    }
}

/// Device-bound encrypted persistence for server-confirmed roster pages.
///
/// Keys include the trusted tenant, user, membership version, and complete
/// query shape. Cached pages therefore cannot be reused after a role/version
/// change or across authorities. The bounded archive avoids unbounded Keychain
/// growth while allowing an offline relaunch to restore recent roster reads.
actor SecureStudentPageCache: StudentPageCache {
    private struct Entry: Codable, Sendable {
        let key: StudentPageCacheKey
        let page: StudentStorePage
        let savedAt: Date
    }

    private struct Archive: Codable, Sendable {
        var entries: [Entry]
    }

    nonisolated static let defaultStorageKey = "student-page-cache.v1"
    nonisolated static let defaultDeniedAuthoritiesStorageKey =
        "student-page-cache.v1.denied-authorities"

    private let storage: any StudentPageCachePersistence
    private let storageKey: String
    private let deniedAuthorityStorageKeyPrefix: String
    private let maximumEntryCount: Int
    private var sessionDeniedFingerprints: Set<String> = []

    init(
        storage: any StudentPageCachePersistence = SecureStorage.shared,
        storageKey: String = SecureStudentPageCache.defaultStorageKey,
        maximumEntryCount: Int = 16
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.deniedAuthorityStorageKeyPrefix = "\(storageKey).denied-authorities"
        self.maximumEntryCount = max(1, maximumEntryCount)
    }

    func page(for key: StudentPageCacheKey) async -> StudentStorePage? {
        let fingerprint = Self.authorityFingerprint(
            districtID: key.districtID,
            userID: key.userID
        )
        let isPersistentlyDenied = await isAuthorityDenied(fingerprint: fingerprint)
        guard !sessionDeniedFingerprints.contains(fingerprint),
              !isPersistentlyDenied else {
            return nil
        }
        return await loadArchive().entries.first(where: { $0.key == key })?.page
    }

    func save(_ page: StudentStorePage, for key: StudentPageCacheKey) async {
        var archive = await loadArchive()
        archive.entries.removeAll { $0.key == key }
        archive.entries.append(Entry(key: key, page: page, savedAt: .now))
        archive.entries = Array(
            archive.entries
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(maximumEntryCount)
        )
        guard await persistArchive(archive) else { return }

        let fingerprint = Self.authorityFingerprint(
            districtID: key.districtID,
            userID: key.userID
        )
        do {
            try storage.remove(for: deniedAuthorityStorageKey(fingerprint: fingerprint))
        } catch {
            return
        }
        sessionDeniedFingerprints.remove(fingerprint)
    }

    func invalidate(authority: StudentCacheAuthority) async {
        let fingerprint = Self.authorityFingerprint(
            districtID: authority.districtID,
            userID: authority.userID
        )
        sessionDeniedFingerprints.insert(fingerprint)

        do {
            try await storage.persist(
                true,
                for: deniedAuthorityStorageKey(fingerprint: fingerprint)
            )
        } catch {
            await removeArchiveAfterTombstoneFailure()
            return
        }

        var archive = await loadArchive()
        archive.entries.removeAll {
            $0.key.districtID == authority.districtID
                && $0.key.userID == authority.userID
        }
        _ = await persistArchive(archive)
    }

    private func loadArchive() async -> Archive {
        do {
            return try await storage.restore(Archive.self, for: storageKey)
        } catch {
            return Archive(entries: [])
        }
    }

    private func isAuthorityDenied(fingerprint: String) async -> Bool {
        do {
            return try await storage.restore(
                Bool.self,
                for: deniedAuthorityStorageKey(fingerprint: fingerprint)
            )
        } catch SecureStorageError.dataNotFound {
            return false
        } catch {
            return true
        }
    }

    private func persistArchive(_ archive: Archive) async -> Bool {
        do {
            if archive.entries.isEmpty {
                try storage.remove(for: storageKey)
            } else {
                try await storage.persist(archive, for: storageKey)
            }
            return true
        } catch {
            return false
        }
    }

    private func removeArchiveAfterTombstoneFailure() async {
        do {
            try storage.remove(for: storageKey)
        } catch {
            try? await storage.persist(Archive(entries: []), for: storageKey)
        }
    }

    private func deniedAuthorityStorageKey(fingerprint: String) -> String {
        "\(deniedAuthorityStorageKeyPrefix).\(fingerprint)"
    }

    private static func authorityFingerprint(
        districtID: String,
        userID: String
    ) -> String {
        let input = [
            "tmi.student-page-cache.authority.v1",
            "\(districtID.utf8.count):\(districtID)",
            "\(userID.utf8.count):\(userID)",
        ].joined(separator: "|")
        return Data(SHA256.hash(data: Data(input.utf8))).base64EncodedString()
    }
}

nonisolated struct PendingStudentCreate: Codable, Sendable, Equatable {
    enum Disposition: String, Codable, Sendable {
        case queued
        case requiresReview
    }

    let operationID: UUID
    let districtID: String
    let userID: String
    let membershipVersion: Int
    let draft: StudentDraft
    let enqueuedAt: Date
    let disposition: Disposition

    init(
        operationID: UUID,
        districtID: String,
        userID: String,
        membershipVersion: Int,
        draft: StudentDraft,
        enqueuedAt: Date = .now,
        disposition: Disposition = .queued
    ) {
        self.operationID = operationID
        self.districtID = districtID
        self.userID = userID
        self.membershipVersion = membershipVersion
        self.draft = draft
        self.enqueuedAt = enqueuedAt
        self.disposition = disposition
    }

    func rebinding(to membershipVersion: Int) -> PendingStudentCreate {
        PendingStudentCreate(
            operationID: operationID,
            districtID: districtID,
            userID: userID,
            membershipVersion: membershipVersion,
            draft: draft,
            enqueuedAt: enqueuedAt,
            disposition: disposition
        )
    }

    func quarantinedForReview() -> PendingStudentCreate {
        PendingStudentCreate(
            operationID: operationID,
            districtID: districtID,
            userID: userID,
            membershipVersion: membershipVersion,
            draft: draft,
            enqueuedAt: enqueuedAt,
            disposition: .requiresReview
        )
    }

    private enum CodingKeys: String, CodingKey {
        case operationID
        case districtID
        case userID
        case membershipVersion
        case draft
        case enqueuedAt
        case disposition
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operationID = try container.decode(UUID.self, forKey: .operationID)
        districtID = try container.decode(String.self, forKey: .districtID)
        userID = try container.decode(String.self, forKey: .userID)
        membershipVersion = try container.decode(Int.self, forKey: .membershipVersion)
        draft = try container.decode(StudentDraft.self, forKey: .draft)
        enqueuedAt = try container.decode(Date.self, forKey: .enqueuedAt)
        disposition = try container.decodeIfPresent(
            Disposition.self,
            forKey: .disposition
        ) ?? .queued
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operationID, forKey: .operationID)
        try container.encode(districtID, forKey: .districtID)
        try container.encode(userID, forKey: .userID)
        try container.encode(membershipVersion, forKey: .membershipVersion)
        try container.encode(draft, forKey: .draft)
        try container.encode(enqueuedAt, forKey: .enqueuedAt)
        try container.encode(disposition, forKey: .disposition)
    }
}

nonisolated protocol StudentCreateOutbox: Sendable {
    func enqueue(_ item: PendingStudentCreate) async throws
    func pending() async throws -> [PendingStudentCreate]
    func remove(operationID: UUID) async throws
}

actor InMemoryStudentCreateOutbox: StudentCreateOutbox {
    private var itemsByOperationID: [UUID: PendingStudentCreate] = [:]

    func enqueue(_ item: PendingStudentCreate) {
        itemsByOperationID[item.operationID] = item
    }

    func pending() -> [PendingStudentCreate] {
        itemsByOperationID.values.sorted(by: Self.isEarlier)
    }

    func remove(operationID: UUID) {
        itemsByOperationID.removeValue(forKey: operationID)
    }

    private static func isEarlier(_ lhs: PendingStudentCreate, _ rhs: PendingStudentCreate) -> Bool {
        if lhs.enqueuedAt == rhs.enqueuedAt {
            return lhs.operationID.uuidString < rhs.operationID.uuidString
        }
        return lhs.enqueuedAt < rhs.enqueuedAt
    }
}

nonisolated protocol StudentCreateOutboxStorage: Sendable {
    func load() async throws -> [PendingStudentCreate]
    func save(_ items: [PendingStudentCreate]) async throws
}

nonisolated struct SecureStorageStudentCreateOutboxStorage: StudentCreateOutboxStorage {
    nonisolated static let defaultStorageKey = "students.pending-creates"
    private let secureStorage: SecureStorage

    init(secureStorage: SecureStorage = .shared) {
        self.secureStorage = secureStorage
    }

    func load() async throws -> [PendingStudentCreate] {
        guard secureStorage.exists(for: Self.defaultStorageKey) else { return [] }
        return try await secureStorage.retrieve(
            [PendingStudentCreate].self,
            for: Self.defaultStorageKey
        )
    }

    func save(_ items: [PendingStudentCreate]) async throws {
        if items.isEmpty {
            guard secureStorage.exists(for: Self.defaultStorageKey) else { return }
            try secureStorage.delete(for: Self.defaultStorageKey)
            return
        }
        try await secureStorage.store(items, for: Self.defaultStorageKey)
    }
}

actor SecureStudentCreateOutbox: StudentCreateOutbox {
    private let storage: any StudentCreateOutboxStorage

    init(storage: any StudentCreateOutboxStorage = SecureStorageStudentCreateOutboxStorage()) {
        self.storage = storage
    }

    func enqueue(_ item: PendingStudentCreate) async throws {
        var items = try await storage.load()
        items.removeAll { $0.operationID == item.operationID }
        items.append(item)
        try await storage.save(Self.sorted(items))
    }

    func pending() async throws -> [PendingStudentCreate] {
        Self.sorted(try await storage.load())
    }

    func remove(operationID: UUID) async throws {
        var items = try await storage.load()
        items.removeAll { $0.operationID == operationID }
        try await storage.save(Self.sorted(items))
    }

    private static func sorted(_ items: [PendingStudentCreate]) -> [PendingStudentCreate] {
        items.sorted { lhs, rhs in
            if lhs.enqueuedAt == rhs.enqueuedAt {
                return lhs.operationID.uuidString < rhs.operationID.uuidString
            }
            return lhs.enqueuedAt < rhs.enqueuedAt
        }
    }
}

// MARK: - Trusted mutation callables

nonisolated enum StudentMutationReasonCode: String, Codable, Sendable, Equatable {
    case staffRosterCreate = "staff_roster_create"
    case staffRosterUpdate = "staff_roster_update"
    case staffRosterArchive = "staff_roster_archive"
}

nonisolated struct StudentMutationBase: Sendable, Equatable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: StudentMutationReasonCode
}

nonisolated struct StudentCreateMutationRequest: Sendable, Equatable {
    let base: StudentMutationBase
    let schoolID: String
    let displayName: String
    let grade: String
    let studentIdentifier: String?
    let dateOfBirth: Date?
    let pronouns: String?
    let assignedMemberIDs: Set<String>
}

nonisolated struct StudentUpdateMutationRequest: Sendable, Equatable {
    let base: StudentMutationBase
    let studentID: String
    let schoolID: String
    let displayName: String
    let grade: String
    let studentIdentifier: String?
    let dateOfBirth: Date?
    let pronouns: String?
    let assignedMemberIDs: Set<String>
}

nonisolated struct StudentArchiveMutationRequest: Sendable, Equatable {
    let base: StudentMutationBase
    let studentID: String
}

nonisolated struct StudentMutationResult: Sendable, Equatable {
    let studentID: String
    let recordVersion: Int
    let replayed: Bool
    let membership: StudentMutationMembership
}

nonisolated struct StudentMutationMembership: Codable, Sendable, Equatable {
    let districtID: String
    let schoolIDs: Set<String>
    let role: StaffRole
    let capabilities: Set<Capability>
    let assignedStudentIDs: Set<String>
    let isActive: Bool
    let version: Int

    func context(userID: String) throws -> MembershipContext {
        guard TrustedIdentifier.isValid(userID),
              TrustedIdentifier.isValid(districtID),
              schoolIDs.allSatisfy(TrustedIdentifier.isValid),
              assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid),
              version > 0 else {
            throw StudentRepositoryError.invalidResponse
        }
        return MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: schoolIDs,
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assignedStudentIDs,
            isActive: isActive,
            version: version
        )
    }
}

nonisolated enum StudentMutationBackendError: Error, Equatable {
    case transportUnavailable
    case permissionDenied
    case duplicate(candidateIDs: [String])
    case versionConflict(expected: Int, actual: Int)
    case idempotencyKeyReused
    case invalidResponse
}

nonisolated enum StudentMutationBackendErrorMapper {
    static func map(_ error: any Error) -> StudentMutationBackendError {
        if let error = error as? StudentMutationBackendError {
            return error
        }

        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else {
            return .invalidResponse
        }

        let code = FunctionsErrorCode(rawValue: nsError.code)
        if code == .unavailable {
            return .transportUnavailable
        }
        if code == .permissionDenied || code == .unauthenticated {
            return .permissionDenied
        }

        guard let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any],
              let kind = details["kind"] as? String else {
            return .invalidResponse
        }
        switch (code, kind) {
        case (.alreadyExists, "student-duplicate"):
            guard let candidateIDs = details["candidateIDs"] as? [String],
                  !candidateIDs.isEmpty,
                  candidateIDs.allSatisfy(TrustedIdentifier.isValid) else {
                return .invalidResponse
            }
            return .duplicate(candidateIDs: candidateIDs.sorted())
        case (.aborted, "record-version-conflict"):
            guard let expected = integer(details["expectedRecordVersion"]),
                  let actual = integer(details["actualRecordVersion"]),
                  expected > 0,
                  actual > 0 else {
                return .invalidResponse
            }
            return .versionConflict(expected: expected, actual: actual)
        case (.alreadyExists, "idempotency-key-reused"):
            return .idempotencyKeyReused
        default:
            return .invalidResponse
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}

nonisolated protocol StudentTrustedMutationBackend: Sendable {
    func createStudent(_ request: StudentCreateMutationRequest) async throws -> StudentMutationResult
    func updateStudent(_ request: StudentUpdateMutationRequest) async throws -> StudentMutationResult
    func archiveStudent(_ request: StudentArchiveMutationRequest) async throws -> StudentMutationResult
}

nonisolated protocol StudentMutationAuthorityRefreshing: Sendable {
    func refresh(
        membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext
}

nonisolated enum StudentMutationAuthorityRefreshError: Error, Equatable {
    case unauthenticated
    case invalidResponse
    case unavailable
}

/// Forces the new custom claim into the Firebase client and republishes the
/// complete trusted session before a post-mutation Firestore read.
@MainActor
final class FirebaseStudentMutationAuthorityRefresher: StudentMutationAuthorityRefreshing {
    private let auth: Auth
    private let sessionStore: TrustedAuthorizationSessionStore

    init(
        auth: Auth = Auth.auth(),
        sessionStore: TrustedAuthorizationSessionStore = .shared
    ) {
        self.auth = auth
        self.sessionStore = sessionStore
    }

    func refresh(
        membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext {
        try await refreshOnMainActor(
            membership: membership,
            previous: previous
        )
    }

    private func refreshOnMainActor(
        membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext {
        guard let existingSession = sessionStore.session(authenticatedUserID: previous.userID),
              let user = auth.currentUser,
              user.uid == previous.userID else {
            throw StudentMutationAuthorityRefreshError.unauthenticated
        }

        let tokenResult: AuthTokenResult
        do {
            tokenResult = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            throw StudentMutationAuthorityRefreshError.unavailable
        }

        let claim: TrustedTenantClaim
        let refreshedMembership: MembershipContext
        do {
            claim = try TrustedTenantClaim(
                userID: user.uid,
                tokenClaims: tokenResult.claims
            )
            refreshedMembership = try membership.context(userID: user.uid)
        } catch {
            throw StudentMutationAuthorityRefreshError.invalidResponse
        }

        guard refreshedMembership.isActive,
              refreshedMembership.districtID == previous.districtID,
              claim.districtID == refreshedMembership.districtID,
              claim.membershipVersion == refreshedMembership.version,
              claim.membershipVersion >= previous.version else {
            throw StudentMutationAuthorityRefreshError.invalidResponse
        }

        sessionStore.publish(AuthenticatedSession(
            profile: existingSession.profile,
            claim: claim,
            membership: refreshedMembership
        ))
        return refreshedMembership
    }
}

nonisolated private struct StudentCreateCallablePayload: Codable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let schoolID: String
    let displayName: String
    let grade: String
    let studentIdentifier: String?
    let dateOfBirth: String?
    let pronouns: String?
    let assignedMemberIDs: [String]
}

nonisolated private struct StudentUpdateCallablePayload: Codable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
    let schoolID: String
    let displayName: String
    let grade: String
    let studentIdentifier: String?
    let dateOfBirth: String?
    let pronouns: String?
    let assignedMemberIDs: [String]
}

nonisolated private struct StudentArchiveCallablePayload: Codable, Sendable {
    let districtID: String
    let expectedRecordVersion: Int
    let idempotencyKey: String
    let reasonCode: String
    let studentID: String
}

nonisolated private struct StudentCallableResponse: Codable, Sendable {
    let studentID: String
    let recordVersion: Int
    let replayed: Bool
    let membership: StudentMutationMembership
}

nonisolated struct FirebaseStudentTrustedMutationBackend: StudentTrustedMutationBackend, @unchecked Sendable {
    private let functions: Functions

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }

    func createStudent(_ request: StudentCreateMutationRequest) async throws -> StudentMutationResult {
        let payload = StudentCreateCallablePayload(
            districtID: request.base.districtID,
            expectedRecordVersion: request.base.expectedRecordVersion,
            idempotencyKey: request.base.idempotencyKey,
            reasonCode: request.base.reasonCode.rawValue,
            schoolID: request.schoolID,
            displayName: request.displayName,
            grade: request.grade,
            studentIdentifier: request.studentIdentifier,
            dateOfBirth: Self.iso8601(request.dateOfBirth),
            pronouns: request.pronouns,
            assignedMemberIDs: request.assignedMemberIDs.sorted()
        )
        return try await perform(name: "createStudent", payload: payload)
    }

    func updateStudent(_ request: StudentUpdateMutationRequest) async throws -> StudentMutationResult {
        let payload = StudentUpdateCallablePayload(
            districtID: request.base.districtID,
            expectedRecordVersion: request.base.expectedRecordVersion,
            idempotencyKey: request.base.idempotencyKey,
            reasonCode: request.base.reasonCode.rawValue,
            studentID: request.studentID,
            schoolID: request.schoolID,
            displayName: request.displayName,
            grade: request.grade,
            studentIdentifier: request.studentIdentifier,
            dateOfBirth: Self.iso8601(request.dateOfBirth),
            pronouns: request.pronouns,
            assignedMemberIDs: request.assignedMemberIDs.sorted()
        )
        return try await perform(name: "updateStudent", payload: payload)
    }

    func archiveStudent(_ request: StudentArchiveMutationRequest) async throws -> StudentMutationResult {
        let payload = StudentArchiveCallablePayload(
            districtID: request.base.districtID,
            expectedRecordVersion: request.base.expectedRecordVersion,
            idempotencyKey: request.base.idempotencyKey,
            reasonCode: request.base.reasonCode.rawValue,
            studentID: request.studentID
        )
        return try await perform(name: "archiveStudent", payload: payload)
    }

    private func perform<Request: Encodable & Sendable>(
        name: String,
        payload: Request
    ) async throws -> StudentMutationResult {
        do {
            let callable: Callable<Request, StudentCallableResponse> = functions.httpsCallable(name)
            let response = try await callable.call(payload)
            guard TrustedIdentifier.isValid(response.studentID),
                  response.recordVersion > 0 else {
                throw StudentMutationBackendError.invalidResponse
            }
            return StudentMutationResult(
                studentID: response.studentID,
                recordVersion: response.recordVersion,
                replayed: response.replayed,
                membership: response.membership
            )
        } catch let error as StudentMutationBackendError {
            throw error
        } catch {
            throw StudentMutationBackendErrorMapper.map(error)
        }
    }

    private static func iso8601(_ date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

}

// MARK: - Repository implementation

nonisolated private struct NormalizedStudentPageRequest: Sendable, Equatable {
    let search: StudentSearchPredicate?
    let schoolID: String?
    let grade: String?
    let assignedMemberID: String?
    let status: StudentRecordStatusFilter
    let sort: StudentRosterSort
    let cursor: StudentPageCursor?
    let limit: Int
}

actor CanonicalStudentRepository: StudentRepository {
    private let store: any StudentRecordStore
    private let mutationBackend: any StudentTrustedMutationBackend
    private let cache: any StudentPageCache
    private let outbox: any StudentCreateOutbox
    private let authorityRefresher: any StudentMutationAuthorityRefreshing
    private var latestVersionByAuthority: [StudentCacheAuthority: Int] = [:]

    init(
        store: any StudentRecordStore,
        mutationBackend: any StudentTrustedMutationBackend,
        cache: any StudentPageCache = InMemoryStudentPageCache(),
        outbox: any StudentCreateOutbox = InMemoryStudentCreateOutbox(),
        authorityRefresher: any StudentMutationAuthorityRefreshing
    ) {
        self.store = store
        self.mutationBackend = mutationBackend
        self.cache = cache
        self.outbox = outbox
        self.authorityRefresher = authorityRefresher
    }

    func page(_ request: StudentPageRequest, member: MembershipContext) async throws -> StudentPage {
        try await validate(member)
        let normalized = try normalized(request)
        let scope = try readScope(for: normalized, member: member)
        let storeRequest = StudentStorePageRequest(
            districtID: member.districtID,
            scope: scope,
            search: normalized.search,
            schoolID: normalized.schoolID,
            grade: normalized.grade,
            assignedMemberID: normalized.assignedMemberID,
            status: normalized.status,
            sort: normalized.sort,
            cursor: normalized.cursor,
            limit: normalized.limit,
            source: .server
        )
        let cacheKey = cacheKey(for: normalized, member: member)

        let storedPage: StudentStorePage
        let source: StudentPageSource
        do {
            storedPage = try await store.page(for: storeRequest)
            source = .server
        } catch StudentRecordStoreError.transportUnavailable {
            guard let cachedPage = await cache.page(for: cacheKey) else {
                throw StudentRepositoryError.unavailable
            }
            storedPage = cachedPage
            source = .cache
        } catch StudentRecordStoreError.permissionDenied {
            await invalidateCachedPages(for: member)
            throw StudentRepositoryError.permissionDenied
        } catch {
            throw StudentRepositoryError.invalidResponse
        }

        let records = try decodedAuthorizedRecords(
            storedPage.documents,
            member: member,
            request: storeRequest
        )
        if source == .server {
            await cache.save(storedPage, for: cacheKey)
        }
        return StudentPage(
            records: records,
            nextCursor: storedPage.nextCursor,
            source: source
        )
    }

    func student(id: String, member: MembershipContext) async throws -> StudentRecord {
        try await validate(member)
        return try await authoritativeStudent(id: id, member: member)
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        try await validate(member)
        let normalizedDraft = try validated(draft, member: member)
        let school = SchoolAuthorizationScope(
            districtID: member.districtID,
            schoolID: normalizedDraft.schoolID
        )
        guard AuthorizationPolicy.canCreateStudent(member, school: school) else {
            throw StudentRepositoryError.permissionDenied
        }

        let request = StudentCreateMutationRequest(
            base: mutationBase(
                member: member,
                expectedVersion: 0,
                operationID: operationID,
                reasonCode: .staffRosterCreate
            ),
            schoolID: normalizedDraft.schoolID,
            displayName: normalizedDraft.displayName,
            grade: normalizedDraft.grade,
            studentIdentifier: normalizedDraft.studentIdentifier,
            dateOfBirth: normalizedDraft.dateOfBirth,
            pronouns: normalizedDraft.pronouns,
            assignedMemberIDs: normalizedDraft.assignedMemberIDs
        )

        let result: StudentMutationResult
        do {
            result = try await mutationBackend.createStudent(request)
        } catch StudentMutationBackendError.transportUnavailable {
            do {
                try await outbox.enqueue(PendingStudentCreate(
                    operationID: operationID,
                    districtID: member.districtID,
                    userID: member.userID,
                    membershipVersion: member.version,
                    draft: normalizedDraft
                ))
            } catch {
                throw StudentRepositoryError.unavailable
            }
            throw StudentRepositoryError.createQueued(operationID: operationID)
        } catch {
            throw mapMutationError(error)
        }

        await invalidateCachedPages(for: member)
        let refreshedMember = try await refreshedMember(
            from: result.membership,
            previous: member
        )
        let record = try await authoritativeStudent(id: result.studentID, member: refreshedMember)
        guard record.metadata.recordVersion == result.recordVersion else {
            throw StudentRepositoryError.invalidResponse
        }
        return record
    }

    /// Drains durable offline creates in enqueue order. Every item is bound to
    /// the exact authenticated authority that queued it, and is removed only
    /// after a server read confirms the callable result and record version.
    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord] {
        try await validate(member)
        var items: [PendingStudentCreate]
        do {
            items = try await outbox.pending().filter {
                $0.userID == member.userID && $0.districtID == member.districtID
            }
        } catch {
            throw StudentRepositoryError.unavailable
        }
        guard !items.isEmpty else { return [] }

        var currentMember = member
        var reconciled: [StudentRecord] = []
        var hasItemsRequiringReview = false
        var index = 0
        while index < items.count {
            var item = items[index]
            guard item.userID == currentMember.userID,
                  item.districtID == currentMember.districtID else {
                throw StudentRepositoryError.permissionDenied
            }
            if item.disposition == .requiresReview {
                hasItemsRequiringReview = true
                index += 1
                continue
            }
            if item.membershipVersion != currentMember.version {
                let quarantined = try await quarantineForReview(item)
                items[index] = quarantined
                hasItemsRequiringReview = true
                index += 1
                continue
            }

            let normalizedDraft: StudentDraft
            do {
                normalizedDraft = try validated(item.draft, member: currentMember)
            } catch {
                items[index] = try await quarantineForReview(item)
                hasItemsRequiringReview = true
                index += 1
                continue
            }
            let school = SchoolAuthorizationScope(
                districtID: currentMember.districtID,
                schoolID: normalizedDraft.schoolID
            )
            guard AuthorizationPolicy.canCreateStudent(currentMember, school: school) else {
                items[index] = try await quarantineForReview(item)
                hasItemsRequiringReview = true
                index += 1
                continue
            }
            let request = StudentCreateMutationRequest(
                base: mutationBase(
                    member: currentMember,
                    expectedVersion: 0,
                    operationID: item.operationID,
                    reasonCode: .staffRosterCreate
                ),
                schoolID: normalizedDraft.schoolID,
                displayName: normalizedDraft.displayName,
                grade: normalizedDraft.grade,
                studentIdentifier: normalizedDraft.studentIdentifier,
                dateOfBirth: normalizedDraft.dateOfBirth,
                pronouns: normalizedDraft.pronouns,
                assignedMemberIDs: normalizedDraft.assignedMemberIDs
            )

            let result: StudentMutationResult
            do {
                result = try await mutationBackend.createStudent(request)
            } catch StudentMutationBackendError.transportUnavailable {
                throw StudentRepositoryError.unavailable
            } catch {
                let mappedError = mapMutationError(error)
                switch mappedError {
                case .permissionDenied,
                     .duplicate,
                     .versionConflict,
                     .idempotencyKeyReused,
                     .invalidDraft,
                     .invalidRequest:
                    items[index] = try await quarantineForReview(item)
                    hasItemsRequiringReview = true
                    index += 1
                    continue
                default:
                    throw mappedError
                }
            }

            await invalidateCachedPages(for: currentMember)
            let refreshed = try await refreshedMember(
                from: result.membership,
                previous: currentMember
            )

            // Persist refreshed authority before confirmation. If the server
            // read is temporarily unavailable, the idempotency key and draft
            // remain retryable under the newly issued membership version.
            for remainingIndex in index..<items.count {
                let remaining = items[remainingIndex]
                guard remaining.userID == refreshed.userID,
                      remaining.districtID == refreshed.districtID,
                      remaining.disposition == .queued else {
                    continue
                }
                let rebound = remaining.rebinding(to: refreshed.version)
                do {
                    try await outbox.enqueue(rebound)
                } catch {
                    throw StudentRepositoryError.unavailable
                }
                items[remainingIndex] = rebound
            }
            item = items[index]

            let record = try await authoritativeStudent(
                id: result.studentID,
                member: refreshed
            )
            guard record.metadata.recordVersion == result.recordVersion else {
                throw StudentRepositoryError.invalidResponse
            }
            do {
                try await outbox.remove(operationID: item.operationID)
            } catch {
                throw StudentRepositoryError.unavailable
            }
            reconciled.append(record)
            currentMember = refreshed
            index += 1
        }
        if hasItemsRequiringReview {
            throw StudentRepositoryError.staleMembership
        }
        return reconciled
    }

    private func quarantineForReview(
        _ item: PendingStudentCreate
    ) async throws -> PendingStudentCreate {
        let quarantined = item.quarantinedForReview()
        do {
            try await outbox.enqueue(quarantined)
        } catch {
            throw StudentRepositoryError.unavailable
        }
        return quarantined
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        try await validate(member)
        guard expectedVersion > 0 else {
            throw StudentRepositoryError.invalidRequest
        }
        let existing = try await authoritativeStudent(id: id, member: member)
        guard AuthorizationPolicy.canWriteStudentDetail(
            member,
            student: authorizationScope(for: existing)
        ) else {
            throw StudentRepositoryError.permissionDenied
        }
        let normalizedDraft = try validated(draft, member: member)
        let targetSchool = SchoolAuthorizationScope(
            districtID: member.districtID,
            schoolID: normalizedDraft.schoolID
        )
        guard existing.schoolID == normalizedDraft.schoolID
                || AuthorizationPolicy.canCreateStudent(member, school: targetSchool) else {
            throw StudentRepositoryError.permissionDenied
        }

        let request = StudentUpdateMutationRequest(
            base: mutationBase(
                member: member,
                expectedVersion: expectedVersion,
                operationID: operationID,
                reasonCode: .staffRosterUpdate
            ),
            studentID: id,
            schoolID: normalizedDraft.schoolID,
            displayName: normalizedDraft.displayName,
            grade: normalizedDraft.grade,
            studentIdentifier: normalizedDraft.studentIdentifier,
            dateOfBirth: normalizedDraft.dateOfBirth,
            pronouns: normalizedDraft.pronouns,
            assignedMemberIDs: normalizedDraft.assignedMemberIDs
        )

        let result: StudentMutationResult
        do {
            result = try await mutationBackend.updateStudent(request)
        } catch {
            throw mapMutationError(error)
        }
        await invalidateCachedPages(for: member)
        guard result.studentID == id else {
            throw StudentRepositoryError.invalidResponse
        }

        let refreshedMember = try await refreshedMember(
            from: result.membership,
            previous: member
        )
        let record = try await authoritativeStudent(id: id, member: refreshedMember)
        guard record.metadata.recordVersion == result.recordVersion else {
            throw StudentRepositoryError.invalidResponse
        }
        return record
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        try await validate(member)
        guard expectedVersion > 0 else {
            throw StudentRepositoryError.invalidRequest
        }
        let existing = try await authoritativeStudent(id: id, member: member)
        guard AuthorizationPolicy.canWriteStudentDetail(
            member,
            student: authorizationScope(for: existing)
        ) else {
            throw StudentRepositoryError.permissionDenied
        }

        let request = StudentArchiveMutationRequest(
            base: mutationBase(
                member: member,
                expectedVersion: expectedVersion,
                operationID: operationID,
                reasonCode: .staffRosterArchive
            ),
            studentID: id
        )
        let result: StudentMutationResult
        do {
            result = try await mutationBackend.archiveStudent(request)
        } catch StudentMutationBackendError.transportUnavailable {
            throw StudentRepositoryError.onlineRequired
        } catch {
            throw mapMutationError(error)
        }
        await invalidateCachedPages(for: member)
        guard result.studentID == id,
              result.recordVersion > expectedVersion else {
            throw StudentRepositoryError.invalidResponse
        }
        _ = try await refreshedMember(
            from: result.membership,
            previous: member
        )
    }

    private func validate(_ member: MembershipContext) async throws {
        let authority = StudentCacheAuthority(
            districtID: member.districtID,
            userID: member.userID
        )
        guard member.isActive,
              member.version > 0,
              TrustedIdentifier.isValid(member.userID),
              TrustedIdentifier.isValid(member.districtID),
              member.schoolIDs.allSatisfy(TrustedIdentifier.isValid),
              member.assignedStudentIDs.allSatisfy(TrustedIdentifier.isValid) else {
            await cache.invalidate(authority: authority)
            latestVersionByAuthority.removeValue(forKey: authority)
            throw StudentRepositoryError.permissionDenied
        }

        if let latestVersion = latestVersionByAuthority[authority] {
            guard member.version >= latestVersion else {
                throw StudentRepositoryError.staleMembership
            }
            if member.version > latestVersion {
                await cache.invalidate(authority: authority)
            }
        }
        latestVersionByAuthority[authority] = member.version
    }

    private func invalidateCachedPages(for member: MembershipContext) async {
        await cache.invalidate(authority: StudentCacheAuthority(
            districtID: member.districtID,
            userID: member.userID
        ))
    }

    private func refreshedMember(
        from membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext {
        let refreshed: MembershipContext
        do {
            refreshed = try await authorityRefresher.refresh(
                membership: membership,
                previous: previous
            )
        } catch StudentMutationAuthorityRefreshError.unauthenticated {
            throw StudentRepositoryError.permissionDenied
        } catch StudentMutationAuthorityRefreshError.invalidResponse {
            throw StudentRepositoryError.invalidResponse
        } catch {
            throw StudentRepositoryError.unavailable
        }

        guard refreshed.userID == previous.userID,
              refreshed.districtID == previous.districtID,
              refreshed.version >= previous.version else {
            throw StudentRepositoryError.invalidResponse
        }
        try await validate(refreshed)
        return refreshed
    }

    private func normalized(_ request: StudentPageRequest) throws -> NormalizedStudentPageRequest {
        let schoolID = Self.normalizedIdentifier(request.schoolID)
        let assignedMemberID = Self.normalizedIdentifier(request.assignedMemberID)
        let cursor = request.cursor.map {
            StudentPageCursor(
                token: $0.token.trimmingCharacters(in: .whitespacesAndNewlines),
                sort: $0.sort,
                sortValue: Self.normalizedSearchText($0.sortValue),
                updatedAt: $0.updatedAt,
                queryFingerprint: Self.normalizedIdentifier($0.queryFingerprint)
            )
        }
        let search = Self.normalizedSearchPredicate(request.search)
        guard request.limit > 0,
              schoolID.map(TrustedIdentifier.isValid) ?? true,
              assignedMemberID.map(TrustedIdentifier.isValid) ?? true,
              cursor.map({ TrustedIdentifier.isValid($0.token) && $0.sort == request.sort }) ?? true else {
            throw StudentRepositoryError.invalidRequest
        }
        if request.sort == .recentlyUpdated,
           case .normalizedNamePrefix = search {
            throw StudentRepositoryError.invalidRequest
        }
        return NormalizedStudentPageRequest(
            search: search,
            schoolID: schoolID,
            grade: Self.normalizedText(request.grade),
            assignedMemberID: assignedMemberID,
            status: request.status,
            sort: request.sort,
            cursor: cursor,
            limit: min(request.limit, StudentPageRequest.maximumPageSize)
        )
    }

    private func readScope(
        for request: NormalizedStudentPageRequest,
        member: MembershipContext
    ) throws -> StudentStoreQueryScope {
        switch member.role {
        case .teacher, .counselor, .socialWorker:
            guard request.assignedMemberID == nil || request.assignedMemberID == member.userID else {
                throw StudentRepositoryError.permissionDenied
            }
            let schoolID: String
            if let requestedSchoolID = request.schoolID {
                schoolID = requestedSchoolID
            } else if member.schoolIDs.count == 1, let onlySchoolID = member.schoolIDs.first {
                schoolID = onlySchoolID
            } else {
                throw StudentRepositoryError.schoolFilterRequired
            }
            guard member.schoolIDs.contains(schoolID) else {
                throw StudentRepositoryError.permissionDenied
            }
            return .assigned(memberID: member.userID, schoolID: schoolID)
        case .schoolAdministrator:
            guard member.capabilities.contains(.studentReadDetail) else {
                throw StudentRepositoryError.permissionDenied
            }
            let schoolID: String
            if let requestedSchoolID = request.schoolID {
                schoolID = requestedSchoolID
            } else if member.schoolIDs.count == 1, let onlySchoolID = member.schoolIDs.first {
                schoolID = onlySchoolID
            } else {
                throw StudentRepositoryError.schoolFilterRequired
            }
            guard member.schoolIDs.contains(schoolID) else {
                throw StudentRepositoryError.permissionDenied
            }
            return .school(schoolID: schoolID)
        case .districtAdministrator:
            guard member.capabilities.contains(.studentReadDetail) else {
                throw StudentRepositoryError.permissionDenied
            }
            return .district
        }
    }

    private func cacheKey(
        for request: NormalizedStudentPageRequest,
        member: MembershipContext
    ) -> StudentPageCacheKey {
        StudentPageCacheKey(
            districtID: member.districtID,
            userID: member.userID,
            membershipVersion: member.version,
            search: request.search,
            schoolID: request.schoolID,
            grade: request.grade,
            assignedMemberID: request.assignedMemberID,
            status: request.status,
            sort: request.sort,
            cursor: request.cursor,
            limit: request.limit
        )
    }

    private func authoritativeStudent(
        id: String,
        member: MembershipContext
    ) async throws -> StudentRecord {
        guard TrustedIdentifier.isValid(id) else {
            throw StudentRepositoryError.invalidRequest
        }
        let snapshot: FirebaseStudentSnapshot
        do {
            guard let stored = try await store.student(for: StudentStoreRecordRequest(
                districtID: member.districtID,
                studentID: id,
                source: .server
            )) else {
                throw StudentRepositoryError.notFound
            }
            snapshot = stored
        } catch let error as StudentRepositoryError {
            throw error
        } catch StudentRecordStoreError.transportUnavailable {
            throw StudentRepositoryError.unavailable
        } catch StudentRecordStoreError.permissionDenied {
            throw StudentRepositoryError.permissionDenied
        } catch {
            throw StudentRepositoryError.invalidResponse
        }

        let record = try snapshot.record()
        guard AuthorizationPolicy.canReadStudentDetail(
            member,
            student: authorizationScope(for: record)
        ) else {
            throw StudentRepositoryError.permissionDenied
        }
        return record
    }

    private func decodedAuthorizedRecords(
        _ documents: [FirebaseStudentSnapshot],
        member: MembershipContext,
        request: StudentStorePageRequest
    ) throws -> [StudentRecord] {
        try documents.map { snapshot in
            let record = try snapshot.record()
            guard AuthorizationPolicy.canReadStudentDetail(
                member,
                student: authorizationScope(for: record)
            ) else {
                throw StudentRepositoryError.permissionDenied
            }
            guard Self.matchesServerPredicates(record, request: request) else {
                throw StudentRepositoryError.invalidResponse
            }
            return record
        }
    }

    private static func matchesServerPredicates(
        _ record: StudentRecord,
        request: StudentStorePageRequest
    ) -> Bool {
        switch request.scope {
        case .assigned(let memberID, let schoolID):
            guard record.schoolID == schoolID,
                  record.assignedMemberIDs.contains(memberID) else { return false }
        case .school(let schoolID):
            guard record.schoolID == schoolID else { return false }
        case .district:
            break
        }
        if let schoolID = request.schoolID, record.schoolID != schoolID { return false }
        if let grade = request.grade, normalizedText(record.grade) != grade { return false }
        if let memberID = request.assignedMemberID,
           !record.assignedMemberIDs.contains(memberID) { return false }
        switch request.status {
        case .active where record.isArchived:
            return false
        case .archived where !record.isArchived:
            return false
        default:
            break
        }
        switch request.search {
        case .normalizedNamePrefix(let prefix):
            return normalizedSearchText(record.displayName)?.hasPrefix(prefix) == true
        case .normalizedStudentIdentifier(let identifier):
            return normalizedSearchText(record.studentIdentifier) == identifier
        case nil:
            return true
        }
    }

    private func validated(
        _ draft: StudentDraft,
        member: MembershipContext
    ) throws -> StudentDraft {
        let normalizedDraft = draft.normalized
        guard StudentValidation.issues(
            for: normalizedDraft,
            districtID: member.districtID,
            policy: .standard
        ).isEmpty else {
            throw StudentRepositoryError.invalidDraft
        }
        return normalizedDraft
    }

    private func mutationBase(
        member: MembershipContext,
        expectedVersion: Int,
        operationID: UUID,
        reasonCode: StudentMutationReasonCode
    ) -> StudentMutationBase {
        StudentMutationBase(
            districtID: member.districtID,
            expectedRecordVersion: expectedVersion,
            idempotencyKey: operationID.uuidString.lowercased(),
            reasonCode: reasonCode
        )
    }

    private func authorizationScope(for record: StudentRecord) -> StudentAuthorizationScope {
        StudentAuthorizationScope(
            studentID: record.id,
            districtID: record.districtID,
            schoolID: record.schoolID
        )
    }

    private func mapMutationError(_ error: any Error) -> StudentRepositoryError {
        guard let error = error as? StudentMutationBackendError else {
            return .invalidResponse
        }
        switch error {
        case .transportUnavailable:
            return .unavailable
        case .permissionDenied:
            return .permissionDenied
        case .duplicate(let candidateIDs):
            return .duplicate(candidateIDs: candidateIDs.sorted())
        case .versionConflict(let expected, let actual):
            return .versionConflict(expected: expected, actual: actual)
        case .idempotencyKeyReused:
            return .idempotencyKeyReused
        case .invalidResponse:
            return .invalidResponse
        }
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedSearchPredicate(_ value: String?) -> StudentSearchPredicate? {
        guard let normalized = normalizedSearchText(value) else { return nil }
        let isIdentifierLike = !normalized.contains(where: { $0.isWhitespace })
            && normalized.contains(where: { $0.isNumber || "-_/".contains($0) })
        return isIdentifierLike
            ? .normalizedStudentIdentifier(normalized)
            : .normalizedNamePrefix(normalized)
    }

    private static func normalizedSearchText(_ value: String?) -> String? {
        guard let normalized = normalizedText(value) else { return nil }
        return normalized
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

extension CanonicalStudentRepository {
    /// Production composition point. Tests use the injectable designated
    /// initializer above and never require Firebase configuration.
    @MainActor
    static func firebase(
        firestore: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions(region: "us-central1"),
        auth: Auth = Auth.auth(),
        sessionStore: TrustedAuthorizationSessionStore = .shared
    ) -> CanonicalStudentRepository {
        CanonicalStudentRepository(
            store: FirebaseStudentRecordStore(firestore: firestore),
            mutationBackend: FirebaseStudentTrustedMutationBackend(functions: functions),
            cache: SecureStudentPageCache(),
            outbox: SecureStudentCreateOutbox(),
            authorityRefresher: FirebaseStudentMutationAuthorityRefresher(
                auth: auth,
                sessionStore: sessionStore
            )
        )
    }
}
