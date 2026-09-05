import Foundation
import Testing
@testable import TMI

@Suite("Student operational hub state")
@MainActor
struct StudentDetailStateTests {
    @Test("The header projects canonical identity and operational status")
    func headerProjectsCanonicalStudentContext() async {
        let lastInteraction = Date(timeIntervalSince1970: 1_800)
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(
                snapshot(
                    student: record(
                        assignedMemberIDs: ["teacher-a", "counselor-a"]
                    ),
                    activePlanStatus: .none,
                    lastInteractionAt: lastInteraction
                )
            )
        )
        let state = makeState(repository: repository)

        await state.load(studentID: "student-a")

        #expect(
            state.header == StudentHeaderProjection(
                studentID: "student-a",
                displayName: "Ava Stone",
                grade: "7",
                schoolID: "school-a",
                assignedStaffCount: 2,
                activePlanStatus: .none,
                lastInteractionAt: lastInteraction,
                studentModeAvailability: .availableInRelease2
            )
        )
        #expect(state.phase == .loaded)
        #expect(
            state.header?.studentModeAvailability == .availableInRelease2
        )
    }

    @Test("Contextual actions are derived from current authorization")
    func menuActionsUseAuthorizationPolicy() async {
        let writableRepository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot())
        )
        let writableState = makeState(
            repository: writableRepository,
            member: membership(role: .teacher)
        )

        await writableState.load(studentID: "student-a")

        #expect(writableState.menuActions == [.edit, .archive])
        #expect(!writableState.menuActions.contains(.delete))

        let readOnlyRepository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot())
        )
        let readOnlyState = makeState(
            repository: readOnlyRepository,
            member: membership(role: .socialWorker)
        )

        await readOnlyState.load(studentID: "student-a")

        #expect(readOnlyState.menuActions.isEmpty)
    }

    @Test("Private staff notes and student reflections use separate queries and projections")
    func notesAndReflectionsRemainSeparate() async {
        let note = StudentPrivateNoteProjection(
            id: "note-a",
            summary: "Staff follow-up",
            occurredAt: Date(timeIntervalSince1970: 1_700)
        )
        let reflection = StudentReflectionProjection(
            id: "reflection-a",
            summary: "Student reflection",
            occurredAt: Date(timeIntervalSince1970: 1_750)
        )
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            privateNotesResult: .success(.available([note])),
            studentReflectionsResult: .success(.available([reflection]))
        )
        let state = makeState(repository: repository)

        await state.load(studentID: "student-a")

        #expect(state.privateNotes == .available([note]))
        #expect(state.studentReflections == .available([reflection]))
        #expect(await repository.privateNoteRequests == ["student-a"])
        #expect(await repository.studentReflectionRequests == ["student-a"])
    }

    @Test("Release 1 marks both timeline feeds unavailable until Release 4")
    func release1TimelineFeedsAreUnavailable() async throws {
        let repository = Release1StudentDetailRepository(
            students: UnusedStudentRepository()
        )
        let member = membership(role: .teacher)

        let notes = try await repository.privateNotes(
            studentID: "student-a",
            member: member
        )
        let reflections = try await repository.studentReflections(
            studentID: "student-a",
            member: member
        )

        #expect(notes == .unavailable(nextAvailableRelease: 4))
        #expect(reflections == .unavailable(nextAvailableRelease: 4))
    }

    @Test("Empty canonical collections produce purposeful current and history sections")
    func emptyCollectionsProducePurposefulSections() async {
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(
                snapshot(collections: .empty)
            )
        )
        let state = makeState(repository: repository)

        await state.load(studentID: "student-a")

        let expectedDomains: Set<StudentDetailDomain> = [
            .interests,
            .surveysAndForms,
            .careers,
            .resources,
            .plans,
            .meetingsAndNotes,
            .progress,
        ]
        #expect(Set(state.currentSections.map(\.domain)) == expectedDomains)
        #expect(Set(state.historySections.map(\.domain)) == expectedDomains)
        #expect(state.currentSections.allSatisfy { $0.itemIDs.isEmpty })
        #expect(state.historySections.allSatisfy { $0.itemIDs.isEmpty })
        #expect(state.currentSections.allSatisfy { section in
            guard let emptyState = section.emptyState else { return false }
            return !emptyState.title.isEmpty
                && !emptyState.detail.isEmpty
                && emptyState.nextAvailableRelease >= 2
        })
        #expect(state.historySections.allSatisfy { section in
            guard let emptyState = section.emptyState else { return false }
            return !emptyState.title.isEmpty
                && !emptyState.detail.isEmpty
                && emptyState.nextAvailableRelease >= 2
        })
    }

    @Test("A confirmed canonical load establishes the router's active student")
    func loadEstablishesActiveStudentContext() async {
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot())
        )
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )

        await state.load(studentID: "student-a")

        #expect(router.activeStudentID == "student-a")
        #expect(router.activeStudentName == "Ava Stone")
        #expect(router.activeStudentRecord == record())
    }

    @Test("A returned record does not establish context without current authorization")
    func unauthorizedRecordDoesNotEstablishActiveContext() async {
        let member = membership(
            role: .counselor,
            assignedStudentIDs: []
        )
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot())
        )
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )

        await state.load(studentID: "student-a")

        #expect(state.phase == .permissionDenied)
        #expect(state.header == nil)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
        #expect(await repository.privateNoteRequests.isEmpty)
        #expect(await repository.studentReflectionRequests.isEmpty)
    }

    @Test("A related-record failure never publishes a partially loaded student context")
    func relatedRecordFailureDoesNotPublishContext() async {
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            privateNotesResult: .failure(.unavailable)
        )
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )

        await state.load(studentID: "student-a")

        #expect(state.phase == .failed("Unable to load this student. Try again."))
        #expect(state.header == nil)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
        #expect(await repository.studentReflectionRequests.isEmpty)
    }

    @Test("A cached snapshot is labeled offline and hides mutation actions")
    func cachedSnapshotIsHonestlyOffline() async {
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot(source: .cache))
        )
        let state = makeState(repository: repository)

        await state.load(studentID: "student-a")

        #expect(state.phase == .offline)
        #expect(state.header?.displayName == "Ava Stone")
        #expect(state.menuActions.isEmpty)
    }

    @Test("An unavailable refresh preserves canonical content as explicitly offline")
    func unavailableRefreshPreservesCanonicalContent() async {
        let repository = StudentDetailRepositorySpy(
            hubResults: [
                .success(snapshot()),
                .failure(.unavailable),
            ]
        )
        let state = makeState(repository: repository)
        await state.load(studentID: "student-a")
        #expect(state.phase == .loaded)

        await state.refresh()

        #expect(state.phase == .offline)
        #expect(state.header?.studentID == "student-a")
        #expect(state.header?.displayName == "Ava Stone")
        #expect(state.menuActions.isEmpty)
    }

    @Test("A confirmed edit sends versioned idempotent input and reprojects context")
    func confirmedEditReprojectsHeaderAndRouter() async {
        let operationID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000601"
        )!
        let updatedRecord = record(
            displayName: "Ava Updated",
            recordVersion: 2
        )
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            updateResults: [.success(updatedRecord)]
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")
        let draft = StudentDraft(
            displayName: "Ava Updated",
            schoolID: "school-a",
            grade: "7",
            studentIdentifier: "0012",
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
            pronouns: "she / her",
            assignedMemberIDs: ["teacher-a"]
        )

        let succeeded = await state.update(
            draft,
            operationID: operationID
        )

        #expect(succeeded)
        #expect(
            await repository.updateRequests == [
                StudentDetailUpdateRequest(
                    id: "student-a",
                    draft: draft,
                    expectedVersion: 1,
                    operationID: operationID
                ),
            ]
        )
        #expect(state.header?.displayName == "Ava Updated")
        #expect(router.activeStudentName == "Ava Updated")
        #expect(router.activeStudentRecord == updatedRecord)
        #expect(state.mutationError == nil)
    }

    @Test("An online-required edit preserves the last confirmed student")
    func failedEditPreservesConfirmedProjection() async {
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            updateResults: [.failure(.onlineRequired)]
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let succeeded = await state.update(
            StudentDraft(
                displayName: "Unconfirmed Name",
                schoolID: "school-a",
                grade: "7",
                studentIdentifier: "0012",
                dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
                pronouns: "she / her",
                assignedMemberIDs: ["teacher-a"]
            ),
            operationID: UUID()
        )

        #expect(!succeeded)
        #expect(state.mutationError == .onlineRequired)
        #expect(state.header?.displayName == "Ava Stone")
        #expect(router.activeStudentRecord == record())
    }

    @Test("An authority change invalidates an older edit response")
    func authorityChangeInvalidatesInFlightEdit() async {
        let updateGate = StudentDetailAsyncGate()
        let updatedRecord = record(
            displayName: "Stale Update",
            recordVersion: 2
        )
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            updateResults: [.success(updatedRecord)],
            updateGate: updateGate
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let update = Task {
            await state.update(
                StudentDraft(
                    displayName: "Stale Update",
                    schoolID: "school-a",
                    grade: "7",
                    studentIdentifier: "0012",
                    dateOfBirth: nil,
                    pronouns: nil,
                    assignedMemberIDs: ["teacher-a"]
                ),
                operationID: UUID()
            )
        }
        await waitForUpdateRequests(1, repository: repository)

        let revoked = membership(
            role: .teacher,
            assignedStudentIDs: []
        )
        router.updatePolicy(AppNavigationPolicy(membership: revoked))
        state.updateMember(revoked)
        await updateGate.open()

        #expect(!(await update.value))
        #expect(state.phase == .idle)
        #expect(state.header == nil)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
    }

    @Test("Refresh cannot supersede an in-flight confirmed edit")
    func refreshDoesNotSupersedeInFlightEdit() async {
        let updateGate = StudentDetailAsyncGate()
        let updatedRecord = record(
            displayName: "Confirmed Update",
            recordVersion: 2
        )
        let repository = StudentDetailRepositorySpy(
            hubResults: [
                .success(snapshot()),
                .failure(.permissionDenied),
            ],
            updateResults: [.success(updatedRecord)],
            updateGate: updateGate
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let update = Task {
            await state.update(
                StudentDraft(
                    displayName: "Confirmed Update",
                    schoolID: "school-a",
                    grade: "7",
                    studentIdentifier: "0012",
                    dateOfBirth: nil,
                    pronouns: nil,
                    assignedMemberIDs: ["teacher-a"]
                ),
                operationID: UUID()
            )
        }
        await waitForUpdateRequests(1, repository: repository)

        await state.refresh()
        #expect(await repository.hubRequests == ["student-a"])
        #expect(state.isMutating)
        await updateGate.open()

        #expect(await update.value)
        #expect(state.phase == .loaded)
        #expect(state.header?.displayName == "Confirmed Update")
        #expect(state.student == updatedRecord)
        #expect(router.activeStudentRecord == updatedRecord)
    }

    @Test("A stale refresh cannot overwrite a newer confirmed edit")
    func staleRefreshDoesNotOverwriteConfirmedEdit() async {
        let refreshGate = StudentDetailAsyncGate()
        let originalRecord = record()
        let updatedRecord = record(
            displayName: "Ava Updated",
            recordVersion: 2
        )
        let repository = StudentDetailRepositorySpy(
            hubResults: [
                .success(snapshot(student: originalRecord)),
                .success(snapshot(student: originalRecord)),
            ],
            updateResults: [.success(updatedRecord)],
            hubGates: [nil, refreshGate]
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let refresh = Task {
            await state.refresh()
        }
        await waitForHubRequests(2, repository: repository)

        let editSucceeded = await state.update(
            StudentDraft(
                displayName: "Ava Updated",
                schoolID: "school-a",
                grade: "7",
                studentIdentifier: "0012",
                dateOfBirth: nil,
                pronouns: nil,
                assignedMemberIDs: ["teacher-a"]
            ),
            operationID: UUID()
        )
        #expect(editSucceeded)
        await refreshGate.open()
        await refresh.value

        #expect(state.phase == .loaded)
        #expect(state.header?.displayName == "Ava Updated")
        #expect(state.student?.metadata.recordVersion == 2)
        #expect(router.activeStudentName == "Ava Updated")
        #expect(router.activeStudentRecord == updatedRecord)
    }

    @Test("A stale refresh cannot republish a confirmed archived student")
    func staleRefreshDoesNotRepublishConfirmedArchive() async {
        let refreshGate = StudentDetailAsyncGate()
        let repository = StudentDetailRepositorySpy(
            hubResults: [
                .success(snapshot()),
                .success(snapshot()),
            ],
            archiveResults: [.success(())],
            hubGates: [nil, refreshGate]
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let refresh = Task {
            await state.refresh()
        }
        await waitForHubRequests(2, repository: repository)

        #expect(await state.archive(operationID: UUID()))
        await refreshGate.open()
        await refresh.value

        #expect(state.phase == .idle)
        #expect(state.header == nil)
        #expect(state.student == nil)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
    }

    @Test("Refresh cannot supersede an in-flight confirmed archive")
    func refreshDoesNotSupersedeInFlightArchive() async {
        let archiveGate = StudentDetailAsyncGate()
        let repository = StudentDetailRepositorySpy(
            hubResults: [
                .success(snapshot()),
                .failure(.permissionDenied),
            ],
            archiveResults: [.success(())],
            archiveGate: archiveGate
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let archive = Task {
            await state.archive(operationID: UUID())
        }
        await waitForArchiveRequests(1, repository: repository)

        await state.refresh()
        #expect(await repository.hubRequests == ["student-a"])
        #expect(state.isMutating)
        await archiveGate.open()

        #expect(await archive.value)
        #expect(state.phase == .idle)
        #expect(state.header == nil)
        #expect(state.student == nil)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
    }

    @Test("Archive preserves context on failure and clears it only after confirmation")
    func archiveClearsContextOnlyAfterConfirmation() async throws {
        let failedOperationID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000602"
        )!
        let confirmedOperationID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000603"
        )!
        let repository = StudentDetailRepositorySpy(
            hubResult: .success(snapshot()),
            archiveResults: [
                .failure(.onlineRequired),
                .success(()),
            ]
        )
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        try router.open(record())
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )
        await state.load(studentID: "student-a")

        let firstSucceeded = await state.archive(
            operationID: failedOperationID
        )

        #expect(!firstSucceeded)
        #expect(state.mutationError == .onlineRequired)
        #expect(state.header?.studentID == "student-a")
        #expect(router.path == [.student("student-a")])
        #expect(router.activeStudentRecord == record())

        let secondSucceeded = await state.archive(
            operationID: confirmedOperationID
        )

        #expect(secondSucceeded)
        #expect(
            await repository.archiveRequests == [
                StudentDetailArchiveRequest(
                    id: "student-a",
                    expectedVersion: 1,
                    operationID: failedOperationID
                ),
                StudentDetailArchiveRequest(
                    id: "student-a",
                    expectedVersion: 1,
                    operationID: confirmedOperationID
                ),
            ]
        )
        #expect(state.header == nil)
        #expect(router.path.isEmpty)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
    }

    @Test("Permission denial fails closed and clears active student context")
    func permissionDenialFailsClosed() async {
        let member = membership(role: .teacher)
        let router = AppRouter(policy: AppNavigationPolicy(membership: member))
        #expect(router.setActiveStudent(record()))
        let repository = StudentDetailRepositorySpy(
            hubResult: .failure(.permissionDenied)
        )
        let state = StudentDetailState(
            repository: repository,
            member: member,
            router: router
        )

        await state.load(studentID: "student-a")

        #expect(state.phase == .permissionDenied)
        #expect(state.header == nil)
        #expect(
            state.privateNotes == .unavailable(nextAvailableRelease: 4)
        )
        #expect(
            state.studentReflections == .unavailable(nextAvailableRelease: 4)
        )
        #expect(state.currentSections.isEmpty)
        #expect(state.historySections.isEmpty)
        #expect(router.activeStudentID == nil)
        #expect(router.activeStudentRecord == nil)
    }

    private func makeState(
        repository: StudentDetailRepositorySpy,
        member: MembershipContext? = nil
    ) -> StudentDetailState {
        let member = member ?? membership(role: .teacher)
        return StudentDetailState(
            repository: repository,
            member: member,
            router: AppRouter(policy: AppNavigationPolicy(membership: member))
        )
    }

    private func waitForUpdateRequests(
        _ count: Int,
        repository: StudentDetailRepositorySpy
    ) async {
        for _ in 0..<200 {
            if await repository.updateRequests.count >= count {
                return
            }
            await Task.yield()
        }
    }

    private func waitForHubRequests(
        _ count: Int,
        repository: StudentDetailRepositorySpy
    ) async {
        for _ in 0..<200 {
            if await repository.hubRequests.count >= count {
                return
            }
            await Task.yield()
        }
    }

    private func waitForArchiveRequests(
        _ count: Int,
        repository: StudentDetailRepositorySpy
    ) async {
        for _ in 0..<200 {
            if await repository.archiveRequests.count >= count {
                return
            }
            await Task.yield()
        }
    }

    private func membership(
        role: StaffRole,
        capabilities: Set<Capability> = [],
        assignedStudentIDs: Set<String> = ["student-a"]
    ) -> MembershipContext {
        MembershipContext(
            userID: role == .socialWorker ? "social-worker-a" : "teacher-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assignedStudentIDs,
            isActive: true,
            version: 1
        )
    }

    private func snapshot(
        student: StudentRecord? = nil,
        activePlanStatus: StudentActivePlanStatus = .none,
        lastInteractionAt: Date? = nil,
        collections: StudentDetailCanonicalCollections = .empty,
        source: StudentDetailSource = .server
    ) -> StudentDetailHubSnapshot {
        StudentDetailHubSnapshot(
            student: student ?? record(),
            activePlanStatus: activePlanStatus,
            lastInteractionAt: lastInteractionAt,
            collections: collections,
            source: source
        )
    }

    private func record(
        displayName: String = "Ava Stone",
        assignedMemberIDs: Set<String> = ["teacher-a"],
        recordVersion: Int = 1
    ) -> StudentRecord {
        StudentRecord(
            id: "student-a",
            districtID: "district-a",
            schoolID: "school-a",
            displayName: displayName,
            grade: "7",
            studentIdentifier: "0012",
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800),
            pronouns: "she / her",
            assignedMemberIDs: assignedMemberIDs,
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: recordVersion,
                createdAt: Date(timeIntervalSince1970: 10),
                createdBy: "teacher-a",
                updatedAt: Date(
                    timeIntervalSince1970: Double(recordVersion * 20)
                ),
                updatedBy: "teacher-a"
            )
        )
    }
}

private struct StudentDetailUpdateRequest: Sendable, Equatable {
    let id: String
    let draft: StudentDraft
    let expectedVersion: Int
    let operationID: UUID
}

private struct StudentDetailArchiveRequest: Sendable, Equatable {
    let id: String
    let expectedVersion: Int
    let operationID: UUID
}

private actor StudentDetailRepositorySpy: StudentDetailRepository {
    private var hubResults:
        [Result<StudentDetailHubSnapshot, StudentRepositoryError>]
    private let privateNotesResult:
        Result<
            StudentDetailRelatedRecords<StudentPrivateNoteProjection>,
            StudentRepositoryError
        >
    private let studentReflectionsResult:
        Result<
            StudentDetailRelatedRecords<StudentReflectionProjection>,
            StudentRepositoryError
        >
    private var updateResults:
        [Result<StudentRecord, StudentRepositoryError>]
    private var archiveResults:
        [Result<Void, StudentRepositoryError>]
    private var hubGates: [StudentDetailAsyncGate?]
    private let updateGate: StudentDetailAsyncGate?
    private let archiveGate: StudentDetailAsyncGate?

    private(set) var hubRequests: [String] = []
    private(set) var privateNoteRequests: [String] = []
    private(set) var studentReflectionRequests: [String] = []
    private(set) var updateRequests: [StudentDetailUpdateRequest] = []
    private(set) var archiveRequests: [StudentDetailArchiveRequest] = []

    init(
        hubResult: Result<StudentDetailHubSnapshot, StudentRepositoryError>,
        privateNotesResult:
            Result<
                StudentDetailRelatedRecords<StudentPrivateNoteProjection>,
                StudentRepositoryError
            > = .success(.available([])),
        studentReflectionsResult:
            Result<
                StudentDetailRelatedRecords<StudentReflectionProjection>,
                StudentRepositoryError
            > = .success(.available([])),
        updateResults:
            [Result<StudentRecord, StudentRepositoryError>] = [],
        archiveResults:
            [Result<Void, StudentRepositoryError>] = [],
        hubGates: [StudentDetailAsyncGate?] = [],
        updateGate: StudentDetailAsyncGate? = nil,
        archiveGate: StudentDetailAsyncGate? = nil
    ) {
        self.hubResults = [hubResult]
        self.privateNotesResult = privateNotesResult
        self.studentReflectionsResult = studentReflectionsResult
        self.updateResults = updateResults
        self.archiveResults = archiveResults
        self.hubGates = hubGates
        self.updateGate = updateGate
        self.archiveGate = archiveGate
    }

    init(
        hubResults:
            [Result<StudentDetailHubSnapshot, StudentRepositoryError>],
        privateNotesResult:
            Result<
                StudentDetailRelatedRecords<StudentPrivateNoteProjection>,
                StudentRepositoryError
            > = .success(.available([])),
        studentReflectionsResult:
            Result<
                StudentDetailRelatedRecords<StudentReflectionProjection>,
                StudentRepositoryError
            > = .success(.available([])),
        updateResults:
            [Result<StudentRecord, StudentRepositoryError>] = [],
        archiveResults:
            [Result<Void, StudentRepositoryError>] = [],
        hubGates: [StudentDetailAsyncGate?] = [],
        updateGate: StudentDetailAsyncGate? = nil,
        archiveGate: StudentDetailAsyncGate? = nil
    ) {
        self.hubResults = hubResults
        self.privateNotesResult = privateNotesResult
        self.studentReflectionsResult = studentReflectionsResult
        self.updateResults = updateResults
        self.archiveResults = archiveResults
        self.hubGates = hubGates
        self.updateGate = updateGate
        self.archiveGate = archiveGate
    }

    func hub(
        studentID: String,
        member _: MembershipContext
    ) async throws -> StudentDetailHubSnapshot {
        hubRequests.append(studentID)
        guard !hubResults.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        let result = hubResults.removeFirst()
        if !hubGates.isEmpty, let gate = hubGates.removeFirst() {
            await gate.wait()
        }
        return try result.get()
    }

    func privateNotes(
        studentID: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentPrivateNoteProjection> {
        privateNoteRequests.append(studentID)
        return try privateNotesResult.get()
    }

    func studentReflections(
        studentID: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentReflectionProjection> {
        studentReflectionRequests.append(studentID)
        return try studentReflectionsResult.get()
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        updateRequests.append(
            StudentDetailUpdateRequest(
                id: id,
                draft: draft,
                expectedVersion: expectedVersion,
                operationID: operationID
            )
        )
        if let updateGate {
            await updateGate.wait()
        }
        guard !updateResults.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        return try updateResults.removeFirst().get()
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member _: MembershipContext
    ) async throws {
        archiveRequests.append(
            StudentDetailArchiveRequest(
                id: id,
                expectedVersion: expectedVersion,
                operationID: operationID
            )
        )
        if let archiveGate {
            await archiveGate.wait()
        }
        guard !archiveResults.isEmpty else {
            throw StudentRepositoryError.invalidResponse
        }
        try archiveResults.removeFirst().get()
    }
}

private actor StudentDetailAsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private struct UnusedStudentRepository: StudentRepository {
    func page(
        _: StudentPageRequest,
        member _: MembershipContext
    ) async throws -> StudentPage {
        throw StudentRepositoryError.invalidResponse
    }

    func student(
        id _: String,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidResponse
    }

    func create(
        _: StudentDraft,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidResponse
    }

    func reconcilePendingCreates(
        member _: MembershipContext
    ) async throws -> [StudentRecord] {
        throw StudentRepositoryError.invalidResponse
    }

    func update(
        id _: String,
        draft _: StudentDraft,
        expectedVersion _: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidResponse
    }

    func archive(
        id _: String,
        expectedVersion _: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws {
        throw StudentRepositoryError.invalidResponse
    }
}
