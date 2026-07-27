import Foundation
import Observation

nonisolated enum StudentDetailSource: Sendable, Equatable {
    case server
    case cache
}

nonisolated enum StudentActivePlanStatus: Sendable, Equatable {
    case unavailable
    case none
    case active(count: Int)
}

nonisolated enum StudentModeAvailability: Sendable, Equatable {
    case availableInRelease2
}

nonisolated struct StudentHeaderProjection: Sendable, Equatable {
    let studentID: String
    let displayName: String
    let grade: String
    let schoolID: String
    let assignedStaffCount: Int
    let activePlanStatus: StudentActivePlanStatus
    let lastInteractionAt: Date?
    let studentModeAvailability: StudentModeAvailability
}

nonisolated struct StudentPrivateNoteProjection: Identifiable, Sendable, Equatable {
    let id: String
    let summary: String
    let occurredAt: Date
}

nonisolated struct StudentReflectionProjection: Identifiable, Sendable, Equatable {
    let id: String
    let summary: String
    let occurredAt: Date
}

nonisolated enum StudentDetailRelatedRecords<Record: Sendable & Equatable>:
    Sendable,
    Equatable
{
    case unavailable(nextAvailableRelease: Int)
    case available([Record])

    var records: [Record] {
        switch self {
        case .unavailable:
            []
        case .available(let records):
            records
        }
    }
}

nonisolated enum StudentDetailDomain: String, CaseIterable, Sendable, Hashable {
    case interests
    case surveysAndForms
    case careers
    case resources
    case plans
    case meetingsAndNotes
    case progress

    var title: String {
        switch self {
        case .interests: "Interests"
        case .surveysAndForms: "Surveys & Forms"
        case .careers: "Careers"
        case .resources: "Resources"
        case .plans: "Plans"
        case .meetingsAndNotes: "Meetings & Notes"
        case .progress: "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .interests: "sparkles"
        case .surveysAndForms: "list.clipboard"
        case .careers: "briefcase"
        case .resources: "books.vertical"
        case .plans: "checklist"
        case .meetingsAndNotes: "calendar.badge.clock"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }

    var nextAvailableRelease: Int {
        switch self {
        case .interests, .surveysAndForms, .careers:
            2
        case .resources, .plans, .progress:
            3
        case .meetingsAndNotes:
            4
        }
    }
}

nonisolated struct StudentDetailCanonicalCollections: Sendable, Equatable {
    static let empty = StudentDetailCanonicalCollections()

    let currentItemIDs: [StudentDetailDomain: [String]]
    let historyItemIDs: [StudentDetailDomain: [String]]

    init(
        currentItemIDs: [StudentDetailDomain: [String]] = [:],
        historyItemIDs: [StudentDetailDomain: [String]] = [:]
    ) {
        self.currentItemIDs = currentItemIDs
        self.historyItemIDs = historyItemIDs
    }

    func itemIDs(
        for domain: StudentDetailDomain,
        scope: StudentDetailSectionScope
    ) -> [String] {
        switch scope {
        case .current:
            currentItemIDs[domain] ?? []
        case .history:
            historyItemIDs[domain] ?? []
        }
    }
}

nonisolated enum StudentDetailSectionScope: Sendable, Equatable {
    case current
    case history
}

nonisolated struct StudentDetailEmptyState: Sendable, Equatable {
    let title: String
    let detail: String
    let nextAvailableRelease: Int
}

nonisolated struct StudentDetailSectionProjection: Identifiable, Sendable, Equatable {
    let domain: StudentDetailDomain
    let scope: StudentDetailSectionScope
    let itemIDs: [String]
    let emptyState: StudentDetailEmptyState?

    var id: String {
        "\(domain.rawValue)-\(scope == .current ? "current" : "history")"
    }
}

nonisolated struct StudentDetailHubSnapshot: Sendable, Equatable {
    let student: StudentRecord
    let activePlanStatus: StudentActivePlanStatus
    let lastInteractionAt: Date?
    let collections: StudentDetailCanonicalCollections
    let source: StudentDetailSource
}

nonisolated enum StudentDetailMenuAction: Sendable, Equatable {
    case edit
    case archive
    case delete
}

nonisolated protocol StudentDetailRepository: Sendable {
    func hub(
        studentID: String,
        member: MembershipContext
    ) async throws -> StudentDetailHubSnapshot

    func privateNotes(
        studentID: String,
        member: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentPrivateNoteProjection>

    func studentReflections(
        studentID: String,
        member: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentReflectionProjection>

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

/// Release 1 keeps future student domains behind explicit typed seams. The
/// canonical roster read and mutations are live; later releases replace the
/// unavailable domain projections without changing the detail screen's privacy
/// boundary or navigation contract.
nonisolated struct Release1StudentDetailRepository: StudentDetailRepository {
    private let students: any StudentRepository

    init(students: any StudentRepository) {
        self.students = students
    }

    func hub(
        studentID: String,
        member: MembershipContext
    ) async throws -> StudentDetailHubSnapshot {
        let student = try await students.student(id: studentID, member: member)
        return StudentDetailHubSnapshot(
            student: student,
            activePlanStatus: .unavailable,
            lastInteractionAt: nil,
            collections: .empty,
            source: .server
        )
    }

    func privateNotes(
        studentID _: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentPrivateNoteProjection> {
        .unavailable(nextAvailableRelease: 4)
    }

    func studentReflections(
        studentID _: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentReflectionProjection> {
        .unavailable(nextAvailableRelease: 4)
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        try await students.update(
            id: id,
            draft: draft,
            expectedVersion: expectedVersion,
            operationID: operationID,
            member: member
        )
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        try await students.archive(
            id: id,
            expectedVersion: expectedVersion,
            operationID: operationID,
            member: member
        )
    }
}

@MainActor
@Observable
final class StudentDetailState {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case refreshing
        case offline
        case permissionDenied
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var header: StudentHeaderProjection?
    private(set) var privateNotes:
        StudentDetailRelatedRecords<StudentPrivateNoteProjection> =
            .unavailable(nextAvailableRelease: 4)
    private(set) var studentReflections:
        StudentDetailRelatedRecords<StudentReflectionProjection> =
            .unavailable(nextAvailableRelease: 4)
    private(set) var currentSections: [StudentDetailSectionProjection] = []
    private(set) var historySections: [StudentDetailSectionProjection] = []
    private(set) var menuActions: [StudentDetailMenuAction] = []
    private(set) var mutationError: StudentRepositoryError?
    private(set) var isMutating = false
    private(set) var student: StudentRecord?

    @ObservationIgnored private let repository: any StudentDetailRepository
    @ObservationIgnored private var member: MembershipContext
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private var studentID: String?
    @ObservationIgnored private var snapshot: StudentDetailHubSnapshot?
    @ObservationIgnored private var operationEpoch = 0

    init(
        repository: any StudentDetailRepository,
        member: MembershipContext,
        router: AppRouter
    ) {
        self.repository = repository
        self.member = member
        self.router = router
    }

    func updateMember(_ member: MembershipContext) {
        guard self.member != member else { return }
        operationEpoch += 1
        self.member = member
        clearContent(clearRouter: true)
        phase = .idle
    }

    func load(studentID: String) async {
        guard TrustedIdentifier.isValid(studentID) else {
            failClosed()
            return
        }
        self.studentID = studentID
        await performLoad(studentID: studentID, refreshing: false)
    }

    func refresh() async {
        guard let studentID, !isMutating else { return }
        await performLoad(studentID: studentID, refreshing: true)
    }

    func update(
        _ draft: StudentDraft,
        operationID: UUID
    ) async -> Bool {
        guard phase == .loaded || phase == .refreshing,
              !isMutating,
              let startingStudent = student,
              menuActions.contains(.edit) else {
            return false
        }

        operationEpoch += 1
        let epoch = operationEpoch
        isMutating = true
        mutationError = nil
        updateMenuActions()
        defer {
            if epoch == operationEpoch {
                isMutating = false
                updateMenuActions()
            }
        }

        do {
            let confirmed = try await repository.update(
                id: startingStudent.id,
                draft: draft,
                expectedVersion: startingStudent.metadata.recordVersion,
                operationID: operationID,
                member: member
            )
            guard epoch == operationEpoch else { return false }
            guard confirmed.id == startingStudent.id,
                  confirmed.districtID == member.districtID,
                  confirmed.metadata.recordVersion
                    > startingStudent.metadata.recordVersion,
                  canRead(confirmed),
                  router.setActiveStudent(confirmed) else {
                mutationError = .invalidResponse
                return false
            }

            let updatedSnapshot = StudentDetailHubSnapshot(
                student: confirmed,
                activePlanStatus: snapshot?.activePlanStatus ?? .unavailable,
                lastInteractionAt: snapshot?.lastInteractionAt,
                collections: snapshot?.collections ?? .empty,
                source: .server
            )
            apply(updatedSnapshot)
            phase = .loaded
            return true
        } catch {
            guard epoch == operationEpoch else { return false }
            mutationError = repositoryError(from: error)
            return false
        }
    }

    func archive(operationID: UUID) async -> Bool {
        guard phase == .loaded || phase == .refreshing,
              !isMutating,
              let startingStudent = student,
              menuActions.contains(.archive) else {
            return false
        }

        operationEpoch += 1
        let epoch = operationEpoch
        isMutating = true
        mutationError = nil
        updateMenuActions()
        defer {
            if epoch == operationEpoch {
                isMutating = false
                updateMenuActions()
            }
        }

        do {
            try await repository.archive(
                id: startingStudent.id,
                expectedVersion: startingStudent.metadata.recordVersion,
                operationID: operationID,
                member: member
            )
            guard epoch == operationEpoch else { return false }
            clearContent(clearRouter: false)
            router.popToRoot()
            router.clearActiveStudent()
            phase = .idle
            return true
        } catch {
            guard epoch == operationEpoch else { return false }
            mutationError = repositoryError(from: error)
            return false
        }
    }

    private func performLoad(
        studentID: String,
        refreshing: Bool
    ) async {
        guard !isMutating else { return }
        operationEpoch += 1
        let epoch = operationEpoch
        let minimumAcceptedVersion = student?.id == studentID
            ? student?.metadata.recordVersion
            : nil
        isMutating = false
        phase = refreshing && student != nil ? .refreshing : .loading
        mutationError = nil
        updateMenuActions()

        do {
            let loadedSnapshot = try await repository.hub(
                studentID: studentID,
                member: member
            )
            guard epoch == operationEpoch, !Task.isCancelled else { return }
            guard loadedSnapshot.student.id == studentID,
                  loadedSnapshot.student.districtID == member.districtID,
                  canRead(loadedSnapshot.student) else {
                failClosed()
                return
            }
            if let minimumAcceptedVersion,
               loadedSnapshot.student.metadata.recordVersion
                < minimumAcceptedVersion {
                restoreConfirmedPhase()
                return
            }

            let notes = try await repository.privateNotes(
                studentID: studentID,
                member: member
            )
            guard epoch == operationEpoch, !Task.isCancelled else { return }
            let reflections = try await repository.studentReflections(
                studentID: studentID,
                member: member
            )
            guard epoch == operationEpoch, !Task.isCancelled else { return }

            guard router.setActiveStudent(loadedSnapshot.student) else {
                failClosed()
                return
            }
            apply(loadedSnapshot)
            privateNotes = notes
            studentReflections = reflections
            phase = loadedSnapshot.source == .cache ? .offline : .loaded
            updateMenuActions()
        } catch is CancellationError {
            return
        } catch {
            guard epoch == operationEpoch else { return }
            handleLoadError(error, refreshing: refreshing)
        }
    }

    private func restoreConfirmedPhase() {
        phase = snapshot?.source == .cache ? .offline : .loaded
        updateMenuActions()
    }

    private func apply(_ snapshot: StudentDetailHubSnapshot) {
        self.snapshot = snapshot
        student = snapshot.student
        header = StudentHeaderProjection(
            studentID: snapshot.student.id,
            displayName: snapshot.student.displayName,
            grade: snapshot.student.grade,
            schoolID: snapshot.student.schoolID,
            assignedStaffCount: snapshot.student.assignedMemberIDs.count,
            activePlanStatus: snapshot.activePlanStatus,
            lastInteractionAt: snapshot.lastInteractionAt,
            studentModeAvailability: .availableInRelease2
        )
        currentSections = sections(
            from: snapshot.collections,
            scope: .current
        )
        historySections = sections(
            from: snapshot.collections,
            scope: .history
        )
        updateMenuActions()
    }

    private func sections(
        from collections: StudentDetailCanonicalCollections,
        scope: StudentDetailSectionScope
    ) -> [StudentDetailSectionProjection] {
        StudentDetailDomain.allCases.map { domain in
            let itemIDs = collections.itemIDs(for: domain, scope: scope)
            return StudentDetailSectionProjection(
                domain: domain,
                scope: scope,
                itemIDs: itemIDs,
                emptyState: itemIDs.isEmpty
                    ? emptyState(for: domain, scope: scope)
                    : nil
            )
        }
    }

    private func emptyState(
        for domain: StudentDetailDomain,
        scope: StudentDetailSectionScope
    ) -> StudentDetailEmptyState {
        let timeFrame = scope == .current ? "current" : "historical"
        return StudentDetailEmptyState(
            title: "No \(timeFrame) \(domain.title.lowercased()) available",
            detail: emptyStateDetail(for: domain, scope: scope),
            nextAvailableRelease: domain.nextAvailableRelease
        )
    }

    private func emptyStateDetail(
        for domain: StudentDetailDomain,
        scope: StudentDetailSectionScope
    ) -> String {
        let availability = "This area becomes available in Release \(domain.nextAvailableRelease)."
        switch scope {
        case .current:
            return "\(availability) Until then, use the verified student profile and assigned team to prepare the next step."
        case .history:
            return "\(availability) Confirmed prior records will appear here without replacing completed work."
        }
    }

    private func updateMenuActions() {
        guard phase == .loaded || phase == .refreshing,
              !isMutating,
              let student,
              !student.isArchived,
              canWrite(student) else {
            menuActions = []
            return
        }

        var actions: [StudentDetailMenuAction] = [.edit, .archive]
        if canDelete(student) {
            actions.append(.delete)
        }
        menuActions = actions
    }

    private func handleLoadError(
        _ error: any Error,
        refreshing: Bool
    ) {
        let repositoryError = repositoryError(from: error)
        switch repositoryError {
        case .permissionDenied, .staleMembership:
            failClosed()
        case .unavailable where refreshing && student != nil:
            phase = .offline
            menuActions = []
        case .notFound:
            clearContent(clearRouter: true)
            phase = .failed("This student record is no longer available.")
        default:
            if student != nil {
                phase = .failed("Some student details could not be refreshed. Try again.")
                menuActions = []
            } else {
                clearContent(clearRouter: true)
                phase = .failed("Unable to load this student. Try again.")
            }
        }
    }

    private func failClosed() {
        operationEpoch += 1
        clearContent(clearRouter: true)
        phase = .permissionDenied
    }

    private func clearContent(clearRouter: Bool) {
        snapshot = nil
        student = nil
        header = nil
        privateNotes = .unavailable(nextAvailableRelease: 4)
        studentReflections = .unavailable(nextAvailableRelease: 4)
        currentSections = []
        historySections = []
        menuActions = []
        mutationError = nil
        isMutating = false
        if clearRouter {
            router.clearActiveStudent()
        }
    }

    private func canRead(_ student: StudentRecord) -> Bool {
        guard let scope = StudentAuthorizationScope(record: student) else {
            return false
        }
        return AuthorizationPolicy.canReadStudentDetail(member, student: scope)
    }

    private func canWrite(_ student: StudentRecord) -> Bool {
        guard let scope = StudentAuthorizationScope(record: student) else {
            return false
        }
        return AuthorizationPolicy.canWriteStudentDetail(member, student: scope)
    }

    private func canDelete(_ student: StudentRecord) -> Bool {
        guard let scope = StudentAuthorizationScope(record: student) else {
            return false
        }
        return AuthorizationPolicy.canDeleteStudent(member, student: scope)
    }

    private func repositoryError(from error: any Error) -> StudentRepositoryError {
        error as? StudentRepositoryError ?? .invalidResponse
    }
}
