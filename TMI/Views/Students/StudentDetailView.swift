import SwiftUI

struct StudentDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentModeSession) private var studentModeSession
    @Environment(AppRouter.self) private var router

    let studentID: String

    @State private var state: StudentDetailState?
    @State private var loadedAuthority: Authority?
    @State private var selectedDestination: StudentHubDestination = .overview
    @State private var showingEditor = false
    @State private var showingStudentModeLaunch = false

    private let memberOverride: MembershipContext?

    init(
        studentID: String,
        member: MembershipContext? = nil
    ) {
        self.studentID = studentID
        self.memberOverride = member
        _loadedAuthority = State(initialValue: member.map(Authority.init))
    }

    var body: some View {
        Group {
            if member == nil {
                permissionUnavailable
            } else if let state {
                StudentOperationalHubContent(
                    state: state,
                    selectedDestination: $selectedDestination,
                    edit: { showingEditor = true },
                    archive: {
                        Task { @MainActor in
                            _ = await state.archive(operationID: UUID())
                        }
                    },
                    launchStudentMode: {
                        showingStudentModeLaunch = true
                    },
                    member: member
                )
            } else {
                ProgressView("Loading student access…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("studentDetail.loading")
            }
        }
        .background(TMIColors.background)
        .navigationTitle(state?.header?.displayName ?? "Student")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authority) {
            await configureState()
        }
        .sheet(isPresented: $showingEditor) {
            if let state,
               let member,
               let student = state.student {
                NavigationStack {
                    StudentEditorView(
                        mode: .edit(student),
                        member: member,
                        isSubmitting: state.isMutating,
                        duplicateCandidateIDs: duplicateCandidateIDs,
                        submissionError: mutationErrorMessage
                    ) { draft in
                        let succeeded = await state.update(
                            draft,
                            operationID: UUID()
                        )
                        if succeeded {
                            return .confirmed
                        }
                        if case .duplicate(let candidateIDs) = state.mutationError {
                            return .duplicate(candidateIDs: candidateIDs)
                        }
                        return .failed
                    }
                }
                .tmiSheetStyle()
            } else {
                StudentSheetUnavailableView(title: "Editing unavailable")
            }
        }
        .sheet(isPresented: $showingStudentModeLaunch) {
            if let state,
               let student = state.student,
               let member,
               let repository = dependencies.studentModeRepository {
                StudentModeLaunchView(
                    student: student,
                    member: member,
                    repository: repository,
                    session: studentModeSession
                )
                .tmiSheetStyle()
            } else {
                StudentSheetUnavailableView(title: "Student Mode unavailable")
            }
        }
    }

    private var member: MembershipContext? {
        memberOverride ?? authStateModel.currentMembership
    }

    private var authority: Authority? {
        member.map(Authority.init)
    }

    private var duplicateCandidateIDs: [String] {
        guard case .duplicate(let candidateIDs) = state?.mutationError else {
            return []
        }
        return candidateIDs
    }

    private var mutationErrorMessage: String? {
        guard let error = state?.mutationError else { return nil }
        switch error {
        case .duplicate:
            return "A possible duplicate needs review before this update can be saved."
        case .versionConflict:
            return "This record changed on the server. Close the editor, refresh, and review the latest version."
        case .onlineRequired, .unavailable:
            return "This change requires a connection. Your current record has not been changed."
        case .permissionDenied, .staleMembership:
            return "Your current staff access does not allow this change."
        default:
            return "The update was not confirmed. Review the fields and try again."
        }
    }

    private var permissionUnavailable: some View {
        ContentUnavailableView(
            "Student Access Unavailable",
            systemImage: "lock.fill",
            description: Text(
                "A verified staff membership is required to open this student record."
            )
        )
        .accessibilityIdentifier("studentDetail.permissionDenied")
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
            state = StudentDetailState(
                repository: dependencies.studentDetailRepository,
                member: member,
                router: router
            )
        }
        loadedAuthority = authority
        await state?.load(studentID: studentID)
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

private struct StudentOperationalHubContent: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.programContext) private var programContext
    @Bindable var state: StudentDetailState
    @Binding var selectedDestination: StudentHubDestination

    let edit: () -> Void
    let archive: () -> Void
    let launchStudentMode: () -> Void
    let member: MembershipContext?

    @State private var showingPlanEditor = false
    @State private var planCreatedMessage: String?
    /// Approved interests drive career matching; an empty list means nothing
    /// has been approved yet, which the discovery view says plainly.
    @State private var careerInterests: [StudentInterest] = []
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    private var usesWideLayout: Bool {
#if os(macOS)
        true
#else
        horizontalSizeClass == .regular
#endif
    }

    var body: some View {
        ZStack {
            TMIColors.background.ignoresSafeArea()

            phaseContent
        }
        .accessibilityIdentifier("studentDetail.screen")
#if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await state.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh this record (⌘R)")
            }
        }
#endif
        .sheet(isPresented: $showingPlanEditor) {
            if let member, let header = state.header {
                CanonicalPlanEditorView(
                    studentID: header.studentID,
                    studentName: header.displayName,
                    schoolID: header.schoolID,
                    member: member,
                    onCreated: { record in
                        planCreatedMessage =
                            "Created \(record.title) as a \(record.status.displayName.lowercased())."
                        selectedDestination = .domain(.plans)
                        Task { await state.refresh() }
                    }
                )
            }
        }
        .refreshable {
            await state.refresh()
        }
        .task(id: state.header?.studentID) {
            guard let student = state.student else { return }
            careerInterests = (try? await StudentInterestService.shared.getStudentInterests(
                districtID: student.districtID,
                studentID: student.id
            )) ?? []
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .idle, .loading:
            ProgressView("Loading student…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("studentDetail.loading")

        case .permissionDenied:
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityHidden(true)
                Text("Student Access Changed")
                    .font(.title2.bold())
                    .foregroundStyle(TMIColors.textPrimary)
                    .accessibilityIdentifier("studentDetail.permissionDenied")
                Text(
                    "Your current staff membership no longer allows access to this student."
                )
                .font(.body)
                .foregroundStyle(TMIColors.textSecondary)
                .multilineTextAlignment(.center)
            }
            .padding(TMISpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message) where state.header == nil:
            ContentUnavailableView {
                Label("Student Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { @MainActor in
                        await state.refresh()
                    }
                }
                .buttonStyle(.tmiPrimary)
            }
            .accessibilityIdentifier("studentDetail.failed")

        case .loaded, .refreshing, .offline, .failed:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TMISpacing.lg) {
                statusBanner

                if let header = state.header {
                    StudentHeaderView(
                        header: header,
                        isOffline: state.phase == .offline,
                        isMutating: state.isMutating,
                        onEdit: state.menuActions.contains(.edit) ? edit : nil,
                        onArchive: state.menuActions.contains(.archive)
                            ? archive
                            : nil,
                        // Offer Student Mode only when this build can run it;
                        // otherwise the button would open an empty sheet.
                        onLaunchStudentMode: dependencies.studentModeRepository == nil
                            ? nil
                            : launchStudentMode
                    )
                }

                if usesWideLayout {
                    HStack(alignment: .top, spacing: TMISpacing.lg) {
                        sectionRail
                            .frame(width: 220)
                        selectedContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    destinationPicker
                    selectedContent
                }
            }
            .frame(maxWidth: TMISizing.maxContentWidth, alignment: .leading)
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.md)
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.selection, trigger: selectedDestination)
    }

    /// iPad and Mac: a System Settings–style section list beside the content.
    private var sectionRail: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(StudentHubDestination.destinations(for: programProfile)) { destination in
                let isSelected = selectedDestination == destination
                Button {
                    selectedDestination = destination
                } label: {
                    HStack(spacing: TMISpacing.ms) {
                        TMIIconTile(destination.systemImage, tone: isSelected ? .brand : .neutral, size: 26)
                        Text(destination.title(for: programProfile))
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(TMIColors.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, TMISpacing.sm)
                    .padding(.vertical, 6)
                    .background(isSelected ? TMIColors.selection : Color.clear, in: TMIShape.control)
                    .contentShape(TMIShape.control)
                }
                .buttonStyle(.tmiPressable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("studentDetail.destination.\(destination.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Student detail sections")
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch state.phase {
        case .refreshing:
            StudentDetailStatusBanner(
                title: "Refreshing student details",
                systemImage: "arrow.clockwise",
                foreground: TMIColors.infoText,
                background: TMIColors.infoSurface,
                showsProgress: true
            )
        case .offline:
            StudentDetailStatusBanner(
                title: "Offline — showing the last confirmed student details",
                systemImage: "wifi.slash",
                foreground: TMIColors.infoText,
                background: TMIColors.infoSurface
            )
            .accessibilityIdentifier("studentDetail.offline")
        case .failed(let message):
            StudentDetailStatusBanner(
                title: message,
                systemImage: "exclamationmark.triangle",
                foreground: TMIColors.errorText,
                background: TMIColors.errorSurface
            )
            .accessibilityIdentifier("studentDetail.partialFailure")
        default:
            EmptyView()
        }

        if let mutationError = state.mutationError {
            StudentDetailStatusBanner(
                title: mutationMessage(for: mutationError),
                systemImage: "exclamationmark.triangle",
                foreground: TMIColors.errorText,
                background: TMIColors.errorSurface
            )
            .accessibilityIdentifier("studentDetail.mutationError")
        }
    }

    private var programProfile: ProgramProfile {
        programContext.profile(forSchoolID: state.header?.schoolID ?? state.student?.schoolID)
    }

    private var destinationPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: TMISpacing.sm) {
                ForEach(StudentHubDestination.destinations(for: programProfile)) { destination in
                    Button {
                        selectedDestination = destination
                    } label: {
                        Label(destination.title(for: programProfile), systemImage: destination.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, TMISpacing.ms + 2)
                            .padding(.vertical, 8)
                            .foregroundStyle(
                                selectedDestination == destination
                                    ? TMIColors.accent
                                    : TMIColors.textPrimary
                            )
                            .background(
                                selectedDestination == destination
                                    ? TMIColors.accentSoft
                                    : TMIColors.fill,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        selectedDestination == destination
                                            ? TMIColors.accent.opacity(0.35)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            }
                            .frame(minHeight: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selectedDestination == destination ? .isSelected : []
                    )
                    .accessibilityIdentifier(
                        "studentDetail.destination.\(destination.id)"
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Student detail sections")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedDestination {
        case .overview:
            StudentOverviewSection(
                header: state.header,
                currentSections: state.currentSections,
                member: member,
                planCreatedMessage: planCreatedMessage,
                onStartPlan: { showingPlanEditor = true },
                onOpen: { domain in selectedDestination = .domain(domain) }
            )
        case .domain(let domain):
            if domain == .interests, let student = state.student {
                StudentInterestsSection(
                    districtID: student.districtID,
                    studentID: student.id,
                    schoolID: student.schoolID,
                    studentName: student.displayName
                )
            } else if domain == .careers, let student = state.student {
                // Matching is a claim about this student, so it is read where
                // the student is, not from a global explorer.
                StudentCareerDiscoveryView(
                    studentID: student.id,
                    studentName: student.displayName,
                    approvedInterests: careerInterests,
                    clusters: [],
                    member: member,
                    relationshipRepository: dependencies.careerRelationshipRepository
                )
            } else if domain == .plans, let student = state.student, let member,
                      let repository = dependencies.planRepository {
                CanonicalPlanListView(
                    state: CanonicalPlanListState(
                        repository: repository,
                        studentRepository: dependencies.studentRepository,
                        children: dependencies.planChildRepository,
                        studentID: student.id
                    ),
                    member: member,
                    embedded: true
                )
                    .id(student.id)
            } else if domain == .resources, let student = state.student, let member,
                      let repository = dependencies.resourceRepository {
                StudentResourceListSection(
                    studentID: student.id,
                    member: member,
                    repository: repository
                )
                .id(student.id)
            } else if domain == .resources {
                ContentUnavailableView(
                    "Resources unavailable",
                    systemImage: "books.vertical",
                    description: Text("Resource assignment requires a verified staff membership.")
                )
            } else if domain == .surveysAndForms, let student = state.student {
                VStack(alignment: .leading, spacing: TMISpacing.lg) {
                    StudentFormsSection(
                        districtID: student.districtID,
                        studentID: student.id,
                        studentName: student.displayName
                    )
                    StudentDomainSection(
                        domain: domain,
                        current: state.currentSections.first { $0.domain == domain },
                        history: state.historySections.first { $0.domain == domain }
                    )
                }
            } else if domain == .meetingsAndNotes, let student = state.student {
                VStack(alignment: .leading, spacing: TMISpacing.lg) {
                    // Private notes and student reflections from the record
                    // itself, kept visibly distinct (previously unreachable).
                    StudentTimelineView(
                        privateNotes: state.privateNotes,
                        studentReflections: state.studentReflections
                    )

                    StudentMeetingsSection(studentID: student.id)

                    StudentTasksSection(
                        districtID: student.districtID,
                        studentID: student.id,
                        studentName: student.displayName,
                        member: member
                    )

                    StudentNotesSection(
                        districtID: student.districtID,
                        studentID: student.id,
                        member: member
                    )
                }
            } else if domain == .meetingsAndNotes {
                StudentTimelineView(
                    privateNotes: state.privateNotes,
                    studentReflections: state.studentReflections
                )
            } else {
                StudentDomainSection(
                    domain: domain,
                    current: state.currentSections.first { $0.domain == domain },
                    history: state.historySections.first { $0.domain == domain }
                )
            }
        }
    }

    private func mutationMessage(for error: StudentRepositoryError) -> String {
        switch error {
        case .onlineRequired, .unavailable:
            "This action requires a connection. No confirmed student data was changed."
        case .versionConflict:
            "The student changed on the server. Refresh before trying again."
        case .permissionDenied, .staleMembership:
            "Your current staff access does not allow this action."
        case .duplicate:
            "A possible duplicate requires review."
        default:
            "The action was not confirmed. Try again."
        }
    }
}

private enum StudentHubDestination: Hashable, Identifiable, CaseIterable {
    case overview
    case domain(StudentDetailDomain)

    static let allCases: [StudentHubDestination] = [
        .overview,
        .domain(.interests),
        .domain(.surveysAndForms),
        .domain(.careers),
        .domain(.resources),
        .domain(.plans),
        .domain(.meetingsAndNotes),
        .domain(.progress),
    ]

    var id: String {
        switch self {
        case .overview: "overview"
        case .domain(let domain): domain.rawValue
        }
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .domain(let domain): domain.title
        }
    }

    /// Early-childhood hubs have no career exploration, and discovery is
    /// observation and family input rather than student surveys.
    static func destinations(for profile: ProgramProfile) -> [StudentHubDestination] {
        allCases.filter { destination in
            destination != .domain(.careers) || profile.showsCareers
        }
    }

    func title(for profile: ProgramProfile) -> String {
        if !profile.learnerSelfReports, self == .domain(.surveysAndForms) {
            return "Observations & Forms"
        }
        return title
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .domain(let domain): domain.systemImage
        }
    }
}

private struct StudentOverviewSection: View {
    @Environment(\.programContext) private var programContext
    let header: StudentHeaderProjection?
    let currentSections: [StudentDetailSectionProjection]
    var member: MembershipContext?
    var planCreatedMessage: String?
    var onStartPlan: () -> Void = {}
    var onOpen: (StudentDetailDomain) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            TMIGoldenHourCard {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Label("Next step", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TMIColors.surface.opacity(0.55), in: Capsule())
                    Text(planCreatedMessage ?? planStatus)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        programProfile.showsCareers
                            ? "Review the verified profile and assigned team, then explore this student's interests, careers, plans, and resources."
                            : "Review the child's profile and care team, record what you observe them enjoying, invite the family's input, then build a plan."
                    )
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.goldenHourSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    if canStartPlan {
                        Button("Start a TMI plan", systemImage: "plus.circle") {
                            onStartPlan()
                        }
                        .buttonStyle(.tmiPrimary)
                        .padding(.top, TMISpacing.xs)
                        .accessibilityIdentifier("studentDetail.startPlan")
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: TMISpacing.ms)],
                spacing: TMISpacing.ms
            ) {
                ForEach(visibleSections) { section in
                    Button {
                        onOpen(section.domain)
                    } label: {
                    HStack(alignment: .top, spacing: TMISpacing.ms) {
                        TMIIconTile(section.domain.systemImage, tone: section.itemIDs.isEmpty ? .neutral : .brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.domain.title)
                                .font(.headline)
                                .foregroundStyle(TMIColors.textPrimary)
                            Text(sectionSummary(section))
                                .font(.subheadline)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TMIColors.textTertiary)
                    }
                    .tmiSurface(padding: TMISpacing.md)
                    }
                    .buttonStyle(.tmiPressable)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(
                        "studentDetail.overview.\(section.domain.rawValue)"
                    )
                }
            }
        }
        .accessibilityIdentifier("studentDetail.overview")
    }

    private var programProfile: ProgramProfile {
        programContext.profile(forSchoolID: header?.schoolID)
    }

    /// Early-childhood sites have no careers, so their card is hidden too.
    private var visibleSections: [StudentDetailSectionProjection] {
        currentSections.filter { $0.domain != .careers || programProfile.showsCareers }
    }

    /// Creating a plan writes to the district, so it needs the same authority
    /// the roster write requires.
    private var canStartPlan: Bool {
        guard let member, header != nil else { return false }
        return PlanCreation.isAvailable(to: member)
    }

    private var planStatus: String {
        guard let activePlanStatus = header?.activePlanStatus else {
            return "Plan status becomes available with the verified plan workflow."
        }
        return switch activePlanStatus {
        case .active(let count):
            "\(count) active \(count == 1 ? "plan" : "plans")"
        case .none:
            "No active plan is recorded."
        case .unavailable:
            "Plan status becomes available with the verified plan workflow."
        }
    }

    private func sectionSummary(
        _ section: StudentDetailSectionProjection
    ) -> String {
        if section.itemIDs.isEmpty {
            return "Open to review"
        }
        return "\(section.itemIDs.count) confirmed \(section.itemIDs.count == 1 ? "record" : "records")"
    }
}

private struct StudentDomainSection: View {
    let domain: StudentDetailDomain
    let current: StudentDetailSectionProjection?
    let history: StudentDetailSectionProjection?

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text(domain.title)
                .font(.tmiHeading2)
                .foregroundStyle(TMIColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            StudentDomainCollectionCard(
                title: "Current",
                projection: current,
                identifier: "studentDetail.\(domain.rawValue).current"
            )
            StudentDomainCollectionCard(
                title: "History",
                projection: history,
                identifier: "studentDetail.\(domain.rawValue).history"
            )
        }
        .accessibilityIdentifier("studentDetail.domain.\(domain.rawValue)")
    }
}

private struct StudentDomainCollectionCard: View {
    let title: String
    let projection: StudentDetailSectionProjection?
    let identifier: String

    var body: some View {
        TMICard(style: .outlined) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Text(title)
                    .tmiEyebrow()

                if let projection, !projection.itemIDs.isEmpty {
                    Label(
                        "\(projection.itemIDs.count) confirmed \(projection.itemIDs.count == 1 ? "record" : "records")",
                        systemImage: "checkmark.seal"
                    )
                    .foregroundStyle(TMIColors.successText)
                } else if let emptyState = projection?.emptyState {
                    ContentUnavailableView(
                        emptyState.title,
                        systemImage: projection?.domain.systemImage ?? "tray",
                        description: Text(emptyState.detail)
                    )
                } else {
                    ContentUnavailableView(
                        "Section unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Refresh the student record and try again.")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct StudentDetailStatusBanner: View {
    let title: String
    let systemImage: String
    let foreground: Color
    let background: Color
    var showsProgress = false

    var body: some View {
        HStack(spacing: TMISpacing.sm) {
            if showsProgress {
                ProgressView()
                    .tint(foreground)
            } else {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, TMISpacing.md)
        .padding(.vertical, TMISpacing.ms)
        .background(background, in: TMIShape.control)
        .accessibilityElement(children: .combine)
    }
}

/// Shown instead of an empty sheet when the record a sheet needs has gone away
/// (for example after access changed while the sheet was opening).
private struct StudentSheetUnavailableView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("Refresh the student record and try again.")
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
