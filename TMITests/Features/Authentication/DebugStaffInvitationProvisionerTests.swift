import Foundation
import Testing
@testable import TMI

#if DEBUG
@Suite("Debug staff invitation provisioning")
@MainActor
struct DebugStaffInvitationProvisionerTests {
    @Test("Debug Firebase identity authorizes without Firestore profile or membership documents")
    func debugIdentityAuthorizesWithoutFirestoreDocuments() async {
        let eligibilityStore = DebugIdentityEligibilityStore()
        let identity = AuthenticatedIdentity(
            userID: "debug-user",
            email: DebugStaffInvitationProvisioner.allowedEmail,
            isEmailVerified: false
        )
        let identityProvider = DebugAuthenticationIdentityProvider(
            delegate: RecordingAuthenticationIdentityProvider(identity: identity),
            eligibilityStore: eligibilityStore
        )
        let profileProvider = DebugUserProfileProvider(
            delegate: MissingUserProfileProvider()
        )
        let membershipProvider = DebugMembershipProvider(
            delegate: MissingMembershipProvider(),
            eligibilityStore: eligibilityStore
        )
        let model = AuthStateModel(
            identityProvider: identityProvider,
            profileProvider: profileProvider,
            membershipProvider: membershipProvider,
            featureFlags: .production,
            automaticallyStart: false
        )

        await model.fetch()

        #expect(model.isLoggedIn)
        #expect(model.authenticatedSession?.profile.userID == identity.userID)
        #expect(
            model.authenticatedSession?.membership
                == DebugStaffInvitationProvisioner.membership(userID: identity.userID)
        )
    }

    @Test("A non-Debug identity with Debug-shaped claims still delegates membership")
    func nonDebugIdentityWithDebugClaimDelegatesMembership() async throws {
        let eligibilityStore = DebugIdentityEligibilityStore()
        let identityProvider = DebugAuthenticationIdentityProvider(
            delegate: RecordingAuthenticationIdentityProvider(
                identity: AuthenticatedIdentity(
                    userID: "other-user",
                    email: "other@example.com",
                    isEmailVerified: true
                )
            ),
            eligibilityStore: eligibilityStore
        )
        let delegate = RecordingMembershipProvider()
        let membershipProvider = DebugMembershipProvider(
            delegate: delegate,
            eligibilityStore: eligibilityStore
        )
        let identity = AuthenticatedIdentity(
            userID: "other-user",
            email: "other@example.com",
            isEmailVerified: true
        )
        _ = try? await identityProvider.trustedClaim(for: identity)
        let claim = DebugAuthenticationIdentityProvider.claim(userID: identity.userID)

        let membership = try await membershipProvider.membership(for: claim)

        #expect(membership == delegate.membership)
        #expect(await delegate.callCount == 1)
    }

    @Test("Debug staff roster is locally usable without trusted Firestore claims")
    func debugStaffRosterUsesLocalStorage() async throws {
        let membership = DebugStaffInvitationProvisioner.membership(userID: "debug-user")
        // Isolate the durable roster per run so leftover on-disk records from
        // prior test invocations cannot leak into this expectation.
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-roster-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let repository = DebugStudentRepository(
            delegate: UnavailableStudentRepository(),
            persistence: .file(url: fileURL)
        )
        let draft = StudentDraft(
            displayName: "Jordan Lee",
            schoolID: DebugStaffInvitationProvisioner.schoolID,
            grade: "8",
            studentIdentifier: "S-100",
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: [membership.userID]
        )

        let created = try await repository.create(
            draft,
            operationID: UUID(),
            member: membership
        )
        let page = try await repository.page(.first, member: membership)

        #expect(page.records == [created])
        #expect(page.nextCursor == nil)
        // A durable local roster is authoritative for the Debug tenant, so it is
        // reported as a live source rather than a stale offline cache.
        #expect(page.source == .server)
    }

    @Test("Debug roster survives relaunch and reports a live source")
    func debugStaffRosterPersistsAcrossInstances() async throws {
        let membership = DebugStaffInvitationProvisioner.membership(userID: "debug-user")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-roster-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let persistence = DebugStudentPersistence.file(url: fileURL)
        let draft = StudentDraft(
            displayName: "Jordan Lee",
            schoolID: DebugStaffInvitationProvisioner.schoolID,
            grade: "8",
            studentIdentifier: "S-100",
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: [membership.userID]
        )

        let firstLaunch = DebugStudentRepository(
            delegate: UnavailableStudentRepository(),
            persistence: persistence
        )
        let created = try await firstLaunch.create(
            draft,
            operationID: UUID(),
            member: membership
        )

        // A fresh repository instance simulates the app being rebuilt/relaunched.
        let secondLaunch = DebugStudentRepository(
            delegate: UnavailableStudentRepository(),
            persistence: persistence
        )
        let page = try await secondLaunch.page(.first, member: membership)

        #expect(page.records == [created])
        #expect(page.source == .server)
    }

    @Test("Dashboard uses the injected Debug roster repository")
    func dashboardUsesInjectedDebugRoster() async {
        let membership = DebugStaffInvitationProvisioner.membership(userID: "debug-user")
        // Isolate the durable roster per run so a clean store yields zero students.
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-roster-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let repository = DebugStudentRepository(
            delegate: UnavailableStudentRepository(),
            persistence: .file(url: fileURL)
        )
        let model = DashboardStateModel(studentRepository: repository)

        await model.fetchWithMembership(membership)

        #expect(model.value?.totalStudents == 0)
        #expect(model.hasError == false)
    }

    @Test("Debug staff plans are locally usable without Firestore membership documents")
    func debugStaffPlansUseLocalStorage() async throws {
        let membership = DebugStaffInvitationProvisioner.membership(userID: "debug-user")
        let store = DebugPlanStore()
        let plans = DebugPlanRepository(
            delegate: UnavailableDebugPlanRepository(),
            store: store
        )
        let children = DebugPlanChildRepository(
            delegate: UnavailableDebugPlanChildRepository(),
            store: store
        )
        let draft = PlanCreation.draft(
            studentID: "student-debug",
            schoolID: DebugStaffInvitationProvisioner.schoolID,
            member: membership,
            model: .chaseYourSpace,
            title: "Chase Your Space",
            summary: "Build a reliable routine.",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            targetDate: nil
        )

        #expect(try await plans.plans(member: membership).isEmpty)

        let created = try await plans.create(
            draft,
            operationID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            member: membership
        )
        let loaded = try await plans.plan(id: created.id, member: membership)
        let listed = try await plans.plans(member: membership)

        #expect(loaded == created)
        #expect(listed == [created])
        #expect(try await children.goals(planID: created.id, member: membership).isEmpty)
        #expect(try await children.actions(planID: created.id, member: membership).isEmpty)
        #expect(try await children.progress(planID: created.id, member: membership).isEmpty)
        #expect(try await children.revisions(planID: created.id, member: membership).isEmpty)
    }

    @Test("Debug plan wrappers still delegate ordinary memberships")
    func debugPlanWrappersDelegateOrdinaryMemberships() async throws {
        let store = DebugPlanStore()
        let planDelegate = RecordingDebugPlanRepository()
        let childDelegate = RecordingDebugPlanChildRepository()
        let plans = DebugPlanRepository(delegate: planDelegate, store: store)
        let children = DebugPlanChildRepository(delegate: childDelegate, store: store)
        let membership = planDelegate.membership

        let listed = try await plans.plans(member: membership)
        let goals = try await children.goals(planID: planDelegate.record.id, member: membership)

        #expect(listed == [planDelegate.record])
        #expect(goals.isEmpty)
        #expect(planDelegate.planListCallCount == 1)
        #expect(childDelegate.goalReadCallCount == 1)
    }

    @Test("The Debug alias and allowed email synthesize canonical membership")
    func aliasSynthesizesMembershipForAllowedEmail() async throws {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: " \nTMI-DEBUG@Example.COM\t ",
            isEmailVerified: true
        )
        let request = StaffInvitationAcceptanceRequest(
            displayName: "Morgan Lee",
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: "privacy-v3",
            acceptableUsePolicyVersion: "aup-v4"
        )

        let membership = try await provisioner.provision(
            request: request,
            identity: identity
        )

        #expect(
            membership == MembershipContext(
                userID: identity.userID,
                districtID: "district-debug",
                schoolIDs: ["school-debug"],
                role: .teacher,
                capabilities: [.studentReadDetail, .studentWriteDetail],
                assignedStudentIDs: [],
                isActive: true,
                version: 1
            )
        )
        #expect(delegate.provisionCallCount == 0)
    }

    @Test("Canonical Debug provisioning does not require trusted claim refresh")
    func canonicalDebugProvisioningSkipsTrustedClaimRefresh() {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: " TMI-DEBUG@Example.COM ",
            isEmailVerified: true
        )

        #expect(
            provisioner.requiresTrustedClaimRefresh(
                request: self.aliasRequest,
                identity: identity
            ) == false
        )
        #expect(
            provisioner.requiresTrustedClaimRefresh(
                request: StaffInvitationAcceptanceRequest(
                    displayName: "Morgan Lee",
                    invitationCode: "ordinary-opaque-invitation",
                    privacyPolicyVersion: "privacy-v3",
                    acceptableUsePolicyVersion: "aup-v4"
                ),
                identity: identity
            )
        )
    }

    @Test("The Debug session loader synthesizes an authorized canonical session")
    func sessionLoaderSynthesizesCanonicalSession() async throws {
        let delegate = RecordingAuthenticationSessionLoader()
        let loader = DebugAuthenticationSessionLoader(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-1",
            email: "\nTMI-DEBUG@Example.COM\t",
            isEmailVerified: false
        )

        let session = try await loader.session(for: identity)

        #expect(session.access(requiringEmailVerification: false) == .authorized)
        #expect(
            session.identity == AuthIdentity(
                userID: identity.userID,
                email: identity.email,
                isEmailVerified: false,
                districtID: "district-debug"
            )
        )
        #expect(session.membership == DebugStaffInvitationProvisioner.membership(for: identity))
        #expect(delegate.sessionCallCount == 0)
    }

    @Test("The Debug session loader delegates other identities unchanged")
    func sessionLoaderDelegatesOtherIdentities() async throws {
        let delegate = RecordingAuthenticationSessionLoader()
        let loader = DebugAuthenticationSessionLoader(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-5",
            email: "other@example.com",
            isEmailVerified: true,
            districtID: "district-a"
        )

        let session = try await loader.session(for: identity)

        #expect(session == delegate.session)
        #expect(delegate.sessionCallCount == 1)
        #expect(delegate.lastIdentity == identity)
    }

    @Test("The Debug alias provisions any email and remembers it for later sessions")
    func aliasProvisionsAnyEmail() async throws {
        DebugStaffAccessRegistry.reset()
        defer { DebugStaffAccessRegistry.reset() }
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let identity = AuthIdentity(
            userID: "staff-2",
            email: "Other@Example.com",
            isEmailVerified: true
        )

        #expect(DebugStaffAccessRegistry.contains("other@example.com") == false)

        let membership = try await provisioner.provision(
            request: self.aliasRequest,
            identity: identity
        )

        #expect(membership.districtID == DebugStaffInvitationProvisioner.districtID)
        #expect(membership.userID == "staff-2")
        #expect(delegate.provisionCallCount == 0)
        // Recorded so relaunch and sign-in resolve the same synthetic membership.
        #expect(DebugStaffAccessRegistry.contains("other@example.com"))
        #expect(DebugStaffInvitationProvisioner.isAllowed(identity: identity))
    }

    @Test("An account that never redeemed the Debug alias is not treated as Debug staff")
    func unregisteredEmailIsNotDebugStaff() {
        DebugStaffAccessRegistry.reset()
        defer { DebugStaffAccessRegistry.reset() }

        #expect(
            DebugStaffInvitationProvisioner.isAllowed(
                identity: AuthIdentity(
                    userID: "staff-9",
                    email: "real.staff@district.example",
                    isEmailVerified: true
                )
            ) == false
        )
    }

    @Test("The Debug alias rejects a missing email without delegation")
    func aliasRejectsMissingEmail() async {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)

        await #expect(throws: DebugStaffInvitationError.emailNotAllowed) {
            _ = try await provisioner.provision(
                request: self.aliasRequest,
                identity: AuthIdentity(
                    userID: "staff-3",
                    isEmailVerified: true
                )
            )
        }
        #expect(delegate.provisionCallCount == 0)
    }

    @Test("A non-alias invitation delegates the request and identity unchanged")
    func nonAliasDelegatesUnchanged() async throws {
        let delegate = RecordingStaffInvitationProvisioner()
        let provisioner = DebugStaffInvitationProvisioner(delegate: delegate)
        let request = StaffInvitationAcceptanceRequest(
            displayName: "Taylor Kim",
            invitationCode: "ordinary-opaque-invitation",
            privacyPolicyVersion: "privacy-v5",
            acceptableUsePolicyVersion: "aup-v6"
        )
        let identity = AuthIdentity(
            userID: "staff-4",
            isEmailVerified: false,
            districtID: "district-a"
        )

        let membership = try await provisioner.provision(
            request: request,
            identity: identity
        )

        #expect(membership == delegate.membership)
        #expect(delegate.provisionCallCount == 1)
        #expect(delegate.lastRequest == request)
        #expect(delegate.lastIdentity == identity)
    }

    private var aliasRequest: StaffInvitationAcceptanceRequest {
        StaffInvitationAcceptanceRequest(
            displayName: "Morgan Lee",
            invitationCode: DebugStaffInvitationProvisioner.invitationAlias,
            privacyPolicyVersion: "privacy-v3",
            acceptableUsePolicyVersion: "aup-v4"
        )
    }
}

@MainActor
private final class RecordingStaffInvitationProvisioner: StaffInvitationProvisioning {
    let membership = MembershipContext(
        userID: "staff-1",
        districtID: "district-a",
        schoolIDs: ["school-a"],
        role: .teacher,
        capabilities: [.studentReadDetail],
        assignedStudentIDs: ["student-a"],
        isActive: true,
        version: 1
    )
    private(set) var provisionCallCount = 0
    private(set) var lastRequest: StaffInvitationAcceptanceRequest?
    private(set) var lastIdentity: AuthIdentity?

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        provisionCallCount += 1
        lastRequest = request
        lastIdentity = identity
        return membership
    }
}

@MainActor
private final class RecordingAuthenticationSessionLoader: AuthenticationSessionLoading {
    let session = AuthSession(
        identity: AuthIdentity(
            userID: "delegate-user",
            isEmailVerified: true,
            districtID: "delegate-district"
        ),
        membership: nil
    )
    private(set) var sessionCallCount = 0
    private(set) var lastIdentity: AuthIdentity?

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        sessionCallCount += 1
        lastIdentity = identity
        return session
    }
}

@MainActor
private final class RecordingAuthenticationIdentityProvider: AuthenticationIdentityProviding {
    let currentIdentity: AuthenticatedIdentity?

    init(identity: AuthenticatedIdentity) {
        currentIdentity = identity
    }

    func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim {
        throw TrustedTenantClaimError.missing
    }

    func addStateDidChangeListener(
        _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
    ) -> AuthStateListenerHandle {
        AuthStateListenerHandle(removalOperation: {})
    }
}

private struct MissingUserProfileProvider: UserProfileProviding {
    func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
        nil
    }
}

private struct MissingMembershipProvider: MembershipProviding {
    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        throw MembershipRepositoryError.notFound
    }
}

private actor RecordingMembershipProvider: MembershipProviding {
    let membership = MembershipContext(
        userID: "delegate-user",
        districtID: "delegate-district",
        schoolIDs: ["delegate-school"],
        role: .teacher,
        capabilities: [.studentReadDetail],
        assignedStudentIDs: [],
        isActive: true,
        version: 1
    )
    private(set) var callCount = 0

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        callCount += 1
        return membership
    }
}

@MainActor
private final class UnavailableDebugPlanRepository: PlanRecordRepository {
    func plans(member: MembershipContext) async throws -> [PlanRecord] {
        throw PlanRecordRepositoryError.unavailable
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }
}

@MainActor
private final class UnavailableDebugPlanChildRepository: PlanChildRepositoryProtocol {
    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        throw PlanRecordRepositoryError.unavailable
    }

    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] {
        throw PlanRecordRepositoryError.unavailable
    }

    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] {
        throw PlanRecordRepositoryError.unavailable
    }

    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] {
        throw PlanRecordRepositoryError.unavailable
    }

    func save(goal: GoalRecord, member: MembershipContext) async throws {
        throw PlanRecordRepositoryError.unavailable
    }

    func save(action: ActionRecord, member: MembershipContext) async throws {
        throw PlanRecordRepositoryError.unavailable
    }

    func append(progress: ProgressRecord, member: MembershipContext) async throws {
        throw PlanRecordRepositoryError.unavailable
    }

    func freeze(revision: PlanRevision, member: MembershipContext) async throws {
        throw PlanRecordRepositoryError.unavailable
    }
}

@MainActor
private final class RecordingDebugPlanRepository: PlanRecordRepository {
    let membership = MembershipContext(
        userID: "ordinary-user",
        districtID: "ordinary-district",
        schoolIDs: ["ordinary-school"],
        role: .teacher,
        capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: [],
        isActive: true,
        version: 1
    )
    let record = PlanRecord(
        id: "ordinary-plan",
        districtID: "ordinary-district",
        studentIDs: ["ordinary-student"],
        schoolIDs: ["ordinary-school"],
        assignedMemberIDs: ["ordinary-user"],
        status: .draft,
        model: .chaseYourSpace,
        title: "Ordinary Plan",
        summary: nil,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        targetDate: nil,
        approvalStatus: .notRequested,
        metadata: CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdBy: "ordinary-user",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedBy: "ordinary-user"
        )
    )
    private(set) var planListCallCount = 0

    func plans(member: MembershipContext) async throws -> [PlanRecord] {
        planListCallCount += 1
        return [record]
    }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { record }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord { record }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord { record }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord { record }
}

@MainActor
private final class RecordingDebugPlanChildRepository: PlanChildRepositoryProtocol {
    private(set) var goalReadCallCount = 0

    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] {
        goalReadCallCount += 1
        return []
    }

    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { [] }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { [] }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] { [] }
    func save(goal: GoalRecord, member: MembershipContext) async throws {}
    func save(action: ActionRecord, member: MembershipContext) async throws {}
    func append(progress: ProgressRecord, member: MembershipContext) async throws {}
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {}
}
#endif
