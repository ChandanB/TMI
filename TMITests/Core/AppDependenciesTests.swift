import FirebaseCore
import FirebaseFirestore
import Foundation
import Testing
@testable import TMI

@Suite("Application dependencies")
struct AppDependenciesTests {
    @Test("Production composes Firebase membership and production logging")
    func productionComposition() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let dependencies = AppDependencies.production(
            firestore: Firestore.firestore()
        )

        #expect(dependencies.runtime == .production)
        #expect(dependencies.flags == .production)
        #expect(dependencies.membership is MembershipRepository)
        #expect(dependencies.logger === TMILogger.production)
    }

    @Test("Preview composes an in-memory membership fixture")
    func previewComposition() async throws {
        let membership = MembershipContext(
            userID: "preview-staff",
            districtID: "preview-district",
            schoolIDs: ["preview-school"],
            role: .teacher,
            capabilities: [],
            assignedStudentIDs: ["preview-student"],
            isActive: true,
            version: 1
        )
        let claim = TrustedTenantClaim(
            userID: membership.userID,
            districtID: membership.districtID,
            accessClass: .staff,
            membershipVersion: membership.version
        )

        let dependencies = AppDependencies.preview(memberships: [membership])
        let loaded = try await dependencies.membership.membership(for: claim)

        #expect(dependencies.runtime == .preview)
        #expect(dependencies.membership is InMemoryMembershipProvider)
        #expect(loaded == membership)
    }

    @Test("A production repository failure remains an honest unavailable error")
    func productionFailureDoesNotFabricateMembership() async {
        let repository = MembershipRepository(store: FailingMembershipStore())
        let claim = TrustedTenantClaim(
            userID: "staff-1",
            districtID: "district-a",
            accessClass: .staff,
            membershipVersion: 1
        )

        await #expect(throws: MembershipRepositoryError.unavailable) {
            _ = try await repository.membership(for: claim)
        }
    }

    @Test("Sample seeding is debug-only and authentication never fabricates success")
    func productionHasNoImplicitFixtures() throws {
        let root = repositoryRoot
        let seederSource = try source("TMI/Utilities/SampleDataSeeder.swift", root: root)
        let firebaseSource = try source("TMI/Services/FirebaseManager.swift", root: root)
        let studentServiceSource = try source("TMI/Services/StudentService.swift", root: root)

        #expect(seederSource.contains("#if DEBUG"))
        #expect(studentServiceSource.contains("#if DEBUG\nclass MockStudentService"))
        #expect(!firebaseSource.contains("seedInitialEducatorDataIfNeeded"))
        #expect(!firebaseSource.contains("comprehensiveSampleStudents"))
        #expect(!firebaseSource.contains("expandedSampleInterests"))
        #expect(!firebaseSource.localizedCaseInsensitiveContains("mock authentication"))
    }

    @Test("Gate 0 paths contain no raw console logging")
    func gateZeroLoggingIsStructured() throws {
        let root = repositoryRoot
        let files = [
            "TMI/App/TMIApp.swift",
            "TMI/Views/MainTabView.swift",
            "TMI/Services/AuthenticationService.swift",
            "TMI/Services/TMIAuthService.swift",
            "TMI/Services/FirebaseManager.swift",
            "TMI/Services/FirebaseConfigurationHelper.swift",
            "TMI/Services/AccountDeletionService.swift",
            "TMI/Core/Logging/TMILogger.swift",
            "TMI/Views/Authentication/RoleSelectionView.swift",
        ]

        for file in files {
            let contents = try source(file, root: root)
            #expect(!contents.contains("print("), "Found raw logging in \(file)")
            #expect(!contents.contains("debugPrint("), "Found raw logging in \(file)")
            #expect(!contents.contains("dump("), "Found raw logging in \(file)")
        }
    }

    private func source(_ path: String, root: URL) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct FailingMembershipStore: MembershipStore {
    struct Failure: Error {}

    func membership(for request: MembershipStoreRequest) async throws -> MembershipStoreRecord? {
        throw Failure()
    }
}
