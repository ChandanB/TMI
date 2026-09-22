import Foundation
import Testing
@testable import TMI

@Suite("Staff administration")
@MainActor
struct StaffAdministrationTests {
    @Test("Role defaults never include restricted-record writes")
    func roleDefaults() {
        for role in StaffRole.allCases {
            #expect(!role.defaultCapabilities.contains(.studentRestrictedWrite))
        }
        #expect(StaffRole.schoolAdministrator.defaultCapabilities.contains(.staffManage))
        #expect(!StaffRole.teacher.defaultCapabilities.contains(.staffManage))
    }

    @Test("Audit events have plain-language titles")
    func auditTitles() {
        let event = AuditEventSummary(id: "1", action: "staff.invitation.create", actorUserID: "a", targetPath: "", createdAt: nil, isOperator: false)
        #expect(event.title == "Invitation created")
        let unknown = AuditEventSummary(id: "2", action: "something.new", actorUserID: "a", targetPath: "", createdAt: nil, isOperator: false)
        #expect(unknown.title == "something.new")
    }

    @Test("In-memory repository applies membership edits with a new version")
    func inMemoryEdits() async throws {
        let repository = InMemoryStaffAdministrationRepository()
        let staff = try await repository.staff(districtID: "d")
        let teacher = try #require(staff.first { $0.userID == "teacher-2" })
        var draft = AdminMembershipDraft(member: teacher)
        draft.isActive = true
        try await repository.updateMembership(draft, districtID: "d", operationID: "op")
        let updated = try #require(try await repository.staff(districtID: "d").first { $0.userID == "teacher-2" })
        #expect(updated.isActive)
        #expect(updated.recordVersion == teacher.recordVersion + 1)
    }

    @Test("Functions errors map to actionable admin errors")
    func errorMapping() {
        #expect(StaffAdministrationError.map(URLError(.timedOut)) == .unavailable)
        #expect(StaffAdministrationError.map(StaffAdministrationError.conflict) == .conflict)
    }
}
