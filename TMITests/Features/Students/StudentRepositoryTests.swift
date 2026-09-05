import Foundation
@preconcurrency import FirebaseFunctions
import Synchronization
import Testing
@testable import TMI

@Suite("Assigned-scope student repository")
struct StudentRepositoryTests {
    @Test("Roster sort is Codable and defaults to alphabetical")
    func rosterSortContractDefaultsToAlphabetical() throws {
        #expect(StudentPageRequest.first.sort == .alphabetical)

        let encoded = try JSONEncoder().encode(StudentRosterSort.recentlyUpdated)
        let decoded = try JSONDecoder().decode(StudentRosterSort.self, from: encoded)

        #expect(decoded == .recentlyUpdated)
    }

    @Test("First and next pages normalize filters and never request more than 50 records")
    func pagesAreCappedAndNormalized() async throws {
        let store = StudentRecordStoreSpy(
            pageResults: [
                .success(StudentStorePage(documents: [], nextCursor: StudentPageCursor(token: "next"))),
                .success(StudentStorePage(documents: [], nextCursor: nil)),
            ]
        )
        let repository = makeRepository(store: store)
        let member = membership()

        _ = try await repository.page(
            StudentPageRequest(
                search: "  JOSÉ   Stone  ",
                schoolID: " school-a ",
                grade: " 7 ",
                assignedMemberID: " teacher-a ",
                status: .active,
                cursor: nil,
                limit: 500
            ),
            member: member
        )
        _ = try await repository.page(
            StudentPageRequest(
                status: .all,
                cursor: StudentPageCursor(token: "next"),
                limit: 75
            ),
            member: member
        )

        let requests = await store.pageRequests
        #expect(requests.count == 2)
        #expect(requests[0].districtID == "district-a")
        #expect(requests[0].scope == .school(schoolID: "school-a"))
        #expect(requests[0].search == .normalizedNamePrefix("jose stone"))
        #expect(requests[0].schoolID == "school-a")
        #expect(requests[0].grade == "7")
        #expect(requests[0].assignedMemberID == "teacher-a")
        #expect(requests[0].limit == 50)
        #expect(requests[1].cursor == StudentPageCursor(token: "next"))
        #expect(requests[1].limit == 50)
    }

    @Test("Repository forwards roster sort and binds it to the cache key")
    func repositoryForwardsAndCachesRosterSort() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            pageResults: [.success(StudentStorePage(documents: [], nextCursor: nil))]
        )
        let repository = makeRepository(store: store, cache: cache)

        _ = try await repository.page(
            StudentPageRequest(sort: .recentlyUpdated),
            member: membership()
        )

        #expect(store.pageRequests.first?.sort == .recentlyUpdated)
        #expect(cache.savedKeys.first?.sort == .recentlyUpdated)
    }

    @Test("Name prefix and exact identifier search are sent to the server with admin member filters")
    func searchAndMemberFiltersAreServerPredicates() async throws {
        let store = StudentRecordStoreSpy(
            pageResults: [
                .success(StudentStorePage(
                    documents: [snapshot(id: "name", displayName: "José Stone")],
                    nextCursor: nil
                )),
                .success(StudentStorePage(
                    documents: [snapshot(id: "identifier", studentIdentifier: "0012")],
                    nextCursor: nil
                )),
            ]
        )
        let repository = makeRepository(store: store)
        let administrator = membership(
            role: .districtAdministrator,
            capabilities: [.studentReadDetail],
            assignedStudentIDs: []
        )

        let namePage = try await repository.page(
            StudentPageRequest(
                search: "  JOSÉ   St ",
                schoolID: "school-a",
                grade: "7",
                assignedMemberID: "teacher-b",
                status: .active
            ),
            member: administrator
        )
        let identifierPage = try await repository.page(
            StudentPageRequest(
                search: " 0012 ",
                schoolID: "school-a",
                assignedMemberID: "teacher-b",
                status: .active
            ),
            member: administrator
        )

        #expect(namePage.records.map(\.id) == ["name"])
        #expect(identifierPage.records.map(\.id) == ["identifier"])
        let requests = store.pageRequests
        #expect(requests[0].search == .normalizedNamePrefix("jose st"))
        #expect(requests[0].assignedMemberID == "teacher-b")
        #expect(requests[1].search == .normalizedStudentIdentifier("0012"))
        #expect(requests[1].assignedMemberID == "teacher-b")
    }

    @Test("Teacher roster reads are school scoped and may filter by assignment")
    func teacherReadScopeIsSchoolBound() async throws {
        let store = StudentRecordStoreSpy(
            pageResults: [.success(StudentStorePage(documents: [], nextCursor: nil))]
        )
        let repository = makeRepository(store: store)

        _ = try await repository.page(
            StudentPageRequest(schoolID: "school-b", assignedMemberID: "teacher-b"),
            member: membership(schoolIDs: ["school-a", "school-b"])
        )
        #expect(store.pageRequests.first?.scope == .school(schoolID: "school-b"))
        #expect(store.pageRequests.first?.assignedMemberID == "teacher-b")

        await expectRepositoryError(.schoolFilterRequired) {
            _ = try await repository.page(
                .first,
                member: membership(schoolIDs: ["school-a", "school-b"])
            )
        }
        await expectRepositoryError(.permissionDenied) {
            _ = try await repository.page(
                StudentPageRequest(schoolID: "school-c"),
                member: membership(schoolIDs: ["school-a", "school-b"])
            )
        }
    }

    @Test("Firestore query plans bind predicates, ordering, limit, and cursor fingerprint")
    func firestoreQueryPlanBindsCursorToSearch() throws {
        let request = StudentStorePageRequest(
            districtID: "district-a",
            scope: .assigned(memberID: "teacher-a", schoolID: "school-a"),
            search: .normalizedNamePrefix("ava"),
            schoolID: "school-a",
            grade: "7",
            assignedMemberID: "teacher-a",
            status: .active,
            cursor: nil,
            limit: 50,
            source: .server
        )
        let first = try StudentFirestoreQueryPlan(request: request)

        #expect(first.schoolID == "school-a")
        #expect(first.assignedMemberID == "teacher-a")
        #expect(first.search == .normalizedNamePrefix("ava"))
        #expect(first.order == [.normalizedDisplayName, .documentID])
        #expect(first.limit == 50)

        let cursor = try first.nextCursor(
            documentID: "student-z",
            normalizedDisplayName: "ava stone"
        )
        let next = try StudentFirestoreQueryPlan(request: StudentStorePageRequest(
            districtID: request.districtID,
            scope: request.scope,
            search: request.search,
            schoolID: request.schoolID,
            grade: request.grade,
            assignedMemberID: request.assignedMemberID,
            status: request.status,
            cursor: cursor,
            limit: request.limit,
            source: request.source
        ))
        #expect(next.startAfter == [
            .string("ava stone"),
            .string("student-z"),
        ])

        let mismatched = StudentPageCursor(
            token: "student-z",
            sortValue: "ava stone",
            queryFingerprint: "another-query"
        )
        #expect(throws: StudentRepositoryError.invalidRequest) {
            _ = try StudentFirestoreQueryPlan(request: StudentStorePageRequest(
                districtID: request.districtID,
                scope: request.scope,
                search: request.search,
                schoolID: request.schoolID,
                grade: request.grade,
                assignedMemberID: request.assignedMemberID,
                status: request.status,
                cursor: mismatched,
                limit: request.limit,
                source: request.source
            ))
        }
    }

    @Test("Recent query plans use updated time and bind sort to their cursor")
    func recentQueryPlanBindsSortAndTimestampCursor() throws {
        let timestamp = Date(timeIntervalSince1970: 1_234)
        let request = StudentStorePageRequest(
            districtID: "district-a",
            scope: .district,
            search: .normalizedStudentIdentifier("0012"),
            schoolID: nil,
            grade: nil,
            assignedMemberID: nil,
            status: .all,
            sort: .recentlyUpdated,
            cursor: nil,
            limit: 25,
            source: .server
        )
        let first = try StudentFirestoreQueryPlan(request: request)

        #expect(first.sort == .recentlyUpdated)
        #expect(first.order == [.updatedAtDescending, .documentID])

        let cursor = try first.nextCursor(
            documentID: "student-z",
            normalizedDisplayName: nil,
            updatedAt: timestamp
        )
        #expect(cursor.sort == .recentlyUpdated)
        #expect(cursor.updatedAt == timestamp)

        let next = try StudentFirestoreQueryPlan(request: StudentStorePageRequest(
            districtID: request.districtID,
            scope: request.scope,
            search: request.search,
            schoolID: request.schoolID,
            grade: request.grade,
            assignedMemberID: request.assignedMemberID,
            status: request.status,
            sort: request.sort,
            cursor: cursor,
            limit: request.limit,
            source: request.source
        ))
        #expect(next.startAfter == [
            .timestamp(timestamp),
            .string("student-z"),
        ])

        let alphabeticalPlan = try StudentFirestoreQueryPlan(request: StudentStorePageRequest(
            districtID: request.districtID,
            scope: request.scope,
            search: request.search,
            schoolID: request.schoolID,
            grade: request.grade,
            assignedMemberID: request.assignedMemberID,
            status: request.status,
            sort: .alphabetical,
            cursor: nil,
            limit: request.limit,
            source: request.source
        ))
        #expect(alphabeticalPlan.fingerprint != first.fingerprint)
    }

    @Test("Name prefix with recent sort fails before store access while exact ID honors it")
    func recentSortRejectsNamePrefixButAllowsExactIdentifier() async throws {
        let store = StudentRecordStoreSpy(
            pageResults: [.success(StudentStorePage(
                documents: [snapshot(id: "student-a")],
                nextCursor: nil
            ))]
        )
        let repository = makeRepository(store: store)

        await expectRepositoryError(.invalidRequest) {
            _ = try await repository.page(
                StudentPageRequest(search: "Ava", sort: .recentlyUpdated),
                member: membership()
            )
        }
        #expect(store.pageRequests.isEmpty)

        _ = try await repository.page(
            StudentPageRequest(search: "0012", sort: .recentlyUpdated),
            member: membership()
        )
        #expect(store.pageRequests.first?.search == .normalizedStudentIdentifier("0012"))
        #expect(store.pageRequests.first?.sort == .recentlyUpdated)
    }

    @Test("A response containing any cross-tenant or out-of-school record fails closed")
    func unauthorizedResponseFailsClosed() async throws {
        for unauthorized in [
            snapshot(id: "student-a", districtID: "district-b"),
            snapshot(id: "student-c", schoolID: "school-b", assignedMemberIDs: ["teacher-b"]),
        ] {
            let cache = StudentPageCacheSpy()
            let store = StudentRecordStoreSpy(
                pageResults: [
                    .success(StudentStorePage(
                        documents: [snapshot(id: "student-a"), unauthorized],
                        nextCursor: nil
                    )),
                ]
            )
            let repository = makeRepository(store: store, cache: cache)

            await expectRepositoryError(.permissionDenied) {
                _ = try await repository.page(.first, member: membership())
            }
            #expect(cache.savedKeys.isEmpty)
        }
    }

    @Test("A limited server page that violates its search predicate fails instead of post-filtering")
    func serverPredicateMismatchFailsClosed() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(pageResults: [.success(StudentStorePage(
            documents: [snapshot(id: "student-a", displayName: "Different Name")],
            nextCursor: nil
        ))])
        let repository = makeRepository(store: store, cache: cache)

        await expectRepositoryError(.invalidResponse) {
            _ = try await repository.page(
                StudentPageRequest(search: "Ava"),
                member: membership()
            )
        }

        #expect(cache.savedKeys.isEmpty)
    }

    @Test("Teacher student reads are server-first and school scoped")
    func studentReadIsServerFirstAndSchoolScoped() async throws {
        let store = StudentRecordStoreSpy(
            studentResults: [
                .success(snapshot(id: "student-a")),
                .success(snapshot(id: "student-c", assignedMemberIDs: ["teacher-b"])),
                .success(snapshot(id: "student-d", schoolID: "school-b", assignedMemberIDs: ["teacher-a"])),
            ]
        )
        let repository = makeRepository(store: store)

        let record = try await repository.student(id: "student-a", member: membership())
        #expect(record.id == "student-a")
        #expect((await store.studentRequests).first?.source == .server)

        let unassigned = try await repository.student(id: "student-c", member: membership())
        #expect(unassigned.id == "student-c")

        await expectRepositoryError(.permissionDenied) {
            _ = try await repository.student(id: "student-d", member: membership())
        }
    }

    @Test("A page uses cache only for transport unavailability and reports the cache source")
    func cacheFallbackIsTransportOnly() async throws {
        let cache = StudentPageCacheSpy()
        let request = StudentPageRequest(search: " Ava ", status: .active)
        let member = membership(version: 4)
        let primingStore = StudentRecordStoreSpy(
            pageResults: [
                .success(StudentStorePage(documents: [snapshot(id: "student-a")], nextCursor: nil)),
            ]
        )
        let primingRepository = makeRepository(store: primingStore, cache: cache)
        _ = try await primingRepository.page(request, member: member)

        let offlineStore = StudentRecordStoreSpy(pageResults: [.failure(.transportUnavailable)])
        let offlineRepository = makeRepository(store: offlineStore, cache: cache)
        let cached = try await offlineRepository.page(request, member: member)

        #expect(cached.source == .cache)
        #expect(cached.records.map(\.id) == ["student-a"])

        let deniedStore = StudentRecordStoreSpy(pageResults: [.failure(.permissionDenied)])
        let deniedRepository = makeRepository(store: deniedStore, cache: cache)
        await expectRepositoryError(.permissionDenied) {
            _ = try await deniedRepository.page(request, member: member)
        }
    }

    @Test("A server permission denial evicts cached pages for that authority")
    func permissionDeniedPageEvictsAuthorityCache() async throws {
        let cache = StudentPageCacheSpy()
        let request = StudentPageRequest(search: "Ava")
        let member = membership()
        let primingRepository = makeRepository(
            store: StudentRecordStoreSpy(pageResults: [.success(StudentStorePage(
                documents: [snapshot(id: "student-a")],
                nextCursor: nil
            ))]),
            cache: cache
        )
        _ = try await primingRepository.page(request, member: member)

        let deniedRepository = makeRepository(
            store: StudentRecordStoreSpy(pageResults: [.failure(.permissionDenied)]),
            cache: cache
        )
        await expectRepositoryError(.permissionDenied) {
            _ = try await deniedRepository.page(request, member: member)
        }

        let offlineRepository = makeRepository(
            store: StudentRecordStoreSpy(pageResults: [.failure(.transportUnavailable)]),
            cache: cache
        )
        await expectRepositoryError(.unavailable) {
            _ = try await offlineRepository.page(request, member: member)
        }
        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("The encrypted page cache survives repository reconstruction")
    func secureCachePersistsAcrossInstances() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        let storageKey = "student-pages"
        defer { try? keychain.deleteAll() }

        let key = StudentPageCacheKey(
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 3,
            search: nil,
            schoolID: "school-a",
            grade: nil,
            assignedMemberID: nil,
            status: .active,
            sort: .alphabetical,
            cursor: nil,
            limit: 50
        )
        let expected = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )

        let writer = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        await writer.save(expected, for: key)

        let reader = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        #expect(await reader.page(for: key) == expected)
    }

    @Test("Encrypted cache invalidation denies stale pages after archive deletion fails")
    func secureCacheInvalidationFailsClosedAcrossReconstruction() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        let storageKey = "student-pages"
        defer { try? keychain.deleteAll() }

        let key = StudentPageCacheKey.fixture(userID: "teacher-a")
        let page = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )
        let writer = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        await writer.save(page, for: key)

        let failingStorage = StudentPageCacheDeletionFailurePersistence(
            storage: storage,
            failingKey: storageKey
        )
        let invalidator = SecureStudentPageCache(
            storage: failingStorage,
            storageKey: storageKey
        )
        await invalidator.invalidate(
            authority: StudentCacheAuthority(
                districtID: key.districtID,
                userID: key.userID
            )
        )

        let reconstructed = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        #expect(await reconstructed.page(for: key) == nil)
    }

    @Test("Encrypted cache invalidation denies stale pages after archive rewrite fails")
    func secureCacheRewriteFailureFailsClosedAcrossReconstruction() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        let storageKey = "student-pages"
        defer { try? keychain.deleteAll() }

        let deniedKey = StudentPageCacheKey.fixture(userID: "teacher-a")
        let retainedKey = StudentPageCacheKey.fixture(userID: "teacher-b")
        let page = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )
        let writer = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        await writer.save(page, for: deniedKey)
        await writer.save(page, for: retainedKey)

        let invalidator = SecureStudentPageCache(
            storage: StudentPageCacheRewriteFailurePersistence(
                storage: storage,
                failingKey: storageKey
            ),
            storageKey: storageKey
        )
        await invalidator.invalidate(
            authority: StudentCacheAuthority(
                districtID: deniedKey.districtID,
                userID: deniedKey.userID
            )
        )

        let reconstructed = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        #expect(await reconstructed.page(for: deniedKey) == nil)
        #expect(await reconstructed.page(for: retainedKey) == page)
    }

    @Test("Encrypted cache clears stale pages when tombstone writing and archive deletion fail")
    func secureCacheTombstoneWriteFailureFallsBackToEmptyArchive() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        let storageKey = "student-pages"
        defer { try? keychain.deleteAll() }

        let key = StudentPageCacheKey.fixture(userID: "teacher-a")
        let page = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )
        let writer = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        await writer.save(page, for: key)

        let invalidator = SecureStudentPageCache(
            storage: StudentPageCacheTombstoneWriteFailurePersistence(
                storage: storage,
                archiveKey: storageKey
            ),
            storageKey: storageKey
        )
        await invalidator.invalidate(
            authority: StudentCacheAuthority(
                districtID: key.districtID,
                userID: key.userID
            )
        )

        let reconstructed = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        #expect(await reconstructed.page(for: key) == nil)
    }

    @Test("Encrypted cache denies pages when an authority tombstone cannot be read")
    func secureCacheTombstoneReadFailureFailsClosed() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        let storageKey = "student-pages"
        defer { try? keychain.deleteAll() }

        let key = StudentPageCacheKey.fixture(userID: "teacher-a")
        let page = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )
        let writer = SecureStudentPageCache(
            storage: storage,
            storageKey: storageKey
        )
        await writer.save(page, for: key)

        let failingReader = SecureStudentPageCache(
            storage: StudentPageCacheTombstoneReadFailurePersistence(
                storage: storage,
                archiveKey: storageKey
            ),
            storageKey: storageKey
        )

        #expect(await failingReader.page(for: key) == nil)
    }

    @Test("Encrypted page-cache invalidation is scoped to one authority")
    func secureCacheInvalidationPreservesOtherAuthorities() async throws {
        let service = "com.tmi.tests.student-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "student-cache-key"
        )
        defer { try? keychain.deleteAll() }

        let cache = SecureStudentPageCache(
            storage: storage,
            storageKey: "student-pages"
        )
        let first = StudentPageCacheKey.fixture(userID: "teacher-a")
        let second = StudentPageCacheKey.fixture(userID: "teacher-b")
        let page = StudentStorePage(
            documents: [snapshot(id: "student-a")],
            nextCursor: nil
        )
        await cache.save(page, for: first)
        await cache.save(page, for: second)

        await cache.invalidate(
            authority: StudentCacheAuthority(
                districtID: first.districtID,
                userID: first.userID
            )
        )

        #expect(await cache.page(for: first) == nil)
        #expect(await cache.page(for: second) == page)
    }

    @Test("Cache keys bind tenant, user, membership version, filters, and cursor")
    func cacheKeyBindsAuthorityAndRequest() async throws {
        let cache = StudentPageCacheSpy()
        let request = StudentPageRequest(
            search: "Ava",
            schoolID: "school-a",
            grade: "7",
            assignedMemberID: "teacher-a",
            status: .all,
            cursor: StudentPageCursor(token: "cursor-a"),
            limit: 25
        )
        let store = StudentRecordStoreSpy(
            pageResults: [.success(StudentStorePage(documents: [], nextCursor: nil))]
        )
        let repository = makeRepository(store: store, cache: cache)

        _ = try await repository.page(request, member: membership(version: 8))

        let keys = await cache.savedKeys
        #expect(keys.count == 1)
        #expect(keys[0].districtID == "district-a")
        #expect(keys[0].userID == "teacher-a")
        #expect(keys[0].membershipVersion == 8)
        #expect(keys[0].search == .normalizedNamePrefix("ava"))
        #expect(keys[0].schoolID == "school-a")
        #expect(keys[0].grade == "7")
        #expect(keys[0].assignedMemberID == "teacher-a")
        #expect(keys[0].status == .all)
        #expect(keys[0].cursor == StudentPageCursor(token: "cursor-a"))
        #expect(keys[0].limit == 25)
    }

    @Test("Membership revocation and stale versions invalidate authority and fail closed")
    func membershipRevocationAndVersionChangesFailClosed() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            pageResults: [
                .success(StudentStorePage(documents: [snapshot(id: "student-a")], nextCursor: nil)),
                .success(StudentStorePage(documents: [snapshot(id: "student-a")], nextCursor: nil)),
            ]
        )
        let repository = makeRepository(store: store, cache: cache)

        _ = try await repository.page(.first, member: membership(version: 1))
        _ = try await repository.page(.first, member: membership(version: 2))
        #expect(await cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: "district-a", userID: "teacher-a"),
        ])

        await expectRepositoryError(.staleMembership) {
            _ = try await repository.page(.first, member: membership(version: 1))
        }
        await expectRepositoryError(.permissionDenied) {
            _ = try await repository.page(.first, member: membership(isActive: false, version: 3))
        }
    }

    @Test("Create sends a normalized idempotent callable payload and returns an authoritative server record")
    func createUsesTrustedCallable() async throws {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-new", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    role: .districtAdministrator,
                    capabilities: [.studentReadDetail, .studentWriteDetail],
                    assignedStudentIDs: [],
                    version: 2
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend)
        let draft = studentDraft(displayName: "  Ava   Stone ", studentIdentifier: " 0012 ")

        let created = try await repository.create(
            draft,
            operationID: operationID,
            member: membership(
                role: .districtAdministrator,
                capabilities: [.studentReadDetail, .studentWriteDetail],
                assignedStudentIDs: []
            )
        )

        #expect(created.id == "student-new")
        let requests = await backend.createRequests
        #expect(requests.count == 1)
        #expect(requests[0].base.districtID == "district-a")
        #expect(requests[0].base.expectedRecordVersion == 0)
        #expect(requests[0].base.idempotencyKey == operationID.uuidString.lowercased())
        #expect(requests[0].base.reasonCode == .staffRosterCreate)
        #expect(requests[0].displayName == "Ava Stone")
        #expect(requests[0].studentIdentifier == "0012")
        #expect((await store.studentRequests).last?.source == .server)
    }

    @Test("Create refreshes caller authority before reading a newly assigned student")
    func createRefreshesAuthorityBeforeRead() async throws {
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-new", recordVersion: 1))]
        )
        let refreshedMembership = mutationMembership(
            assignedStudentIDs: ["student-a", "student-b", "student-new"],
            version: 2
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: refreshedMembership
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy()
        let repository = makeRepository(
            store: store,
            backend: backend,
            authorityRefresher: authorityRefresher
        )

        let created = try await repository.create(
            studentDraft(),
            operationID: UUID(),
            member: membership(version: 1)
        )

        #expect(created.id == "student-new")
        let requests = authorityRefresher.requests
        #expect(requests.count == 1)
        #expect(requests[0].previous.version == 1)
        #expect(requests[0].membership == refreshedMembership)
    }

    @Test("A confirmed create evicts cached pages even when membership version is unchanged")
    func confirmedCreateEvictsAuthorityCache() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-new", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    assignedStudentIDs: ["student-a", "student-b", "student-new"],
                    version: 1
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend, cache: cache)
        let member = membership(version: 1)

        _ = try await repository.create(
            studentDraft(),
            operationID: UUID(),
            member: member
        )

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("A successful create response evicts cached pages before authority refresh fails")
    func successfulCreateResponseEvictsCacheBeforeRefreshFailure() async throws {
        let cache = StudentPageCacheSpy()
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(version: 2)
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy(error: .unavailable)
        let repository = makeRepository(
            backend: backend,
            cache: cache,
            authorityRefresher: authorityRefresher
        )
        let member = membership(version: 1)

        await expectRepositoryError(.unavailable) {
            _ = try await repository.create(
                studentDraft(),
                operationID: UUID(),
                member: member
            )
        }

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("Create exposes duplicate candidates as a typed repository error")
    func createDuplicateResultIsTyped() async throws {
        let backend = StudentMutationBackendSpy(
            createResults: [.failure(.duplicate(candidateIDs: ["student-b", "student-a"]))]
        )
        let repository = makeRepository(backend: backend)

        await expectRepositoryError(.duplicate(candidateIDs: ["student-a", "student-b"])) {
            _ = try await repository.create(
                studentDraft(),
                operationID: UUID(),
                member: membership(
                    role: .districtAdministrator,
                    capabilities: [.studentReadDetail, .studentWriteDetail],
                    assignedStudentIDs: []
                )
            )
        }
    }

    @Test("Offline create is queued with operation and membership authority then explicitly reported")
    func offlineCreateIsQueued() async throws {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        let backend = StudentMutationBackendSpy(createResults: [.failure(.transportUnavailable)])
        let outbox = StudentCreateOutboxSpy()
        let repository = makeRepository(backend: backend, outbox: outbox)
        let member = membership(version: 9)

        await expectRepositoryError(.createQueued(operationID: operationID)) {
            _ = try await repository.create(
                studentDraft(),
                operationID: operationID,
                member: member
            )
        }

        let queued = await outbox.items
        #expect(queued.count == 1)
        #expect(queued[0].operationID == operationID)
        #expect(queued[0].districtID == member.districtID)
        #expect(queued[0].userID == member.userID)
        #expect(queued[0].membershipVersion == member.version)
        #expect(queued[0].draft == studentDraft().normalized)
    }

    @Test("Student drafts and pending creates survive a Codable persistence round trip")
    func pendingCreateIsCodable() throws {
        let pending = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000555")!,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 7,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 123)
        )

        let encoded = try JSONEncoder().encode(pending)
        let decoded = try JSONDecoder().decode(PendingStudentCreate.self, from: encoded)

        #expect(decoded == pending)
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "disposition")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try JSONDecoder().decode(
            PendingStudentCreate.self,
            from: legacyData
        )
        #expect(legacyDecoded.disposition == .queued)
    }

    @Test("Secure outbox is durable and idempotent across outbox instances")
    func secureOutboxPersistsAcrossInstances() async throws {
        let storage = StudentCreateOutboxStorageSpy()
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000666")!
        let first = SecureStudentCreateOutbox(storage: storage)
        let original = PendingStudentCreate(
            operationID: operationID,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Original"),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )
        let replacement = PendingStudentCreate(
            operationID: operationID,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 2,
            draft: studentDraft(displayName: "Replacement"),
            enqueuedAt: Date(timeIntervalSince1970: 20)
        )

        try await first.enqueue(original)
        try await first.enqueue(replacement)

        let reopened = SecureStudentCreateOutbox(storage: storage)
        #expect(try await reopened.pending() == [replacement])
        try await reopened.remove(operationID: operationID)
        #expect(try await first.pending().isEmpty)
    }

    @Test("Outbox reconciliation confirms the server record before removal and is idempotent")
    func reconcilePendingCreateConfirmsThenRemoves() async throws {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!
        let outbox = StudentCreateOutboxSpy(items: [PendingStudentCreate(
            operationID: operationID,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )])
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-new", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    assignedStudentIDs: ["student-a", "student-b", "student-new"],
                    version: 2
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)

        let reconciled = try await repository.reconcilePendingCreates(member: membership(version: 1))
        let repeated = try await repository.reconcilePendingCreates(member: membership(
            assignedStudentIDs: ["student-a", "student-b", "student-new"],
            version: 2
        ))

        #expect(reconciled.map(\.id) == ["student-new"])
        #expect(repeated.isEmpty)
        #expect(await outbox.items.isEmpty)
        #expect(backend.createRequests.count == 1)
        #expect(store.studentRequests.count == 1)
    }

    @Test("A successful reconciled create evicts cached pages before authority refresh fails")
    func successfulReconciledCreateEvictsCacheBeforeRefreshFailure() async throws {
        let pending = PendingStudentCreate(
            operationID: UUID(),
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )
        let cache = StudentPageCacheSpy()
        let outbox = StudentCreateOutboxSpy(items: [pending])
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(version: 2)
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy(error: .unavailable)
        let repository = makeRepository(
            backend: backend,
            cache: cache,
            outbox: outbox,
            authorityRefresher: authorityRefresher
        )
        let member = membership(version: 1)

        await expectRepositoryError(.unavailable) {
            _ = try await repository.reconcilePendingCreates(member: member)
        }

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
        #expect(outbox.items == [pending])
    }

    @Test("Foreign outbox entries do not block the current authority and remain preserved")
    func reconcileSelectsCurrentAuthorityWithoutRemovingForeignItems() async throws {
        let foreign = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000801")!,
            districtID: "district-a",
            userID: "administrator-a",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Foreign Student"),
            enqueuedAt: Date(timeIntervalSince1970: 1)
        )
        let current = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000802")!,
            districtID: "district-a",
            userID: "administrator-b",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Current Student"),
            enqueuedAt: Date(timeIntervalSince1970: 2)
        )
        let outbox = StudentCreateOutboxSpy(items: [foreign, current])
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-current", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-current",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    role: .districtAdministrator,
                    capabilities: [.studentReadDetail, .studentWriteDetail],
                    assignedStudentIDs: [],
                    version: 2
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)
        let member = membership(
            userID: "administrator-b",
            role: .districtAdministrator,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            version: 1
        )

        let reconciled = try await repository.reconcilePendingCreates(member: member)

        #expect(reconciled.map(\.id) == ["student-current"])
        #expect(backend.createRequests.map(\.base.idempotencyKey) == [
            current.operationID.uuidString.lowercased(),
        ])
        #expect(await outbox.items == [foreign])
    }

    @Test("Outbox reconciliation rejects stale authority before writing and preserves the draft")
    func reconcilePendingCreateRejectsStaleAuthority() async throws {
        let pending = PendingStudentCreate(
            operationID: UUID(),
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )
        let outbox = StudentCreateOutboxSpy(items: [pending])
        let backend = StudentMutationBackendSpy()
        let repository = makeRepository(backend: backend, outbox: outbox)

        await expectRepositoryError(.staleMembership) {
            _ = try await repository.reconcilePendingCreates(member: membership(version: 2))
        }

        #expect(await outbox.items == [pending.quarantinedForReview()])
        #expect(backend.createRequests.isEmpty)
    }

    @Test("A durable stale head item is quarantined and cannot block a later valid item after reopen")
    func staleHeadItemIsDurablyQuarantined() async throws {
        let stale = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000811")!,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Stale Student"),
            enqueuedAt: Date(timeIntervalSince1970: 1)
        )
        let current = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000812")!,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 2,
            draft: studentDraft(displayName: "Current Student"),
            enqueuedAt: Date(timeIntervalSince1970: 2)
        )
        let outbox = StudentCreateOutboxSpy(items: [stale, current])
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-current", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-current",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    assignedStudentIDs: ["student-a", "student-b", "student-current"],
                    version: 3
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)

        await expectRepositoryError(.staleMembership) {
            _ = try await repository.reconcilePendingCreates(member: membership(version: 2))
        }
        await expectRepositoryError(.staleMembership) {
            _ = try await repository.reconcilePendingCreates(member: membership(
                assignedStudentIDs: ["student-a", "student-b", "student-current"],
                version: 3
            ))
        }

        #expect(await outbox.items == [stale.quarantinedForReview()])
        #expect(backend.createRequests.map(\.base.idempotencyKey) == [
            current.operationID.uuidString.lowercased(),
        ])
        #expect(store.studentRequests.count == 1)
    }

    @Test("A denied head item is durably quarantined and later queued work drains after reopen")
    func permissionDeniedHeadItemIsDurablyQuarantined() async throws {
        let denied = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000821")!,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Denied Student"),
            enqueuedAt: Date(timeIntervalSince1970: 1)
        )
        let allowed = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000822")!,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(displayName: "Allowed Student"),
            enqueuedAt: Date(timeIntervalSince1970: 2)
        )
        let outbox = StudentCreateOutboxSpy(items: [denied, allowed])
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-allowed", recordVersion: 1))]
        )
        let backend = StudentMutationBackendSpy(
            createResults: [
                .failure(.permissionDenied),
                .success(StudentMutationResult(
                    studentID: "student-allowed",
                    recordVersion: 1,
                    replayed: false,
                    membership: mutationMembership(
                        assignedStudentIDs: ["student-a", "student-b", "student-allowed"],
                        version: 2
                    )
                )),
            ]
        )
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)

        await expectRepositoryError(.staleMembership) {
            _ = try await repository.reconcilePendingCreates(member: membership(version: 1))
        }
        await expectRepositoryError(.staleMembership) {
            _ = try await repository.reconcilePendingCreates(member: membership(
                assignedStudentIDs: ["student-a", "student-b", "student-allowed"],
                version: 2
            ))
        }

        #expect(await outbox.items == [denied.quarantinedForReview()])
        #expect(backend.createRequests.map(\.base.idempotencyKey) == [
            denied.operationID.uuidString.lowercased(),
            allowed.operationID.uuidString.lowercased(),
        ])
        #expect(store.studentRequests.count == 1)
    }

    @Test("A recoverable reconciliation failure keeps the draft on refreshed authority")
    func reconcilePendingCreatePreservesRecoverableDraft() async throws {
        let operationID = UUID()
        let outbox = StudentCreateOutboxSpy(items: [PendingStudentCreate(
            operationID: operationID,
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )])
        let store = StudentRecordStoreSpy(studentResults: [.success(nil)])
        let backend = StudentMutationBackendSpy(
            createResults: [.success(StudentMutationResult(
                studentID: "student-new",
                recordVersion: 1,
                replayed: false,
                membership: mutationMembership(
                    assignedStudentIDs: ["student-a", "student-b", "student-new"],
                    version: 2
                )
            ))]
        )
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)

        await expectRepositoryError(.notFound) {
            _ = try await repository.reconcilePendingCreates(member: membership(version: 1))
        }

        let retained = await outbox.items
        #expect(retained.count == 1)
        #expect(retained[0].operationID == operationID)
        #expect(retained[0].membershipVersion == 2)
    }

    @Test("A reconciliation transport failure leaves the exact queued item intact")
    func reconcilePendingCreateTransportFailurePreservesDraft() async throws {
        let pending = PendingStudentCreate(
            operationID: UUID(),
            districtID: "district-a",
            userID: "teacher-a",
            membershipVersion: 1,
            draft: studentDraft(),
            enqueuedAt: Date(timeIntervalSince1970: 10)
        )
        let outbox = StudentCreateOutboxSpy(items: [pending])
        let backend = StudentMutationBackendSpy(createResults: [.failure(.transportUnavailable)])
        let repository = makeRepository(backend: backend, outbox: outbox)

        await expectRepositoryError(.unavailable) {
            _ = try await repository.reconcilePendingCreates(member: membership())
        }

        #expect(await outbox.items == [pending])
        #expect(backend.createRequests.count == 1)
    }

    @Test("Only a Functions unavailable error is queueable and server discriminators stay distinct")
    func callableErrorMappingIsFailClosedAndDiscriminated() {
        let unavailable = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.unavailable.rawValue
        )
        let cancelled = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.cancelled.rawValue
        )
        let duplicate = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.alreadyExists.rawValue,
            userInfo: [FunctionsErrorDetailsKey: [
                "kind": "student-duplicate",
                "candidateIDs": ["student-b", "student-a"],
            ]]
        )
        let conflict = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.aborted.rawValue,
            userInfo: [FunctionsErrorDetailsKey: [
                "kind": "record-version-conflict",
                "expectedRecordVersion": 3,
                "actualRecordVersion": 4,
            ]]
        )
        let reusedKey = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.alreadyExists.rawValue,
            userInfo: [FunctionsErrorDetailsKey: ["kind": "idempotency-key-reused"]]
        )
        let reusedKeyWithWrongCode = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [FunctionsErrorDetailsKey: ["kind": "idempotency-key-reused"]]
        )
        let alreadyExistsWithWrongKind = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.alreadyExists.rawValue,
            userInfo: [FunctionsErrorDetailsKey: ["kind": "record-version-conflict"]]
        )
        let malformedDuplicate = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.alreadyExists.rawValue,
            userInfo: [FunctionsErrorDetailsKey: ["candidateIDs": ["student-a"]]]
        )

        #expect(StudentMutationBackendErrorMapper.map(unavailable) == .transportUnavailable)
        #expect(StudentMutationBackendErrorMapper.map(cancelled) == .invalidResponse)
        #expect(StudentMutationBackendErrorMapper.map(NSError(domain: "other", code: -1)) == .invalidResponse)
        #expect(StudentMutationBackendErrorMapper.map(duplicate) == .duplicate(
            candidateIDs: ["student-a", "student-b"]
        ))
        #expect(StudentMutationBackendErrorMapper.map(conflict) == .versionConflict(expected: 3, actual: 4))
        #expect(StudentMutationBackendErrorMapper.map(reusedKey) == .idempotencyKeyReused)
        #expect(StudentMutationBackendErrorMapper.map(reusedKeyWithWrongCode) == .invalidResponse)
        #expect(StudentMutationBackendErrorMapper.map(alreadyExistsWithWrongKind) == .invalidResponse)
        #expect(StudentMutationBackendErrorMapper.map(malformedDuplicate) == .invalidResponse)
    }

    @Test("Update carries expected version and maps conflicts without a second write")
    func updateVersionConflictIsTyped() async throws {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
        let store = StudentRecordStoreSpy(studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))])
        let backend = StudentMutationBackendSpy(
            updateResults: [.failure(.versionConflict(expected: 3, actual: 4))]
        )
        let repository = makeRepository(store: store, backend: backend)

        await expectRepositoryError(.versionConflict(expected: 3, actual: 4)) {
            _ = try await repository.update(
                id: "student-a",
                draft: studentDraft(),
                expectedVersion: 3,
                operationID: operationID,
                member: membership()
            )
        }

        let requests = await backend.updateRequests
        #expect(requests.count == 1)
        #expect(requests[0].studentID == "student-a")
        #expect(requests[0].base.expectedRecordVersion == 3)
        #expect(requests[0].base.idempotencyKey == operationID.uuidString.lowercased())
    }

    @Test("A successful update re-reads the authoritative record from the server")
    func updateReturnsAuthoritativeRecord() async throws {
        let store = StudentRecordStoreSpy(
            studentResults: [
                .success(snapshot(id: "student-a", recordVersion: 3)),
                .success(snapshot(id: "student-a", displayName: "Ava Updated", recordVersion: 4)),
            ]
        )
        let backend = StudentMutationBackendSpy(
            updateResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership()
            ))]
        )
        let repository = makeRepository(store: store, backend: backend)

        let updated = try await repository.update(
            id: "student-a",
            draft: studentDraft(displayName: "Ava Updated"),
            expectedVersion: 3,
            operationID: UUID(),
            member: membership()
        )

        #expect(updated.displayName == "Ava Updated")
        #expect(updated.metadata.recordVersion == 4)
        #expect((await store.studentRequests).count == 2)
    }

    @Test("A confirmed update evicts cached pages even when membership version is unchanged")
    func confirmedUpdateEvictsAuthorityCache() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            studentResults: [
                .success(snapshot(id: "student-a", recordVersion: 3)),
                .success(snapshot(id: "student-a", displayName: "Ava Updated", recordVersion: 4)),
            ]
        )
        let backend = StudentMutationBackendSpy(
            updateResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership(version: 1)
            ))]
        )
        let repository = makeRepository(
            store: store,
            backend: backend,
            cache: cache
        )
        let member = membership(version: 1)

        _ = try await repository.update(
            id: "student-a",
            draft: studentDraft(displayName: "Ava Updated"),
            expectedVersion: 3,
            operationID: UUID(),
            member: member
        )

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("A successful update response evicts cached pages before authority refresh fails")
    func successfulUpdateResponseEvictsCacheBeforeRefreshFailure() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))]
        )
        let backend = StudentMutationBackendSpy(
            updateResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership(version: 2)
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy(error: .unavailable)
        let repository = makeRepository(
            store: store,
            backend: backend,
            cache: cache,
            authorityRefresher: authorityRefresher
        )
        let member = membership(version: 1)

        await expectRepositoryError(.unavailable) {
            _ = try await repository.update(
                id: "student-a",
                draft: studentDraft(displayName: "Ava Updated"),
                expectedVersion: 3,
                operationID: UUID(),
                member: member
            )
        }

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("Archive is online-required and transport failure is never queued")
    func archiveIsOnlineRequired() async throws {
        let store = StudentRecordStoreSpy(studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))])
        let backend = StudentMutationBackendSpy(archiveResults: [.failure(.transportUnavailable)])
        let outbox = StudentCreateOutboxSpy()
        let repository = makeRepository(store: store, backend: backend, outbox: outbox)

        await expectRepositoryError(.onlineRequired) {
            try await repository.archive(
                id: "student-a",
                expectedVersion: 3,
                operationID: UUID(),
                member: membership()
            )
        }

        #expect(await outbox.items.isEmpty)
    }

    @Test("Archive sends the trusted callable contract with an idempotency key")
    func archiveUsesTrustedCallable() async throws {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000444")!
        let store = StudentRecordStoreSpy(studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))])
        let backend = StudentMutationBackendSpy(
            archiveResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership()
            ))]
        )
        let repository = makeRepository(store: store, backend: backend)

        try await repository.archive(
            id: "student-a",
            expectedVersion: 3,
            operationID: operationID,
            member: membership()
        )

        let requests = await backend.archiveRequests
        #expect(requests.count == 1)
        #expect(requests[0].studentID == "student-a")
        #expect(requests[0].base.expectedRecordVersion == 3)
        #expect(requests[0].base.idempotencyKey == operationID.uuidString.lowercased())
        #expect(requests[0].base.reasonCode == .staffRosterArchive)
    }

    @Test("A confirmed archive evicts cached pages even when membership version is unchanged")
    func confirmedArchiveEvictsAuthorityCache() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))]
        )
        let backend = StudentMutationBackendSpy(
            archiveResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership(version: 1)
            ))]
        )
        let repository = makeRepository(
            store: store,
            backend: backend,
            cache: cache
        )
        let member = membership(version: 1)

        try await repository.archive(
            id: "student-a",
            expectedVersion: 3,
            operationID: UUID(),
            member: member
        )

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("A successful archive response evicts cached pages before authority refresh fails")
    func successfulArchiveResponseEvictsCacheBeforeRefreshFailure() async throws {
        let cache = StudentPageCacheSpy()
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))]
        )
        let backend = StudentMutationBackendSpy(
            archiveResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership(version: 2)
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy(error: .unavailable)
        let repository = makeRepository(
            store: store,
            backend: backend,
            cache: cache,
            authorityRefresher: authorityRefresher
        )
        let member = membership(version: 1)

        await expectRepositoryError(.unavailable) {
            try await repository.archive(
                id: "student-a",
                expectedVersion: 3,
                operationID: UUID(),
                member: member
            )
        }

        #expect(cache.invalidatedAuthorities == [
            StudentCacheAuthority(districtID: member.districtID, userID: member.userID),
        ])
    }

    @Test("Archive preserves an unavailable authority-refresh error")
    func archivePreservesAuthorityRefreshError() async throws {
        let store = StudentRecordStoreSpy(
            studentResults: [.success(snapshot(id: "student-a", recordVersion: 3))]
        )
        let backend = StudentMutationBackendSpy(
            archiveResults: [.success(StudentMutationResult(
                studentID: "student-a",
                recordVersion: 4,
                replayed: false,
                membership: mutationMembership(version: 2)
            ))]
        )
        let authorityRefresher = StudentMutationAuthorityRefresherSpy(error: .unavailable)
        let repository = makeRepository(
            store: store,
            backend: backend,
            authorityRefresher: authorityRefresher
        )

        await expectRepositoryError(.unavailable) {
            try await repository.archive(
                id: "student-a",
                expectedVersion: 3,
                operationID: UUID(),
                member: membership()
            )
        }
    }

    @Test("School administrators require an allowed school scope while district administrators use district scope")
    func administratorReadScopes() async throws {
        let store = StudentRecordStoreSpy(
            pageResults: [
                .success(StudentStorePage(documents: [], nextCursor: nil)),
                .success(StudentStorePage(documents: [], nextCursor: nil)),
            ]
        )
        let repository = makeRepository(store: store)

        _ = try await repository.page(
            StudentPageRequest(schoolID: "school-a"),
            member: membership(
                role: .schoolAdministrator,
                capabilities: [.studentReadDetail],
                assignedStudentIDs: []
            )
        )
        _ = try await repository.page(
            .first,
            member: membership(
                role: .districtAdministrator,
                capabilities: [.studentReadDetail],
                assignedStudentIDs: []
            )
        )

        let requests = await store.pageRequests
        #expect(requests[0].scope == .school(schoolID: "school-a"))
        #expect(requests[1].scope == .district)

        await expectRepositoryError(.schoolFilterRequired) {
            _ = try await repository.page(
                .first,
                member: membership(
                    schoolIDs: ["school-a", "school-b"],
                    role: .schoolAdministrator,
                    capabilities: [.studentReadDetail],
                    assignedStudentIDs: []
                )
            )
        }
    }

    @Test("Firebase DTO uses flat tenant fields and keeps document identity separate")
    func firebaseDTOSeparatesDocumentIdentity() throws {
        let document = snapshot(id: "document-id").document
        let data = try JSONEncoder().encode(document)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["districtId"] as? String == "district-a")
        #expect(object["schoolId"] as? String == "school-a")
        #expect(object["id"] == nil)

        let record = try FirebaseStudentSnapshot(documentID: "document-id", document: document).record()
        #expect(record.id == "document-id")
        #expect(record.districtID == "district-a")
        #expect(record.schoolID == "school-a")
    }

    private func makeRepository(
        store: StudentRecordStoreSpy = StudentRecordStoreSpy(),
        backend: StudentMutationBackendSpy = StudentMutationBackendSpy(),
        cache: StudentPageCacheSpy = StudentPageCacheSpy(),
        outbox: StudentCreateOutboxSpy = StudentCreateOutboxSpy(),
        authorityRefresher: StudentMutationAuthorityRefresherSpy = StudentMutationAuthorityRefresherSpy()
    ) -> CanonicalStudentRepository {
        CanonicalStudentRepository(
            store: store,
            mutationBackend: backend,
            cache: cache,
            outbox: outbox,
            authorityRefresher: authorityRefresher
        )
    }

    private func membership(
        userID: String = "teacher-a",
        districtID: String = "district-a",
        schoolIDs: Set<String> = ["school-a"],
        role: StaffRole = .teacher,
        capabilities: Set<Capability> = [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: Set<String> = ["student-a", "student-b"],
        isActive: Bool = true,
        version: Int = 1
    ) -> MembershipContext {
        MembershipContext(
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

    private func studentDraft(
        displayName: String = "Ava Stone",
        studentIdentifier: String? = "0012"
    ) -> StudentDraft {
        StudentDraft(
            displayName: displayName,
            schoolID: "school-a",
            grade: "7",
            studentIdentifier: studentIdentifier,
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
            pronouns: "she / her",
            assignedMemberIDs: ["teacher-a"]
        )
    }

    private func mutationMembership(
        role: StaffRole = .teacher,
        capabilities: Set<Capability> = [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: Set<String> = ["student-a", "student-b"],
        version: Int = 1
    ) -> StudentMutationMembership {
        StudentMutationMembership(
            districtID: "district-a",
            schoolIDs: ["school-a", "school-b"],
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assignedStudentIDs,
            isActive: true,
            version: version
        )
    }

    private func snapshot(
        id: String,
        districtID: String = "district-a",
        schoolID: String = "school-a",
        displayName: String = "Ava Stone",
        grade: String = "7",
        studentIdentifier: String? = "0012",
        assignedMemberIDs: Set<String> = ["teacher-a", "teacher-b"],
        isArchived: Bool = false,
        recordVersion: Int = 3
    ) -> FirebaseStudentSnapshot {
        FirebaseStudentSnapshot(
            documentID: id,
            document: FirebaseStudentDocument(
                districtId: districtID,
                schoolId: schoolID,
                displayName: displayName,
                grade: grade,
                studentIdentifier: studentIdentifier,
                dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
                pronouns: "she / her",
                assignedMemberIDs: assignedMemberIDs,
                isArchived: isArchived,
                schemaVersion: 1,
                recordVersion: recordVersion,
                createdAt: Date(timeIntervalSince1970: 10),
                createdBy: "teacher-a",
                updatedAt: Date(timeIntervalSince1970: 20),
                updatedBy: "teacher-a"
            )
        )
    }

    private func expectRepositoryError(
        _ expected: StudentRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected StudentRepositoryError.\(expected)")
        } catch let error as StudentRepositoryError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private final class StudentMutationAuthorityRefresherSpy: StudentMutationAuthorityRefreshing, @unchecked Sendable {
    struct Request: Sendable, Equatable {
        let membership: StudentMutationMembership
        let previous: MembershipContext
    }

    private let state = Mutex<[Request]>([])
    private let error: StudentMutationAuthorityRefreshError?

    init(error: StudentMutationAuthorityRefreshError? = nil) {
        self.error = error
    }

    var requests: [Request] {
        state.withLock { $0 }
    }

    func refresh(
        membership: StudentMutationMembership,
        previous: MembershipContext
    ) async throws -> MembershipContext {
        state.withLock { $0.append(Request(membership: membership, previous: previous)) }
        if let error {
            throw error
        }
        return try membership.context(userID: previous.userID)
    }
}

private final class StudentRecordStoreSpy: StudentRecordStore, @unchecked Sendable {
    private struct State: Sendable {
        var queuedPageResults: [Result<StudentStorePage, StudentRecordStoreError>]
        var queuedStudentResults: [Result<FirebaseStudentSnapshot?, StudentRecordStoreError>]
        var pageRequests: [StudentStorePageRequest] = []
        var studentRequests: [StudentStoreRecordRequest] = []
    }

    private let state: Mutex<State>

    var pageRequests: [StudentStorePageRequest] {
        state.withLock { $0.pageRequests }
    }

    var studentRequests: [StudentStoreRecordRequest] {
        state.withLock { $0.studentRequests }
    }

    init(
        pageResults: [Result<StudentStorePage, StudentRecordStoreError>] = [],
        studentResults: [Result<FirebaseStudentSnapshot?, StudentRecordStoreError>] = []
    ) {
        self.state = Mutex(State(
            queuedPageResults: pageResults,
            queuedStudentResults: studentResults
        ))
    }

    func page(for request: StudentStorePageRequest) async throws -> StudentStorePage {
        let result: Result<StudentStorePage, StudentRecordStoreError>? = state.withLock { state in
            state.pageRequests.append(request)
            guard !state.queuedPageResults.isEmpty else { return nil }
            return state.queuedPageResults.removeFirst()
        }
        return try result?.get() ?? StudentStorePage(documents: [], nextCursor: nil)
    }

    func student(for request: StudentStoreRecordRequest) async throws -> FirebaseStudentSnapshot? {
        let result: Result<FirebaseStudentSnapshot?, StudentRecordStoreError>? = state.withLock { state in
            state.studentRequests.append(request)
            guard !state.queuedStudentResults.isEmpty else { return nil }
            return state.queuedStudentResults.removeFirst()
        }
        return try result?.get()
    }
}

private final class StudentMutationBackendSpy: StudentTrustedMutationBackend, @unchecked Sendable {
    private struct State: Sendable {
        var queuedCreateResults: [Result<StudentMutationResult, StudentMutationBackendError>]
        var queuedUpdateResults: [Result<StudentMutationResult, StudentMutationBackendError>]
        var queuedArchiveResults: [Result<StudentMutationResult, StudentMutationBackendError>]
        var createRequests: [StudentCreateMutationRequest] = []
        var updateRequests: [StudentUpdateMutationRequest] = []
        var archiveRequests: [StudentArchiveMutationRequest] = []
    }

    private let state: Mutex<State>

    var createRequests: [StudentCreateMutationRequest] {
        state.withLock { $0.createRequests }
    }

    var updateRequests: [StudentUpdateMutationRequest] {
        state.withLock { $0.updateRequests }
    }

    var archiveRequests: [StudentArchiveMutationRequest] {
        state.withLock { $0.archiveRequests }
    }

    init(
        createResults: [Result<StudentMutationResult, StudentMutationBackendError>] = [],
        updateResults: [Result<StudentMutationResult, StudentMutationBackendError>] = [],
        archiveResults: [Result<StudentMutationResult, StudentMutationBackendError>] = []
    ) {
        self.state = Mutex(State(
            queuedCreateResults: createResults,
            queuedUpdateResults: updateResults,
            queuedArchiveResults: archiveResults
        ))
    }

    func createStudent(_ request: StudentCreateMutationRequest) async throws -> StudentMutationResult {
        let result: Result<StudentMutationResult, StudentMutationBackendError>? = state.withLock { state in
            state.createRequests.append(request)
            guard !state.queuedCreateResults.isEmpty else { return nil }
            return state.queuedCreateResults.removeFirst()
        }
        guard let result else { throw StudentMutationBackendError.invalidResponse }
        return try result.get()
    }

    func updateStudent(_ request: StudentUpdateMutationRequest) async throws -> StudentMutationResult {
        let result: Result<StudentMutationResult, StudentMutationBackendError>? = state.withLock { state in
            state.updateRequests.append(request)
            guard !state.queuedUpdateResults.isEmpty else { return nil }
            return state.queuedUpdateResults.removeFirst()
        }
        guard let result else { throw StudentMutationBackendError.invalidResponse }
        return try result.get()
    }

    func archiveStudent(_ request: StudentArchiveMutationRequest) async throws -> StudentMutationResult {
        let result: Result<StudentMutationResult, StudentMutationBackendError>? = state.withLock { state in
            state.archiveRequests.append(request)
            guard !state.queuedArchiveResults.isEmpty else { return nil }
            return state.queuedArchiveResults.removeFirst()
        }
        guard let result else { throw StudentMutationBackendError.invalidResponse }
        return try result.get()
    }
}

private final class StudentPageCacheSpy: StudentPageCache, @unchecked Sendable {
    private struct State: Sendable {
        var pages: [StudentPageCacheKey: StudentStorePage] = [:]
        var savedKeys: [StudentPageCacheKey] = []
        var invalidatedAuthorities: [StudentCacheAuthority] = []
    }

    private let state = Mutex(State())

    var savedKeys: [StudentPageCacheKey] {
        state.withLock { $0.savedKeys }
    }

    var invalidatedAuthorities: [StudentCacheAuthority] {
        state.withLock { $0.invalidatedAuthorities }
    }

    func page(for key: StudentPageCacheKey) async -> StudentStorePage? {
        state.withLock { $0.pages[key] }
    }

    func save(_ page: StudentStorePage, for key: StudentPageCacheKey) async {
        state.withLock { state in
            state.pages[key] = page
            state.savedKeys.append(key)
        }
    }

    func invalidate(authority: StudentCacheAuthority) async {
        state.withLock { state in
            state.invalidatedAuthorities.append(authority)
            state.pages = state.pages.filter { key, _ in
                key.districtID != authority.districtID || key.userID != authority.userID
            }
        }
    }
}

private extension StudentPageCacheKey {
    static func fixture(userID: String) -> StudentPageCacheKey {
        StudentPageCacheKey(
            districtID: "district-a",
            userID: userID,
            membershipVersion: 1,
            search: nil,
            schoolID: "school-a",
            grade: nil,
            assignedMemberID: nil,
            status: .active,
            sort: .alphabetical,
            cursor: nil,
            limit: 50
        )
    }
}

private nonisolated struct StudentPageCacheDeletionFailurePersistence: StudentPageCachePersistence {
    let storage: SecureStorage
    let failingKey: String

    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws {
        try await storage.store(object, for: key)
    }

    func restore<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String
    ) async throws -> T {
        try await storage.retrieve(type, for: key)
    }

    func remove(for key: String) throws {
        guard key != failingKey else {
            throw SecureStorageError.deletionFailed
        }
        try storage.delete(for: key)
    }
}

private nonisolated struct StudentPageCacheTombstoneReadFailurePersistence: StudentPageCachePersistence {
    let storage: SecureStorage
    let archiveKey: String

    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws {
        try await storage.store(object, for: key)
    }

    func restore<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String
    ) async throws -> T {
        guard key == archiveKey else {
            throw SecureStorageError.retrievalFailed
        }
        return try await storage.retrieve(type, for: key)
    }

    func remove(for key: String) throws {
        try storage.delete(for: key)
    }
}

private nonisolated struct StudentPageCacheRewriteFailurePersistence: StudentPageCachePersistence {
    let storage: SecureStorage
    let failingKey: String

    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws {
        guard key != failingKey else {
            throw SecureStorageError.storageFailed
        }
        try await storage.store(object, for: key)
    }

    func restore<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String
    ) async throws -> T {
        try await storage.retrieve(type, for: key)
    }

    func remove(for key: String) throws {
        try storage.delete(for: key)
    }
}

private nonisolated struct StudentPageCacheTombstoneWriteFailurePersistence: StudentPageCachePersistence {
    let storage: SecureStorage
    let archiveKey: String

    func persist<T: Codable & Sendable>(_ object: T, for key: String) async throws {
        guard !key.hasPrefix("\(archiveKey).denied-authorities.") else {
            throw SecureStorageError.storageFailed
        }
        try await storage.store(object, for: key)
    }

    func restore<T: Codable & Sendable>(
        _ type: T.Type,
        for key: String
    ) async throws -> T {
        try await storage.retrieve(type, for: key)
    }

    func remove(for key: String) throws {
        guard key != archiveKey else {
            throw SecureStorageError.deletionFailed
        }
        try storage.delete(for: key)
    }
}

private final class StudentCreateOutboxSpy: StudentCreateOutbox, @unchecked Sendable {
    private let state: Mutex<[PendingStudentCreate]>

    init(items: [PendingStudentCreate] = []) {
        self.state = Mutex(items)
    }

    var items: [PendingStudentCreate] {
        state.withLock { $0 }
    }

    func enqueue(_ item: PendingStudentCreate) async throws {
        state.withLock { items in
            items.removeAll { $0.operationID == item.operationID }
            items.append(item)
        }
    }

    func pending() async throws -> [PendingStudentCreate] {
        state.withLock { $0 }
    }

    func remove(operationID: UUID) async throws {
        state.withLock { items in
            items.removeAll { $0.operationID == operationID }
        }
    }
}

private final class StudentCreateOutboxStorageSpy: StudentCreateOutboxStorage, @unchecked Sendable {
    private let state = Mutex<[PendingStudentCreate]>([])

    func load() async throws -> [PendingStudentCreate] {
        state.withLock { $0 }
    }

    func save(_ items: [PendingStudentCreate]) async throws {
        state.withLock { $0 = items }
    }
}
