import Foundation
import Testing
@testable import TMI

@Suite("Trusted Membership Repository")
struct MembershipRepositoryTests {
    @Test("Completely absent trusted claims are distinguished from malformed claims")
    func absentTrustedClaimsAreMissing() {
        #expect(throws: TrustedTenantClaimError.missing) {
            try TrustedTenantClaim(userID: "user-1", tokenClaims: [:])
        }
    }

    @Test("Partial trusted claims remain malformed")
    func partialTrustedClaimsAreMalformed() {
        #expect(throws: TrustedTenantClaimError.malformed) {
            try TrustedTenantClaim(
                userID: "user-1",
                tokenClaims: [TrustedTenantClaim.districtIDClaimKey: "district-1"]
            )
        }
    }

    @Test("Trusted claims use the frozen wire keys and accept staff only")
    func trustedClaimWireContract() throws {
        let claim = try TrustedTenantClaim(
            userID: "user-1",
            tokenClaims: [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": 4,
            ]
        )

        #expect(claim == TrustedTenantClaim(
            userID: "user-1",
            districtID: "district-1",
            accessClass: .staff,
            membershipVersion: 4
        ))
        #expect(TrustedTenantClaim.districtIDClaimKey == "tmiDistrictID")
        #expect(TrustedTenantClaim.accessClassClaimKey == "tmiAccessClass")
        #expect(TrustedTenantClaim.membershipVersionClaimKey == "tmiMembershipVersion")
        #expect(Set(TrustedAccessClass.allCases.map(\.rawValue)) == [
            "staff",
            "studentMode",
            "guardianRespondent",
        ])

        for accessClass in ["studentMode", "guardianRespondent", "administrator", "staff "] {
            #expect(throws: TrustedTenantClaimError.self) {
                try TrustedTenantClaim(
                    userID: "user-1",
                    tokenClaims: [
                        "tmiDistrictID": "district-1",
                        "tmiAccessClass": accessClass,
                        "tmiMembershipVersion": 4,
                    ]
                )
            }
        }
    }

    @Test("Missing and malformed trusted claims fail closed")
    func malformedClaimsFailClosed() {
        let invalidClaims: [[String: Any]] = [
            [:],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
            ],
            [
                "tmiDistrictID": "district/1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": 1,
            ],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": 0,
            ],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": true,
            ],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": 1.5,
            ],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": Double(Int.max),
            ],
            [
                "tmiDistrictID": "district-1",
                "tmiAccessClass": "staff",
                "tmiMembershipVersion": Double.infinity,
            ],
        ]

        for tokenClaims in invalidClaims {
            #expect(throws: TrustedTenantClaimError.self) {
                try TrustedTenantClaim(userID: "user-1", tokenClaims: tokenClaims)
            }
        }

        #expect(throws: TrustedTenantClaimError.self) {
            try TrustedTenantClaim(
                userID: "user/1",
                tokenClaims: [
                    "tmiDistrictID": "district-1",
                    "tmiAccessClass": "staff",
                    "tmiMembershipVersion": 1,
                ]
            )
        }
    }

    @Test("Repository reads the exact trusted member path from the server")
    func readsExactServerPath() async throws {
        let record = membershipRecord(version: 3)
        let store = RecordingMembershipStore(outcomes: [.record(record)])
        let repository = MembershipRepository(store: store)
        let claim = trustedClaim(version: 3)

        let membership = try await repository.membership(for: claim)
        let requests = await store.capturedRequests()

        #expect(requests == [
            MembershipStoreRequest(
                path: "districts/district-1/members/user-1",
                source: .server
            )
        ])
        #expect(membership.userID == "user-1")
        #expect(membership.districtID == "district-1")
        #expect(membership.role == .teacher)
        #expect(membership.version == 3)
    }

    @Test("Missing, offline, inactive, mismatched, and malformed records deny access")
    func invalidMembershipsFailClosed() async {
        let scenarios: [(MembershipStoreOutcome, TrustedTenantClaim)] = [
            (.missing, trustedClaim(version: 1)),
            (.failure, trustedClaim(version: 1)),
            (.record(membershipRecord(isActive: false)), trustedClaim(version: 1)),
            (.record(membershipRecord(version: 2)), trustedClaim(version: 1)),
            (
                .record(membershipRecord(schoolIDs: ["school/unsafe"])),
                trustedClaim(version: 1)
            ),
            (
                .record(membershipRecord(assignedStudentIDs: ["\u{0000}"])),
                trustedClaim(version: 1)
            ),
        ]

        for (outcome, claim) in scenarios {
            let repository = MembershipRepository(
                store: RecordingMembershipStore(outcomes: [outcome])
            )

            await #expect(throws: MembershipRepositoryError.self) {
                try await repository.membership(for: claim)
            }
        }
    }

    @Test("Membership versions advance monotonically and reject rollback")
    func membershipVersionsAreMonotonic() async throws {
        let store = RecordingMembershipStore(outcomes: [
            .record(membershipRecord(version: 1)),
            .record(membershipRecord(version: 2)),
            .record(membershipRecord(version: 1)),
        ])
        let repository = MembershipRepository(store: store)

        let first = try await repository.membership(for: trustedClaim(version: 1))
        let second = try await repository.membership(for: trustedClaim(version: 2))

        #expect(first.version == 1)
        #expect(second.version == 2)
        await #expect(throws: MembershipRepositoryError.self) {
            try await repository.membership(for: trustedClaim(version: 1))
        }
    }

    @Test("Version history is isolated by trusted district and user path")
    func versionHistoryUsesTrustedMemberKey() async throws {
        let store = RecordingMembershipStore(outcomes: [
            .record(membershipRecord(version: 5)),
            .record(membershipRecord(version: 1)),
        ])
        let repository = MembershipRepository(store: store)

        _ = try await repository.membership(for: trustedClaim(version: 5))
        let otherMember = try await repository.membership(
            for: TrustedTenantClaim(
                userID: "user-2",
                districtID: "district-1",
                accessClass: .staff,
                membershipVersion: 1
            )
        )

        #expect(otherMember.userID == "user-2")
        #expect(otherMember.version == 1)
    }

    private func trustedClaim(version: Int) -> TrustedTenantClaim {
        TrustedTenantClaim(
            userID: "user-1",
            districtID: "district-1",
            accessClass: .staff,
            membershipVersion: version
        )
    }

    private func membershipRecord(
        schoolIDs: Set<String> = ["school-1"],
        isActive: Bool = true,
        version: Int = 1,
        assignedStudentIDs: Set<String> = ["student-1"]
    ) -> MembershipStoreRecord {
        MembershipStoreRecord(
            schoolIDs: schoolIDs,
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: assignedStudentIDs,
            isActive: isActive,
            version: version
        )
    }
}

private enum MembershipStoreOutcome: Sendable {
    case record(MembershipStoreRecord)
    case missing
    case failure
}

private actor RecordingMembershipStore: MembershipStore {
    private var outcomes: [MembershipStoreOutcome]
    private var requests: [MembershipStoreRequest] = []

    init(outcomes: [MembershipStoreOutcome]) {
        self.outcomes = outcomes
    }

    func membership(for request: MembershipStoreRequest) async throws -> MembershipStoreRecord? {
        requests.append(request)
        guard !outcomes.isEmpty else {
            throw MembershipStoreTestError.noQueuedOutcome
        }

        switch outcomes.removeFirst() {
        case .record(let record):
            return record
        case .missing:
            return nil
        case .failure:
            throw MembershipStoreTestError.offline
        }
    }

    func capturedRequests() -> [MembershipStoreRequest] {
        requests
    }
}

private enum MembershipStoreTestError: Error {
    case noQueuedOutcome
    case offline
}
