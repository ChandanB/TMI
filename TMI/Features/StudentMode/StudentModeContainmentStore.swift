import Foundation

nonisolated struct StudentModeContainmentRecord: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let districtID: String
    let sessionID: String

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        districtID: String,
        sessionID: String
    ) {
        self.schemaVersion = schemaVersion
        self.districtID = districtID
        self.sessionID = sessionID
    }

    var isValid: Bool {
        schemaVersion == Self.currentSchemaVersion &&
            Self.isValidIdentifier(districtID) &&
            Self.isValidIdentifier(sessionID)
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

nonisolated enum StudentModeContainmentLoad: Equatable, Sendable {
    case missing
    case record(StudentModeContainmentRecord)
    case corrupt
}

nonisolated struct StudentModeContainmentStore: Sendable {
    typealias Load = @Sendable () async -> StudentModeContainmentLoad
    typealias Save = @Sendable (StudentModeContainmentRecord) async throws -> Void
    typealias Clear = @Sendable () async throws -> Void

    private let loadValue: Load
    private let saveValue: Save
    private let clearValue: Clear

    init(
        load: @escaping Load,
        save: @escaping Save,
        clear: @escaping Clear
    ) {
        loadValue = load
        saveValue = save
        clearValue = clear
    }

    func load() async -> StudentModeContainmentLoad {
        await loadValue()
    }

    func save(_ record: StudentModeContainmentRecord) async throws {
        guard record.isValid else {
            throw StudentModeRepositoryError.invalidRequest
        }
        try await saveValue(record)
    }

    func clear() async throws {
        try await clearValue()
    }
}

nonisolated extension StudentModeContainmentStore {
    static let empty = StudentModeContainmentStore(
        load: { .missing },
        save: { _ in },
        clear: {}
    )

    static func keychain(
        manager: KeychainManager = KeychainManager(
            service: "com.tmi.education.student-mode"
        )
    ) -> StudentModeContainmentStore {
        let key = "containment.v1"
        return StudentModeContainmentStore(
            load: {
                do {
                    let data = try manager.retrieve(for: key)
                    let record = try JSONDecoder().decode(
                        StudentModeContainmentRecord.self,
                        from: data
                    )
                    return record.isValid ? .record(record) : .corrupt
                } catch KeychainError.itemNotFound {
                    return .missing
                } catch {
                    return .corrupt
                }
            },
            save: { record in
                let data = try JSONEncoder().encode(record)
                try manager.store(data, for: key)
            },
            clear: {
                try manager.delete(for: key)
            }
        )
    }
}
