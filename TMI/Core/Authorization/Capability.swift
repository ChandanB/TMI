enum Capability: String, Codable, Sendable, CaseIterable, Equatable {
    case studentReadDetail = "student.read.detail"
    case studentWriteDetail = "student.write.detail"
    case studentRestrictedRead = "student.restricted.read"
    case studentRestrictedWrite = "student.restricted.write"
    case planApprove = "plan.approve"
    case staffManage = "staff.manage"
    case reportExport = "report.export"
    case auditRead = "audit.read"
}

enum StaffRole: String, Codable, Sendable, CaseIterable, Equatable {
    case teacher
    case counselor
    case socialWorker
    case schoolAdministrator
    case districtAdministrator
}

extension StaffRole {
    var displayName: String {
        switch self {
        case .teacher: "Teacher"
        case .counselor: "Counselor"
        case .socialWorker: "Social Worker"
        case .schoolAdministrator: "School Administrator"
        case .districtAdministrator: "District Administrator"
        }
    }
}
