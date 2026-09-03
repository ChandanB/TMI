import Foundation
import Testing
@testable import TMI

@Suite("Application dependencies")
struct AppDependenciesTests {
    @Test("Production composes Firebase membership and production logging")
    func productionComposition() throws {
        let dependencies = AppDependencies.production(
            membershipStore: FailingMembershipStore()
        )
        let source = try self.source(
            "TMI/Core/Dependencies/AppDependencies.swift",
            root: self.repositoryRoot
        )

        #expect(dependencies.runtime == .production)
        #expect(dependencies.flags == .production)
        #expect(dependencies.membership is MembershipRepository)
        #expect(dependencies.logger === TMILogger.production)
        #expect(source.contains("FirebaseMembershipStore(firestore: firestore)"))
        #expect(source.contains("FirebaseAuthenticationBackend"))
        #expect(source.contains("FirebaseAuthenticationSessionLoader"))
        #expect(source.contains("FirebaseStaffInvitationProvisioner"))
        #expect(source.contains("SecurePendingStaffRegistrationStore"))
    }

    @Test("Production assembly gates both Debug authentication decorators")
    func productionGatesDebugAuthenticationDecorators() throws {
        let source = try self.source(
            "TMI/Core/Dependencies/AppDependencies.swift",
            root: self.repositoryRoot
        )
        let compactSource = source.removingWhitespace

        #expect(compactSource.contains(
            """
            letfirebaseInvitationProvisioner=FirebaseStaffInvitationProvisioner()
            letfirebaseSessionLoader=FirebaseAuthenticationSessionLoader(
            membershipProvider:membership,
            requiresEmailVerification:flags.staffEmailVerificationRequired
            )
            #ifDEBUG
            letinvitationProvisioner:anyStaffInvitationProvisioning=DebugStaffInvitationProvisioner(delegate:firebaseInvitationProvisioner)
            letsessionLoader:anyAuthenticationSessionLoading=DebugAuthenticationSessionLoader(delegate:firebaseSessionLoader)
            #else
            letinvitationProvisioner:anyStaffInvitationProvisioning=firebaseInvitationProvisioner
            letsessionLoader:anyAuthenticationSessionLoading=firebaseSessionLoader
            #endif
            """.removingWhitespace
        ))
        #expect(compactSource.contains("sessionLoader:sessionLoader"))
        #expect(compactSource.contains("invitationProvisioner:invitationProvisioner"))
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

        #expect(seederSource.contains("#if DEBUG"))
        #expect(!firebaseSource.contains("seedInitialEducatorDataIfNeeded"))
        #expect(!firebaseSource.contains("comprehensiveSampleStudents"))
        #expect(!firebaseSource.contains("expandedSampleInterests"))
        #expect(!firebaseSource.localizedCaseInsensitiveContains("mock authentication"))
    }

    @Test("Release 1 removes the legacy student service and state models")
    func releaseOneRemovesLegacyStudentStack() throws {
        let legacyFiles = [
            "TMI/Services/StudentService.swift",
            "TMI/StateModels/StudentListStateModel.swift",
            "TMI/StateModels/AddStudentStateModel.swift",
        ]
        let remainingLegacyFiles = legacyFiles.filter { file in
            FileManager.default.fileExists(
                atPath: self.repositoryRoot.appending(path: file).path
            )
        }
        #expect(
            remainingLegacyFiles.isEmpty,
            "Release 1 must remove: \(remainingLegacyFiles.joined(separator: ", "))"
        )

        let productionSource = try self.productionSwiftSources()
        let forbiddenSymbols = [
            "StudentService",
            "StudentListStateModel",
            "AddStudentStateModel",
        ]
        var legacyReferences: [String] = []
        for (path, source) in productionSource {
            for symbol in forbiddenSymbols {
                if source.contains(symbol) {
                    legacyReferences.append("\(symbol): \(path)")
                }
            }
        }
        #expect(
            legacyReferences.isEmpty,
            """
            Release 1 production source still references the legacy student stack:
            \(legacyReferences.sorted().joined(separator: "\n"))
            """
        )
    }

    @Test("Release 1 student persistence is district scoped")
    func releaseOneStudentPersistenceIsDistrictScoped() throws {
        let repositorySource = try self.source(
            "TMI/Features/Students/StudentRepository.swift",
            root: self.repositoryRoot
        ).removingWhitespace

        #expect(
            repositorySource.contains(
                ".collection(\"districts\").document(plan.districtID).collection(\"students\")"
            )
        )
        #expect(
            repositorySource.contains(
                ".collection(\"districts\").document(request.districtID).collection(\"students\")"
            )
        )

        let legacyUserStudentPaths = [
            #"\.collection\((?:"users"|FirestoreCollection\.users\.rawValue)\)\.document\([^)]*\)\.collection\("students"\)"#,
            #"userDoc\.collection\("students"\)"#,
        ]
        let directLegacyStudentRoots = [
            #"db\.collection\("students"\)"#,
            #"self\.db\.collection\("students"\)"#,
            #"firestore\.collection\("students"\)"#,
        ]

        var userScopedPaths = Set<String>()
        var topLevelPaths = Set<String>()
        var enumBasedStudentPaths = Set<String>()
        var dynamicCollectionPaths = Set<String>()
        for (path, source) in try self.productionSwiftSources() {
            let compactSource = source.removingWhitespace
            for pattern in legacyUserStudentPaths {
                if compactSource.matches(pattern) {
                    userScopedPaths.insert(path)
                }
            }
            for pattern in directLegacyStudentRoots {
                if compactSource.matches(pattern) {
                    topLevelPaths.insert(path)
                }
            }
            if compactSource.contains(
                ".collection(FirestoreCollection.students.rawValue)"
            ) {
                enumBasedStudentPaths.insert(path)
            }
            if compactSource.contains(".collection(dataType)") {
                dynamicCollectionPaths.insert(path)
            }
        }
        #expect(
            userScopedPaths.isEmpty,
            """
            Found legacy user-scoped student collections in:
            \(userScopedPaths.sorted().joined(separator: "\n"))
            """
        )
        #expect(
            topLevelPaths.isEmpty,
            """
            Found legacy top-level student collections in:
            \(topLevelPaths.sorted().joined(separator: "\n"))
            """
        )
        #expect(
            enumBasedStudentPaths.isEmpty,
            """
            Found enum-based legacy student collections in:
            \(enumBasedStudentPaths.sorted().joined(separator: "\n"))
            """
        )
        #expect(
            dynamicCollectionPaths.isEmpty,
            """
            Found dynamic collection paths that can bypass the student writer freeze in:
            \(dynamicCollectionPaths.sorted().joined(separator: "\n"))
            """
        )
    }

    @Test("Release 1 import rejects institutional student records")
    func releaseOneImportRejectsStudentRecords() throws {
        #expect(throws: DataImportPayloadPolicy.PolicyError.studentRecordsUnsupported) {
            try DataImportPayloadPolicy.validate([
                "students": [
                    ["id": "legacy-student"],
                ],
                "resources": [],
            ])
        }

        try DataImportPayloadPolicy.validate([
            "resources": [],
            "forms": [],
        ])

        let importSource = try self.source(
            "TMI/Views/Settings/DataImportView.swift",
            root: self.repositoryRoot
        )
        #expect(!importSource.contains("studentsImported"))
        #expect(!importSource.contains(#""students", "tmiPlans""#))
    }

    @Test("Release 1 dashboard is independent of denied legacy plan storage")
    func releaseOneDashboardAvoidsLegacyPlans() throws {
        let dashboardSource = try self.source(
            "TMI/Views/Dashboard/DashboardView.swift",
            root: self.repositoryRoot
        )
        let shellSource = try self.source(
            "TMI/Views/MainTabView.swift",
            root: self.repositoryRoot
        )

        #expect(!dashboardSource.contains("tmiPlanService.fetchPlans()"))
        #expect(!dashboardSource.contains("private let tmiPlanService"))
        #expect(!shellSource.contains("case .plans:\n            TMIPlanListView()"))
        #expect(shellSource.contains("TMI Plans Arrive in Release 3"))
    }

    @Test("Plan snapshots derive only from canonical roster records")
    func planSnapshotsAreCanonical() {
        let birthDate = Date(timeIntervalSince1970: 1_325_376_000)
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let updatedAt = Date(timeIntervalSince1970: 1_704_153_600)
        let record = StudentRecord(
            id: "student-1",
            districtID: "district-a",
            schoolID: "school-a",
            displayName: "Ava Stone",
            grade: "7",
            studentIdentifier: "A-100",
            dateOfBirth: birthDate,
            pronouns: "she/her",
            assignedMemberIDs: ["teacher-1"],
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 3,
                createdAt: createdAt,
                createdBy: "teacher-1",
                updatedAt: updatedAt,
                updatedBy: "teacher-1"
            )
        )

        let snapshot = record.planStudentSnapshot()

        #expect(snapshot?.id == record.id)
        #expect(snapshot?.name == record.displayName)
        #expect(snapshot?.grade == record.grade)
        #expect(snapshot?.school == record.schoolID)
        #expect(snapshot?.dateOfBirth == birthDate)
        #expect(snapshot?.districtId == record.districtID)
        #expect(snapshot?.schoolId == record.schoolID)
        #expect(snapshot?.studentID == record.studentIdentifier)
        #expect(snapshot?.createdAt == createdAt)
        #expect(snapshot?.updatedAt == updatedAt)
        #expect(snapshot?.surveyResults == nil)
        #expect(snapshot?.notes == nil)
    }

    @Test("Survey results never report success when persistence fails")
    func surveyResultsRenderPersistenceFailure() throws {
        // Persistence moved out of SurveyResultsView and into StudentSurveyFlow,
        // which now owns submission. The guarantee is unchanged: results are
        // only reachable after a submit that actually persisted, and a failure
        // keeps the student on review with a message instead of reporting
        // success.
        let flowSource = try self.source(
            "TMI/Views/Survey/StudentSurveyFlow.swift",
            root: self.repositoryRoot
        )
        let serviceSource = try self.source(
            "TMI/Services/SurveyService.swift",
            root: self.repositoryRoot
        )

        let submitBody = try #require(
            flowSource.range(of: "response = try await repository.submit")
                .map { flowSource[$0.lowerBound...] }
                .map(String.init)
        )
        let advance = try #require(submitBody.range(of: "phase = .results"))
        let failure = try #require(submitBody.range(of: "catch { message = friendly(error) }"))
        // The advance is inside the do block, ahead of the catch.
        #expect(advance.lowerBound < failure.lowerBound)
        #expect(flowSource.contains("@State private var isSaving = false"))
        #expect(
            serviceSource.contains(
                "case studentSurveyPersistenceUnavailable"
            )
        )
        #expect(
            serviceSource.contains(
                "throw SurveyServiceError.studentSurveyPersistenceUnavailable"
            )
        )
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

    @Test("Environment defaults never resolve production service singletons")
    func environmentDefaultsAreInjected() throws {
        let root = repositoryRoot
        let notificationSource = try source("TMI/Services/NotificationService.swift", root: root)
        let auditSource = try source("TMI/Services/AuditService.swift", root: root)
        let authSource = try source("TMI/StateModels/AuthStateModel.swift", root: root)
        let appSource = try source("TMI/App/TMIApp.swift", root: root)

        #expect(!notificationSource.contains("@Entry var notificationService: NotificationService = NotificationService.shared"))
        #expect(notificationSource.contains("@Entry var notificationService: NotificationService? = nil"))
        #expect(!auditSource.contains("AUDIT_SERVICE"))
        #expect(!authSource.contains("auditService: AuditService ="))
        #expect(appSource.contains("auditService: AuditService()"))
        #expect(appSource.contains(".environment(\\.notificationService, notificationService)"))
    }

    private func source(_ path: String, root: URL) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private func productionSwiftSources() throws -> [(path: String, source: String)] {
        let sourceRoot = self.repositoryRoot.appending(path: "TMI")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )
        )
        var sources: [(path: String, source: String)] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift",
                  !fileURL.path.contains("/Migration/") else {
                continue
            }
            sources.append(
                (
                    path: fileURL.path.replacingOccurrences(
                        of: self.repositoryRoot.path + "/",
                        with: ""
                    ),
                    source: try String(contentsOf: fileURL, encoding: .utf8)
                )
            )
        }

        return sources
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

private extension String {
    var removingWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines).joined()
    }

    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
