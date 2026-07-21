import Foundation
@preconcurrency import FirebaseFunctions
import Testing
@testable import TMI

@Suite("Firebase staff invitation provisioning")
@MainActor
struct FirebaseStaffInvitationProvisionerTests {
    @Test("The client sends no identity, password, or authorization fields")
    func requestContainsOnlyOnboardingInputs() async throws {
        var capturedRequest: [String: Any] = [:]
        let provisioner = FirebaseStaffInvitationProvisioner { request in
            capturedRequest = request
            return validResponse
        }

        let membership = try await provisioner.provision(
            request: registrationRequest,
            identity: verifiedIdentity
        )

        #expect(Set(capturedRequest.keys) == [
            "invitationCode",
            "displayName",
            "privacyPolicyVersion",
            "acceptableUsePolicyVersion",
        ])
        #expect(capturedRequest["invitationCode"] as? String == "opaque-invitation")
        #expect(capturedRequest["displayName"] as? String == "Morgan Lee")
        #expect(capturedRequest["password"] == nil)
        #expect(capturedRequest["email"] == nil)
        #expect(capturedRequest["userID"] == nil)
        #expect(capturedRequest["requestedRole"] == nil)
        #expect(capturedRequest["districtID"] == nil)
        #expect(capturedRequest["schoolIDs"] == nil)
        #expect(capturedRequest["capabilities"] == nil)
        #expect(membership == expectedMembership)
    }

    @Test("An unavailable callable preserves the verified account for claim repair")
    func unavailableIsRecoverable() async {
        let unavailable = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.unavailable.rawValue
        )
        let provisioner = FirebaseStaffInvitationProvisioner { _ in
            throw unavailable
        }

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await provisioner.provision(
                request: registrationRequest,
                identity: verifiedIdentity
            )
        }
    }

    @Test("An ambiguous callable timeout preserves the account for idempotent retry")
    func deadlineExceededIsRecoverable() async {
        let timeout = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.deadlineExceeded.rawValue
        )
        let provisioner = FirebaseStaffInvitationProvisioner { _ in
            throw timeout
        }

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await provisioner.provision(
                request: registrationRequest,
                identity: verifiedIdentity
            )
        }
    }

    @Test("A mismatched post-commit response fails closed and remains repairable")
    func mismatchedIdentityFailsClosed() async {
        var response = validResponse
        response["userID"] = "different-user"
        let provisioner = FirebaseStaffInvitationProvisioner { _ in response }

        await #expect(throws: StaffInvitationProvisioningError.claimRefreshPending) {
            _ = try await provisioner.provision(
                request: registrationRequest,
                identity: verifiedIdentity
            )
        }
    }

    private var registrationRequest: StaffRegistrationRequest {
        StaffRegistrationRequest(
            displayName: "Morgan Lee",
            email: "morgan@example.edu",
            password: "Correct-Horse-9",
            requestedRole: .teacher,
            invitationCode: "opaque-invitation",
            privacyPolicyVersion: "2026-07-20",
            acceptableUsePolicyVersion: "2026-07-20"
        )
    }

    private var verifiedIdentity: AuthIdentity {
        AuthIdentity(
            userID: "staff-1",
            email: "morgan@example.edu",
            isEmailVerified: true
        )
    }

    private var validResponse: [String: Any] {
        [
            "userID": "staff-1",
            "districtID": "district-a",
            "schoolIDs": ["school-a"],
            "role": "teacher",
            "capabilities": ["student.read.detail"],
            "assignedStudentIDs": ["student-a"],
            "isActive": true,
            "version": 1,
            "replayed": false,
        ]
    }

    private var expectedMembership: MembershipContext {
        MembershipContext(
            userID: "staff-1",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .teacher,
            capabilities: [.studentReadDetail],
            assignedStudentIDs: ["student-a"],
            isActive: true,
            version: 1
        )
    }
}
