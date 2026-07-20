import Foundation
import Testing
@testable import TMI

@Suite("Editable profile authority purge")
struct AuthoritySourcePurgeTests {
    @Test("Personal profiles encode requested role but no authorization state")
    func personalProfileEncodingOmitsAuthority() throws {
        let profile = TMIUser(
            userID: "user-1",
            displayName: "Casey Staff",
            email: "casey@example.org",
            requestedRole: .teacher,
            photoURL: "https://example.org/casey.png",
            organization: "Example School"
        )

        let data = try JSONEncoder().encode(profile)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["requestedRole"] as? String == UserRole.teacher.rawValue)
        #expect(object["photoURL"] as? String == "https://example.org/casey.png")
        #expect(object["organization"] as? String == "Example School")
        for forbiddenKey in Self.authorityKeys {
            #expect(object[forbiddenKey] == nil)
        }
    }

    @Test("Legacy authorization fields decode only through migration record")
    func legacyAuthorizationHasDedicatedDecoder() throws {
        let data = Data(
            """
            {
              "role": "administrator",
              "permissions": ["manage_users"],
              "dataClassificationAccess": ["sensitive"],
              "districtId": "district-a",
              "schoolId": "school-a",
              "institutionID": "institution-a",
              "isActive": true
            }
            """.utf8
        )

        let legacy = try JSONDecoder().decode(LegacyUserAuthorizationRecord.self, from: data)

        #expect(legacy.role == .administrator)
        #expect(legacy.districtID == "district-a")
        #expect(legacy.schoolID == "school-a")
    }

    @Test("Production source has no editable-profile authorization readers")
    func productionSourceHasNoEditableProfileAuthorizationReaders() throws {
        let source = try productionSwiftSource()
        let forbiddenFragments = [
            "authStateModel.currentUser?.role",
            "authStateModel.currentUser.role",
            "authStateModel.currentUser?.districtId",
            "authStateModel.currentUser.districtId",
            "authStateModel.currentUser?.schoolId",
            "authStateModel.currentUser.schoolId",
            "RBACService.shared",
            "requirePermission(",
            "role.defaultPermissions",
            "role.defaultDataAccess",
            "defaultPermissions",
            "defaultDataAccess",
            "canAccessSensitiveData",
            "canManageUserData",
        ]

        for fragment in forbiddenFragments {
            #expect(!source.contains(fragment), "Found forbidden production fragment: \(fragment)")
        }
    }

    @Test("Registration services do not write profile authority fields")
    func registrationWritersOmitAuthority() throws {
        let root = repositoryRoot
        let files = [
            root.appending(path: "TMI/Services/AuthenticationService.swift"),
            root.appending(path: "TMI/Services/FirebaseManager.swift"),
        ]

        let source = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        for key in Self.authorityKeys {
            #expect(!source.contains("\"\(key)\""), "Registration writer still references authority key: \(key)")
        }
    }

    @Test("Services never fetch personal profiles to authorize")
    func servicesDoNotFetchProfileAuthority() throws {
        let root = repositoryRoot
        let files = [
            "TMI/Services/StudentService.swift",
            "TMI/Services/TMIPlanService.swift",
            "TMI/Services/FormAssignmentService.swift",
            "TMI/Services/AuditLogService.swift",
        ]
        let source = try files.map {
            try String(contentsOf: root.appending(path: $0), encoding: .utf8)
        }.joined()

        #expect(!source.contains("data(as: TMIUser.self)"))
        #expect(!source.contains("userData?[\"role\"]"))
        #expect(!source.contains("userData?[\"districtId\"]"))
    }

    @Test("Template services require trusted typed scope")
    func templateServicesRequireTrustedTypedScope() throws {
        let root = repositoryRoot
        let files = [
            "TMI/Services/FormTemplateService.swift",
            "TMI/Services/PlanTemplateService.swift",
        ]

        for file in files {
            let source = try String(
                contentsOf: root.appending(path: file),
                encoding: .utf8
            )
            #expect(source.contains("AuthorizationSessionProviding"))
            #expect(source.contains("TemplateAuthorizationScope"))
        }
    }

    private func productionSwiftSource() throws -> String {
        let sourceRoot = repositoryRoot.appending(path: "TMI")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )
        )
        var source = ""

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift",
                  !fileURL.path.contains("/Migration/") else {
                continue
            }
            source += try String(contentsOf: fileURL, encoding: .utf8)
        }

        return source
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static let authorityKeys = [
        "role",
        "permissions",
        "dataClassificationAccess",
        "districtId",
        "schoolId",
        "institutionID",
        "isActive",
    ]
}
