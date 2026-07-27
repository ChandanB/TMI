import Foundation
import Observation

nonisolated struct StudentListFilters: Sendable, Equatable {
    var schoolID: String?
    var grade: String?
    var assignedMemberID: String?
    var status: StudentRecordStatusFilter

    init(
        schoolID: String? = nil,
        grade: String? = nil,
        assignedMemberID: String? = nil,
        status: StudentRecordStatusFilter = .active
    ) {
        self.schoolID = schoolID
        self.grade = grade
        self.assignedMemberID = assignedMemberID
        self.status = status
    }
}

@MainActor
@Observable
final class StudentListState {
    enum Phase: Equatable {
        case idle
        case loading
        case empty
        case loaded
        case refreshing
        case offline
        case permissionDenied
        case failed(String)
    }

    enum MutationConfirmation: Equatable {
        case created(StudentRecord)
        case updated(StudentRecord)
        case archived(String)
    }

    enum EditorDraftTarget: Hashable {
        case create
        case edit(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var students: [StudentRecord] = []
    var searchText = "" {
        didSet {
            guard searchText != oldValue, !isResettingAuthority else { return }
            scheduleSearch()
        }
    }
    var filters = StudentListFilters()
    var sort: StudentRosterSort = .alphabetical
    private(set) var isLoadingNextPage = false
    private(set) var isSubmitting = false
    private(set) var mutationError: StudentRepositoryError?
    private(set) var lastConfirmedMutation: MutationConfirmation?
    private(set) var pendingCreateNeedsReview = false

    var canLoadNextPage: Bool {
        nextCursor != nil && !isLoadingPage
    }

    var query: StudentPageRequest {
        makeRequest(cursor: nil)
    }

    @ObservationIgnored private let repository: any StudentRepository
    @ObservationIgnored private let debounceDuration: Duration
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var member: MembershipContext
    @ObservationIgnored private var nextCursor: StudentPageCursor?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var isLoadingPage = false
    @ObservationIgnored private var authorityGeneration = 0
    @ObservationIgnored private var queryGeneration = 0
    @ObservationIgnored private var isResettingAuthority = false
    @ObservationIgnored private var activeFirstPageRequest: StudentPageRequest?
    @ObservationIgnored private var activeMutationToken: UUID?
    @ObservationIgnored private var mutationSequence = 0
    @ObservationIgnored private var mutationErrorTarget: EditorDraftTarget?
    @ObservationIgnored private var editorDrafts: [EditorDraftTarget: StudentDraft] = [:]

    init(
        repository: any StudentRepository,
        member: MembershipContext,
        debounceDuration: Duration = .milliseconds(300),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.repository = repository
        self.member = member
        self.debounceDuration = debounceDuration
        self.sleep = sleep
    }

    func updateMember(_ member: MembershipContext) {
        guard self.member != member else { return }
        authorityGeneration += 1
        queryGeneration += 1
        searchTask?.cancel()
        searchTask = nil
        self.member = member
        nextCursor = nil
        isLoadingPage = false
        isLoadingNextPage = false
        activeFirstPageRequest = nil
        activeMutationToken = nil
        isSubmitting = false
        students = []
        editorDrafts.removeAll()
        mutationError = nil
        mutationErrorTarget = nil
        lastConfirmedMutation = nil
        pendingCreateNeedsReview = false
        isResettingAuthority = true
        searchText = ""
        filters = StudentListFilters()
        sort = .alphabetical
        isResettingAuthority = false
        phase = .idle
    }

    func load() async {
        await loadFirstPage(
            phase: .loading,
            clearExisting: true,
            reconcilePendingCreates: true
        )
    }

    func refresh() async {
        await loadFirstPage(
            phase: .refreshing,
            clearExisting: false,
            reconcilePendingCreates: true
        )
    }

    func loadNextPage() async {
        guard let cursor = nextCursor, !isLoadingPage else { return }
        let authority = authorityGeneration
        let query = queryGeneration
        isLoadingPage = true
        isLoadingNextPage = true
        defer {
            if authority == authorityGeneration, query == queryGeneration {
                isLoadingPage = false
                isLoadingNextPage = false
            }
        }

        do {
            let page = try await repository.page(
                makeRequest(cursor: cursor),
                member: member
            )
            guard authority == authorityGeneration,
                  query == queryGeneration,
                  !Task.isCancelled else {
                return
            }
            merge(page.records)
            nextCursor = page.nextCursor
            phase = page.source == .cache ? .offline : phaseForCurrentRecords()
        } catch is CancellationError {
            return
        } catch {
            guard authority == authorityGeneration, query == queryGeneration else { return }
            handleLoadError(error, preserveRecords: true)
        }
    }

    func setFilters(_ filters: StudentListFilters) async {
        self.filters = filters
        await loadFirstPage(
            phase: .loading,
            clearExisting: true,
            reconcilePendingCreates: false
        )
    }

    func setSort(_ sort: StudentRosterSort) async {
        self.sort = effectiveSort(sort, search: searchText)
        await loadFirstPage(
            phase: .loading,
            clearExisting: true,
            reconcilePendingCreates: false
        )
    }

    func editorDraft(for target: EditorDraftTarget) -> StudentDraft? {
        editorDrafts[target]
    }

    func mutationError(for target: EditorDraftTarget) -> StudentRepositoryError? {
        mutationErrorTarget == target ? mutationError : nil
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID
    ) async -> Bool {
        let target = EditorDraftTarget.create
        guard let submission = beginSubmission(draft: draft, target: target) else {
            return false
        }
        defer { finishSubmission(submission) }
        do {
            let record = try await repository.create(
                draft,
                operationID: operationID,
                member: submission.member
            )
            guard accepts(submission, confirmedRecord: record) else { return false }
            upsert(record)
            nextCursor = nil
            editorDrafts[target] = nil
            mutationError = nil
            mutationErrorTarget = nil
            pendingCreateNeedsReview = false
            lastConfirmedMutation = .created(record)
            phase = phaseAfterConfirmedMutation()
            return true
        } catch {
            guard isCurrent(submission) else { return false }
            mutationError = repositoryError(from: error)
            mutationErrorTarget = target
            return false
        }
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID
    ) async -> Bool {
        let target = EditorDraftTarget.edit(id)
        guard let submission = beginSubmission(draft: draft, target: target) else {
            return false
        }
        defer { finishSubmission(submission) }
        do {
            let record = try await repository.update(
                id: id,
                draft: draft,
                expectedVersion: expectedVersion,
                operationID: operationID,
                member: submission.member
            )
            guard accepts(submission, confirmedRecord: record) else { return false }
            upsert(record)
            nextCursor = nil
            editorDrafts[target] = nil
            mutationError = nil
            mutationErrorTarget = nil
            lastConfirmedMutation = .updated(record)
            phase = phaseAfterConfirmedMutation()
            return true
        } catch {
            guard isCurrent(submission) else { return false }
            mutationError = repositoryError(from: error)
            mutationErrorTarget = target
            return false
        }
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID
    ) async -> Bool {
        let recordBeforeArchive = students.first { $0.id == id }
        guard let submission = beginSubmission() else { return false }
        mutationError = nil
        mutationErrorTarget = nil
        lastConfirmedMutation = nil
        defer { finishSubmission(submission) }
        do {
            try await repository.archive(
                id: id,
                expectedVersion: expectedVersion,
                operationID: operationID,
                member: submission.member
            )
            guard accepts(submission, confirmedRecord: recordBeforeArchive) else {
                return false
            }
            students.removeAll { $0.id == id }
            nextCursor = nil
            lastConfirmedMutation = .archived(id)
            phase = phaseAfterConfirmedMutation()
            return true
        } catch {
            guard isCurrent(submission) else { return false }
            mutationError = repositoryError(from: error)
            return false
        }
    }

    private func loadFirstPage(
        phase loadingPhase: Phase,
        clearExisting: Bool,
        reconcilePendingCreates shouldReconcilePendingCreates: Bool
    ) async {
        let request = query
        if isLoadingPage, activeFirstPageRequest == request {
            return
        }

        queryGeneration += 1
        let authority = authorityGeneration
        let query = queryGeneration
        let authorityMember = member
        isLoadingPage = true
        isLoadingNextPage = false
        activeFirstPageRequest = request
        phase = loadingPhase
        if clearExisting {
            students = []
            nextCursor = nil
        }
        defer {
            if authority == authorityGeneration, query == queryGeneration {
                isLoadingPage = false
                activeFirstPageRequest = nil
            }
        }

        do {
            let reconciled: [StudentRecord]
            if shouldReconcilePendingCreates {
                reconciled = try await reconcilePendingCreates(member: authorityMember)
            } else {
                reconciled = []
            }
            let page = try await repository.page(request, member: authorityMember)
            guard authority == authorityGeneration,
                  query == queryGeneration,
                  !Task.isCancelled else {
                return
            }
            students = page.records
            merge(reconciled)
            if !reconciled.isEmpty,
               mutationErrorTarget == .create,
               case .createQueued = mutationError {
                editorDrafts[.create] = nil
                mutationError = nil
                mutationErrorTarget = nil
                pendingCreateNeedsReview = false
            }
            nextCursor = page.nextCursor
            phase = page.source == .cache ? .offline : phaseForCurrentRecords()
        } catch is CancellationError {
            guard authority == authorityGeneration, query == queryGeneration else { return }
            phase = phaseForCurrentRecords()
        } catch {
            guard authority == authorityGeneration, query == queryGeneration else { return }
            handleLoadError(error, preserveRecords: !clearExisting)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let generation = authorityGeneration
        let duration = debounceDuration
        let sleep = sleep
        searchTask = Task { [weak self] in
            do {
                try await sleep(duration)
                try Task.checkCancellation()
            } catch {
                return
            }
            guard let self, self.authorityGeneration == generation else { return }
            self.sort = self.effectiveSort(self.sort, search: self.searchText)
            await self.loadFirstPage(
                phase: .loading,
                clearExisting: true,
                reconcilePendingCreates: false
            )
        }
    }

    private func makeRequest(cursor: StudentPageCursor?) -> StudentPageRequest {
        StudentPageRequest(
            search: searchText,
            schoolID: filters.schoolID,
            grade: filters.grade,
            assignedMemberID: filters.assignedMemberID,
            status: filters.status,
            sort: effectiveSort(sort, search: searchText),
            cursor: cursor
        )
    }

    private func effectiveSort(
        _ proposed: StudentRosterSort,
        search: String
    ) -> StudentRosterSort {
        if proposed == .recentlyUpdated, Self.isNamePrefixSearch(search) {
            .alphabetical
        } else {
            proposed
        }
    }

    private static func isNamePrefixSearch(_ value: String) -> Bool {
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !normalized.isEmpty else { return false }
        let isIdentifierLike = !normalized.contains(where: { $0.isWhitespace })
            && normalized.contains(where: { $0.isNumber || "-_/".contains($0) })
        return !isIdentifierLike
    }

    private func merge(_ records: [StudentRecord]) {
        for record in records {
            upsert(record)
        }
    }

    private func upsert(_ record: StudentRecord) {
        if let index = students.firstIndex(where: { $0.id == record.id }) {
            students[index] = record
        } else {
            students.append(record)
        }
    }

    private func reconcilePendingCreates(
        member: MembershipContext
    ) async throws -> [StudentRecord] {
        do {
            return try await repository.reconcilePendingCreates(member: member)
        } catch let error as StudentRepositoryError {
            switch error {
            case .permissionDenied, .staleMembership:
                quarantineStalePendingCreate()
                return []
            default:
                return []
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return []
        }
    }

    private struct Submission {
        let token: UUID
        let sequence: Int
        let authorityGeneration: Int
        let member: MembershipContext
    }

    private func beginSubmission(
        draft: StudentDraft? = nil,
        target: EditorDraftTarget? = nil
    ) -> Submission? {
        guard !isSubmitting else { return nil }
        mutationSequence += 1
        let submission = Submission(
            token: UUID(),
            sequence: mutationSequence,
            authorityGeneration: authorityGeneration,
            member: member
        )
        isSubmitting = true
        activeMutationToken = submission.token
        if let draft, let target {
            editorDrafts[target] = draft
        }
        mutationError = nil
        mutationErrorTarget = target
        lastConfirmedMutation = nil
        return submission
    }

    private func isCurrent(_ submission: Submission) -> Bool {
        activeMutationToken == submission.token
            && authorityGeneration == submission.authorityGeneration
    }

    private func accepts(
        _ submission: Submission,
        confirmedRecord: StudentRecord?
    ) -> Bool {
        if isCurrent(submission) {
            return true
        }

        guard activeMutationToken == nil,
              mutationSequence == submission.sequence,
              authorityGeneration > submission.authorityGeneration,
              member.userID == submission.member.userID,
              member.districtID == submission.member.districtID,
              member.isActive,
              member.version >= submission.member.version,
              let confirmedRecord,
              let scope = StudentAuthorizationScope(record: confirmedRecord) else {
            return false
        }
        return AuthorizationPolicy.canReadStudentDetail(member, student: scope)
    }

    private func quarantineStalePendingCreate() {
        if mutationErrorTarget == .create,
           case .createQueued = mutationError {
            editorDrafts[.create] = nil
            mutationError = nil
            mutationErrorTarget = nil
        }
        pendingCreateNeedsReview = true
    }

    private func finishSubmission(_ submission: Submission) {
        guard activeMutationToken == submission.token else { return }
        activeMutationToken = nil
        isSubmitting = false
    }

    private func phaseForCurrentRecords() -> Phase {
        students.isEmpty ? .empty : .loaded
    }

    private func phaseAfterConfirmedMutation() -> Phase {
        phaseForCurrentRecords()
    }

    private func handleLoadError(
        _ error: any Error,
        preserveRecords: Bool
    ) {
        let error = repositoryError(from: error)
        switch error {
        case .permissionDenied, .staleMembership:
            students = []
            nextCursor = nil
            phase = .permissionDenied
        case .schoolFilterRequired:
            if !preserveRecords {
                students = []
                nextCursor = nil
            }
            phase = .failed("Choose a school to view students.")
        case .invalidRequest:
            if !preserveRecords {
                students = []
                nextCursor = nil
            }
            phase = .failed("The student list request is invalid.")
        default:
            if !preserveRecords {
                students = []
                nextCursor = nil
            }
            phase = .failed("Unable to load students. Try again.")
        }
    }

    private func repositoryError(from error: any Error) -> StudentRepositoryError {
        error as? StudentRepositoryError ?? .invalidResponse
    }
}
