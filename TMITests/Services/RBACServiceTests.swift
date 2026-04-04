import XCTest
@testable import TMI

final class RBACServiceTests: XCTestCase {
    func testEducatorRolesCanDeleteStudents() {
        let roles: [UserRole] = [
            .teacher,
            .counselor,
            .administrator,
            .admin,
            .socialWorker,
            .superintendent,
            .districtAdmin
        ]

        for role in roles {
            XCTAssertTrue(
                role.canDeleteStudents,
                "\(role.rawValue) should be allowed to delete students"
            )
        }
    }

    func testNonEducatorRolesCannotDeleteStudents() {
        let roles: [UserRole] = [
            .student,
            .parent,
            .legalGuardian
        ]

        for role in roles {
            XCTAssertFalse(
                role.canDeleteStudents,
                "\(role.rawValue) should not be allowed to delete students"
            )
        }
    }
}
