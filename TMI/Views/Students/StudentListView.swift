import SwiftUI

struct StudentListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel

    @State private var state: StudentListState?
    @State private var loadedAuthority: Authority?

    private let memberOverride: MembershipContext?

    init(
        state: StudentListState? = nil,
        member: MembershipContext? = nil
    ) {
        _state = State(initialValue: state)
        _loadedAuthority = State(initialValue: member.map(Authority.init))
        memberOverride = member
    }

    var body: some View {
        Group {
            if let member {
                if let state {
                    StudentRosterContent(state: state, member: member)
                } else {
                    ProgressView("Loading student access…")
                        .tint(TMIColors.teal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("studentRoster.loading")
                }
            } else {
                ContentUnavailableView(
                    "Student Access Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("A verified staff membership is required to view students.")
                )
                .accessibilityIdentifier("studentRoster.permissionDenied")
            }
        }
        .background(TMIColors.background)
        .navigationTitle("Students")
        .task(id: authority) {
            await configureState()
        }
    }

    private var member: MembershipContext? {
        memberOverride ?? authStateModel.currentMembership
    }

    private var authority: Authority? {
        member.map(Authority.init)
    }

    @MainActor
    private func configureState() async {
        guard let member, let authority else {
            state = nil
            loadedAuthority = nil
            return
        }

        if let state {
            if let loadedAuthority, loadedAuthority != authority {
                state.updateMember(member)
            }
        } else {
            state = StudentListState(
                repository: dependencies.studentRepository,
                member: member
            )
        }
        loadedAuthority = authority
        await state?.load()
    }

    private struct Authority: Hashable {
        let userID: String
        let districtID: String
        let membershipVersion: Int

        init(_ member: MembershipContext) {
            userID = member.userID
            districtID = member.districtID
            membershipVersion = member.version
        }
    }
}

private struct StudentRosterContent: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var state: StudentListState
    let member: MembershipContext

    @State private var editor: EditorPresentation?
    @State private var showingFilters = false
    @State private var selectedStudentIDs: Set<String> = []
    @State private var isSelecting = false
    @State private var showingBulkAssignment = false
    @State private var navigationError: String?
    @State private var showingNavigationError = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TMIColors.background.ignoresSafeArea()

                phaseContent(
                    usesGrid: proxy.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("studentRoster.screen")
        .searchable(
            text: $state.searchText,
            placement: .automatic,
            prompt: "Search by student name or identifier"
        )
        .toolbar { rosterToolbar }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                StudentBulkSelectionBar(
                    selectedCount: selectedStudentIDs.count,
                    canAssign: canManageAssignments,
                    assign: { showingBulkAssignment = true },
                    finish: finishSelecting
                )
            }
        }
        .sheet(item: $editor) { presentation in
            NavigationStack {
                editorView(for: presentation)
            }
            .tmiSheetStyle()
        }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                StudentRosterFilterView(
                    filters: state.filters,
                    member: member,
                    records: state.students,
                    apply: applyFilters
                )
            }
            .tmiSheetStyle()
        }
        .sheet(isPresented: $showingBulkAssignment) {
            NavigationStack {
                StudentBulkAssignmentView(
                    selectedCount: selectedStudentIDs.count,
                    isSubmitting: state.isSubmitting,
                    protectedMemberID: member.userID,
                    apply: applyBulkAssignment
                )
            }
            .tmiSheetStyle()
        }
        .alert("Unable to Open Student", isPresented: $showingNavigationError) {
        } message: {
            Text(navigationError ?? "This student record is not available.")
        }
        .onChange(of: state.students) { _, records in
            let visibleIDs = Set(records.map(\.id))
            selectedStudentIDs.formIntersection(visibleIDs)
        }
        .onChange(of: state.phase) { _, phase in
            if phase == .permissionDenied {
                finishSelecting()
                editor = nil
            }
        }
    }

    @ViewBuilder
    private func phaseContent(usesGrid: Bool) -> some View {
        switch state.phase {
        case .idle, .loading:
            ProgressView("Loading students…")
                .tint(TMIColors.teal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("studentRoster.loading")

        case .permissionDenied:
            ContentUnavailableView(
                "Student Access Changed",
                systemImage: "lock.fill",
                description: Text("Your current staff membership does not allow access to this roster.")
            )
            .accessibilityIdentifier("studentRoster.permissionDenied")

        case .empty:
            VStack(spacing: 0) {
                pendingCreateReviewBanner
                emptyContent
            }

        case .loaded:
            rosterWithMutationFeedback(records: state.students, usesGrid: usesGrid)

        case .refreshing:
            VStack(spacing: 0) {
                ProgressView()
                    .tint(TMIColors.teal)
                    .padding(.vertical, TMISpacing.sm)
                    .accessibilityLabel("Refreshing students")
                rosterWithMutationFeedback(records: state.students, usesGrid: usesGrid)
            }

        case .offline:
            VStack(spacing: 0) {
                StudentRosterStatusBanner(
                    title: "Offline — showing saved students",
                    systemImage: "wifi.slash",
                    foreground: TMIColors.infoText,
                    background: TMIColors.infoSurface,
                    identifier: "studentRoster.offline"
                )
                if state.students.isEmpty {
                    ContentUnavailableView(
                        "No Saved Students",
                        systemImage: "tray",
                        description: Text("Reconnect to load this roster.")
                    )
                } else {
                    rosterWithMutationFeedback(records: state.students, usesGrid: usesGrid)
                }
            }

        case .failed(let message):
            if state.students.isEmpty {
                ContentUnavailableView {
                    Label("Couldn’t Load Students", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: refresh)
                        .buttonStyle(.borderedProminent)
                        .tint(TMIColors.teal)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("studentRoster.retry")
                }
                .accessibilityIdentifier("studentRoster.error")
            } else {
                VStack(spacing: 0) {
                    StudentRosterStatusBanner(
                        title: message,
                        systemImage: "exclamationmark.triangle.fill",
                        foreground: TMIColors.errorText,
                        background: TMIColors.errorSurface,
                        identifier: "studentRoster.error"
                    )
                    rosterWithMutationFeedback(records: state.students, usesGrid: usesGrid)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if !state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search
                .accessibilityIdentifier("studentRoster.empty.search")
        } else if state.filters != StudentListFilters() {
            ContentUnavailableView {
                Label("No Students Match These Filters", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Clear the roster filters to see the full authorized list.")
            } actions: {
                Button("Clear Filters") {
                    Task { await state.setFilters(StudentListFilters()) }
                }
                .buttonStyle(.borderedProminent)
                .tint(TMIColors.teal)
                .frame(minHeight: 44)
                .accessibilityIdentifier("studentRoster.empty.clearFilters")
            }
            .accessibilityIdentifier("studentRoster.empty.filters")
        } else {
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "person.3")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityHidden(true)

                Text("No Students Yet")
                    .font(.title2.bold())
                    .foregroundStyle(TMIColors.textPrimary)

                Text("Add the first student record for this roster, or adjust the active filters.")
                    .font(.body)
                    .foregroundStyle(TMIColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)

                if canCreateStudent {
                    Button("Add Student", systemImage: "plus", action: presentCreateEditor)
                        .buttonStyle(.borderedProminent)
                        .tint(TMIColors.teal)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Add first student")
                        .accessibilityIdentifier("studentRoster.empty.addStudent")
                }
            }
            .padding(TMISpacing.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("studentRoster.empty")
        }
    }

    @ViewBuilder
    private func rosterWithMutationFeedback(
        records: [StudentRecord],
        usesGrid: Bool
    ) -> some View {
        VStack(spacing: 0) {
            pendingCreateReviewBanner
            if case nil = editor, let mutationErrorMessage {
                StudentRosterStatusBanner(
                    title: mutationErrorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    foreground: TMIColors.errorText,
                    background: TMIColors.errorSurface,
                    identifier: "studentRoster.mutationError"
                )
            }
            roster(records: records, usesGrid: usesGrid)
        }
    }

    @ViewBuilder
    private var pendingCreateReviewBanner: some View {
        if state.pendingCreateNeedsReview {
            StudentRosterStatusBanner(
                title: "A saved offline student could not be submitted after your access changed. Contact an administrator if the record is still needed.",
                systemImage: "exclamationmark.shield.fill",
                foreground: TMIColors.warningText,
                background: TMIColors.warningSurface,
                identifier: "studentRoster.pendingCreateNeedsReview"
            )
        }
    }

    @ViewBuilder
    private func roster(records: [StudentRecord], usesGrid: Bool) -> some View {
        if usesGrid {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300, maximum: 420))],
                    spacing: TMISpacing.md
                ) {
                    ForEach(records) { record in
                        StudentRosterCard(
                            record: record,
                            isSelected: selectedStudentIDs.contains(record.id),
                            isSelecting: isSelecting,
                            isOffline: state.phase == .offline,
                            canEdit: canEdit(record),
                            open: { open(record) },
                            toggleSelection: { toggleSelection(record.id) },
                            edit: { editor = .edit(record, operationID: UUID()) },
                            archive: { archive(record) }
                        )
                    }
                    paginationProgress
                }
                .padding(TMISpacing.screenPadding)
            }
            .refreshable { await state.refresh() }
        } else {
            List {
                ForEach(records) { record in
                    StudentRosterCard(
                        record: record,
                        isSelected: selectedStudentIDs.contains(record.id),
                        isSelecting: isSelecting,
                        isOffline: state.phase == .offline,
                        canEdit: canEdit(record),
                        open: { open(record) },
                        toggleSelection: { toggleSelection(record.id) },
                        edit: { editor = .edit(record, operationID: UUID()) },
                        archive: { archive(record) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: TMISpacing.xs,
                            leading: TMISpacing.screenPadding,
                            bottom: TMISpacing.xs,
                            trailing: TMISpacing.screenPadding
                        )
                    )
                }
                paginationProgress
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await state.refresh() }
        }
    }

    @ViewBuilder
    private var paginationProgress: some View {
        if state.canLoadNextPage || state.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView()
                    .tint(TMIColors.teal)
                    .accessibilityLabel("Loading more students")
                Spacer()
            }
            .frame(minHeight: 44)
            .task {
                await state.loadNextPage()
            }
        }
    }

    @ToolbarContentBuilder
    private var rosterToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                showingFilters = true
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("studentRoster.filters")

            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Button("Alphabetical") {
                    setSort(.alphabetical)
                }
                .accessibilityAddTraits(state.sort == .alphabetical ? .isSelected : [])

                Button("Recently updated") {
                    setSort(.recentlyUpdated)
                }
                .disabled(nameSearchIsActive)
                .accessibilityAddTraits(state.sort == .recentlyUpdated ? .isSelected : [])
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("studentRoster.sort")

            if canManageAssignments, !state.students.isEmpty {
                Button(
                    isSelecting ? "Done" : "Select",
                    systemImage: isSelecting ? "checkmark.circle" : "checkmark.circle.badge.questionmark",
                    action: toggleSelecting
                )
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("studentRoster.selectStudents")
            }

            if canCreateStudent, state.phase != .permissionDenied {
                Button("Add Student", systemImage: "plus", action: presentCreateEditor)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("studentRoster.addStudent")
            }
        }
    }

    @ViewBuilder
    private func editorView(for presentation: EditorPresentation) -> some View {
        switch presentation {
        case .create(let operationID):
            StudentEditorView(
                mode: .create,
                member: member,
                draft: state.editorDraft(for: .create),
                isSubmitting: state.isSubmitting,
                isQueued: isCreateQueued,
                duplicateCandidateIDs: duplicateCandidateIDs(for: .create),
                submissionError: mutationErrorMessage(for: .create)
            ) { draft in
                let confirmed = await state.create(draft, operationID: operationID)
                if confirmed {
                    return .confirmed
                }
                if case .createQueued = state.mutationError(for: .create) {
                    return .queued
                }
                if case .duplicate = state.mutationError(for: .create) {
                    return .duplicate
                }
                return .failed
            }

        case .edit(let record, let operationID):
            let target = StudentListState.EditorDraftTarget.edit(record.id)
            StudentEditorView(
                mode: .edit(record),
                member: member,
                draft: state.editorDraft(for: target),
                isSubmitting: state.isSubmitting,
                duplicateCandidateIDs: duplicateCandidateIDs(for: target),
                submissionError: mutationErrorMessage(for: target)
            ) { draft in
                let confirmed = await state.update(
                    id: record.id,
                    draft: draft,
                    expectedVersion: record.metadata.recordVersion,
                    operationID: operationID
                )
                if confirmed {
                    return .confirmed
                }
                if case .duplicate = state.mutationError(for: target) {
                    return .duplicate
                }
                return .failed
            }
        }
    }

    private func duplicateCandidateIDs(
        for target: StudentListState.EditorDraftTarget
    ) -> [String] {
        guard case .duplicate(let candidateIDs) = state.mutationError(for: target) else {
            return []
        }
        return candidateIDs
    }

    private var mutationErrorMessage: String? {
        message(for: state.mutationError)
    }

    private var isCreateQueued: Bool {
        guard case .createQueued = state.mutationError(for: .create) else { return false }
        return true
    }

    private func mutationErrorMessage(
        for target: StudentListState.EditorDraftTarget
    ) -> String? {
        message(for: state.mutationError(for: target))
    }

    private func message(for error: StudentRepositoryError?) -> String? {
        guard let error else { return nil }
        switch error {
        case .duplicate:
            return "Review the possible duplicate records before trying again."
        case .versionConflict:
            return "This record changed on the server. Close the editor, refresh, and try again."
        case .createQueued:
            return "This draft is saved on this device and will be submitted after you reconnect."
        case .permissionDenied, .staleMembership:
            return "Your student access changed. Refresh your account before trying again."
        case .onlineRequired:
            return "This action requires an internet connection."
        case .unavailable:
            return "The server is unavailable. Your entries are still in the form."
        case .invalidDraft:
            return "Review the student fields and try again."
        case .idempotencyKeyReused:
            return "This save request can’t be reused. Try saving again."
        case .notFound:
            return "This student record is no longer available."
        case .schoolFilterRequired:
            return "Select a school before continuing."
        case .invalidRequest, .invalidResponse:
            return "The server couldn’t confirm this change. Try again."
        }
    }

    private var canCreateStudent: Bool {
        switch member.role {
        case .teacher, .counselor:
            return !member.schoolIDs.isEmpty
        case .socialWorker:
            return false
        case .schoolAdministrator:
            return member.capabilities.contains(.studentWriteDetail)
                && !member.schoolIDs.isEmpty
        case .districtAdministrator:
            return member.capabilities.contains(.studentWriteDetail)
        }
    }

    private var canManageAssignments: Bool {
        member.capabilities.contains(.staffManage)
            && member.capabilities.contains(.studentWriteDetail)
            && (member.role == .schoolAdministrator || member.role == .districtAdministrator)
            && state.phase != .offline
            && state.phase != .permissionDenied
    }

    private var nameSearchIsActive: Bool {
        let normalized = state.searchText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalized.isEmpty else { return false }
        let isIdentifierLike = !normalized.contains(where: { $0.isWhitespace })
            && normalized.contains(where: { $0.isNumber || "-_/".contains($0) })
        return !isIdentifierLike
    }

    private func canEdit(_ record: StudentRecord) -> Bool {
        AuthorizationPolicy.canWriteStudentDetail(
            member,
            student: StudentAuthorizationScope(
                studentID: record.id,
                districtID: record.districtID,
                schoolID: record.schoolID
            )
        )
    }

    private func presentCreateEditor() {
        editor = .create(operationID: UUID())
    }

    private func open(_ record: StudentRecord) {
        guard !isSelecting else {
            toggleSelection(record.id)
            return
        }

        do {
            try router.open(record)
        } catch {
            navigationError = "Your current access does not allow this student record to open."
            showingNavigationError = true
        }
    }

    private func archive(_ record: StudentRecord) {
        Task {
            let didArchive = await state.archive(
                id: record.id,
                expectedVersion: record.metadata.recordVersion,
                operationID: UUID()
            )
            if didArchive {
                AccessibilityManager.shared.announce(
                    "\(record.displayName) archived.",
                    priority: .high
                )
            }
        }
    }

    private func refresh() {
        Task { await state.refresh() }
    }

    private func setSort(_ sort: StudentRosterSort) {
        Task { await state.setSort(sort) }
    }

    private func applyFilters(_ filters: StudentListFilters) {
        showingFilters = false
        Task { await state.setFilters(filters) }
    }

    private func toggleSelecting() {
        if isSelecting {
            finishSelecting()
        } else {
            isSelecting = true
        }
    }

    private func toggleSelection(_ studentID: String) {
        if selectedStudentIDs.contains(studentID) {
            selectedStudentIDs.remove(studentID)
        } else {
            selectedStudentIDs.insert(studentID)
        }
    }

    private func finishSelecting() {
        isSelecting = false
        selectedStudentIDs.removeAll()
        showingBulkAssignment = false
    }

    @MainActor
    private func applyBulkAssignment(
        memberID: String,
        action: StudentBulkAssignmentView.Action
    ) async -> Bool {
        guard memberID != member.userID else { return false }
        let selectedRecords = state.students.filter { selectedStudentIDs.contains($0.id) }
        guard !selectedRecords.isEmpty else { return false }

        for record in selectedRecords {
            var assignedMemberIDs = record.assignedMemberIDs
            switch action {
            case .assign:
                assignedMemberIDs.insert(memberID)
            case .unassign:
                assignedMemberIDs.remove(memberID)
            }

            let draft = StudentDraft(
                displayName: record.displayName,
                schoolID: record.schoolID,
                grade: record.grade,
                studentIdentifier: record.studentIdentifier,
                dateOfBirth: record.dateOfBirth,
                pronouns: record.pronouns,
                assignedMemberIDs: assignedMemberIDs
            )
            let didUpdate = await state.update(
                id: record.id,
                draft: draft,
                expectedVersion: record.metadata.recordVersion,
                operationID: UUID()
            )
            guard didUpdate else { return false }
        }

        finishSelecting()
        AccessibilityManager.shared.announce("Student assignments updated.", priority: .high)
        return true
    }

    private enum EditorPresentation: Identifiable {
        case create(operationID: UUID)
        case edit(StudentRecord, operationID: UUID)

        var id: String {
            switch self {
            case .create(let operationID):
                "create-\(operationID.uuidString)"
            case .edit(let record, let operationID):
                "edit-\(record.id)-\(operationID.uuidString)"
            }
        }
    }
}

private struct StudentRosterCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: StudentRecord
    let isSelected: Bool
    let isSelecting: Bool
    let isOffline: Bool
    let canEdit: Bool
    let open: () -> Void
    let toggleSelection: () -> Void
    let edit: () -> Void
    let archive: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMISpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: TMISpacing.md))

        layout {
            if isSelecting {
                Button(
                    isSelected ? "Deselect \(record.displayName)" : "Select \(record.displayName)",
                    systemImage: isSelected ? "checkmark.circle.fill" : "circle",
                    action: toggleSelection
                )
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(isSelected ? TMIColors.teal : TMIColors.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("studentRoster.select.\(record.id)")
            }

            Button(action: open) {
                StudentRosterCardLabel(record: record)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint(isSelecting ? "Selects this student" : "Opens the student record")
            .accessibilityIdentifier("studentRoster.student.\(record.id)")

            if !isSelecting, canEdit, !isOffline {
                StudentRosterActionMenu(
                    record: record,
                    edit: edit,
                    archive: archive
                )
            }
        }
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .stroke(
                    isSelected ? TMIColors.teal : TMIColors.interactiveBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }

    private var accessibilitySummary: String {
        var values = [
            record.displayName,
            "grade \(record.grade)",
            "school \(record.schoolID)",
        ]
        if let studentIdentifier = record.studentIdentifier {
            values.append("student identifier \(studentIdentifier)")
        }
        values.append("\(record.assignedMemberIDs.count) assigned staff")
        if record.isArchived {
            values.append("archived")
        }
        return values.joined(separator: ", ")
    }
}

private struct StudentRosterCardLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: StudentRecord

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMISpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: TMISpacing.md))

        layout {
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    Circle().fill(TMIColors.aubergineSoft)
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(TMIColors.aubergine)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: TMISpacing.xs) {
                Text(record.displayName)
                    .font(.headline)
                    .foregroundStyle(TMIColors.textPrimary)
                if record.isArchived {
                    Label("Archived", systemImage: "archivebox.fill")
                        .font(.footnote)
                        .foregroundStyle(TMIColors.warningText)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    Text("Grade: \(record.grade)")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                    Text("School: \(record.schoolID)")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                } else {
                    Text("Grade \(record.grade) • \(record.schoolID)")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }

                if let studentIdentifier = record.studentIdentifier {
                    Text("Student ID: \(studentIdentifier)")
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                }

                Label(
                    "\(record.assignedMemberIDs.count) assigned staff",
                    systemImage: "person.2"
                )
                .font(.footnote)
                .foregroundStyle(TMIColors.infoText)
            }
        }
    }

    private var initials: String {
        record.displayName
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct StudentRosterActionMenu: View {
    let record: StudentRecord
    let edit: () -> Void
    let archive: () -> Void

    @State private var showingArchiveConfirmation = false

    var body: some View {
        Menu("Actions for \(record.displayName)", systemImage: "ellipsis.circle") {
            Button("Edit Student", systemImage: "pencil", action: edit)
                .accessibilityIdentifier("studentRoster.edit.\(record.id)")

            if !record.isArchived {
                Button("Archive Student", systemImage: "archivebox", role: .destructive) {
                    showingArchiveConfirmation = true
                }
                .accessibilityIdentifier("studentRoster.archive.\(record.id)")
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .foregroundStyle(TMIColors.aubergine)
        .frame(minWidth: 44, minHeight: 44)
        .confirmationDialog(
            "Archive \(record.displayName)?",
            isPresented: $showingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Student", role: .destructive, action: archive)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The student will leave the active roster. The institutional record is retained.")
        }
    }
}

private struct StudentRosterStatusBanner: View {
    let title: String
    let systemImage: String
    let foreground: Color
    let background: Color
    let identifier: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, TMISpacing.screenPadding)
            .background(background)
            .accessibilityIdentifier(identifier)
    }
}

private struct StudentRosterFilterView: View {
    @Environment(\.dismiss) private var dismiss

    let member: MembershipContext
    let records: [StudentRecord]
    let apply: (StudentListFilters) -> Void

    @State private var schoolID: String
    @State private var grade: String
    @State private var assignedMemberID: String
    @State private var status: StudentRecordStatusFilter

    init(
        filters: StudentListFilters,
        member: MembershipContext,
        records: [StudentRecord],
        apply: @escaping (StudentListFilters) -> Void
    ) {
        self.member = member
        self.records = records
        self.apply = apply
        _schoolID = State(initialValue: filters.schoolID ?? "")
        _grade = State(initialValue: filters.grade ?? "")
        _assignedMemberID = State(initialValue: filters.assignedMemberID ?? "")
        _status = State(initialValue: filters.status)
    }

    var body: some View {
        Form {
            Section("Roster scope") {
                schoolControl
                TextField("Grade", text: $grade)
                    .accessibilityIdentifier("studentRoster.filter.grade")

                if canFilterByMember {
                    TextField("Assigned staff member ID", text: $assignedMemberID)
                        .accessibilityIdentifier("studentRoster.filter.assignedMember")
                }

                Picker("Record status", selection: $status) {
                    Text("Active").tag(StudentRecordStatusFilter.active)
                    Text("Archived").tag(StudentRecordStatusFilter.archived)
                    Text("All").tag(StudentRecordStatusFilter.all)
                }
                .accessibilityIdentifier("studentRoster.filter.status")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Filter Students")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Clear", action: clear)
                    .accessibilityIdentifier("studentRoster.filter.clear")
                Button("Apply", action: submit)
                    .disabled(!canApply)
                    .accessibilityIdentifier("studentRoster.filter.apply")
            }
        }
    }

    @ViewBuilder
    private var schoolControl: some View {
        let schools = availableSchoolIDs
        if schools.isEmpty {
            TextField("School identifier", text: $schoolID)
                .accessibilityIdentifier("studentRoster.filter.school")
        } else {
            Picker("School", selection: $schoolID) {
                Text("All authorized schools").tag("")
                ForEach(schools, id: \.self) { school in
                    Text(school).tag(school)
                }
            }
            .accessibilityIdentifier("studentRoster.filter.school")
        }
    }

    private var availableSchoolIDs: [String] {
        Set(member.schoolIDs).union(records.map(\.schoolID)).sorted()
    }

    private var canFilterByMember: Bool {
        member.role == .schoolAdministrator || member.role == .districtAdministrator
    }

    private var canApply: Bool {
        guard member.role != .districtAdministrator, member.schoolIDs.count > 1 else {
            return true
        }
        return normalized(schoolID) != nil
    }

    private func clear() {
        schoolID = ""
        grade = ""
        assignedMemberID = ""
        status = .active
    }

    private func submit() {
        apply(
            StudentListFilters(
                schoolID: normalized(schoolID),
                grade: normalized(grade),
                assignedMemberID: canFilterByMember ? normalized(assignedMemberID) : nil,
                status: status
            )
        )
        dismiss()
    }

    private func normalized(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private struct StudentBulkSelectionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedCount: Int
    let canAssign: Bool
    let assign: () -> Void
    let finish: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMISpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: TMISpacing.sm))

        layout {
            Text("\(selectedCount) selected")
                .font(.headline)
                .foregroundStyle(TMIColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Assign Staff", systemImage: "person.badge.plus", action: assign)
                .buttonStyle(.borderedProminent)
                .tint(TMIColors.teal)
                .disabled(selectedCount == 0 || !canAssign)
                .frame(minHeight: 44)
                .accessibilityIdentifier("studentRoster.bulkAssignment")
            Button("Done", action: finish)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.vertical, TMISpacing.sm)
        .background(.regularMaterial)
    }
}

private struct StudentBulkAssignmentView: View {
    enum Action: String, CaseIterable, Identifiable {
        case assign
        case unassign

        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    @Environment(\.dismiss) private var dismiss

    let selectedCount: Int
    let isSubmitting: Bool
    let protectedMemberID: String
    let apply: @MainActor (String, Action) async -> Bool

    @State private var memberID = ""
    @State private var action = Action.assign
    @State private var isAwaitingServer = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Assignment change") {
                LabeledContent("Selected students", value: "\(selectedCount)")
                TextField("Staff member ID", text: $memberID)
                    .accessibilityIdentifier("studentRoster.bulk.memberID")
                Picker("Action", selection: $action) {
                    ForEach(Action.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("studentRoster.bulk.action")

                if isProtectedMember {
                    Label(
                        "Your own roster access can’t be changed in a bulk action.",
                        systemImage: "person.badge.shield.checkmark"
                    )
                    .foregroundStyle(TMIColors.warningText)
                    .accessibilityIdentifier("studentRoster.bulk.protectedMember")
                }
            }

            Section {
                Text("The server confirms each assignment against current district and school access.")
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textSecondary)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(TMIColors.errorText)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Assign Staff")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
                    .disabled(submissionInFlight)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply", action: submit)
                    .disabled(
                        normalizedMemberID == nil
                            || isProtectedMember
                            || submissionInFlight
                    )
                    .accessibilityIdentifier("studentRoster.bulk.apply")
            }
        }
        .interactiveDismissDisabled(submissionInFlight)
    }

    private var submissionInFlight: Bool {
        isSubmitting || isAwaitingServer
    }

    private var normalizedMemberID: String? {
        let value = memberID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, TrustedIdentifier.isValid(value) else { return nil }
        return value
    }

    private var isProtectedMember: Bool {
        normalizedMemberID == protectedMemberID
    }

    private func submit() {
        guard let memberID = normalizedMemberID, !submissionInFlight else { return }
        isAwaitingServer = true
        errorMessage = nil
        Task { @MainActor in
            let didApply = await self.apply(memberID, self.action)
            self.isAwaitingServer = false
            if didApply {
                self.dismiss()
            } else {
                self.errorMessage = "The server did not confirm every assignment. Refresh and try again."
            }
        }
    }
}
