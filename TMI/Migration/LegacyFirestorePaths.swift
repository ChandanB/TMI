import Foundation

nonisolated enum LegacyMigrationRelease: String, Codable, Sendable {
    case release1SecureRoster
    case release2Discovery
    case release3Intervention
    case release4Collaboration
    case release6OptionalAI
}

nonisolated struct LegacyCollectionMigration: Codable, Sendable, Equatable {
    let collectionTemplate: String
    let owner: LegacyMigrationRelease
}

/// Read-only path inventory for forward migration tooling.
///
/// Production repositories must never depend on this type. Canonical writes
/// always use `FirestorePaths`; unresolved ownership is quarantined by the
/// migration runner instead of being guessed by an app client.
nonisolated enum LegacyFirestorePaths {
    static func userStudents(userID: String) -> String {
        "users/\(userID)/students"
    }

    static func userPlans(userID: String) -> String {
        "users/\(userID)/tmiPlans"
    }

    static func topLevelStudentInterests(studentID: String) -> String {
        "students/\(studentID)/studentInterests"
    }

    static func topLevelStudentCareerState(studentID: String) -> String {
        "students/\(studentID)/careerState"
    }

    static func topLevelStudentSurveys(studentID: String) -> String {
        "students/\(studentID)/surveys"
    }

    static func topLevelPlans() -> String {
        "plans"
    }

    static func topLevelPlanSubcollection(planID: String, name: String) -> String {
        "plans/\(planID)/\(name)"
    }

    static let migrationManifest: [LegacyCollectionMigration] = [
        .init(collectionTemplate: "users/{uid}/students", owner: .release1SecureRoster),
        .init(collectionTemplate: "students", owner: .release1SecureRoster),
        .init(
            collectionTemplate: "users/{uid}/students/{studentId}/consents",
            owner: .release1SecureRoster
        ),
        .init(
            collectionTemplate: "students/{studentId}/studentInterests",
            owner: .release2Discovery
        ),
        .init(
            collectionTemplate: "students/{studentId}/careerState",
            owner: .release2Discovery
        ),
        .init(
            collectionTemplate: "students/{studentId}/surveys",
            owner: .release2Discovery
        ),
        .init(
            collectionTemplate: "users/{uid}/students/{studentId}/interestSurveys",
            owner: .release2Discovery
        ),
        .init(
            collectionTemplate: "users/{uid}/students/{studentId}/savedCareers",
            owner: .release2Discovery
        ),
        .init(collectionTemplate: "users/{uid}/tmiPlans", owner: .release3Intervention),
        .init(collectionTemplate: "plans", owner: .release3Intervention),
        .init(
            collectionTemplate: "plans/{planId}/planResources",
            owner: .release3Intervention
        ),
        .init(
            collectionTemplate: "plans/{planId}/activities",
            owner: .release3Intervention
        ),
        .init(
            collectionTemplate: "plans/{planId}/approvals",
            owner: .release3Intervention
        ),
        .init(
            collectionTemplate: "plans/{planId}/inputs",
            owner: .release3Intervention
        ),
        .init(
            collectionTemplate: "plans/{planId}/evidence",
            owner: .release3Intervention
        ),
        .init(collectionTemplate: "users/{uid}/resources", owner: .release4Collaboration),
        .init(collectionTemplate: "users/{uid}/meetings", owner: .release4Collaboration),
        .init(collectionTemplate: "formTemplates", owner: .release4Collaboration),
        .init(collectionTemplate: "formAssignments", owner: .release4Collaboration),
        .init(collectionTemplate: "formSubmissions", owner: .release4Collaboration),
        .init(collectionTemplate: "resources", owner: .release4Collaboration),
        .init(collectionTemplate: "notifications", owner: .release4Collaboration),
        .init(collectionTemplate: "generatedResources", owner: .release6OptionalAI),
    ]

    static let collectionTemplates = Set(migrationManifest.map(\.collectionTemplate))

    static func owner(for collectionTemplate: String) -> LegacyMigrationRelease? {
        migrationManifest.first {
            $0.collectionTemplate == collectionTemplate
        }?.owner
    }
}
