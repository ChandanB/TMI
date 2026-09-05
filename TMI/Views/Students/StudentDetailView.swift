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
                    .tint(TMIColors.teal)
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

    var body: some View {
        ZStack {
            TMIColors.background.ignoresSafeArea()

            phaseContent
        }
        .accessibilityIdentifier("studentDetail.screen")
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
                .tint(TMIColors.teal)
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
                .buttonStyle(.borderedProminent)
                .tint(TMIColors.teal)
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
                        onLaunchStudentMode: launchStudentMode
                    )
                }

                destinationPicker
                selectedContent
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(TMISpacing.lg)
            .frame(maxWidth: .infinity)
        }
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

    private var destinationPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: TMISpacing.sm) {
                ForEach(StudentHubDestination.allCases) { destination in
                    Button {
                        selectedDestination = destination
                    } label: {
                        Label(destination.title, systemImage: destination.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, TMISpacing.md)
                            .frame(minHeight: 44)
                            .foregroundStyle(
                                selectedDestination == destination
                                    ? TMIColors.tealForeground
                                    : TMIColors.textPrimary
                            )
                            .background(
                                selectedDestination == destination
                                    ? TMIColors.teal
                                    : TMIColors.surface
                            )
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(
                                        selectedDestination == destination
                                            ? TMIColors.teal
                                            : TMIColors.interactiveBorder,
                                        lineWidth: 1
                                    )
                            }
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
                onStartPlan: { showingPlanEditor = true }
            )
        case .domain(let domain):
            if domain == .interests, let student = state.student {
                StudentInterestsSection(
                    districtID: student.districtID,
                    studentID: student.id
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
                CanonicalPlanListView(state: CanonicalPlanListState(repository: repository, studentID: student.id), member: member, embedded: true)
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

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .domain(let domain): domain.systemImage
        }
    }
}

private struct StudentOverviewSection: View {
    let header: StudentHeaderProjection?
    let currentSections: [StudentDetailSectionProjection]
    var member: MembershipContext?
    var planCreatedMessage: String?
    var onStartPlan: () -> Void = {}

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 260), spacing: TMISpacing.md)],
            spacing: TMISpacing.md
        ) {
            TMICard(style: .outlined, accentColor: TMIColors.teal) {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Label("Next step", systemImage: "arrow.forward.circle")
                        .font(.headline)
                        .foregroundStyle(TMIColors.aubergine)
                    Text(
                        "Review the verified profile and assigned team. Discovery activities become available in the next release."
                    )
                    .font(.body)
                    .foregroundStyle(TMIColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TMICard(style: .outlined, accentColor: TMIColors.aubergine) {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Label("Plan status", systemImage: "checklist")
                        .font(.headline)
                        .foregroundStyle(TMIColors.aubergine)
                    Text(planCreatedMessage ?? planStatus)
                        .font(.body)
                        .foregroundStyle(
                            planCreatedMessage == nil
                                ? TMIColors.textSecondary
                                : TMIColors.successText
                        )
                    if canStartPlan {
                        Button("Start a TMI plan", systemImage: "plus.circle") {
                            onStartPlan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TMIColors.aubergine)
                        .accessibilityIdentifier("studentDetail.startPlan")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(currentSections) { section in
                TMICard(style: .outlined) {
                    HStack(alignment: .top, spacing: TMISpacing.md) {
                        Image(systemName: section.domain.systemImage)
                            .font(.title2)
                            .foregroundStyle(TMIColors.teal)
                            .frame(width: 32)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: TMISpacing.xs) {
                            Text(section.domain.title)
                                .font(.headline)
                                .foregroundStyle(TMIColors.textPrimary)
                            Text(sectionSummary(section))
                                .font(.subheadline)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier(
                    "studentDetail.overview.\(section.domain.rawValue)"
                )
            }
        }
        .accessibilityIdentifier("studentDetail.overview")
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
            return "Planned for Release \(section.domain.nextAvailableRelease)."
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
                .font(.title2.bold())
                .foregroundStyle(TMIColors.textPrimary)

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
                    .font(.headline)
                    .foregroundStyle(TMIColors.aubergine)

                if let projection, !projection.itemIDs.isEmpty {
                    Label(
                        "\(projection.itemIDs.count) confirmed \(projection.itemIDs.count == 1 ? "record" : "records")",
                        systemImage: "checkmark.seal"
                    )
                    .foregroundStyle(TMIColors.teal)
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
        .padding(TMISpacing.md)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
