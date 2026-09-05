import FirebaseFirestore
import Foundation
import SwiftUI

nonisolated struct AppDependencies: Sendable {
    enum Runtime: Sendable, Equatable {
        case production
        case preview
        case unconfigured
    }

    let runtime: Runtime
    let flags: FeatureFlags
    let membership: any MembershipProviding
    let authentication: (any AuthenticationProviding)?
    let studentRepository: any StudentRepository
    let studentDetailRepository: any StudentDetailRepository
    let studentModeRepository: StudentModeRepository?
    let planRepository: (any PlanRecordRepository)?
    let planChildRepository: (any PlanChildRepositoryProtocol)?
    let planExportAuditing: (any PlanExportAuditing)?
    let careerRelationshipRepository: (any CareerRelationshipProviding)?
    let resourceRepository: (any ResourceRepository)?
    let logger: TMILogger

    init(
        runtime: Runtime,
        flags: FeatureFlags,
        membership: any MembershipProviding,
        authentication: (any AuthenticationProviding)?,
        studentRepository: any StudentRepository,
        studentDetailRepository: any StudentDetailRepository,
        studentModeRepository: StudentModeRepository? = nil,
        planRepository: (any PlanRecordRepository)? = nil,
        planChildRepository: (any PlanChildRepositoryProtocol)? = nil,
        planExportAuditing: (any PlanExportAuditing)? = nil,
        careerRelationshipRepository: (any CareerRelationshipProviding)? = nil,
        resourceRepository: (any ResourceRepository)? = nil,
        logger: TMILogger
    ) {
        self.runtime = runtime
        self.flags = flags
        self.membership = membership
        self.authentication = authentication
        self.studentRepository = studentRepository
        self.studentDetailRepository = studentDetailRepository
        self.studentModeRepository = studentModeRepository
        self.planRepository = planRepository
        self.planChildRepository = planChildRepository
        self.planExportAuditing = planExportAuditing
        self.careerRelationshipRepository = careerRelationshipRepository
        self.resourceRepository = resourceRepository
        self.logger = logger
    }

    @MainActor
    static func production(firestore: Firestore) -> AppDependencies {
        let flags = FeatureFlags.production
        let membership = MembershipRepository(
            store: FirebaseMembershipStore(firestore: firestore)
        )
        let firebaseInvitationProvisioner = FirebaseStaffInvitationProvisioner()
        let firebaseSessionLoader = FirebaseAuthenticationSessionLoader(
            membershipProvider: membership,
            requiresEmailVerification: flags.staffEmailVerificationRequired
        )
#if DEBUG
        let invitationProvisioner: any StaffInvitationProvisioning =
            DebugStaffInvitationProvisioner(delegate: firebaseInvitationProvisioner)
        let sessionLoader: any AuthenticationSessionLoading =
            DebugAuthenticationSessionLoader(delegate: firebaseSessionLoader)
#else
        let invitationProvisioner: any StaffInvitationProvisioning =
            firebaseInvitationProvisioner
        let sessionLoader: any AuthenticationSessionLoading = firebaseSessionLoader
#endif
        let authentication = AuthenticationRepository(
            backend: FirebaseAuthenticationBackend(),
            sessionLoader: sessionLoader,
            invitationProvisioner: invitationProvisioner,
            pendingRegistrationStore: SecurePendingStaffRegistrationStore(),
            requiresEmailVerification: flags.staffEmailVerificationRequired
        )
        let firebaseStudents = CanonicalStudentRepository.firebase(firestore: firestore)
        let firebasePlans = CanonicalPlanRepository(firestore: firestore)
        let firebasePlanChildren = PlanChildRepository(firestore: firestore)
#if DEBUG
        let students: any StudentRepository = DebugStudentRepository(delegate: firebaseStudents)
        let debugPlanStore = DebugPlanStore()
        let plans: any PlanRecordRepository = DebugPlanRepository(
            delegate: firebasePlans,
            store: debugPlanStore
        )
        let planChildren: any PlanChildRepositoryProtocol = DebugPlanChildRepository(
            delegate: firebasePlanChildren,
            store: debugPlanStore
        )
#else
        let students: any StudentRepository = firebaseStudents
        let plans: any PlanRecordRepository = firebasePlans
        let planChildren: any PlanChildRepositoryProtocol = firebasePlanChildren
#endif
        let resources: any ResourceRepository = FirebaseResourceRepository(
            transport: FirebaseResourceTransport(firestore: firestore)
        )

        return AppDependencies(
            runtime: .production,
            flags: flags,
            membership: membership,
            authentication: authentication,
            studentRepository: students,
            studentDetailRepository: CanonicalStudentDetailRepository.firebase(students: students, plans: plans, firestore: firestore),
            studentModeRepository: .firebase(),
            planRepository: plans,
            planChildRepository: planChildren,
            planExportAuditing: FirebasePlanExportAuditing(),
            careerRelationshipRepository: CareerRelationshipRepository(
                firestore: firestore
            ),
            resourceRepository: resources,
            logger: .production
        )
    }

    static func production(
        membershipStore: any MembershipStore,
        authentication: (any AuthenticationProviding)? = nil
    ) -> AppDependencies {
        let students = UnavailableStudentRepository()
        return AppDependencies(
            runtime: .production,
            flags: .production,
            membership: MembershipRepository(store: membershipStore),
            authentication: authentication,
            studentRepository: students,
            studentDetailRepository: Release1StudentDetailRepository(students: students),
            logger: .production
        )
    }

    static func preview(
        memberships: [MembershipContext] = [],
        studentRepository: any StudentRepository = UnavailableStudentRepository(),
        studentDetailRepository: (any StudentDetailRepository)? = nil
    ) -> AppDependencies {
        AppDependencies(
            runtime: .preview,
            flags: .production,
            membership: InMemoryMembershipProvider(memberships: memberships),
            authentication: nil,
            studentRepository: studentRepository,
            studentDetailRepository: studentDetailRepository
                ?? Release1StudentDetailRepository(students: studentRepository),
            logger: TMILogger(category: "Preview")
        )
    }

    /// A fail-closed default for views rendered without the application root.
    static let unconfigured = AppDependencies(
        runtime: .unconfigured,
        flags: .production,
        membership: UnavailableMembershipProvider(),
        authentication: nil,
        studentRepository: UnavailableStudentRepository(),
        studentDetailRepository: Release1StudentDetailRepository(
            students: UnavailableStudentRepository()
        ),
        logger: .production
    )
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies = .unconfigured
}

nonisolated struct InMemoryMembershipProvider: MembershipProviding {
    private struct Key: Hashable, Sendable {
        let userID: String
        let districtID: String
    }

    private let memberships: [Key: MembershipContext]

    init(memberships: [MembershipContext]) {
        self.memberships = Dictionary(
            uniqueKeysWithValues: memberships.map {
                (Key(userID: $0.userID, districtID: $0.districtID), $0)
            }
        )
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        guard claim.accessClass == .staff else {
            throw MembershipRepositoryError.invalidClaim
        }

        let key = Key(userID: claim.userID, districtID: claim.districtID)
        guard let membership = memberships[key] else {
            throw MembershipRepositoryError.notFound
        }
        guard membership.isActive else {
            throw MembershipRepositoryError.inactive
        }
        guard membership.version == claim.membershipVersion else {
            throw MembershipRepositoryError.versionMismatch
        }
        return membership
    }
}

nonisolated private struct UnavailableMembershipProvider: MembershipProviding {
    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        throw MembershipRepositoryError.unavailable
    }
}

nonisolated struct UnavailableStudentRepository: StudentRepository {
    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        throw StudentRepositoryError.unavailable
    }

    func student(
        id: String,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.unavailable
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.unavailable
    }

    func reconcilePendingCreates(
        member: MembershipContext
    ) async throws -> [StudentRecord] {
        throw StudentRepositoryError.unavailable
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.unavailable
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        throw StudentRepositoryError.unavailable
    }
}
