import Foundation
import Testing
@testable import TMI

@Suite("Student roster state")
@MainActor
struct StudentListStateTests {
    @Test("The first load moves from idle through loading to empty")
    func firstLoadShowsLoadingThenEmpty() async {
        let gate = StudentListAsyncGate()
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: []))],
            pageGates: [gate]
        )
        let state = makeState(repository: repository)

        #expect(state.phase == .idle)
        let load = Task { await state.load() }
        await waitForPageRequests(1, repository: repository)
        #expect(state.phase == .loading)

        await gate.open()
        await load.value

        #expect(state.phase == .empty)
        #expect(state.students.isEmpty)
    }

    @Test("A populated refresh preserves records while refreshing and replaces them after confirmation")
    func refreshPreservesLoadedRecords() async {
        let gate = StudentListAsyncGate()
        let initial = record(id: "student-a", displayName: "Ava Stone")
        let refreshed = record(id: "student-a", displayName: "Ava Updated", recordVersion: 2)
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [initial])),
                .success(page(records: [refreshed])),
            ],
            pageGates: [nil, gate]
        )
        let state = makeState(repository: repository)
        await state.load()

        #expect(state.phase == .loaded)
        #expect(state.students == [initial])

        let refresh = Task { await state.refresh() }
        await waitForPageRequests(2, repository: repository)
        #expect(state.phase == .refreshing)
        #expect(state.students == [initial])

        await gate.open()
        await refresh.value

        #expect(state.phase == .loaded)
        #expect(state.students == [refreshed])
    }

    @Test("A cached roster is explicitly offline")
    func cachedPageShowsOfflinePhase() async {
        let cached = record(id: "student-a", displayName: "Ava Stone")
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [cached], source: .cache))]
        )
        let state = makeState(repository: repository)

        await state.load()

        #expect(state.phase == .offline)
        #expect(state.students == [cached])
    }

    @Test("A confirmed online mutation clears an offline roster phase")
    func confirmedMutationClearsOfflinePhase() async {
        let cached = record(id: "student-a", displayName: "Ava Stone")
        let updated = record(id: "student-a", displayName: "Ava Updated", recordVersion: 2)
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [cached], source: .cache))],
            updates: [.success(updated)]
        )
        let state = makeState(repository: repository)
        await state.load()
        #expect(state.phase == .offline)

        let succeeded = await state.update(
            id: cached.id,
            draft: studentDraft(displayName: updated.displayName),
            expectedVersion: cached.metadata.recordVersion,
            operationID: UUID()
        )

        #expect(succeeded)
        #expect(state.phase == .loaded)
        #expect(state.students == [updated])
    }

    @Test("Permission denial clears the roster and receives a dedicated phase")
    func permissionDeniedFailsClosed() async {
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [record(id: "student-a")])),
                .failure(.permissionDenied),
            ]
        )
        let state = makeState(repository: repository)
        await state.load()

        await state.refresh()

        #expect(state.phase == .permissionDenied)
        #expect(state.students.isEmpty)
    }

    @Test("A recoverable load failure preserves records and can be retried")
    func recoverableFailureCanRetry() async {
        let original = record(id: "student-a", displayName: "Ava Stone")
        let recovered = record(id: "student-a", displayName: "Ava Recovered", recordVersion: 2)
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [original])),
                .failure(.unavailable),
                .success(page(records: [recovered])),
            ]
        )
        let state = makeState(repository: repository)
        await state.load()

        await state.refresh()
        #expect(state.phase == .failed("Unable to load students. Try again."))
        #expect(state.students == [original])

        await state.refresh()
        #expect(state.phase == .loaded)
        #expect(state.students == [recovered])
    }

    @Test("Search waits for the 300 millisecond debounce, cancels stale input, and resets illegal recent sorting")
    func searchIsDebouncedAndCancellable() async throws {
        let sleeper = StudentListSleeperSpy()
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [record(id: "student-a")]))]
        )
        let state = makeState(
            repository: repository,
            sleep: { duration in
                try await sleeper.sleep(duration)
            }
        )
        state.sort = .recentlyUpdated

        state.searchText = "A"
        state.searchText = "Ava Stone"
        await waitForPageRequests(1, repository: repository)

        let requests = await repository.pageRequests
        let durations = await sleeper.durations
        #expect(requests.count == 1)
        #expect(requests[0].search == "Ava Stone")
        #expect(requests[0].sort == .alphabetical)
        #expect(state.sort == .alphabetical)
        #expect(durations.last == .milliseconds(300))
        try await Task.sleep(for: .milliseconds(30))
        #expect(await repository.pageRequests.count == 1)
    }

    @Test("A replacement search supersedes an older first page that is still in flight")
    func replacementSearchSupersedesInFlightPage() async {
        let oldPageGate = StudentListAsyncGate()
        let oldRecord = record(id: "student-old", displayName: "Old Result")
        let currentRecord = record(id: "student-current", displayName: "Ava Stone")
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [oldRecord])),
                .success(page(records: [currentRecord])),
            ],
            pageGates: [oldPageGate, nil]
        )
        let state = makeState(
            repository: repository,
            sleep: { _ in }
        )

        let initialLoad = Task { await state.load() }
        await waitForPageRequests(1, repository: repository)

        state.searchText = "Ava"
        await waitForPageRequests(2, repository: repository)
        while state.students != [currentRecord] {
            await Task.yield()
        }

        #expect(state.phase == .loaded)
        #expect(state.students == [currentRecord])

        await oldPageGate.open()
        await initialLoad.value

        #expect(state.phase == .loaded)
        #expect(state.students == [currentRecord])
        #expect((await repository.pageRequests).map(\.search) == ["", "Ava"])
    }

    @Test("Committed filters and sort are forwarded to the first server page")
    func filtersAndSortAreServerBacked() async {
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [])),
                .success(page(records: [])),
            ]
        )
        let state = makeState(repository: repository)
        let filters = StudentListFilters(
            schoolID: "school-b",
            grade: "8",
            assignedMemberID: "teacher-b",
            status: .archived
        )

        await state.setFilters(filters)
        await state.setSort(.recentlyUpdated)

        let requests = await repository.pageRequests
        #expect(requests.count == 2)
        #expect(requests[0].schoolID == "school-b")
        #expect(requests[0].grade == "8")
        #expect(requests[0].assignedMemberID == "teacher-b")
        #expect(requests[0].status == .archived)
        #expect(requests[0].sort == .alphabetical)
        #expect(requests[1].sort == .recentlyUpdated)
        #expect(requests.allSatisfy { $0.cursor == nil })
    }

    @Test("The next page appends unique records and rejects a duplicate pagination request")
    func nextPageAppendsOnce() async {
        let gate = StudentListAsyncGate()
        let cursor = StudentPageCursor(token: "student-a", queryFingerprint: "query")
        let first = record(id: "student-a", displayName: "Ava Stone")
        let second = record(id: "student-b", displayName: "Ben Stone")
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [first], nextCursor: cursor)),
                .success(page(records: [first, second])),
            ],
            pageGates: [nil, gate]
        )
        let state = makeState(repository: repository)
        await state.load()

        #expect(state.canLoadNextPage)
        let firstNext = Task { await state.loadNextPage() }
        await waitForPageRequests(2, repository: repository)
        #expect(state.isLoadingNextPage)
        let duplicateNext = Task { await state.loadNextPage() }
        await duplicateNext.value
        #expect(await repository.pageRequests.count == 2)

        await gate.open()
        await firstNext.value

        #expect(state.students.map(\.id) == ["student-a", "student-b"])
        #expect(!state.canLoadNextPage)
        #expect(!state.isLoadingNextPage)
        #expect((await repository.pageRequests)[1].cursor == cursor)
    }

    @Test("Concurrent initial loads coalesce into one repository request")
    func duplicateLoadsAreDisabled() async {
        let gate = StudentListAsyncGate()
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: []))],
            pageGates: [gate]
        )
        let state = makeState(repository: repository)

        let first = Task { await state.load() }
        await waitForPageRequests(1, repository: repository)
        let duplicate = Task { await state.load() }
        await duplicate.value

        #expect(await repository.pageRequests.count == 1)
        await gate.open()
        await first.value
        #expect(state.phase == .empty)
    }

    @Test("Create disables double submit and confirms only after the repository responds")
    func createConfirmsAfterRepositoryResponse() async {
        let gate = StudentListAsyncGate()
        let created = record(id: "student-new", displayName: "Ava Stone", recordVersion: 1)
        let repository = StudentListRepositorySpy(
            creates: [.success(created)],
            createGates: [gate]
        )
        let state = makeState(repository: repository)
        let draft = studentDraft()
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!

        let first = Task {
            await state.create(draft, operationID: operationID)
        }
        await waitForCreateRequests(1, repository: repository)
        #expect(state.isSubmitting)
        #expect(state.lastConfirmedMutation == nil)
        #expect(state.editorDraft(for: .create) == draft)

        let duplicate = await state.create(draft, operationID: UUID())
        #expect(!duplicate)
        #expect(await repository.createRequests.count == 1)
        #expect(state.lastConfirmedMutation == nil)

        await gate.open()
        let succeeded = await first.value

        #expect(succeeded)
        #expect(!state.isSubmitting)
        #expect(state.editorDraft(for: .create) == nil)
        #expect(state.lastConfirmedMutation == .created(created))
        #expect(state.students == [created])
    }

    @Test("A failed create preserves the exact editor draft")
    func failedCreatePreservesDraft() async {
        let repository = StudentListRepositorySpy(creates: [.failure(.unavailable)])
        let state = makeState(repository: repository)
        let draft = studentDraft(displayName: "  Ava   Stone  ")

        let succeeded = await state.create(draft, operationID: UUID())

        #expect(!succeeded)
        #expect(state.editorDraft(for: .create) == draft)
        #expect(state.mutationError == .unavailable)
        #expect(state.lastConfirmedMutation == nil)
    }

    @Test("A failed edit draft is retained only for the student that owns it")
    func failedEditDraftDoesNotLeakToAnotherEditor() async {
        let repository = StudentListRepositorySpy(updates: [.failure(.unavailable)])
        let state = makeState(repository: repository)
        let draft = studentDraft(displayName: "Ava Revised")

        let succeeded = await state.update(
            id: "student-a",
            draft: draft,
            expectedVersion: 1,
            operationID: UUID()
        )

        #expect(!succeeded)
        #expect(state.editorDraft(for: .edit("student-a")) == draft)
        #expect(state.editorDraft(for: .edit("student-b")) == nil)
        #expect(state.editorDraft(for: .create) == nil)
        #expect(state.mutationError(for: .edit("student-a")) == .unavailable)
        #expect(state.mutationError(for: .edit("student-b")) == nil)
    }

    @Test("Loading reconciles queued creates and retains confirmations missing from a stale page")
    func loadReconcilesPendingCreates() async {
        let queued = record(id: "student-queued", displayName: "Queued Student")
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: []))],
            reconciliations: [.success([queued])]
        )
        let state = makeState(repository: repository)

        await state.load()

        #expect(state.phase == .loaded)
        #expect(state.students == [queued])
        #expect(await repository.reconcileMembers == [membership()])
    }

    @Test("A queued create stays pending until a later load reconciles it")
    func queuedCreateClearsOnlyAfterReconciliation() async {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!
        let draft = studentDraft(displayName: "Queued Student")
        let confirmed = record(id: "student-queued", displayName: draft.displayName)
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: []))],
            creates: [.failure(.createQueued(operationID: operationID))],
            reconciliations: [.success([confirmed])]
        )
        let state = makeState(repository: repository)

        let created = await state.create(draft, operationID: operationID)

        #expect(!created)
        #expect(state.mutationError(for: .create) == .createQueued(operationID: operationID))
        #expect(state.editorDraft(for: .create) == draft)

        await state.load()

        #expect(state.mutationError(for: .create) == nil)
        #expect(state.editorDraft(for: .create) == nil)
        #expect(state.students == [confirmed])
        #expect(state.phase == .loaded)
    }

    @Test("A confirmed update replaces the record and archive removes it")
    func updateAndArchiveUseRepositoryConfirmation() async {
        let original = record(id: "student-a", displayName: "Ava Stone", recordVersion: 1)
        let updated = record(id: "student-a", displayName: "Ava Updated", recordVersion: 2)
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [original]))],
            updates: [.success(updated)],
            archives: [.success(())]
        )
        let state = makeState(repository: repository)
        await state.load()

        let didUpdate = await state.update(
            id: original.id,
            draft: studentDraft(displayName: updated.displayName),
            expectedVersion: original.metadata.recordVersion,
            operationID: UUID()
        )
        #expect(didUpdate)
        #expect(state.students == [updated])
        #expect(state.lastConfirmedMutation == .updated(updated))

        let didArchive = await state.archive(
            id: updated.id,
            expectedVersion: updated.metadata.recordVersion,
            operationID: UUID()
        )
        #expect(didArchive)
        #expect(state.students.isEmpty)
        #expect(state.phase == .empty)
        #expect(state.lastConfirmedMutation == .archived(updated.id))
    }

    @Test("Changing membership cancels authority-bound state before the next load")
    func memberUpdateResetsAuthorityState() async {
        let repository = StudentListRepositorySpy(
            pages: [
                .success(page(records: [record(id: "student-a")])),
                .success(page(records: [])),
            ]
        )
        let state = makeState(repository: repository)
        await state.load()
        state.searchText = "pending"

        let replacement = membership(userID: "teacher-b", version: 4)
        state.updateMember(replacement)

        #expect(state.phase == .idle)
        #expect(state.students.isEmpty)
        #expect(state.searchText.isEmpty)
        await state.load()
        #expect((await repository.pageMembers).last == replacement)
    }

    @Test("A mutation response from an obsolete authority cannot repopulate the roster")
    func authorityChangeRejectsInFlightMutationResult() async {
        let gate = StudentListAsyncGate()
        let updated = record(id: "student-a", displayName: "Old Tenant Result", recordVersion: 2)
        let repository = StudentListRepositorySpy(
            updates: [.success(updated)],
            updateGates: [gate]
        )
        let state = makeState(repository: repository)

        let mutation = Task {
            await state.update(
                id: "student-a",
                draft: studentDraft(displayName: updated.displayName),
                expectedVersion: 1,
                operationID: UUID()
            )
        }
        await waitForUpdateRequests(1, repository: repository)

        state.updateMember(membership(userID: "teacher-b", version: 2))
        await gate.open()

        #expect(await mutation.value == false)
        #expect(state.students.isEmpty)
        #expect(state.phase == .idle)
        #expect(!state.isSubmitting)
    }

    @Test("A trusted compatible authority refresh may confirm the mutation that caused it")
    func compatibleAuthorityRefreshAcceptsConfirmedCreate() async {
        let gate = StudentListAsyncGate()
        let created = record(id: "student-new", displayName: "Created Student")
        let repository = StudentListRepositorySpy(
            creates: [.success(created)],
            createGates: [gate]
        )
        let state = makeState(repository: repository)

        let mutation = Task {
            await state.create(
                studentDraft(displayName: created.displayName),
                operationID: UUID()
            )
        }
        await waitForCreateRequests(1, repository: repository)

        state.updateMember(membership(version: 2))
        await gate.open()

        #expect(await mutation.value)
        #expect(state.students == [created])
        #expect(state.lastConfirmedMutation == .created(created))
        #expect(state.phase == .loaded)
    }

    @Test("A completed newer mutation permanently supersedes an older compatible response")
    func newerMutationSequenceRejectsOlderResponse() async {
        let oldGate = StudentListAsyncGate()
        let oldRecord = record(id: "student-new", displayName: "Older Response")
        let newRecord = record(id: "student-newer", displayName: "Newer Response")
        let repository = StudentListRepositorySpy(
            creates: [.success(oldRecord), .success(newRecord)],
            createGates: [oldGate, nil]
        )
        let state = makeState(repository: repository)

        let olderMutation = Task {
            await state.create(
                studentDraft(displayName: oldRecord.displayName),
                operationID: UUID()
            )
        }
        await waitForCreateRequests(1, repository: repository)
        state.updateMember(membership(version: 2))

        let newerConfirmed = await state.create(
            studentDraft(displayName: newRecord.displayName),
            operationID: UUID()
        )
        #expect(newerConfirmed)
        #expect(state.students == [newRecord])

        await oldGate.open()

        #expect(await olderMutation.value == false)
        #expect(state.students == [newRecord])
        #expect(state.lastConfirmedMutation == .created(newRecord))
    }

    @Test("A stale quarantined offline create cannot block a current roster read")
    func stalePendingCreateDoesNotBlockRoster() async {
        let operationID = UUID(uuidString: "00000000-0000-0000-0000-000000000903")!
        let visible = record(id: "student-a")
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [visible]))],
            creates: [.failure(.createQueued(operationID: operationID))],
            reconciliations: [.failure(.staleMembership)]
        )
        let state = makeState(repository: repository)
        let draft = studentDraft(displayName: "Stale Offline Draft")

        _ = await state.create(draft, operationID: operationID)
        state.updateMember(membership(version: 2))
        await state.load()

        #expect(state.phase == .loaded)
        #expect(state.students == [visible])
        #expect(state.pendingCreateNeedsReview)
        #expect(state.mutationError(for: .create) == nil)
        #expect(state.editorDraft(for: .create) == nil)
        #expect(await repository.pageRequests.count == 1)
    }

    @Test("A rejected pending create cannot replace the current page authorization decision")
    func pendingCreatePermissionDenialDoesNotBlockRoster() async {
        let visible = record(id: "student-a")
        let repository = StudentListRepositorySpy(
            pages: [.success(page(records: [visible]))],
            reconciliations: [.failure(.permissionDenied)]
        )
        let state = makeState(repository: repository)

        await state.load()

        #expect(state.phase == .loaded)
        #expect(state.students == [visible])
        #expect(state.pendingCreateNeedsReview)
        #expect(await repository.pageRequests.count == 1)
    }

    private func makeState(
        repository: StudentListRepositorySpy,
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) -> StudentListState {
        StudentListState(
            repository: repository,
            member: membership(),
            debounceDuration: .milliseconds(300),
            sleep: sleep
        )
    }

    private func membership(
        userID: String = "teacher-a",
        version: Int = 1
    ) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: "district-a",
            schoolIDs: ["school-a", "school-b"],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: ["student-a", "student-b", "student-new"],
            isActive: true,
            version: version
        )
    }

    private func studentDraft(displayName: String = "Ava Stone") -> StudentDraft {
        StudentDraft(
            displayName: displayName,
            schoolID: "school-a",
            grade: "7",
            studentIdentifier: "0012",
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
            pronouns: "she / her",
            assignedMemberIDs: ["teacher-a"]
        )
    }

    private func record(
        id: String,
        displayName: String = "Ava Stone",
        recordVersion: Int = 1
    ) -> StudentRecord {
        StudentRecord(
            id: id,
            districtID: "district-a",
            schoolID: "school-a",
            displayName: displayName,
            grade: "7",
            studentIdentifier: "0012",
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
            pronouns: "she / her",
            assignedMemberIDs: ["teacher-a"],
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: recordVersion,
                createdAt: Date(timeIntervalSince1970: 10),
                createdBy: "teacher-a",
                updatedAt: Date(timeIntervalSince1970: Double(recordVersion * 10)),
                updatedBy: "teacher-a"
            )
        )
    }

    private func page(
        records: [StudentRecord],
        nextCursor: StudentPageCursor? = nil,
        source: StudentPageSource = .server
    ) -> StudentPage {
        StudentPage(records: records, nextCursor: nextCursor, source: source)
    }

    private func waitForPageRequests(
        _ count: Int,
        repository: StudentListRepositorySpy
    ) async {
        while await repository.pageRequests.count < count {
            await Task.yield()
        }
    }

    private func waitForCreateRequests(
        _ count: Int,
        repository: StudentListRepositorySpy
    ) async {
        while await repository.createRequests.count < count {
            await Task.yield()
        }
    }

    private func waitForUpdateRequests(
        _ count: Int,
        repository: StudentListRepositorySpy
    ) async {
        while await repository.updateRequests.count < count {
            await Task.yield()
        }
    }
}

private actor StudentListAsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var permitCount = 0

    func wait() async {
        if permitCount > 0 {
            permitCount -= 1
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        if let continuation {
            self.continuation = nil
            continuation.resume()
        } else {
            permitCount += 1
        }
    }
}

private actor StudentListSleeperSpy {
    private(set) var durations: [Duration] = []

    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        try await Task.sleep(for: .milliseconds(10))
    }
}

private actor StudentListRepositorySpy: StudentRepository {
    private var queuedPages: [Result<StudentPage, StudentRepositoryError>]
    private var queuedCreates: [Result<StudentRecord, StudentRepositoryError>]
    private var queuedUpdates: [Result<StudentRecord, StudentRepositoryError>]
    private var queuedArchives: [Result<Void, StudentRepositoryError>]
    private var queuedReconciliations: [Result<[StudentRecord], StudentRepositoryError>]
    private var pageGates: [StudentListAsyncGate?]
    private var createGates: [StudentListAsyncGate?]
    private var updateGates: [StudentListAsyncGate?]

    private(set) var pageRequests: [StudentPageRequest] = []
    private(set) var pageMembers: [MembershipContext] = []
    private(set) var createRequests: [(StudentDraft, UUID, MembershipContext)] = []
    private(set) var updateRequests: [(String, StudentDraft, Int, UUID, MembershipContext)] = []
    private(set) var archiveRequests: [(String, Int, UUID, MembershipContext)] = []
    private(set) var reconcileMembers: [MembershipContext] = []

    init(
        pages: [Result<StudentPage, StudentRepositoryError>] = [],
        creates: [Result<StudentRecord, StudentRepositoryError>] = [],
        updates: [Result<StudentRecord, StudentRepositoryError>] = [],
        archives: [Result<Void, StudentRepositoryError>] = [],
        reconciliations: [Result<[StudentRecord], StudentRepositoryError>] = [],
        pageGates: [StudentListAsyncGate?] = [],
        createGates: [StudentListAsyncGate?] = [],
        updateGates: [StudentListAsyncGate?] = []
    ) {
        self.queuedPages = pages
        self.queuedCreates = creates
        self.queuedUpdates = updates
        self.queuedArchives = archives
        self.queuedReconciliations = reconciliations
        self.pageGates = pageGates
        self.createGates = createGates
        self.updateGates = updateGates
    }

    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        pageRequests.append(request)
        pageMembers.append(member)
        let gate = pageGates.isEmpty ? nil : pageGates.removeFirst()
        guard !queuedPages.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        let result = queuedPages.removeFirst()
        if let gate {
            await gate.wait()
        }
        return try result.get()
    }

    func student(id: String, member: MembershipContext) async throws -> StudentRecord {
        throw StudentRepositoryError.notFound
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        createRequests.append((draft, operationID, member))
        let gate = createGates.isEmpty ? nil : createGates.removeFirst()
        guard !queuedCreates.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        let result = queuedCreates.removeFirst()
        if let gate {
            await gate.wait()
        }
        return try result.get()
    }

    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord] {
        reconcileMembers.append(member)
        guard !queuedReconciliations.isEmpty else { return [] }
        return try queuedReconciliations.removeFirst().get()
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        updateRequests.append((id, draft, expectedVersion, operationID, member))
        let gate = updateGates.isEmpty ? nil : updateGates.removeFirst()
        guard !queuedUpdates.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        let result = queuedUpdates.removeFirst()
        if let gate {
            await gate.wait()
        }
        return try result.get()
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        archiveRequests.append((id, expectedVersion, operationID, member))
        guard !queuedArchives.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        try queuedArchives.removeFirst().get()
    }
}
