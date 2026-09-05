import Foundation
import Testing
@testable import TMI

@Suite("Canonical Authorization Policy")
struct AuthorizationPolicyTests {
    private static let allCapabilities = Set(Capability.allCases)

    @Test("Capabilities expose the exact stable raw vocabulary")
    func capabilityRawVocabulary() throws {
        let expected = Set([
            "student.read.detail",
            "student.write.detail",
            "student.restricted.read",
            "student.restricted.write",
            "plan.approve",
            "staff.manage",
            "report.export",
            "audit.read",
        ])

        #expect(Set(Capability.allCases.map(\.rawValue)) == expected)
        #expect(Capability.allCases.count == expected.count)

        for capability in Capability.allCases {
            let encoded = try JSONEncoder().encode(capability)
            let decoded = try JSONDecoder().decode(Capability.self, from: encoded)
            #expect(decoded == capability)
        }
    }

    @Test("Staff roles expose canonical camel-case vocabulary and reject legacy values")
    func staffRoleRawVocabulary() throws {
        let expected = Set([
            "teacher",
            "counselor",
            "socialWorker",
            "schoolAdministrator",
            "districtAdministrator",
        ])

        #expect(Set(StaffRole.allCases.map(\.rawValue)) == expected)
        #expect(StaffRole.allCases.count == expected.count)

        for role in StaffRole.allCases {
            let encoded = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(StaffRole.self, from: encoded)
            #expect(decoded == role)
        }

        let legacyValues = [
            "social_worker",
            "school_administrator",
            "district_administrator",
            "administrator",
            "admin",
        ]

        for legacyValue in legacyValues {
            let data = Data("\"\(legacyValue)\"".utf8)
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(StaffRole.self, from: data)
            }
        }
    }

    @Test("Membership context round-trips every trusted field")
    func membershipContextJSONRoundTrip() throws {
        let member = membership(
            userID: "user-42",
            districtID: "district-9",
            schoolIDs: ["school-a", "school-b"],
            role: .counselor,
            capabilities: [.studentReadDetail, .studentRestrictedRead, .planApprove],
            assignedStudentIDs: ["student-1", "student-2"],
            isActive: true,
            version: 7
        )

        let data = try JSONEncoder().encode(member)
        let decoded = try JSONDecoder().decode(MembershipContext.self, from: data)

        #expect(decoded == member)
    }

    @Test("Inactive memberships fail closed for every policy predicate")
    func inactiveMembershipFailsClosed() {
        let member = membership(
            role: .districtAdministrator,
            capabilities: Self.allCapabilities,
            isActive: false
        )
        let student = scope()

        expectEveryStudentPredicateDenied(member, student: student)
        #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a"))
        #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a", schoolID: "school-a"))
    }

    @Test("Malformed memberships and targets fail closed")
    func malformedInputsFailClosed() {
        let malformedMembers = [
            membership(userID: " ", role: .districtAdministrator, capabilities: Self.allCapabilities),
            membership(districtID: "", role: .districtAdministrator, capabilities: Self.allCapabilities),
            membership(schoolIDs: ["school-a", " "], role: .districtAdministrator, capabilities: Self.allCapabilities),
            membership(role: .districtAdministrator, capabilities: Self.allCapabilities, assignedStudentIDs: [""]),
            membership(role: .districtAdministrator, capabilities: Self.allCapabilities, version: 0),
        ]

        for member in malformedMembers {
            expectEveryStudentPredicateDenied(member, student: scope())
            #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a"))
            #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a", schoolID: "school-a"))
        }

        let validMember = membership(
            role: .districtAdministrator,
            capabilities: Self.allCapabilities
        )
        let malformedStudents = [
            scope(studentID: ""),
            scope(districtID: " "),
            scope(schoolID: ""),
        ]

        for student in malformedStudents {
            expectEveryStudentPredicateDenied(validMember, student: student)
        }

        #expect(!AuthorizationPolicy.canViewAggregate(validMember, districtID: ""))
        #expect(!AuthorizationPolicy.canViewAggregate(validMember, districtID: "district-a", schoolID: " "))
    }

    @Test("Every membership identifier field rejects unsafe opaque identifiers")
    func membershipIdentifierFieldsRejectUnsafeValues() {
        for invalidIdentifier in Self.unsafeOpaqueIdentifiers {
            let invalidUser = membership(
                userID: invalidIdentifier,
                role: .districtAdministrator,
                capabilities: Self.allCapabilities
            )
            expectEveryStudentPredicateDenied(invalidUser, student: scope())
            expectEveryAggregatePredicateDenied(invalidUser, districtID: "district-a")

            let invalidDistrict = membership(
                districtID: invalidIdentifier,
                role: .districtAdministrator,
                capabilities: Self.allCapabilities
            )
            expectEveryStudentPredicateDenied(
                invalidDistrict,
                student: scope(districtID: invalidIdentifier)
            )
            expectEveryAggregatePredicateDenied(invalidDistrict, districtID: invalidIdentifier)

            let invalidSchoolSet = membership(
                schoolIDs: [invalidIdentifier],
                role: .districtAdministrator,
                capabilities: Self.allCapabilities
            )
            expectEveryStudentPredicateDenied(invalidSchoolSet, student: scope())
            expectEveryAggregatePredicateDenied(invalidSchoolSet, districtID: "district-a")

            let invalidAssignmentSet = membership(
                role: .districtAdministrator,
                capabilities: Self.allCapabilities,
                assignedStudentIDs: [invalidIdentifier]
            )
            expectEveryStudentPredicateDenied(invalidAssignmentSet, student: scope())
            expectEveryAggregatePredicateDenied(invalidAssignmentSet, districtID: "district-a")
        }
    }

    @Test("Every student scope identifier field rejects unsafe opaque identifiers")
    func studentScopeIdentifierFieldsRejectUnsafeValues() {
        let validMember = membership(
            role: .districtAdministrator,
            capabilities: Self.allCapabilities
        )

        for invalidIdentifier in Self.unsafeOpaqueIdentifiers {
            expectEveryStudentPredicateDenied(
                validMember,
                student: scope(studentID: invalidIdentifier)
            )

            let matchingInvalidDistrictMember = membership(
                districtID: invalidIdentifier,
                role: .districtAdministrator,
                capabilities: Self.allCapabilities
            )
            expectEveryStudentPredicateDenied(
                matchingInvalidDistrictMember,
                student: scope(districtID: invalidIdentifier)
            )

            expectEveryStudentPredicateDenied(
                validMember,
                student: scope(schoolID: invalidIdentifier)
            )
        }
    }

    @Test("Aggregate district and school identifiers reject unsafe opaque identifiers")
    func aggregateIdentifierFieldsRejectUnsafeValues() {
        let validMember = membership(
            schoolIDs: [],
            role: .districtAdministrator,
            capabilities: Self.allCapabilities
        )

        for invalidIdentifier in Self.unsafeOpaqueIdentifiers {
            let matchingInvalidDistrictMember = membership(
                districtID: invalidIdentifier,
                schoolIDs: [],
                role: .districtAdministrator,
                capabilities: Self.allCapabilities
            )

            #expect(
                !AuthorizationPolicy.canViewAggregate(
                    matchingInvalidDistrictMember,
                    districtID: invalidIdentifier
                )
            )
            #expect(
                !AuthorizationPolicy.canViewAggregate(
                    matchingInvalidDistrictMember,
                    districtID: invalidIdentifier,
                    schoolID: "school-a"
                )
            )
            #expect(
                !AuthorizationPolicy.canViewAggregate(
                    validMember,
                    districtID: "district-a",
                    schoolID: invalidIdentifier
                )
            )
        }
    }

    @Test("Negative membership versions fail closed")
    func negativeMembershipVersionFailsClosed() {
        let member = membership(
            role: .districtAdministrator,
            capabilities: Self.allCapabilities,
            version: -1
        )

        expectEveryStudentPredicateDenied(member, student: scope())
        expectEveryAggregatePredicateDenied(member, districtID: "district-a")
    }

    @Test("Opaque identifiers allow exactly 1500 UTF-8 bytes")
    func maximumOpaqueIdentifierLengthIsAllowed() {
        let maximumLengthIdentifier = String(repeating: "é", count: 750)
        let member = membership(
            userID: maximumLengthIdentifier,
            districtID: maximumLengthIdentifier,
            schoolIDs: [maximumLengthIdentifier],
            role: .districtAdministrator,
            capabilities: Self.allCapabilities,
            assignedStudentIDs: [maximumLengthIdentifier]
        )
        let student = scope(
            studentID: maximumLengthIdentifier,
            districtID: maximumLengthIdentifier,
            schoolID: maximumLengthIdentifier
        )

        #expect(maximumLengthIdentifier.utf8.count == 1_500)
        #expect(AuthorizationPolicy.canReadStudentDetail(member, student: student))
        #expect(AuthorizationPolicy.canWriteStudentDetail(member, student: student))
        #expect(AuthorizationPolicy.canReadRestrictedRecord(member, student: student))
        #expect(AuthorizationPolicy.canWriteRestrictedRecord(member, student: student))
        #expect(AuthorizationPolicy.canViewAggregate(member, districtID: maximumLengthIdentifier))
        #expect(
            AuthorizationPolicy.canViewAggregate(
                member,
                districtID: maximumLengthIdentifier,
                schoolID: maximumLengthIdentifier
            )
        )
    }

    @Test("Cross-district and wrong-school targets are denied even with every capability")
    func tenantAndSchoolBoundariesFailClosed() {
        let districtAdministrator = membership(
            role: .districtAdministrator,
            capabilities: Self.allCapabilities
        )
        let schoolAdministrator = membership(
            role: .schoolAdministrator,
            capabilities: Self.allCapabilities
        )
        let assignedTeacher = membership(
            role: .teacher,
            capabilities: Self.allCapabilities,
            assignedStudentIDs: ["student-1"]
        )

        expectEveryStudentPredicateDenied(
            districtAdministrator,
            student: scope(districtID: "district-b")
        )
        expectEveryStudentPredicateDenied(
            schoolAdministrator,
            student: scope(schoolID: "school-b")
        )
        expectEveryStudentPredicateDenied(
            assignedTeacher,
            student: scope(schoolID: "school-b")
        )

        #expect(!AuthorizationPolicy.canViewAggregate(districtAdministrator, districtID: "district-b"))
        #expect(!AuthorizationPolicy.canViewAggregate(schoolAdministrator, districtID: "district-a", schoolID: "school-b"))
    }

    @Test("Teachers read every student in their schools while writes remain assignment scoped")
    func teacherDetailAccessIsSchoolWideForReads() {
        let member = membership(role: .teacher, assignedStudentIDs: ["student-1"])

        #expect(AuthorizationPolicy.canReadStudentDetail(member, student: scope()))
        #expect(AuthorizationPolicy.canWriteStudentDetail(member, student: scope()))
        #expect(AuthorizationPolicy.canReadStudentDetail(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: scope(schoolID: "school-b")))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: scope(schoolID: "school-b")))
    }

    @Test("Counselors remain assignment scoped for student detail")
    func counselorDetailAccessRemainsAssignmentScoped() {
        let member = membership(role: .counselor, assignedStudentIDs: ["student-1"])

        #expect(AuthorizationPolicy.canReadStudentDetail(member, student: scope()))
        #expect(AuthorizationPolicy.canWriteStudentDetail(member, student: scope()))
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: scope(schoolID: "school-b")))
    }

    @Test("Social workers can read assigned detail but never write student profiles")
    func socialWorkerDetailAccess() {
        let member = membership(
            role: .socialWorker,
            capabilities: Self.allCapabilities,
            assignedStudentIDs: ["student-1"]
        )

        #expect(AuthorizationPolicy.canReadStudentDetail(member, student: scope()))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: scope()))
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: scope(schoolID: "school-b")))
    }

    @Test("School administrators read their schools by role while writes require capability")
    func schoolAdministratorDetailCapabilities() {
        let noCapabilities = membership(role: .schoolAdministrator)
        let readOnly = membership(role: .schoolAdministrator, capabilities: [.studentReadDetail])
        let writeOnly = membership(role: .schoolAdministrator, capabilities: [.studentWriteDetail])

        #expect(AuthorizationPolicy.canReadStudentDetail(noCapabilities, student: scope()))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(noCapabilities, student: scope()))
        #expect(AuthorizationPolicy.canReadStudentDetail(readOnly, student: scope()))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(readOnly, student: scope()))
        #expect(AuthorizationPolicy.canReadStudentDetail(writeOnly, student: scope()))
        #expect(AuthorizationPolicy.canWriteStudentDetail(writeOnly, student: scope()))
        #expect(!AuthorizationPolicy.canReadStudentDetail(readOnly, student: scope(schoolID: "school-b")))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(writeOnly, student: scope(schoolID: "school-b")))
    }

    @Test("District administrators read their district by role while writes require capability")
    func districtAdministratorDetailCapabilities() {
        let noCapabilities = membership(role: .districtAdministrator)
        let readOnly = membership(role: .districtAdministrator, capabilities: [.studentReadDetail])
        let writeOnly = membership(role: .districtAdministrator, capabilities: [.studentWriteDetail])

        #expect(AuthorizationPolicy.canReadStudentDetail(noCapabilities, student: scope()))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(noCapabilities, student: scope()))
        #expect(AuthorizationPolicy.canReadStudentDetail(readOnly, student: scope()))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(readOnly, student: scope()))
        #expect(AuthorizationPolicy.canReadStudentDetail(writeOnly, student: scope()))
        #expect(AuthorizationPolicy.canWriteStudentDetail(writeOnly, student: scope()))
        #expect(!AuthorizationPolicy.canReadStudentDetail(readOnly, student: scope(districtID: "district-b")))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(writeOnly, student: scope(districtID: "district-b")))
    }

    @Test("Assignment alone never grants restricted record access")
    func assignmentDoesNotGrantRestrictedAccess() {
        for role in [StaffRole.teacher, .counselor, .socialWorker] {
            let member = membership(role: role, assignedStudentIDs: ["student-1"])

            #expect(!AuthorizationPolicy.canReadRestrictedRecord(member, student: scope()))
            #expect(!AuthorizationPolicy.canWriteRestrictedRecord(member, student: scope()))
        }
    }

    @Test("Restricted read and write capabilities are independent")
    func restrictedCapabilitiesAreIndependent() {
        let readOnly = membership(
            role: .counselor,
            capabilities: [.studentRestrictedRead],
            assignedStudentIDs: ["student-1"]
        )
        let writeOnly = membership(
            role: .counselor,
            capabilities: [.studentRestrictedWrite],
            assignedStudentIDs: ["student-1"]
        )

        #expect(AuthorizationPolicy.canReadRestrictedRecord(readOnly, student: scope()))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(readOnly, student: scope()))
        #expect(!AuthorizationPolicy.canReadRestrictedRecord(writeOnly, student: scope()))
        #expect(AuthorizationPolicy.canWriteRestrictedRecord(writeOnly, student: scope()))
    }

    @Test("Restricted capabilities never bypass detail visibility or scope boundaries")
    func restrictedCapabilitiesDoNotBypassBaseVisibility() {
        let unassignedCounselor = membership(
            role: .counselor,
            capabilities: [.studentRestrictedRead, .studentRestrictedWrite]
        )
        let scopedAdministrator = membership(
            role: .schoolAdministrator,
            capabilities: [.studentRestrictedRead, .studentRestrictedWrite]
        )

        #expect(!AuthorizationPolicy.canReadRestrictedRecord(unassignedCounselor, student: scope()))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(unassignedCounselor, student: scope()))
        #expect(AuthorizationPolicy.canReadRestrictedRecord(scopedAdministrator, student: scope()))
        #expect(AuthorizationPolicy.canWriteRestrictedRecord(scopedAdministrator, student: scope()))
        #expect(!AuthorizationPolicy.canReadRestrictedRecord(scopedAdministrator, student: scope(schoolID: "school-b")))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(scopedAdministrator, student: scope(districtID: "district-b")))
    }

    @Test("Social workers may write restricted records without profile-write access")
    func socialWorkerRestrictedWriteAccess() {
        let member = membership(
            role: .socialWorker,
            capabilities: [.studentRestrictedWrite, .studentWriteDetail],
            assignedStudentIDs: ["student-1"]
        )

        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: scope()))
        #expect(AuthorizationPolicy.canWriteRestrictedRecord(member, student: scope()))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(member, student: scope(studentID: "student-2")))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(member, student: scope(schoolID: "school-b")))
    }

    @Test("Aggregate access follows school and district administrator scope")
    func aggregateScope() {
        let schoolAdministrator = membership(role: .schoolAdministrator)
        let districtAdministrator = membership(schoolIDs: [], role: .districtAdministrator)

        #expect(!AuthorizationPolicy.canViewAggregate(schoolAdministrator, districtID: "district-a"))
        #expect(AuthorizationPolicy.canViewAggregate(schoolAdministrator, districtID: "district-a", schoolID: "school-a"))
        #expect(!AuthorizationPolicy.canViewAggregate(schoolAdministrator, districtID: "district-a", schoolID: "school-b"))

        #expect(AuthorizationPolicy.canViewAggregate(districtAdministrator, districtID: "district-a"))
        #expect(AuthorizationPolicy.canViewAggregate(districtAdministrator, districtID: "district-a", schoolID: "school-any"))
        #expect(!AuthorizationPolicy.canViewAggregate(districtAdministrator, districtID: "district-b"))
        #expect(!AuthorizationPolicy.canViewAggregate(districtAdministrator, districtID: "district-b", schoolID: "school-any"))
    }

    @Test("The coarse aggregate API denies assigned staff roles")
    func coarseAggregateDeniesAssignedStaff() {
        for role in [StaffRole.teacher, .counselor, .socialWorker] {
            let member = membership(
                role: role,
                capabilities: Self.allCapabilities,
                assignedStudentIDs: ["student-1"]
            )

            #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a"))
            #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: "district-a", schoolID: "school-a"))
        }
    }

    private func expectEveryStudentPredicateDenied(
        _ member: MembershipContext,
        student: StudentAuthorizationScope
    ) {
        #expect(!AuthorizationPolicy.canReadStudentDetail(member, student: student))
        #expect(!AuthorizationPolicy.canWriteStudentDetail(member, student: student))
        #expect(!AuthorizationPolicy.canReadRestrictedRecord(member, student: student))
        #expect(!AuthorizationPolicy.canWriteRestrictedRecord(member, student: student))
    }

    private func expectEveryAggregatePredicateDenied(
        _ member: MembershipContext,
        districtID: String
    ) {
        #expect(!AuthorizationPolicy.canViewAggregate(member, districtID: districtID))
        #expect(
            !AuthorizationPolicy.canViewAggregate(
                member,
                districtID: districtID,
                schoolID: "school-a"
            )
        )
    }

    private static var unsafeOpaqueIdentifiers: [String] {
        [
            "segment/segment",
            ".",
            "..",
            "line\nbreak",
            "null\u{0000}scalar",
            String(repeating: "é", count: 751),
        ]
    }

    private func membership(
        userID: String = "user-1",
        districtID: String = "district-a",
        schoolIDs: Set<String> = ["school-a"],
        role: StaffRole,
        capabilities: Set<Capability> = [],
        assignedStudentIDs: Set<String> = [],
        isActive: Bool = true,
        version: Int = 1
    ) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: schoolIDs,
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: assignedStudentIDs,
            isActive: isActive,
            version: version
        )
    }

    private func scope(
        studentID: String = "student-1",
        districtID: String = "district-a",
        schoolID: String = "school-a"
    ) -> StudentAuthorizationScope {
        StudentAuthorizationScope(
            studentID: studentID,
            districtID: districtID,
            schoolID: schoolID
        )
    }
}
