import Foundation

nonisolated struct TOTPEnrollment: Sendable, Equatable {
    let secretKey: String
    let qrCodeURL: URL
    let expiresAt: Date
}

nonisolated struct MFAFactor: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let displayName: String
}

nonisolated struct MFAChallengeReceipt: Sendable, Equatable {
    let id: String
    let factorID: String
    let verifiedAt: Date
    let expiresAt: Date
}

nonisolated enum PrivilegedOperation: Sendable, Equatable {
    case staffManagement
    case retention
    case audit
    case studentDrillDown
    case sensitiveExport
}

nonisolated enum MFAAccessState: Sendable, Equatable {
    case notRequired
    case enrollmentRequired
    case challengeRequired
    case authorized
}

nonisolated enum MFARepositoryError: Error, Equatable {
    case invalidCode
    case enrollmentExpired
    case noPendingEnrollment
    case enrollmentRequired
    case challengeExpired
    case replayedChallenge
    case malformedChallenge
    case recentAuthenticationRequired
}

nonisolated protocol MFABackend: Sendable {
    func beginEnrollment() async throws -> TOTPEnrollment
    func confirmEnrollment(
        _ enrollment: TOTPEnrollment,
        code: String
    ) async throws -> MFAFactor
    func challenge(
        factorID: String,
        code: String
    ) async throws -> MFAChallengeReceipt
    func unenroll(factorID: String) async throws
}

actor MFARepository {
    private let backend: any MFABackend
    private let now: @Sendable () -> Date
    private var factorsByID: [String: MFAFactor]
    private var pendingEnrollment: TOTPEnrollment?
    private var currentChallenge: MFAChallengeReceipt?
    private var usedChallengeIDs: Set<String> = []

    init(
        backend: any MFABackend,
        enrolledFactors: [MFAFactor] = [],
        now: @Sendable @escaping () -> Date = Date.init
    ) {
        self.backend = backend
        self.now = now
        factorsByID = Dictionary(
            uniqueKeysWithValues: enrolledFactors.map { ($0.id, $0) }
        )
    }

    var enrolledFactors: [MFAFactor] {
        factorsByID.values.sorted { $0.id < $1.id }
    }

    func enrollTOTP() async throws -> TOTPEnrollment {
        let enrollment = try await backend.beginEnrollment()
        guard enrollment.expiresAt > now(),
              !enrollment.secretKey.isEmpty else {
            throw MFARepositoryError.enrollmentExpired
        }
        pendingEnrollment = enrollment
        return enrollment
    }

    func confirmEnrollment(code: String) async throws -> MFAFactor {
        let code = try validatedCode(code)
        guard let pendingEnrollment else {
            throw MFARepositoryError.noPendingEnrollment
        }
        guard pendingEnrollment.expiresAt > now() else {
            self.pendingEnrollment = nil
            throw MFARepositoryError.enrollmentExpired
        }

        let factor = try await backend.confirmEnrollment(
            pendingEnrollment,
            code: code
        )
        guard TrustedIdentifier.isValid(factor.id) else {
            throw MFARepositoryError.malformedChallenge
        }
        factorsByID[factor.id] = factor
        self.pendingEnrollment = nil
        return factor
    }

    func challenge(code: String) async throws -> MFAChallengeReceipt {
        let code = try validatedCode(code)
        guard let factor = enrolledFactors.first else {
            throw MFARepositoryError.enrollmentRequired
        }

        let receipt = try await backend.challenge(
            factorID: factor.id,
            code: code
        )
        guard TrustedIdentifier.isValid(receipt.id),
              receipt.factorID == factor.id else {
            throw MFARepositoryError.malformedChallenge
        }
        guard receipt.expiresAt > now(), receipt.verifiedAt <= now() else {
            throw MFARepositoryError.challengeExpired
        }
        guard usedChallengeIDs.insert(receipt.id).inserted else {
            throw MFARepositoryError.replayedChallenge
        }

        currentChallenge = receipt
        return receipt
    }

    func unenroll(factorID: String) async throws {
        guard factorsByID[factorID] != nil else {
            return
        }
        try await backend.unenroll(factorID: factorID)
        factorsByID[factorID] = nil
        if currentChallenge?.factorID == factorID {
            currentChallenge = nil
        }
    }

    func invalidateForSignOut() {
        pendingEnrollment = nil
        currentChallenge = nil
        usedChallengeIDs.removeAll()
    }

    func access(
        for role: StaffRole,
        operation: PrivilegedOperation
    ) -> MFAAccessState {
        guard Self.requiresMFA(role: role, operation: operation) else {
            return .notRequired
        }
        guard !factorsByID.isEmpty else {
            return .enrollmentRequired
        }
        guard let currentChallenge,
              factorsByID[currentChallenge.factorID] != nil,
              currentChallenge.expiresAt > now() else {
            return .challengeRequired
        }
        return .authorized
    }

    private func validatedCode(_ code: String) throws -> String {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6,
              code.allSatisfy(\.isNumber) else {
            throw MFARepositoryError.invalidCode
        }
        return code
    }

    private static func requiresMFA(
        role: StaffRole,
        operation: PrivilegedOperation
    ) -> Bool {
        switch role {
        case .schoolAdministrator, .districtAdministrator:
            true
        case .teacher, .counselor, .socialWorker:
            false
        }
    }
}
