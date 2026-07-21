import Foundation
import Testing
@testable import TMI

@Suite("Administrator TOTP MFA")
struct MFARepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_784_548_800)

    @Test("Invalid and expired codes fail closed")
    func invalidAndExpiredCodesFailClosed() async throws {
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(-1))
        )
        let repository = MFARepository(
            backend: backend,
            now: { now }
        )

        await #expect(throws: MFARepositoryError.enrollmentExpired) {
            _ = try await repository.enrollTOTP()
        }
        await #expect(throws: MFARepositoryError.invalidCode) {
            _ = try await repository.challenge(code: "12ab")
        }
        #expect(await backend.challengeCallCount == 0)
    }

    @Test("A verified code receipt cannot be replayed")
    func verifiedReceiptCannotBeReplayed() async throws {
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(300)),
            challengeReceipt: MFAChallengeReceipt(
                id: "receipt-1",
                factorID: "factor-1",
                verifiedAt: now,
                expiresAt: now.addingTimeInterval(300)
            )
        )
        let repository = MFARepository(
            backend: backend,
            enrolledFactors: [MFAFactor(id: "factor-1", displayName: "TMI Authenticator")],
            now: { now }
        )

        _ = try await repository.challenge(code: "123456")
        await #expect(throws: MFARepositoryError.replayedChallenge) {
            _ = try await repository.challenge(code: "123456")
        }
    }

    @Test("Sign out invalidates privileged access but retains enrollment")
    func signOutInvalidatesChallenge() async throws {
        let factor = MFAFactor(id: "factor-1", displayName: "TMI Authenticator")
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(300)),
            challengeReceipt: MFAChallengeReceipt(
                id: "receipt-1",
                factorID: factor.id,
                verifiedAt: now,
                expiresAt: now.addingTimeInterval(300)
            )
        )
        let repository = MFARepository(
            backend: backend,
            enrolledFactors: [factor],
            now: { now }
        )

        _ = try await repository.challenge(code: "123456")
        #expect(
            await repository.access(
                for: .schoolAdministrator,
                operation: .staffManagement
            ) == .authorized
        )

        await repository.invalidateForSignOut()

        #expect(
            await repository.access(
                for: .schoolAdministrator,
                operation: .staffManagement
            ) == .challengeRequired
        )
        #expect(await repository.enrolledFactors == [factor])
    }

    @Test("Role promotion requires MFA and demotion retains the factor")
    func rolePromotionAndDemotion() async throws {
        let factor = MFAFactor(id: "factor-1", displayName: "TMI Authenticator")
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(300))
        )
        let repository = MFARepository(
            backend: backend,
            enrolledFactors: [factor],
            now: { now }
        )

        #expect(
            await repository.access(
                for: .teacher,
                operation: .sensitiveExport
            ) == .notRequired
        )
        #expect(
            await repository.access(
                for: .districtAdministrator,
                operation: .sensitiveExport
            ) == .challengeRequired
        )
        #expect(
            await repository.access(
                for: .teacher,
                operation: .sensitiveExport
            ) == .notRequired
        )
        #expect(await repository.enrolledFactors == [factor])
        #expect(await backend.unenrollCallCount == 0)
    }

    @Test("An administrator without a factor must enroll")
    func administratorWithoutFactorMustEnroll() async {
        let repository = MFARepository(
            backend: MFAStubBackend(
                enrollment: enrollment(expiresAt: now.addingTimeInterval(300))
            ),
            now: { now }
        )

        #expect(
            await repository.access(
                for: .schoolAdministrator,
                operation: .audit
            ) == .enrollmentRequired
        )
    }

    @Test("Enrollment preserves recent-authentication failures")
    func enrollmentRequiresRecentAuthentication() async {
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(300))
        )
        await backend.setBeginEnrollmentError(.recentAuthenticationRequired)
        let repository = MFARepository(
            backend: backend,
            now: { now }
        )

        await #expect(throws: MFARepositoryError.recentAuthenticationRequired) {
            _ = try await repository.enrollTOTP()
        }
    }

    @Test("Unenrolling removes the factor and its challenge")
    func unenrollingRemovesFactor() async throws {
        let factor = MFAFactor(id: "factor-1", displayName: "TMI Authenticator")
        let backend = MFAStubBackend(
            enrollment: enrollment(expiresAt: now.addingTimeInterval(300)),
            challengeReceipt: MFAChallengeReceipt(
                id: "receipt-1",
                factorID: factor.id,
                verifiedAt: now,
                expiresAt: now.addingTimeInterval(300)
            )
        )
        let repository = MFARepository(
            backend: backend,
            enrolledFactors: [factor],
            now: { now }
        )
        _ = try await repository.challenge(code: "123456")

        try await repository.unenroll(factorID: factor.id)

        #expect(await repository.enrolledFactors.isEmpty)
        #expect(
            await repository.access(
                for: .districtAdministrator,
                operation: .retention
            ) == .enrollmentRequired
        )
    }

    private func enrollment(expiresAt: Date) -> TOTPEnrollment {
        TOTPEnrollment(
            secretKey: "ABCD1234",
            qrCodeURL: URL(string: "otpauth://totp/TMI:staff@example.edu?secret=ABCD1234")!,
            expiresAt: expiresAt
        )
    }
}

private actor MFAStubBackend: MFABackend {
    private let enrollment: TOTPEnrollment
    private let challengeReceipt: MFAChallengeReceipt
    private var beginEnrollmentError: MFARepositoryError?
    private(set) var challengeCallCount = 0
    private(set) var unenrollCallCount = 0

    init(
        enrollment: TOTPEnrollment,
        challengeReceipt: MFAChallengeReceipt? = nil
    ) {
        self.enrollment = enrollment
        self.challengeReceipt = challengeReceipt ?? MFAChallengeReceipt(
            id: "receipt-default",
            factorID: "factor-1",
            verifiedAt: .distantPast,
            expiresAt: .distantFuture
        )
    }

    func setBeginEnrollmentError(_ error: MFARepositoryError) {
        beginEnrollmentError = error
    }

    func beginEnrollment() async throws -> TOTPEnrollment {
        if let beginEnrollmentError {
            throw beginEnrollmentError
        }
        return enrollment
    }

    func confirmEnrollment(
        _ enrollment: TOTPEnrollment,
        code: String
    ) async throws -> MFAFactor {
        MFAFactor(id: "factor-1", displayName: "TMI Authenticator")
    }

    func challenge(
        factorID: String,
        code: String
    ) async throws -> MFAChallengeReceipt {
        challengeCallCount += 1
        return challengeReceipt
    }

    func unenroll(factorID: String) async throws {
        unenrollCallCount += 1
    }
}
